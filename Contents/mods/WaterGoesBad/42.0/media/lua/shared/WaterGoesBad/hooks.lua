local WaterGoesBad = require("WaterGoesBad/WaterGoesBad")

local sandboxVars = SandboxVars.WaterGoesBad

---@type IsoObject
local isoObject = __classmetatables[IsoObject.class].__index

local old_isTaintedWater = isoObject.isTaintedWater
isoObject.isTaintedWater = function(self)
    if WaterGoesBad.isWaterExpired() and WaterGoesBad.isValidContainer(self) then
        if not sandboxVars.NeedFilterWater or not self:getUsesExternalWaterSource() then
            return old_isTaintedWater(self)
        else
            local modData = self:getModData().WaterGoesBad
            if not modData or not modData.hasTapFilter then
                return IsoObject.FindExternalWaterSource(self:getSquare()):isTaintedWater()
            end

            return false
        end
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
