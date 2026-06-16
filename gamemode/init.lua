-- Server-side gamemode init: load shared/client files and register server hooks.
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

-- Load dungeon generation (server-only).
local DungeonGenerate = "DungeonGenerate/"
include(DungeonGenerate .. "init.lua")

-- Load inventory system (server + client).
local DungeonGenerate = "Inventory/"
AddCSLuaFile(DungeonGenerate .. "cl_init.lua")
include(DungeonGenerate .. "init.lua")

-- Load scoreboard (shared).
local DungeonGenerate = "scoreboard/"
include(DungeonGenerate .. "shared.lua")
AddCSLuaFile(DungeonGenerate .. "shared.lua")

-- Send all custom sounds and materials to connecting clients.
for k, v in pairs(file.Find("sound/darkdrift/" .. "*", "GAME")) do
    resource.AddFile("sound/darkdrift/" .. v)
end
for k, v in pairs(file.Find("materials/darkdrift/" .. "*", "GAME")) do
    resource.AddFile("materials/darkdrift/" .. v)
end

-- Enable custom per-entity collision checks (needed for prop/ragdoll filtering).
hook.Add("PlayerInitialSpawn", "SetCustomCollisions", function(ply)
    ply:SetCustomCollisionCheck(true)
end)

-- Reset player appearance and stats every time they (re)spawn.
hook.Add("PlayerSpawn", "SetCustomCollisions", function(ply)
    ply:SetModel("models/player/breen.mdl")
    ply:SetFrags(0)
    ply:SetRunSpeed(900)
end)

-- On player death: award a frag to the killer and spawn a ragdoll prop.
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
    ent.Ragdoll = true  -- flag used by ShouldCollide in shared.lua

    -- Remove the engine-created ragdoll so we don't get two bodies.
    local death_Rag = IsValid(victim) and victim.GetRagdollEntity and victim:GetRagdollEntity()
    if IsValid(death_Rag) then death_Rag:Remove() end
end)

-- On NPC death: spawn a ragdoll at its position, then remove the NPC entity.
hook.Add("OnNPCKilled", "DarkDriftNPCDeath", function(npc, attacker, inflictor)
    if not IsValid(npc) then return end

    local ent = ents.Create("prop_ragdoll")
    if not IsValid(ent) then return end
    ent:SetPos(npc:GetPos())
    ent:SetModel(npc:GetModel())
    ent:Spawn()
    ent:Activate()
    ent.Ragdoll = true  -- flag used by ShouldCollide in shared.lua

    npc:Remove()
end)

-- Prevent players from using noclip.
hook.Add("PlayerNoClip", "NoNoClip", function(ply) return false end)
