--[[
	ExampleNPCScript.lua
	Complete example usage of PollinationsNPC in a Roblox game.
	Place in: ServerScriptService → ExampleNPCScript

	This script creates a talking NPC that responds to:
	- ProximityPrompt interaction
	- Chat commands (@Wizard message)
	- Player join events

	Configuration is done via ModuleScript attributes or the config table below.
]]

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Load the module
local PollinationsNPC = require(script.Parent.Modules.PollinationsNPC)

-- Configuration
local CONFIG = {
	model = "openai/gpt-5.4-nano",
	systemPrompt = "You are a wise old wizard who speaks in cryptic but helpful riddles. You live in a magical forest and guide adventurers on their quests.",
	temperature = 0.8,
	maxTokens = 256,
	rateLimitSeconds = 3,
	maxConversationTurns = 10,
	npcName = "Wizard",
	enableChatCommands = true,
	enableProximityPrompt = true,
	enableSpeechBubbles = true,
}

-- Get API key from Roblox Secrets
local function getApiKey()
	local success, key = pcall(function()
		return ServerStorage:GetSecret("POLLINATIONS_API_KEY")
	end)
	if success and key then
		return key
	end
	warn("[ExampleNPCScript] No API key found in Roblox Secrets. Using fallback auth.")
	return ""
end

-- Create the NPC instance
local npc = PollinationsNPC.new({
	model = CONFIG.model,
	systemPrompt = CONFIG.systemPrompt,
	temperature = CONFIG.temperature,
	maxTokens = CONFIG.maxTokens,
	apiKey = getApiKey(),
	rateLimitSeconds = CONFIG.rateLimitSeconds,
	maxConversationTurns = CONFIG.maxConversationTurns,
	npcName = CONFIG.npcName,
	enableChatCommands = CONFIG.enableChatCommands,
	enableProximityPrompt = CONFIG.enableProximityPrompt,
	enableSpeechBubbles = CONFIG.enableSpeechBubbles,
})

-- Find or create the NPC model in workspace
local function getOrCreateNPCModel()
	local npcModel = workspace:FindFirstChild("WizardNPC")
	if npcModel then
		return npcModel
	end

	-- Create a simple NPC model
	npcModel = Instance.new("Model")
	npcModel.Name = "WizardNPC"

	-- Create torso
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Position = Vector3.new(0, 3, 0)
	torso.Anchored = true
	torso.BrickColor = BrickColor.new("Bright blue")
	torso.Parent = npcModel

	-- Create head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1, 1, 1)
	head.Position = Vector3.new(0, 4.5, 0)
	head.Anchored = true
	head.BrickColor = BrickColor.new("Bright yellow")
	head.Parent = npcModel

	-- Create humanoid
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = npcModel

	npcModel.PrimaryPart = torso
	npcModel.Parent = workspace

	return npcModel
end

-- Setup the NPC
local function setupNPC()
	local npcModel = getOrCreateNPCModel()

	-- Setup ProximityPrompt
	if CONFIG.enableProximityPrompt then
		npc:SetupProximityPrompt(npcModel, "Talk to Wizard")
		print("[ExampleNPCScript] ProximityPrompt setup complete")
	end

	-- Setup BillboardGui for speech bubbles
	if CONFIG.enableSpeechBubbles then
		npc:SetupBillboardGui(npcModel, "Greetings, traveler!")
		print("[ExampleNPCScript] BillboardGui setup complete")
	end

	-- Setup chat commands
	if CONFIG.enableChatCommands then
		npc:SetupChatCommand(CONFIG.npcName)
		print("[ExampleNPCScript] Chat command @" .. CONFIG.npcName .. " setup complete")
	end

	-- Setup player events
	npc:SetupPlayerEvents()
	print("[ExampleNPCScript] Player events setup complete")

	-- Register callbacks
	npc:OnPlayerQuestion(function(player, question, reply)
		print(string.format("[ExampleNPCScript] %s asked: %s", player.Name, question))
		print(string.format("[ExampleNPCScript] Wizard replied: %s", reply))
	end)

	npc:OnPlayerGreeting(function(player, greeting)
		print(string.format("[ExampleNPCScript] Greeting to %s: %s", player.Name, greeting))
	end)
end

-- Run setup
local success, err = pcall(setupNPC)
if not success then
	warn("[ExampleNPCScript] Setup failed: " .. tostring(err))
end

-- Export for other scripts
return {
	npc = npc,
	config = CONFIG,
}
