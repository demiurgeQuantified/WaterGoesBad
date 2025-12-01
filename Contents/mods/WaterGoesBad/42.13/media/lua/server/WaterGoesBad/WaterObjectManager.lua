if isClient() then
    return
end

local WaterGoesBad = require("WaterGoesBad/WaterGoesBad")


-- TODO: we could keep track of all loaded water objects and update them periodically instead of only when loading

local WaterObjectManager = {}


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


---@param object IsoObject
function WaterObjectManager.objectAdded(object)
    WaterObjectManager.initialiseObject(object)

    if WaterGoesBad.isWaterExpired() then
        WaterGoesBad.updateObject(object)
    end
end


---@param object IsoObject
local function waterObjectLoaded(object)
    if object:hasModData() and object:getModData().canBeWaterPiped then
        return
    end

    WaterObjectManager.objectAdded(object)
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