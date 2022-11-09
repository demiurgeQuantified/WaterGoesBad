local WaterGoesBad = {}

WaterGoesBad.TimedActions = require 'WaterGoesBad/TimedActions'
WaterGoesBad.ContextMenu = require 'WaterGoesBad/ContextMenu'

function WaterGoesBad.OnGameStart()
    if not SandboxVars.WaterGoesBad.NeedFilterWater then
        getScriptManager():getRecipe('WaterGoesBad.Make Tap Filter'):setNeedToBeLearn(true)
    else
        Events.OnFillWorldObjectContextMenu.Add(WaterGoesBad.ContextMenu.OnFillWorldObjectContextMenu)
    end
end

Events.OnGameStart.Add(WaterGoesBad.OnGameStart)

return WaterGoesBad