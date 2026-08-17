local ReplicatedStorage = game:GetService("ReplicatedStorage")

const SoundSequence = require(ReplicatedStorage.Shared.Classes.SoundSequence)
local Spring = require(ReplicatedStorage.Shared.Classes.Spring)
local WeaponConstants = require(ReplicatedStorage.Shared.Constants.WeaponConstants)
local GeneralUtil = require(ReplicatedStorage.Shared.Utils.GeneralUtil)

local random = Random.new()

return function()
	return {
		Caliber = WeaponConstants.Calibers[".45 ACP"],

		MagazineSize = 12,
		Firerate = 500,
		Action = WeaponConstants.GunActions.Single,
		Firemode = WeaponConstants.GunFiremodes.Semi,
		Pellets = 1,
		PelletSpread = 0,
		MuzzleVelocity = 2400,

		TorsoYaw = math.rad(5),

		Damage = {
			Lower = 24,
			Upper = 34,
			Head = 68,
		},

		Springs = {
			RecoilOrientation = Spring.new(Vector3.zero, 1.5, 32, 0.65),
			RecoilPosition = Spring.new(Vector3.zero, 1.5, 32, 0.6),
			RecoilRoll = Spring.new(0, 1, 48, 0.18),

			FPVOrientation = Spring.new(Vector3.zero, 2, 25, 0.8),
			FPVPosition = Spring.new(Vector3.zero, 2, 25, 0.8),
         FPVLeftArm = Spring.new(Vector3.zero, 1, 40, 0.25),
         FPVRightArm = Spring.new(Vector3.zero, 1, 40, 0.25),
		},

		Offsets = {
			FirstPerson = CFrame.new(0.372197265625, -0.67049609375, -1.931494140625) * CFrame.fromOrientation(0, 0, math.rad(7.3)),
			ThirdPerson = CFrame.new(0.700791015625, 1.45019375, -1.3635564453125),
			FirstPersonAiming = CFrame.new(0, 0, -1.165753125),
			LeftArmSolver = CFrame.fromOrientation(0, math.pi / 2, -math.pi) + Vector3.new(0, 2.1325, 0),
			RightArmSolver = CFrame.fromOrientation(0, math.pi / 2, -math.pi) + Vector3.new(0, 2.1325, 0),
		},

		CalculateRecoil = function(aiming: boolean)
         const aimMulti = aiming and 0.5 or 1
         
			return {
				Pitch = random:NextNumber(19, 19.25) * aimMulti,
				Yaw = random:NextNumber(3.5, 4) * aimMulti,
				AxisZ = random:NextNumber(20, 20.5) * aimMulti,
				Fov = random:NextNumber(40, 55) * aimMulti,
				CameraRoll = random:NextNumber(3, 3.5) * aimMulti,
				Roll = random:NextNumber(4, 8) * GeneralUtil.randomSign() * aimMulti,

            LeftArm = Vector3.new(
               random:NextNumber(7, 8) * GeneralUtil.randomSign(),
               random:NextNumber(7, 8) * GeneralUtil.randomSign(),
               random:NextNumber(7, 8) * GeneralUtil.randomSign()
            ) * aimMulti,

            RightArm = Vector3.new(
               random:NextNumber(7, 8) * GeneralUtil.randomSign(),
               random:NextNumber(7, 8) * GeneralUtil.randomSign(),
               random:NextNumber(7, 8) * GeneralUtil.randomSign()
            ) * aimMulti
			}
		end,

		CalculateSway = function(direction: Vector3, lookDelta: Vector2, speed: number, aim: boolean, sprinting: boolean)
			const AIM_MULTIPLIER = aim and 0.5 or 1
			const FREQUENCY = sprinting and 24 or 16

			const t = os.clock()
			const speedAlpha = math.clamp(speed / 16, 0, 1)

			const moveX = direction.X
			const moveZ = -direction.Z
			const moveMagnitude = math.clamp(Vector2.new(moveX, moveZ).Magnitude, 0, 1)

			local finalCFrame: CFrame
			if sprinting then
				finalCFrame = CFrame.Angles(
					math.rad(32) + math.sin(t * (FREQUENCY / 2)) * 0.045 * speedAlpha * moveMagnitude - lookDelta.Y * 0.0015,
					math.sin(t * (FREQUENCY / 4)) * 0.03 * speedAlpha * moveMagnitude - lookDelta.X * 0.0012,
					math.rad(6) + math.sin(t * FREQUENCY) * 0.055 * speedAlpha * moveMagnitude + moveX * 0.06
				)

				finalCFrame += Vector3.new(
					math.sin(t * (FREQUENCY / 2)) * 0.045 * speedAlpha * moveMagnitude,
					0.07 + math.sin(t * FREQUENCY) * 0.035 * speedAlpha * moveMagnitude,
					0.02 + math.cos(t * (FREQUENCY / 2)) * 0.02 * speedAlpha * moveMagnitude
				) * AIM_MULTIPLIER
			else
				finalCFrame = CFrame.Angles(
					math.sin(t * 1.4) * 0.0035 - lookDelta.Y * 0.0045,
					math.sin(t * 1.8) * 0.0025 - lookDelta.X * 0.0035,
					math.sin(t * 1.2) * 0.002 + moveX * 0.075 + math.sin(t * FREQUENCY / 2) * 0.02 * speedAlpha * moveMagnitude
				)

				finalCFrame += Vector3.new(
					math.sin(t * 1.6) * 0.003 + moveX * 0.05,
					math.sin(t * 2.4) * 0.004 + math.sin(t * FREQUENCY) * 0.03 * moveMagnitude * speedAlpha,
					0
				) * AIM_MULTIPLIER
			end

			return finalCFrame
		end,

		Animations = {
			EmptyReload = 117697294110252,
			Reload = 128528604357985,
			Shoot = 87204221491465,
			Empty = 84232246111943,
			Idle = 79110880102337,
		},

      SoundSequences = {
         Reload = SoundSequence.new({
            { Volume = 1, Pitch = 1.2, Time = 18/42, Id = 86564897647873 }, -- Mag throw
            { Volume = 1, Pitch = 1, Time = 50/42, Id = 94436562536620 }, -- Mag enter
         }),

         EmptyReload = SoundSequence.new({
            { Volume = 1, Pitch = 1.2, Time = 18/42, Id = 86564897647873 }, -- Mag throw
            { Volume = 1, Pitch = 1, Time = 50/42, Id = 94436562536620 }, -- Mag enter
            { Volume = 1, Pitch = 1, Time = 82/42, Id = 81967093909840 } -- Bolt pullback
         }),

         Shoot = SoundSequence.new({
            { Volume = 1, Pitch = 1, Time = 0, Id = 98689091988046 } -- Shoot
         })
      },

		Timestamps = {
			MagOut = 21/42,
			MagIn = 60/42,
		},
	}
end
