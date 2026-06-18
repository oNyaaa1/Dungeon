AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")
local DungeonGenerate = "dungeongen/"
include(DungeonGenerate .. "init.lua")
local DungeonGenerate = "ninventory/"
AddCSLuaFile(DungeonGenerate .. "cl_init.lua")
include(DungeonGenerate .. "init.lua")
AddCSLuaFile(DungeonGenerate .. "threegrid.lua")
local DungeonGenerate = "scoreboard/"
include(DungeonGenerate .. "shared.lua")
AddCSLuaFile(DungeonGenerate .. "shared.lua")
local DungeonGenerate = "hud/"
AddCSLuaFile(DungeonGenerate .. "cl_init.lua")
include(DungeonGenerate .. "init.lua")
for k, v in pairs(file.Find("sound/darkdrift/" .. "*", "GAME")) do
    resource.AddFile("sound/darkdrift/" .. v)
end

for k, v in pairs(file.Find("materials/darkdrift/" .. "*", "GAME")) do
    resource.AddFile("materials/darkdrift/" .. v)
end

hook.Add("PlayerInitialSpawn", "SetCustomCollisions", function(ply) ply:SetCustomCollisionCheck(true) end)
hook.Add("PlayerSpawn", "SetCustomCollisions", function(ply)
    if IsValid(ply) then
        ply:SetModel("models/player/breen.mdl")
        ply:SetFrags(0)
        ply:SetRunSpeed(900)
    end
end)

hook.Add("PlayerDeath", "DarkDriftPlayerDeath", function(victim, inflictor, attacker)
    local ply = attacker
    if IsValid(ply) then ply:SetFrags(ply:Frags() + 1) end
    if not IsValid(victim) then return end
    local ent = ents.Create("prop_ragdoll")
    if not IsValid(ent) then return end
    ent:SetPos(victim:GetPos())
    ent:SetModel(victim:GetModel())
    ent:Spawn()
    ent:Activate()
    ent.Ragdoll = true
    local death_Rag = IsValid(victim) and victim.GetRagdollEntity and victim:GetRagdollEntity()
    if IsValid(death_Rag) then death_Rag:Remove() end
end)

hook.Add("OnNPCKilled", "DarkDriftNPCDeath", function(npc, attacker, inflictor)
    if not IsValid(npc) then return end
    local ent = ents.Create("prop_ragdoll")
    if not IsValid(ent) then return end
    ent:SetPos(npc:GetPos())
    ent:SetModel(npc:GetModel())
    ent:Spawn()
    ent:Activate()
    ent.Ragdoll = true
    npc:Remove()
end)

hook.Add("PlayerNoClip", "NoNoClip", function(ply) return false end)