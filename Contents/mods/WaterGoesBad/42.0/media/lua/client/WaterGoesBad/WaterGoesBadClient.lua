local WaterGoesBad = {}

-- function WaterGoesBad.initRecipes()
--     ScriptManager.instance:getAllCraftRecipes():remove(
--          ScriptManager.instance:getCraftRecipe("WaterGoesBad.MakeTapFilter"))
-- end

-- Events.OnGameStart.Add(WaterGoesBad.initRecipes)

-- TODO: check if this still works

WaterGoesBad.reduceTaintedWaterCounters = function()
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player then
            local modData = player:getModData()
            if player:HasTrait("ProneToIllness") then
                modData.WGB_TaintedWaterDrank = modData.WGB_TaintedWaterDrank - 0.03
            else
                modData.WGB_TaintedWaterDrank = modData.WGB_TaintedWaterDrank - 0.1
            end
            modData.WGB_TaintedWaterDrank = modData.WGB_TaintedWaterDrank > 0 and modData.WGB_TaintedWaterDrank or 0
        end
    end
end

Events.EveryHours.Add(WaterGoesBad.reduceTaintedWaterCounters)

---@param character IsoGameCharacter The character drinking the water
---@param amount number Amount of water drank
WaterGoesBad.onDrinkTaintedWater = function(character, amount)
    local bodyDamage = character:getBodyDamage()
    local modData = character:getModData()
    local poisonLevel = bodyDamage:getPoisonLevel()

    local poisoning = modData.WGB_TaintedWaterDrank
    if character:HasTrait("Resilient") then
        poisoning = poisoning - 3
        poisoning = poisoning * 0.7
    end
    if character:HasTrait("Outdoorsman") then
        poisoning = poisoning * 0.9
    end

    bodyDamage:setPoisonLevel(poisonLevel + poisoning)

    modData.WGB_TaintedWaterDrank = modData.WGB_TaintedWaterDrank + amount
end

---Returns the amount of poisoning a character should receive if they drink a certain amount of units of water
---@param character IsoGameCharacter The character drinking the water
---@param units number Amount of water drank
---@return number poisoning
WaterGoesBad.getPoisoning = function(character, units)
    local mult = 1
    if character:HasTrait("Resilient") then
        mult = mult * 0.7
    end
    if character:HasTrait("Outdoorsman") then
        mult = mult * 0.9
    end

    return (10 + units) * mult
end

local old_ISTakeWaterAction_perform = ISTakeWaterAction.perform
---Makes sure players are still poisoned even if they already have some poisoning, and calls onDrinkTaintedWater
---@diagnostic disable-next-line: duplicate-set-field
ISTakeWaterAction.perform = function(self)
    if not self.item and self.waterObject:isTaintedWater() then
        ---@type BodyDamage
        local bodyDamage = self.character:getBodyDamage()

        local targetPoison = bodyDamage:getPoisonLevel() + WaterGoesBad.getPoisoning(self.character, self.waterUnit)
        targetPoison = targetPoison > 100 and 100 or targetPoison

        old_ISTakeWaterAction_perform(self)

        if bodyDamage:getPoisonLevel() < targetPoison then
            bodyDamage:setPoisonLevel(targetPoison)
        end

        WaterGoesBad.onDrinkTaintedWater(self.character, self.waterUnit)
    else
        old_ISTakeWaterAction_perform(self)
    end
end

local old_ISDrinkFromBottle_drink = ISDrinkFromBottle.drink
---Makes sure players are still poisoned even if they already have some poisoning, and calls onDrinkTaintedWater
---Also fixes drinking from a bottle not scaling with the amount drank
---@diagnostic disable-next-line: duplicate-set-field
ISDrinkFromBottle.drink = function(self, _, percentage)
    if self.item:isTaintedWater() then
        if percentage > 0.95 then
            percentage = 1.0
        end
        local uses = math.floor(self.uses * percentage + 0.001)

        ---@type BodyDamage
        local bodyDamage = self.character:getBodyDamage()

        local targetPoison = bodyDamage:getPoisonLevel() + WaterGoesBad.getPoisoning(self.character, uses)
        targetPoison = targetPoison > 100 and 100 or targetPoison

        old_ISDrinkFromBottle_drink(self, _, percentage)

        if bodyDamage:getPoisonLevel() < targetPoison then
            bodyDamage:setPoisonLevel(targetPoison)
        end

        WaterGoesBad.onDrinkTaintedWater(self.character, uses)
    else
        old_ISDrinkFromBottle_drink(self, _, percentage)
    end
end

---@type Callback_OnCreatePlayer
WaterGoesBad.initPlayer = function(_, player)
    local modData = player:getModData()
    if modData.WGB_TaintedWaterDrank then return end
    modData.WGB_TaintedWaterDrank = 0
end

Events.OnCreatePlayer.Add(WaterGoesBad.initPlayer)

return WaterGoesBad