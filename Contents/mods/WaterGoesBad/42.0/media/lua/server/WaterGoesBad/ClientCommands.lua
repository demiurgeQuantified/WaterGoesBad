local ClientCommands = {}

---@param x integer
---@param y integer
---@param z integer
---@param i integer
---@param addFilter boolean
function ClientCommands.changeFilter(x, y, z, i, addFilter)
    local square = getSquare(x, y, z)
    local object = square:getObjects():get(i) --[[@as IsoObject]]

    local modData = object:getModData()
    if not modData.WaterGoesBad then
        modData.WaterGoesBad = {}
    end
    modData = modData.WaterGoesBad

    modData.hasTapFilter = addFilter
    object:transmitModData()
end

---@type Callback_OnClientCommand
local function handleClientCommand(module, command, player, args)
    if module ~= "WaterGoesBad" then
        return
    end

    if command == "changeFilter" then
        ClientCommands.changeFilter(args.x, args.y, args.z, args.i, args.addFilter)
    end
end

Events.OnClientCommand.Add(handleClientCommand)

return ClientCommands