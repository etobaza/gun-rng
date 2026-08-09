--[[
  CharacterController

  Description:
  Handles client-sided character operations

  Author:
  @SixthAtom

  Date:
  05-04-2026
]]

local CharacterController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GlobalInstanceController = require(ReplicatedStorage.Client.Controllers.GlobalInstanceController)
local GunController = require(ReplicatedStorage.Client.Controllers.GunController)
local GameTypes = require(ReplicatedStorage.Shared.GameTypes)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local SimpleRemotesUtil = require(ReplicatedStorage.Shared.Networking.SimpleRemotesUtil)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local REPLICATION_RATE = 1 / 15

local ANIMATION_SPEEDS = table.freeze({
	Waist = 14,
	Root = 8,
})

local ANGLE_LIMITS = table.freeze({
	WaistYaw = math.rad(35),
	WaistPitch = math.rad(45),
})

local UNRELIABLE_CODES = RemoteCodes.Character.Unreliable

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type RequiredCharacterInstances = {
	HumanoidRootPart: BasePart,
	Waist: Motor6D,
	Neck: Motor6D,
	Humanoid: Humanoid,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local unreliableEvent = SimpleRemotes.getUnreliableEvent("Character")

local playersSolverTarget: { [Player]: Vector3 } = {}
local characterInstances: { [GameTypes.R15Character]: RequiredCharacterInstances } = {}
local motorsBaseC0: { [Motor6D]: CFrame } = {}

local nextReplicationAt = 0

local equippedGunModule: GameTypes.GunModule?

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function solveMotorsForCharacter(character: GameTypes.R15Character, lookAt: Vector3, dT: number)
	local instances = characterInstances[character]
	if not instances then
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		local upperTorso = character:FindFirstChild("UpperTorso")
		local head = character:FindFirstChild("Head")
		local humanoid = character:FindFirstChild("Humanoid")

		if not (humanoidRootPart and upperTorso and humanoid and head) then
			return
		end

		local waistM6D = upperTorso:FindFirstChild("Waist")
		local neckM6D = head:FindFirstChild("Neck")
		if not (waistM6D and neckM6D) or not (waistM6D:IsA("Motor6D") and neckM6D:IsA("Motor6D")) then
			return
		end

		instances = {
			HumanoidRootPart = humanoidRootPart,
			Humanoid = humanoid,
			Waist = waistM6D,
			Neck = neckM6D,
		}

		motorsBaseC0[waistM6D] = waistM6D.C0
		motorsBaseC0[neckM6D] = neckM6D.C0
		characterInstances[character] = instances
	end

	local humanoidRootPart, humanoid, waistM6D, neckM6D = instances.HumanoidRootPart, instances.Humanoid, instances.Waist, instances.Neck
	local waistBaseC0, neckBaseC0 = motorsBaseC0[waistM6D], motorsBaseC0[neckM6D]

	-- Compute waist & neck
	local neckYawAngle = 0

	local waistTarget = (waistM6D.Part0.CFrame * waistBaseC0):PointToObjectSpace(lookAt)
	local waistYawAngle = math.clamp(math.atan2(-waistTarget.X, -waistTarget.Z), -ANGLE_LIMITS.WaistYaw, ANGLE_LIMITS.WaistYaw)
	local waistPitchAngle = math.clamp(math.atan2(waistTarget.Y, Vector2.new(waistTarget.X, waistTarget.Z).Magnitude), -ANGLE_LIMITS.WaistPitch, ANGLE_LIMITS.WaistPitch)

	if equippedGunModule and equippedGunModule.TorsoYaw then
		waistYawAngle -= equippedGunModule.TorsoYaw
		neckYawAngle += equippedGunModule.TorsoYaw
	end

	waistM6D.C0 = waistM6D.C0:Lerp(waistBaseC0 * CFrame.fromOrientation(waistPitchAngle, waistYawAngle, 0), dT * ANIMATION_SPEEDS.Waist)
	neckM6D.C0 = neckM6D.C0:Lerp(neckBaseC0 * CFrame.fromOrientation(0, neckYawAngle, 0), dT * ANIMATION_SPEEDS.Waist)

	-- Compute root (local player only)
	if character == player.Character and not humanoid.SeatPart then
		local delta = lookAt - humanoidRootPart.Position
		local yawAngle = math.atan2(-delta.X, -delta.Z)

		humanoidRootPart.CFrame = humanoidRootPart.CFrame:Lerp(CFrame.Angles(0, yawAngle, 0) + humanoidRootPart.Position, dT * ANIMATION_SPEEDS.Root)
	end
end

local function onPreSimulation(dT: number)
	local localTarget = mouse.Hit.Position
	playersSolverTarget[player] = localTarget

	if PlayersUtil.isAlive(player) then
		local now = os.clock()
		if now >= nextReplicationAt then
			nextReplicationAt = now + REPLICATION_RATE

			unreliableEvent:FireServer(BufferUtil.construct({
				{ Type = "U8", Value = UNRELIABLE_CODES.SetTargetsBulk },
				{ Type = "VECTOR3_96", Value = localTarget },
			}))
		end
	end

	for forPlayer, solverTarget in next, playersSolverTarget do
		if PlayersUtil.isAlive(forPlayer) then
			solveMotorsForCharacter(forPlayer.Character, solverTarget, dT)
		end
	end
end

local function onAnyCharacterRemoved(character: GameTypes.R15Character)
	local instances = characterInstances[character]
	if instances then
		motorsBaseC0[instances.Waist] = nil
	end
	characterInstances[character] = nil
end

local function onPlayerRemoving(removingPlayer: Player)
	playersSolverTarget[removingPlayer] = nil
end

local function loadRemotes()
	SimpleRemotesUtil.bindRemoteEventActions(unreliableEvent, {
		[UNRELIABLE_CODES.SetTargetsBulk] = function(b: buffer)
			local len, offset = buffer.len(b) / 16, 0
			for _ = 1, len do
				local instanceId, solverTarget
				instanceId, offset = BufferUtil.readu32(b, offset)
				solverTarget, offset = BufferUtil.readVector3_96(b, offset)

				local character = GlobalInstanceController.getInstance(instanceId)
				if not character then
					continue
				end

				local forPlayer = Players:GetPlayerFromCharacter(character)
				if not forPlayer or forPlayer == player then
					continue
				end

				playersSolverTarget[forPlayer] = solverTarget
			end
		end,
	}, SimpleRemotesUtil.DecodeActionBuffer)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function CharacterController.init()
	loadRemotes()

	RunService.PreSimulation:Connect(onPreSimulation)
	workspace.Characters.ChildRemoved:Connect(onAnyCharacterRemoved)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	GunController.GunEquipped:Connect(function(_, gunModule)
		equippedGunModule = gunModule
	end)

	GunController.GunUnequipped:Connect(function(_, gunModule)
		if gunModule == equippedGunModule then
			equippedGunModule = nil
		end
	end)
end

function CharacterController.start() end

function CharacterController.test() end

return CharacterController
