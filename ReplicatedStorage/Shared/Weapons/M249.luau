local ReplicatedStorage = game:GetService("ReplicatedStorage")

const SoundSequence = require(ReplicatedStorage.Shared.Classes.SoundSequence)
local Spring = require(ReplicatedStorage.Shared.Classes.Spring)
local WeaponConstants = require(ReplicatedStorage.Shared.Constants.WeaponConstants)
local GeneralUtil = require(ReplicatedStorage.Shared.Utils.GeneralUtil)

local random = Random.new()

return function()
	return {
		Caliber = WeaponConstants.Calibers["5.56x45mm"],

		MagazineSize = 200,
		Firerate = 800,
		Action = WeaponConstants.GunActions.Single,
		Firemode = WeaponConstants.GunFiremodes.Auto,
		Pellets = 1,
		PelletSpread = 0,
		MuzzleVelocity = { 2400, 3200 },

		TorsoYaw = math.rad(25),

		Damage = {
			Lower = 3,
			Upper = 10,
			Head = 19,
		},

		Springs = {
			RecoilOrientation = Spring.new(Vector3.zero, 1.2, 30, 0.9),
			RecoilPosition = Spring.new(Vector3.zero, 1.2, 30, 0.5),
			RecoilRoll = Spring.new(0, 1.2, 58, 0.40),

			FPVOrientation = Spring.new(Vector3.zero, 2, 25, 0.8),
			FPVPosition = Spring.new(Vector3.zero, 2, 25, 0.8),
         FPVLeftArm = Spring.new(Vector3.zero, 1, 16, 0.65),
         FPVRightArm = Spring.new(Vector3.zero, 1, 16, 0.75),
		},

		Offsets = {
			FirstPerson = CFrame.new(0.32433359375, -0.7780892578125, -1.204118359375) * CFrame.Angles(0, 0, 0.2295708302063605),
			ThirdPerson = CFrame.new(0.727104296875, 1.305166015625, -0.18013984375) * CFrame.Angles(0, 0, 0),
			FirstPersonAiming = CFrame.new(0, 0, -0.466273828125) * CFrame.Angles(0, 0, 0),
	      LeftArmSolver = CFrame.fromOrientation(0, math.pi / 2, -math.pi) + Vector3.new(0, 2.02, 0),
			RightArmSolver = CFrame.fromOrientation(0, math.pi / 2, -math.pi) + Vector3.new(0, 2.02, 0),
		},

		CalculateRecoil = function(aiming: boolean)
         const aimMulti = aiming and 0.5 or 1
         
			return {
				Pitch = random:NextNumber(6, 7) * aimMulti,
				Yaw = random:NextNumber(1, 1.5) * GeneralUtil.randomSign() * aimMulti,
				AxisZ = random:NextNumber(15, 17) * aimMulti,
				Fov = random:NextNumber(20, 30) * aimMulti,
				CameraRoll = random:NextNumber(2.5, 3) * aimMulti,
				Roll = random:NextNumber(8,10) * GeneralUtil.randomSign() * aimMulti,

            LeftArm = Vector3.new(
               random:NextNumber(2.5, 3.5),
               random:NextNumber(1.0, 1.5) + random:NextNumber(-1.2, 1.2),
               random:NextNumber(-2.5, 2.5)
            ) * aimMulti,

            RightArm = Vector3.new(
               random:NextNumber(2.5, 3.5),
               random:NextNumber(-1.5, -1.0),
               random:NextNumber(-0.5, 0.5)
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
			EmptyReload = 101276890280032,
			Reload = 101276890280032,
			Shoot = 75665522163231,
			Empty = 138701485610187,
			Idle = 138701485610187,
		},

      SoundSequences = {
         Reload = SoundSequence.new({
            { Volume = 1, Pitch = 1, Time = 27/60, Id = 111536469337026 }, -- Latch open
            { Volume = 1, Pitch = 1, Time = 107/60, Id = 135519754212644 }, -- Mag out
            { Volume = 1, Pitch = 1, Time = 182/60, Id = 87723670225186 }, -- Mag in
            { Volume = 1, Pitch = 1, Time = 228/60, Id = 98421532106641 }, -- Belt and rail slap
            { Volume = 1, Pitch = 1, Time = 354/60, Id = 89069016973471} -- Rack slide
         }),
         
         EmptyReload = SoundSequence.new({
            { Volume = 1, Pitch = 1, Time = 27/60, Id = 111536469337026 }, -- Latch open
            { Volume = 1, Pitch = 1, Time = 107/60, Id = 135519754212644 }, -- Mag out
            { Volume = 1, Pitch = 1, Time = 182/60, Id = 87723670225186 }, -- Mag in
            { Volume = 1, Pitch = 1, Time = 228/60, Id = 98421532106641 }, -- Belt and rail slap
            { Volume = 1, Pitch = 1, Time = 354/60, Id = 89069016973471} -- Rack slide
         }),
         
         Shoot = SoundSequence.new({
            { Volume = 1, Pitch = 1, Time = 0, Id = 130803236536545 } -- Shoot
         })
      },

		Timestamps = {
			MagOut = 110/60,
			MagIn = 182/60,
		},
	}
end
