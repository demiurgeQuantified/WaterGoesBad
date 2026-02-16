local ChangeTapFilterAction = require("WaterGoesBad/ChangeTapFilterAction")
local Utils = require("WaterGoesBad/Utils")
local Registries = require("WaterGoesBad/Registries")


local DRINK_TEXT = getText("ContextMenu_Drink")


local ContextMenu = {}


---@param item InventoryItem
---@return boolean
---@nodiscard
local function predicateNotBroken(item)
    return not item:isBroken()
end


---@param object IsoObject
function ContextMenu.isFilterable(object)
    return object:hasProperty(IsoFlagType.waterPiped) and object:getUsesExternalWaterSource()
end


---@param object IsoObject
---@return boolean
---@nodiscard
local function shouldBeTainted(object)
    return not Utils.hasFilter(object) and object:getUsesExternalWaterSource() and object:FindExternalWaterSource():isTaintedWater()
end


---Adds tainted water text to an option's tooltip
---@param option umbrella.ISContextMenu.Option
local function addTaintedWaterTooltip(option)
    assert(option.toolTip ~= nil, "Drink option has no tooltip")

    option.toolTip.description = string.format(
        "%s <BR> <RGB:1,0.5,0.5> %s",
        option.toolTip.description,
        Translator.getText("Tooltip_item_TaintedWater")
    )
end


---@param context ISContextMenu
---@return table<IsoObject, ISContextMenu>
local function findSinkSubmenus(context)
    ---@type table<IsoObject, ISContextMenu>
    local submenuMap = {}

    for i = 1, #context.options do
        local option = context.options[i]
        if option.subOption then
            local submenu = context:getSubInstance(option.subOption)
            assert(submenu ~= nil)
            local drinkOption = submenu:getOptionFromName(DRINK_TEXT)
            if drinkOption then
                local object = drinkOption.param3
                if instanceof(object, "IsoObject") then
                    ---@cast object IsoObject
                    submenuMap[object] = submenu
                end
            end
        end
    end

    return submenuMap
end


---@param sink IsoObject
---@param player IsoPlayer
---@param isAddFilter boolean
function ContextMenu.onFilterOptionPressed(sink, player, isAddFilter)
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
            sink,
            wrench,
            isAddFilter
        )
    )
end


---Adds an add/remove filter context option if appropriate.
---@param context ISContextMenu
---@param object IsoObject
---@param player IsoPlayer
local function doFilterContextOption(context, object, player)
    if ContextMenu.isFilterable(object) then
        local inventory = player:getInventory()
        local playerHasFilter = inventory:containsType(Registries.items.TAP_FILTER)
        local playerHasWrench = inventory:containsTagEvalRecurse(
            ItemTag.PIPE_WRENCH,
            predicateNotBroken
        )

        if not (playerHasFilter or playerHasWrench) then
            return
        end

        local hasFilter = Utils.hasFilter(object)
        local name = getText(
            hasFilter and "ContextMenu_WaterGoesBad_RemoveFilter" or "ContextMenu_WaterGoesBad_AddFilter",
            -- leaving this extra argument here because the italian translation is not updated and will still use it
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
                getItemNameFromFullType(Registries.items.TAP_FILTER)
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


---@param playerNum integer
---@param context ISContextMenu
---@param worldObjects IsoObject[]
---@param test boolean
function ContextMenu.updateContextMenu(playerNum, context, worldObjects, test)
    ---@diagnostic disable-next-line: undefined-field
    if not SandboxVars.WaterGoesBad.NeedFilterWater then
        return
    end

    local submenus = findSinkSubmenus(context)
    for sink, submenu in pairs(submenus) do
        doFilterContextOption(
            submenu,
            sink,
            getSpecificPlayer(playerNum)
        )

        if SandboxVars.EnableTaintedWaterText then
            local drinkOption = submenu:getOptionFromName(DRINK_TEXT)
            -- currently this option is always present because findSinkSubmenus searches for drink options
            --  but in the future maybe there'll be things to filter that you can't directly drink from
            if drinkOption and shouldBeTainted(sink) then
                addTaintedWaterTooltip(drinkOption)
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(ContextMenu.updateContextMenu)


return ContextMenu