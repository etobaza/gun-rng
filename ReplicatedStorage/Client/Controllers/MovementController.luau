--[[
  MovementController

  Description:
  Handles movement

  Author:
  @SixthAtom

  Date:
  28-03-2026
]]

local MovementController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputController = require(ReplicatedStorage.Client.Core.InputController)
local MovementConstants = require(ReplicatedStorage.Shared.Constants.MovementConstants)
local InputConstants = require(ReplicatedStorage.Shared.Constants.InputConstants)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local INPUT_ACTIONS = InputConstants.Actions
local WALK_SPEED = MovementConstants.WalkSpeed
local SPRINT_SPEED = MovementConstants.SprintSpeed

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

MovementController.Sprinting = false

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function registerInputs()
	InputController.registerInput(INPUT_ACTIONS.Sprint, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3, function(state)
		MovementController.setSprint(state == Enum.UserInputState.Begin)
	end, {
		RequiresAlive = true,
		MobileButton = {
			SizeMultiplier = 0.75,
			PositionOffsetScalar = Vector2.new(-1.71, -0.33),
			Radius = UDim.new(1, 0),
			IsToggle = true,
		},
	})
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function MovementController.setSprint(value: boolean)
	if MovementController.Sprinting == value then
		return
	end

	MovementController.Sprinting = value

	local humanoid = PlayersUtil.getHumanoid(player)
	if humanoid then
		humanoid.WalkSpeed = if MovementController.Sprinting then SPRINT_SPEED else WALK_SPEED
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function MovementController.init()
	registerInputs()
end

-- function MovementController.start() end

-- function MovementController.test() end

return MovementController
