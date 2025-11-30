local ChangeTapFilterAction = require("WaterGoesBad/timedActions/ChangeTapFilterAction")
local Utils = require("WaterGoesBad/Utils")


local ContextMenu = {}


---@param item InventoryItem
---@return boolean
---@nodiscard
local function predicateNotBroken(item)
	return not item:isBroken()
end


---@param itemToPipe IsoObject
---@param player integer
---@param isAddFilter boolean
function ContextMenu.onFilterOptionPressed(itemToPipe, player, isAddFilter)
	local playerObj = getSpecificPlayer(player)

	local wrench = playerObj:getInventory():getFirstTagEvalRecurse(
		ItemTag.PIPE_WRENCH,
		predicateNotBroken
	)

	ISWorldObjectContextMenu.equip(
		playerObj,
		playerObj:getPrimaryHandItem(),
		wrench,
		true
	)

	ISTimedActionQueue.add(
		ChangeTapFilterAction:new(
			playerObj,
			itemToPipe,
			wrench,
			isAddFilter
		)
	)
end

---@param object IsoObject
function ContextMenu.isFilterable(object)
	return object:getProperties()
			and object:hasProperty(IsoFlagType.waterPiped)
			and object:getUsesExternalWaterSource()
end

---@param player integer
---@param context ISContextMenu
---@param worldObjects IsoObject[]
---@param test boolean
function ContextMenu.addFilterContextOption(player, context, worldObjects, test)
	---@diagnostic disable-next-line: undefined-field
	if test or not SandboxVars.WaterGoesBad.NeedFilterWater then
		return
	end

	local playerObj = getSpecificPlayer(player)

	local objects = worldObjects[1] and worldObjects[1]:getSquare():getObjects()
	if not objects then return end

	-- FIXME: fuck all this
	for i=0, objects:size()-1 do
		local object = objects:get(i)
		if ContextMenu.isFilterable(object) then
			local playerHasFilter = playerObj:getInventory():containsType("WaterGoesBad.TapFilter")
			local playerHasWrench = playerObj:getInventory():containsTagEvalRecurse(
				ItemTag.PIPE_WRENCH,
				predicateNotBroken
			)

			if not (playerHasFilter or playerHasWrench) then
				return
			end

			local modData = object:getModData().WaterGoesBad
			local hasFilter = modData and modData.hasTapFilter
			local name = getText(
				hasFilter and "ContextMenu_WaterGoesBad_RemoveFilter" or "ContextMenu_WaterGoesBad_AddFilter",
				Utils.getMoveableDisplayName(object)
			)

			local option = context:addOption(
				name,
				object,
				ContextMenu.onFilterOptionPressed,
				player,
				not hasFilter
			)

			local tooltip
			if not (hasFilter or playerHasFilter) then
				tooltip = ISWorldObjectContextMenu.addToolTip()
				tooltip:setName(name)
				tooltip.description = getText(
					"Tooltip_NeedWrench",
					getItemNameFromFullType("WaterGoesBad.TapFilter")
				)
			elseif not playerHasWrench then
				tooltip = ISWorldObjectContextMenu.addToolTip()
				tooltip:setName(name)
				tooltip.description = getText(
					"Tooltip_NeedWrench",
					getItemNameFromFullType(ItemKey.Weapon.PIPE_WRENCH:toString())
				)
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