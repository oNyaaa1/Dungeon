print("Dungeon Loaded")

local CFG = {
    TileSize   = 64,
    TraceAbove = 512,
    NumRooms   = 6,
    RoomMin    = 4,
    RoomMax    = 10,
    MapW       = 60,
    MapH       = 60,
    WallH      = 180,  -- tall enough to block a player (~3 units tall player = ~72u, so 180 is safe)
}

local FLOOR_MODEL = "models/props_phx/construct/metal_plate2x2.mdl"  -- 64x64 flat
local WALL_MODEL  = "models/props_phx/construct/metal_plate2x2.mdl"  -- same, rotated + scaled

Dungeon          = Dungeon or {}
Dungeon.Entities = Dungeon.Entities or {}

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function overlaps(a, b)
    return not (
        a.x + a.w + 1 <= b.x or b.x + b.w + 1 <= a.x or
        a.y + a.h + 1 <= b.y or b.y + b.h + 1 <= a.y
    )
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
        start  = pos + Vector(0, 0, CFG.TraceAbove),
        endpos = pos - Vector(0, 0, CFG.TraceAbove),
        mask   = MASK_SOLID_BRUSHONLY,
    })
    return tr.Hit and tr.HitPos.z or pos.z
end

-- ── Layout ───────────────────────────────────────────────────────────────────

function Dungeon.BuildLayout()
    local rooms, tileSet, tileList = {}, {}, {}

    local function addTile(x, y)
        local k = x..","..y
        if not tileSet[k] then
            tileSet[k] = true
            table.insert(tileList, {x=x, y=y})
        end
    end

    for _ = 1, CFG.NumRooms do
        for _ = 1, 50 do
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
            if ok then table.insert(rooms, r); break end
        end
    end

    for _, room in ipairs(rooms) do
        for tx = room.x, room.x + room.w - 1 do
            for ty = room.y, room.y + room.h - 1 do
                addTile(tx, ty)
            end
        end
    end

    for i = 1, #rooms - 1 do
        local ax, ay = center(rooms[i])
        local bx, by = center(rooms[i+1])
        local cx, cy = ax, ay
        while cx ~= bx do addTile(cx,cy); cx = cx+(bx>cx and 1 or -1) end
        while cy ~= by do addTile(cx,cy); cy = cy+(by>cy and 1 or -1) end
        addTile(bx, by)
    end

    return rooms, tileList, tileSet
end

-- ── Floor ────────────────────────────────────────────────────────────────────

local function spawnFloor(origin, tx, ty)
    local base = origin + Vector(tx * CFG.TileSize, ty * CFG.TileSize, 0)
    local gz   = groundZ(base)

    local ent = ents.Create("prop_physics")
    if not IsValid(ent) then return end
    ent:SetModel(FLOOR_MODEL)
    ent:SetPos(Vector(base.x, base.y, gz))
    ent:SetAngles(Angle(0, 0, 0))
    ent:Spawn(); ent:Activate(); freeze(ent)
    table.insert(Dungeon.Entities, ent)
end

-- ── Walls ────────────────────────────────────────────────────────────────────

--[[
    Strategy: stack multiple plates vertically to build a wall column.
    Each plate is the floor model (64x64) stood on its edge (roll=90).
    We stack enough of them to reach CFG.WallH.

    One plate stood on edge = 64 units tall, 64 units wide, ~2 units thick.
    Stack count = ceil(WallH / 64).
    Each plate centre is at gz + (i * 64) - 32  (i=1,2,3...)

    Yaw makes the wall face the correct direction:
      North: yaw=0
      South: yaw=180
      East:  yaw=90
      West:  yaw=270

    Wall placed at tile edge: offset ±0.5 * TileSize from tile centre.
--]]

local DIRS = {
    { dx= 0, dy=-1, ox= 0,   oy=-0.5, yaw=  0 },
    { dx= 0, dy= 1, ox= 0,   oy= 0.5, yaw=180 },
    { dx= 1, dy= 0, ox= 0.5, oy= 0,   yaw= 90 },
    { dx=-1, dy= 0, ox=-0.5, oy= 0,   yaw=270 },
}

local PLATE_SIZE = 64  -- metal_plate2x2 is 64 wide and 64 tall when stood upright

local function spawnWalls(origin, tileSet)
    local stackCount = math.ceil(CFG.WallH / PLATE_SIZE)

    for key in pairs(tileSet) do
        local tx, ty = key:match("(-?%d+),(-?%d+)")
        tx, ty = tonumber(tx), tonumber(ty)

        local base = origin + Vector(tx * CFG.TileSize, ty * CFG.TileSize, 0)
        local gz   = groundZ(base)

        for _, d in ipairs(DIRS) do
            if not tileSet[(tx+d.dx)..",".. (ty+d.dy)] then
                local wx = base.x + d.ox * CFG.TileSize
                local wy = base.y + d.oy * CFG.TileSize

                for i = 1, stackCount do
                    -- Centre each plate: first plate bottom sits at gz
                    local wz = gz + (i - 0.5) * PLATE_SIZE

                    local ent = ents.Create("prop_physics")
                    if not IsValid(ent) then continue end
                    ent:SetModel(WALL_MODEL)
                    ent:SetPos(Vector(wx, wy, wz))
                    -- roll=90 stands the flat plate upright like a wall
                    ent:SetAngles(Angle(0, d.yaw, 90))
                    ent:Spawn(); ent:Activate(); freeze(ent)
                    table.insert(Dungeon.Entities, ent)
                end
            end
        end
    end
end

-- ── Cleanup / Generate ───────────────────────────────────────────────────────

function Dungeon.Cleanup()
    for _, e in ipairs(Dungeon.Entities) do
        if IsValid(e) then e:Remove() end
    end
    Dungeon.Entities = {}
    print("Dungeon cleaned up.")
end

function Dungeon:Generate(origin)
    math.randomseed(os.time())
    print("Generating dungeon...")
    Dungeon.Cleanup()
    origin = origin or Vector(0, 0, 0)

    local rooms, tiles, tileSet = Dungeon.BuildLayout()
    for _, t in ipairs(tiles) do spawnFloor(origin, t.x, t.y) end
    spawnWalls(origin, tileSet)

    print(string.format("Done: %d rooms, %d tiles, %d ents.",
        #rooms, #tiles, #Dungeon.Entities))
end

-- ── Hooks & Commands ─────────────────────────────────────────────────────────

hook.Add("PlayerSpawn", "DungeonGen", function(ply)
    if ply:IsAdmin() and #Dungeon.Entities == 0 then
        Dungeon:Generate(ply:GetPos())
    end
end)

concommand.Add("dungeon_generate", function(ply)
    if not IsValid(ply) or ply:IsAdmin() then
        Dungeon:Generate(IsValid(ply) and ply:GetPos() or Vector(0,0,0))
    end
end)

concommand.Add("dungeon_cleanup", function(ply)
    if not IsValid(ply) or ply:IsAdmin() then Dungeon.Cleanup() end
end)