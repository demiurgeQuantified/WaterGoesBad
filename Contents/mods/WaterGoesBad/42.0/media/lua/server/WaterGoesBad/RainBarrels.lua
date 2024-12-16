if isClient() then return end

-- TODO: is this still necessary?

local barrelStateToIsoObject = SRainBarrelGlobalObject.stateToIsoObject

function SRainBarrelGlobalObject:stateToIsoObject(isoObject)
	local shouldTaint = self.taintedWater
	barrelStateToIsoObject(self, isoObject)
	if shouldTaint ~= nil then
		isoObject:setTaintedWater(shouldTaint)
		self.taintedWater = shouldTaint
	end
end
