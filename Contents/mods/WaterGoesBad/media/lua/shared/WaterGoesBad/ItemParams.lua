local item = ScriptManager.instance:getItem("Base.PipeWrench")
if item then
    local tags = item:getTags()
    if not tags:contains("PipeWrench") then
        tags:add("PipeWrench")
    end
end