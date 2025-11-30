local ChangeTapFilterAction = require("WaterGoesBad/ChangeTapFilterAction")
local Utils = require("WaterGoesBad/Utils")


local ContextMenu = {}


---@param item InventoryItem
---@return boolean
---@nodiscard
local function predicateNotBroken(item)
	return not item:isBroken()
end


---@param itemToPipe IsoObject
---@param player IsoPlayer
---@param isAddFilter boolean
function ContextMenu.onFilterOptionPressed(itemToPipe, player, isAddFilter)
	local wrench = player:getInventory():getFirstTagEvalRecurse(
		ItemTag.PIPE_WRENCH,
		predicateNotBroken
	)

	ISWorldObjectContextMenu.equip(
		player,
		player:getPrimaryHandItem(),
		wrench,
		true
	)

	ISTimedActionQueue.add(
		ChangeTapFilterAction:new(
			player,
			itemToPipe,
			wrench,
			isAddFilter
		)
	)
end


---@param object IsoObject
function ContextMenu.isFilterable(object)
	return object:hasProperty(IsoFlagType.waterPiped) and object:getUsesExternalWaterSource()
end


---Marks a Drink option as tainted if the sink is plumbed to a tainted water source.
---@param option umbrella.ISContextMenu.Option
local function updateDrinkOption(option)
	if option.toolTip == nil then
		return
	end

	local object = option.param3
	if not instanceof(object, "IsoObject") then
		-- we are writing defensively here because we search for these by name
		-- which could easily hit something else by some mod
		return
	end
	---@cast object IsoObject

	if not Utils.hasFilter(object) and object:getUsesExternalWaterSource() and object:FindExternalWaterSource():isTaintedWater() then
		option.toolTip.description = string.format(
			"%s <BR> <RGB:1,0.5,0.5> %s",
			option.toolTip.description,
			Translator.getText("Tooltip_item_TaintedWater")
		)
	end
end


---Marks Drink options as tainted for sinks that are plumbed to a tainted water source.
---@param context ISContextMenu
local function updateTaintedWaterTooltips(context)
	local DRINK_TEXT = getText("ContextMenu_Drink")

	for i = 1, #context.options do
		local option = context.options[i]
		if option.subOption then
			local submenu = context:getSubInstance(option.subOption)
			assert(submenu ~= nil)
			local drinkOption = submenu:getOptionFromName(DRINK_TEXT)
			if drinkOption then
				updateDrinkOption(drinkOption)
			end
		end
	end
end


---@param context ISContextMenu
---@param player IsoPlayer
---@param objects IsoObject[]
local function addFilterContextOption(context, player, objects)
	for i = 1, #objects do
		local object = objects[i]
		if ContextMenu.isFilterable(object) then
			local inventory = player:getInventory()
			local playerHasFilter = inventory:containsType("WaterGoesBad.TapFilter")
			local playerHasWrench = inventory:containsTagEvalRecurse(
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


---@param playerNum integer
---@param context ISContextMenu
---@param worldObjects IsoObject[]
---@param test boolean
function ContextMenu.addFilterContextOption(playerNum, context, worldObjects, test)
	---@diagnostic disable-next-line: undefined-field
	if test or not SandboxVars.WaterGoesBad.NeedFilterWater then
		return
	end

	if SandboxVars.EnableTaintedWaterText then
		updateTaintedWaterTooltips(context)
	end

	-- not sure if this ever actually happens, but just in case
	if #worldObjects < 1 then
		return
	end
	---@diagnostic disable-next-line: need-check-nil
	local objects = worldObjects[1]:getSquare():getLuaTileObjectList()

	addFilterContextOption(
		context,
		getSpecificPlayer(playerNum),
		objects
	)
end

Events.OnFillWorldObjectContextMenu.Add(ContextMenu.addFilterContextOption)


return ContextMenu