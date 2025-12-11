if isClient() then
    return
end

local Utils = require("WaterGoesBad/Utils")



local originalTransferFluid = ISTakeWaterAction.transferFluid
function ISTakeWaterAction:transferFluid(amount)
    if not self.waterObject:getUsesExternalWaterSource() or Utils.hasFilter(self.waterObject) then
        originalTransferFluid(self, amount)
        return
    end

    -- could be a subtype and lua overrides do not propagate down
    --  so we just get the metatable of whatever class this object is
    ---@type IsoObject
    local objectMetatable = getmetatable(self.waterObject).__index

    local originalMoveFluidToTemporaryContainer = objectMetatable.moveFluidToTemporaryContainer
    function objectMetatable:moveFluidToTemporaryContainer(amount)
        return self:FindExternalWaterSource():moveFluidToTemporaryContainer(amount)
    end

    local originalTransferFluidTo = objectMetatable.transferFluidTo
    function objectMetatable:transferFluidTo(fluidContainer, amount)
        return self:FindExternalWaterSource():transferFluidTo(fluidContainer, amount)
    end

    originalTransferFluid(self, amount)

    objectMetatable.moveFluidToTemporaryContainer = originalMoveFluidToTemporaryContainer
    objectMetatable.transferFluidTo = originalTransferFluidTo
end
