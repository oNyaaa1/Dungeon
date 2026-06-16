print("Dungeon Loaded")
local CFG = {
    TileSize = 120,
    TraceAbove = 512,
    NumRooms = 12,
    RoomMin = 5,
    RoomMax = 10,
    MapW = 60,
    MapH = 60,
    MaxPlayers = 32,
    WallH = 240,
    PlateSize = 120,
    WallOffset = 60,
    NPCTypes = {
        {
            class = "npc_evil_ass_skeleton",
            weight = 100,
            nextbot = true
        },
    },
    NPCPerRoom = {
        min = 0, // 2
        max = 0 //5 
    },
    NPCRespawn = true,
    NPCRespawnTime = 30,
    TrapsPerRoom = {
        min = 1,
        max = 5
    },
    TrapCooldown = 2,
    TrapDamage = 10,
}

local PLATE_MODEL = "models/props_phx/construct/metal_plate4x4.mdl"
Dungeon = Dungeon or {}
Dungeon.Entities = Dungeon.Entities or {}
Dungeon.NPCs = Dungeon.NPCs or {}
Dungeon.Traps = Dungeon.Traps or {}
Dungeon.SpawnPos = Dungeon.SpawnPos or {}
Dungeon.LastRooms = Dungeon.LastRooms or {}
Dungeon.Origin = Dungeon.Origin or Vector(0, 0, 0)
Dungeon._spawnIdx = 0
Dungeon.LootBoxes = Dungeon.LootBoxes or {}
-- ── Helpers ──────────────────────────────────────────────────────────────────
local function overlaps(a, b)
    return not (a.x + a.w + 1 <= b.x or b.x + b.w + 1 <= a.x or a.y + a.h + 1 <= b.y or b.y + b.h + 1 <= a.y)
end

local function center(room)
    return math.floor(room.x + room.w * 0.5), math.floor(room.y + room.h * 0.5)
end

local function freeze(ent)
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end
end

local function groundZ(pos)
    local tr = util.TraceLine({
        start = pos + Vector(0, 0, CFG.TraceAbove),
        endpos = pos - Vector(0, 0, CFG.TraceAbove),
        mask = MASK_SOLID_BRUSHONLY,
    })
    return tr.Hit and tr.HitPos.z or pos.z
end

local function weightedRandom(items)
    local total = 0
    for _, v in ipairs(items) do
        total = total + v.weight
    end

    local r = math.random(1, total)
    local acc = 0
    for _, v in ipairs(items) do
        acc = acc + v.weight
        if r <= acc then return v end
    end
    return items[#items]
end

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
    ent.IsProp = true
    table.insert(Dungeon.Entities, ent)
    return ent
end

-- ── Trap Types ───────────────────────────────────────────────────────────────
local TRAP_TYPES = {
    {
        name = "spike",
        color = Color(180, 40, 40),
        damage = CFG.TrapDamage,
    },
    {
        name = "fire",
        color = Color(220, 120, 20),
        damage = CFG.TrapDamage * 0.5,
    },
    {
        name = "explosive",
        color = Color(200, 60, 0),
        damage = CFG.TrapDamage * 1.2,
    },
    {
        name = "health",
        color = Color(40, 200, 40),
        heal = 25,
    },
}

-- ── Trap Spawning ────────────────────────────────────────────────────────────
local function spawnTrap(origin, tileX, tileY, forcedType)
    -- forcedType lets a relocated plate keep the same kind (heal stays heal, etc.)
    local trapType = forcedType or TRAP_TYPES[math.random(1, #TRAP_TYPES)]
    local wx = origin.x + tileX * CFG.TileSize
    local wy = origin.y + tileY * CFG.TileSize
    local gz = groundZ(Vector(wx, wy, origin.z))
    -- Floor plate (looks normal until triggered)
    local plate = spawnProp(Vector(wx, wy, gz), Angle(0, 0, 0))
    if not IsValid(plate) then return nil end

    -- Health traps are visibly green so players can spot them
    if trapType.heal then
        plate:SetColor(trapType.color)
    end

    -- Trap data
    local trapData = {
        pos = Vector(wx, wy, gz),
        type = trapType.name,
        typeData = trapType,
        damage = trapType.damage,
        heal = trapType.heal,
        color = trapType.color,
        lastTriggered = 0,
        plate = plate,
        tileX = tileX,
        tileY = tileY,
    }

    table.insert(Dungeon.Traps, trapData)
    return trapData
end

-- ── Spawn Traps For Room ────────────────────────────────────────────────────
local function spawnTrapsForRoom(origin, room)
    local numTraps = math.random(CFG.TrapsPerRoom.min, CFG.TrapsPerRoom.max)
    for _ = 1, numTraps do
        -- Pick a tile inside the room (away from edges so players walk over them)
        local tx = math.random(room.x + 2, room.x + room.w - 3)
        local ty = math.random(room.y + 2, room.y + room.h - 3)
        spawnTrap(origin, tx, ty)
    end
end

function Dungeon.SpawnAllTraps(origin)
    Dungeon.Traps = {}
    -- Skip the first room (index 1) — it's the spawn room
    for i = 2, #Dungeon.LastRooms do
        spawnTrapsForRoom(origin, Dungeon.LastRooms[i])
    end

    print(string.format("Dungeon: %d traps spawned.", #Dungeon.Traps))
end

-- ── Loot Boxes ───────────────────────────────────────────────────────────────
local LOOT_BOXES_PER_ROOM = {
    min = 1,
    max = 2,
}

-- Unique loot tables per box (could be expanded later)
local function buildLootTable()
    return {
        {weapon = "confetti_gun", weight = 100},
    }
end

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

local function spawnBoxesForRoom(origin, room)
    local numBoxes = math.random(LOOT_BOXES_PER_ROOM.min, LOOT_BOXES_PER_ROOM.max)
    for _ = 1, numBoxes do
        local tx = math.random(room.x + 1, room.x + room.w - 2)
        local ty = math.random(room.y + 1, room.y + room.h - 2)
        spawnBox(origin, tx, ty)
    end
end

function Dungeon.SpawnAllLootBoxes(origin)
    -- Remove existing boxes
    for _, box in ipairs(Dungeon.LootBoxes) do
        if IsValid(box) then box:Remove() end
    end
    Dungeon.LootBoxes = {}

    -- Spawn in all rooms except the first (spawn room)
    for i = 2, #Dungeon.LastRooms do
        spawnBoxesForRoom(origin, Dungeon.LastRooms[i])
    end

    print(string.format("Dungeon: %d loot boxes spawned.", #Dungeon.LootBoxes))
end

-- ── Trap Relocation ──────────────────────────────────────────────────────────
-- Pick a random interior tile in a random non-spawn room.
local function randomTrapTile()
    if #Dungeon.LastRooms < 2 then return nil end
    local room = Dungeon.LastRooms[math.random(2, #Dungeon.LastRooms)]
    local tx = math.random(room.x + 2, room.x + room.w - 3)
    local ty = math.random(room.y + 2, room.y + room.h - 3)
    return tx, ty
end

-- Remove a single trap: delete its plate and drop it from the trap list.
local function removeTrap(trap)
    if trap.plate and IsValid(trap.plate) then
        trap.plate:Remove()
        table.RemoveByValue(Dungeon.Entities, trap.plate)
    end
    table.RemoveByValue(Dungeon.Traps, trap)
end

-- Remove a trap and spawn a fresh one of the SAME type elsewhere.
local function relocateTrap(trap)
    local keepType = trap.typeData
    removeTrap(trap)
    local tx, ty = randomTrapTile()
    if not tx then return end
    spawnTrap(Dungeon.Origin, tx, ty, keepType)
end

-- ── Trap Trigger (proximity-based) ───────────────────────────────────────────
local TRAP_TRIGGER_RADIUS = 48
timer.Create("DungeonTrapThink", 0.3, 0, function()
    if #Dungeon.Traps == 0 then return end
    local curTime = CurTime()
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or ply:Health() <= 0 then continue end
        local plyPos = ply:GetPos()
        for i, trap in ipairs(Dungeon.Traps) do
            if curTime - trap.lastTriggered < CFG.TrapCooldown then continue end
            if not trap.plate or not IsValid(trap.plate) then continue end
            local dx = plyPos.x - trap.pos.x
            local dy = plyPos.y - trap.pos.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < TRAP_TRIGGER_RADIUS then
                trap.lastTriggered = curTime
                local effectData = EffectData()
                effectData:SetOrigin(plyPos + Vector(0, 0, 16))

                if trap.heal then
                    -- Health trap: heal the player
                    local newHealth = math.min(ply:Health() + trap.heal, ply:GetMaxHealth())
                    ply:SetHealth(newHealth)
                    ply:EmitSound("vo/ravenholm/monk_givehealth01.wav", 75, 100)
                    effectData:SetMagnitude(trap.heal)
                    util.Effect("confetti", effectData)

                    -- Spawn a loot box in a random room
                    if #Dungeon.LastRooms > 1 then
                        local room = Dungeon.LastRooms[math.random(2, #Dungeon.LastRooms)]
                        local tx = math.random(room.x + 1, room.x + room.w - 2)
                        local ty = math.random(room.y + 1, room.y + room.h - 2)
                        spawnBox(Dungeon.Origin, tx, ty)
                        ply:ChatPrint("A reward box appeared somewhere in the dungeon!")
                    end
                else
                    -- Damage trap: hurts the player
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

                -- Flash the plate, then move it (heal or trap) to a fresh spot.
                -- Deferred via timer so we never mutate Dungeon.Traps mid-iteration.
                trap.plate:SetColor(trap.color)
                timer.Simple(0.3, function() relocateTrap(trap) end)
            end
        end
    end
end)

-- ── Layout ───────────────────────────────────────────────────────────────────
function Dungeon.BuildLayout()
    local rooms, tileSet, tileList = {}, {}, {}
    local function addTile(x, y)
        local k = x .. "," .. y
        if not tileSet[k] then
            tileSet[k] = true
            table.insert(tileList, {
                x = x,
                y = y
            })
        end
    end

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
                if overlaps(r, e) then
                    ok = false
                    break
                end
            end

            if ok then
                table.insert(rooms, r)
                break
            end
        end
    end

    for _, room in ipairs(rooms) do
        for tx = room.x, room.x + room.w - 1 do
            for ty = room.y, room.y + room.h - 1 do
                addTile(tx, ty)
            end
        end
    end

    -- 2-tile wide corridors
    for i = 1, #rooms - 1 do
        local ax, ay = center(rooms[i])
        local bx, by = center(rooms[i + 1])
        local cx, cy = ax, ay
        while cx ~= bx do
            addTile(cx, cy)
            addTile(cx, cy + 1)
            cx = cx + (bx > cx and 1 or -1)
        end

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
local function spawnFloors(origin, tileList)
    for _, tile in ipairs(tileList) do
        local wx = origin.x + tile.x * CFG.TileSize
        local wy = origin.y + tile.y * CFG.TileSize
        local gz = groundZ(Vector(wx, wy, origin.z))
        spawnProp(Vector(wx, wy, gz), Angle(0, 0, 0))
    end
end

-- ── Roof ─────────────────────────────────────────────────────────────────────
local function spawnRoofs(origin, tileList)
    for _, tile in ipairs(tileList) do
        local wx = origin.x + tile.x * CFG.TileSize
        local wy = origin.y + tile.y * CFG.TileSize
        local gz = groundZ(Vector(wx, wy, origin.z))
        spawnProp(Vector(wx, wy, gz + CFG.WallH), Angle(0, 0, 0))
    end
end

-- ── Walls ────────────────────────────────────────────────────────────────────
local DIRS = {
    {
        dx = 0,
        dy = -1,
        ox = 0,
        oy = -CFG.WallOffset,
        yaw = 0
    },
    {
        dx = 0,
        dy = 1,
        ox = 0,
        oy = CFG.WallOffset,
        yaw = 180
    },
    {
        dx = 1,
        dy = 0,
        ox = CFG.WallOffset,
        oy = 0,
        yaw = 90
    },
    {
        dx = -1,
        dy = 0,
        ox = -CFG.WallOffset,
        oy = 0,
        yaw = 270
    },
}

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
        if not IsValid(npc) then continue end
        npc:SetPos(spawnPos)
        npc:Spawn()
        npc:Activate()
        npc:SetCollisionGroup(COLLISION_GROUP_WORLD)
        function npc:TeleportToRecoveryPos()
            npc:SetPos(spawnPos)
        end

        function npc:OnKilled(damageInfo)
            -- Award the killer a point (read attacker BEFORE the NPC is removed)
            local attacker = damageInfo:GetAttacker()
            if IsValid(attacker) and attacker:IsPlayer() then
                attacker:SetFrags(attacker:Frags() + 1)
            end

            -- DarkDriftNPCDeath (OnNPCKilled) spawns the ragdoll, removes this NPC,
            -- and DungeonNPCKilled triggers the respawn wave. Fire it LAST and do
            -- not touch `self` afterwards -- the NPC no longer exists once it runs.
            hook.Run("OnNPCKilled", self, attacker, damageInfo:GetInflictor())
        end

        function npc:HandleStuck()
            self.loco:ClearStuck()
            self:TeleportToRecoveryPos(spawnPos)
        end

        function npc:IsGoodRecoveryPosition(pos)
            return self:IsRecoveryPositionClear(pos) and self:IsRecoveryPositionOnNavmesh(pos)
        end

        function npc:GetRecoveryPos(pos)
            local wantedPos = pos + Vector(0, 0, 6)
            if self:IsGoodRecoveryPosition(wantedPos) then return wantedPos end
            local navPos = self:GetRandomNavmeshRecoveryPos()
            if navPos then return navPos end
            return pos + Vector(0, 0, 48)
        end

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

        function npc:LaunchAsRagdoll(target)
            if self.IsRagdollLaunching or not IsValid(target) then return end
            self.IsRagdollLaunching = true
            self.LastLaunchTime = CurTime()
            self.NextLaunch = self.LastLaunchTime + self:GetConfiguredLaunchCooldown()
            self.LastDamageTimes = {}
            self.HitVictims = {}
            local startPos = self:GetPos()
            local startAngles = self:GetAngles()
            local aimDir = (target:WorldSpaceCenter() - self:WorldSpaceCenter()):GetNormalized()
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
            timer.Simple(0, function()
                if not IsValid(self) or not IsValid(ragdoll) then return end
                self:ThrowRagdoll(ragdoll, aimDir)
            end)

            ragdoll:AddCallback("PhysicsCollide", function(_, data)
                if not IsValid(self) then return end
                local hitEnt = data.HitEntity
                if IsValid(hitEnt) and data.OurOldVelocity:Length() > 420 then self:DamageVictim(hitEnt, ragdoll, data.OurOldVelocity:GetNormalized(), self:GetConfiguredDamage()) end
            end)

            local timerName = "evil_skeleton_ragdoll_" .. self:EntIndex()
            self.RagdollTimerName = timerName
            local ragdollTime = self:GetConfiguredRagdollTime()
            timer.Create(timerName, 0.05, math.ceil(ragdollTime / 0.05), function()
                if not IsValid(self) or not IsValid(ragdoll) then
                    timer.Remove(timerName)
                    return
                end

                self:DamageNearbyVictims(ragdoll)
            end)

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
            -- Nextbots ignore SetPos until fully initialized,
            -- so defer position to land on top of floor props
            local finalPos = spawnPos
            timer.Simple(1, function()
                if not IsValid(npc) then return end
                local tr = util.TraceLine({
                    start = finalPos + Vector(0, 0, 200),
                    endpos = finalPos - Vector(0, 0, 200),
                    mask = MASK_SOLID,
                })

                local landPos = tr.Hit and (tr.HitPos + Vector(0, 0, 10)) or finalPos
                npc:SetPos(landPos)
            end)
        end

        table.insert(Dungeon.NPCs, npc)
    end
end

function Dungeon.SpawnAllNPCs(origin)
    for _, n in ipairs(Dungeon.NPCs) do
        if IsValid(n) then n:Remove() end
    end

    Dungeon.NPCs = {}
    -- Skip room 1 (the spawn room) so players don't spawn inside a mob,
    -- matching how traps and loot boxes are placed.
    for i = 2, #Dungeon.LastRooms do
        spawnNPCsForRoom(origin, Dungeon.LastRooms[i])
    end

    print(string.format("Dungeon: %d NPCs spawned.", #Dungeon.NPCs))
end

local function checkNPCRespawn()
    if not CFG.NPCRespawn then return end
    for _, n in ipairs(Dungeon.NPCs) do
        if IsValid(n) and n:Health() > 0 then return end
    end

    print("Dungeon: all NPCs dead, respawning in " .. CFG.NPCRespawnTime .. "s...")
    timer.Simple(CFG.NPCRespawnTime, function() Dungeon.SpawnAllNPCs(Dungeon.Origin) end)
end

hook.Add("OnNPCKilled", "DungeonNPCKilled", function() checkNPCRespawn() end)
-- ── Spawn Points ─────────────────────────────────────────────────────────────
local function buildSpawnPoints(origin, rooms)
    Dungeon.SpawnPos = {}
    Dungeon._spawnIdx = 0
    for _, r in ipairs(rooms) do
        local cx = origin.x + math.floor(r.x + r.w * 0.5) * CFG.TileSize
        local cy = origin.y + math.floor(r.y + r.h * 0.5) * CFG.TileSize
        local gz = groundZ(Vector(cx, cy, origin.z))
        table.insert(Dungeon.SpawnPos, Vector(cx, cy, gz + 10))
    end
end

function Dungeon.GetSpawnPos()
    if #Dungeon.SpawnPos == 0 then return Vector(0, 0, 0) end
    Dungeon._spawnIdx = (Dungeon._spawnIdx % #Dungeon.SpawnPos) + 1
    return Dungeon.SpawnPos[Dungeon._spawnIdx]
end

-- ── Cleanup ──────────────────────────────────────────────────────────────────
function Dungeon.Cleanup()
    for _, e in ipairs(Dungeon.Entities) do
        if IsValid(e) then e:Remove() end
    end

    for _, n in ipairs(Dungeon.NPCs) do
        if IsValid(n) then n:Remove() end
    end

    Dungeon.Entities = {}
    Dungeon.NPCs = {}
    Dungeon.Traps = {}
    Dungeon.SpawnPos = {}
    Dungeon._spawnIdx = 0
    print("Dungeon cleaned up.")
end

-- ── Generate ─────────────────────────────────────────────────────────────────
function Dungeon:Generate(origin)
    math.randomseed(os.time())
    print("Generating dungeon...")
    Dungeon.Cleanup()
    -- Snap origin to ground so dungeon never floats
    local tr = util.TraceLine({
        start = origin + Vector(0, 0, 500),
        endpos = origin - Vector(0, 0, 5000),
        mask = MASK_SOLID_BRUSHONLY,
    })

    origin = tr.Hit and tr.HitPos or origin
    Dungeon.Origin = origin
    local rooms, tiles, tileSet = Dungeon.BuildLayout()
    spawnFloors(origin, tiles)
    spawnWalls(origin, tileSet)
    spawnRoofs(origin, tiles)
    buildSpawnPoints(origin, rooms)
    Dungeon.SpawnAllNPCs(origin)
    Dungeon.SpawnAllTraps(origin)
    Dungeon.SpawnAllLootBoxes(origin)
    print(string.format("Done: %d rooms | %d tiles | %d ents | %d NPCs | %d traps | %d boxes | %d spawns", #rooms, #tiles, #Dungeon.Entities, #Dungeon.NPCs, #Dungeon.Traps, #Dungeon.LootBoxes, #Dungeon.SpawnPos))
end

-- ── Max Players ──────────────────────────────────────────────────────────────
hook.Add("CheckPassword", "DungeonMaxPlayers", function() if player.GetCount() >= CFG.MaxPlayers then return false, "Server is full! (Max " .. CFG.MaxPlayers .. " players)" end end)
-- ── Player Hooks ─────────────────────────────────────────────────────────────
-- Only generate once when the FIRST player spawns, then just teleport after that
hook.Add("PlayerSpawn", "DungeonGen", function(ply)
    if #Dungeon.Entities == 0 then
        -- First time: generate then teleport
        Dungeon:Generate(ply:GetPos())
        timer.Simple(0.2, function() if IsValid(ply) and #Dungeon.SpawnPos > 0 then ply:SetPos(Dungeon.GetSpawnPos()) end end)
    else
        -- Dungeon already exists: just teleport in
        timer.Simple(0.1, function() if IsValid(ply) and #Dungeon.SpawnPos > 0 then ply:SetPos(Dungeon.GetSpawnPos()) end end)
    end
end)

-- ── Commands ─────────────────────────────────────────────────────────────────
concommand.Add("dungeon_generate", function(ply)
    if not IsValid(ply) or ply:IsAdmin() then
        Dungeon:Generate(IsValid(ply) and ply:GetPos() or Vector(0, 0, 0))
        timer.Simple(0.2, function() if IsValid(ply) then ply:SetPos(Dungeon.GetSpawnPos()) end end)
    end
end)

concommand.Add("dungeon_cleanup", function(ply) if not IsValid(ply) or ply:IsAdmin() then Dungeon.Cleanup() end end)
concommand.Add("dungeon_spawnnpcs", function(ply) if not IsValid(ply) or ply:IsAdmin() then Dungeon.SpawnAllNPCs(Dungeon.Origin) end end)
concommand.Add("dungeon_respawntraps", function(ply) if not IsValid(ply) or ply:IsAdmin() then Dungeon.SpawnAllTraps(Dungeon.Origin) end end)
concommand.Add("dungeon_info", function(ply)
    if IsValid(ply) then
        local alive = 0
        for _, n in ipairs(Dungeon.NPCs) do
            if IsValid(n) and n:Health() > 0 then alive = alive + 1 end
        end

        ply:ChatPrint(string.format("Dungeon: %d rooms | %d ents | %d/%d NPCs | %d traps | %d/%d players | %d spawns", #Dungeon.LastRooms, #Dungeon.Entities, alive, #Dungeon.NPCs, #Dungeon.Traps, player.GetCount(), CFG.MaxPlayers, #Dungeon.SpawnPos))
    end
end)
