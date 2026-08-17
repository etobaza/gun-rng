local ReplicatedStorage = game:GetService("ReplicatedStorage")

const SoundSequence = require(ReplicatedStorage.Shared.Classes.SoundSequence)
local Spring = require(ReplicatedStorage.Shared.Classes.Spring)
local WeaponConstants = require(ReplicatedStorage.Shared.Constants.WeaponConstants)
const GeneralUtil = require(ReplicatedStorage.Shared.Utils.GeneralUtil)

local random = Random.new()

return function()
	return {
		Caliber = WeaponConstants.Calibers["12g"],

		MagazineSize = 8,
		Firerate = 85,
		Action = WeaponConstants.GunActions.Pump,
		Firemode = WeaponConstants.GunFiremodes.Semi,
		Pellets = 12,
		PelletSpread = 0.035,
		MuzzleVelocity = { 1400, 2200 },

		TorsoYaw = math.rad(40),

		Damage = {
			Lower = 10,
			Upper = 14,
			Head = 20,
		},

		Springs = {
			RecoilOrientation = Spring.new(Vector3.zero, 2.4, 29, 0.9),
			RecoilPosition = Spring.new(Vector3.zero, 2.4, 29, 0.7),
			RecoilRoll = Spring.new(0, 2, 40, 0.25),

			FPVOrientation = Spring.new(Vector3.zero, 2.2, 25, 0.92),
			FPVPosition = Spring.new(Vector3.zero, 2.2, 25, 0.92),
         FPVLeftArm = Spring.new(Vector3.zero, 1, 30, 0.25),
         FPVRightArm = Spring.new(Vector3.zero, 1, 30, 0.25),
		},

		Offsets = {
			FirstPerson = CFrame.new(0.402879685, -0.772200406, -0.86234802, 0.990530491, -0.137292981, 0, 0.137292981, 0.990530491, 0, 0, 0, 1),
			ThirdPerson = CFrame.new(0.9551875, 1.18473911, -0.171182811, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			FirstPersonAiming = CFrame.new(0, -0.0525914058, -0.29945001, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			LeftArmSolver = CFrame.fromOrientation(-0.00000, 1.57080, 3.14159) + Vector3.new(0.00037, 1.91121, 0.00023),
			RightArmSolver = CFrame.fromOrientation(0, 1.57080, 3.14159) + Vector3.new(0, 1.91122, 0),
		},

		CalculateRecoil = function(aiming: boolean)
         const aimMulti = aiming and 0.5 or 1

			return {
				Pitch = random:NextNumber(19, 19.25) * aimMulti,
				Yaw = random:NextNumber(3.5, 4) * aimMulti,
				AxisZ = random:NextNumber(15, 15.5) * aimMulti,
				Fov = random:NextNumber(35, 45) * aimMulti,
				CameraRoll = random:NextNumber(1.5, 2.5) * aimMulti,
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
			local AIM_MULTIPLIER = aim and 0.6 or 1
			local FREQUENCY = sprinting and 20 or 12

			local t = os.clock()
			local speedAlpha = math.clamp(speed / 16, 0, 1)

			local moveX = direction.X
			local moveZ = -direction.Z
			local moveMagnitude = math.clamp(Vector2.new(moveX, moveZ).Magnitude, 0, 1)

			local finalCFrame: CFrame
			if sprinting then
				finalCFrame = CFrame.Angles(
					math.rad(18) + math.sin(t * (FREQUENCY / 2)) * 0.03 * speedAlpha * moveMagnitude - lookDelta.Y * 0.0012,
					math.sin(t * (FREQUENCY / 4)) * 0.02 * speedAlpha * moveMagnitude - lookDelta.X * 0.001,
					math.rad(10) + math.sin(t * FREQUENCY) * 0.04 * speedAlpha * moveMagnitude + moveX * 0.06
				)

				finalCFrame += Vector3.new(
					math.sin(t * (FREQUENCY / 2)) * 0.03 * speedAlpha * moveMagnitude,
					0.04 + math.sin(t * FREQUENCY) * 0.02 * speedAlpha * moveMagnitude,
					0.06 + math.cos(t * (FREQUENCY / 2)) * 0.02 * speedAlpha * moveMagnitude
				) * AIM_MULTIPLIER
			else
				finalCFrame = CFrame.Angles(
					math.sin(t * 1.2) * 0.004 - lookDelta.Y * 0.004,
					math.sin(t * 1.5) * 0.003 - lookDelta.X * 0.003,
					math.sin(t * 1.1) * 0.003 + moveX * 0.08 + math.sin(t * FREQUENCY / 2) * 0.025 * speedAlpha * moveMagnitude
				)

				finalCFrame += Vector3.new(
					math.sin(t * 1.4) * 0.004 + moveX * 0.06,
					math.sin(t * 2) * 0.005 + math.sin(t * FREQUENCY) * 0.035 * moveMagnitude * speedAlpha,
					0
				) * AIM_MULTIPLIER
			end

			return finalCFrame
		end,

		Animations = {
			Idle = 98329165085910,
			Shoot = 106887285227923,
			ReloadStart = 85753044106217,
			ReloadRound = 119057166929861,
			ReloadFinish = 140074409870506,
		},

      SoundSequences = {
         Shoot = SoundSequence.new({
            { Volume = 1, Pitch = 1, Time = 0, Id = 84032198169931 }
         }),

         ReloadStart = SoundSequence.new({
            { Volume = 1, Pitch = 1, Time = 0, Id = 95128710504876 }
         }),

         ReloadRound = SoundSequence.new({
            { Volume = 1, Pitch = 1, Time = 0, Id = 111937533692571 }
         }),

         ReloadFinish = SoundSequence.new({
            { Volume = 1, Pitch = 1, Time = 0, Id = 107130049976867 }
         }),
      },

		Timestamps = {
			Cycle = 0.4,
		},
	}
end
