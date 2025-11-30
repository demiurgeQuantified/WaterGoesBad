local LuaEvent = require("Starlit/LuaEvent")
local Utils = require("WaterGoesBad/Utils")


---@type GameTime
local gameTime

---@diagnostic disable-next-line: undefined-field
local sandboxVars = SandboxVars.WaterGoesBad ---@as table

local rand = newrandom()


local WaterGoesBad = {}


---@type integer
WaterGoesBad.expirationDate = -1

---@type integer
WaterGoesBad.daysSinceExpiration = 0

WaterGoesBad.DRAIN_SPEED_VARIANCE = 0.4

---Event triggered when water expires.
---It passes a single boolean argument. This will be true when the water is just expiring,
---and false when the water was already expired (the game was restarted after expiration)
WaterGoesBad.onWaterExpired = LuaEvent.new()


---@param object IsoObject
---@return boolean
---@nodiscard
function WaterGoesBad.isPipedContainer(object)
    return object:hasProperty(IsoFlagType.waterPiped)
            -- we check hasModData first to avoid giving every object in the entire world mod data
            and (not object:hasModData() or not object:getModData().canBeWaterPiped)
end


---@return integer
---@nodiscard
function WaterGoesBad.calculateDaysSinceExpiration()
    local daysSurvived = gameTime:getWorldAgeHours() / 24
    daysSurvived = math.floor(daysSurvived + 0.5)
    return daysSurvived - WaterGoesBad.expirationDate
end


---@return boolean
---@nodiscard
function WaterGoesBad.isWaterExpired()
    return WaterGoesBad.daysSinceExpiration >= 0
end


function WaterGoesBad.updateDay()
    local daysSinceExpiration = WaterGoesBad.calculateDaysSinceExpiration()
    if daysSinceExpiration >= 0 and WaterGoesBad.daysSinceExpiration < 0 then
        WaterGoesBad.onWaterExpired:trigger(true)
    end
    WaterGoesBad.daysSinceExpiration = daysSinceExpiration >= 0 and daysSinceExpiration or -1
end

Events.EveryDays.Add(WaterGoesBad.updateDay)


-- TODO: water loss could be made smoother than once a day, now that water amount isn't integer anyway

---Simulates a given number of days of drainage.
---@param fluidContainer FluidContainer The piped water object being drained.
---@param days number The number of days to simulate water drain of.
function WaterGoesBad.drainContainer(fluidContainer, days)
    local scale = fluidContainer:getCapacity() * 0.05 -- 20 = 1x
    local amount = fluidContainer:getAmount()
    local minWater = sandboxVars.MinimumWaterLeft * scale
    if amount <= minWater then
        return
    end

    local drainSpeed = (1 - WaterGoesBad.DRAIN_SPEED_VARIANCE * 0.5) + rand:random() * WaterGoesBad.DRAIN_SPEED_VARIANCE

    amount = amount - sandboxVars.WaterReductionRate * scale * drainSpeed * days
    if amount < minWater then
        amount = minWater
    end

    fluidContainer:adjustAmount(amount)
end


---Replaces all water in a container with tainted water.
---@param fluidContainer FluidContainer
function WaterGoesBad.taintContainer(fluidContainer)
    local waterAmount = fluidContainer:getSpecificFluidAmount(Fluid.Water)
    fluidContainer:adjustSpecificFluidAmount(Fluid.Water, 0)

    local locked = fluidContainer:isInputLocked()
    if locked then
        fluidContainer:setInputLocked(false)
    end

    fluidContainer:addFluid(FluidType.TaintedWater, waterAmount)

    if locked then
        fluidContainer:setInputLocked(true)
    end
end


---@param object IsoObject
---@return FluidContainer
---@nodiscard
function WaterGoesBad.createFluidContainerFor(object)
    local fluidContainer = ComponentType.FluidContainer:CreateComponent() ---@as FluidContainer
    
    local modData = object:getModData()

    local spriteProperties = object:getSprite():getProperties()

    local water = modData.waterAmount
        or tonumber(spriteProperties:get(IsoPropertyType.WaterAmount))
        or 0

    local maxWater = modData.waterMaxAmount
        or tonumber(spriteProperties:get(IsoPropertyType.MaximumWaterAmount))
        or water
    
    if object:getSquare():isNoWater() then
        water = 0
    end

    fluidContainer:setCapacity(maxWater)
    fluidContainer:addFluid(Fluid.Water, water)
    fluidContainer:setInputLocked(true)
    -- fluidContainer:setContainerName(Utils.getMoveableDisplayName(object))

    return fluidContainer
end


---Updates an object if it is required.
---@param object IsoObject The object to be updated.
function WaterGoesBad.updateObject(object)
    local modData = object:getModData()
    if not modData.WaterGoesBad then
        modData.WaterGoesBad = {
            lastUpdateDay = 0
        }
    end
    modData = modData.WaterGoesBad

    -- FIXME: check sprite property SpriteGridPos: if not 0,0, update the object there instead and copy result back to here

    local fluidContainer = object:getFluidContainer()
    if modData.lastUpdateDay == 0 then
        WaterGoesBad.taintContainer(fluidContainer)
    end

    local daysToSimulate = WaterGoesBad.daysSinceExpiration - modData.lastUpdateDay
    if daysToSimulate <= 0 then
        return
    end

    if sandboxVars.ReduceWaterOverTime then
        WaterGoesBad.drainContainer(fluidContainer, daysToSimulate)
    end

    modData.lastUpdateDay = WaterGoesBad.daysSinceExpiration
end


---@param square IsoGridSquare
function WaterGoesBad.updateObjectsOnSquare(square)
    local objects = square:getLuaTileObjectList() ---@as IsoObject[]
    for i = 1, #objects do
        local object = objects[i]
        if WaterGoesBad.isPipedContainer(object) then
            if not object:hasComponent(ComponentType.FluidContainer) then
                GameEntityFactory.AddComponent(
                    object,
                    WaterGoesBad.createFluidContainerFor(object)
                )
            end

            if WaterGoesBad.isWaterExpired() then
                WaterGoesBad.updateObject(object)
            end
        end
    end
end

Events.LoadGridsquare.Add(WaterGoesBad.updateObjectsOnSquare)


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


return WaterGoesBad