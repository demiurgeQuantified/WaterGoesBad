ISAddTapFilter = ISPlumbItem:derive("ISAddTapFilter")

function ISAddTapFilter:new(character, itemToPipe, wrench, time)
	local o = ISPlumbItem.new(self, character, itemToPipe, wrench, time)
	o.modData = o.itemToPipe:getModData()
	return o
end

function ISAddTapFilter:isValid()
	return not self.modData.hasFilter and ISPlumbItem.isValid(self)
end

function ISAddTapFilter:perform()
	self.character:stopOrTriggerSound(self.sound)
	local obj = self.itemToPipe
	local args = { x=obj:getX(), y=obj:getY(), z=obj:getZ(), index=obj:getObjectIndex(), hasFilter = true }
	sendClientCommand(self.character, 'WaterGoesBad', 'changeFilter', args)

	buildUtil.setHaveConstruction(obj:getSquare(), true)

	-- needed to remove from queue / start next.
	ISBaseTimedAction.perform(self)
end

ISRemoveTapFilter = ISAddTapFilter:derive("ISRemoveTapFilter")

function ISRemoveTapFilter:isValid()
	return self.modData.hasFilter and ISPlumbItem.isValid(self)
end

function ISRemoveTapFilter:perform()
	self.character:stopOrTriggerSound(self.sound)
	local obj = self.itemToPipe
	local args = { x=obj:getX(), y=obj:getY(), z=obj:getZ(), index=obj:getObjectIndex(), hasFilter = false }
	sendClientCommand(self.character, 'WaterGoesBad', 'changeFilter', args)

	buildUtil.setHaveConstruction(obj:getSquare(), true)

	-- needed to remove from queue / start next.
	ISBaseTimedAction.perform(self)
end