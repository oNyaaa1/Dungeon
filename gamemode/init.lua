AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")
local DungeonGenerate = "DungeonGenerate/"
include(DungeonGenerate .. "init.lua")
local DungeonGenerate = "Inventory/"
include(DungeonGenerate .. "init.lua")
AddCSLuaFile(DungeonGenerate .. "cl_init.lua")
for k, v in pairs(file.Find("sound/darkdrift/" .. "*", "GAME")) do
    resource.AddFile("sound/darkdrift/" .. v)
end

hook.Add("PlayerInitialSpawn", "SetCustomCollisions", function(ply) ply:SetCustomCollisionCheck(true) end)
hook.Add("PlayerSpawn", "SetCustomCollisions", function(ply)
    ply:SetModel("models/player/breen.mdl")
    //ply:Give("confetti_gun")
    ply:SetFrags(0)
end)

hook.Add("PlayerDeath", "DarkDriftPlayerDeath", function(victim, inflictor, attacker)
    if IsValid(attacker) then attacker:SetFrags(attacker:Frags() + 1) end
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
