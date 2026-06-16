print("Dungeon Loaded")

-- ── Config ────────────────────────────────────────────────────────────────────
-- All tunable values live here so nothing is hardcoded deeper in the file.
local CFG = {
    TileSize    = 120,   -- world-units per dungeon tile (floor plate width)
    TraceAbove  = 512,   -- how far above/below to trace when finding ground Z
    NumRooms    = 12,    -- number of rooms to attempt to place
    RoomMin     = 5,     -- minimum room side length (in tiles)
    RoomMax     = 10,    -- maximum room side length (in tiles)
    MapW        = 60,    -- dungeon grid width (tiles)
    MapH        = 60,    -- dungeon grid height (tiles)
    MaxPlayers  = 32,    -- server capacity enforced in CheckPassword
    WallH       = 240,   -- wall height in world-units
    PlateSize   = 120,   -- height of one stacked wall plate
    WallOffset  = 60,    -- how far from the tile center to push wall plates

    -- NPC classes to spawn; weight controls relative frequency.
    -- nextbot = true means the entity is a NextBot (needs a navmesh).
    NPCTypes = {
        {
            class   = "npc_evil_ass_skeleton",
            weight  = 100,
            nextbot = true
        },
    },

    -- How many NPCs appear inside each room.
    NPCPerRoom = {
        min = 2,
        max = 5
    },

    NPCRespawn     = true,  -- respawn all NPCs after the wave is cleared
    NPCRespawnTime = 30,    -- seconds before a new wave spawns

    -- How many traps appear inside each room.
    TrapsPerRoom = {
        min = 1,
        max = 5
    },

    TrapCooldown = 2,   -- seconds a trap must wait before it can trigger again
    TrapDamage   = 10,  -- base damage dealt by damage traps
}

-- Model used for every floor, wall, and roof plate.
local PLATE_MODEL = "models/props_phx/construct/metal_plate4x4.mdl"

-- ── Global State ─────────────────────────────────────────────────────────────
-- Persists across calls so late-joining players still get valid data.
Dungeon            = Dungeon or {}
Dungeon.Entities   = Dungeon.Entities   or {}  -- all prop_physics plates
Dungeon.NPCs       = Dungeon.NPCs       or {}  -- all live NPC handles
Dungeon.Traps      = Dungeon.Traps      or {}  -- trap data tables
Dungeon.SpawnPos   = Dungeon.SpawnPos   or {}  -- player spawn positions
Dungeon.LastRooms  = Dungeon.LastRooms  or {}  -- room list from last generate
Dungeon.Origin     = Dungeon.Origin     or Vector(0, 0, 0)
Dungeon._spawnIdx  = 0                          -- round-robin spawn counter
Dungeon.LootBoxes  = Dungeon.LootBoxes  or {}  -- spawned loot box entities

-- ── Helpers ──────────────────────────────────────────────────────────────────

-- Returns true if rooms a and b overlap (with a 1-tile padding so rooms don't touch).
local function overlaps(a, b)
    return not (a.x + a.w + 1 <= b.x or b.x + b.w + 1 <= a.x or a.y + a.h + 1 <= b.y or b.y + b.h + 1 <= a.y)
end

-- Returns the integer center tile coordinates of a room.
local function center(room)
    return math.floor(room.x + room.w * 0.5), math.floor(room.y + room.h * 0.5)
end

-- Freezes a physics entity in place so dungeon props don't fall or slide.
local function freeze(ent)
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end
end

-- Traces down from above a position to find the actual ground Z coordinate.
-- Falls back to the original Z if nothing is hit.
local function groundZ(pos)
    local tr = util.TraceLine({
        start  = pos + Vector(0, 0, CFG.TraceAbove),
        endpos = pos - Vector(0, 0, CFG.TraceAbove),
        mask   = MASK_SOLID_BRUSHONLY,
    })
    return tr.Hit and tr.HitPos.z or pos.z
end

-- Picks a random item from a weighted list.
local function weightedRandom(items)
    local total = 0
    for _, v in ipairs(items) do total = total + v.weight end

    local r   = math.random(1, total)
    local acc = 0
    for _, v in ipairs(items) do
        acc = acc + v.weight
        if r <= acc then return v end
    end
    return items[#items]
end

-- Spawns a frozen prop_physics plate, registers it in Dungeon.Entities, and returns it.
local function spawnProp(pos, ang)
    local ent = ents.Create("prop_physics")
    if not IsValid(ent) then return nil end
    ent:SetModel(PLATE_MODEL)
    ent:SetPos(pos)
    ent:SetAngles(ang)
    ent:Spawn()
    ent:Activate()
    ent:DrawShadow(false)
    freeze(ent)
    ent.IsProp = true  -- used by ShouldCollide to skip prop/ragdoll collisions
    table.insert(Dungeon.Entities, ent)
    return ent
end

-- ── Trap Types ───────────────────────────────────────────────────────────────
-- Each entry defines a trap variant. Damage traps hurt players; heal traps restore health.
local TRAP_TYPES = {
    { name = "spike",     color = Color(180,  40,  40), damage = CFG.TrapDamage          },
    { name = "fire",      color = Color(220, 120,  20), damage = CFG.TrapDamage * 0.5    },
    { name = "explosive", color = Color(200,  60,   0), damage = CFG.TrapDamage * 1.2    },
    { name = "health",    color = Color( 40, 200,  40), heal   = 25                       },
}

-- ── Trap Spawning ────────────────────────────────────────────────────────────

-- Places a single trap plate at the given tile coordinates.
-- forcedType keeps a relocating plate as the same trap variant.
local function spawnTrap(origin, tileX, tileY, forcedType)
    local trapType = forcedType or TRAP_TYPES[math.random(1, #TRAP_TYPES)]
    local wx = origin.x + tileX * CFG.TileSize
    local wy = origin.y + tileY * CFG.TileSize
    local gz = groundZ(Vector(wx, wy, origin.z))

    -- Floor plate looks like a normal tile until stepped on.
    local plate = spawnProp(Vector(wx, wy, gz), Angle(0, 0, 0))
    if not IsValid(plate) then return nil end

    -- Health traps are visibly green so players can spot them.
    if trapType.heal then
        plate:SetColor(trapType.color)
    end

    local trapData = {
        pos         = Vector(wx, wy, gz),
        type        = trapType.name,
        typeData    = trapType,
        damage      = trapType.damage,
        heal        = trapType.heal,
        color       = trapType.color,
        lastTriggered = 0,   -- CurTime() of last activation
        plate       = plate,
        tileX       = tileX,
        tileY       = tileY,
    }

    table.insert(Dungeon.Traps, trapData)
    return trapData
end

-- Fills a room with a random number of traps, avoiding the outer edge tiles.
local function spawnTrapsForRoom(origin, room)
    local numTraps = math.random(CFG.TrapsPerRoom.min, CFG.TrapsPerRoom.max)
    for _ = 1, numTraps do
        local tx = math.random(room.x + 2, room.x + room.w - 3)
        local ty = math.random(room.y + 2, room.y + room.h - 3)
        spawnTrap(origin, tx, ty)
    end
end

-- Clears old traps and re-populates every room except the spawn room (index 1).
function Dungeon.SpawnAllTraps(origin)
    Dungeon.Traps = {}
    for i = 2, #Dungeon.LastRooms do
        spawnTrapsForRoom(origin, Dungeon.LastRooms[i])
    end
    print(string.format("Dungeon: %d traps spawned.", #Dungeon.Traps))
end

-- ── Loot Boxes ───────────────────────────────────────────────────────────────
local LOOT_BOXES_PER_ROOM = { min = 1, max = 2 }

-- Builds a loot table for a box (currently only the confetti gun).
local function buildLootTable()
    return {
        { weapon = "confetti_gun", weight = 100 },
    }
end

-- Spawns a loot box entity at the given tile and registers it.
local function spawnBox(origin, tileX, tileY)
    local wx = origin.x + tileX * CFG.TileSize
    local wy = origin.y + tileY * CFG.TileSize
    local gz = groundZ(Vector(wx, wy, origin.z))

    local ent = ents.Create("box")
    if not IsValid(ent) then return nil end
    ent:SetPos(Vector(wx, wy, gz + 5))
    ent:Spawn()
    ent:Activate()

    table.insert(Dungeon.LootBoxes, ent)
    return ent
end

-- Fills a room with a random number of loot boxes.
local function spawnBoxesForRoom(origin, room)
    local numBoxes = math.random(LOOT_BOXES_PER_ROOM.min, LOOT_BOXES_PER_ROOM.max)
    for _ = 1, numBoxes do
        local tx = math.random(room.x + 1, room.x + room.w - 2)
        local ty = math.random(room.y + 1, room.y + room.h - 2)
        spawnBox(origin, tx, ty)
    end
end

-- Removes existing loot boxes and re-spawns them in every non-spawn room.
function Dungeon.SpawnAllLootBoxes(origin)
    for _, box in ipairs(Dungeon.LootBoxes) do
        if IsValid(box) then box:Remove() end
    end
    Dungeon.LootBoxes = {}

    for i = 2, #Dungeon.LastRooms do
        spawnBoxesForRoom(origin, Dungeon.LastRooms[i])
    end
    print(string.format("Dungeon: %d loot boxes spawned.", #Dungeon.LootBoxes))
end

-- ── Trap Relocation ──────────────────────────────────────────────────────────

-- Returns a random interior tile in a random non-spawn room, or nil if impossible.
local function randomTrapTile()
    if #Dungeon.LastRooms < 2 then return nil end
    local room = Dungeon.LastRooms[math.random(2, #Dungeon.LastRooms)]
    local tx = math.random(room.x + 2, room.x + room.w - 3)
    local ty = math.random(room.y + 2, room.y + room.h - 3)
    return tx, ty
end

-- Removes a trap's plate entity and drops it from the trap list.
local function removeTrap(trap)
    if trap.plate and IsValid(trap.plate) then
        trap.plate:Remove()
        table.RemoveByValue(Dungeon.Entities, trap.plate)
    end
    table.RemoveByValue(Dungeon.Traps, trap)
end

-- Destroys a trap and re-spawns it as the same type at a new random tile.
local function relocateTrap(trap)
    local keepType = trap.typeData
    removeTrap(trap)
    local tx, ty = randomTrapTile()
    if not tx then return end
    spawnTrap(Dungeon.Origin, tx, ty, keepType)
end

-- ── Trap Trigger (proximity-based) ───────────────────────────────────────────
local TRAP_TRIGGER_RADIUS = 48  -- units; player must be this close to trigger

-- Checks all players against all traps every 0.3 s.
timer.Create("DungeonTrapThink", 0.3, 0, function()
    if #Dungeon.Traps == 0 then return end
    local curTime = CurTime()
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or ply:Health() <= 0 then continue end
        local plyPos = ply:GetPos()
        for i, trap in ipairs(Dungeon.Traps) do
            if curTime - trap.lastTriggered < CFG.TrapCooldown then continue end
            if not trap.plate or not IsValid(trap.plate) then continue end
            -- 2-D distance check (ignores Z so tall rooms don't block triggers).
            local dx   = plyPos.x - trap.pos.x
            local dy   = plyPos.y - trap.pos.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < TRAP_TRIGGER_RADIUS then
                trap.lastTriggered = curTime
                local effectData = EffectData()
                effectData:SetOrigin(plyPos + Vector(0, 0, 16))

                if trap.heal then
                    -- Health trap: restore up to the player's max health.
                    local newHealth = math.min(ply:Health() + trap.heal, ply:GetMaxHealth())
                    ply:SetHealth(newHealth)
                    ply:EmitSound("vo/ravenholm/monk_givehealth01.wav", 75, 100)
                    effectData:SetMagnitude(trap.heal)
                    util.Effect("confetti", effectData)

                    -- Bonus: spawn a loot box somewhere in the dungeon.
                    if #Dungeon.LastRooms > 1 then
                        local room = Dungeon.LastRooms[math.random(2, #Dungeon.LastRooms)]
                        local tx = math.random(room.x + 1, room.x + room.w - 2)
                        local ty = math.random(room.y + 1, room.y + room.h - 2)
                        spawnBox(Dungeon.Origin, tx, ty)
                        ply:ChatPrint("A reward box appeared somewhere in the dungeon!")
                    end
                else
                    -- Damage trap: deal damage to the player.
                    local dmgInfo = DamageInfo()
                    dmgInfo:SetDamageType(DMG_SLASH)
                    dmgInfo:SetDamage(trap.damage)
                    dmgInfo:SetAttacker(ply)
                    dmgInfo:SetInflictor(trap.plate)
                    ply:TakeDamageInfo(dmgInfo)
                    effectData:SetMagnitude(trap.damage)
                    util.Effect("confetti", effectData)
                    ply:EmitSound("physics/metal/metal_box_impact_bullet" .. math.random(1, 3) .. ".wav", 70, 180)
                end

                -- Flash the plate color, then move it to a new location.
                -- Deferred via timer so Dungeon.Traps is never mutated mid-iteration.
                trap.plate:SetColor(trap.color)
                timer.Simple(0.3, function() relocateTrap(trap) end)
            end
        end
    end
end)

-- ── Layout ───────────────────────────────────────────────────────────────────
-- Generates a random room layout and returns: room list, tile list, tile set.
-- Rooms are placed with up to 100 attempts each to avoid overlaps.
-- Adjacent rooms are connected by 2-tile-wide L-shaped corridors.
function Dungeon.BuildLayout()
    local rooms, tileSet, tileList = {}, {}, {}

    -- Adds a tile to the set and list; deduplicates by key.
    local function addTile(x, y)
        local k = x .. "," .. y
        if not tileSet[k] then
            tileSet[k] = true
            table.insert(tileList, { x = x, y = y })
        end
    end

    -- Place rooms, skipping any that overlap an existing room.
    for _ = 1, CFG.NumRooms do
        for _ = 1, 100 do
            local w = math.random(CFG.RoomMin, CFG.RoomMax)
            local h = math.random(CFG.RoomMin, CFG.RoomMax)
            local r = {
                x = math.random(1, CFG.MapW - w - 1),
                y = math.random(1, CFG.MapH - h - 1),
                w = w,
                h = h,
            }
            local ok = true
            for _, e in ipairs(rooms) do
                if overlaps(r, e) then ok = false break end
            end
            if ok then
                table.insert(rooms, r)
                break
            end
        end
    end

    -- Fill each room's interior tiles.
    for _, room in ipairs(rooms) do
        for tx = room.x, room.x + room.w - 1 do
            for ty = room.y, room.y + room.h - 1 do
                addTile(tx, ty)
            end
        end
    end

    -- Connect sequential rooms with 2-tile-wide L-shaped corridors.
    for i = 1, #rooms - 1 do
        local ax, ay = center(rooms[i])
        local bx, by = center(rooms[i + 1])
        local cx, cy = ax, ay
        -- Horizontal segment first.
        while cx ~= bx do
            addTile(cx, cy)
            addTile(cx, cy + 1)
            cx = cx + (bx > cx and 1 or -1)
        end
        -- Then vertical segment.
        while cy ~= by do
            addTile(cx, cy)
            addTile(cx + 1, cy)
            cy = cy + (by > cy and 1 or -1)
        end
        addTile(bx, by)
        addTile(bx + 1, by)
    end

    Dungeon.LastRooms = rooms
    return rooms, tileList, tileSet
end

-- ── Floor ────────────────────────────────────────────────────────────────────
-- Spawns a flat plate at ground level for every tile in the dungeon.
local function spawnFloors(origin, tileList)
    for _, tile in ipairs(tileList) do
        local wx = origin.x + tile.x * CFG.TileSize
        local wy = origin.y + tile.y * CFG.TileSize
        local gz = groundZ(Vector(wx, wy, origin.z))
        spawnProp(Vector(wx, wy, gz), Angle(0, 0, 0))
    end
end

-- ── Roof ─────────────────────────────────────────────────────────────────────
-- Spawns a ceiling plate WallH units above the floor for every tile.
local function spawnRoofs(origin, tileList)
    for _, tile in ipairs(tileList) do
        local wx = origin.x + tile.x * CFG.TileSize
        local wy = origin.y + tile.y * CFG.TileSize
        local gz = groundZ(Vector(wx, wy, origin.z))
        spawnProp(Vector(wx, wy, gz + CFG.WallH), Angle(0, 0, 0))
    end
end

-- ── Walls ────────────────────────────────────────────────────────────────────
-- Cardinal directions used when checking for missing neighbours to place walls.
local DIRS = {
    { dx =  0, dy = -1, ox =  0,              oy = -CFG.WallOffset, yaw =   0 },
    { dx =  0, dy =  1, ox =  0,              oy =  CFG.WallOffset, yaw = 180 },
    { dx =  1, dy =  0, ox =  CFG.WallOffset, oy =  0,              yaw =  90 },
    { dx = -1, dy =  0, ox = -CFG.WallOffset, oy =  0,              yaw = 270 },
}

-- For each tile that borders empty space, stack plates vertically to form a wall.
local function spawnWalls(origin, tileSet)
    local stackCount = math.ceil(CFG.WallH / CFG.PlateSize)
    for key in pairs(tileSet) do
        local tx, ty = key:match("(-?%d+),(-?%d+)")
        tx, ty = tonumber(tx), tonumber(ty)
        local wx = origin.x + tx * CFG.TileSize
        local wy = origin.y + ty * CFG.TileSize
        local gz = groundZ(Vector(wx, wy, origin.z))
        for _, d in ipairs(DIRS) do
            if not tileSet[(tx + d.dx) .. "," .. (ty + d.dy)] then
                local wallX = wx + d.ox
                local wallY = wy + d.oy
                for i = 1, stackCount do
                    local wallZ = gz + (i - 0.5) * CFG.PlateSize
                    spawnProp(Vector(wallX, wallY, wallZ), Angle(0, d.yaw, 90))
                end
            end
        end
    end
end

-- ── NPCs ─────────────────────────────────────────────────────────────────────

-- Spawns a random number of NPCs inside one room and wires up their behaviour.
local function spawnNPCsForRoom(origin, room)
    for _ = 1, math.random(CFG.NPCPerRoom.min, CFG.NPCPerRoom.max) do
        local npcType = weightedRandom(CFG.NPCTypes)
        local tx = math.random(room.x + 1, room.x + room.w - 2)
        local ty = math.random(room.y + 1, room.y + room.h - 2)
        local wx = origin.x + tx * CFG.TileSize
        local wy = origin.y + ty * CFG.TileSize
        local gz = groundZ(Vector(wx, wy, origin.z))
        local spawnPos = Vector(wx, wy, gz + 10)

        local npc = ents.Create(npcType.class)
        -- If the class isn't registered (e.g. missing addon), skip silently.
        if not IsValid(npc) then continue end
        npc:SetPos(spawnPos)
        npc:Spawn()
        npc:Activate()
        -- COLLISION_GROUP_WORLD lets the NPC walk through other dungeon props.
        npc:SetCollisionGroup(COLLISION_GROUP_WORLD)

        -- Teleports the NPC back to where it spawned (used by HandleStuck).
        function npc:TeleportToRecoveryPos()
            npc:SetPos(spawnPos)
        end

        -- Called by the engine when this NPC's health reaches zero.
        function npc:OnKilled(damageInfo)
            -- Read the attacker BEFORE the NPC is removed by OnNPCKilled.
            local attacker = damageInfo:GetAttacker()
            if IsValid(attacker) and attacker:IsPlayer() then
                attacker:SetFrags(attacker:Frags() + 1)
            end
            -- Fire OnNPCKilled LAST — it removes this entity, so self is invalid after.
            hook.Run("OnNPCKilled", self, attacker, damageInfo:GetInflictor())
        end

        -- Called by the NextBot locomotion system when the bot gets stuck.
        function npc:HandleStuck()
            self.loco:ClearStuck()
            self:TeleportToRecoveryPos(spawnPos)
        end

        -- Returns true only if pos is both clear and on the navmesh.
        function npc:IsGoodRecoveryPosition(pos)
            return self:IsRecoveryPositionClear(pos) and self:IsRecoveryPositionOnNavmesh(pos)
        end

        -- Picks the best position to teleport to after recovering from a launch.
        function npc:GetRecoveryPos(pos)
            local wantedPos = pos + Vector(0, 0, 6)
            if self:IsGoodRecoveryPosition(wantedPos) then return wantedPos end
            local navPos = self:GetRandomNavmeshRecoveryPos()
            if navPos then return navPos end
            return pos + Vector(0, 0, 48)  -- fallback: above the stuck position
        end

        -- Re-shows the NPC and restores its movement after a ragdoll launch.
        function npc:RecoverFromLaunch(pos)
            timer.Simple(self.RecoverDelay, function()
                if not IsValid(self) then return end
                local targetPos = self:GetRecoveryPos(pos)
                self:SetPos(targetPos)
                self:SetNoDraw(false)
                self:SetNotSolid(false)
                self:RefreshConfiguredMovement()
                self.loco:ClearStuck()
                self.IsRagdollLaunching = false
                self.ActiveRagdoll = nil
                self:ApplySprintSequence()
            end)
        end

        -- Hides the NPC, spawns a ragdoll in its place, flings it at the target,
        -- then re-materialises the NPC after the ragdoll timer expires.
        function npc:LaunchAsRagdoll(target)
            if self.IsRagdollLaunching or not IsValid(target) then return end
            self.IsRagdollLaunching  = true
            self.LastLaunchTime      = CurTime()
            self.NextLaunch          = self.LastLaunchTime + self:GetConfiguredLaunchCooldown()
            self.LastDamageTimes     = {}
            self.HitVictims          = {}

            local startPos    = self:GetPos()
            local startAngles = self:GetAngles()
            local aimDir      = (target:WorldSpaceCenter() - self:WorldSpaceCenter()):GetNormalized()
            self:BecomeHiddenChaser()

            local ragdoll = ents.Create("prop_ragdoll")
            if not IsValid(ragdoll) then
                self:RecoverFromLaunch(startPos)
                return
            end

            ragdoll:SetModel(self.Model)
            ragdoll:SetPos(startPos + Vector(0, 0, 8))
            ragdoll:SetAngles(startAngles)
            ragdoll:SetOwner(self)
            ragdoll:SetCollisionGroup(COLLISION_GROUP_NONE)
            ragdoll:Spawn()
            ragdoll:Activate()
            self.ActiveRagdoll = ragdoll

            -- ThrowRagdoll must run after Spawn/Activate complete (next tick).
            timer.Simple(0, function()
                if not IsValid(self) or not IsValid(ragdoll) then return end
                self:ThrowRagdoll(ragdoll, aimDir)
            end)

            -- Damage any entity the ragdoll hits at speed.
            ragdoll:AddCallback("PhysicsCollide", function(_, data)
                if not IsValid(self) then return end
                local hitEnt = data.HitEntity
                if IsValid(hitEnt) and data.OurOldVelocity:Length() > 420 then
                    self:DamageVictim(hitEnt, ragdoll, data.OurOldVelocity:GetNormalized(), self:GetConfiguredDamage())
                end
            end)

            -- Periodically damage entities near the ragdoll while it flies.
            local timerName   = "evil_skeleton_ragdoll_" .. self:EntIndex()
            self.RagdollTimerName = timerName
            local ragdollTime = self:GetConfiguredRagdollTime()
            timer.Create(timerName, 0.05, math.ceil(ragdollTime / 0.05), function()
                if not IsValid(self) or not IsValid(ragdoll) then
                    timer.Remove(timerName)
                    return
                end
                self:DamageNearbyVictims(ragdoll)
            end)

            -- After the ragdoll expires, remove it and recover the NPC.
            timer.Simple(ragdollTime, function()
                if not IsValid(self) then return end
                local recoverPos = IsValid(ragdoll) and ragdoll:GetPos() or startPos
                local npc = ents.Create(npcType.class)
                if not IsValid(npc) then return end
                npc:SetPos(recoverPos)
                npc:Spawn()
                npc:Activate()
                npc:SetCollisionGroup(COLLISION_GROUP_WORLD)
                if IsValid(ragdoll) then ragdoll:Remove() end
                self:RecoverFromLaunch(recoverPos)
            end)
        end

        if npcType.nextbot then
            -- NextBots ignore SetPos until fully initialised, so defer the
            -- position correction by 1 second and trace to land on floor props.
            local finalPos = spawnPos
            timer.Simple(1, function()
                if not IsValid(npc) then return end
                local tr = util.TraceLine({
                    start  = finalPos + Vector(0, 0, 200),
                    endpos = finalPos - Vector(0, 0, 200),
                    mask   = MASK_SOLID,
                })
                local landPos = tr.Hit and (tr.HitPos + Vector(0, 0, 10)) or finalPos
                npc:SetPos(landPos)
            end)
        end

        table.insert(Dungeon.NPCs, npc)
    end
end

-- Removes all existing NPCs and re-populates every non-spawn room.
function Dungeon.SpawnAllNPCs(origin)
    for _, n in ipairs(Dungeon.NPCs) do
        if IsValid(n) then n:Remove() end
    end
    Dungeon.NPCs = {}

    -- Room 1 is the player spawn room; skip it so players don't land inside a mob.
    for i = 2, #Dungeon.LastRooms do
        spawnNPCsForRoom(origin, Dungeon.LastRooms[i])
    end
    print(string.format("Dungeon: %d NPCs spawned.", #Dungeon.NPCs))
end

-- Checks whether all NPCs are dead; if so, schedules a respawn wave.
local function checkNPCRespawn()
    if not CFG.NPCRespawn then return end
    for _, n in ipairs(Dungeon.NPCs) do
        if IsValid(n) and n:Health() > 0 then return end  -- at least one alive, bail
    end
    print("Dungeon: all NPCs dead, respawning in " .. CFG.NPCRespawnTime .. "s...")
    timer.Simple(CFG.NPCRespawnTime, function() Dungeon.SpawnAllNPCs(Dungeon.Origin) end)
end

hook.Add("OnNPCKilled", "DungeonNPCKilled", function() checkNPCRespawn() end)

-- ── Spawn Points ─────────────────────────────────────────────────────────────
-- Places one spawn point at the center of each room.
local function buildSpawnPoints(origin, rooms)
    Dungeon.SpawnPos  = {}
    Dungeon._spawnIdx = 0
    for _, r in ipairs(rooms) do
        local cx = origin.x + math.floor(r.x + r.w * 0.5) * CFG.TileSize
        local cy = origin.y + math.floor(r.y + r.h * 0.5) * CFG.TileSize
        local gz = groundZ(Vector(cx, cy, origin.z))
        table.insert(Dungeon.SpawnPos, Vector(cx, cy, gz + 10))
    end
end

-- Returns the next spawn position in a round-robin cycle.
function Dungeon.GetSpawnPos()
    if #Dungeon.SpawnPos == 0 then return Vector(0, 0, 0) end
    Dungeon._spawnIdx = (Dungeon._spawnIdx % #Dungeon.SpawnPos) + 1
    return Dungeon.SpawnPos[Dungeon._spawnIdx]
end

-- ── Cleanup ──────────────────────────────────────────────────────────────────
-- Removes all dungeon entities and resets state tables.
function Dungeon.Cleanup()
    for _, e in ipairs(Dungeon.Entities) do if IsValid(e) then e:Remove() end end
    for _, n in ipairs(Dungeon.NPCs)     do if IsValid(n) then n:Remove() end end

    Dungeon.Entities  = {}
    Dungeon.NPCs      = {}
    Dungeon.Traps     = {}
    Dungeon.SpawnPos  = {}
    Dungeon._spawnIdx = 0
    print("Dungeon cleaned up.")
end

-- ── Generate ─────────────────────────────────────────────────────────────────
-- Full dungeon generation: cleans up, builds layout, spawns all geometry and content.
function Dungeon:Generate(origin)
    math.randomseed(os.time())
    print("Generating dungeon...")
    Dungeon.Cleanup()

    -- Snap origin to the map geometry so the dungeon sits on the ground.
    local tr = util.TraceLine({
        start  = origin + Vector(0, 0, 500),
        endpos = origin - Vector(0, 0, 5000),
        mask   = MASK_SOLID_BRUSHONLY,
    })
    origin       = tr.Hit and tr.HitPos or origin
    Dungeon.Origin = origin

    local rooms, tiles, tileSet = Dungeon.BuildLayout()
    spawnFloors(origin, tiles)
    spawnWalls(origin, tileSet)
    spawnRoofs(origin, tiles)
    buildSpawnPoints(origin, rooms)
    Dungeon.SpawnAllNPCs(origin)
    Dungeon.SpawnAllTraps(origin)
    Dungeon.SpawnAllLootBoxes(origin)
    print(string.format(
        "Done: %d rooms | %d tiles | %d ents | %d NPCs | %d traps | %d boxes | %d spawns",
        #rooms, #tiles, #Dungeon.Entities, #Dungeon.NPCs,
        #Dungeon.Traps, #Dungeon.LootBoxes, #Dungeon.SpawnPos
    ))
end

-- ── Max Players ──────────────────────────────────────────────────────────────
-- Rejects connection attempts when the server is at capacity.
hook.Add("CheckPassword", "DungeonMaxPlayers", function()
    if player.GetCount() >= CFG.MaxPlayers then
        return false, "Server is full! (Max " .. CFG.MaxPlayers .. " players)"
    end
end)

-- ── Player Hooks ─────────────────────────────────────────────────────────────
-- Generate the dungeon on the first player spawn, then just teleport subsequent players.
hook.Add("PlayerSpawn", "DungeonGen", function(ply)
    if #Dungeon.Entities == 0 then
        -- First spawn: build everything, then teleport the player in.
        Dungeon:Generate(ply:GetPos())
        timer.Simple(0.2, function()
            if IsValid(ply) and #Dungeon.SpawnPos > 0 then ply:SetPos(Dungeon.GetSpawnPos()) end
        end)
    else
        -- Dungeon already exists: teleport straight in.
        timer.Simple(0.1, function()
            if IsValid(ply) and #Dungeon.SpawnPos > 0 then ply:SetPos(Dungeon.GetSpawnPos()) end
        end)
    end
end)

-- ── Commands ─────────────────────────────────────────────────────────────────
-- Admin-only: regenerate the dungeon at the caller's position.
concommand.Add("dungeon_generate", function(ply)
    if not IsValid(ply) or ply:IsAdmin() then
        Dungeon:Generate(IsValid(ply) and ply:GetPos() or Vector(0, 0, 0))
        timer.Simple(0.2, function() if IsValid(ply) then ply:SetPos(Dungeon.GetSpawnPos()) end end)
    end
end)

-- Admin-only: remove all dungeon entities.
concommand.Add("dungeon_cleanup", function(ply)
    if not IsValid(ply) or ply:IsAdmin() then Dungeon.Cleanup() end
end)

-- Admin-only: re-spawn the NPC wave immediately.
concommand.Add("dungeon_spawnnpcs", function(ply)
    if not IsValid(ply) or ply:IsAdmin() then Dungeon.SpawnAllNPCs(Dungeon.Origin) end
end)

-- Admin-only: reset and re-spawn all traps.
concommand.Add("dungeon_respawntraps", function(ply)
    if not IsValid(ply) or ply:IsAdmin() then Dungeon.SpawnAllTraps(Dungeon.Origin) end
end)

-- Prints live dungeon stats to the calling player's chat.
concommand.Add("dungeon_info", function(ply)
    if IsValid(ply) then
        local alive = 0
        for _, n in ipairs(Dungeon.NPCs) do
            if IsValid(n) and n:Health() > 0 then alive = alive + 1 end
        end
        ply:ChatPrint(string.format(
            "Dungeon: %d rooms | %d ents | %d/%d NPCs | %d traps | %d/%d players | %d spawns",
            #Dungeon.LastRooms, #Dungeon.Entities, alive, #Dungeon.NPCs,
            #Dungeon.Traps, player.GetCount(), CFG.MaxPlayers, #Dungeon.SpawnPos
        ))
    end
end)
