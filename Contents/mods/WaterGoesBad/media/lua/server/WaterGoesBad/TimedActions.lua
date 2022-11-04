ISAddTapFilter = ISBaseTimedAction:derive("ISPlumbItem")

function ISAddTapFilter:isValid()
	return self.character:isEquipped(self.wrench)
end

function ISAddTapFilter:update()
	self.character:faceThisObject(self.itemToPipe)
end

function ISAddTapFilter:start()
	self.sound = self.character:playSound("RepairWithWrench")
end

function ISAddTapFilter:stop()
	self.character:stopOrTriggerSound(self.sound)
    ISBaseTimedAction.stop(self);
end

function ISAddTapFilter:perform()
	self.character:stopOrTriggerSound(self.sound)
	local obj = self.itemToPipe
	local args = { x=obj:getX(), y=obj:getY(), z=obj:getZ(), index=obj:getObjectIndex() }
	sendClientCommand(self.character, 'WaterGoesBad', 'addFilter', args)

	buildUtil.setHaveConstruction(obj:getSquare(), true)

	-- needed to remove from queue / start next.
	ISBaseTimedAction.perform(self)
end

function ISAddTapFilter:new(character, itemToPipe, wrench, time)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
    o.itemToPipe = itemToPipe
	o.wrench = wrench
	o.stopOnWalk = true
	o.stopOnRun = true
	o.maxTime = time
	if o.character:isTimedActionInstant() then o.maxTime = 1 end
	return o
end
