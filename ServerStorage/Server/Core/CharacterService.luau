--[[
  CharacterService

  Description:
  Handles server-side character management

  Author:
  @SixthAtom

  Date:
  28-02-2026
]]

local CharacterService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local ConnectionsList = require(ReplicatedStorage.Shared.Classes.ConnectionsList)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)
local GlobalInstanceService = require(ServerStorage.Server.Services.GlobalInstanceService)
local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local CollisionConstants = require(ReplicatedStorage.Shared.Constants.CollisionConstants)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local SimpleRemotesUtil = require(ReplicatedStorage.Shared.Networking.SimpleRemotesUtil)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)
local PartUtil = require(ReplicatedStorage.Shared.Utils.PartUtil)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local UNRELIABLE_CODES = RemoteCodes.Character.Unreliable
local COLLISION_GROUP = CollisionConstants.Groups.Characters

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type CharacterAddedTask = (character: Model, player: Player) -> ()
type CharacterRemovingTask = (character: Model, player: Player) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local unreliableEvent = SimpleRemotes.getUnreliableEvent("Character")
local solverTargetReplicationSchedule: { { Player: Player, SolverTarget: Vector3 } } = {}

local playerConnections: { [Player]: ConnectionsList.ConnectionsList } = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

CharacterService.CharacterAddedTasks = TasksList.new() :: TasksList.TasksList<CharacterAddedTask>
CharacterService.CharacterRemovingTasks = TasksList.new() :: TasksList.TasksList<CharacterRemovingTask>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function onCharacterAdded(character: Model)
	-- Prepare character
	local hitbox = PartUtil.createHitbox(character)
	hitbox.CanQuery = false -- This hitbox isn't for raycasts

	character.Parent = workspace.Characters

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.AutoRotate = false

	for _, v in next, character:QueryDescendants("BasePart") :: { BasePart } do
		v.CollisionGroup = COLLISION_GROUP
	end

	-- Execute tasks
	CharacterService.CharacterAddedTasks:Execute("parallel", character, Players:GetPlayerFromCharacter(character))
end

local function onCharacterRemoving(character: Model)
	CharacterService.CharacterRemovingTasks:Execute("parallel", character, Players:GetPlayerFromCharacter(character))
end

local function dispatchSchedule()
	if #solverTargetReplicationSchedule <= 0 then
		return
	end

	task.defer(task.defer, function()
		local len = #solverTargetReplicationSchedule
		local b, offset = buffer.create(1 + len * 16), 0
		offset = BufferUtil.writeu8(b, offset, UNRELIABLE_CODES.SetTargetsBulk)

		for i = 1, len do
			local v = solverTargetReplicationSchedule[i]

			offset = BufferUtil.writeu32(b, offset, GlobalInstanceService.getId(v.Player.Character))
			offset = BufferUtil.writeVector3_96(b, offset, v.SolverTarget)
		end

		unreliableEvent:FireAllClients(b)
		solverTargetReplicationSchedule = {}
	end)
end

local function loadCharacterRemotes()
	SimpleRemotesUtil.bindRemoteEventActions(unreliableEvent, {
		[UNRELIABLE_CODES.SetTargetsBulk] = function(player: Player, b: buffer)
			local solverTarget
			local offset = 0

			solverTarget, offset = BufferUtil.readVector3_96(b, offset)

			table.insert(solverTargetReplicationSchedule, { Player = player, SolverTarget = solverTarget })
		end,
	}, SimpleRemotesUtil.DecodeActionBuffer)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function CharacterService.init()
	loadCharacterRemotes()

	PlayerDataService.ProfileAddedTasks:Add(function(player)
		playerConnections[player] = ConnectionsList.new({
			PlayersUtil.onCharacterAdded(player, onCharacterAdded),
			player.CharacterRemoving:Connect(onCharacterRemoving),
		})
	end)

	Players.PlayerRemoving:Connect(function(player)
		local playerConnectionList = playerConnections[player]
		if playerConnectionList then
			playerConnectionList:Destroy()
		end

		playerConnections[player] = nil
	end)

	RunService.PostSimulation:Connect(dispatchSchedule)
end

function CharacterService.start() end

function CharacterService.test() end

return CharacterService
