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

local WaterGoesBad = require("WaterGoesBad/WaterGoesBad")

-- TODO: expiration date init should be moved here

local WaterGoesBadServer = {}

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