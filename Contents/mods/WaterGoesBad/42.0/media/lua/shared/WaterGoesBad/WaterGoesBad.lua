local LuaEvent = require("Starlit/LuaEvent")

---@type GameTime
local gameTime

local sandboxVars = SandboxVars.WaterGoesBad
local rand = newrandom()

local WaterGoesBad = {}

-- FIXME: when multiplayer returns this needs to be networked
WaterGoesBad.expirationDate = -1
WaterGoesBad.daysSinceExpiration = 0
WaterGoesBad.DRAIN_SPEED_VARIANCE = 0.4

---Event fired when water expires.
---It passes a single boolean argument. This will be true when the water is just expiring,
---and false when the water was already expired (the game was restarted after expiration)
WaterGoesBad.onWaterExpired = LuaEvent.new()

---@param object IsoObject
---@return boolean
function WaterGoesBad.isValidContainer(object)
    return object:getProperties():Is(IsoFlagType.waterPiped)
end

---@return integer
function WaterGoesBad.calculateDaysSinceExpiration()
    local daysSurvived = gameTime:getWorldAgeHours() / 24
    daysSurvived = math.floor(daysSurvived + 0.5)
    return daysSurvived - WaterGoesBad.expirationDate
end

---@return boolean
function WaterGoesBad.isWaterExpired()
    return WaterGoesBad.daysSinceExpiration >= 0
end

-- TODO: water loss could be made smoother than once a day, now that water amount isn't integer anyway

---Simulates a given amount of days of water drainage for an object with piped water.
---The simulation is deterministic: the same object draining on the same day will always have the same result.
---@param object IsoObject The piped water object being drained.
---@param days number The number of days to simulate water drain of.
WaterGoesBad.drainPipedWater = function(object, days)
    local scale = object:getWaterMax() * 0.05 -- 20 = 1x
    local water = object:getWaterAmount()
    local minWater = sandboxVars.MinimumWaterLeft * scale
    if water <= minWater then
        return
    end

    -- random multiplication factors stop nearby objects from having the same seed
    rand:seed(
        (object:getX() * 5321)
        + (object:getY() * 9406)
        + (object:getZ() * 1462))
    local drainSpeed = (1 - WaterGoesBad.DRAIN_SPEED_VARIANCE * 0.5)
            + rand:random() * WaterGoesBad.DRAIN_SPEED_VARIANCE

    water = water - sandboxVars.WaterReductionRate * scale * drainSpeed * days
    if water < minWater then
        water = minWater
    end

    object:setWaterAmount(water, true)
end

---Updates an object if it is required.
---@param object IsoObject The object to be updated.
WaterGoesBad.updateObject = function(object)
    if not WaterGoesBad.isValidContainer(object) or object:getUsesExternalWaterSource() then
        return
    end

    local modData = object:getModData()
    if not modData.WaterGoesBad then
        modData.WaterGoesBad = {
            daysSimulated = 0
        }
    end
    modData = modData.WaterGoesBad

    -- FIXME: check sprite property SpriteGridPos: if not 0,0, update the object there instead and copy result back to here

    local daysToSimulate = WaterGoesBad.daysSinceExpiration - modData.daysSimulated
    if daysToSimulate <= 0 then
        return
    end

    if sandboxVars.ReduceWaterOverTime then
        WaterGoesBad.drainPipedWater(object, daysToSimulate)
    end

    modData.daysSimulated = WaterGoesBad.daysSinceExpiration
end

function WaterGoesBad.updateDay()
    local daysSinceExpiration = WaterGoesBad.calculateDaysSinceExpiration()
    if daysSinceExpiration >= 0 and WaterGoesBad.daysSinceExpiration < 0 then
        WaterGoesBad.onWaterExpired:trigger(true)
    end
    WaterGoesBad.daysSinceExpiration = daysSinceExpiration >= 0 and daysSinceExpiration or -1
end

Events.EveryDays.Add(WaterGoesBad.updateDay)

function WaterGoesBad.init()
    gameTime = getGameTime()

    local modData = ModData.getOrCreate("WaterGoesBad")

    local shutDate = SandboxVars.WaterShutModifier
    shutDate = shutDate >= 0 and shutDate or 0 -- shut date can be -1, which is treated as zero
    local minDate = shutDate + sandboxVars.ExpirationMin
    local maxDate = shutDate + sandboxVars.ExpirationMax

    ---@type integer
    local expirationDate = modData.ExpirationDate
    if not expirationDate or expirationDate > maxDate or expirationDate < minDate then

        if sandboxVars.ExpirationMax > sandboxVars.ExpirationMin then
            expirationDate = rand:random(minDate, maxDate)
        else
            expirationDate = minDate
        end

        modData.ExpirationDate = expirationDate
    end
    WaterGoesBad.expirationDate = expirationDate

    WaterGoesBad.daysSinceExpiration = WaterGoesBad.calculateDaysSinceExpiration()
    if WaterGoesBad.daysSinceExpiration >= 0 then
        WaterGoesBad.onWaterExpired:trigger(false)
    end
end

Events.OnInitGlobalModData.Add(WaterGoesBad.init)

---@deprecated Renamed to init
WaterGoesBad.calculateExpirationDate = WaterGoesBad.init

return WaterGoesBad