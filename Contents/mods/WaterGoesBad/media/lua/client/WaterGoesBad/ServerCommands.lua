local ServerCommands = {}

---@param x integer
---@param y integer
---@param z integer
---@param i integer
---@param tainted boolean
---@param external? boolean
function ServerCommands.setTainted(x, y, z, i, tainted, external)
    local square = getSquare(x, y, z)
    if square then
        ---@type IsoObject
        local object = square:getObjects():get(i)
        object:setTaintedWater(tainted)

        -- vanilla fails to sync this for washers/dryers, due to overriding the method responsible for handling updates
        if external ~= nil then
            object:setUsesExternalWaterSource(true)
        end
    end
end

---@param squareDatas table[]
function ServerCommands.updateSquares(squareDatas)
    -- print("[WaterGoesBad] received data for " .. #squareDatas .. " squares")
    local squares = {}
    for i = 1, #squareDatas do
        local squareData = squareDatas[i]
        local square = getSquare(squareData.x, squareData.y, squareData.z)
        -- doesn't matter if this is nil
        squares[i] = square
    end

    local stride = SandboxVars.WaterGoesBad.ReduceWaterOverTime and 2 or 1

    for i = 1, #squareDatas do
        local square = squares[i]
        if square then
            local squareData = squareDatas[i]
            ---@type IsoObject[]
            local objects = square:getLuaTileObjectList()
            for j = 1, #squareData, stride do
                objects[squareData[j]]:setTaintedWater(true)
            end
        end
    end

    if SandboxVars.WaterGoesBad.ReduceWaterOverTime then
        for i = 1, #squareDatas do
            local square = squares[i]
            if square then
                local squareData = squareDatas[i]
                ---@type IsoObject[]
                local objects = square:getLuaTileObjectList()
                for j = 1, #squareData, stride do
                    objects[squareData[j]]:setWaterAmount(squareData[j+1])
                end
            end
        end
    end
end

---@type Callback_OnServerCommand
local function onServerCommand(module, command, args)
    if module == "WaterGoesBad" then
        if command == "setTainted" then
            ServerCommands.setTainted(args.x, args.y, args.z, args.i, args.tainted, args.external)
        elseif command == "updateSquares" then
            ServerCommands.updateSquares(args)
        end
    end
end

Events.OnServerCommand.Add(onServerCommand)

return ServerCommands