local Filters = {}

function Filters.FindPlumbedTaps(object) -- reverse FindExternalWaterSource
    local objSq = {x=object:getX(),y=object:getY(),z=object:getZ()}
    local plumbedTaps = {}
    
    local sq = getSquare(objSq.x,objSq.y,objSq.z-1)
    if sq then
        local waterSource = IsoObject.FindWaterSourceOnSquare(sq)
        if waterSource and waterSource:getUsesExternalWaterSource() then
            table.insert(plumbedTaps, waterSource)
        end
    end

    for x = -1,1 do
        for y= -1,1 do
            sq = getSquare(objSq.x+x,objSq.y+y,objSq.z-1)
            if sq then
                local waterSource = IsoObject.FindWaterSourceOnSquare(sq)
                if waterSource and waterSource:getUsesExternalWaterSource() and not waterSource:getModData().hasFilter then
                    table.insert(plumbedTaps, waterSource)
                end
            end
        end
    end

    return plumbedTaps
end

function Filters.OnWaterAmountChange(object, waterAmount)
    if not SRainBarrelSystem:getLuaObjectOnSquare(object:getSquare()) then return end
    local tainted = object:isTaintedWater()
    local plumbedTaps = Filters.FindPlumbedTaps(object)
    for _,tap in ipairs(plumbedTaps) do
        tap:setTaintedWater(tainted)
        tap:transmitCompleteItemToClients()
    end
end

if SandboxVars.WaterGoesBad.NeedFilterWater then
    Events.OnWaterAmountChange.Add(Filters.OnWaterAmountChange)
end

return Filters