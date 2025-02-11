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
