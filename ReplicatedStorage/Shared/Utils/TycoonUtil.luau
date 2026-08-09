local TycoonUtil = {}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local TEMPLATE = workspace.TycoonTemplate

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type TycoonTemplate = typeof(TEMPLATE)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local childToTycoonModelCache: { [BasePart]: typeof(TEMPLATE) } = {}

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function TycoonUtil.getTycoonModel(child: Instance): typeof(TEMPLATE)
	local cached = childToTycoonModelCache[child]
	if cached and cached.Parent then
		return cached
	end

	local current: Instance? = child
	while current and current ~= workspace do
		if current:IsA("Model") and current.Name == "TycoonModel" then
			childToTycoonModelCache[child] = current
			return current
		end
		current = current.Parent
	end

	return nil
end

function TycoonUtil.getTycoonTemplate()
	return TEMPLATE
end

function TycoonUtil.getPlayerTycoonModel(player: Player): typeof(TEMPLATE)
	local nodeIndex = player:GetAttribute("NodeIndex")
	if type(nodeIndex) ~= "number" then
		return nil
	end

	local node = workspace.Plots:FindFirstChild(tostring(nodeIndex))
	if not node then
		return nil
	end

	local tycoonModel = node:FindFirstChild("TycoonModel")
	if tycoonModel and tycoonModel:IsA("Model") then
		return tycoonModel
	end

	return nil
end

return TycoonUtil
