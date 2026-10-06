# Changelog

## [2.0.0] — 2026-10-06

### Added
- Full conversation history per player with configurable max turns
- Async API calls via `task.spawn` (non-blocking)
- ProximityPrompt support for NPC interaction
- BillboardGui for speech bubbles
- Chat command support (`@NPCName message`)
- Rate limiting per player
- Graceful degradation on API errors with fallback
- Roblox Secrets integration for API key
- Fallback to query-param auth when no key
- Player join/leave event handling
- Callback system for questions and greetings
- Complete example script with all features
- Professional documentation with API reference
- Landing page with live API evidence

### Changed
- Complete rewrite of core module for production readiness
- Improved error handling with pcall everywhere
- Better configuration system with defaults
- Enhanced developer experience with clear API

### Fixed
- URL encoding for fallback auth
- Conversation history trimming
- Rate limit tracking per player

## [1.0.0] — 2026-09-28

### Added
- PollinationsNPC.lua Luau module for NPC dialogue via Pollinations API
- ExampleNPCScript.lua drop-in demo with wizard persona
- README with install steps and Roblox Secrets configuration guide
