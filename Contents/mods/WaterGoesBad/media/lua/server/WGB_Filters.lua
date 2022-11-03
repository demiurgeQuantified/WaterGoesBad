if isClient() then return end

local old_loadIsoObject = SRainBarrelSystem.loadIsoObject or nil -- doesn't exist in vanilla, but might ensure mod compatibility

function SRainBarrelSystem:loadIsoObject(isoObject)
	if old_loadIsoObject then old_loadIsoObject(self, isoObject) else SGlobalObjectSystem.loadIsoObject(self, isoObject) end
	if not isoObject:getModData()['isTainted'] == nil then
		isoObject:setTaintedWater(isoObject:getModData()['isTainted'])
	end
end

local old_checkRain = SRainBarrelSystem.checkRain

function SRainBarrelSystem:checkRain()
	old_checkRain(self)
	for i=1,self:getLuaObjectCount() do
		local luaObject = self:getLuaObjectByIndex(i)
		local isoObject = luaObject:getIsoObject()
		isoObject:getModData()['isTainted'] = isoObject:isTaintedWater()
	end
end

local function OnWaterAmountChange(isoObject)
	if not isoObject then return end
	local luaObject = SRainBarrelSystem.instance:getLuaObjectAt(isoObject:getX(), isoObject:getY(), isoObject:getZ())
	if luaObject then
		isoObject:getModData()['isTainted'] = isoObject:isTaintedWater()
	end
end

Events.OnWaterAmountChange.Add(OnWaterAmountChange)