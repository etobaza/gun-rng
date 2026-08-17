local ReplicatedStorage = game:GetService("ReplicatedStorage")

const SoundSequence = require(ReplicatedStorage.Shared.Classes.SoundSequence)
local Spring = require(ReplicatedStorage.Shared.Classes.Spring)
local WeaponConstants = require(ReplicatedStorage.Shared.Constants.WeaponConstants)
local GeneralUtil = require(ReplicatedStorage.Shared.Utils.GeneralUtil)

local random = Random.new()

return function()
	return {
		Caliber = WeaponConstants.Calibers["7.62x51mm NATO"],

		MagazineSize = 5,
		Firerate = 30,
		Action = WeaponConstants.GunActions.Single,
		Firemode = WeaponConstants.GunFiremodes.Semi,
		Pellets = 1,
		PelletSpread = 0,
		MuzzleVelocity = { 4500, 7000 },
      ScopeImage = "rbxassetid://111913395797647",

		TorsoYaw = math.rad(25),

		Damage = {
			Lower = 25,
			Upper = 80,
			Head = 150,
		},

		Springs = {
			RecoilOrientation = Spring.new(Vector3.zero, 2.2, 22, 0.9),
			RecoilPosition = Spring.new(Vector3.zero, 1.5, 22, 0.5),
			RecoilRoll = Spring.new(0, .4, 36, 0.18),

			FPVOrientation = Spring.new(Vector3.zero, 2, 27, 0.9),
			FPVPosition = Spring.new(Vector3.zero, 2, 27, 0.9),
         FPVLeftArm = Spring.new(Vector3.zero, 1, 30, 0.25),
         FPVRightArm = Spring.new(Vector3.zero, 1, 30, 0.25),
		},

		Offsets = {
			FirstPerson = CFrame.new(0.3402171875, -0.760065234375, -1.7273552734375) * CFrame.Angles(0, 0, 0.16596365400547772),
			ThirdPerson = CFrame.new(0.695351953125, 1.49996953125, -1.1826404296875) * CFrame.Angles(0, 0, 0),
			FirstPersonAiming = CFrame.new(0, 0, 1.5) * CFrame.Angles(0, 0, 0),
			LeftArmSolver = CFrame.fromOrientation(0, math.pi / 2, -math.pi) + Vector3.new(0, 2.02, 0),
			RightArmSolver = CFrame.fromOrientation(0, math.pi / 2, -math.pi) + Vector3.new(0, 2.02, 0),
		},

		CalculateRecoil = function(aiming: boolean)
         const aimMulti = aiming and 0.5 or 1

			return {
				Pitch = random:NextNumber(19, 19.25) * aimMulti,
				Yaw = random:NextNumber(3.5, 4) * aimMulti,
				AxisZ = random:NextNumber(15, 15.5) * aimMulti,
				Fov = random:NextNumber(35, 45) * aimMulti,
				CameraRoll = random:NextNumber(4.5, 5) * aimMulti,
				Roll = random:NextNumber(8,10) * GeneralUtil.randomSign() * aimMulti,

            LeftArm = Vector3.new(
               random:NextNumber(9, 10) * GeneralUtil.randomSign(),
               random:NextNumber(9, 10) * GeneralUtil.randomSign(),
               random:NextNumber(9, 10) * GeneralUtil.randomSign()
            ) * aimMulti,

            RightArm = Vector3.new(
               random:NextNumber(9, 10) * GeneralUtil.randomSign(),
               random:NextNumber(9, 10) * GeneralUtil.randomSign(),
               random:NextNumber(9, 10) * GeneralUtil.randomSign()
            ) * aimMulti
			}
		end,

		CalculateSway = function(direction: Vector3, lookDelta: Vector2, speed: number, aim: boolean, sprinting: boolean)
			local AIM_MULTIPLIER = aim and 0.55 or 1
			local FREQUENCY = sprinting and 20 or 13

			local t = os.clock()
			local speedAlpha = math.clamp(speed / 16, 0, 1)

			local moveX = direction.X
			local moveZ = -direction.Z
			local moveMagnitude = math.clamp(Vector2.new(moveX, moveZ).Magnitude, 0, 1)

			local finalCFrame: CFrame
			if sprinting then
				finalCFrame = CFrame.Angles(
					math.rad(24) + math.sin(t * (FREQUENCY / 2)) * 0.04 * speedAlpha * moveMagnitude - lookDelta.Y * 0.0013,
					math.sin(t * (FREQUENCY / 4)) * 0.025 * speedAlpha * moveMagnitude - lookDelta.X * 0.0011,
					math.rad(9) + math.sin(t * FREQUENCY) * 0.05 * speedAlpha * moveMagnitude + moveX * 0.065
				)

				finalCFrame += Vector3.new(
					math.sin(t * (FREQUENCY / 2)) * 0.04 * speedAlpha * moveMagnitude,
					0.055 + math.sin(t * FREQUENCY) * 0.03 * speedAlpha * moveMagnitude,
					0.045 + math.cos(t * (FREQUENCY / 2)) * 0.025 * speedAlpha * moveMagnitude
				) * AIM_MULTIPLIER
			else
				finalCFrame = CFrame.Angles(
					math.sin(t * 1.25) * 0.004 - lookDelta.Y * 0.0042,
					math.sin(t * 1.7) * 0.003 - lookDelta.X * 0.0032,
					math.sin(t * 1.15) * 0.0025 + moveX * 0.08 + math.sin(t * FREQUENCY / 2) * 0.024 * speedAlpha * moveMagnitude
				)

				finalCFrame += Vector3.new(
					math.sin(t * 1.45) * 0.004 + moveX * 0.06,
					math.sin(t * 2.2) * 0.005 + math.sin(t * FREQUENCY) * 0.033 * moveMagnitude * speedAlpha,
					0
				) * AIM_MULTIPLIER
			end

			return finalCFrame
		end,

		Animations = {
			EmptyReload = 97806236164958,
			Reload = 104149363180837,
			Shoot = 119356576212254,
			Idle = 120891455745436,
		},

      SoundSequences = {
         Reload = SoundSequence.new({
            { Volume = 1, Pitch = 0.9, Time = 24/60, Id = 86564897647873 }, -- Mag throw
            { Volume = 1, Pitch = 0.9, Time = 100/60, Id = 94436562536620 }, -- Mag enter
         }),
         
         EmptyReload = SoundSequence.new({
            { Volume = 1, Pitch = 0.9, Time = 24/60, Id = 86564897647873 }, -- Mag throw
            { Volume = 1, Pitch = 0.9, Time = 100/60, Id = 94436562536620 }, -- Mag enter
            { Volume = 1, Pitch = 0.9, Time = 166/60, Id = 81967093909840 } -- Bolt pullback
         }),
         
         Shoot = SoundSequence.new({
            { Volume = 1, Pitch = 1, Time = 0, Id = 113324841610108 } -- Shoot
         })
      },

      Timestamps = {
         MagOut = 46/60,
         MagIn = 110/60,
      },
	}
end
