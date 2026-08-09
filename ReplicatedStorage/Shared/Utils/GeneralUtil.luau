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

function GeneralUtil.deepFreeze<T>(tbl: T): T
	if type(tbl) ~= "table" then
		return tbl
	end

	for _, v in tbl do
		if type(v) == "table" then
			GeneralUtil.deepFreeze(v)
		end
	end

	if not table.isfrozen(tbl) then
		table.freeze(tbl)
	end

	return tbl
end

function GeneralUtil.bindToRenderStep(name: string, priority: number, func: (deltaTime: number) -> ())
   RunService:BindToRenderStep(name, priority, func)

   return {
      Disconnect = function()
         RunService:UnbindFromRenderStep(name)
         warn('dusconnected', name)
      end
   }
end

function GeneralUtil.getPrimaryPart(object: Tool | Model)
	if object.PrimaryPart then
		return object.PrimaryPart
	end

	object:GetPropertyChangedSignal("PrimaryPart"):Wait()
	return object.PrimaryPart
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
GeneralUtil.canDebug = (if IS_STUDIO then function(debug: boolean)
	return debug
end else function(_debug: boolean)
		return false
	end) :: (debug: boolean) -> boolean

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
): {
	Instance: Instance?,
	Normal: Vector3?,
	Material: Enum.Material,
	Distance: number,
	Position: Vector3,
	}
	local result = if not forceFake then workspace:Raycast(origin, direction, params) else nil
	if not result then
		result = {
			Distance = direction.Magnitude,
			Material = Enum.Material.Air,
			Position = origin + direction,
		}
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

function GeneralUtil.loadAnimationsList<I>(
	target: Animator,
	animations: I,
	props: { [keyof<I>]: {
		Looped: boolean?,
	} }?
): { [keyof<I>]: AnimationTrack }
	props = props or {}

	local tracks = {}
	for i, v in next, animations do
		local a = Instance.new("Animation")
		a.AnimationId = `rbxassetid://{v}`
		a.Parent = target
		tracks[i] = target:LoadAnimation(a)
	end

	for i, list in next, props do
		for name, value in next, list do
			tracks[i][name] = value
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
	if not separator then
		separator = ","
	end
	return string.split(string.gsub(str, `{separator}%s+`, separator), separator)
end

return GeneralUtil
