local sandboxVars = SandboxVars.WaterGoesBad

local ClientCommands = {}

function ClientCommands.plumbObject(args)
    local square = getSquare(args.x, args.y, args.z)
    local object = square:getObjects():get(args.index)

    local tainted = false
    if sandboxVars.NeedFilterWater then
        local externalWaterSource = IsoObject.FindExternalWaterSource(square)
        tainted = externalWaterSource and externalWaterSource:isTaintedWater() or false
    end
    object:setTaintedWater(tainted)

    args = {x=args.x, y=args.y, z=args.z, i=args.index, tainted=tainted, external = true}
    sendServerCommand('WaterGoesBad', 'setTainted', args)
end

---@param x integer
---@param y integer
---@param z integer
---@param i integer
---@param addFilter boolean
function ClientCommands.changeFilter(x, y, z, i, addFilter)
    local square = getSquare(x, y, z)
    local object = square:getObjects():get(i) --[[@as IsoObject]]

    local shouldTaint
    if addFilter then
        shouldTaint = false
        object:setTaintedWater(false)
    else
        shouldTaint = IsoObject.FindExternalWaterSource(square):isTaintedWater()
        object:setTaintedWater(shouldTaint)
    end

    object:getModData().hasFilter = addFilter
    object:transmitModData()

    local args = {x=x, y=y, z=z, i=i, tainted=shouldTaint}
    sendServerCommand('WaterGoesBad', 'setTainted', args)
end

---@type Callback_OnClientCommand
local function handleClientCommand(module, command, player, args)
    if module == 'object' and command == 'plumbObject' then
        ClientCommands.plumbObject(args)
    elseif module == "WaterGoesBad" and command == "changeFilter" then
        ClientCommands.changeFilter(args.x, args.y, args.z, args.i, args.addFilter)
    end
end

Events.OnClientCommand.Add(handleClientCommand)

return ClientCommands