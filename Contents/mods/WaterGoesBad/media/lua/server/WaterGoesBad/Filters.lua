if isClient() then return end

local Filters = {}

---Finds all of the objects that draw their water from this object
---@see IsoObject.FindExternalWaterSource
---@param object IsoObject
function Filters.FindPlumbedObjects(object)
    local objSq = {x=object:getX(),y=object:getY(),z=object:getZ()}
    local plumbedObjects = {}
    
    local sq = getSquare(objSq.x,objSq.y,objSq.z-1)
    local plumbedObject = Filters.FindPlumbedObjectOnSquare(sq)
    table.insert(plumbedObjects, plumbedObject)

    for x = -1, 1 do
        for y = -1, 1 do
            if x ~= 0 or y ~= 0 then
                sq = getSquare(objSq.x+x,objSq.y+y,objSq.z-1)
                local plumbedObject = Filters.FindPlumbedObjectOnSquare(sq)
                table.insert(plumbedObjects, plumbedObject)
            end
        end
    end

    return plumbedObjects
end

---Finds any taps/baths/etc on a square that are plumbed to another object
---@see IsoObject.FindWaterSourceOnSquare
---@param square IsoGridSquare
function Filters.FindPlumbedObjectOnSquare(square)
    if not square then return nil end
    local objects = square:getObjects()
    for i=0,objects:size()-1 do
        local object = objects:get(i)
        if instanceof(object, 'IsoObject') and object:getUsesExternalWaterSource() then
            return object
        end
    end
    return nil
end

function Filters.OnWaterAmountChange(object)
	if not object then return end
	local luaObject = SRainBarrelSystem.instance:getLuaObjectAt(object:getX(), object:getY(), object:getZ())
	if luaObject then
        local tainted = object:isTaintedWater()
        local plumbedObjects = Filters.FindPlumbedObjects(object)
        for _,tap in ipairs(plumbedObjects) do
            if not tap:getModData().hasFilter then
                tap:setTaintedWater(tainted)
                local args = {x=tap:getX(), y=tap:getY(), z=tap:getZ(), index=tap:getObjectIndex(), tainted=tainted}
                sendServerCommand('WaterGoesBad', 'setTainted', args)
            end
        end
    end
end

----------------------------------------------------------------------------------------------------------
-- client commands
----------------------------------------------------------------------------------------------------------
Filters.Commands = {}

function Filters.Commands.changeFilter(args)
    local sq = getSquare(args.x, args.y, args.z)
    if sq and args.index >= 0 and args.index < sq:getObjects():size() then
        local object = sq:getObjects():get(args.index)
        object:getModData().hasFilter = args.addFilter
        if args.addFilter then
            object:setTaintedWater(false)
        else
            object:setTaintedWater(IsoObject.FindExternalWaterSource(sq):isTaintedWater())
        end
        object:transmitModData()
        args = {x=args.x, y=args.y, z=args.z, index=args.index, tainted=object:isTaintedWater()}
        sendServerCommand('WaterGoesBad', 'setTainted', args)
    end
end

local function onClientCommand(module, command, player, args)
    if module ~= 'WaterGoesBad.Filters' then return end
    Filters.Commands[command](args)
end

Events.OnClientCommand.Add(onClientCommand)

return Filters