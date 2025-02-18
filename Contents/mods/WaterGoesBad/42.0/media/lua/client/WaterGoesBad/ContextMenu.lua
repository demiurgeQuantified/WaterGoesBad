local ContextMenu = {}
local ChangeTapFilterAction = require("WaterGoesBad/timedActions/ChangeTapFilterAction")

---@param item InventoryItem
local function predicateNotBroken(item)
	return not item:isBroken()
end

---@param obj IsoObject
local function getMoveableDisplayName(obj)
	if not obj then return nil end
	if not obj:getSprite() then return nil end
	local props = obj:getSprite():getProperties()
	if props:Is("CustomName") then
		local name = props:Val("CustomName")
		if props:Is("GroupName") then
			name = props:Val("GroupName") .. " " .. name
		end
		return Translator.getMoveableDisplayName(name)
	end
	return nil
end

---@param itemToPipe IsoObject
---@param player number
---@param isAddFilter boolean
function ContextMenu.onFilterOptionPressed(itemToPipe, player, isAddFilter)
	local playerObj = getSpecificPlayer(player)

	local wrench = playerObj:getInventory():getFirstTagEvalRecurse(
		"PipeWrench", predicateNotBroken)
	ISWorldObjectContextMenu.equip(
		playerObj, playerObj:getPrimaryHandItem(), wrench, true)

	ISTimedActionQueue.add(
		ChangeTapFilterAction.new(
			playerObj, itemToPipe, wrench, isAddFilter))
end

---@param object IsoObject
function ContextMenu.isFilterable(object)
	return object:getProperties()
			and object:getProperties():Is(IsoFlagType.waterPiped)
			and object:getUsesExternalWaterSource()
end

---@type Callback_OnFillWorldObjectContextMenu
function ContextMenu.addFilterContextOption(player, context, worldObjects, test)
	if test or not SandboxVars.WaterGoesBad.NeedFilterWater then return end
	-- i'd prefer to instead not add the event at all when filters are disabled, but it was causing bugs
	local playerObj = getSpecificPlayer(player)

	local objects = worldObjects[1] and worldObjects[1]:getSquare():getObjects()
	if not objects then return end

	-- FIXME: fuck all this
	for i=0, objects:size()-1 do
		local object = objects:get(i)
		if ContextMenu.isFilterable(object) then
			local playerHasFilter = playerObj:getInventory():containsType(
				"WaterGoesBad.TapFilter")
			local playerHasWrench = playerObj:getInventory():containsTagEvalRecurse(
				"PipeWrench", predicateNotBroken)
			if not (playerHasFilter or playerHasWrench) then return end

			local modData = object:getModData().WaterGoesBad
			local hasFilter = modData and modData.hasTapFilter
			local objectName = getMoveableDisplayName(object) or ""
			local name = getText(
				hasFilter and "ContextMenu_WaterGoesBad_RemoveFilter" or "ContextMenu_WaterGoesBad_AddFilter", objectName)

			local option = context:addOption(
				name, object, ContextMenu.onFilterOptionPressed,
				player, not hasFilter)

			local tooltip
			if not (hasFilter or playerHasFilter) then
				tooltip = ISWorldObjectContextMenu.addToolTip()
				tooltip:setName(name)
				tooltip.description = getText(
					"Tooltip_NeedWrench", getItemNameFromFullType("WaterGoesBad.TapFilter"))
			elseif not playerHasWrench then
				tooltip = ISWorldObjectContextMenu.addToolTip()
				tooltip:setName(name)
				tooltip.description = getText(
					"Tooltip_NeedWrench", getItemNameFromFullType("Base.PipeWrench"))
			end
			if tooltip then
				option.notAvailable = true
				option.toolTip = tooltip
			end
		end
	end
end

Events.OnFillWorldObjectContextMenu.Add(ContextMenu.addFilterContextOption)

return ContextMenu