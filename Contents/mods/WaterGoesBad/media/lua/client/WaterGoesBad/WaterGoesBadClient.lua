local WaterGoesBad = {}

function WaterGoesBad.initRecipes()
    ScriptManager.instance:getRecipe('WaterGoesBad.Make Tap Filter'):setNeedToBeLearn(not SandboxVars.WaterGoesBad.NeedFilterWater)
end

Events.OnGameStart.Add(WaterGoesBad.initRecipes)

return WaterGoesBad