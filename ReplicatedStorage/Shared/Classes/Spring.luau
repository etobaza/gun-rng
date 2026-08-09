--[[
	Spring

	Description:
	Lightweight damped spring for smoothing numbers, Vector2s, and Vector3s.

	Author:
	@SixthAtom
]]

local Spring = {}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local MAX_STEP = 1 / 120

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type Spring<T> = {
	Position: T,
	Velocity: T,
	Mass: number,
	Speed: number,
	Damper: number,
	Resolution: number,

	Update: (self: Spring<T>, deltaTime: number, target: T) -> T,
	Impulse: (self: Spring<T>, deltaVelocity: T) -> (),
	GetPosition: (self: Spring<T>) -> T,
	Reset: (self: Spring<T>) -> (),
}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getZeroFromValue<T>(value: T): T
	if typeof(value) == "number" then
		return 0 :: any
	end

	return value - value
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function Spring.Reset<T>(self: Spring<T>)
	self.Position = getZeroFromValue(self.Position)
	self.Velocity = getZeroFromValue(self.Velocity)
end

function Spring.Update<T>(self: Spring<T>, deltaTime: number, target: T): T
	local mass = self.Mass
	local speed = self.Speed
	local damper = self.Damper
	local goal = target :: any

	local clampedDeltaTime = math.min(deltaTime, 0.1)
	local steps = math.max(self.Resolution, math.ceil(clampedDeltaTime / MAX_STEP))
	local stepDeltaTime = clampedDeltaTime / steps

	local position = self.Position :: any
	local velocity = self.Velocity :: any

	for _ = 1, steps do
		local offset = goal - position
		local springForce = offset * (speed * speed)
		local dampingForce = velocity * (2 * damper * speed)
		local acceleration = (springForce - dampingForce) / mass

		velocity += acceleration * stepDeltaTime
		position += velocity * stepDeltaTime
	end

	self.Velocity = velocity
	self.Position = position

	return self.Position
end

function Spring.Impulse<T>(self: Spring<T>, deltaVelocity: T)
	self.Velocity = ((self.Velocity :: any) + deltaVelocity) :: T
end

function Spring.GetPosition<T>(self: Spring<T>): T
	return self.Position
end

-------------------------------------------------------------------------------
-- RETURN
-------------------------------------------------------------------------------

return {
	new = function<T>(initialPosition: T, mass: number?, speed: number?, damper: number?, resolution: number?)
		local valueType = typeof(initialPosition)
		assert(valueType == "number" or valueType == "Vector2" or valueType == "Vector3", "Spring only supports number, Vector2, and Vector3 values")
		assert(mass == nil or mass > 0, "Spring mass must be greater than 0")

		local self = table.clone(Spring) :: Spring<T>

		self.Position = initialPosition
		self.Velocity = getZeroFromValue(initialPosition)
		self.Mass = mass or 1
		self.Speed = speed or 10
		self.Damper = damper or 1
		self.Resolution = resolution or 1

		return self
	end,
}
