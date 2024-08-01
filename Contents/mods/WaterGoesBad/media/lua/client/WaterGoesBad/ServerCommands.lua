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

local function onServerCommand(module, command, args)
    if module == 'WaterGoesBad' and command == "setTainted" then
        ServerCommands.setTainted(args.x, args.y, args.z, args.i, args.tainted, args.external)
    end
end

Events.OnServerCommand.Add(onServerCommand)