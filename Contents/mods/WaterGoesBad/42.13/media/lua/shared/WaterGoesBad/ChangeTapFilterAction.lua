---@class ChangeTapFilterAction : ISBaseTimedAction
---@field modData table
---@field isAddFilter boolean
---@field wrench InventoryItem
---@field tap IsoObject
---@field sound integer
local ChangeTapFilterAction = ISBaseTimedAction:derive("WaterGoesBadChangeTapFilterAction")
ChangeTapFilterAction.__index = ChangeTapFilterAction


function ChangeTapFilterAction:isValid()
	return not ((self.modData.hasTapFilter == true) == self.isAddFilter)
			and self.character:isEquipped(self.wrench)
end


function ChangeTapFilterAction:stopSound()
	self.character:stopOrTriggerSound(self.sound)
end


function ChangeTapFilterAction:stop()
	self:stopSound()
	ISBaseTimedAction.stop(self)
end


function ChangeTapFilterAction:perform()
	self:stopSound()
	ISBaseTimedAction.perform(self)
end


function ChangeTapFilterAction:complete()
	self.modData.hasTapFilter = self.isAddFilter
	self.tap:transmitModData()

	local inventory = self.character:getInventory()
	if self.isAddFilter then
		local item = inventory:RemoveOneOf("WaterGoesBad.TapFilter", false)
		sendRemoveItemFromContainer(inventory, item)
	else
		local item = inventory:AddItem("WaterGoesBad.TapFilter")
		sendAddItemToContainer(inventory, item)
	end

	buildUtil.setHaveConstruction(self.tap:getSquare(), true)

	return true
end


function ChangeTapFilterAction:update()
	self.character:faceThisObject(self.tap)

    self.character:setMetabolicTarget(Metabolics.MediumWork);
end


function ChangeTapFilterAction:start()
	self.sound = self.character:playSound("RepairWithWrench")
end


function ChangeTapFilterAction:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 100
end


---@param character IsoGameCharacter
---@param tap IsoObject
---@param wrench InventoryItem
---@param isAddFilter boolean
---@return self
---@nodiscard
function ChangeTapFilterAction:new(character, tap, wrench, isAddFilter)
	local o = ISBaseTimedAction.new(self, character) ---@as ChangeTapFilterAction

	local modData = tap:getModData()
	modData.WaterGoesBad = modData.WaterGoesBad or {}

	o.modData = modData.WaterGoesBad
	o.isAddFilter = isAddFilter
	o.tap = tap
	o.wrench = wrench
	o.sound = -1

	o.maxTime = o:getDuration()

	return o
end


_G[ChangeTapFilterAction.Type] = ChangeTapFilterAction


return ChangeTapFilterAction