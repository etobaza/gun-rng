--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Classes.Signal)

--[[
	Written by SixthAtom,
	a modern, type-checked, very lightweight and optimized reactive state listener.

	Designed to provide simple and efficient state management for (mainly UI) updates, 
	data syncing and event-driven systems in Roblox projects.
]]

local Atom = {}

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type Atom<T> = {
	_reference: T,
	_event: Signal.Signal<T, T>,

	Set: (self: Atom<T>, new: T) -> (),
	SetIndex: (self: Atom<T>, index: keyof<T>, value: any?) -> (),
	Update: (self: Atom<T>, updater: (current: T) -> T) -> (),
	Subscribe: (self: Atom<T>, handler: (new: T, old: T?) -> ()) -> Signal.Connection<T>,
	Compare: (self: Atom<T>, index: keyof<T>, compareValue: any) -> boolean,
	Get: (self: Atom<T>) -> T,
	GetIndex: (self: Atom<T>, index: keyof<T>) -> any,
	Destroy: (self: Atom<T>) -> (),
}

type GenericTable = { [any]: any }
type DifferenceEntry = { Old: any, New: any }
type DifferenceMap = { [any]: DifferenceEntry }

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function deepClone<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end

	local clone = {}
	for k, v in value :: GenericTable do
		clone[k] = deepClone(v)
	end

	return clone :: T
end

local function computeDifference(old: GenericTable, new: GenericTable): DifferenceMap
	local out: DifferenceMap = {}

	for k, oldValue in old do
		local newValue = new[k]
		if oldValue ~= newValue then
			out[k] = { Old = oldValue, New = newValue }
		end
	end

	for k, newValue in new do
		if old[k] == nil and newValue ~= nil then
			out[k] = { Old = nil, New = newValue }
		end
	end

	return out
end

local function handleChange<T>(self: Atom<T>, old: T, new: T)
	local difference = computeDifference(old :: GenericTable, new :: GenericTable)
	local differenceOld = {}
	local differenceNew = {}

	for k, v in difference do
		differenceOld[k] = v.Old
		differenceNew[k] = v.New
	end

	self._event:Fire(differenceNew, differenceOld)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- Replace the entire state with a new table
function Atom.Set<T>(self: Atom<T>, new: GenericTable)
	assert(type(new) == "table", "Set only accepts a table for new")

	local old = self:Get() -- deep clone old state first
	local reference = self._reference :: GenericTable

	-- Replace the reference with new values
	table.clear(reference)
	for k, v in new do
		reference[k] = deepClone(v) -- deep clone values to avoid shared references
	end

	handleChange(self, old, reference)
end

-- Update a single key in the state
function Atom.SetIndex<T>(self: Atom<T>, index: keyof<T>, value: any?)
	local old = self:Get() -- deep clone old state first
	local reference = self._reference :: GenericTable

	-- Assign a deep clone if value is a table
	if type(value) == "table" then
		value = deepClone(value)
	end
	reference[index] = value

	handleChange(self, old, reference)
end

-- Update state using a function that returns a new table
function Atom.Update<T>(self: Atom<T>, updater: (current: T) -> T)
	local old = self:Get() -- deep clone old state first
	local reference = self._reference :: GenericTable

	-- Pass a deep clone to updater to avoid mutating internal reference
	local newValues = updater(deepClone(reference)) :: GenericTable

	-- Replace the internal reference values safely
	table.clear(reference)
	for k, v in newValues do
		reference[k] = deepClone(v)
	end

	handleChange(self, old, reference)
end

-- Subscribe to state changes
function Atom.Subscribe<T>(self: Atom<T>, handler: (new: T, old: T?) -> ())
	task.spawn(handler, self._reference, nil)
	return self._event:Connect(handler)
end

-- Compare a key's value to a given value
function Atom.Compare<T>(self: Atom<T>, index: keyof<T>, compareValue: any)
	return (self._reference :: GenericTable)[index] == compareValue
end

-- Get a (deep) clone of a certain index in the current state
function Atom.GetIndex<T>(self: Atom<T>, index: keyof<T>)
	local value = (self._reference :: GenericTable)[index] :: any
	if type(value) == "table" then
		value = deepClone(value)
	end
	return value
end

-- Get a deep clone of the current state
function Atom.Get<T>(self: Atom<T>)
	return deepClone(self._reference)
end

-- Destroy the atom object and clean up the event
function Atom.Destroy<T>(self: Atom<T>)
	self._event:Destroy()
	self._reference = nil
end

-------------------------------------------------------------------------------
-- CONSTRUCTOR
-------------------------------------------------------------------------------

return {
	new = function<T>(initial: T)
		assert(type(initial) == "table", "Initial can only be a table.")

		local atom = table.clone(Atom) :: Atom<T>

		atom._reference = deepClone(initial)
		atom._event = Signal.new("Parallel") :: Signal.Signal<T, T>

		return atom
	end,
}
