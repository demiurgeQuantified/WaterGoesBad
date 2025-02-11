if isClient() then return end

local Filters = {}

---Finds all of the objects that draw their water from this object
---@see IsoObject.FindExternalWaterSource
---@param object IsoObject
---@return IsoObject[]
function Filters.findPlumbedObjects(object)
    local objSq = {x=object:getX(), y=object:getY(), z=object:getZ()}
    local plumbedObjects = {}

    local sq = getSquare(objSq.x, objSq.y, objSq.z - 1)
    local plumbedObject = Filters.findPlumbedObjectOnSquare(sq)
    table.insert(plumbedObjects, plumbedObject)

    for x = -1, 1 do
        for y = -1, 1 do
            if x ~= 0 or y ~= 0 then
                local sq = getSquare(objSq.x+x, objSq.y+y, objSq.z-1)
                local plumbedObject = Filters.findPlumbedObjectOnSquare(sq)
                table.insert(plumbedObjects, plumbedObject)
            end
        end
    end

    return plumbedObjects
end

---Finds any taps/baths/etc on a square that are plumbed to another object
---@see IsoObject.FindWaterSourceOnSquare
---@param square IsoGridSquare
---@return IsoObject?
function Filters.findPlumbedObjectOnSquare(square)
    if not square then return nil end
    local objects = square:getObjects()
    for i=0,objects:size()-1 do
        ---@type IsoObject
        local object = objects:get(i)
        if object:getUsesExternalWaterSource() then
            return object
        end
    end
    return nil
end

---@type Callback_OnWaterAmountChange
function Filters.handleWaterChange(object)
    local square = object:getSquare()
    local waterSource = SRainBarrelSystem:getIsoObjectOnSquare(square)
	if object ~= waterSource then return end
    local tainted = object:isTaintedWater()
    local plumbedObjects = Filters.findPlumbedObjects(object)
    for i = 1, #plumbedObjects do
        local tap = plumbedObjects[i]
        if not tap:getModData().hasFilter then
            tap:setTaintedWater(tainted)
            local args = {x=tap:getX(), y=tap:getY(), z=tap:getZ(), i=tap:getObjectIndex(), tainted=tainted}
            sendServerCommand('WaterGoesBad', 'setTainted', args)
        end
    end
end

Filters.init = function()
    if SandboxVars.WaterGoesBad.NeedFilterWater then
        Events.OnWaterAmountChange.Add(Filters.handleWaterChange)
    end
end

Events.OnInitGlobalModData.Add(Filters.init)

return Filters