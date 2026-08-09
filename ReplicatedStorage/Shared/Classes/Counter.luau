--[[
  Counter

  Description:
  Simple counter for, for example tracking IDs

  Author:
  @SixthAtom
]]

local Counter = {}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local DEFAULT_LIMIT = 4_294_967_295 -- u32 limit
local DEFAULT_BASE = 1

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type Counter = {
	_limit: number,
	_base: number,
	_n: number,
} & typeof(Counter)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function Counter.Increment(self: Counter)
	self._n = if self._n >= self._limit then self._base else self._n + 1
	return self._n
end

function Counter.Get(self: Counter)
	return self._n
end

-------------------------------------------------------------------------------
-- RETURN
-------------------------------------------------------------------------------

return {
	new = function(base: number?, limit: number?)
		local self = table.clone(Counter) :: Counter

		self._limit = limit or DEFAULT_LIMIT
		self._base = base or DEFAULT_BASE
		self._n = self._base

		return self
	end,
}
