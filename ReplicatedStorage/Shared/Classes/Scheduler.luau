local RunService = game:GetService("RunService")
--[[
  Scheduler

  Description:
  Schedules function calls without spawning new threads, only use in serial. 
   (Batches calls at 0.01s precision)

  Author:
  @SixthAtom
]]

local Scheduler = {}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local PRECISION = 0.01

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type ScheduledCall = {
	Func: (...any) -> (),
	Args: { any },
}

export type Scheduler = {
	_scheduled: { [number]: { ScheduledCall } },
	_connection: RBXScriptConnection,

	Add: (self: Scheduler, delay: number, func: (...any) -> (), ...any) -> (),
	Destroy: (self: Scheduler) -> (),
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function toBucketKey(time: number)
	return math.ceil(time / PRECISION + 0.5)
end

local function runDue(self: Scheduler)
	local nowKey = toBucketKey(os.clock())

	for bucketKey, calls in next, self._scheduled do
		if bucketKey <= nowKey then
			self._scheduled[bucketKey] = nil

			for _, c in next, calls do
				c.Func(unpack(c.Args))
			end
		end
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function Scheduler.Add(self: Scheduler, delay: number, func: (...any) -> (), ...: any)
	local bucketKey = toBucketKey(os.clock() + delay)

	local bucket = self._scheduled[bucketKey]
	if not bucket then
		bucket = {}
		self._scheduled[bucketKey] = bucket
	end

	bucket[#bucket + 1] = {
		Func = func,
		Args = { ... },
	}
end

function Scheduler.Destroy(self: Scheduler)
	self._connection:Disconnect()
	self._scheduled = {}
end

-------------------------------------------------------------------------------
-- RETURN
-------------------------------------------------------------------------------

return {
	new = function<T>()
		local self = table.clone(Scheduler) :: Scheduler

		self._scheduled = {}
		self._connection = RunService.Heartbeat:Connect(function()
			runDue(self)
		end)

		return self
	end,
}
