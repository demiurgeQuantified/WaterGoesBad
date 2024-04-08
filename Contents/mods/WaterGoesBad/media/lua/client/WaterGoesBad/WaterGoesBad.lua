local WaterGoesBad = {}

function WaterGoesBad.OnGameStart()
    if not SandboxVars.WaterGoesBad.NeedFilterWater then
        getScriptManager():getRecipe('WaterGoesBad.Make Tap Filter'):setNeedToBeLearn(true)
    end
end

Events.OnGameStart.Add(WaterGoesBad.OnGameStart)

----------------------------------------------------------------------------------------------------------
-- server commands
----------------------------------------------------------------------------------------------------------

WaterGoesBad.Commands = {}

function WaterGoesBad.Commands.setTainted(args)
    local sq = getSquare(args.x, args.y, args.z)
    if sq and args.index >= 0 and args.index < sq:getObjects():size() then
        ---@type IsoObject
        local object = sq:getObjects():get(args.index)
        object:setTaintedWater(args.tainted)

        -- vanilla fails to sync this for washers/dryers, due to overriding the method responsible for handling updates
        object:setUsesExternalWaterSource(true)
    end
end

local function onServerCommand(module, command, args)
    if module ~= 'WaterGoesBad' then return end
    WaterGoesBad.Commands[command](args)
end

Events.OnServerCommand.Add(onServerCommand)

return WaterGoesBad