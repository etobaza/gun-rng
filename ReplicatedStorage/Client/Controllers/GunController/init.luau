--[[
  GunController

  Description:
  Handles client sided weapons

  Author:
  @SixthAtom

  Date:
  18-03-2026
]]

const GunController = {}

const ContentProvider = game:GetService("ContentProvider")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const SoundService = game:GetService("SoundService")
const UserInputService = game:GetService("UserInputService")

const GlobalInstanceController = require(ReplicatedStorage.Client.Controllers.GlobalInstanceController)
const BulletTrackingController = require(ReplicatedStorage.Client.Controllers.GunController.BulletTrackingController)
const MovementController = require(ReplicatedStorage.Client.Controllers.MovementController)
const InputController = require(ReplicatedStorage.Client.Core.InputController)
const SettingsController = require(ReplicatedStorage.Client.Core.SettingsController)
const UIUtil = require(ReplicatedStorage.Client.UI.UIUtil)
const ConnectionsList = require(ReplicatedStorage.Shared.Classes.ConnectionsList)
const IKSolver = require(ReplicatedStorage.Shared.Classes.IKSolver)
const ObjectPool = require(ReplicatedStorage.Shared.Classes.ObjectPool)
const Scheduler = require(ReplicatedStorage.Shared.Classes.Scheduler)
const Signal = require(ReplicatedStorage.Shared.Classes.Signal)
const SoundSequence = require(ReplicatedStorage.Shared.Classes.SoundSequence)
const Spring = require(ReplicatedStorage.Shared.Classes.Spring)
const BulletTrackingConstants = require(ReplicatedStorage.Shared.Constants.BulletTrackingConstants)
const CollisionConstants = require(ReplicatedStorage.Shared.Constants.CollisionConstants)
const EquipmentConstants = require(ReplicatedStorage.Shared.Constants.EquipmentConstants)
const InputConstants = require(ReplicatedStorage.Shared.Constants.InputConstants)
const SettingConstants = require(ReplicatedStorage.Shared.Constants.SettingConstants)
const WeaponConstants = require(ReplicatedStorage.Shared.Constants.WeaponConstants)
const GameTypes = require(ReplicatedStorage.Shared.GameTypes)
const RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
const SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
const SimpleRemotesUtil = require(ReplicatedStorage.Shared.Networking.SimpleRemotesUtil)
const BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)
const DeviceUtil = require(ReplicatedStorage.Shared.Utils.DeviceUtil)
const GeneralUtil = require(ReplicatedStorage.Shared.Utils.GeneralUtil)
const InstanceUtil = require(ReplicatedStorage.Shared.Utils.InstanceUtil)
const PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
const WeaponsUtil = require(ReplicatedStorage.Shared.Utils.WeaponsUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

const DEBUG = GeneralUtil.canDebug(true)
const DEBUG_INPUT_ACTIONS = InputConstants.DebugActions
const INPUT_ACTIONS = InputConstants.Actions

const FUNCTION_CODES = RemoteCodes.Guns.Functions
const EVENT_CODES = RemoteCodes.Guns.Events

const IDENTITY_CF = CFrame.identity
const HPI = math.pi / 2

const SETTINGS = SettingConstants.Settings
const SLOTS = EquipmentConstants.Slots
const WEAPON_MODULES = ReplicatedStorage.Shared.Weapons
const COLLISION_GROUPS = CollisionConstants.Groups
const OWNER_TYPES = BulletTrackingConstants.OwnerTypes
const GUN_ACTIONS = WeaponConstants.GunActions

const ADDED_AIM_FOV = -20
const MAGAZINE_SAMPLE_OFFSET = (1/60)*5
const AIM_SENSITIVITY_MULTIPLIER = 0.4

const CARRY_HANDLE_LANDING_IMPULSE = Vector3.new(0, 0, 8)
const SCOPE_ZERO_OFFSET = Vector3.new(0, 0, -100)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type GunModule = GameTypes.GunModule

type Firemode = "Semi" | "Auto" | "Bolt"
type GunTool = Tool & GameTypes.GunModel

type WeaponAssetConfig = {
	Animations: { [string]: string | number },
	SoundSequences: { [string]: SoundSequence.SoundSequence },
}

type InputContext = {
	Tool: Tool,
	SetShootingButtonDown: (value: boolean) -> (),
	SetAiming: (ads: boolean) -> (),
	IsAiming: () -> boolean,
	DoReload: () -> (),
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local assets = ReplicatedStorage.Assets
local soundGroupSFX = SoundService.Master.SFX
local hitSoundsFolder = soundGroupSFX.HitSounds

local globalRemoteEvent = SimpleRemotes.getEvent("Guns")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

local gunUI = player.PlayerGui.GunUI
local gunUIVignette = gunUI.Vignette
local gunUICrosshair = gunUI.Crosshair
local gunUICrosshairs: { { Frame: Frame, BasePosition: UDim2, AnchorDirection: Vector2 } } = {}
local gunUIAmmoLabel = gunUI.AmmoCounter.AmmoLabel

local loadedTools: { [Tool]: true } = {}
const localMagazinesVelocityCache = {}

local rng = Random.new()
local scheduler = Scheduler.new()

local casingsFolder = Instance.new("Folder", workspace.Terrain)
local casingPools = {}

local muzzleFlashPool = ObjectPool.new(assets.GunVisuals.MuzzleFlash, 100, "MuzzleFlashes")
local muzzleSmokePool = ObjectPool.new(assets.GunVisuals.MuzzleSmoke, 100, "MuzzleSmokes")

local coreSprings = {
	Fov = Spring.new(0, 1, 18, 0.9),
	CameraRotation = Spring.new(Vector3.zero, 1, 19, 0.9),
   CarryHandle = Spring.new(Vector3.zero, 1, 15, 0.25)
}

local aiming = false
local inFPV = false
local sensitivity = 1

local collisionDebugPart: BasePart
local fakeFPVArms: typeof(assets.GunVisuals.FPVArms)

local inputContext: InputContext? = nil

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

GunController.GunEquipped = Signal.new() :: Signal.Signal<string, GunModule>
GunController.GunUnequipped = Signal.new() :: Signal.Signal<string, GunModule>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local preloadWeaponAssets = function()
	const dud = Instance.new("Model")
	dud.Name = "WeaponAssetPreloadDud"

	const animationController = Instance.new("AnimationController")
	animationController.Parent = dud

	const animator = Instance.new("Animator")
	animator.Parent = animationController

	const sounds = Instance.new("Folder")
	sounds.Name = "Sounds"
	sounds.Parent = dud

	dud.Parent = workspace

	const assetsToPreload: { Instance } = {}
	const assetSources: { [string]: { string } } = {}
	const animationIds: { [string]: true } = {}
	const soundIds: { [string]: true } = {}

	for _, weaponModule in next, WEAPON_MODULES:GetChildren() do
		if not weaponModule:IsA("ModuleScript") then
			continue
		end

		const gunModule = (require(weaponModule) :: () -> WeaponAssetConfig)()

		for animationName, animationId in next, gunModule.Animations do
			const contentId = `rbxassetid://{animationId}`
			const sources = assetSources[contentId]
			if sources then
				table.insert(sources, `{weaponModule.Name}.Animations.{animationName}`)
				continue
			end

			const animation = Instance.new("Animation")
			animation.Name = `{weaponModule.Name}_{animationName}`
			animation.AnimationId = contentId
			animation.Parent = animator

			animationIds[contentId] = true
			assetSources[contentId] = { `{weaponModule.Name}.Animations.{animationName}` }
			table.insert(assetsToPreload, animation)
		end

		for sequenceName, sequence in next, gunModule.SoundSequences do
			for keyframeIndex, keyframe in next, sequence._keyframes do
				const contentId = `rbxassetid://{keyframe.Id}`
				const source = `{weaponModule.Name}.SoundSequences.{sequenceName}[{keyframeIndex}]`
				const sources = assetSources[contentId]
				if sources then
					table.insert(sources, source)
					continue
				end

				const sound = Instance.new("Sound")
				sound.Name = `{weaponModule.Name}_{sequenceName}_{keyframeIndex}`
				sound.SoundId = contentId
				sound.Parent = sounds

				soundIds[contentId] = true
				assetSources[contentId] = { source }
				table.insert(assetsToPreload, sound)
			end
		end
	end

	for _, asset in next, assetsToPreload do
		if asset:IsA("Animation") then
			const success, loadError = pcall(animator.LoadAnimation, animator, asset)
			if not success then
				warn(`Failed to load weapon animation {asset.AnimationId}: {loadError}`)
			end
		end
	end

	const onAssetPreloaded = function(contentId: string, status: Enum.AssetFetchStatus)
		if status == Enum.AssetFetchStatus.Success then
			return
		end

		const assetType = if animationIds[contentId] then "animation" elseif soundIds[contentId] then "sound" else "asset"
		warn(`Failed to preload weapon {assetType} {contentId} ({status.Name}): {table.concat(assetSources[contentId] or {}, ", ")}`)
	end

	const success, preloadError = pcall(ContentProvider.PreloadAsync, ContentProvider, assetsToPreload, onAssetPreloaded)
	dud:Destroy()

	if not success then
		warn(`Failed to preload weapon assets: {preloadError}`)
	end
end

@native
local function getFovAlpha(fovOffset: number)
	return math.clamp(fovOffset / ADDED_AIM_FOV, 0, 1)
end

local function playShootVFX(node: BasePart)
	if rng:NextNumber() >= 0.2 then
		local muzzleFlash = muzzleFlashPool:Draw(node)

		local scale = rng:NextNumber(0.25, 0.5)
		muzzleFlash.Size = NumberSequence.new(scale)
		muzzleFlash:Emit(1)

		scheduler:Add(0.1, muzzleFlashPool.Return, muzzleFlashPool, muzzleFlash)
	end

	local muzzleSmoke = muzzleSmokePool:Draw(node)
	muzzleSmoke:Emit(rng:NextInteger(6, 11))
	scheduler:Add(2, muzzleSmokePool.Return, muzzleSmokePool, muzzleSmoke)
end


local function dropCasing(node: BasePart, caliber: number, replicated: true?)
	if replicated then
		if not SettingsController.getValue(SETTINGS.RenderReplicatedCasings) then
			return
		end
	end

	local caliberName = WeaponConstants.CaliberNames[caliber]
	local pool = if caliberName then casingPools[caliberName] else nil
	if pool then
      const character = node:FindFirstAncestorOfClass("Model")
      if not character then return end

      const characterRoot = character.PrimaryPart
      if not characterRoot then return end

		local casing = pool:Draw(casingsFolder, function(v)
			v.CFrame = node.CFrame * CFrame.Angles(0, HPI, 0)
		end)

		casing.CollisionGroup = COLLISION_GROUPS.Debris
		casing.AssemblyLinearVelocity = (characterRoot.AssemblyLinearVelocity + node.CFrame.LookVector * rng:NextNumber(22, 32)) 
		casing.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-30, 30), rng:NextNumber(-50, 50), rng:NextNumber(-30, 30))

		scheduler:Add(5, pool.Return, pool, casing)
	end
end

local function initializeGunTool(tool: GunTool)
	loadedTools[tool] = true
	tool.ManualActivationOnly = true

	local gunModule = require(WEAPON_MODULES[tool.Name])() :: GunModule & GameTypes.PumpGunModule & GameTypes.SniperGunModule
	local character = player.Character :: GameTypes.R15Character
	local characterRoot = character.HumanoidRootPart
	local characterHead = character.Head
	local equippedConnections = ConnectionsList.new()

	-- RC & Remote Creation
	local remoteFunction = SimpleRemotes.getFunction("RemoteFunction", tool)
	local remoteEvent = SimpleRemotes.getEvent("RemoteEvent", tool)

	local rcStartValue, rcIncrementValue, rcFinishValue, rcCurrentValue = remoteFunction:InvokeServer(BufferUtil.construct({
		{ Type = "U8", Value = FUNCTION_CODES.GetRC },
	}))

	--- This buffer contains the rolling code
	local rollingCodeBuffer = buffer.create(20)
	buffer.writestring(rollingCodeBuffer, 8, "🚽🧻💩")

	-- Localize variables
	local rpm = 60 / gunModule.Firerate
	local firemode: Firemode = gunModule.Firemode
	local currentAmmo = gunModule.MagazineSize
	local springs = gunModule.Springs
	local offsets = gunModule.Offsets
	local soundSequences = gunModule.SoundSequences
	local spread = gunModule.PelletSpread
	local gunAction = gunModule.Action
	local timestamps = gunModule.Timestamps

	local crosshairIgnoreList: { Instance } = { tool, character, fakeFPVArms }
	local crosshairRCParams = RaycastParams.new()

	local validationIgnoreList: { Instance } = { tool, character, fakeFPVArms }
	local validationRCParams = RaycastParams.new()
	validationRCParams.ExcludeInstances = validationIgnoreList
	validationRCParams.RespectCanCollide = true

	local loadsRounds = gunAction == GUN_ACTIONS.Pump or gunAction == GUN_ACTIONS.Bolts
   local scopeBillboard: typeof(ReplicatedStorage.Assets.ScopeBillboard)? = nil

	-- Localize tool instances
	local animationController = tool.AnimationController
	local animator = animationController.Animator

	local animationTracks = GeneralUtil.loadAnimationsList(animator, gunModule.Animations)

   -- Configure animation tracks via script
   for i, v in next, animationTracks do
      if string.match(i, "Reload") then
         v.Priority = Enum.AnimationPriority.Action3
         v.Looped = false
      end
   end

   animationTracks.Shoot.Priority = Enum.AnimationPriority.Action4
   animationTracks.Shoot.Looped = false

   animationTracks.Idle.Priority = Enum.AnimationPriority.Action
   animationTracks.Idle.Looped = true

   if animationTracks.Empty then
      animationTracks.Empty.Priority = Enum.AnimationPriority.Action2
      animationTracks.Empty.Looped = true
   end

   -- Miscallenious
	local gunRoot = tool.GunRoot
	gunRoot.Anchored = true

   local gunBody = tool.Body

	local leftArm, leftArmM6D = tool["Left Arm"], gunBody["Left Arm"]
	local rightArm, rightArmM6D = tool["Right Arm"], gunBody["Right Arm"]

	local carryHandleM6D = gunBody:FindFirstChild("Handle") :: Motor6D?
	local carryHandleAddedCFrame = IDENTITY_CF

	local fakeLeftArm = fakeFPVArms["Left Arm"]
	local fakeRightArm = fakeFPVArms["Right Arm"]

	fakeLeftArm.Size = leftArm.Size
	fakeRightArm.Size = rightArm.Size

	local nodes = tool.Nodes
	local aimNode, ejectNode, exitNode = nodes.Aim, nodes.Eject, nodes.Exit

	local aimToRootOffset = gunRoot.CFrame:ToObjectSpace(aimNode.CFrame):Inverse()

   if gunModule.ScopeImage then
      scopeBillboard = ReplicatedStorage.Assets.ScopeBillboard:Clone()
      scopeBillboard.StudsOffsetWorldSpace = SCOPE_ZERO_OFFSET
      scopeBillboard.Enabled = false
      scopeBillboard.Parent = exitNode
   end

	-- Localize character instances
	local rootM6D = gunRoot:WaitForChild("RootMotor") :: Motor6D
	local humanoid = character.Humanoid
	local waistM6D = character.UpperTorso.Waist

	local rightSolver: IKSolver.IkSolver, leftSolver: IKSolver.IkSolver

	rootM6D.Enabled = false

	-- State variables
	local shootingButtonDown = false
	local reloadThread: thread? = nil
	local activeReloadSoundSequence: SoundSequence.PlaybackSession? = nil
	local equipped = false

	local nextShootAt = 0

	-- Local/helper functions
	local updateRollingCodeBuffer = function()
		BufferUtil.writef64(rollingCodeBuffer, 0, rcCurrentValue)

		rcCurrentValue += rcIncrementValue
		if rcCurrentValue > rcFinishValue then
			rcCurrentValue = rcStartValue
		end

		return rollingCodeBuffer
	end

	local updateAmmoUI = function()
		if inputContext and inputContext.Tool == tool then
			gunUIAmmoLabel.Text = `{(reloadThread ~= nil and not loadsRounds) and `-` or currentAmmo}/{gunModule.MagazineSize}`
		end
	end

	local getValidatedCrosshairCastPosition = function(origin: Vector3, direction: Vector3)
		local result = GeneralUtil.customCast(origin, direction, crosshairRCParams)
		if not result.Instance then
			return result.Position
		end

		local validImpact, ignoredInstance = BulletTrackingController.validateImpact(result)
		if not validImpact then
			table.insert(crosshairIgnoreList, ignoredInstance or result.Instance)
			crosshairRCParams.ExcludeInstances = crosshairIgnoreList
			return origin + direction
		end

		return result.Position
	end

	local onBulletImpact = function(result: RaycastResult, _trackedBullet: BulletTrackingController.TrackedBullet)
		local resultInstance, resultPosition = result.Instance, result.Position
		local headshot = resultInstance.Name == "Head"

		--[[
         Helper method for locating and creating impact sounds
      ]]
		local playImpactSound = function(isFleshHit: boolean)
			local soundFolder
			if isFleshHit then
				soundFolder = hitSoundsFolder:FindFirstChild("Flesh")
			end

			soundFolder = soundFolder or hitSoundsFolder:FindFirstChild(result.Material.Name) or hitSoundsFolder.Default

			local hitSounds = soundFolder:GetChildren()
			if #hitSounds == 0 then
				return
			end

			local soundAttachment = Instance.new("Attachment")
			soundAttachment.Name = "SoundAttachment"
			soundAttachment.WorldCFrame = CFrame.new(result.Position)
			soundAttachment.Parent = workspace.Terrain

			local hitSound = hitSounds[math.random(#hitSounds)]:Clone() :: Sound
			hitSound.SoundGroup = soundGroupSFX
			hitSound.PlayOnRemove = true
			hitSound.Parent = soundAttachment
			hitSound:Destroy()

			scheduler:Add(hitSound.TimeLength + 4, function()
				soundAttachment:Destroy()
			end)
		end

		--[[
         Actual hit logic begins here
      ]]

		local hitPlayer = Players:GetPlayerFromCharacter(resultInstance.Parent)
		if hitPlayer and hitPlayer ~= player then -- A player has been hit
			if not PlayersUtil.isAlive(hitPlayer) then
				return
			end

			local hitInstanceId = GlobalInstanceController.getId(resultInstance)
			local characterInstanceId = GlobalInstanceController.getId(hitPlayer.Character)
			if not (hitInstanceId and characterInstanceId) then
				return
			end

			warn(`Player Hit:`, characterInstanceId, hitPlayer, hitPlayer.Character)
			WeaponsUtil.createHitmarker(resultPosition, headshot and Color3.new(1, 0, 0) or Color3.new(1, 1, 1))
			playImpactSound(true)
			updateRollingCodeBuffer()

			local damageBuffer, offset = buffer.create(1 + buffer.len(rollingCodeBuffer) + 1 + 4 + 4), 0
			offset = BufferUtil.writeu8(damageBuffer, offset, EVENT_CODES.Damage)
			offset = BufferUtil.inject(rollingCodeBuffer, damageBuffer, offset)
			offset = BufferUtil.writeu8(damageBuffer, offset, OWNER_TYPES.Player)
			offset = BufferUtil.writeu32(damageBuffer, offset, characterInstanceId)
			offset = BufferUtil.writeu32(damageBuffer, offset, hitInstanceId)

			remoteEvent:FireServer(damageBuffer)
			return
		end

		local hitHumanoid = resultInstance.Parent:FindFirstChildOfClass("Humanoid")
		if hitHumanoid then -- An NPC has been hit
			if hitHumanoid.Health <= 0 then
				return
			end

			local hitInstanceId = GlobalInstanceController.getId(resultInstance)
			local characterInstanceId = GlobalInstanceController.getId(hitHumanoid.Parent)
			if not (hitInstanceId and characterInstanceId) then
				return
			end

			WeaponsUtil.createHitmarker(resultPosition, headshot and Color3.new(1, 0, 0) or Color3.new(1, 1, 1))
			playImpactSound(true)
			updateRollingCodeBuffer()

			local damageBuffer, offset = buffer.create(1 + buffer.len(rollingCodeBuffer) + 1 + 4 + 4), 0
			offset = BufferUtil.writeu8(damageBuffer, offset, EVENT_CODES.Damage)
			offset = BufferUtil.inject(rollingCodeBuffer, damageBuffer, offset)
			offset = BufferUtil.writeu8(damageBuffer, offset, OWNER_TYPES.NPC)
			offset = BufferUtil.writeu32(damageBuffer, offset, characterInstanceId)
			offset = BufferUtil.writeu32(damageBuffer, offset, hitInstanceId)

			remoteEvent:FireServer(damageBuffer)
			return
		end

		playImpactSound(false)
	end

	local cancelReload = function()
		if reloadThread then
			task.cancel(reloadThread)
			reloadThread = nil

			if activeReloadSoundSequence then
				activeReloadSoundSequence:Stop()
				activeReloadSoundSequence = nil
			end

			local magazine = tool:FindFirstChild("Magazine") :: BasePart?
			if magazine then
				magazine.Transparency = 0
			end

			if loadsRounds then
				if animationTracks.ReloadStart then animationTracks.ReloadStart:Stop() end
				if animationTracks.ReloadRound then animationTracks.ReloadRound:Stop() end
				if animationTracks.ReloadFinish then animationTracks.ReloadFinish:Stop() end
			else
				if animationTracks.Reload then animationTracks.Reload:Stop() end
				if animationTracks.EmptyReload then animationTracks.EmptyReload:Stop() end
			end

			updateAmmoUI()
		end
	end

	local reload = function()
		local roundsToReload = gunModule.MagazineSize - currentAmmo
		if reloadThread ~= nil or roundsToReload <= 0 then
			return
		end

		local fireReloadEvent = function()
			updateRollingCodeBuffer()

			local reloadBuffer, offset = buffer.create(1 + buffer.len(rollingCodeBuffer)), 0
			offset = BufferUtil.writeu8(reloadBuffer, offset, EVENT_CODES.Reload)
			offset = BufferUtil.inject(rollingCodeBuffer, reloadBuffer, offset)

			remoteEvent:FireServer(reloadBuffer)
		end

		if gunAction == GUN_ACTIONS.Single then
			reloadThread = task.spawn(function()
				local reloadAnimation = if currentAmmo == 0 then animationTracks.EmptyReload else animationTracks.Reload
				fireReloadEvent() -- Notify server

				task.defer(updateAmmoUI)

				reloadAnimation:Play()
				if animationTracks.Empty then
					animationTracks.Empty:Stop()
				end

				if currentAmmo == 0 then
					activeReloadSoundSequence = soundSequences.EmptyReload:Play(gunRoot)
				else
					activeReloadSoundSequence = soundSequences.Reload:Play(gunRoot)
				end

				const magazine = tool:FindFirstChild("Magazine") :: BasePart?
				if magazine then
					local weaponName = tool.Name
					local cachedLocalVelocity = localMagazinesVelocityCache[weaponName]
					local lastLocalPos: Vector3? = nil
					local lastTime: number? = nil

					if not cachedLocalVelocity and gunRoot then
						const sampleTime = math.max(0.01, timestamps.MagOut - MAGAZINE_SAMPLE_OFFSET)
						task.wait(sampleTime)
						if magazine and gunRoot then
							lastLocalPos = gunRoot.CFrame:PointToObjectSpace(magazine.Position)
							lastTime = os.clock()
						end
						const remaining = timestamps.MagOut - sampleTime
						if remaining > 0 then task.wait(remaining) end
					else
						task.wait(timestamps.MagOut)
					end

					local throwVelocity = Vector3.zero
					if cachedLocalVelocity then
						if gunRoot then throwVelocity = gunRoot.CFrame:VectorToWorldSpace(cachedLocalVelocity) end
					elseif lastLocalPos and lastTime and magazine and gunRoot then
						const currentLocalPos = gunRoot.CFrame:PointToObjectSpace(magazine.Position)
						const dt = os.clock() - lastTime
						if dt > 0 then
							const localVelocity = (currentLocalPos - lastLocalPos) / dt
							localMagazinesVelocityCache[weaponName] = localVelocity
							throwVelocity = gunRoot.CFrame:VectorToWorldSpace(localVelocity)
						end
					end

					const clone = Instance.fromExisting(magazine)
					clone.CollisionGroup = COLLISION_GROUPS.Debris
					magazine.Transparency = 1
					clone.CFrame = magazine.CFrame
					clone.Anchored = false
					clone.CanTouch, clone.CanQuery, clone.CanCollide = false, false, true

					local characterVelocity = if characterRoot then characterRoot.AssemblyLinearVelocity else Vector3.zero
					clone.AssemblyLinearVelocity = throwVelocity + characterVelocity
					clone.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-6, 6), rng:NextNumber(-6, 6), rng:NextNumber(-6, 6))

					clone.Name = "MagazineClone"
					clone.Parent = workspace.Terrain
					scheduler:Add(10, function() if clone then clone:Destroy() end end)

					const remainingToMagIn = timestamps.MagIn - timestamps.MagOut
					if remainingToMagIn > 0 then task.wait(remainingToMagIn) end

					magazine.Transparency = 0

					const remainingToFinish = reloadAnimation.Length - timestamps.MagIn
					if remainingToFinish > 0 then task.wait(remainingToFinish) end
				else
					task.wait(reloadAnimation.Length)
				end

				currentAmmo = gunModule.MagazineSize
				reloadThread = nil
				updateAmmoUI()
			end)
		elseif loadsRounds then
			reloadThread = task.spawn(function()
				local startReloadAnimation = animationTracks.ReloadStart
				local reloadRoundAnimation = animationTracks.ReloadRound
				local finishReloadAnimation = animationTracks.ReloadFinish

				local startReloadSoundSequence = soundSequences.ReloadStart
				local reloadRoundSoundSequence = soundSequences.ReloadRound
				local finishReloadSoundSequence = soundSequences.ReloadFinish

				task.defer(updateAmmoUI)

				if animationTracks.Empty then
					animationTracks.Empty:Stop()
				end

				startReloadAnimation:Play()
				activeReloadSoundSequence = startReloadSoundSequence:Play(gunRoot)

				task.wait(startReloadAnimation.Length)

				for roundIndex = 1, roundsToReload do
					local isFinalRound = roundIndex == roundsToReload
					local roundSoundSequence = if isFinalRound then finishReloadSoundSequence else reloadRoundSoundSequence
					local roundAnimation = if isFinalRound then finishReloadAnimation else reloadRoundAnimation

					roundAnimation:Play()
					activeReloadSoundSequence = roundSoundSequence:Play(gunRoot)

					task.wait(roundAnimation.Length)

					fireReloadEvent()
					currentAmmo = math.min(gunModule.MagazineSize, currentAmmo + 1)
					updateAmmoUI()
				end

				reloadThread = nil
				updateAmmoUI()
			end)
		end
	end

	local shoot = function(now: number)
		if reloadThread ~= nil then
			if loadsRounds and currentAmmo > 0 then
				shootingButtonDown = false
				cancelReload()
			end
			return
		end

		animationTracks.Shoot:Play()
		currentAmmo = math.max(0, currentAmmo - 1)
		nextShootAt = now + rpm
		updateAmmoUI()

		--[[
         Calculate the spawn position of the bullet
         - From the character root -> head,
         - head -> exit node
         Stops when there's an early collision, and offsets a little back from the hit result.
      ]]

		local rootPosition = characterRoot.Position
		local headPosition = characterHead.Position
		local barrelPosition = exitNode.Position

		local rootToHead = headPosition - rootPosition
		local rootToHeadResult = GeneralUtil.customCast(rootPosition, rootToHead, validationRCParams, nil, DEBUG)

		local fromPosition
		if rootToHeadResult.Instance then
			fromPosition = rootToHeadResult.Position - rootToHead.Unit * 0.05
		else
			fromPosition = headPosition

			local headToBarrel = barrelPosition - headPosition
			local headToBarrelResult = GeneralUtil.customCast(headPosition, headToBarrel, validationRCParams, nil, DEBUG)

			if headToBarrelResult.Instance then
				fromPosition = headToBarrelResult.Position - headToBarrel.Unit * 0.05
			else
				fromPosition = exitNode.Position
			end
		end

		--[[
         Calculate the pellet velocities and log it on the buffer
         Track these pallets, and replicate to the server.
      ]]

		local exitNodeId = GlobalInstanceController.getId(exitNode)

		if type(exitNodeId) == "number" then
			updateRollingCodeBuffer()

			local shootBuffer, offset = buffer.create(1 + buffer.len(rollingCodeBuffer) + 4 + 1 + gunModule.Pellets * 12), 0
			offset = BufferUtil.writeu8(shootBuffer, offset, EVENT_CODES.Shoot)
			offset = BufferUtil.inject(rollingCodeBuffer, shootBuffer, offset)
			offset = BufferUtil.writeu32(shootBuffer, offset, exitNodeId)
			offset = BufferUtil.writeu8(shootBuffer, offset, gunModule.Pellets)

			local baseMuzzleVelocity = gunModule.MuzzleVelocity

         local lookVector = exitNode.CFrame.LookVector
         local rightVector = exitNode.CFrame.RightVector
         local upVector = exitNode.CFrame.UpVector

         for _ = 1, gunModule.Pellets do
				local theta = rng:NextNumber(0, math.pi * 2)
				local radius = math.sqrt(rng:NextNumber()) * spread

				local direction = (
					lookVector
					+ rightVector * math.cos(theta) * radius
					+ upVector * math.sin(theta) * radius
				).Unit

				local muzzleVelocity = if type(baseMuzzleVelocity) == "table" then rng:NextInteger(baseMuzzleVelocity[1], baseMuzzleVelocity[2]) else baseMuzzleVelocity

				local velocity = characterRoot.AssemblyLinearVelocity + direction * muzzleVelocity
				BulletTrackingController.track(
					exitNode,
					fromPosition,
					velocity,
					validationIgnoreList,
					gunModule.Caliber,
					onBulletImpact
				)
				offset = BufferUtil.writeVector3_96(shootBuffer, offset, velocity)
			end

			remoteEvent:FireServer(shootBuffer, validationIgnoreList)
		end

		--[[
         Update visuals & do finishing touches
      ]]

		const recoil = gunModule.CalculateRecoil(aiming)

		springs.RecoilOrientation:Impulse(Vector3.new(recoil.Pitch, recoil.Yaw, 0))
		springs.RecoilRoll:Impulse(recoil.Roll or 0)
		springs.RecoilPosition:Impulse(Vector3.new(0, 0, recoil.AxisZ))

      if inFPV then
         springs.FPVLeftArm:Impulse(recoil.LeftArm)
         springs.FPVRightArm:Impulse(recoil.RightArm)
      end

		if loadsRounds then
			scheduler:Add(timestamps.Cycle, dropCasing, ejectNode, gunModule.Caliber)
		else
			dropCasing(ejectNode, gunModule.Caliber)
		end

      soundSequences.Shoot:SetPitch(rng:NextNumber(0.9, 1.1))
      soundSequences.Shoot:Play(exitNode)

		playShootVFX(exitNode)

		coreSprings.Fov:Impulse(recoil.Fov or rng:NextNumber(25, 30))
		coreSprings.CameraRotation:Impulse(Vector3.zAxis * (recoil.CameraRoll or rng:NextNumber(0.5, 1.5)))

		if carryHandleM6D then
			coreSprings.CarryHandle:Impulse(Vector3.new(0, 0, recoil.AxisZ * rng:NextNumber(0.15, 0.25)))
		end

		if currentAmmo == 0 then
			scheduler:Add(animationTracks.Shoot.Length / 4, function()
				if animationTracks.Empty then
					animationTracks.Shoot:Stop()
					animationTracks.Empty:Play()
				end
			end)
		end

		if firemode == "Semi" then
			shootingButtonDown = false
		end
	end

	local aim = function(value: boolean)
		if value == true and MovementController.Sprinting then
			MovementController.setSprint(false)
		end

		aiming = value
	end

	local createInputContext = function()
		return {
			Tool = tool,

			SetShootingButtonDown = function(value: boolean)
				shootingButtonDown = value
			end,

			SetAiming = function(ads: boolean)
				if inFPV then
					aiming = ads
				end
			end,

			IsAiming = function()
				return aiming
			end,

			DoReload = reload,
		} :: InputContext
	end

	local unequip = function()
		equipped = false
		GunController.GunUnequipped:Fire(tool.Name, gunModule)

		cancelReload()

		-- Remove input context & disable input actions
		inputContext = nil
		InputController.disableInputs({ INPUT_ACTIONS.Shoot, INPUT_ACTIONS.Aim, INPUT_ACTIONS.Reload })

		UserInputService.MouseIconEnabled = true
		gunUICrosshair.Visible = false
		fakeFPVArms.Parent = nil
		gunUIAmmoLabel.Visible = false

		shootingButtonDown = false
		coreSprings.CarryHandle:Reset()

		for _, v in next, animationTracks do
			v:Stop()
		end

		if leftSolver and rightSolver then
			leftSolver:reset()
			rightSolver:reset()
		end

		equippedConnections:Clean()

		if aiming then
			aim(false)
		end

		inFPV = false
		player.CameraMode = Enum.CameraMode.Classic
	end

	local equip = function()
		equipped = true
		GunController.GunEquipped:Fire(tool.Name, gunModule)

		if DeviceUtil.isMobile() then
			player.CameraMode = Enum.CameraMode.LockFirstPerson
		end

		-- Create input context & enable input actions
		inputContext = createInputContext()
		InputController.enableInputs({ INPUT_ACTIONS.Shoot, INPUT_ACTIONS.Aim, INPUT_ACTIONS.Reload })

		local rightShoulder = character:WaitForChild("RightUpperArm"):WaitForChild("RightShoulder")
		local rightElbow = character:WaitForChild("RightLowerArm"):WaitForChild("RightElbow")
		local rightWrist = character:WaitForChild("RightHand"):WaitForChild("RightWrist")

		local leftShoulder = character:WaitForChild("LeftUpperArm"):WaitForChild("LeftShoulder")
		local leftElbow = character:WaitForChild("LeftLowerArm"):WaitForChild("LeftElbow")
		local leftWrist = character:WaitForChild("LeftHand"):WaitForChild("LeftWrist")

		if not leftSolver then
			task.delay(0.5, function()
				rightSolver = IKSolver.new(rightShoulder, rightElbow, rightWrist)
				leftSolver = IKSolver.new(leftShoulder, leftElbow, leftWrist)
			end)
		end

		animationTracks.Idle:Play()
		fakeFPVArms.Parent = camera
		UserInputService.MouseIconEnabled = false
		gunUICrosshair.Visible = true

		updateAmmoUI()
		gunUIAmmoLabel.Visible = true

		if currentAmmo == 0 then
			animationTracks.Empty:Play()
		end

      local leftArmAddedCFrame, rightArmAddedCFrame = CFrame.identity, CFrame.identity

      -- Visual loop
		-- equippedConnections:Add(RunService.PreRender:Connect(function(dT)
      equippedConnections:Add(GeneralUtil.bindToRenderStep("GunUpdate", Enum.RenderPriority.Camera.Value+9, function(dT)
         local now = os.clock()

			local head = character:FindFirstChild("Head")
			local lowerTorso = character:FindFirstChild("LowerTorso")
			if not head or not lowerTorso then
				return
			end

			local characterSpeed = characterRoot.AssemblyLinearVelocity.Magnitude
			local sprinting = humanoid.MoveDirection.Magnitude > 0 and MovementController.Sprinting

			-- CFrame & render the gun
			inFPV = head.LocalTransparencyModifier == 1
			gunRoot.AssemblyLinearVelocity = Vector3.zero

			local recoilPosition = springs.RecoilPosition:Update(dT, Vector3.zero)
			local recoilOrientation = springs.RecoilOrientation:Update(dT, Vector3.zero)
			local recoilRoll = springs.RecoilRoll:Update(dT, 0)

			local mouseDelta = UserInputService:GetMouseDelta() * sensitivity

			local targetCFrame = IDENTITY_CF
			if inFPV then
				local fpvOffset = if aiming then aimToRootOffset * offsets.FirstPersonAiming else offsets.FirstPerson

				fpvOffset *= gunModule.CalculateSway(
					characterRoot.CFrame:VectorToObjectSpace(humanoid.MoveDirection),
					mouseDelta,
					characterSpeed,
					aiming,
					sprinting
				)

				local offsetPosition = springs.FPVPosition:Update(dT, fpvOffset.Position)
				local offsetOrientation = springs.FPVOrientation:Update(dT, Vector3.new(unpack({ fpvOffset:ToOrientation() })))

				fpvOffset = CFrame.Angles(offsetOrientation.X, offsetOrientation.Y, offsetOrientation.Z) + offsetPosition
				targetCFrame = camera.CFrame * fpvOffset

            -- Dynamic arm movement
            leftArmM6D.C1 *= leftArmAddedCFrame:Inverse()
            rightArmM6D.C1 *= rightArmAddedCFrame:Inverse()

            const leftArmOrientation = springs.FPVLeftArm:Update(dT, Vector3.zero)
            const rightArmOrientation = springs.FPVRightArm:Update(dT, Vector3.zero)

            leftArmAddedCFrame = CFrame.Angles(leftArmOrientation.X, leftArmOrientation.Y, leftArmOrientation.Z)
            rightArmAddedCFrame = CFrame.Angles(rightArmOrientation.X, rightArmOrientation.Y, rightArmOrientation.Z)

            leftArmM6D.C1 *= leftArmAddedCFrame
            rightArmM6D.C1 *= rightArmAddedCFrame
			else
				targetCFrame = CFrame.lookAt(
					(lowerTorso.CFrame * CFrame.Angles(waistM6D.C0:ToOrientation(), 0, 0)):PointToWorldSpace(offsets.ThirdPerson.Position),
					getValidatedCrosshairCastPosition(mouse.UnitRay.Origin, mouse.UnitRay.Direction * 400)
				)
			end

			--[[if carryHandleM6D then
				carryHandleM6D.C1 *= carryHandleAddedCFrame:Inverse()

				if mouseDelta.Magnitude > 0 then
					-- coreSprings.CarryHandle:Impulse(Vector3.new(-mouseDelta.Y * 0.015, -mouseDelta.X * 0.02, mouseDelta.X * 0.015))
				end

				const carryHandleAngles = coreSprings.CarryHandle:Update(dT, Vector3.zero)
				carryHandleAddedCFrame = CFrame.Angles(carryHandleAngles.X, carryHandleAngles.Y, carryHandleAngles.Z)

				carryHandleM6D.C1 *= carryHandleAddedCFrame
			end]]

			targetCFrame *= workspace.World.CFrameEditor.Value
			targetCFrame *= CFrame.fromOrientation(recoilOrientation.X, recoilOrientation.Y, recoilOrientation.Z + recoilRoll) + recoilPosition
			gunRoot.CFrame = targetCFrame

			if fakeFPVArms then
				fakeLeftArm.Transparency = if inFPV then 0 elseif DEBUG then 0.5 else 1
				fakeRightArm.Transparency = fakeLeftArm.Transparency

				fakeLeftArm.CFrame = leftArm.CFrame * CFrame.Angles(math.pi, 0, 0)
				fakeRightArm.CFrame = rightArm.CFrame * CFrame.Angles(math.pi, 0, 0)
			end

			-- Handle crosshairs
			local aimAlpha = math.map(math.clamp(coreSprings.Fov:GetPosition() / ADDED_AIM_FOV, 0, 0.8), 0, 0.8, 0, 1)
			local crosshairValue = recoilOrientation.Magnitude + gunModule.PelletSpread
			local offsetLength = crosshairValue * (1 - aimAlpha)

			local crosshairLocation = UserInputService:GetMouseLocation()
			if inFPV then
				local barrelTarget = getValidatedCrosshairCastPosition(exitNode.Position, exitNode.CFrame.LookVector * 400)
				local viewportPoint = camera:WorldToViewportPoint(barrelTarget)
				crosshairLocation = Vector2.new(viewportPoint.X, viewportPoint.Y)
			end

			gunUICrosshair.Position = UDim2.fromOffset(crosshairLocation.X, crosshairLocation.Y)
			gunUICrosshair.Rotation = -math.deg(select(3, exitNode.CFrame:ToOrientation()))

			for _, v in next, gunUICrosshairs do
				local frame = v.Frame
				local basePosition = v.BasePosition
				local anchorDirection = v.AnchorDirection

				local normalPosition = basePosition + UDim2.fromScale(anchorDirection.X * offsetLength, anchorDirection.Y * offsetLength)
				frame.Position = normalPosition:Lerp(UDim2.fromScale(0.5, 0.5), aimAlpha)

				frame.Transparency = aimAlpha
				frame.UIStroke.Transparency = aimAlpha
			end

			-- Handle shooting (& reloading)
			if shootingButtonDown then
				if now >= nextShootAt then
					if currentAmmo > 0 then
						shoot(now)
					else
						reload()
					end
				end
			end

			-- Automatic unaiming
			if aiming and (not inFPV or sprinting) then
				aim(false)
			end
      end))

		equippedConnections:Add(RunService.PreSimulation:Connect(function()
			if not (leftSolver and rightSolver and rightShoulder and leftShoulder) then
				return
			end

			rightShoulder.Transform, rightElbow.Transform, rightWrist.Transform = IDENTITY_CF, IDENTITY_CF, IDENTITY_CF
			leftShoulder.Transform, leftElbow.Transform, leftWrist.Transform = IDENTITY_CF, IDENTITY_CF, IDENTITY_CF
			waistM6D.Transform = IDENTITY_CF

			local leftSolverTarget = leftArm.CFrame * offsets.LeftArmSolver
			local rightSolverTarget = rightArm.CFrame * offsets.RightArmSolver

			leftSolver:solve(leftSolverTarget)
			rightSolver:solve(rightSolverTarget)
		end))
	end

	-- Connections
	tool.Unequipped:Connect(unequip)
	tool.Equipped:Connect(equip)

	humanoid.StateChanged:Connect(function(_, newState)
		if not equipped then
			return
		end

		if newState == Enum.HumanoidStateType.Jumping then
			if inFPV then
				springs.FPVPosition.Velocity += Vector3.new(0, -4.5, 1.9)
			end

			if carryHandleM6D then
				coreSprings.CarryHandle:Impulse(-CARRY_HANDLE_LANDING_IMPULSE)
			end
		elseif newState == Enum.HumanoidStateType.Landed then
			if inFPV then
				springs.FPVPosition.Velocity += Vector3.new(0, 4.75, 1.6)
			end

			if carryHandleM6D then
				coreSprings.CarryHandle:Impulse(CARRY_HANDLE_LANDING_IMPULSE)
			end
		end
	end)
end

local function onBackpackChildAdded(tool: Tool)
	if not (tool:IsA("Tool") and tool:GetAttribute("Slot") == SLOTS.Gun) then
		return -- RETURN: Not a gun tool
	end

	if loadedTools[tool] then
		return
	end

	initializeGunTool(tool)
end

local function loadRemotes()
	SimpleRemotesUtil.bindRemoteEventActions(globalRemoteEvent, {
		[EVENT_CODES.NotifyKill] = function(b: buffer)
			local characterInstanceId, ownerType
			local offset = 0

			characterInstanceId, offset = BufferUtil.readu32(b, offset)
			ownerType, offset = BufferUtil.readu8(b, offset)

			local killedCharacter = GlobalInstanceController.getInstance(characterInstanceId) :: GameTypes.R15Character?
			if not killedCharacter then
				return
			end

			warn("You killed", killedCharacter.Name, ". This entity was a ", BulletTrackingConstants.getOwnerTypeKey(ownerType))
		end,

		[EVENT_CODES.Damage] = function(b: buffer)
			local fromDirection
			local offset = 0

			fromDirection, offset = BufferUtil.readVector3_96(b, offset)

			WeaponsUtil.createDamageIndicator(fromDirection)
		end,

		[EVENT_CODES.Shoot] = function(b: buffer)
			local exitNodeId
			local offset = 0

			exitNodeId, offset = BufferUtil.readu32(b, offset)

			local exitNode = GlobalInstanceController.getInstance(exitNodeId) :: BasePart?
			if not exitNode then
				return
			end

			if (camera.CFrame.Position - exitNode.Position).Magnitude > 400 then
				return -- RETURN: No point in showing, too far away
			end

			local tool = exitNode:FindFirstAncestorOfClass("Tool")
			if not tool then
				return
			end

			local gunModule = require(WEAPON_MODULES[tool.Name])() :: GunModule

			playShootVFX(exitNode)

         gunModule.SoundSequences.Shoot:SetPitch(rng:NextNumber(0.9, 1.1))
         gunModule.SoundSequences.Shoot:Play(exitNode)
		end,
	}, SimpleRemotesUtil.DecodeActionBuffer)
end

local function loadCameraEffects()
	local appliedFOV, appliedCFrame = 0, IDENTITY_CF
	local lastCameraCFrame = camera.CFrame

	RunService:BindToRenderStep("GunBeforeCamera", Enum.RenderPriority.Camera.Value - 10, function()
		camera.FieldOfView -= appliedFOV
		camera.CFrame *= appliedCFrame:Inverse()
		lastCameraCFrame = camera.CFrame
	end)

	RunService:BindToRenderStep("GunAfterCamera", Enum.RenderPriority.Camera.Value + 10, function(dT)
		local rotation = coreSprings.CameraRotation:Update(dT, Vector3.zero)

		appliedFOV = coreSprings.Fov:Update(dT, aiming and ADDED_AIM_FOV or 0)
		appliedCFrame = CFrame.Angles(rotation.X, rotation.Y, rotation.Z)

		sensitivity = if inFPV and aiming then AIM_SENSITIVITY_MULTIPLIER else 1
		if sensitivity < 1 then
			camera.CFrame = CFrame.new(camera.CFrame.Position) * lastCameraCFrame.Rotation:Lerp(camera.CFrame.Rotation, sensitivity)
		end

		camera.FieldOfView += appliedFOV
		camera.CFrame *= appliedCFrame

		local fovAlpha = getFovAlpha(appliedFOV)
		gunUIVignette.ImageTransparency = math.lerp(1, 0.5, fovAlpha)
	end)
end

local function registerInputs()
	InputController.registerInput(INPUT_ACTIONS.Shoot, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2, function(state)
		if inputContext then
			inputContext.SetShootingButtonDown(state == Enum.UserInputState.Begin)
		end
	end, {
		RequiresAlive = true,
		MobileButton = {
			SizeMultiplier = 1.25,
			PositionOffsetScalar = Vector2.new(-0.16, -1.37),
			Radius = UDim.new(1, 0),
			IsToggle = false,
		},
	}, true)

	InputController.registerInput(INPUT_ACTIONS.Aim, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2, function(state)
		if inputContext then
			if DeviceUtil.isMobile() then
				if state == Enum.UserInputState.Begin then
					inputContext.SetAiming(not inputContext.IsAiming())
				end
			else
				inputContext.SetAiming(state == Enum.UserInputState.Begin)
			end
		end
	end, {
		RequiresAlive = true,
		MobileButton = {
			SizeMultiplier = 0.75,
			PositionOffsetScalar = Vector2.new(-1, -0.75),
			Radius = UDim.new(1, 0),
			IsToggle = true,
		},
	}, true)

	InputController.registerInput(INPUT_ACTIONS.Reload, Enum.KeyCode.R, Enum.KeyCode.ButtonX, function(state)
		if state == Enum.UserInputState.Begin and inputContext then
			inputContext.DoReload()
		end
	end, {
		RequiresAlive = true,
		MobileButton = {
			SizeMultiplier = 0.75,
			PositionOffsetScalar = Vector2.new(-1, 0.08),
			Radius = UDim.new(1, 0),
			IsToggle = false,
		},
	}, true)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function GunController.init()
	gunUICrosshair.Visible = false
	gunUIAmmoLabel.Visible = false

	collisionDebugPart = Instance.new("Part")
	collisionDebugPart.Size = Vector3.one * 0.5
	collisionDebugPart.Color = Color3.new(1, 0, 0)
	collisionDebugPart.Anchored = true
	collisionDebugPart.Parent = workspace
	collisionDebugPart.CanCollide = false
	collisionDebugPart.CanQuery = false

	for _, crosshair in gunUICrosshair:GetChildren() do
		if crosshair:IsA("Frame") then
			table.insert(gunUICrosshairs, {
				Frame = crosshair,
				BasePosition = crosshair.Position,
				AnchorDirection = UIUtil.getAnchorDirection(crosshair),
			})
		end
	end

	for _, v in next, assets.Ammunition:GetChildren() do
		casingPools[v.Name] = ObjectPool.new(v, 300, `casing_{v}`)
	end

	PlayersUtil.onCharacterAdded(player, function(character: Model)
		if fakeFPVArms then
			fakeFPVArms:Destroy()
		end

		fakeFPVArms = assets.GunVisuals.FPVArms:Clone()

		const shirt = character:WaitForChild("Shirt", 5)
		if shirt then
			shirt:Clone().Parent = fakeFPVArms
		end

		-- Bake in the instances by adding a humanoid
		const humanoid = Instance.new("Humanoid")
		humanoid.Parent = fakeFPVArms

		const bodyColors = character:WaitForChild("Body Colors", 5)
		if bodyColors then
			bodyColors:Clone().Parent = fakeFPVArms
		end
	end)

	InstanceUtil.connectChildAdded(player, function(child)
		if child == player.Backpack then
			InstanceUtil.connectChildAdded(child, onBackpackChildAdded)
		end
	end)

	loadRemotes()
	loadCameraEffects()
	registerInputs()

	if RunService:IsStudio() then
		task.defer(preloadWeaponAssets)
	end
end

function GunController.test()
	local mouseUnlock = player.PlayerGui.HUD.MouseUnlock

	local wfa = Instance.new("WireframeHandleAdornment")
	wfa.Adornee = workspace.Terrain
	wfa.Parent = workspace.Terrain
	wfa.Color3 = Color3.new(1, 0, 0)

	InputController.registerInput(DEBUG_INPUT_ACTIONS.ToggleMouseUnlock, Enum.KeyCode.LeftAlt, nil, function(state)
		if state == Enum.UserInputState.Begin then
			mouseUnlock.Visible = not mouseUnlock.Visible
		end
	end, {
		RequiresHUD = true,
	})
end

return GunController
