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

-- Update the object when a drink context menu option is added
--  this is necessary because 42.9.0 moved this logic to the java side

Events.OnFillWorldObjectContextMenu.Add(function(playerNum, context, worldObjects, test)
    -- search submenus for drink option
    --  drink option is never in the root level
    for i = 1, context.subOptionNums do
        local childContext = context:getSubMenu(i)
        -- not really sure why but childContext:getOptionFromName didn't want to work here
        for j = 1, #childContext.options do
            local option = childContext.options[j]
            if option.name == getText("ContextMenu_Drink") and instanceof(option.param3, "IsoObject") then
                WaterGoesBad.updateObject(option.param3)
            end
        end
    end
end)
