if isClient() then
    return
end


local EntityHandle = require("Starlit/EntityHandle")

local ExpirationManager = require("WaterGoesBad/ExpirationManager")


---@diagnostic disable-next-line: undefined-field
local sandboxVars = SandboxVars.WaterGoesBad ---@as table

local rand = newrandom()


---Tracks and updates loaded water objects.
local WaterObjectManager = {}

---Percentage by which drain speed can vary per tap
WaterObjectManager.DRAIN_SPEED_VARIANCE = 0.4

---Objects registered with the object manager.
---Objects are added as soon as they load, but may remain in the list for some time after unloading.
---@type starlit.EntityHandle[]
WaterObjectManager.objects = {}


---Simulates a given number of days of drainage.
---@param fluidContainer FluidContainer The piped water object being drained.
---@param days number The number of days to simulate water drain of.
function WaterObjectManager.drainContainer(fluidContainer, days)
    local scale = fluidContainer:getCapacity() * 0.05 -- 20 = 1x
    local amount = fluidContainer:getAmount()

    local minWater = sandboxVars.MinimumWaterLeft * scale
    if amount <= minWater then
        return
    end

    local drainSpeed = sandboxVars.WaterReductionRate
    if drainSpeed == 20 then
        drainSpeed = 1
    else
        -- when more than one day's update is being applied this should probably be weighted towards the average
        -- but i don't really know the maths so this is fine
        drainSpeed = (1 - WaterObjectManager.DRAIN_SPEED_VARIANCE * 0.5) + rand:random() * WaterObjectManager.DRAIN_SPEED_VARIANCE
    end

    amount = amount - sandboxVars.WaterReductionRate * scale * drainSpeed * days
    if amount < minWater then
        amount = minWater
    end

    fluidContainer:adjustAmount(amount)
end


---Replaces all water in a container with tainted water.
---@param fluidContainer FluidContainer
function WaterObjectManager.taintContainer(fluidContainer)
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


---Updates an object if it is required.
---@param object IsoObject The object to be updated.
function WaterObjectManager.updateObject(object)
    local modData = object:getModData().WaterGoesBad

    assert(modData ~= nil)
    assert(object:hasComponent(ComponentType.FluidContainer))

    -- FIXME: check sprite property SpriteGridPos: if not 0,0, update the object there instead and copy result back to here

    local fluidContainer = object:getFluidContainer()
    if modData.lastUpdateDay == -1 then
        WaterObjectManager.taintContainer(fluidContainer)
    end

    local daysToSimulate = ExpirationManager.daysSinceExpiration - modData.lastUpdateDay
    if daysToSimulate <= 0 then
        return
    end

    if sandboxVars.ReduceWaterOverTime then
        WaterObjectManager.drainContainer(fluidContainer, daysToSimulate)
    end

    object:sync()

    modData.lastUpdateDay = ExpirationManager.daysSinceExpiration
end


---Updates all loaded objects.
function WaterObjectManager.update()
    -- may want to consider spreading this over a couple ticks, but there shouldn't be many objects at once anyway
    
    -- remove removed objects
    for i = #WaterObjectManager.objects, 1, -1 do
        local object = WaterObjectManager.objects[i]
        if object:isEmpty() then
            table.remove(WaterObjectManager.objects, i)
        end
    end

    -- update remaining objects if the water is expired
    if ExpirationManager.isWaterExpired() then
        for i = 1, #WaterObjectManager.objects do
            local object = WaterObjectManager.objects[i]
            WaterObjectManager.updateObject(object:get())
        end
    end
end


---@param object IsoObject
---@return FluidContainer
---@nodiscard
function WaterObjectManager.createFluidContainerFor(object)
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


---Initialises an object after it has loaded.
---Should not assume that the object has not been initialised before.
---@param object IsoObject
function WaterObjectManager.initialiseObject(object)
    local modData = object:getModData()
    if not modData.WaterGoesBad then
        modData.WaterGoesBad = {
            lastUpdateDay = -1
        }
    end

    if not object:hasComponent(ComponentType.FluidContainer) then
        GameEntityFactory.AddComponent(
            object,
            WaterObjectManager.createFluidContainerFor(object)
        )
    end
end


---Adds an object and initialises it.
---@param object IsoObject
function WaterObjectManager.addObject(object)
    WaterObjectManager.initialiseObject(object)
    WaterObjectManager.objects[#WaterObjectManager.objects + 1] = EntityHandle.get(object)

    if ExpirationManager.isWaterExpired() then
        WaterObjectManager.updateObject(object)
    end
end


---@param firstTime boolean
local function onWaterExpired(firstTime)
    if firstTime then
        -- if false, the event was fired because the game just reloaded, so there aren't any objects anyway
        WaterObjectManager.update()
    end
    Events.EveryDays.Add(WaterObjectManager.update)
end


ExpirationManager.onWaterExpired:addListener(onWaterExpired)


---@param object IsoObject
local function waterObjectLoaded(object)
    if object:hasModData() and object:getModData().canBeWaterPiped then
        return
    end

    WaterObjectManager.addObject(object)
end


---@param spriteManager IsoSpriteManager
local function addWaterObjectListener(spriteManager)
    ---@type string[]
    local waterObjectSprites = table.newarray()

    ---@type table<string, IsoSprite>
    ---@diagnostic disable-next-line: undefined-field
    local sprites = transformIntoKahluaTable(spriteManager.namedMap --[[@as HashMap<string, IsoSprite>]])

    for name, sprite in pairs(sprites) do
        if sprite:getProperties():has(IsoFlagType.waterPiped) then
            waterObjectSprites[#waterObjectSprites + 1] = name
        end
    end

    MapObjects.OnLoadWithSprite(waterObjectSprites, waterObjectLoaded, 5)
end

Events.OnLoadedTileDefinitions.Add(addWaterObjectListener)


return WaterObjectManager