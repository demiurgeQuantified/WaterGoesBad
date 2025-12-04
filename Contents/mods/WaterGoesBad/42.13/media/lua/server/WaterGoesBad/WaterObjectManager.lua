if isClient() then
    return
end


local EntityHandle = require("Starlit/EntityHandle")
local TaskManager = require("Starlit/TaskManager")

local ExpirationManager = require("WaterGoesBad/ExpirationManager")


local TASK_CHAIN = "WaterGoesBad.WaterObjectManager"
TaskManager.addTaskChain(TASK_CHAIN)

---@diagnostic disable-next-line: undefined-field
local sandboxVars = SandboxVars.WaterGoesBad ---@as table

local rand = newrandom()


---Tracks and updates loaded water objects.
local WaterObjectManager = {}

---Drainage speed multiplier applied on top of the sandbox option.
WaterObjectManager.DRAIN_SPEED = 1 / 24

---Percentage by which drain speed can vary per tap
WaterObjectManager.DRAIN_SPEED_VARIANCE = 0.4

---Maximum number of objects to update per tick.
WaterObjectManager.MAX_OBJECT_UPDATES_PER_TICK = 128

---Objects registered with the object manager.
---Objects are added as soon as they load, but may remain in the list for some time after unloading.
---
---Be careful when modifying this: if elements are removed or reordered while the update coroutine is running,
---it may crash or not update all objects successfully.
---@type starlit.EntityHandle<IsoObject>[]
local objects = table.newarray()


---Simulates a given number of hours of drainage.
---@param fluidContainer FluidContainer The piped water object being drained.
---@param hours number The number of hours to simulate water drain of.
function WaterObjectManager.drainContainer(fluidContainer, hours)
    local scale = fluidContainer:getCapacity()
    local amount = fluidContainer:getAmount()

    local minWater = sandboxVars.MinimumWaterLeft * scale
    if amount <= minWater then
        return
    end

    local drainSpeed = sandboxVars.WaterReductionRate
    if drainSpeed == 1 then
        drainSpeed = 1
    else
        -- when more than one hour's update is being applied this should probably be weighted towards the average
        -- but i don't really know the maths so this is fine
        drainSpeed = (1 - WaterObjectManager.DRAIN_SPEED_VARIANCE * 0.5) + rand:random() * WaterObjectManager.DRAIN_SPEED_VARIANCE
        drainSpeed = drainSpeed * WaterObjectManager.DRAIN_SPEED
    end

    amount = amount - sandboxVars.WaterReductionRate * scale * drainSpeed * hours
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
    if modData.lastUpdateHours == -1 then
        WaterObjectManager.taintContainer(fluidContainer)
    end

    local hoursToSimulate = ExpirationManager.hoursSinceExpiration - modData.lastUpdateHours
    if hoursToSimulate <= 0 then
        return
    end

    if sandboxVars.WaterReductionRate > 0 then
        WaterObjectManager.drainContainer(fluidContainer, hoursToSimulate)
    end

    object:sync()

    modData.lastUpdateHours = ExpirationManager.hoursSinceExpiration
end


---Updates all loaded objects.
---@async
---@return starlit.taskmanager.TaskResult result
local function update()
    local highIndex = #objects

    -- this won't change during an update
    local doObjectUpdates = ExpirationManager.isWaterExpired()

    while true do
        local lowIndex = math.max(highIndex - WaterObjectManager.MAX_OBJECT_UPDATES_PER_TICK, 1)

        -- remove unloaded objects in range
        for i = highIndex, lowIndex, -1 do
            local object = objects[i]:get()
            if object then
                if doObjectUpdates then
                    WaterObjectManager.updateObject(object)
                end
            else
                table.remove(objects, i)
            end
        end

        highIndex = lowIndex - 1
        if highIndex <= 0 then
           break
        end

        coroutine.yield(TaskManager.TaskResult.CONTINUE)
    end

    return TaskManager.TaskResult.DONE
end


local updateTask = ""

---Updates all loaded objects over the next few ticks.
function WaterObjectManager.startUpdate()
    -- cancel the currently running update if there is one
    if TaskManager.hasTask(TASK_CHAIN, updateTask) then
        TaskManager.removeTask(TASK_CHAIN, updateTask)
    end

    updateTask = TaskManager.addTask(
        TASK_CHAIN,
        coroutine.wrap(update)
    )
end

Events.EveryHours.Add(WaterObjectManager.startUpdate)


---Creates a FluidContainer appropriate for an object.
---@param object IsoObject
---@return FluidContainer fluidContainer
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
    
    water = water * sandboxVars.TapSizeScalar
    maxWater = maxWater * sandboxVars.TapSizeScalar
    
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
            lastUpdateHours = -1
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
    objects[#objects + 1] = EntityHandle.get(object)

    if ExpirationManager.isWaterExpired() then
        WaterObjectManager.updateObject(object)
    end
end


---@param firstTime boolean
local function onWaterExpired(firstTime)
    if not firstTime then
        -- the event was fired because the game just reloaded, so there aren't any objects anyway
        return
    end

    WaterObjectManager.startUpdate()
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