local WeaponsUtil = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local SoundController = require(ReplicatedStorage.Client.Core.SoundController)
local EquipmentConstants = require(ReplicatedStorage.Shared.Constants.EquipmentConstants)
local Scheduler = require(ReplicatedStorage.Shared.Classes.Scheduler)
local GameTypes = require(ReplicatedStorage.Shared.GameTypes)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local IS_CLIENT = RunService:IsClient()
local SLOTS = EquipmentConstants.Slots

local TWEEN_INFO = TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function WeaponsUtil.isToolAGun(tool: Tool?)
	return tool:IsA("Tool") and tool:GetAttribute("Slot", SLOTS.Gun)
end

function WeaponsUtil.getAverageDamage(gunModule: GameTypes.GunModule)
	local dmg, n = 0, 0
	for _, v in next, gunModule.Damage do
		dmg += v
		n += 1
	end
	return dmg / n
end

-------------------------------------------------------------------------------
-- CLIENT FUNCTIONS
-------------------------------------------------------------------------------

if IS_CLIENT then
	local ConnectionsList = require(ReplicatedStorage.Shared.Classes.ConnectionsList)
	local ObjectPool = require(ReplicatedStorage.Shared.Classes.ObjectPool)

	local scheduler = Scheduler.new()
	local rng = Random.new()

	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera

	local gunUIScreen = player.PlayerGui.GunUI

	local hitmarkerPool = ObjectPool.new(gunUIScreen.Hitmarker, 500, "Hitmarkers")
	local damageIndicatorPool = ObjectPool.new(gunUIScreen.DamageIndicator, 100, "DamageIndicators")

	--[[
      Client methods go under here
   ]]

	function WeaponsUtil.createHitmarker(position: Vector3, color: Color3, rotation: number?, dontPlaySound: true?)
		local screenPosition, onScreen = camera:WorldToViewportPoint(position)
		if not onScreen then
			return -- RETURN: No point in rendering
		end

		local hitmarker = hitmarkerPool:Draw(gunUIScreen)
		hitmarker.Rotation = rotation or rng:NextNumber(-20, 20)
		hitmarker.Position = UDim2.fromOffset(screenPosition.X, screenPosition.Y)

		for _, frame in next, hitmarker:GetChildren() do
			if frame:IsA("Frame") then
				frame.BackgroundColor3 = color
			end
		end

		hitmarker.Visible = true
		if not dontPlaySound then
			SoundController.play("HitMarker", {Pitch = rng:NextNumber(0.9, 1.4)})
		end

		scheduler:Add(0.1, hitmarkerPool.Return, hitmarkerPool, hitmarker)
	end

	function WeaponsUtil.createDamageIndicator(fromPosition: Vector3)
		local PIXEL_OFFSET = 150
		local LIFETIME = 5

		local damageIndicator = damageIndicatorPool:Draw(gunUIScreen)
		local rendered = false

		local connectionList = ConnectionsList.new({
			RunService.RenderStepped:Connect(function()
				local cameraCFrame = camera.CFrame

				local fromDirection = (fromPosition - cameraCFrame.Position)
				fromDirection = Vector3.new(fromDirection.X, 0, fromDirection.Z).Unit

				local camLook = Vector3.new(cameraCFrame.LookVector.X, 0, cameraCFrame.LookVector.Z).Unit
				local camRight = Vector3.new(cameraCFrame.RightVector.X, 0, cameraCFrame.RightVector.Z).Unit

				local angle = math.atan2(fromDirection:Dot(camRight), fromDirection:Dot(camLook)) - math.pi / 2

				damageIndicator.Rotation = math.deg(angle)
				damageIndicator.Position = UDim2.new(0.5, PIXEL_OFFSET * math.cos(angle), 0.5, PIXEL_OFFSET * math.sin(angle))

				if not rendered then
					rendered = true

					damageIndicator.Visible = true
					damageIndicator.ImageTransparency = 0.6
				end
			end),
		})

		scheduler:Add(LIFETIME - TWEEN_INFO.Time, function()
			TweenService:Create(damageIndicator, TWEEN_INFO, { ImageTransparency = 1 }):Play()
		end)

		scheduler:Add(LIFETIME, function()
			connectionList:Destroy()
			damageIndicatorPool:Return(damageIndicator)
		end)
	end
end

return WeaponsUtil
