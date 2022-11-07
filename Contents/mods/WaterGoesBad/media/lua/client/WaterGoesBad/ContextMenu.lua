local ContextMenu = {}

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

function ContextMenu.onAddFilter(worldobjects, player, itemToPipe)
	local playerObj = getSpecificPlayer(player)
	local wrench = playerObj:getInventory():getFirstTypeEvalRecurse('PipeWrench', predicateNotBroken);
	ISWorldObjectContextMenu.equip(playerObj, playerObj:getPrimaryHandItem(), wrench, true)
	ISTimedActionQueue.add(ISAddTapFilter:new(playerObj, itemToPipe, wrench, 100));
end

function ContextMenu.onRemoveFilter(worldobjects, player, itemToPipe)
	local playerObj = getSpecificPlayer(player)
	local wrench = playerObj:getInventory():getFirstTypeEvalRecurse('PipeWrench', predicateNotBroken);
	ISWorldObjectContextMenu.equip(playerObj, playerObj:getPrimaryHandItem(), wrench, true)
	ISTimedActionQueue.add(ISRemoveTapFilter:new(playerObj, itemToPipe, wrench, 100));
end

function ContextMenu.isFilterable(object)
	return object:getProperties():Is(IsoFlagType.waterPiped) and object:getUsesExternalWaterSource()
end

function ContextMenu.OnFillWorldObjectContextMenu(player, context, worldObjects, test)
	local playerObj = getSpecificPlayer(player)
	for _,object in ipairs(worldObjects) do
		if ContextMenu.isFilterable(object) then
			if not object:getModData().hasFilter then
				local name = getMoveableDisplayName(object) or ''
				local option = context:addOption(getText('ContextMenu_AddFilter', name), worldObjects, ContextMenu.onAddFilter, player, object)
				if not playerObj:getInventory():containsTypeEvalRecurse('PipeWrench', predicateNotBroken) then
					option.notAvailable = true
					local tooltip = ISWorldObjectContextMenu.addToolTip()
					tooltip:setName(getText('ContextMenu_AddFilter', name))
					local usedItem = InventoryItemFactory.CreateItem('Base.PipeWrench')
					tooltip.description = getText('Tooltip_NeedWrench', usedItem:getName())
					option.toolTip = tooltip
				end
			else
				local name = getMoveableDisplayName(object) or ''
				local option = context:addOption(getText('ContextMenu_RemoveFilter', name), worldObjects, ContextMenu.onRemoveFilter, player, object)
				if not playerObj:getInventory():containsTypeEvalRecurse('PipeWrench', predicateNotBroken) then
					option.notAvailable = true
					local tooltip = ISWorldObjectContextMenu.addToolTip()
					tooltip:setName(getText('ContextMenu_AddFilter', name))
					local usedItem = InventoryItemFactory.CreateItem('Base.PipeWrench')
					tooltip.description = getText('Tooltip_NeedWrench', usedItem:getName())
					option.toolTip = tooltip
				end
			end
		end
	end
end

Events.OnFillWorldObjectContextMenu.Add(ContextMenu.OnFillWorldObjectContextMenu)

return ContextMenu