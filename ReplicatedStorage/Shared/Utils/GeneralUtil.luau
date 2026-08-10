--!strict
--!optimize 2

local RunService = game:GetService("RunService")

local GeneralUtil = {}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

const IS_STUDIO = RunService:IsStudio()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local debouncing: { [any]: true } = {}

local suffixes = { "K", "M", "B", "T" }

type CastResult = {
	Instance: Instance?,
	Normal: Vector3?,
	Material: Enum.Material,
	Distance: number,
	Position: Vector3,
}

local function deepFreeze<T>(tbl: T): T
	if type(tbl) ~= "table" then
		return tbl
	end

	for _, v in tbl :: { [any]: any } do
		if type(v) == "table" then
			deepFreeze(v)
		end
	end

	if not table.isfrozen(tbl) then
		table.freeze(tbl)
	end

	return tbl
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function GeneralUtil.formatNumber(n: number): string
	for i = #suffixes, 1, -1 do
		local threshold = 10 ^ (i * 3)
		if n >= threshold then
			return string.format("%.1f%s", n / threshold, suffixes[i])
		end
	end

	return tostring(math.floor(n))
end

GeneralUtil.deepFreeze = deepFreeze

function GeneralUtil.bindToRenderStep(name: string, priority: number, func: (deltaTime: number) -> ())
	RunService:BindToRenderStep(name, priority, func)

	return {
		Disconnect = function()
			RunService:UnbindFromRenderStep(name)
			warn("dusconnected", name)
		end,
	}
end

function GeneralUtil.getPrimaryPart(object: Tool | Model)
	local primaryPart = object.PrimaryPart
	while not primaryPart do
		object:GetPropertyChangedSignal("PrimaryPart"):Wait()
		primaryPart = object.PrimaryPart
	end

	return primaryPart
end

function GeneralUtil.secondsToMMSS(seconds: number): string
	seconds = math.max(0, math.floor(seconds + 0.5))

	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60

	return string.format("%02d:%02d", minutes, secs)
end

--[[
	Returns whether the environment allows debug actions.
	This is resolved at module load-time to eliminate environment branch checks
	and C-boundary calls (RunService:IsStudio) during hot runtime loops.
]]
GeneralUtil.canDebug = (
	if IS_STUDIO
		then function(debug: boolean)
			return debug
		end
		else function(_debug: boolean)
			return false
		end
) :: (debug: boolean) -> boolean

function GeneralUtil.isDebouncing(key: any, duration: number)
	if debouncing[key] then
		return true
	end

	debouncing[key] = true
	task.delay(duration, function()
		debouncing[key] = nil
	end)
	return false
end

--- Always returns a result, Instance & Normal might be missing depending on if :Raycast hit something.
function GeneralUtil.customCast(
	origin: Vector3,
	direction: Vector3,
	params: RaycastParams?,
	forceFake: boolean?,
	visualize: boolean?
): CastResult
	local result: CastResult = {
		Distance = direction.Magnitude,
		Instance = nil,
		Material = Enum.Material.Air,
		Normal = nil,
		Position = origin + direction,
	}
	local raycastResult = if not forceFake then workspace:Raycast(origin, direction, params) else nil
	if raycastResult then
		result.Distance = raycastResult.Distance
		result.Instance = raycastResult.Instance
		result.Material = raycastResult.Material
		result.Normal = raycastResult.Normal
		result.Position = raycastResult.Position
	end

	if visualize then
		local wfa = Instance.new("WireframeHandleAdornment")
		wfa.Adornee = workspace.Terrain
		wfa.Parent = workspace.Terrain
		wfa.Color3 = Color3.new(1, 0, 0)
		wfa:AddLine(origin, result.Position)

		if result.Normal then
			wfa.Color3 = Color3.new(0, 1, 0)
			wfa:AddLine(result.Position, result.Position + result.Normal * 4)
		end

		task.delay(5, wfa.Destroy, wfa)
	end

	return result
end

function GeneralUtil.getJointWorldCFrame(joint: JointInstance)
	local p0, p1, c0, c1 = joint.Part0, joint.Part1, joint.C0, joint.C1
	return if p0 then p0.CFrame * c0 elseif p1 then p1.CFrame * c1 else nil
end

function GeneralUtil.randomSign(): number
	return if math.random() < 0.5 then -1 else 1
end

function GeneralUtil.loadAnimationsList<K>(
	target: Animator,
	animations: { [K]: string | number },
	props: { [K]: {
		Looped: boolean?,
	} }?
): { [K]: AnimationTrack }
	local animationProps: { [K]: { Looped: boolean? } } = props or {}

	local tracks: { [K]: AnimationTrack } = {}
	for i, v in next, animations do
		local a = Instance.new("Animation")
		a.AnimationId = `rbxassetid://{v}`
		a.Parent = target
		tracks[i] = target:LoadAnimation(a)
	end

	for i, animationPropsForTrack in next, animationProps do
		local track = tracks[i]
		if track and animationPropsForTrack.Looped ~= nil then
			track.Looped = animationPropsForTrack.Looped
		end
	end

	return tracks
end

--[[
	Normalizes a separator-delimited dependency string by removing whitespace
	after each separator, then splits it into a list of entries.
]]
--- @param str string -- The raw dependency string to normalize and split.
--- @param separator string? -- The delimiter to split on. Defaults to ",".
--- @return {string} -- A list of normalized dependency entries.
function GeneralUtil.normalizeDependencyList(str: string, separator: string?)
	local delimiter = separator or ","
	return string.split(string.gsub(str, `{delimiter}%s+`, delimiter), delimiter)
end

return GeneralUtil
