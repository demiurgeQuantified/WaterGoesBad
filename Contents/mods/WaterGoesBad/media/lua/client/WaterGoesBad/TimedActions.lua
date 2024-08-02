---@class ChangeTapFilterAction : ISPlumbItem
---@field modData table
---@field isAddFilter boolean
local ChangeTapFilterAction = ISPlumbItem:derive("ChangeTapFilterAction")

function ChangeTapFilterAction:new(character, itemToPipe, wrench, isAddFilter, time)
	local o = ISPlumbItem.new(self, character, itemToPipe, wrench, time)
	o.modData = o.itemToPipe:getModData()
	o.isAddFilter = isAddFilter
	return o
end

function ChangeTapFilterAction:isValid()
	return not (self.modData.hasFilter == self.isAddFilter) and ISPlumbItem.isValid(self)
end

function ChangeTapFilterAction:perform()
	self.character:stopOrTriggerSound(self.sound)
	local obj = self.itemToPipe
	local args = { x=obj:getX(), y=obj:getY(), z=obj:getZ(), i=obj:getObjectIndex(), addFilter=self.isAddFilter }
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

local TimedActions = {}
TimedActions.ChangeTapFilterAction = ChangeTapFilterAction

return TimedActions