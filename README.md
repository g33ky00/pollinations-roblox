# Pollinations Roblox NPC

[![Quest](https://img.shields.io/badge/Quest-%2315583-blue)](https://github.com/pollinations/pollinations/issues/15583)
[![Roblox](https://img.shields.io/badge/Roblox-Luau-00ff00)](https://create.roblox.com/)
[![Version](https://img.shields.io/badge/Version-2.0.0-green)](CHANGELOG.md)

Production-ready Luau module that gives your NPCs conversations powered by Pollinations AI text models. Players type in chat, NPCs reply with AI-generated dialogue in-character.

## Features

- **Async text generation** via `gen.pollinations.ai/v1/chat/completions` (Bearer) or `text.pollinations.ai/{prompt}` (key=)
- **Conversation history** — NPCs remember context per player (configurable max turns)
- **Persona system** — set a system prompt, NPCs stay in character
- **Multiple model support** — any text model from `gen.pollinations.ai/text/models`
- **Secret-based auth** — uses Roblox's `ServerStorage:GetSecret()` for API keys
- **Fallback auth** — works without a key via `?key=` query parameter
- **ProximityPrompt** — players click to interact with NPCs
- **BillboardGui speech bubbles** — visual feedback for NPC dialogue
- **Chat commands** — `@NPCName message` to talk to NPCs
- **Rate limiting** — per-player request throttling
- **Graceful degradation** — fallback messages on API errors
- **Complete example** — drop-in demo with wizard persona

## Installation

### 1. Import the module

1. Download this repository
2. In Roblox Studio, open **View → Explorer**
3. Copy `src/PollinationsNPC.lua` to `ServerScriptService → Modules → PollinationsNPC`

### 2. Set up your API key (recommended)

In **Creator Dashboard → Games → Your Game → Configure Game → Secrets**:
1. Add a new secret: `Key Name = POLLINATIONS_API_KEY`, `Value = sk_...`
2. In your script: `game:GetService("ServerStorage"):GetSecret("POLLINATIONS_API_KEY")`

### 3. Add the example NPC

1. Copy `src/ExampleNPCScript.lua` to `ServerScriptService`
2. The example NPC uses a wizard persona

### 4. Enable HTTP Service

1. In Roblox Studio: **Home → Game Settings → Security**
2. Enable **Enable Studio Access to API Services** (for testing)
3. On publish: enable **HTTP Requests** in game config

## Quick Start

```lua
local PollinationsNPC = require(game.ServerScriptService.Modules.PollinationsNPC)

local npc = PollinationsNPC.new({
    model = "openai/gpt-5.4-nano",
    systemPrompt = "You are a pirate captain who speaks in pirate slang.",
    apiKey = game:GetService("ServerStorage"):GetSecret("POLLINATIONS_API_KEY") or "",
    temperature = 0.8,
})

-- Setup interaction methods
npc:SetupProximityPrompt(workspace.NPCModel)
npc:SetupChatCommand("Wizard")
npc:SetupPlayerEvents()

-- Register callbacks
npc:OnPlayerQuestion(function(player, question, reply)
    print(player.Name .. " asked: " .. question)
    print("NPC replied: " .. reply)
end)
```

## API Reference

### Constructor

| Method | Description |
|---|---|
| `PollinationsNPC.new(config)` | Create a new NPC instance |

### Core Methods

| Method | Description |
|---|---|
| `npc:GenerateText(prompt, model?)` | Generate text from prompt (sync) |
| `npc:GenerateTextAsync(player, question, callback)` | Generate text with history (async) |
| `npc:AskPlayer(question)` | Ask NPC a question, get persona reply (sync) |
| `npc:AskPlayerAsync(player, question, callback)` | Ask NPC a question (async) |
| `npc:GetGreeting()` | Get a random NPC greeting |
| `npc:SetPersona(prompt)` | Change the NPC's system prompt |
| `npc:GetPersona()` | Get the NPC's current persona |
| `npc:GetTextModels()` | Fetch available text models |

### Interaction Setup

| Method | Description |
|---|---|
| `npc:SetupProximityPrompt(model, promptText?)` | Setup ProximityPrompt on NPC model |
| `npc:SetupBillboardGui(model, bubbleText?)` | Setup speech bubble BillboardGui |
| `npc:SetupChatCommand(commandName?)` | Setup chat command handler |
| `npc:SetupPlayerEvents()` | Setup player join/leave events |
| `npc:ShowSpeechBubble(player, text, duration?)` | Show speech bubble for player |

### Callbacks

| Method | Description |
|---|---|
| `npc:OnPlayerQuestion(callback)` | Register callback for player questions |
| `npc:OnPlayerGreeting(callback)` | Register callback for player greetings |

### Utility

| Method | Description |
|---|---|
| `npc:ClearHistory(player)` | Clear conversation history for a player |
| `npc:GetHistory(player)` | Get conversation history for a player |
| `npc:GetConfig()` | Get current configuration |
| `npc:UpdateConfig(newConfig)` | Update configuration |
| `npc:Destroy()` | Cleanup all connections and instances |

## Configuration Options

| Field | Default | Description |
|---|---|---|
| `model` | `openai/gpt-5.4-nano` | Pollinations text model |
| `systemPrompt` | `"You are a helpful NPC..."` | NPC persona |
| `temperature` | `0.7` | Creativity (0.0–1.0) |
| `maxTokens` | `256` | Max response length |
| `apiKey` | `""` | API key (from Secrets or direct) |
| `maxConversationTurns` | `10` | Max conversation history turns |
| `rateLimitSeconds` | `3` | Per-player rate limit cooldown |
| `enableChatCommands` | `true` | Enable chat command handler |
| `enableProximityPrompt` | `true` | Enable ProximityPrompt |
| `enableSpeechBubbles` | `true` | Enable speech bubbles |
| `fallbackOnError` | `true` | Use fallback on API errors |
| `customFallbackMessage` | `"I'm temporarily unable to speak..."` | Fallback message |
| `npcName` | `"NPC"` | NPC name for chat commands |

## Roblox Secrets Setup

1. Go to [Creator Dashboard](https://create.roblox.com/dashboard)
2. Select your game
3. Navigate to **Configure Game → Secrets**
4. Click **Add Secret**
5. Set **Key Name** to `POLLINATIONS_API_KEY`
6. Set **Value** to your Pollinations API key (starts with `sk_`)
7. Click **Save**

In your script:
```lua
local apiKey = game:GetService("ServerStorage"):GetSecret("POLLINATIONS_API_KEY")
```

## Example Place Guide

1. Open Roblox Studio
2. Create a new Baseplate project
3. Insert a **Script** into `ServerScriptService`
4. Copy the contents of `ExampleNPCScript.lua` into it
5. Insert a **ModuleScript** into `ServerScriptService` named `PollinationsNPC`
6. Copy the contents of `PollinationsNPC.lua` into it
7. Press **Play** to test
8. Walk up to the Wizard NPC and click the ProximityPrompt
9. Type `@Wizard What is the meaning of life?` in chat

## FAQ

### Do I need a Pollinations API key?

No, but it's recommended. Without a key, the module uses `text.pollinations.ai` with query-param auth, which has rate limits. With a key, you get higher limits and access to more models.

### How do I change the NPC's personality?

Use `npc:SetPersona("Your new system prompt")` or set `systemPrompt` in the config.

### How do I limit API costs?

Set `rateLimitSeconds` to a higher value, reduce `maxTokens`, or use a cheaper model.

### Can I use multiple NPCs?

Yes! Create multiple instances with different configs:
```lua
local wizard = PollinationsNPC.new({ npcName = "Wizard", systemPrompt = "You are a wizard" })
local pirate = PollinationsNPC.new({ npcName = "Pirate", systemPrompt = "You are a pirate" })
```

### How do I handle API errors?

The module has built-in fallback handling. Set `customFallbackMessage` to customize the error message players see.

## License

MIT — see [CHANGELOG.md](CHANGELOG.md).

## Quest

This module fulfills [Quest #15583](https://github.com/pollinations/pollinations/issues/15583) — _[QUEST] Pollinations NPC dialogue for Roblox_
