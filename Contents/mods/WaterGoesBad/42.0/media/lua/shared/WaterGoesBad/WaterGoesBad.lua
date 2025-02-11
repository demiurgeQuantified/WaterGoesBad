local LuaEvent = require("Starlit/LuaEvent")

---@type GameTime
local gameTime
Events.OnGameTimeLoaded.Add(function ()
    gameTime = getGameTime()
end)

local sandboxVars = SandboxVars.WaterGoesBad
local rand = newrandom()

local WaterGoesBad = {}

-- FIXME: when multiplayer returns this needs to be networked
WaterGoesBad.expirationDate = -1
WaterGoesBad.daysSinceExpiration = 0

---Event fired when water expires.
---It passes a single boolean argument. This will be true when the water is just expiring,
---and false when the water was already expired (the game was restarted after expiration)
WaterGoesBad.onWaterExpired = LuaEvent.new()

---@param object IsoObject
---@return boolean
function WaterGoesBad.isValidContainer(object)
    return object:getProperties():Is(IsoFlagType.waterPiped)
        and not object:getUsesExternalWaterSource()
end

---@return integer
function WaterGoesBad.calculateDaysSinceExpiration()
    local daysSurvived = gameTime:getWorldAgeHours() / 24
    daysSurvived = math.floor(daysSurvived + 0.5)
    return daysSurvived - WaterGoesBad.expirationDate
end

---@return boolean
function WaterGoesBad.isWaterExpired()
    return WaterGoesBad.calculateDaysSinceExpiration() >= 0
end

function WaterGoesBad.calculateExpirationDate()
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

Events.OnInitGlobalModData.Add(WaterGoesBad.calculateExpirationDate)

function WaterGoesBad.updateDay()
    local daysSinceExpiration = WaterGoesBad.calculateDaysSinceExpiration()
    if daysSinceExpiration >= 0 and WaterGoesBad.daysSinceExpiration < 0 then
        WaterGoesBad.onWaterExpired:trigger(true)
    end
    WaterGoesBad.daysSinceExpiration = daysSinceExpiration
end

Events.EveryDays.Add(WaterGoesBad.updateDay)

return WaterGoesBad