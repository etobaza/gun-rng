--[[
  Stack

  Description:
  Lightweight generic Stack-like container with push/pop helpers.

  Author:
  @SixthAtom
]]

local Stack = {}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type Stack<T> = {
	_items: { T },

	Push: (self: Stack<T>, item: T) -> (),
	Pop: (self: Stack<T>) -> T?,
	Peek: (self: Stack<T>) -> T?,
	Size: (self: Stack<T>) -> number,
	IsEmpty: (self: Stack<T>) -> boolean,
	Clear: (self: Stack<T>) -> (),
	Find: (self: Stack<T>, item: T) -> number?,
	Remove: (self: Stack<T>, item: T) -> T?,
} -- Only use typeof() if the type is NOT generic

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

function Stack.Push<T>(self: Stack<T>, item: T)
	table.insert(self._items, item)
end

function Stack.Pop<T>(self: Stack<T>): T?
	return table.remove(self._items)
end

function Stack.Peek<T>(self: Stack<T>): T?
	return self._items[#self._items]
end

function Stack.Size<T>(self: Stack<T>): number
	return #self._items
end

function Stack.IsEmpty<T>(self: Stack<T>): boolean
	return #self._items == 0
end

function Stack.Clear<T>(self: Stack<T>)
	table.clear(self._items)
end

function Stack.Find<T>(self: Stack<T>, item: T): number?
	return table.find(self._items, item)
end

function Stack.Remove<T>(self: Stack<T>, item: T): T?
	local index = table.find(self._items, item)
	if not index then
		return nil
	end

	return table.remove(self._items, index)
end

-------------------------------------------------------------------------------
-- RETURN
-------------------------------------------------------------------------------

return {
	new = function<T>()
		local self = table.clone(Stack) :: Stack<T>
		self._items = {}
		return self
	end,
}
