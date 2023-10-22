if isClient() then return end


local barrelStateToIsoObject = SRainBarrelGlobalObject.stateToIsoObject

function SRainBarrelGlobalObject:stateToIsoObject(isoObject)
	local shouldTaint = self.taintedWater
	barrelStateToIsoObject(self, isoObject)
	if shouldTaint ~= nil then
		isoObject:setTaintedWater(shouldTaint)
		self.taintedWater = shouldTaint
	end
end

local drumStateToIsoObject = SMetalDrumGlobalObject.stateToIsoObject

function SMetalDrumGlobalObject:stateToIsoObject(isoObject)
	local shouldTaint = self.taintedWater
	drumStateToIsoObject(self, isoObject)
	if shouldTaint ~= nil then
		isoObject:setTaintedWater(shouldTaint)
		self.taintedWater = shouldTaint
	end
end