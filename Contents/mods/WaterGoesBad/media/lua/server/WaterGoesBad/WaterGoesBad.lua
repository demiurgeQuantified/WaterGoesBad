--[[WATER GOES BAD
    Copyright (C) 2022 albion

    This program is free software: you can redistribute it and/or modify
    it under the terms of Version 3 of the GNU Affero General Public License as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

    For any questions, contact me through steam or on Discord - albion#0123
]]
if isClient() then return end
local getTileObjectList = IsoGridSquare.getLuaTileObjectList
local hasWater = IsoObject.hasWater
local usesExternalWaterSource = IsoObject.getUsesExternalWaterSource
local getProperties = IsoObject.getProperties
local hasProperty = PropertyContainer.Is
local setTaintedWater = IsoObject.setTaintedWater
local sandboxVars = SandboxVars.WaterGoesBad

local Filters = require 'WaterGoesBad/Filters'

local WaterGoesBad = {}
WaterGoesBad.expirationDate = nil

---@return number
function WaterGoesBad.getDaysSinceExpiration()
    local daysSurvived = getGameTime():getWorldAgeHours() / 24
    daysSurvived = math.floor(daysSurvived + 0.5)
    return daysSurvived - WaterGoesBad.expirationDate
end

---@param object IsoObject
function WaterGoesBad.IsValidContainer(object)
    return hasWater(object) and hasProperty(getProperties(object), IsoFlagType.waterPiped) and not usesExternalWaterSource(object)
end

---Simulates the reduction of water for every day since the water started draining that this object has not been loaded
---@param object IsoObject
function WaterGoesBad.ReduceWater(object)
    local modData = object:getModData()
    local daysSimulated = modData.WGBDaysSimulated or 0
    local daysNotSimulated = WaterGoesBad.getDaysSinceExpiration() + 1 - daysSimulated

    local daysToSimulate = 0
    if daysNotSimulated > 0 then
        if sandboxVars.WaterReductionChance == 100 then
            daysToSimulate = daysNotSimulated
        else
            for i=1,daysNotSimulated do
                if ZombRand(1, 101) <= sandboxVars.WaterReductionChance then
                    daysToSimulate = daysToSimulate + 1
                end
            end
        end
        
        if daysToSimulate > 0 then
            local scale = object:getWaterMax() / 20
            local wantedWater = object:getWaterAmount() - sandboxVars.WaterReductionRate * daysToSimulate * scale
            wantedWater = math.max(wantedWater, sandboxVars.MinimumWaterLeft * scale)
            object:setWaterAmount(wantedWater)
        end
    end

    modData.WGBDaysSimulated = WaterGoesBad.getDaysSinceExpiration() + 1
end

---Taints the water in an object, if it is valid, and simulates the water reduction, if enabled
---@param square IsoGridSquare
function WaterGoesBad.TaintWater(square)
    local objects = getTileObjectList(square)
    for i = 1, #objects do
        local object = objects[i]
        if WaterGoesBad.IsValidContainer(object) then
            setTaintedWater(object, true)
            if sandboxVars.ReduceWaterOverTime and object:getWaterAmount() > sandboxVars.MinimumWaterLeft then
                WaterGoesBad.ReduceWater(object)
            end
        end
    end
end

function WaterGoesBad.EveryDays()
    if WaterGoesBad.getDaysSinceExpiration() >= 0 then
        Events.LoadGridsquare.Add(WaterGoesBad.TaintWater)
        Events.EveryDays.Remove(WaterGoesBad.EveryDays)
    end
end

function WaterGoesBad.CalculateExpirationDate()
    local modData = ModData.getOrCreate("WaterGoesBad")
    WaterGoesBad.expirationDate = modData.ExpirationDate
    if not WaterGoesBad.expirationDate then
        local expirationDate

        if sandboxVars.ExpirationMax > sandboxVars.ExpirationMin then
            expirationDate = ZombRand(sandboxVars.ExpirationMin, sandboxVars.ExpirationMax + 1)
        else
            expirationDate = sandboxVars.ExpirationMin
        end
        expirationDate = expirationDate + math.max(SandboxVars.WaterShutModifier, 0)

        WaterGoesBad.expirationDate = expirationDate
        modData.ExpirationDate = expirationDate
    end
    if WaterGoesBad.getDaysSinceExpiration() >= 0 then Events.LoadGridsquare.Add(WaterGoesBad.TaintWater) else Events.EveryDays.Add(WaterGoesBad.EveryDays) end
    if sandboxVars.NeedFilterWater then
        Events.OnWaterAmountChange.Add(Filters.OnWaterAmountChange)
    end
end

Events.OnInitGlobalModData.Add(WaterGoesBad.CalculateExpirationDate)

----------------------------------------------------------------------------------------------------------
-- client commands
----------------------------------------------------------------------------------------------------------

WaterGoesBad.Commands = {}

function WaterGoesBad.Commands.plumbObject(args)
    local sq = getSquare(args.x, args.y, args.z)
    if sq and args.index >= 0 and args.index < sq:getObjects():size() then
        local object = sq:getObjects():get(args.index)

        local tainted = false
        if sandboxVars.NeedFilterWater then
            local externalWaterSource = IsoObject.FindExternalWaterSource(sq)
            tainted = externalWaterSource and externalWaterSource:isTaintedWater() or false
        end
        setTaintedWater(object, tainted)
        args = {x=args.x, y=args.y, z=args.z, index=args.index, tainted=tainted}
        sendServerCommand('WaterGoesBad', 'setTainted', args)
    end
end

local function onClientCommand(module, command, player, args)
    if module == 'object' and command == 'plumbObject' then
        WaterGoesBad.Commands.plumbObject(args)
    end
end

Events.OnClientCommand.Add(onClientCommand)

return WaterGoesBad