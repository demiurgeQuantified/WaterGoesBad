local Utils = {}


---@param obj IsoObject
---@return string
---@nodiscard
function Utils.getMoveableDisplayName(obj)
	if not obj:getSprite() then
		return ""
	end

	local props = obj:getSprite():getProperties()
	if props:has("CustomName") then
		local name = props:get("CustomName")
		if props:has("GroupName") then
			name = props:get("GroupName") .. " " .. name
		end
		return Translator.getMoveableDisplayName(name)
	end

	return ""
end


return Utils