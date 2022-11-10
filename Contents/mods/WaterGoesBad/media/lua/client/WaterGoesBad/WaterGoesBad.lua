local WaterGoesBad = {}

WaterGoesBad.TimedActions = require 'WaterGoesBad/TimedActions'
WaterGoesBad.ContextMenu = require 'WaterGoesBad/ContextMenu'

function WaterGoesBad.OnGameStart()
    Events.OnFillWorldObjectContextMenu.Remove(WaterGoesBad.ContextMenu.OnFillWorldObjectContextMenu)
    if SandboxVars.WaterGoesBad.NeedFilterWater then
        Events.OnFillWorldObjectContextMenu.Add(WaterGoesBad.ContextMenu.OnFillWorldObjectContextMenu)
    else
        getScriptManager():getRecipe('WaterGoesBad.Make Tap Filter'):setNeedToBeLearn(true)
    end
end

Events.OnGameStart.Add(WaterGoesBad.OnGameStart)

----------------------------------------------------------------------------------------------------------
-- server commands
----------------------------------------------------------------------------------------------------------

WaterGoesBad.Commands = {}

function WaterGoesBad.Commands.setTainted(args)
    print('setTainted '..tostring(args.x)..','..tostring(args.y)..','..tostring(args.z)..' '..tostring(args.index)..' '..tostring(args.tainted))
    local sq = getSquare(args.x, args.y, args.z)
    if sq and args.index >= 0 and args.index < sq:getObjects():size() then
        local object = sq:getObjects():get(args.index)
        object:setTaintedWater(args.tainted)
    end
end

local function onServerCommand(module, command, args)
    if module ~= 'WaterGoesBad' then return end
    WaterGoesBad.Commands[command](args)
end

Events.OnServerCommand.Add(onServerCommand)

return WaterGoesBad