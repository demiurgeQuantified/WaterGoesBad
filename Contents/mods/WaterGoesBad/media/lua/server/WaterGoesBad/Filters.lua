local Filters = {}

---Finds all of the objects that draw their water from this object
---@see IsoObject.FindExternalWaterSource
---@param object IsoObject
function Filters.FindPlumbedObjects(object)
    local objSq = {x=object:getX(),y=object:getY(),z=object:getZ()}
    local plumbedObjects = {}
    
    local sq = getSquare(objSq.x,objSq.y,objSq.z-1)
    if sq then
        local plumbedObject = Filters.FindPlumbedObjectOnSquare(sq)
        table.insert(plumbedObjects, plumbedObject)
    end

    for x = -1, 1 do
        for y = -1, 1 do
            if x ~= 0 or y ~= 0 then
                sq = getSquare(objSq.x+x,objSq.y+y,objSq.z-1)
                if sq then
                    local plumbedObject = Filters.FindPlumbedObjectOnSquare(sq)
                    table.insert(plumbedObjects, plumbedObject)
                end
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

---@param object IsoObject
function Filters.OnWaterAmountChange(object)
    if not SRainBarrelSystem.instance and SRainBarrelSystem.instance:getLuaObjectOnSquare(object:getSquare()) then return end
    local tainted = object:isTaintedWater()
    local plumbedObjects = Filters.FindPlumbedObjects(object)
    for _,tap in ipairs(plumbedObjects) do
        if not tap:getModData().hasFilter then
            tap:setTaintedWater(tainted)
            tap:transmitCompleteItemToClients()
        end
    end
end

return Filters