local DropAnimationUtil = {}

local EncodingService = game:GetService("EncodingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CRC32C = require(ReplicatedStorage.Shared.Hashing.CRC32C)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local IS_CLIENT = RunService:IsClient()

local DISTANCE_STEPS = {
	[100] = 8,
	[200] = 15,
}

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type UpgraderHitHandler = (animation: ActiveAnimation, upgraderIndex: number) -> ()
type FinishedHandler = (animation: ActiveAnimation) -> ()

type Keyframe = {
	CFrame: CFrame,
	Time: number,
}

type DecodedTrack = {
	UpgraderTimestamps: { number },
	Keyframes: { Keyframe },
	Duration: number,
}

export type ActiveAnimation = {
	Frame: number,
	Root: BasePart,
	Subject: BasePart,
	Keyframes: { Keyframe },
	Duration: number,
	UpgraderTimestamps: { number },
	StartTime: number,
	OldKeyframeIndex: number,
	NextKeyframeIndex: number,
	NextUpgraderIndex: number,

	OnUpgraderHit: UpgraderHitHandler,
	OnFinished: FinishedHandler,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local decodedTracks: { [number]: DecodedTrack } = {}
local activeAnimations: { ActiveAnimation } = {}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

--- Returns how often a conveyor should update it's bags based on distance
--- Uses a simple lookup instead of math to keep it predictable and cheap
local function getStepFromDistance(distance: number)
	local step = 1
	for treshold, s in DISTANCE_STEPS do
		if distance > treshold then
			step = s
			break
		end
	end
	return step
end

local function decode(track: string)
	local trackHash = CRC32C(buffer.fromstring(track))
	if decodedTracks[trackHash] then
		return decodedTracks[trackHash]
	end

	local b = EncodingService:DecompressBuffer(buffer.fromstring(track), Enum.CompressionAlgorithm.Zstd)

	local offset = 0

	local duration
	duration, offset = BufferUtil.readf32(b, offset)

	local min, max
	min, offset = BufferUtil.readVector3_96(b, offset)
	max, offset = BufferUtil.readVector3_96(b, offset)

	local upgraderAmount
	upgraderAmount, offset = BufferUtil.readu8(b, offset)

	local upgradeTimestamps = {}
	for i = 1, upgraderAmount do
		local t
		t, offset = BufferUtil.readf32(b, offset)
		upgradeTimestamps[i] = t
	end
	table.sort(upgradeTimestamps)

	local keyframes = {}
	while offset < buffer.len(b) do
		local t, px, py, pz, rx, ry, rz

		t, offset = BufferUtil.readf32(b, offset)
		px, offset = BufferUtil.readu16(b, offset)
		py, offset = BufferUtil.readu16(b, offset)
		pz, offset = BufferUtil.readu16(b, offset)
		rx, offset = BufferUtil.readu16(b, offset)
		ry, offset = BufferUtil.readu16(b, offset)
		rz, offset = BufferUtil.readu16(b, offset)

		table.insert(keyframes, {
			Time = t,
			CFrame = CFrame.fromOrientation(
				math.map(rx, 0, 65535, -math.pi, math.pi),
				math.map(ry, 0, 65535, -math.pi, math.pi),
				math.map(rz, 0, 65535, -math.pi, math.pi)
			) + Vector3.new(
				math.map(px, 0, 65535, min.X, max.X),
				math.map(py, 0, 65535, min.Y, max.Y),
				math.map(pz, 0, 65535, min.Z, max.Z)
			),
		})
	end

	local decodedTrack: DecodedTrack = {
		UpgraderTimestamps = upgradeTimestamps,
		Keyframes = keyframes,
		Duration = duration,
	}

	decodedTracks[trackHash] = decodedTrack
	return decodedTrack
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function DropAnimationUtil.length(track: string)
	return decode(track).Duration
end

function DropAnimationUtil.play(
	track: string,
	root: BasePart,
	subject: BasePart,
	onFinished: FinishedHandler,
	onUpgraderHit: UpgraderHitHandler
)
	if not IS_CLIENT then
		error("Can only play DropAnimations on the client")
	end

	subject.Anchored = true
	subject.CFrame = root.CFrame

	local decoded = decode(track)
	local index = #activeAnimations + 1

	activeAnimations[index] = {
		Frame = 0,
		Root = root,
		Subject = subject,
		Keyframes = decoded.Keyframes,
		Duration = decoded.Duration,
		UpgraderTimestamps = decoded.UpgraderTimestamps,
		StartTime = os.clock(),
		OldKeyframeIndex = 1,
		NextKeyframeIndex = 2,
		NextUpgraderIndex = 1,

		OnFinished = onFinished,
		OnUpgraderHit = onUpgraderHit,
	}
end

-------------------------------------------------------------------------------
-- LOGIC
-------------------------------------------------------------------------------

if IS_CLIENT then
	local camera = workspace.CurrentCamera

	RunService.RenderStepped:Connect(function()
		local cameraPosition = camera.CFrame.Position
		local parts: { BasePart }, cframes: { CFrame } = {}, {}
		local t = os.clock()

		local i = 1
		while i <= #activeAnimations do
			local animation = activeAnimations[i]
			local root = animation.Root

			local dT = t - animation.StartTime
			animation.Frame += 1

			if dT >= animation.Duration or not workspace:IsAncestorOf(root) then
				task.spawn(animation.OnFinished, animation)
				table.remove(activeAnimations, i)
				continue
			end

			local upgraderTimestamps = animation.UpgraderTimestamps
			local nextUpgraderIndex = animation.NextUpgraderIndex
			while nextUpgraderIndex <= #upgraderTimestamps and dT >= upgraderTimestamps[nextUpgraderIndex] do
				task.spawn(animation.OnUpgraderHit, animation, nextUpgraderIndex)
				nextUpgraderIndex += 1
				animation.NextUpgraderIndex = nextUpgraderIndex
			end

			local step = getStepFromDistance((animation.Root.Position - cameraPosition).Magnitude)
			if animation.Frame % step == 0 then
				local subject = animation.Subject
				local keyframes = animation.Keyframes
				local nextKeyframe = keyframes[animation.NextKeyframeIndex]
				local oldKeyframe = keyframes[animation.OldKeyframeIndex]

				if dT >= nextKeyframe.Time then
					for j = animation.NextKeyframeIndex + 1, #keyframes do
						local v = keyframes[j]
						if dT < v.Time then
							animation.OldKeyframeIndex, animation.NextKeyframeIndex = j - 1, j
							nextKeyframe, oldKeyframe = v, keyframes[j - 1]
							break
						end
					end
				end

				local alpha = math.map(dT, oldKeyframe.Time, nextKeyframe.Time, 0, 1)
				table.insert(parts, subject)
				table.insert(cframes, root.CFrame * oldKeyframe.CFrame:Lerp(nextKeyframe.CFrame, alpha))
			end

			i += 1
		end

		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end)
end

return DropAnimationUtil
