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
local usesExternalWaterSource = mt.getUsesExternalWaterSource
local getProperties = mt.getProperties
local setTaintedWater = mt.setTaintedWater
---@type fun(IsoGridSquare):IsoObject[]
local getTileObjectList = __classmetatables[IsoGridSquare.class].__index.getLuaTileObjectList
---@type fun(PropertyContainer, IsoFlagType):boolean
local hasProperty = __classmetatables[PropertyContainer.class].__index.Is
local sandboxVars = SandboxVars.WaterGoesBad

local Filters = require 'WaterGoesBad/Filters'

local rand = newrandom()

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
    return hasProperty(getProperties(object), IsoFlagType.waterPiped) and
        not usesExternalWaterSource(object)
end

---Simulates the reduction of water for n days
---@param object IsoObject
---@param days integer
---@return number
function WaterGoesBad.reduceWater(object, days)
    local startWater = object:getWaterAmount()
    if startWater <= sandboxVars.MinimumWaterLeft then
        return startWater
    end

    if sandboxVars.WaterReductionChance ~= 100 then
        for _ = 1, days do
            if rand:random(100) > sandboxVars.WaterReductionChance then
                days = days - 1
            end
        end
        if days == 0 then return startWater end
    end

    local scale = object:getWaterMax() / 20
    local wantedWater = startWater - sandboxVars.WaterReductionRate * days * scale
    local min = sandboxVars.MinimumWaterLeft * scale
    wantedWater = wantedWater > min and wantedWater or min

    object:setWaterAmount(wantedWater)
    return wantedWater
end

---@type IsoGridSquare[]
local squaresToProcess = {}

---@param square IsoGridSquare
function WaterGoesBad.addSquare(square)
    table.insert(squaresToProcess, square)
end

---Taints the water in valid objects on a square, and simulates water reduction, if enabled
---@param square IsoGridSquare
---@return table? squareData
function WaterGoesBad.taintWater(square)
    local squareModData = square:getModData()
    local daysNotSimulated = WaterGoesBad.daysSinceExpiration - (squareModData.WGBDaysSimulated or -1)
    if daysNotSimulated <= 0 then return nil end

    local squareData = {x = square:getX(), y = square:getY(), z = square:getZ()}
    local objects = getTileObjectList(square)
    for i = 1, #objects do
        local object = objects[i]
        local water = object:getWaterAmount()

        if water > 0 and WaterGoesBad.isValidContainer(object) then
            table.insert(squareData, i-1)
            setTaintedWater(object, true)
            if sandboxVars.ReduceWaterOverTime then
                table.insert(squareData, WaterGoesBad.reduceWater(object, daysNotSimulated))
            end
        end
    end

    if #squareData <= 0 then return nil end

    squareModData.WGBDaysSimulated = WaterGoesBad.daysSinceExpiration - 1
    square:transmitModdata()
    return squareData
end

-- What portion of queued squares to act upon per tick
-- This is so it doesn't unnecessarily do big amounts of work in one tick but still doesn't take too long to get through big lists
local SQUARES_PER_TICK_FACTOR = 0.2
-- Maximum squares per tick (so that it doesn't ever freeze the server doing huge amounts of work in one tick)
local MAX_SQUARES_PER_TICK = 2000
-- Minimum squares per tick (so that it doesn't keep diminishing and end up taking extremely long to act upon the last few squares)
local MIN_SQUARES_PER_TICK = 100

if isServer() then -- server has a really low tickrate
    SQUARES_PER_TICK_FACTOR = 0.4
    MAX_SQUARES_PER_TICK = 10000
    MIN_SQUARES_PER_TICK = 500
end

-- local previousLen = 0
-- local ticks = 0
-- local startTime = 0
-- local totalSquares = 0

function WaterGoesBad.processSquares()
    local len = #squaresToProcess

    -- if len ~= 0 then
    --     ticks = ticks + 1
    --     if previousLen == 0 then
    --         print("[WaterGoesBad] Starting processing squares")
    --         startTime = os.time()
    --     end
    -- else
    --     if previousLen ~= 0 then
    --         print("[WaterGoesBad] Finished processing " .. totalSquares .. " squares (took " .. ticks .. " ticks (" .. (os.time() - startTime) .. " seconds))")
    --         ticks = 0
    --         totalSquares = 0
    --     end
    -- end

    -- previousLen = len

    if len == 0 then return end

    local numSquares = len * SQUARES_PER_TICK_FACTOR
    numSquares = numSquares - numSquares % 1 -- faster than math.floor lol
    numSquares = (numSquares > MIN_SQUARES_PER_TICK and MIN_SQUARES_PER_TICK < len and MIN_SQUARES_PER_TICK or len)
        and (numSquares < MAX_SQUARES_PER_TICK and numSquares or MAX_SQUARES_PER_TICK)
        or len

    local modifiedSquares = {}
    for i = len, len - numSquares, -1 do
        table.insert(modifiedSquares, WaterGoesBad.taintWater(squaresToProcess[i]))
        squaresToProcess[i] = nil
    end

    if #modifiedSquares > 0 then
        sendServerCommand("WaterGoesBad", "updateSquares", modifiedSquares)
    end

    -- totalSquares = totalSquares + numSquares
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

    local minDate = SandboxVars.WaterShutModifier + sandboxVars.ExpirationMin
    local maxDate = SandboxVars.WaterShutModifier + sandboxVars.ExpirationMax

    WaterGoesBad.expirationDate = modData.ExpirationDate
    if not WaterGoesBad.expirationDate or WaterGoesBad.expirationDate > maxDate or WaterGoesBad.expirationDate < minDate then
        ---@type integer
        local expirationDate

        if sandboxVars.ExpirationMax > sandboxVars.ExpirationMin then
            expirationDate = rand:random(minDate, maxDate)
        else
            expirationDate = minDate
        end

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

return WaterGoesBad