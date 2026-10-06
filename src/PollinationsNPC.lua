--[[
	PollinationsNPC.lua
	Luau ModuleScript for NPC dialogue powered by Pollinations AI text models.
	Place in: ServerScriptService → Modules → PollinationsNPC

	Usage:
		local PollinationsNPC = require(game.ServerScriptService.Modules.PollinationsNPC)
		local npc = PollinationsNPC.new({
			model = "openai/gpt-5.4-nano",
			systemPrompt = "You are a wise old wizard.",
			apiKey = game:GetService("ServerStorage"):GetSecret("POLLINATIONS_API_KEY"),
		})
		npc:SetupProximityPrompt(workspace.NPCModel)
		npc:SetupChatCommand("Wizard")
		npc:OnPlayerQuestion(function(player, question, reply)
			print(player.Name .. " asked: " .. question)
			print("NPC replied: " .. reply)
		end)
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local PollinationsNPC = {}
PollinationsNPC.__index = PollinationsNPC

-- Base URLs for Pollinations generation API
local BASE_URL = "https://gen.pollinations.ai"
local TEXT_MODELS_URL = BASE_URL .. "/text/models"
local CHAT_URL = BASE_URL .. "/v1/chat/completions"
local FALLBACK_TEXT_URL = "https://text.pollinations.ai/"

-- Default configuration
PollinationsNPC.DEFAULT_CONFIG = {
	model = "openai/gpt-5.4-nano",
	systemPrompt = "You are a helpful NPC in a Roblox game.",
	temperature = 0.7,
	maxTokens = 256,
	apiKey = "",
	maxConversationTurns = 10,
	rateLimitSeconds = 3,
	enableChatCommands = true,
	enableProximityPrompt = true,
	enableSpeechBubbles = true,
	fallbackOnError = true,
	customFallbackMessage = "I'm temporarily unable to speak. Please try again later.",
	npcName = "NPC",
}

-- Rate limiting state
local playerLastRequest = {}
local playerRequestCount = {}

-- Conversation history: { [player] = { {role="user", content="..."}, {role="assistant", content="..."} } }
local conversationHistory = {}

-- Callback registry
local onQuestionCallbacks = {}
local onGreetingCallbacks = {}

-- Utility: URL-encode a string
local function urlEncode(str)
	return tostring(str):gsub("([^%w%.%-_])", function(c)
		return string.format("%%%02X", string.byte(c))
	end)
end

-- Utility: check if API key is valid
local function hasValidKey(self)
	return self.config.apiKey and self.config.apiKey ~= "" and string.sub(self.config.apiKey, 1, 3) == "sk_"
end

-- Utility: get HTTP headers for authenticated requests
local function getHeaders(self)
	local headers = {
		["Content-Type"] = "application/json",
		["User-Agent"] = "roblox-pollinations-npc/2.0",
	}
	if hasValidKey(self) then
		headers["Authorization"] = "Bearer " .. self.config.apiKey
	end
	return headers
end

-- Utility: append key as query param (fallback auth)
local function appendKey(self, url)
	if self.config.apiKey and self.config.apiKey ~= "" then
		url = url .. "&key=" .. urlEncode(self.config.apiKey)
	end
	return url
end

-- Utility: check rate limit for a player
local function isRateLimited(player)
	local userId = player.UserId
	local now = tick()
	local lastTime = playerLastRequest[userId]
	if lastTime and (now - lastTime) < PollinationsNPC.DEFAULT_CONFIG.rateLimitSeconds then
		return true
	end
	playerLastRequest[userId] = now
	return false
end

-- Utility: get conversation history for a player
local function getHistory(player)
	local userId = player.UserId
	if not conversationHistory[userId] then
		conversationHistory[userId] = {}
	end
	return conversationHistory[userId]
end

-- Utility: add message to conversation history
local function addToHistory(player, role, content)
	local history = getHistory(player)
	table.insert(history, { role = role, content = content })
	-- Trim to max turns
	local maxTurns = PollinationsNPC.DEFAULT_CONFIG.maxConversationTurns
	while #history > maxTurns * 2 do
		table.remove(history, 1)
	end
end

-- Utility: clear conversation history for a player
local function clearHistory(player)
	conversationHistory[player.UserId] = nil
end

-- Utility: build messages array from history
local function buildMessages(self, player, newQuestion)
	local messages = {}
	-- Add system prompt
	table.insert(messages, { role = "system", content = self.config.systemPrompt })
	-- Add conversation history
	local history = getHistory(player)
	for _, msg in ipairs(history) do
		table.insert(messages, { role = msg.role, content = msg.content })
	end
	-- Add new question
	table.insert(messages, { role = "user", content = newQuestion })
	return messages
end

-- Utility: fire callbacks
local function fireCallbacks(callbacks, ...)
	for _, cb in ipairs(callbacks) do
		local success, err = pcall(cb, ...)
		if not success then
			warn("[PollinationsNPC] Callback error: " .. tostring(err))
		end
	end
end

-- Create a new NPC instance
function PollinationsNPC.new(config)
	config = config or {}
	local self = setmetatable({}, PollinationsNPC)
	self.config = {}
	for k, v in pairs(PollinationsNPC.DEFAULT_CONFIG) do
		self.config[k] = v
	end
	for k, v in pairs(config) do
		self.config[k] = v
	end

	-- Validate API key
	if not hasValidKey(self) then
		warn("[PollinationsNPC] No API key set. Set it via Roblox Secrets or pass directly. " ..
			"Get one at https://enter.pollinations.ai/keys")
	end

	-- Initialize per-instance state
	self._connections = {}
	self._promptConnections = {}
	self._billboardGui = nil
	self._proximityPrompt = nil
	self._chatConnection = nil

	return self
end

-- Fetch the list of available text models
function PollinationsNPC:GetTextModels()
	if not hasValidKey(self) then
		return nil, "No API key configured"
	end

	local success, result = pcall(function()
		return HttpService:GetAsync(TEXT_MODELS_URL, {
			headers = getHeaders(self),
		})
	end)

	if not success then
		return nil, "HTTP fetch failed: " .. tostring(result)
	end

	local decoded
	success, decoded = pcall(function()
		return HttpService:JSONDecode(result)
	end)

	if not success then
		return nil, "JSON decode failed: " .. tostring(decoded)
	end

	return decoded
end

-- Generate text from a prompt using the chat completions endpoint
function PollinationsNPC:GenerateText(prompt, model)
	model = model or self.config.model

	if not hasValidKey(self) then
		-- Fallback: use ?key= query parameter on text.pollinations.ai
		local fallbackUrl = FALLBACK_TEXT_URL .. urlEncode(prompt)
			.. "?model=" .. model
		fallbackUrl = appendKey(self, fallbackUrl)

		local success, result = pcall(function()
			return HttpService:GetAsync(fallbackUrl, {
				headers = {
					["User-Agent"] = "roblox-pollinations-npc/2.0",
				},
			})
		end)

		if success then
			return result
		else
			return nil, "Fallback text generation failed: " .. tostring(result)
		end
	end

	local payload = {
		model = model,
		messages = {
			{ role = "system", content = self.config.systemPrompt },
			{ role = "user", content = prompt },
		},
		max_tokens = self.config.maxTokens,
		temperature = self.config.temperature,
	}

	local jsonBody = HttpService:JSONEncode(payload)

	local success, result = pcall(function()
		return HttpService:PostAsync(
			CHAT_URL,
			jsonBody,
			Enum.HttpContentType.ApplicationJson,
			false,
			false,
			getHeaders(self)
		)
	end)

	if not success then
		return nil, "Chat generation failed: " .. tostring(result)
	end

	local decoded
	success, decoded = pcall(function()
		return HttpService:JSONDecode(result)
	end)

	if not success then
		return nil, "JSON decode failed: " .. tostring(decoded)
	end

	if decoded.error then
		return nil, "API error: " .. tostring(decoded.error.message)
	end

	if decoded.choices and #decoded.choices > 0 then
		return decoded.choices[1].message.content
	end

	return nil, "No content in response"
end

-- Generate text with conversation history (async via task.spawn)
function PollinationsNPC:GenerateTextAsync(player, question, callback)
	-- Check rate limit
	if isRateLimited(player) then
		if callback then
			task.spawn(callback, nil, "Rate limit exceeded. Please wait before asking again.")
		end
		return
	end

	-- Build messages with history
	local messages = buildMessages(self, player, question)

	-- Update history with user message
	addToHistory(player, "user", question)

	-- Make API call in a new thread
	task.spawn(function()
		local payload = {
			model = self.config.model,
			messages = messages,
			max_tokens = self.config.maxTokens,
			temperature = self.config.temperature,
		}

		local jsonBody = HttpService:JSONEncode(payload)

		local success, result = pcall(function()
			return HttpService:PostAsync(
				CHAT_URL,
				jsonBody,
				Enum.HttpContentType.ApplicationJson,
				false,
				false,
				getHeaders(self)
			)
		end)

		if not success then
			-- Fallback to text.pollinations.ai
			local fallbackUrl = FALLBACK_TEXT_URL .. urlEncode(question)
				.. "?model=" .. self.config.model
			fallbackUrl = appendKey(self, fallbackUrl)

			local fbSuccess, fbResult = pcall(function()
				return HttpService:GetAsync(fallbackUrl, {
					headers = { ["User-Agent"] = "roblox-pollinations-npc/2.0" },
				})
			end)

			if fbSuccess then
				addToHistory(player, "assistant", fbResult)
				if callback then
					callback(fbResult, nil)
				end
			else
				if callback then
					callback(nil, "API error: " .. tostring(result))
				end
			end
			return
		end

		local decoded
		success, decoded = pcall(function()
			return HttpService:JSONDecode(result)
		end)

		if not success then
			if callback then
				callback(nil, "JSON decode failed: " .. tostring(decoded))
			end
			return
		end

		if decoded.error then
			if callback then
				callback(nil, "API error: " .. tostring(decoded.error.message))
			end
			return
		end

		if decoded.choices and #decoded.choices > 0 then
			local reply = decoded.choices[1].message.content
			addToHistory(player, "assistant", reply)
			if callback then
				callback(reply, nil)
			end
		else
			if callback then
				callback(nil, "No content in response")
			end
		end
	end)
end

-- Ask the NPC a question and get a persona-appropriate reply (sync)
function PollinationsNPC:AskPlayer(question)
	local prompt = string.format(
		"A player in a Roblox game asks: '%s' — respond as %s. Keep it brief, natural, and in-character. Do not break character.",
		question,
		string.sub(self.config.systemPrompt, 1, 100)
	)

	local reply, err = self:GenerateText(prompt)
	if err then
		return self.config.customFallbackMessage, err
	end

	return reply
end

-- Ask the NPC a question (async with callback)
function PollinationsNPC:AskPlayerAsync(player, question, callback)
	self:GenerateTextAsync(player, question, callback)
end

-- Get a random greeting from the NPC
function PollinationsNPC:GetGreeting()
	local greetings = {
		"Hello, traveler!",
		"Greetings, adventurer!",
		"What brings you here?",
		"I've been expecting you...",
		"The winds carry your name.",
		"Welcome, friend!",
		"Ah, a new face!",
		"The stars foretold your arrival.",
	}
	return greetings[math.random(1, #greetings)]
end

-- Set the NPC's persona (system prompt)
function PollinationsNPC:SetPersona(persona)
	self.config.systemPrompt = persona
end

-- Get the NPC's current persona
function PollinationsNPC:GetPersona()
	return self.config.systemPrompt
end

-- Clear conversation history for a player
function PollinationsNPC:ClearHistory(player)
	clearHistory(player)
end

-- Get conversation history for a player
function PollinationsNPC:GetHistory(player)
	return getHistory(player)
end

-- Register a callback for when a player asks a question
function PollinationsNPC:OnPlayerQuestion(callback)
	table.insert(onQuestionCallbacks, callback)
end

-- Register a callback for when a player is greeted
function PollinationsNPC:OnPlayerGreeting(callback)
	table.insert(onGreetingCallbacks, callback)
end

-- Setup ProximityPrompt on an NPC model
function PollinationsNPC:SetupProximityPrompt(npcModel, promptText)
	if not npcModel or not npcModel:IsA("Model") then
		warn("[PollinationsNPC] SetupProximityPrompt: invalid model")
		return nil
	end

	-- Create or get ProximityPrompt
	local prompt = npcModel:FindFirstChild("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ProximityPrompt"
		prompt.ActionText = promptText or "Talk"
		prompt.ObjectText = self.config.npcName
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = npcModel.PrimaryPart or npcModel:FindFirstChildWhichIsA("BasePart")
	end

	self._proximityPrompt = prompt

	-- Handle prompt triggered
	local connection
	connection = prompt.Triggered:Connect(function(player)
		local greeting = self:GetGreeting()
		self:ShowSpeechBubble(player, greeting)
		fireCallbacks(onGreetingCallbacks, player, greeting)
	end)
	table.insert(self._promptConnections, connection)

	return prompt
end

-- Setup BillboardGui for speech bubbles
function PollinationsNPC:SetupBillboardGui(npcModel, bubbleText)
	if not npcModel or not npcModel:IsA("Model") then
		warn("[PollinationsNPC] SetupBillboardGui: invalid model")
		return nil
	end

	local head = npcModel:FindFirstChild("Head") or npcModel.PrimaryPart
	if not head then
		warn("[PollinationsNPC] SetupBillboardGui: no head or primary part found")
		return nil
	end

	-- Create BillboardGui
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "SpeechBubble"
	billboardGui.Size = UDim2.new(0, 200, 0, 100)
	billboardGui.StudsOffset = Vector3.new(0, 3, 0)
	billboardGui.AlwaysOnTop = true
	billboardGui.MaxDistance = 50
	billboardGui.Parent = head

	-- Create TextLabel
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "BubbleText"
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 0.3
	textLabel.BackgroundColor3 = Color3.new(1, 1, 1)
	textLabel.TextColor3 = Color3.new(0, 0, 0)
	textLabel.TextWrapped = true
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.Gotham
	textLabel.Text = bubbleText or "..."
	textLabel.Parent = billboardGui

	-- Create corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = textLabel

	self._billboardGui = billboardGui
	return billboardGui
end

-- Show a speech bubble for a player
function PollinationsNPC:ShowSpeechBubble(player, text, duration)
	if not self._billboardGui then
		return
	end

	local textLabel = self._billboardGui:FindFirstChild("BubbleText")
	if not textLabel then
		return
	end

	textLabel.Text = text

	-- Auto-hide after duration
	task.delay(duration or 5, function()
		if textLabel and textLabel.Parent then
			textLabel.Text = ""
		end
	end)
end

-- Setup chat command handler (@NPCName message)
function PollinationsNPC:SetupChatCommand(commandName)
	commandName = commandName or self.config.npcName
	local npcNameLower = string.lower(commandName)

	local connection
	connection = Players.PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(message)
			local msgLower = string.lower(message)
			local prefix = "@" .. npcNameLower

			if string.sub(msgLower, 1, #prefix) == prefix then
				local question = string.sub(message, #prefix + 1)
				question = question:gsub("^%s+", "") -- trim leading whitespace

				if question ~= "" then
					-- Show "typing" indicator
					self:ShowSpeechBubble(player, "...")

					-- Generate response async
					self:GenerateTextAsync(player, question, function(reply, err)
						if err then
							self:ShowSpeechBubble(player, self.config.customFallbackMessage)
							warn("[PollinationsNPC] Chat command error for " .. player.Name .. ": " .. tostring(err))
						else
							self:ShowSpeechBubble(player, reply)
							fireCallbacks(onQuestionCallbacks, player, question, reply)
						end
					end)
				end
			end
		end)
	end)

	table.insert(self._connections, connection)
	return connection
end

-- Setup player join/leave events
function PollinationsNPC:SetupPlayerEvents()
	-- Player joined
	local joinConnection
	joinConnection = Players.PlayerAdded:Connect(function(player)
		local greeting = self:GetGreeting()
		print("[PollinationsNPC] " .. player.Name .. " joined. Greeting: " .. greeting)
		fireCallbacks(onGreetingCallbacks, player, greeting)
	end)
	table.insert(self._connections, joinConnection)

	-- Player leaving
	local leaveConnection
	leaveConnection = Players.PlayerRemoving:Connect(function(player)
		clearHistory(player)
		playerLastRequest[player.UserId] = nil
		playerRequestCount[player.UserId] = nil
		print("[PollinationsNPC] " .. player.Name .. " left. History cleared.")
	end)
	table.insert(self._connections, leaveConnection)
end

-- Cleanup all connections and instances
function PollinationsNPC:Destroy()
	-- Disconnect all connections
	for _, conn in ipairs(self._connections) do
		if conn then
			conn:Disconnect()
		end
	end
	for _, conn in ipairs(self._promptConnections) do
		if conn then
			conn:Disconnect()
		end
	end

	-- Clear tables
	self._connections = {}
	self._promptConnections = {}

	-- Remove instances
	if self._billboardGui then
		self._billboardGui:Destroy()
		self._billboardGui = nil
	end
	if self._proximityPrompt then
		self._proximityPrompt:Destroy()
		self._proximityPrompt = nil
	end

	-- Clear global callbacks
	onQuestionCallbacks = {}
	onGreetingCallbacks = {}
end

-- Get current configuration
function PollinationsNPC:GetConfig()
	return self.config
end

-- Update configuration
function PollinationsNPC:UpdateConfig(newConfig)
	for k, v in pairs(newConfig) do
		self.config[k] = v
	end
end

return PollinationsNPC
