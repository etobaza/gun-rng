local ReplicatedStorage = game:GetService("ReplicatedStorage")

const SoundSequence = require(ReplicatedStorage.Shared.Classes.SoundSequence)
local Spring = require(ReplicatedStorage.Shared.Classes.Spring)
local WeaponConstants = require(ReplicatedStorage.Shared.Constants.WeaponConstants)
local GeneralUtil = require(ReplicatedStorage.Shared.Utils.GeneralUtil)

local random = Random.new()

return function()
	return {
		Caliber = WeaponConstants.Calibers["7.62x39mm"],

		MagazineSize = 31,
		Firerate = 550,
		Action = WeaponConstants.GunActions.Single,
		Firemode = WeaponConstants.GunFiremodes.Auto,
		Pellets = 1,
		PelletSpread = 0,
		MuzzleVelocity = { 2400, 3200 },

		TorsoYaw = math.rad(25),

		Damage = {
			Lower = 9,
			Upper = 19,
			Head = 45,
		},

		Springs = {
			RecoilOrientation = Spring.new(Vector3.zero, 1.2, 30, 0.7),
			RecoilPosition = Spring.new(Vector3.zero, 1.2, 30, 0.5),
			RecoilRoll = Spring.new(0, 1.0, 52, 0.35),

			FPVOrientation = Spring.new(Vector3.zero, 2, 25, 0.8),
			FPVPosition = Spring.new(Vector3.zero, 2, 25, 0.8),
         FPVLeftArm = Spring.new(Vector3.zero, 1, 20, 0.5),
         FPVRightArm = Spring.new(Vector3.zero, 1, 20, 0.75),
		},

		Offsets = {
         FirstPerson = CFrame.new(0.48402265625, -0.673965234375, -1.3153087890625) * CFrame.fromOrientation(0, 0, 0.21025678111464308),
         ThirdPerson = CFrame.new(0.6199921875, 1.2962921875, -0.58085859375) * CFrame.fromOrientation(0, 0, 0),
         FirstPersonAiming = CFrame.new(0, -0.02801484375, -0.305837890625) * CFrame.fromOrientation(0, 0, 0),
         LeftArmSolver = CFrame.fromOrientation(0.67046, -1.85292, 2.86726) + Vector3.new(-0.01573, 1.93372, -0.11696),
			RightArmSolver = CFrame.fromOrientation(0, math.pi / 2, -math.pi) + Vector3.new(0, 2.02, 0),
		},

		CalculateRecoil = function(aiming: boolean)
         const aimMulti = aiming and 0.5 or 1
         
			return {
				Pitch = random:NextNumber(10, 12) * aimMulti,
				Yaw = random:NextNumber(1.2, 1.8) * GeneralUtil.randomSign() * aimMulti,
				AxisZ = random:NextNumber(24, 28) * aimMulti,
				Fov = random:NextNumber(35, 45) * aimMulti,
				CameraRoll = random:NextNumber(2.5, 3) * aimMulti,
				Roll = random:NextNumber(6, 9) * GeneralUtil.randomSign() * aimMulti,

            LeftArm = Vector3.new(
               random:NextNumber(2, 3) * GeneralUtil.randomSign(),
               random:NextNumber(3, 5),
               random:NextNumber(-2.5, 2.5)
            ) * aimMulti,

            RightArm = Vector3.new(
               random:NextNumber(4.5, 6),
               random:NextNumber(-3.0, -2.0),
               random:NextNumber(-1, 1)
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
			EmptyReload = 80778101562393,
			Reload = 88355742840466,
			Shoot = 79258039587617,
			Empty = 73855952647752,
			Idle = 80865067018451,
		},

      SoundSequences = {
         Reload = SoundSequence.new({
            { Volume = 1, Pitch = 1, Time = 70/60, Id = 139200000621238 }, -- Mag throw
            { Volume = 1, Pitch = 1, Time = 110/60, Id = 132767133459276 }, -- Mag enter
         }),

         EmptyReload = SoundSequence.new({
            { Volume = 1, Pitch = 1, Time = 70/60, Id = 139200000621238 }, -- Mag throw
            { Volume = 1, Pitch = 1, Time = 110/60, Id = 132767133459276 }, -- Mag enter
            { Volume = 1, Pitch = 1, Time = 175/60, Id = 99388237745221 } -- Bolt pullback
         }),

         Shoot = SoundSequence.new({
            { Volume = 0.9, Pitch = 1, Time = 0, Id = 95135928842394 } -- Shoot
         })
      },

		Timestamps = {
			MagOut = 73/60,
			MagIn = 120/60,
		},
	}
end
