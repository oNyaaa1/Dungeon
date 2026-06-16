-- Client-side gamemode init: load shared logic and client-side subsystems.
include("shared.lua")

-- Load client-side inventory UI.
local DungeonGenerate = "Inventory/"
include(DungeonGenerate .. "cl_init.lua")

-- Load scoreboard (shared file, included on both sides).
local DungeonGenerate = "scoreboard/"
include(DungeonGenerate .. "shared.lua")
