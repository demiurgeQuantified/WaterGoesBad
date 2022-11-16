if isClient() then return end

-- global objects were fixed in 41.78, or something
--[[do
	local old_loadIsoObject = SGlobalObjectSystem.loadIsoObject

	function SGlobalObjectSystem:loadIsoObject(isoObject)
		isoObject:addToWorld()
		old_loadIsoObject(self, isoObject)
	end
end]]

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