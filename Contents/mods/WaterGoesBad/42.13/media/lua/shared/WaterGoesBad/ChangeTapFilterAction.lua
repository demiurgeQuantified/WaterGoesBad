---@class ChangeTapFilterAction : ISPlumbItem
---@field character IsoGameCharacter
---@field modData table
---@field isAddFilter boolean
local ChangeTapFilterAction = ISPlumbItem:derive("WaterGoesBadChangeTapFilterAction")
ChangeTapFilterAction.__index = ChangeTapFilterAction


function ChangeTapFilterAction:isValid()
	return not ((self.modData.hasTapFilter == true) == self.isAddFilter)
			and ISPlumbItem.isValid(self)
end


function ChangeTapFilterAction:complete()
	self.modData.hasTapFilter = self.isAddFilter
	self.itemToPipe:transmitModData()

	local inventory = self.character:getInventory()
	if self.isAddFilter then
		local item = inventory:RemoveOneOf("WaterGoesBad.TapFilter", false)
		sendRemoveItemFromContainer(inventory, item)
	else
		local item = inventory:AddItem("WaterGoesBad.TapFilter")
		sendAddItemToContainer(inventory, item)
	end

	buildUtil.setHaveConstruction(self.itemToPipe:getSquare(), true)

	return true
end


---@param character IsoGameCharacter
---@param itemToPipe IsoObject
---@param wrench InventoryItem
---@param isAddFilter boolean
---@return self
---@nodiscard
function ChangeTapFilterAction:new(character, itemToPipe, wrench, isAddFilter)
	local o = ISPlumbItem.new(self, character, itemToPipe, wrench) ---@as ChangeTapFilterAction

	local modData = itemToPipe:getModData()
	modData.WaterGoesBad = modData.WaterGoesBad or {}

	o.modData = modData.WaterGoesBad
	o.isAddFilter = isAddFilter

	o.maxTime = o:getDuration()

	return o
end


_G[ChangeTapFilterAction.Type] = ChangeTapFilterAction


return ChangeTapFilterAction