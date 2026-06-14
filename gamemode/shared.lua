DeriveGamemode("sandbox")
GM.Name = "The Dark Drift"
Dungeon = Dungeon or {}
hook.Add("PlayerInitialSpawn", "SetCustomCollisions", function(ply) ply:SetCustomCollisionCheck(true) end)
hook.Add("DoPlayerDeath", "DarkDriftPlayerDeath", function(victim, inflictor, attacker)
    if not IsValid(victim) then return end
    local ent = ents.Create("prop_ragdoll")
    if not IsValid(ent) then return end
    ent:SetPos(victim:GetPos())
    ent:SetModel(victim:GetModel())
    ent:Spawn()
    ent:Activate()
    ent.Ragdoll = true
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

hook.Add("ShouldCollide", "DungeonPropCollide", function(ent1, ent2)
    if not IsValid(ent1) or not IsValid(ent2) then return end
    -- Nextbots should not collide with dungeon props
    -- Ragdolls should not collide with dungeon props
    if (ent1.IsProp and ent2.Ragdoll) or (ent2.IsProp and ent1.Ragdoll) then return false end
end)