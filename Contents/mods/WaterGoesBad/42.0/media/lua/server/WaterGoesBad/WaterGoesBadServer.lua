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

---@type fun(IsoGridSquare):IsoObject[]
local getTileObjectList = __classmetatables[IsoGridSquare.class].__index.getLuaTileObjectList
local sandboxVars = SandboxVars.WaterGoesBad

local WaterGoesBad = require("WaterGoesBad/WaterGoesBad")

local rand = newrandom()

local WaterGoesBadServer = {}

---Simulates the reduction of water for n days
---@param object IsoObject
---@param days integer
---@return number
function WaterGoesBadServer.reduceWater(object, days)
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

    object:setWaterAmount(wantedWater, true)
    return wantedWater
end

---@type IsoGridSquare[]
local squaresToProcess = {}

---@param square IsoGridSquare
function WaterGoesBadServer.addSquare(square)
    table.insert(squaresToProcess, square)
end

---Taints the water in valid objects on a square, and simulates water reduction, if enabled
---@param square IsoGridSquare
---@return table? squareData
function WaterGoesBadServer.drainWater(square)
    local squareModData = square:getModData()
    local daysNotSimulated = WaterGoesBad.daysSinceExpiration - (squareModData.WGBDaysSimulated or -1)
    if daysNotSimulated <= 0 then return nil end

    local squareData = {x = square:getX(), y = square:getY(), z = square:getZ()}
    local objects = getTileObjectList(square)
    for i = 1, #objects do
        local object = objects[i]
        local water = object:getWaterAmount()

        -- oh taps don't even use fluid containers (yet?) lol

        -- local fluidContainer = object:getFluidContainer()

        -- if fluidContainer and not fluidContainer:contains(Fluid.Water)
        --         and WaterGoesBad.isValidContainer(object) then
        --     table.insert(squareData, i-1)
        --     local waterAmount = fluidContainer:getSpecificFluidAmount(Fluid.Water)
        --     fluidContainer:adjustSpecificFluidAmount(Fluid.Water, 0)
        --     if fluidContainer:contains(Fluid.TaintedWater) then
        --         fluidContainer:adjustSpecificFluidAmount(
        --         Fluid.TaintedWater, fluidContainer:getSpecificFluidAmount(Fluid.TaintedWater) + waterAmount)
        --     else
        --         fluidContainer:addFluid(Fluid.TaintedWater, waterAmount)
        --     end

        if water > 0 and WaterGoesBad.isValidContainer(object) then
            table.insert(squareData, i-1)
            table.insert(squareData, WaterGoesBadServer.reduceWater(object, daysNotSimulated))
        end
    end

    if #squareData <= 0 then return nil end

    squareModData.WGBDaysSimulated = WaterGoesBad.daysSinceExpiration
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

function WaterGoesBadServer.processSquares()
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
        table.insert(modifiedSquares, WaterGoesBadServer.drainWater(squaresToProcess[i]))
        squaresToProcess[i] = nil
    end

    if #modifiedSquares > 0 then
        sendServerCommand("WaterGoesBad", "updateSquares", modifiedSquares)
    end

    -- totalSquares = totalSquares + numSquares
end

WaterGoesBadServer.startDrainingWater = function()
    if not sandboxVars.ReduceWaterOverTime then
        return
    end

    Events.LoadGridsquare.Add(WaterGoesBadServer.addSquare)
    Events.OnTick.Add(WaterGoesBadServer.processSquares)
end

WaterGoesBad.onWaterExpired:addListener(WaterGoesBadServer.startDrainingWater)

---@deprecated Moved to WaterGoesBad module
WaterGoesBadServer.isValidContainer = WaterGoesBad.isValidContainer

---@deprecated Moved to WaterGoesBad module
WaterGoesBadServer.calculateDaysSinceExpiration = WaterGoesBad.calculateDaysSinceExpiration

---@deprecated Renamed to drainWater, as it no longer taints water
WaterGoesBadServer.taintWater = WaterGoesBadServer.drainWater

---@deprecated Moved to WaterGoesBad module
WaterGoesBadServer.expirationDate = -1

---@deprecated Moved to WaterGoesBad module
WaterGoesBadServer.daysSinceExpiration = 0

return WaterGoesBadServer