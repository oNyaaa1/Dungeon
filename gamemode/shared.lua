DeriveGamemode("base")
GM.Name = "The Dark Drift"
Dungeon = Dungeon or {}
hook.Add("ShouldCollide", "DungeonPropCollide", function(ent1, ent2)
    if not IsValid(ent1) or not IsValid(ent2) then return end
    -- Nextbots should not collide with dungeon props
    -- Ragdolls should not collide with dungeon props
    if (ent1.IsProp and ent2.Ragdoll) or (ent2.IsProp and ent1.Ragdoll) then return false end
end)

