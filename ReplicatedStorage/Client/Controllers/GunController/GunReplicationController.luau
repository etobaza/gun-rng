--[[
  GunReplicationController

  Description:
  Handles replicated gun effects & animations

  Author:
  @SixthAtom

  Date:
  05-04-2026
]]

local GunReplicationController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ConnectionsList = require(ReplicatedStorage.Shared.Classes.ConnectionsList)
local IKSolver = require(ReplicatedStorage.Shared.Classes.IKSolver)
local EquipmentConstants = require(ReplicatedStorage.Shared.Constants.EquipmentConstants)
local GameTypes = require(ReplicatedStorage.Shared.GameTypes)
local AnimationJointUtil = require(ReplicatedStorage.Shared.Utils.AnimationJointUtil)
local GeneralUtil = require(ReplicatedStorage.Shared.Utils.GeneralUtil)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local EQUIPMENT_SLOTS = EquipmentConstants.Slots
local WEAPON_MODULES = ReplicatedStorage.Shared.Weapons

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local function isChildAGunTool(child: Instance)
   return child:IsA("Tool") and child:GetAttribute("Slot") == EQUIPMENT_SLOTS.Gun
end

local function onPlayerAdded(player: Player)
   if player == Players.LocalPlayer then
      return
   end

   local toolEquippedConnections: { [Tool]: ConnectionsList.ConnectionsList } = {}

   PlayersUtil.onCharacterAdded(player, function(character: GameTypes.R15Character)
      local rightSolver: IKSolver.IkSolver?, leftSolver: IKSolver.IkSolver?

      character.ChildAdded:Connect(function(tool: GameTypes.GunModel)
         if not isChildAGunTool(tool) then
            return
         end

         local gunModule = require(WEAPON_MODULES[tool.Name])() :: GameTypes.GunModule

         local offsets = gunModule.Offsets

         local lowerTorso = character.LowerTorso
         local animator = character.Humanoid:WaitForChild("Animator") :: Animator
         local waist = AnimationJointUtil.requireBinding(AnimationJointUtil.waitFor(character.UpperTorso, "Waist"))
         local rightShoulder = AnimationJointUtil.waitFor(character.RightUpperArm, "RightShoulder")
         local rightElbow = AnimationJointUtil.waitFor(character.RightLowerArm, "RightElbow")
         local rightWrist = AnimationJointUtil.waitFor(character.RightHand, "RightWrist")
         local leftShoulder = AnimationJointUtil.waitFor(character.LeftUpperArm, "LeftShoulder")
         local leftElbow = AnimationJointUtil.waitFor(character.LeftLowerArm, "LeftElbow")
         local leftWrist = AnimationJointUtil.waitFor(character.LeftHand, "LeftWrist")

         local gunRoot = GeneralUtil.getPrimaryPart(tool)
         local gunRootConstraint =
            AnimationJointUtil.requireBinding(AnimationJointUtil.waitFor(gunRoot, "RootConstraint"))

         local leftArm, rightArm = tool["Left Arm"], tool["Right Arm"]

         local equippedConnections = ConnectionsList.new({
            RunService.PreSimulation:Connect(function()
               if animator.EvaluationThrottled then
                  return
               end

               if not (leftSolver and rightSolver) then
                  rightSolver = IKSolver.new(rightShoulder, rightElbow, rightWrist)
                  leftSolver = IKSolver.new(leftShoulder, leftElbow, leftWrist)
               end

               local leftSolverTarget = leftArm.CFrame * offsets.LeftArmSolver
               local rightSolverTarget = rightArm.CFrame * offsets.RightArmSolver

               leftSolver:solve(leftSolverTarget)
               rightSolver:solve(rightSolverTarget)

               local waistRotation =
                  CFrame.Angles(AnimationJointUtil.getAppliedOriginFrame(waist):ToOrientation(), 0, 0)
               local torsoRotated = lowerTorso.CFrame.Rotation * waistRotation
               local origin = (lowerTorso.CFrame * waistRotation):PointToWorldSpace(
                  gunModule.Offsets.ThirdPerson.Position
               )
               local direction = torsoRotated.LookVector

               AnimationJointUtil.setPose(
                  gunRootConstraint,
                  lowerTorso.CFrame:ToObjectSpace(CFrame.lookAlong(origin, direction))
               )
            end),
         })

         toolEquippedConnections[tool] = equippedConnections
      end)

      character.ChildRemoved:Connect(function(tool: GameTypes.GunModel)
         if not isChildAGunTool(tool) then
            return
         end

         local equippedConnections = toolEquippedConnections[tool]
         if equippedConnections then
            equippedConnections:Destroy()
            toolEquippedConnections[tool] = nil
         end
      end)
   end)
end

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function GunReplicationController.init()
   PlayersUtil.onPlayerAdded(onPlayerAdded)
end

-- function GunReplicationController.start() end

-- function GunReplicationController.test() end

return GunReplicationController
