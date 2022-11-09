if isClient() then return end

do
	local old_stateToIsoObject = SRainBarrelGlobalObject.stateToIsoObject

	function SRainBarrelGlobalObject:stateToIsoObject(isoObject)
		local shouldTaint = self.taintedWater
		old_stateToIsoObject(self, isoObject)
		if shouldTaint ~= nil then
			isoObject:setTaintedWater(shouldTaint)
			self.taintedWater = shouldTaint
		end
	end
end

do
	local old_stateToIsoObject = SMetalDrumGlobalObject.stateToIsoObject

	function SMetalDrumGlobalObject:stateToIsoObject(isoObject)
		local shouldTaint = self.taintedWater
		old_stateToIsoObject(self, isoObject)
		if shouldTaint ~= nil then
			isoObject:setTaintedWater(shouldTaint)
			self.taintedWater = shouldTaint
		end
	end
end