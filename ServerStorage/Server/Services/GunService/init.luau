--[[
  GunService

  Description:
  Handles the gun on the server side

  Author:
  @SixthAtom

  Date:
  01-04-2026
]]

local GunService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BulletTrackingConstants = require(ReplicatedStorage.Shared.Constants.BulletTrackingConstants)
local WeaponConstants = require(ReplicatedStorage.Shared.Constants.WeaponConstants)
local GameTypes = require(ReplicatedStorage.Shared.GameTypes)
local BanService = require(ServerStorage.Server.Core.BanService)
local GlobalInstanceService = require(ServerStorage.Server.Services.GlobalInstanceService)
local BulletTrackingService = require(ServerStorage.Server.Services.GunService.BulletTrackingService)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local SimpleRemotesUtil = require(ReplicatedStorage.Shared.Networking.SimpleRemotesUtil)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)
local GeneralUtil = require(ReplicatedStorage.Shared.Utils.GeneralUtil)
local InstanceUtil = require(ReplicatedStorage.Shared.Utils.InstanceUtil)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local WeaponsUtil = require(ReplicatedStorage.Shared.Utils.WeaponsUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local FUNCTION_CODES = RemoteCodes.Guns.Functions
local EVENT_CODES = RemoteCodes.Guns.Events

local WEAPON_MODULES = ReplicatedStorage.Shared.Weapons

local GUN_ACTIONS = WeaponConstants.GunActions
local OWNER_TYPES = BulletTrackingConstants.OwnerTypes

local ROLLING_CODE_BYTES = 20 -- Offset by N, because this is the length of the RC with the additional characters

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type GunModule = typeof(require(ReplicatedStorage.Shared.Weapons.M1911)())

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local loadedToolsByPlayer: { [Player]: { [Tool]: true } } = {}

local globalRemoteEvent = SimpleRemotes.getEvent("Guns")

local rng = Random.new()

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function banIfDifferent(player: Player, otherPlayer: Player)
	local same = player == otherPlayer
	if not same then
		BanService.ban(otherPlayer, {
			BaseDuration = BanService.Times.Year,
			PrivateReason = "Retrieving someone elses rolling rode",
		})
	end
	return not same
end

local function getDamageValue(gunModule: GameTypes.GunModule, hitLimb: BasePart)
	local damages = gunModule.Damage
	local limbName = hitLimb.Name

	if limbName == "Head" then
		return damages.Head
	elseif limbName == "LowerTorso" or string.match(limbName, "Leg") or string.match(limbName, "Foot") then
		return damages.Lower
	else
		return damages.Upper
	end
end

local function loadGunTool(player: Player, tool: GameTypes.GunModel)
	loadedToolsByPlayer[player][tool] = true

	local gunModule = require(WEAPON_MODULES[tool.Name])() :: GunModule
	local character = (player.Character or player.CharacterAdded:Wait()) :: GameTypes.R15Character
	local characterInstanceId = GlobalInstanceService.getId(character)
	local gunRoot = GeneralUtil.getPrimaryPart(tool)

	local remoteFunction = SimpleRemotes.getFunction("RemoteFunction", tool)
	local remoteEvent = SimpleRemotes.getEvent("RemoteEvent", tool)

	-- Rolling codes
	local rcStartValue = rng:NextInteger(-1200, -700)
	local rcIncrementValue = rng:NextInteger(1000, 9999) / rng:NextInteger(100, 1000)
	local rcFinishValue = rcStartValue + rcIncrementValue * rng:NextInteger(200, 400)
	local rcCurrentValue = rcStartValue
	local rcRetrieved = false

	-- Localize variables
	local currentAmmo = gunModule.MagazineSize
	local offsets = gunModule.Offsets
	local gunAction = gunModule.Action

	local rootMotor6D = Instance.new("Motor6D")
	rootMotor6D.Part0 = character:WaitForChild("LowerTorso")
	rootMotor6D.Part1 = gunRoot
	rootMotor6D.C0 = offsets.ThirdPerson
	rootMotor6D.Name = "RootMotor"
	rootMotor6D.Parent = gunRoot
	gunRoot.Anchored = false

	local leftArm, rightArm = tool["Left Arm"], tool["Right Arm"]
	leftArm.Transparency = 1
	rightArm.Transparency = 1

	--[[
      Helper methods
   ]]

	local function getRollingCode()
		local old = rcCurrentValue
		rcCurrentValue += rcIncrementValue
		if rcCurrentValue > rcFinishValue then
			rcCurrentValue = rcStartValue
		end
		return old
	end

	local function banIfRCMismatch(clientRCValue: number, serverRCValue: number)
		local same = clientRCValue == serverRCValue
		if not same then
			BanService.ban(player, {
				BaseDuration = BanService.Times.Year,
				PrivateReason = "Rolling code mismatch on shoot action",
			})
		end
		return not same
	end

	--[[
      Connect remote function and event
   ]]

	SimpleRemotesUtil.bindRemoteFunctionActions(remoteFunction, {
		[FUNCTION_CODES.GetRC] = function(otherPlayer: Player)
			if banIfDifferent(player, otherPlayer) then
				return
			end

			if rcRetrieved then
				BanService.ban(player, {
					BaseDuration = BanService.Times.Year,
					PrivateReason = "Retrieving already retrieved rolling code",
				})
				return
			end

			rcRetrieved = true

			return rcStartValue, rcIncrementValue, rcFinishValue, rcStartValue
		end,
	}, SimpleRemotesUtil.DecodeActionBuffer)

	SimpleRemotesUtil.bindRemoteEventActions(remoteEvent, {
		[EVENT_CODES.Shoot] = function(otherPlayer: Player, b: buffer, excludeInstances: { Instance })
			if banIfDifferent(player, otherPlayer) then
				return
			end

			local serverRCValue, clientRCValue, offset = getRollingCode(), BufferUtil.readf64(b, 0), ROLLING_CODE_BYTES
			if banIfRCMismatch(clientRCValue, serverRCValue) then
				return
			end

			currentAmmo -= 1
			if currentAmmo < 0 then
				BanService.ban(player, {
					BaseDuration = BanService.Times.Week,
					PrivateReason = "Shooting without ammo",
					PublicReason = "Exploits Detected",
				})
				return
			end

			local exitNodeId, pelletAmount
			exitNodeId, offset = BufferUtil.readu32(b, offset)
			pelletAmount, offset = BufferUtil.readu8(b, offset)

			local exitNode = GlobalInstanceService.getInstance(exitNodeId) :: BasePart?
			if not exitNode then
				return
			end

			-- Read pellets & schedule bullet tracks
			local pelletVelocities = table.create(pelletAmount)
			for pelletIndex = 1, pelletAmount do
				local pelletVelocity
				pelletVelocity, offset = BufferUtil.readVector3_96(b, offset)
				pelletVelocities[pelletIndex] = pelletVelocity
			end

			BulletTrackingService.replicateShot(
				exitNode,
				pelletVelocities,
				OWNER_TYPES.Player,
				player.UserId,
				excludeInstances,
				gunModule.Caliber
			)

			-- Replicate effect to other clients
			SimpleRemotesUtil.fireAllClientsExcept(
				globalRemoteEvent,
				player,
				BufferUtil.construct({
					{ Type = "U8", Value = EVENT_CODES.Shoot },
					{ Type = "U32", Value = exitNodeId },
				})
			)
		end,

		[EVENT_CODES.Damage] = function(otherPlayer: Player, b: buffer)
			if banIfDifferent(player, otherPlayer) then
				return
			end

			local serverRCValue, clientRCValue, offset = getRollingCode(), BufferUtil.readf64(b, 0), ROLLING_CODE_BYTES
			if banIfRCMismatch(clientRCValue, serverRCValue) then
				return
			end

			local ownerType, hitCharacterInstanceId, hitInstanceId
			ownerType, offset = BufferUtil.readu8(b, offset)
			hitCharacterInstanceId, offset = BufferUtil.readu32(b, offset)
			hitInstanceId, offset = BufferUtil.readu32(b, offset)

			if ownerType == OWNER_TYPES.Player then
				local hitCharacter = GlobalInstanceService.getInstance(hitCharacterInstanceId) :: GameTypes.R15Character?
				if not hitCharacter or hitCharacter == character then
					return
				end

				local hitPlayer = Players:GetPlayerFromCharacter(hitCharacter)
				if not hitPlayer then
					return
				end

				local hitHumanoid = hitCharacter:FindFirstChildOfClass("Humanoid")
				local hitPart = GlobalInstanceService.getInstance(hitInstanceId)
				if not (hitHumanoid and hitPart) then
					return -- RETURN: No humanoid or limb available
				end

				if hitHumanoid.Health <= 0 then
					return -- RETURN: Already dead
				end

				hitHumanoid:TakeDamage(getDamageValue(gunModule, hitPart))
				globalRemoteEvent:FireClient( -- Replicate damage to victim
					hitPlayer,
					BufferUtil.construct({
						{ Type = "U8", Value = EVENT_CODES.Damage },
						{ Type = "VECTOR3_96", Value = character.PrimaryPart.Position },
					}, 13)
				)

				if hitHumanoid.Health <= 0 then -- Replicate kill to the killer
					globalRemoteEvent:FireClient(
						player,
						BufferUtil.construct({
							{ Type = "U8", Value = EVENT_CODES.NotifyKill },
							{ Type = "U32", Value = hitCharacterInstanceId },
							{ Type = "U8", Value = OWNER_TYPES.Player },
						}, 6)
					)
				end
			elseif ownerType == OWNER_TYPES.NPC then
				local hitCharacter = GlobalInstanceService.getInstance(hitCharacterInstanceId) :: GameTypes.R15Character?
				if not hitCharacter then
					return
				end

				local hitHumanoid = hitCharacter:FindFirstChildOfClass("Humanoid")
				local hitPart = GlobalInstanceService.getInstance(hitInstanceId)
				if not (hitHumanoid and hitPart) then
					return -- RETURN: No humanoid or limb available
				end

				if hitHumanoid.Health <= 0 then
					return -- RETURN: Already dead
				end

				hitHumanoid:TakeDamage(getDamageValue(gunModule, hitPart))
				if hitHumanoid.Health <= 0 then -- Replicate kill to the killer
					globalRemoteEvent:FireClient(
						player,
						BufferUtil.construct({
							{ Type = "U8", Value = EVENT_CODES.NotifyKill },
							{ Type = "U32", Value = hitCharacterInstanceId },
							{ Type = "U8", Value = OWNER_TYPES.NPC },
						}, 6)
					)
				end
			end
		end,

		[EVENT_CODES.Reload] = function(otherPlayer: Player, b: buffer)
			if banIfDifferent(player, otherPlayer) then
				return
			end

			local serverRCValue, clientRCValue = getRollingCode(), BufferUtil.readf64(b, 0)
			if banIfRCMismatch(clientRCValue, serverRCValue) then
				return
			end

			if gunAction == GUN_ACTIONS.Single then
				currentAmmo = gunModule.MagazineSize
			elseif gunAction == GUN_ACTIONS.Pump or gunAction == GUN_ACTIONS.Bolt then
				currentAmmo = math.min(currentAmmo + 1, gunModule.MagazineSize)
			end
		end,
	}, SimpleRemotesUtil.DecodeActionBuffer)
end

local function onPlayerAdded(player: Player)
	loadedToolsByPlayer[player] = {}

	InstanceUtil.connectChildAdded(player, function(child)
		if child ~= player.Backpack then
			return
		end

		InstanceUtil.connectChildAdded(child, function(tool)
			if not WeaponsUtil.isToolAGun(tool) then
				return
			end

			if loadedToolsByPlayer[player][tool] then
				return
			end

			loadGunTool(player, tool)
		end)
	end)
end

local function onPlayerRemoving(player: Player)
	loadedToolsByPlayer[player] = nil
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function GunService.init()
	PlayersUtil.onPlayerAdded(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

function GunService.start() end

function GunService.test() end

return GunService
