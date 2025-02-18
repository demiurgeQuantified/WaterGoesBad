---@class ChangeTapFilterAction : ISPlumbItem
---@field character IsoGameCharacter
---@field modData table
---@field isAddFilter boolean
local ChangeTapFilterAction = ISPlumbItem:derive("ChangeTapFilterAction")
ChangeTapFilterAction.__index = ChangeTapFilterAction

---@param character IsoGameCharacter
---@param itemToPipe IsoObject
---@param wrench InventoryItem
---@param isAddFilter boolean
function ChangeTapFilterAction.new(character, itemToPipe, wrench, isAddFilter)
	local o = ISPlumbItem:new(character, itemToPipe, wrench)
	setmetatable(o, ChangeTapFilterAction)

	local modData = itemToPipe:getModData()
	modData.WaterGoesBad = modData.WaterGoesBad or {}

	o.modData = modData.WaterGoesBad
	o.isAddFilter = isAddFilter
	return o
end

function ChangeTapFilterAction:isValid()
	return not ((self.modData.hasTapFilter == true) == self.isAddFilter)
			and ISPlumbItem.isValid(self)
end

function ChangeTapFilterAction:perform()
	self.character:stopOrTriggerSound(self.sound)
	sendClientCommand(
		"WaterGoesBad", "changeFilter",
		{
			x=self.itemToPipe:getX(), y=self.itemToPipe:getY(), z=self.itemToPipe:getZ(),
			i=self.itemToPipe:getObjectIndex(), addFilter=self.isAddFilter
		})

	-- TODO: when MP comes out this will probably need to move to the server
	if self.isAddFilter then
		self.character:getInventory():RemoveOneOf("WaterGoesBad.TapFilter")
	else
		self.character:getInventory():AddItem("WaterGoesBad.TapFilter")
	end

	buildUtil.setHaveConstruction(self.itemToPipe:getSquare(), true)

	-- needed to remove from queue / start next.
	ISBaseTimedAction.perform(self)
end

return ChangeTapFilterAction