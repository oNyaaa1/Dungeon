include("shared.lua")
local DungeonGenerate = "inventory/"
include(DungeonGenerate .. "cl_init.lua")
include(DungeonGenerate .. "threegrid.lua")
local DungeonGenerate = "scoreboard/"
include(DungeonGenerate .. "shared.lua")
local DungeonGenerate = "hud/"
include(DungeonGenerate .. "cl_init.lua")
local DontDraw = {
    ["CHudHealth"] = true,
    ["CHudWeaponSelection"] = true,
    ["CHudBattery"] = true,
}

function GM:HUDShouldDraw(name)
    return not DontDraw[name]
end