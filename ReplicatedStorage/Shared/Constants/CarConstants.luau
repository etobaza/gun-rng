local CarConstants = {}

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type CarConfig = {
	ForwardVelocity: number,
	ForwardTorque: number,
	ForwardAcceleration: number,

	ReverseVelocity: number,
	ReverseTorque: number,
	ReverseAcceleration: number,

	BrakingTorque: number,

	SteerSpeed: number,
	MaxSteerAngle: number,
	CounterSteerMultiplier: number,

	SuspensionHeight: number,
	SuspensionStiffnessScale: number,
	SuspensionDampingScale: number,

	MaxWorth: number,
   Health: number,
	TorsionStiffness: number?,
}

export type CarName = keyof<typeof(CarConstants.CarNames)>

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local carNames = {
	Test = "Test",
	Lada = "Lada",
}

local carConfigs: { [keyof<typeof(carNames)>]: CarConfig } = {
	Test = {
		ForwardVelocity = 120,
		ForwardTorque = 30000,
		ForwardAcceleration = 40,

		ReverseVelocity = 50,
		ReverseTorque = 20000,
		ReverseAcceleration = 30,

		BrakingTorque = 16000,

		SteerSpeed = 13,
		MaxSteerAngle = math.rad(25),
		CounterSteerMultiplier = 0.012,

		SuspensionHeight = 1.2,
		SuspensionStiffnessScale = 0.85,
		SuspensionDampingScale = 1,

		MaxWorth = 5000,
      Health = 5000,
		TorsionStiffness = 25000,
	},

	Lada = {
		ForwardVelocity = 120,
		ForwardTorque = 30000,
		ForwardAcceleration = 40,

		ReverseVelocity = 50,
		ReverseTorque = 20000,
		ReverseAcceleration = 30,

		BrakingTorque = 16000,

		SteerSpeed = 13,
		MaxSteerAngle = math.rad(25),
		CounterSteerMultiplier = 0.012,

		SuspensionHeight = 1.5,
		SuspensionStiffnessScale = 0.9,
		SuspensionDampingScale = 1.25,

		MaxWorth = 5000,
      Health = 15_000,
		TorsionStiffness = 25000,
	},
}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

CarConstants.Attributes = {
	WheelId = "WheelId",
	OriginalCFrame = "OriginalCFrame",
	OriginalOwner = "OriginalOwner",
}

CarConstants.CarConfigs = carConfigs
CarConstants.CarNames = carNames

return CarConstants
