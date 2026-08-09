--[[
	ConnectionsList

	A lightweight, object-oriented connection list for managing RBXScriptConnections
	and cleanup functions. Automatically disconnects/cleans up items when needed.
]]

local ConnectionsList = {}

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type CleanupItem = RBXScriptConnection | () -> () | { Disconnect: (any) -> () } | { Destroy: (any) -> () }

export type ConnectionKey = number

export type ConnectionsList = {
	_items: { [ConnectionKey]: CleanupItem },
	_nextKey: ConnectionKey,

	Add: (self: ConnectionsList, item: CleanupItem) -> ConnectionKey,
	Remove: (self: ConnectionsList, key: ConnectionKey) -> (),
	Clean: (self: ConnectionsList) -> (),
	Destroy: (self: ConnectionsList) -> (),
}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function cleanup(item: CleanupItem)
	if typeof(item) == "RBXScriptConnection" then
		item:Disconnect()
	elseif type(item) == "function" then
		item()
	elseif type(item) == "table" then
		if type(item.Disconnect) == "function" then
			item:Disconnect()
		elseif type(item.Destroy) == "function" then
			item:Destroy()
		end
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- Adds an item and returns its key. Use the key with Remove() to clean up
-- a specific item later without needing to store the function reference.
--
-- Example:
--   local key = connections:Add(part.Touched:Connect(...))
--   connections:Remove(key)
function ConnectionsList.Add(self: ConnectionsList, item: CleanupItem): ConnectionKey
	local key = self._nextKey
	self._nextKey += 1
	self._items[key] = item
	return key
end

-- Cleans up and removes the item associated with the given key.
-- Does nothing if the key has already been removed.
function ConnectionsList.Remove(self: ConnectionsList, key: ConnectionKey)
	local item = self._items[key]
	if item then
		self._items[key] = nil
		cleanup(item)
	end
end

function ConnectionsList.Clean(self: ConnectionsList)
	for key, item in self._items do
		cleanup(item)
		self._items[key] = nil
	end
end

function ConnectionsList.Destroy(self: ConnectionsList)
	self:Clean()
end

-------------------------------------------------------------------------------
-- RETURN
-------------------------------------------------------------------------------

return {
	new = function(connections: { CleanupItem }?): ConnectionsList
		local self = table.clone(ConnectionsList) :: ConnectionsList
		self._items = {}
		self._nextKey = 0

		-- Load connections tbl if exists
		if connections then
			for _, item in next, connections do
				self:Add(item)
			end
		end

		return self
	end,
}
