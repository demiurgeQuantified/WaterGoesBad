local ContextMenu = {}
local TimedActions = require 'WaterGoesBad/TimedActions'

local function predicateNotBroken(item)
	return not item:isBroken()
end

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
function ContextMenu.onFilterAction(itemToPipe, player, isAddFilter)
	local playerObj = getSpecificPlayer(player)

	local wrench = playerObj:getInventory():getFirstTagEvalRecurse('PipeWrench', predicateNotBroken)
	ISWorldObjectContextMenu.equip(playerObj, playerObj:getPrimaryHandItem(), wrench, true)

	ISTimedActionQueue.add(TimedActions.ISChangeTapFilter:new(playerObj, itemToPipe, wrench, isAddFilter, 100))
end

---@param object IsoObject
function ContextMenu.isFilterable(object)
	return object:getProperties() and object:getProperties():Is(IsoFlagType.waterPiped) and object:getUsesExternalWaterSource()
end

function ContextMenu.OnFillWorldObjectContextMenu(player, context, worldObjects, test)
	if not SandboxVars.WaterGoesBad.NeedFilterWater then return end
	-- i'd prefer to instead not add the event at all when filters are disabled, but it was causing bugs
	local playerObj = getSpecificPlayer(player)
	local objects = worldObjects[1] and worldObjects[1]:getSquare():getObjects()
	for i=0, objects:size()-1 do
		local object = objects:get(i)
		if ContextMenu.isFilterable(object) then
			local playerHasFilter = playerObj:getInventory():containsType('WaterGoesBad.TapFilter')
			local playerHasWrench = playerObj:getInventory():containsTagEvalRecurse('PipeWrench', predicateNotBroken)
			if not (playerHasFilter or playerHasWrench) then return end

			local hasFilter = object:getModData().hasFilter
			local name = getMoveableDisplayName(object) or ''
			local translation = 'ContextMenu_AddFilter'
			if hasFilter then translation = 'ContextMenu_RemoveFilter' end

			local option = context:addOption(getText(translation, name), object, ContextMenu.onFilterAction, player, not hasFilter)

			local tooltip
			if not (hasFilter or playerHasFilter) then
				tooltip = ISWorldObjectContextMenu.addToolTip()
				tooltip:setName(getText(translation, name))
				tooltip.description = getText('Tooltip_NeedWrench', getItemNameFromFullType('WaterGoesBad.TapFilter'))
			elseif not playerHasWrench then
				tooltip = ISWorldObjectContextMenu.addToolTip()
				tooltip:setName(getText(translation, name))
				tooltip.description = getText('Tooltip_NeedWrench', getItemNameFromFullType('Base.PipeWrench'))
			end
			if tooltip then
				option.notAvailable = true
				option.toolTip = tooltip
			end
		end
	end
end

Events.OnFillWorldObjectContextMenu.Add(ContextMenu.OnFillWorldObjectContextMenu)

return ContextMenu