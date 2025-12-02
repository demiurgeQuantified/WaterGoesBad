if isClient() then
    return
end


local EntityHandle = require("Starlit/EntityHandle")

local WaterGoesBad = require("WaterGoesBad/WaterGoesBad")


---Tracks and updates loaded water objects.
local WaterObjectManager = {}

---Objects registered with the object manager.
---Objects are added as soon as they load, but may remain in the list for some time after unloading.
---@type starlit.EntityHandle[]
WaterObjectManager.objects = {}


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
            WaterGoesBad.createFluidContainerFor(object)
        )
    end
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
    if WaterGoesBad.isWaterExpired() then
        for i = 1, #WaterObjectManager.objects do
            local object = WaterObjectManager.objects[i]
            WaterGoesBad.updateObject(object:get())
        end
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


WaterGoesBad.onWaterExpired:addListener(onWaterExpired)


---Adds an object and initialises it.
---@param object IsoObject
function WaterObjectManager.addObject(object)
    WaterObjectManager.initialiseObject(object)
    WaterObjectManager.objects[#WaterObjectManager.objects + 1] = EntityHandle.get(object)

    if WaterGoesBad.isWaterExpired() then
        WaterGoesBad.updateObject(object)
    end
end


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