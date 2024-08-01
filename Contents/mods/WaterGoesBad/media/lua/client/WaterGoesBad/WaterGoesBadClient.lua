local WaterGoesBad = {}

function WaterGoesBad.initRecipes()
    if not SandboxVars.WaterGoesBad.NeedFilterWater then
        getScriptManager():getRecipe('WaterGoesBad.Make Tap Filter'):setNeedToBeLearn(true)
    end
end

Events.OnGameStart.Add(WaterGoesBad.initRecipes)

---@deprecated
WaterGoesBad.OnGameStart = WaterGoesBad.initRecipes

return WaterGoesBad