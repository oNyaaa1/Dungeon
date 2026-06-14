print("Dungeon Loaded")

local CFG = {
    TileSize   = 128,
    TraceAbove = 512,
    NumRooms   = 12,
    RoomMin    = 3,
    RoomMax    = 8,
    MapW       = 60,
    MapH       = 60,
    MaxPlayers = 32,

    HeightLayers = { 0, 128, 256 },
    RampStepH    = 32,

    -- Wall is exactly 2 plates tall = 256u, plenty to block a player (~72u tall)
    WallH     = 256,
    PlateSize = 128,  -- metal_plate4x4 is 128u, so 2 stacks = 256u wall
    RoofClearance = 32,  -- extra gap between top of wall and roof so player has headroom

    WallOverlap = 2,

    NPCTypes = {
        { class = "npc_zombie",     weight = 40 },
        { class = "npc_fastzombie", weight = 20 },
        { class = "npc_combine_s",  weight = 25 },
        { class = "npc_manhack",    weight = 15 },
    },
    NPCPerRoom     = { min = 2, max = 5 },
    NPCRespawn     = true,
    NPCRespawnTime = 30,
}

local FLOOR_MODEL = "models/props_phx/construct/metal_plate4x4.mdl"
local WALL_MODEL  = "models/props_phx/construct/metal_plate4x4.mdl"
local ROOF_MODEL  = "models/props_phx/construct/metal_plate4x4.mdl"

Dungeon            = Dungeon or {}
Dungeon.Entities   = Dungeon.Entities or {}
Dungeon.NPCs       = Dungeon.NPCs or {}
Dungeon.SpawnPos   = Dungeon.SpawnPos or {}
Dungeon.LastRooms  = Dungeon.LastRooms or {}
Dungeon.Origin     = Dungeon.Origin or Vector(0,0,0)
Dungeon._spawnIdx  = 0

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function overlaps(a, b)
    return not (
        a.x + a.w + 1 <= b.x or b.x + b.w + 1 <= a.x or
        a.y + a.h + 1 <= b.y or b.y + b.h + 1 <= a.y
    )
end

local function center(room)
    return math.floor(room.x + room.w * 0.5),
           math.floor(room.y + room.h * 0.5)
end

local function freeze(ent)
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end
end

local function groundZ(pos)
    local tr = util.TraceLine({
        start  = pos + Vector(0, 0, CFG.TraceAbove),
        endpos = pos - Vector(0, 0, CFG.TraceAbove),
        mask   = MASK_SOLID_BRUSHONLY,
    })
    return tr.Hit and tr.HitPos.z or pos.z
end

local function weightedRandom(items)
    local total = 0
    for _, v in ipairs(items) do total = total + v.weight end
    local r = math.random(1, total)
    local acc = 0
    for _, v in ipairs(items) do
        acc = acc + v.weight
        if r <= acc then return v end
    end
    return items[#items]
end

local function spawnProp(model, pos, ang)
    local ent = ents.Create("prop_physics")
    if not IsValid(ent) then return nil end
    ent:SetModel(model)
    ent:SetPos(pos)
    ent:SetAngles(ang)
    ent:Spawn()
    ent:Activate()
    freeze(ent)
    table.insert(Dungeon.Entities, ent)
    return ent
end

-- ── Layout ───────────────────────────────────────────────────────────────────

function Dungeon.BuildLayout()
    local rooms, tileSet, tileList, tileZ = {}, {}, {}, {}

    local function addTile(x, y, z)
        local k = x..","..y
        if not tileSet[k] then
            tileSet[k] = true
            tileZ[k]   = z or 0
            table.insert(tileList, { x=x, y=y, z=z or 0 })
        end
    end

    for _ = 1, CFG.NumRooms do
        for _ = 1, 100 do
            local w = math.random(CFG.RoomMin, CFG.RoomMax)
            local h = math.random(CFG.RoomMin, CFG.RoomMax)
            local r = {
                x = math.random(1, CFG.MapW - w - 1),
                y = math.random(1, CFG.MapH - h - 1),
                w = w, h = h,
            }
            local ok = true
            for _, e in ipairs(rooms) do
                if overlaps(r, e) then ok = false; break end
            end
            if ok then
                r.layer = CFG.HeightLayers[math.random(#CFG.HeightLayers)]
                table.insert(rooms, r)
                break
            end
        end
    end

    for _, room in ipairs(rooms) do
        for tx = room.x, room.x + room.w - 1 do
            for ty = room.y, room.y + room.h - 1 do
                addTile(tx, ty, room.layer)
            end
        end
    end

    for i = 1, #rooms - 1 do
        local rA, rB = rooms[i], rooms[i+1]
        local ax, ay = center(rA)
        local bx, by = center(rB)
        local cx, cy = ax, ay
        local zA, zB = rA.layer, rB.layer
        local total  = math.abs(bx-ax) + math.abs(by-ay)
        local step   = 0

        while cx ~= bx do
            step = step + 1
            local frac = total > 0 and step/total or 0
            local cz   = math.floor((zA+(zB-zA)*frac)/CFG.RampStepH)*CFG.RampStepH
            addTile(cx, cy, cz)
            cx = cx + (bx > cx and 1 or -1)
        end
        while cy ~= by do
            step = step + 1
            local frac = total > 0 and step/total or 0
            local cz   = math.floor((zA+(zB-zA)*frac)/CFG.RampStepH)*CFG.RampStepH
            addTile(cx, cy, cz)
            cy = cy + (by > cy and 1 or -1)
        end
        addTile(bx, by, zB)
    end

    Dungeon.LastRooms = rooms
    Dungeon.TileZ     = tileZ
    return rooms, tileList, tileSet, tileZ
end

-- ── Floor ────────────────────────────────────────────────────────────────────

local function spawnFloor(origin, tile)
    local wx = origin.x + tile.x * CFG.TileSize
    local wy = origin.y + tile.y * CFG.TileSize
    local gz = groundZ(Vector(wx, wy, origin.z))
    spawnProp(FLOOR_MODEL, Vector(wx, wy, gz + tile.z), Angle(0, 0, 0))
end

-- ── Roof ─────────────────────────────────────────────────────────────────────

local function spawnRoof(origin, tileList, tileZ)
    for _, tile in ipairs(tileList) do
        local wx = origin.x + tile.x * CFG.TileSize
        local wy = origin.y + tile.y * CFG.TileSize
        local gz = groundZ(Vector(wx, wy, origin.z))

        -- Inner ceiling: sits inside the room giving the player headroom
        -- Placed at floor + layer + WallH so the wall tops align with it
        local innerZ = gz + tile.z + CFG.WallH
        spawnProp(ROOF_MODEL, Vector(wx, wy, innerZ), Angle(0, 0, 0))

        -- Outer roof: one plate above the inner ceiling to seal the top
        -- so there's no gap when looking up from inside
        local outerZ = innerZ + CFG.PlateSize
        spawnProp(ROOF_MODEL, Vector(wx, wy, outerZ), Angle(0, 0, 0))
    end
end

-- ── Stairs ───────────────────────────────────────────────────────────────────

local function spawnStairs(origin, tileList, tileZ)
    local placed = {}
    local ADJ = { {dx=1,dy=0}, {dx=0,dy=1} }

    for _, tile in ipairs(tileList) do
        local k  = tile.x..","..tile.y
        local zA = tileZ[k] or 0

        for _, d in ipairs(ADJ) do
            local nk = (tile.x+d.dx)..",".. (tile.y+d.dy)
            local zB = tileZ[nk]
            if not zB or zB == zA then continue end

            local pk = math.min(tile.x,tile.x+d.dx)..","..math.min(tile.y,tile.y+d.dy)
                       ..">"..math.max(tile.x,tile.x+d.dx)..","..math.max(tile.y,tile.y+d.dy)
            if placed[pk] then continue end
            placed[pk] = true

            local steps = math.abs(zB - zA) / CFG.RampStepH
            local dir   = zB > zA and 1 or -1
            local yaw   = d.dx ~= 0 and 0 or 90

            for s = 1, steps do
                local frac  = s / steps
                local stepX = origin.x + (tile.x + d.dx * frac) * CFG.TileSize
                local stepY = origin.y + (tile.y + d.dy * frac) * CFG.TileSize
                local gz    = groundZ(Vector(stepX, stepY, origin.z))
                local stepZ = gz + zA + (s - 0.5) * CFG.RampStepH * dir
                local pitch = dir * (90 / steps)
                spawnProp(FLOOR_MODEL, Vector(stepX, stepY, stepZ), Angle(pitch, yaw, 0))
            end
        end
    end
end

-- ── Walls ────────────────────────────────────────────────────────────────────

local DIRS = {
    { dx= 0, dy=-1, ox= 0,   oy=-0.5, yaw=  0, ex= 0, ey= 1 },
    { dx= 0, dy= 1, ox= 0,   oy= 0.5, yaw=180, ex= 0, ey=-1 },
    { dx= 1, dy= 0, ox= 0.5, oy= 0,   yaw= 90, ex=-1, ey= 0 },
    { dx=-1, dy= 0, ox=-0.5, oy= 0,   yaw=270, ex= 1, ey= 0 },
}

local function spawnWalls(origin, tileSet, tileZ)
    local stackCount = math.ceil(CFG.WallH / CFG.PlateSize)
    local overlap    = CFG.WallOverlap

    for key in pairs(tileSet) do
        local tx, ty = key:match("(-?%d+),(-?%d+)")
        tx, ty = tonumber(tx), tonumber(ty)

        local wx  = origin.x + tx * CFG.TileSize
        local wy  = origin.y + ty * CFG.TileSize
        local gz  = groundZ(Vector(wx, wy, origin.z))
        local myZ = tileZ[key] or 0

        for _, d in ipairs(DIRS) do
            if not tileSet[(tx+d.dx)..",".. (ty+d.dy)] then
                local wallX = wx + d.ox * CFG.TileSize + d.ex * overlap
                local wallY = wy + d.oy * CFG.TileSize + d.ey * overlap

                for i = 1, stackCount do
                    local wallZ = gz + myZ + (i - 0.5) * CFG.PlateSize
                    spawnProp(WALL_MODEL,
                        Vector(wallX, wallY, wallZ),
                        Angle(0, d.yaw, 90))
                end
            end
        end
    end
end

-- ── NPC Spawning ─────────────────────────────────────────────────────────────

local function spawnNPCsForRoom(origin, room)
    for _ = 1, math.random(CFG.NPCPerRoom.min, CFG.NPCPerRoom.max) do
        local npcType = weightedRandom(CFG.NPCTypes)
        local tx = math.random(room.x + 1, room.x + room.w - 2)
        local ty = math.random(room.y + 1, room.y + room.h - 2)
        local wx = origin.x + tx * CFG.TileSize
        local wy = origin.y + ty * CFG.TileSize
        local gz = groundZ(Vector(wx, wy, origin.z))

        local npc = ents.Create(npcType.class)
        if not IsValid(npc) then continue end
        npc:SetPos(Vector(wx, wy, gz + room.layer + 10))
        npc:Spawn()
        npc:Activate()
        table.insert(Dungeon.NPCs, npc)
    end
end

function Dungeon.SpawnAllNPCs(origin)
    for _, n in ipairs(Dungeon.NPCs) do
        if IsValid(n) then n:Remove() end
    end
    Dungeon.NPCs = {}
    for _, room in ipairs(Dungeon.LastRooms) do
        spawnNPCsForRoom(origin, room)
    end
    print(string.format("Dungeon: %d NPCs spawned.", #Dungeon.NPCs))
end

local function checkNPCRespawn()
    if not CFG.NPCRespawn then return end
    for _, n in ipairs(Dungeon.NPCs) do
        if IsValid(n) and n:Health() > 0 then return end
    end
    print("Dungeon: all NPCs dead, respawning in "..CFG.NPCRespawnTime.."s...")
    timer.Simple(CFG.NPCRespawnTime, function()
        Dungeon.SpawnAllNPCs(Dungeon.Origin)
    end)
end

hook.Add("OnNPCKilled", "DungeonNPCKilled", function() checkNPCRespawn() end)

-- ── Spawn Points ─────────────────────────────────────────────────────────────

local function buildSpawnPoints(origin, rooms)
    Dungeon.SpawnPos  = {}
    Dungeon._spawnIdx = 0
    for _, r in ipairs(rooms) do
        local cx = origin.x + math.floor(r.x + r.w * 0.5) * CFG.TileSize
        local cy = origin.y + math.floor(r.y + r.h * 0.5) * CFG.TileSize
        local gz = groundZ(Vector(cx, cy, origin.z))
        table.insert(Dungeon.SpawnPos, Vector(cx, cy, gz + r.layer + 10))
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
    Dungeon.Entities  = {}
    Dungeon.NPCs      = {}
    Dungeon.SpawnPos  = {}
    Dungeon._spawnIdx = 0
    print("Dungeon cleaned up.")
end

-- ── Generate ─────────────────────────────────────────────────────────────────

function Dungeon:Generate(origin)
    math.randomseed(os.time())
    print("Generating dungeon...")
    Dungeon.Cleanup()

    origin         = origin or Vector(0, 0, 0)
    Dungeon.Origin = origin

    local rooms, tiles, tileSet, tileZ = Dungeon.BuildLayout()

    for _, t in ipairs(tiles) do spawnFloor(origin, t) end
    spawnStairs(origin, tiles, tileZ)
    spawnWalls(origin, tileSet, tileZ)
    spawnRoof(origin, tiles, tileZ)
    buildSpawnPoints(origin, rooms)
    Dungeon.SpawnAllNPCs(origin)

    print(string.format(
        "Done: %d rooms | %d tiles | %d ents | %d NPCs | %d spawns",
        #rooms, #tiles, #Dungeon.Entities, #Dungeon.NPCs, #Dungeon.SpawnPos))
end

-- ── Max Players ──────────────────────────────────────────────────────────────

hook.Add("CheckPassword", "DungeonMaxPlayers", function()
    if player.GetCount() >= CFG.MaxPlayers then
        return false, "Server is full! (Max "..CFG.MaxPlayers.." players)"
    end
end)

-- ── Player Hooks ─────────────────────────────────────────────────────────────

hook.Add("PlayerSpawn", "DungeonGen", function(ply)
    if ply:IsAdmin() and #Dungeon.Entities == 0 then
        Dungeon:Generate(ply:GetPos())
    end
end)

hook.Add("PlayerSpawn", "DungeonPlayerSpawn", function(ply)
    if #Dungeon.SpawnPos > 0 then
        timer.Simple(0.1, function()
            if IsValid(ply) then ply:SetPos(Dungeon.GetSpawnPos()) end
        end)
    end
end)

-- ── Commands ─────────────────────────────────────────────────────────────────

concommand.Add("dungeon_generate", function(ply)
    if not IsValid(ply) or ply:IsAdmin() then
        Dungeon:Generate(IsValid(ply) and ply:GetPos() or Vector(0,0,0))
    end
end)

concommand.Add("dungeon_cleanup", function(ply)
    if not IsValid(ply) or ply:IsAdmin() then Dungeon.Cleanup() end
end)

concommand.Add("dungeon_spawnnpcs", function(ply)
    if not IsValid(ply) or ply:IsAdmin() then
        Dungeon.SpawnAllNPCs(Dungeon.Origin)
    end
end)

concommand.Add("dungeon_info", function(ply)
    if IsValid(ply) then
        local alive = 0
        for _, n in ipairs(Dungeon.NPCs) do
            if IsValid(n) and n:Health() > 0 then alive = alive + 1 end
        end
        ply:ChatPrint(string.format(
            "Dungeon: %d rooms | %d ents | %d/%d NPCs | %d/%d players | %d spawns",
            #Dungeon.LastRooms, #Dungeon.Entities,
            alive, #Dungeon.NPCs,
            player.GetCount(), CFG.MaxPlayers,
            #Dungeon.SpawnPos))
    end
end)