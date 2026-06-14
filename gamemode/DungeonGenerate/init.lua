print("Dungeon Loaded")
local function DungeonLoad()
    math.randomseed(os.time())
    Dungeon.Generate = function()
        print("Generating Dungeon...")
        local loopHoles = 0
        local maxLoopHoles = 1000
        while loopHoles < math.random(0, maxLoopHoles) do
            loopHoles = loopHoles + 1
        end

        function Dungeon.GenerateRoom()
            print("Generating Room...")
            local roomSize = math.random(5, 15)
            local room = {}
            for i = 1, roomSize do
                table.insert(room, {
                    x = math.random(0, 100),
                    y = math.random(0, 100)
                })
            end
            return room
        end

        function Dungeon.GenerateCorridor()
            print("Generating Corridor...")
            local corridorLength = math.random(3, 10)
            local corridor = {}
            for i = 1, corridorLength do
                table.insert(corridor, {
                    x = math.random(0, 100),
                    y = math.random(0, 100)
                })
            end
            return corridor
        end

        function buildDungeon()
            local dungeon = {}
            local numRooms = math.random(5, 10)
            for i = 1, numRooms do
                table.insert(dungeon, Dungeon.GenerateRoom())
                if i < numRooms then table.insert(dungeon, Dungeon.GenerateCorridor()) end
            end
            return dungeon
        end
    end
end