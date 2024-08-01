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

---@type IsoObject
local mt = __classmetatables[IsoObject.class].__index
local hasWater = mt.hasWater
local usesExternalWaterSource = mt.getUsesExternalWaterSource
local getProperties = mt.getProperties
local setTaintedWater = mt.setTaintedWater
---@type fun(IsoGridSquare):IsoObject[]
local getTileObjectList = __classmetatables[IsoGridSquare.class].__index.getLuaTileObjectList
---@type fun(PropertyContainer, IsoFlagType):boolean
local hasProperty = __classmetatables[PropertyContainer.class].__index.Is
local sandboxVars = SandboxVars.WaterGoesBad

local Filters = require 'WaterGoesBad/Filters'

local WaterGoesBad = {}
---@type integer
WaterGoesBad.expirationDate = -1
---@type integer
WaterGoesBad.daysSinceExpiration = 0

---@return integer
function WaterGoesBad.calculateDaysSinceExpiration()
    local daysSurvived = getGameTime():getWorldAgeHours() / 24
    daysSurvived = math.floor(daysSurvived + 0.5)
    return daysSurvived - WaterGoesBad.expirationDate
end

---@param object IsoObject
---@return boolean
function WaterGoesBad.isValidContainer(object)
    return hasWater(object) and
        hasProperty(getProperties(object), IsoFlagType.waterPiped) and
        not usesExternalWaterSource(object)
end

---Simulates the reduction of water for n days
---@param object IsoObject
---@param days integer
function WaterGoesBad.reduceWater(object, days)
    if sandboxVars.WaterReductionChance ~= 100 then
        for _ = 1, days do
            if ZombRand(1, 101) > sandboxVars.WaterReductionChance then
                days = days - 1
            end
        end
        if days == 0 then return end
    end

    local scale = object:getWaterMax() / 20
    local wantedWater = object:getWaterAmount() - sandboxVars.WaterReductionRate * days * scale
    wantedWater = math.max(wantedWater, sandboxVars.MinimumWaterLeft * scale)
    object:setWaterAmount(wantedWater)
    sendServerCommand("object", "setWaterAmount", {x=object:getX(), y=object:getY(), z=object:getZ(), index=object:getObjectIndex(), amount=wantedWater})
end

---@type IsoGridSquare[]
local squaresToProcess = {}

---@param square IsoGridSquare
function WaterGoesBad.addSquare(square)
    table.insert(squaresToProcess, square)
end

---Taints the water in valid objects on a square, and simulates water reduction, if enabled
---@param square IsoGridSquare
function WaterGoesBad.taintWater(square)
    local modData = square:getModData()
    local daysNotSimulated = WaterGoesBad.daysSinceExpiration - (modData.WGBDaysSimulated or -1)
    if daysNotSimulated <= 0 then return end

    local x,y,z = square:getX(), square:getY(), square:getZ()
    local objects = getTileObjectList(square)
    for i = 1, #objects do
        local object = objects[i]
        if WaterGoesBad.isValidContainer(object) then
            if not object:isTaintedWater() then
                setTaintedWater(object, true)
                sendServerCommand("WaterGoesBad", "setTainted", {x=x, y=y, z=z, i=i - 1, tainted=true})
            end
            if sandboxVars.ReduceWaterOverTime and object:getWaterAmount() > sandboxVars.MinimumWaterLeft then
                WaterGoesBad.reduceWater(object, daysNotSimulated)
            end
        end
    end

    modData.WGBDaysSimulated = WaterGoesBad.daysSinceExpiration - 1
end

-- What portion of queued squares to act upon per tick
-- This is so it doesn't unnecessarily do big amounts of work in one tick but still doesn't take too long to get through big lists
local SQUARES_PER_TICK_FACTOR = 0.2
-- Maximum squares per tick (so that it doesn't ever freeze the server doing huge amounts of work in one tick)
local MAX_SQUARES_PER_TICK = 2000
-- Minimum squares per tick (so that it doesn't keep diminishing and end up taking extremely long to act upon the last few squares)
local MIN_SQUARES_PER_TICK = 100

if isServer() then -- server has a really low tickrate compared to sp
    SQUARES_PER_TICK_FACTOR = 0.4
    MAX_SQUARES_PER_TICK = 10000
    MIN_SQUARES_PER_TICK = 500
end

local previousLen = 0
local ticks = 0
local startTime = 0
local totalSquares = 0

function WaterGoesBad.processSquares()
    local len = #squaresToProcess

    if len ~= 0 then
        ticks = ticks + 1
        if previousLen == 0 then
            print("[WaterGoesBad] Starting processing squares")
            startTime = os.time()
        end
    else
        if previousLen ~= 0 then
            print("[WaterGoesBad] Finished processing " .. totalSquares .. " squares (took " .. ticks .. " ticks (" .. (os.time() - startTime) .. " seconds))")
            ticks = 0
            totalSquares = 0
        end
    end

    previousLen = len

    if len == 0 then return end

    local numSquares = len * SQUARES_PER_TICK_FACTOR
    numSquares = numSquares - numSquares % 1 -- faster than math.floor lol
    numSquares = (numSquares > MIN_SQUARES_PER_TICK and MIN_SQUARES_PER_TICK < len and MIN_SQUARES_PER_TICK or len)
        and (numSquares < MAX_SQUARES_PER_TICK and numSquares or MAX_SQUARES_PER_TICK)
        or len
    for i = len, len - numSquares, -1 do
        WaterGoesBad.taintWater(squaresToProcess[i])
        squaresToProcess[i] = nil
    end

    totalSquares = totalSquares + numSquares
end


function WaterGoesBad.updateDay()
    local daysSinceExpiration = WaterGoesBad.calculateDaysSinceExpiration()
    if daysSinceExpiration >= 0 and WaterGoesBad.daysSinceExpiration < 0 then
        Events.LoadGridsquare.Add(WaterGoesBad.addSquare)
        Events.OnTick.Add(WaterGoesBad.processSquares)
    end
    WaterGoesBad.daysSinceExpiration = daysSinceExpiration
end

function WaterGoesBad.calculateExpirationDate()
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

    WaterGoesBad.daysSinceExpiration = WaterGoesBad.calculateDaysSinceExpiration()
    if WaterGoesBad.daysSinceExpiration >= 0 then
        Events.LoadGridsquare.Add(WaterGoesBad.addSquare)
        Events.OnTick.Add(WaterGoesBad.processSquares)
    end
    Events.EveryDays.Add(WaterGoesBad.updateDay)

    if sandboxVars.NeedFilterWater then
        Events.OnWaterAmountChange.Add(Filters.handleWaterChange)
    end
end

Events.OnInitGlobalModData.Add(WaterGoesBad.calculateExpirationDate)

---@deprecated
WaterGoesBad.ReduceWater = WaterGoesBad.reduceWater
---@deprecated
WaterGoesBad.TaintWater = WaterGoesBad.taintWater
---@deprecated
WaterGoesBad.CalculateExpirationDate = WaterGoesBad.calculateExpirationDate
---@deprecated
WaterGoesBad.EveryDays = WaterGoesBad.updateDay
---@deprecated
WaterGoesBad.IsValidContainer = WaterGoesBad.isValidContainer
---@deprecated
WaterGoesBad.getDaysSinceExpiration = WaterGoesBad.calculateDaysSinceExpiration

return WaterGoesBad