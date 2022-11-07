local TimedActions = {}

TimedActions.ISAddTapFilter = ISPlumbItem:derive("ISAddTapFilter")

function TimedActions.ISAddTapFilter:new(character, itemToPipe, wrench, time)
	local o = ISPlumbItem.new(self, character, itemToPipe, wrench, time)
	o.modData = o.itemToPipe:getModData()
	return o
end

function TimedActions.ISAddTapFilter:isValid()
	return not self.modData.hasFilter and ISPlumbItem.isValid(self)
end

function TimedActions.ISAddTapFilter:perform()
	self.character:stopOrTriggerSound(self.sound)
	local obj = self.itemToPipe
	local args = { x=obj:getX(), y=obj:getY(), z=obj:getZ(), index=obj:getObjectIndex(), hasFilter = true }
	sendClientCommand(self.character, 'WaterGoesBad', 'changeFilter', args)

	buildUtil.setHaveConstruction(obj:getSquare(), true)

	-- needed to remove from queue / start next.
	ISBaseTimedAction.perform(self)
end

TimedActions.ISRemoveTapFilter = TimedActions.ISAddTapFilter:derive("ISRemoveTapFilter")

function TimedActions.ISRemoveTapFilter:isValid()
	return self.modData.hasFilter and ISPlumbItem.isValid(self)
end

function TimedActions.ISRemoveTapFilter:perform()
	self.character:stopOrTriggerSound(self.sound)
	local obj = self.itemToPipe
	local args = { x=obj:getX(), y=obj:getY(), z=obj:getZ(), index=obj:getObjectIndex(), hasFilter = false }
	sendClientCommand(self.character, 'WaterGoesBad', 'changeFilter', args)

	buildUtil.setHaveConstruction(obj:getSquare(), true)

	-- needed to remove from queue / start next.
	ISBaseTimedAction.perform(self)
end

return TimedActions