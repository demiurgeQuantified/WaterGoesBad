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

local expirationDate = nil

local function getDaysSinceExpiration()
    local daysSurvived = getGameTime():getWorldAgeHours() / 24
    daysSurvived = math.floor(daysSurvived + 0.5)
    return daysSurvived - expirationDate
end

local function IsValidContainer(object)
    return object:hasWater() and object:getProperties():Is(IsoFlagType.waterPiped) and (not object:getUsesExternalWaterSource())
end

local function ReduceWater(object)
    local daysSimulated = object:getModData()['WGBDaysSimulated'] or 0
    local daysNotSimulated = (getDaysSinceExpiration() + 1) - daysSimulated

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
    
    object:getModData()['WGBDaysSimulated'] = getDaysSinceExpiration() + 1
end

local function TaintWater(square)
    local objectArray = square:getObjects()
    for i = 0, objectArray:size() - 1 do
        local object = objectArray:get(i)
        if IsValidContainer(object) then
            object:setTaintedWater(true)
            if SandboxVars.WaterGoesBad.ReduceWaterOverTime and object:getWaterAmount() > SandboxVars.WaterGoesBad.MinimumWaterLeft then
                ReduceWater(object)
            end
        end
    end
end

local function EveryDays()
    if getDaysSinceExpiration() >= 0 then
        Events.LoadGridsquare.Add(TaintWater)
        Events.EveryDays.Remove(EveryDays)
    end
end

local function CalculateExpirationDate()
    if ModData.exists(WaterGoesBad) then
        expirationDate = ModData.get(WaterGoesBad)['ExpirationDate']
    else
        if SandboxVars.WaterGoesBad.ExpirationMax > SandboxVars.WaterGoesBad.ExpirationMin then
            expirationDate = ZombRand(SandboxVars.WaterGoesBad.ExpirationMin, SandboxVars.WaterGoesBad.ExpirationMax + 1)
        else
            expirationDate = SandboxVars.WaterGoesBad.ExpirationMin
        end
        expirationDate = expirationDate + math.max(SandboxVars.WaterShutModifier, 0)
        local modData = {['ExpirationDate'] = expirationDate}
        ModData.create(WaterGoesBad)
        ModData.add(WaterGoesBad, modData)
    end
    if getDaysSinceExpiration() >= 0 then Events.LoadGridsquare.Add(TaintWater) else Events.EveryDays.Add(EveryDays) end
end

Events.OnInitGlobalModData.Add(CalculateExpirationDate)