local WaterGoesBad = require("WaterGoesBad/WaterGoesBad")

---@type IsoObject
local isoObject = __classmetatables[IsoObject.class].__index

----------------------------------------------------------

-- Override the value of isTaintedWater if it's passed the expiration date
-- Necessary because we can't set an object's water tainted anymore

local old_isTaintedWater = isoObject.isTaintedWater
---@param self IsoObject
local function isTaintedWater(self)
    -- HACK: temporarily unhook the function so calls to isTaintedWater won't be recursive
    isoObject.isTaintedWater = old_isTaintedWater
    local retval = WaterGoesBad.shouldTaintContainer(self)
    isoObject.isTaintedWater = isTaintedWater
    return retval
end

isoObject.isTaintedWater = isTaintedWater

----------------------------------------------------------

-- Show the name of tainted water when getting the object's fluid ui name (not sure this is actually used)

local old_getFluidUiName = isoObject.getFluidUiName
isoObject.getFluidUiName = function(self)
    if WaterGoesBad.shouldTaintContainer(self) then
        return Fluid.TaintedWater:getTranslatedName()
    end
    return old_getFluidUiName(self)
end

----------------------------------------------------------

-- Replaces transferred water from taps with tainted water if it should be tainted

local old_transferFluidTo = isoObject.transferFluidTo
isoObject.transferFluidTo = function(self, fluidContainer, amount)
    local amountTransfered = old_transferFluidTo(self, fluidContainer, amount)
    if WaterGoesBad.shouldTaintContainer(self) then
        fluidContainer:adjustSpecificFluidAmount(Fluid.Water, fluidContainer:getSpecificFluidAmount(Fluid.Water) - amountTransfered)
        fluidContainer:addFluid(FluidType.TaintedWater, amountTransfered)
    end
    return amountTransfered
end

----------------------------------------------------------

-- Replaces the water moved to temporary containers (used for drinking from taps) with tainted water if it should be tainted

local old_moveFluidToTemporaryContainer = isoObject.moveFluidToTemporaryContainer
isoObject.moveFluidToTemporaryContainer = function(self, amount)
    local tempContainer = old_moveFluidToTemporaryContainer(self, amount)
    if WaterGoesBad.shouldTaintContainer(self) then
        local waterAmount = tempContainer:getSpecificFluidAmount(Fluid.Water)
        tempContainer:adjustSpecificFluidAmount(Fluid.Water, 0)
        tempContainer:addFluid(FluidType.TaintedWater, waterAmount)
    end
    return tempContainer
end

----------------------------------------------------------

-- When the game queries an object's fluid amount, check if the object needs to be updated

local old_getFluidAmount = isoObject.getFluidAmount

---@param self IsoObject
local function getFluidAmount(self)
    -- HACK: temporarily unhook the function so calls to getFluidAmount won't be recursive
    isoObject.getFluidAmount = old_getFluidAmount
    WaterGoesBad.updateObject(self)
    isoObject.getFluidAmount = getFluidAmount

    return old_getFluidAmount(self)
end

isoObject.getFluidAmount = getFluidAmount
