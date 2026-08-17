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
local GeneralUtil = require(ReplicatedStorage.Shared.Utils.GeneralUtil)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local EQUIPMENT_SLOTS = EquipmentConstants.Slots
local WEAPON_MODULES = ReplicatedStorage.Shared.Weapons

local IDENTITY_CF = CFrame.identity

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
		local rightSolver: IKSolver.IkSolver, leftSolver: IKSolver.IkSolver

		character.ChildAdded:Connect(function(tool: GameTypes.GunModel)
			if not isChildAGunTool(tool) then
				return
			end

			local gunModule = require(WEAPON_MODULES[tool.Name])() :: GameTypes.GunModule

			local offsets = gunModule.Offsets

			local lowerTorso = character.LowerTorso
			local waist = character.UpperTorso.Waist
			local rightShoulder, rightElbow, rightWrist = character.RightUpperArm.RightShoulder, character.RightLowerArm.RightElbow, character.RightHand.RightWrist
			local leftShoulder, leftElbow, leftWrist = character.LeftUpperArm.LeftShoulder, character.LeftLowerArm.LeftElbow, character.LeftHand.LeftWrist

			local gunRoot = GeneralUtil.getPrimaryPart(tool)
			local gunRootM6D = gunRoot:WaitForChild("RootMotor") :: Motor6D

			local leftArm, rightArm = tool["Left Arm"], tool["Right Arm"]

			local equippedConnections = ConnectionsList.new({
				RunService.PreSimulation:Connect(function()
					if not rightShoulder or not leftShoulder then
						return
					end

					if not leftSolver then
						rightSolver = IKSolver.new(character.RightUpperArm.RightShoulder, character.RightLowerArm.RightElbow, character.RightHand.RightWrist)
						leftSolver = IKSolver.new(character.LeftUpperArm.LeftShoulder, character.LeftLowerArm.LeftElbow, character.LeftHand.LeftWrist)
					end

					rightShoulder.Transform, rightElbow.Transform, rightWrist.Transform = IDENTITY_CF, IDENTITY_CF, IDENTITY_CF
					leftShoulder.Transform, leftElbow.Transform, leftWrist.Transform = IDENTITY_CF, IDENTITY_CF, IDENTITY_CF

					local leftSolverTarget = leftArm.CFrame * offsets.LeftArmSolver
					local rightSolverTarget = rightArm.CFrame * offsets.RightArmSolver

					leftSolver:solve(leftSolverTarget)
					rightSolver:solve(rightSolverTarget)

					-- Update gun's root motor
					local waistRotation = CFrame.Angles(waist.C0:ToOrientation(), 0, 0)
					local torsoRotated = lowerTorso.CFrame.Rotation * waistRotation
					local origin = (lowerTorso.CFrame * waistRotation):PointToWorldSpace(gunModule.Offsets.ThirdPerson.Position)
					local direction = torsoRotated.LookVector

					gunRootM6D.C0 = lowerTorso.CFrame:ToObjectSpace(CFrame.lookAlong(origin, direction))
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
