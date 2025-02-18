local WaterGoesBad = require("WaterGoesBad/WaterGoesBad")

---@type IsoObject
local isoObject = __classmetatables[IsoObject.class].__index

local old_isTaintedWater = isoObject.isTaintedWater
isoObject.isTaintedWater = function(self)
    if WaterGoesBad.isWaterExpired() and WaterGoesBad.isValidContainer(self)
            and not self:getUsesExternalWaterSource() then
        return true
    end
    return old_isTaintedWater(self)
end

local old_getWaterAmount = isoObject.getWaterAmount

---@param self IsoObject
local function getWaterAmount(self)

    -- HACK: temporarily unhook the function so calls to getWaterAmount in updateObject won't be recursive
    isoObject.getWaterAmount = old_getWaterAmount
    WaterGoesBad.updateObject(self)
    isoObject.getWaterAmount = getWaterAmount

    return old_getWaterAmount(self)
end

isoObject.getWaterAmount = getWaterAmount
