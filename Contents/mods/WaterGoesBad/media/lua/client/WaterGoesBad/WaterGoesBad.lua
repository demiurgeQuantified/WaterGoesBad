local WaterGoesBad = {}

WaterGoesBad.TimedActions = require 'WaterGoesBad/TimedActions'
WaterGoesBad.ContextMenu = require 'WaterGoesBad/ContextMenu'

function WaterGoesBad.OnGameStart()
    if SandboxVars.WaterGoesBad.NeedFilterWater then
        Events.OnFillWorldObjectContextMenu.Add(WaterGoesBad.ContextMenu.OnFillWorldObjectContextMenu)
    else
        getScriptManager():getRecipe('WaterGoesBad.Make Tap Filter'):setNeedToBeLearn(true)
    end
end

Events.OnGameStart.Add(WaterGoesBad.OnGameStart)

return WaterGoesBad