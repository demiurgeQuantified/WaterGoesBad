if isClient() then
    return
end


local LuaEvent = require("Starlit/LuaEvent")


---@type GameTime
local gameTime

---@diagnostic disable-next-line: undefined-field
local sandboxVars = SandboxVars.WaterGoesBad ---@as table

local rand = newrandom()


---Tracks the water expiration date and provides related utilities.
local ExpirationManager = {}


---Day relative to water shutoff that the water will expire on.
---@type integer
ExpirationManager.expirationDay = -1

---Days that have passed since the water expired.
---If negative, water has not expired yet.
---@type integer
ExpirationManager.daysSinceExpiration = 0


---Event triggered when water expires.
---It passes a single boolean argument. This will be true when the water is just expiring,
---and false when the water was already expired (the game was restarted after expiration)
---@type starlit.LuaEvent<boolean>
ExpirationManager.onWaterExpired = LuaEvent.new() ---@as starlit.LuaEvent<boolean>


---Returns the number of days since expiration.
---It is usually better to read :lua:data:`expirationDay`.
---@return integer days
---@nodiscard
function ExpirationManager.calculateDaysSinceExpiration()
    local daysSurvived = gameTime:getWorldAgeHours() / 24
    daysSurvived = math.floor(daysSurvived + 0.5)
    return daysSurvived - ExpirationManager.expirationDay
end


---Returns true if the water has expired.
---@return boolean expired
---@nodiscard
function ExpirationManager.isWaterExpired()
    return ExpirationManager.daysSinceExpiration >= 0
end


local function update()
    local daysSinceExpiration = ExpirationManager.calculateDaysSinceExpiration()

    -- necessary to delay trigger so that daysSinceExpiration is set during event
    local triggerEvent = daysSinceExpiration >= 0 and ExpirationManager.daysSinceExpiration < 0

    ExpirationManager.daysSinceExpiration = daysSinceExpiration >= 0 and daysSinceExpiration or -1

    if triggerEvent then
        ExpirationManager.onWaterExpired:trigger(true)
    end
end

Events.EveryDays.Add(update)


function ExpirationManager.init()
    gameTime = getGameTime()

    local modData = ModData.getOrCreate("WaterGoesBad")

    local shutOffDay = math.max(SandboxVars.WaterShutModifier, 0) -- WaterShutModifier can be -1, which is treated as zero
    local minDate = shutOffDay + sandboxVars.ExpirationMin
    local maxDate = shutOffDay + sandboxVars.ExpirationMax

    ---@type integer
    local expirationDay = modData.expirationDay
    if not expirationDay or expirationDay > maxDate or expirationDay < minDate then

        if sandboxVars.ExpirationMax > sandboxVars.ExpirationMin then
            expirationDay = rand:random(minDate, maxDate)
        else
            expirationDay = minDate
        end

        modData.expirationDay = expirationDay
    end
    ExpirationManager.expirationDay = expirationDay

    ExpirationManager.daysSinceExpiration = ExpirationManager.calculateDaysSinceExpiration()
    if ExpirationManager.daysSinceExpiration >= 0 then
        ExpirationManager.onWaterExpired:trigger(false)
    end
end

Events.OnInitGlobalModData.Add(ExpirationManager.init)


return ExpirationManager