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
local AnimationJointUtil = require(ReplicatedStorage.Shared.Utils.AnimationJointUtil)
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
   Humanoid: Humanoid,
   Animator: Animator,
   Waist: AnimationJointUtil.Binding,
   Neck: AnimationJointUtil.Binding,
   WaistFrame: CFrame,
   NeckFrame: CFrame,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local unreliableEvent = SimpleRemotes.getUnreliableEvent("Character")

local playersSolverTarget: { [Player]: Vector3 } = {}
local characterInstances: { [GameTypes.R15Character]: RequiredCharacterInstances } = {}

local nextReplicationAt = 0

local equippedGunModule: GameTypes.GunModule?

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function solveJointsForCharacter(character: GameTypes.R15Character, lookAt: Vector3, dT: number)
   local instances = characterInstances[character]
   if not instances then
      local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
      local upperTorso = character:FindFirstChild("UpperTorso")
      local head = character:FindFirstChild("Head")
      local humanoid = character:FindFirstChild("Humanoid")

      if
         not (
            humanoidRootPart
            and humanoidRootPart:IsA("BasePart")
            and upperTorso
            and head
            and humanoid
            and humanoid:IsA("Humanoid")
         )
      then
         return
      end

      local animator = humanoid:FindFirstChildOfClass("Animator")
      local waistJoint = AnimationJointUtil.find(upperTorso, "Waist")
      local neckJoint = AnimationJointUtil.find(head, "Neck")
      if not (animator and waistJoint and neckJoint) then
         return
      end

      local waist = AnimationJointUtil.bind(waistJoint)
      local neck = AnimationJointUtil.bind(neckJoint)
      if not (waist and neck) then
         return
      end

      instances = {
         HumanoidRootPart = humanoidRootPart,
         Humanoid = humanoid,
         Animator = animator,
         Waist = waist,
         Neck = neck,
         WaistFrame = waist.OriginFrame,
         NeckFrame = neck.OriginFrame,
      }

      characterInstances[character] = instances
   end

   local humanoidRootPart, humanoid = instances.HumanoidRootPart, instances.Humanoid

   if not instances.Animator.EvaluationThrottled then
      local waist, neck = instances.Waist, instances.Neck
      local neckYawAngle = 0

      local waistTarget = (waist.OriginPart.CFrame * waist.OriginFrame):PointToObjectSpace(lookAt)
      local waistYawAngle =
         math.clamp(math.atan2(-waistTarget.X, -waistTarget.Z), -ANGLE_LIMITS.WaistYaw, ANGLE_LIMITS.WaistYaw)
      local waistPitchAngle = math.clamp(
         math.atan2(waistTarget.Y, Vector2.new(waistTarget.X, waistTarget.Z).Magnitude),
         -ANGLE_LIMITS.WaistPitch,
         ANGLE_LIMITS.WaistPitch
      )

      if equippedGunModule and equippedGunModule.TorsoYaw then
         waistYawAngle -= equippedGunModule.TorsoYaw
         neckYawAngle += equippedGunModule.TorsoYaw
      end

      instances.WaistFrame = instances.WaistFrame:Lerp(
         waist.OriginFrame * CFrame.fromOrientation(waistPitchAngle, waistYawAngle, 0),
         dT * ANIMATION_SPEEDS.Waist
      )
      instances.NeckFrame = instances.NeckFrame:Lerp(
         neck.OriginFrame * CFrame.fromOrientation(0, neckYawAngle, 0),
         dT * ANIMATION_SPEEDS.Waist
      )

      AnimationJointUtil.applyOriginFrame(waist, instances.WaistFrame, true)
      AnimationJointUtil.applyOriginFrame(neck, instances.NeckFrame, true)
   end

   -- Compute root (local player only)
   if character == player.Character and not humanoid.SeatPart then
      local delta = lookAt - humanoidRootPart.Position
      local yawAngle = math.atan2(-delta.X, -delta.Z)

      humanoidRootPart.CFrame = humanoidRootPart.CFrame:Lerp(
         CFrame.Angles(0, yawAngle, 0) + humanoidRootPart.Position,
         dT * ANIMATION_SPEEDS.Root
      )
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
         solveJointsForCharacter(forPlayer.Character, solverTarget, dT)
      end
   end
end

local function onAnyCharacterRemoved(character: GameTypes.R15Character)
   local instances = characterInstances[character]
   if instances then
      AnimationJointUtil.clearAppliedOriginFrame(instances.Waist)
      AnimationJointUtil.clearAppliedOriginFrame(instances.Neck)
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
   workspace.World.Characters.ChildRemoved:Connect(onAnyCharacterRemoved)
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
