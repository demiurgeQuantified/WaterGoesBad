local TimedActions = {}

TimedActions.ISChangeTapFilter = ISPlumbItem:derive("ISChangeTapFilter")

function TimedActions.ISChangeTapFilter:new(character, itemToPipe, wrench, isAddFilter, time)
	local o = ISPlumbItem.new(self, character, itemToPipe, wrench, time)
	o.modData = o.itemToPipe:getModData()
	o.isAddFilter = isAddFilter
	return o
end

function TimedActions.ISChangeTapFilter:isValid()
	return (self.modData.hasFilter == self.isAddFilter) and ISPlumbItem.isValid(self)
end

function TimedActions.ISChangeTapFilter:perform()
	self.character:stopOrTriggerSound(self.sound)
	local obj = self.itemToPipe
	local args = { x=obj:getX(), y=obj:getY(), z=obj:getZ(), index=obj:getObjectIndex(), self.isAddFilter }
	sendClientCommand(self.character, 'WaterGoesBad', 'changeFilter', args)
	
	if self.isAddFilter then
		self.character:getInventory():RemoveOneOf('WaterGoesBad.TapFilter')
	else
		self.character:getInventory():AddItem('WaterGoesBad.TapFilter')
	end

	buildUtil.setHaveConstruction(obj:getSquare(), true)

	-- needed to remove from queue / start next.
	ISBaseTimedAction.perform(self)
end