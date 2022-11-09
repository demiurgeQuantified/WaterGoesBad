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

	local wrench = playerObj:getInventory():getFirstTypeEvalRecurse('PipeWrench', predicateNotBroken)
	ISWorldObjectContextMenu.equip(playerObj, playerObj:getPrimaryHandItem(), wrench, true)

	ISTimedActionQueue.add(TimedActions.ISChangeTapFilter:new(playerObj, itemToPipe, wrench, isAddFilter, 100))
end

---@param object IsoObject
function ContextMenu.isFilterable(object)
	return object:getProperties():Is(IsoFlagType.waterPiped) and object:getUsesExternalWaterSource()
end

function ContextMenu.OnFillWorldObjectContextMenu(player, context, worldObjects, test)
	local playerObj = getSpecificPlayer(player)
	for _,object in ipairs(worldObjects) do
		if ContextMenu.isFilterable(object) then
			local hasFilter = object:getModData().hasFilter

			local name = getMoveableDisplayName(object) or ''
			local translation = 'ContextMenu_AddFilter'
			if hasFilter then translation = 'ContextMenu_RemoveFilter' end

			local option = context:addOption(getText(translation, name), object, ContextMenu.onFilterAction, player, not hasFilter)

			local tooltip = nil
			if not playerObj:getInventory():containsType('WaterGoesBad.TapFilter') then
				tooltip = ISWorldObjectContextMenu.addToolTip()
				tooltip:setName(getText('ContextMenu_AddFilter', name))
				tooltip.description = getText('Tooltip_NeedWrench', getText('ItemName_WaterGoesBad.TapFilter'))
			elseif not playerObj:getInventory():containsTypeEvalRecurse('PipeWrench', predicateNotBroken) then
				tooltip = ISWorldObjectContextMenu.addToolTip()
				tooltip:setName(getText('ContextMenu_AddFilter', name))
				tooltip.description = getText('Tooltip_NeedWrench', getText('ItemName_Base.PipeWrench'))
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