AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")
local DungeonGenerate = "DungeonGenerate/"
include(DungeonGenerate .. "init.lua")
local DungeonGenerate = "Inventory/"
include(DungeonGenerate .. "init.lua")
AddCSLuaFile(DungeonGenerate .. "cl_init.lua")