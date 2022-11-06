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

local WaterGoesBad = {}
WaterGoesBad.expirationDate = nil

function WaterGoesBad.getDaysSinceExpiration()
    local daysSurvived = getGameTime():getWorldAgeHours() / 24
    daysSurvived = math.floor(daysSurvived + 0.5)
    return daysSurvived - WaterGoesBad.expirationDate
end

function WaterGoesBad.IsValidContainer(object)
    return object:hasWater() and object:getProperties():Is(IsoFlagType.waterPiped) and not object:getUsesExternalWaterSource()
end

function WaterGoesBad.ReduceWater(object)
    local daysSimulated = object:getModData()['WGBDaysSimulated'] or 0
    local daysNotSimulated = (WaterGoesBad.getDaysSinceExpiration() + 1) - daysSimulated

    local daysToSimulate = 0
    if daysNotSimulated > 0 then
        if SandboxVars.WaterGoesBad.WaterReductionChance == 100 then
            daysToSimulate = daysNotSimulated
        else
            for i=1,daysNotSimulated do
                if ZombRand(1, 101) <= ZombRand(SandboxVars.WaterGoesBad.WaterReductionChance) then
                    daysToSimulate = daysToSimulate + 1
                end
            end
        end
        
        if daysToSimulate > 0 then
            local waterLoss = SandboxVars.WaterGoesBad.WaterReductionRate * daysToSimulate
            if SandboxVars.WaterGoesBad.ScaleWaterLoss then
                waterLoss = waterLoss * (object:getWaterMax() / 20)
            end
            local wantedWater = object:getWaterAmount() - waterLoss
            wantedWater = math.max(wantedWater, SandboxVars.WaterGoesBad.MinimumWaterLeft)
            object:setWaterAmount(wantedWater)
        end
    end
    
    object:getModData()['WGBDaysSimulated'] = WaterGoesBad.getDaysSinceExpiration() + 1
end

function WaterGoesBad.TaintWater(square)
    local objectArray = square:getObjects()
    for i = 0, objectArray:size() - 1 do
        local object = objectArray:get(i)
        if WaterGoesBad.IsValidContainer(object) then
            object:setTaintedWater(true)
            if SandboxVars.WaterGoesBad.ReduceWaterOverTime and object:getWaterAmount() > SandboxVars.WaterGoesBad.MinimumWaterLeft then
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
    if ModData.exists('WaterGoesBad') then
        WaterGoesBad.expirationDate = ModData.get('WaterGoesBad')['ExpirationDate']
    else
        local expirationDate
        if SandboxVars.WaterGoesBad.ExpirationMax > SandboxVars.WaterGoesBad.ExpirationMin then
            expirationDate = ZombRand(SandboxVars.WaterGoesBad.ExpirationMin, SandboxVars.WaterGoesBad.ExpirationMax + 1)
        else
            expirationDate = SandboxVars.WaterGoesBad.ExpirationMin
        end
        expirationDate = expirationDate + math.max(SandboxVars.WaterShutModifier, 0)
        WaterGoesBad.expirationDate = expirationDate
        ModData.create('WaterGoesBad')
        ModData.add('WaterGoesBad', {['ExpirationDate'] = expirationDate})
    end
    if WaterGoesBad.getDaysSinceExpiration() >= 0 then Events.LoadGridsquare.Add(WaterGoesBad.TaintWater) else Events.EveryDays.Add(WaterGoesBad.EveryDays) end
end

Events.OnInitGlobalModData.Add(WaterGoesBad.CalculateExpirationDate)

WaterGoesBad.Commands = require 'WGB_ClientCommands'
WaterGoesBad.ContextMenu = require 'WGB_ContextMenu'

return WaterGoesBad