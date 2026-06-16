-- Shared: runs on both server and client.
DeriveGamemode("base")
GM.Name = "The Dark Drift"

-- Pre-declare the global table so server and client both have it before hooks fire.
Dungeon = Dungeon or {}

-- Suppress collisions between dungeon floor/wall props and ragdolls so bodies
-- don't get stuck inside the geometry.
hook.Add("ShouldCollide", "DungeonPropCollide", function(ent1, ent2)
    if not IsValid(ent1) or not IsValid(ent2) then return end
    -- IsProp is set on all dungeon prop_physics plates; Ragdoll is set on death ragdolls.
    if (ent1.IsProp and ent2.Ragdoll) or (ent2.IsProp and ent1.Ragdoll) then return false end
end)
