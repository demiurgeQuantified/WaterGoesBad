local item = ScriptManager.instance:getItem("Base.PipeWrench")
if item then
    local tags = item:getTags()
    tags:add("PipeWrench")
end