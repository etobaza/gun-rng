local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
--[[
  ObjectPool

  Description:
  Class for pooling objects

  Author:
  @SixthAtom
]]

local ObjectPool = {}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type Id = number

export type ObjectPool<T = Instance> = {
	_destroying: true?,
	_folder: Folder,
	_object: T,
	_pool: { [Id]: T },
	_reversePool: { [T]: Id },
	_available: { [number]: Id },
	_connections: { [Id]: RBXScriptConnection },

	GetAmount: () -> number,
	Draw: (self: ObjectPool<T>, parent: Instance?, beforeParent: ((instance: T) -> ())?) -> T,
	Return: (self: ObjectPool<T>, object: T) -> (),
	Destroy: (self: ObjectPool<T>) -> (),
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local mainPoolFolder = Instance.new("Folder")
mainPoolFolder.Parent = RunService:IsServer() and ServerStorage or ReplicatedStorage
mainPoolFolder.Name = "__OBJECT_POOLS"

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function createAdditional<T>(self: ObjectPool<T>, index: number?)
	index = index or #self._pool + 1

	local object = self._object:Clone()
	object.Parent = self._folder

	self._pool[index] = object
	self._reversePool[object] = index

	table.insert(self._available, index)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ObjectPool.GetAmount<T>(self: ObjectPool<T>)
	return #self._pool
end

function ObjectPool.Draw<T>(self: ObjectPool<T>, parent: Instance?, beforeParent: ((instance: T) -> ())?)
	if #self._available == 0 then
		createAdditional(self)
	end

	local index = table.remove(self._available)
	local object: Instance = self._pool[index]
	if parent then
		if beforeParent then
			beforeParent(object)
		end
		object.Parent = parent
	end

	-- Handle connection
	local oldConnection = self._connections[index]
	if oldConnection then
		oldConnection:Disconnect()
	end

	self._connections[index] = object.Destroying:Connect(function()
		if self._pool[index] ~= object then
			return
		end

		self._reversePool[object] = nil

		local connection = self._connections[index]
		if connection then
			connection:Disconnect()
			self._connections[index] = nil
		end

		local replacement = self._object:Clone()
		replacement.Parent = self._folder

		self._pool[index] = replacement
		self._reversePool[replacement] = index
		table.insert(self._available, index)
	end)

	return object
end

function ObjectPool.Return<T>(self: ObjectPool<T>, object: T)
	local index = self._reversePool[object]
	if not index then
		return -- RETURN: Object does not belong to this pool
	end

	if table.find(self._available, index) then
		return -- RETURN: Object was returned twice
	end

	local connection = self._connections[index]
	if connection then
		connection:Disconnect()
		self._connections[index] = nil
	end

	object.Parent = self._folder
	table.insert(self._available, index)
end

function ObjectPool.Destroy<T>(self: ObjectPool<T>)
	self._destroying = true

	for _, v in next, self._connections do
		if v.Connected then
			v:Disconnect()
		end
	end

	for _, v in next, self._pool do
		if v then
			v:Destroy()
		end
	end

	self._folder:Destroy()
	table.clear(self)
end

-------------------------------------------------------------------------------
-- RETURN
-------------------------------------------------------------------------------

return {
	new = function<T>(object: T, amount: number, folderName: string, debug: boolean?)
		local self = table.clone(ObjectPool) :: ObjectPool<T>

		-------------------------------------------------------------------------------
		-- PRIVATE VARIABLES
		-------------------------------------------------------------------------------

		local beforeKB = if RunService:IsStudio() and debug then gcinfo() else nil

		local folder = Instance.new("Folder")

		-------------------------------------------------------------------------------
		-- PUBLIC VARIABLES
		-------------------------------------------------------------------------------

		self._folder = folder
		self._object = object
		self._pool = {}
		self._reversePool = {}
		self._available = {}
		self._connections = {}

		-------------------------------------------------------------------------------
		-- LOGIC
		-------------------------------------------------------------------------------

		for i = 1, amount do
			createAdditional(self, i)
		end

		if beforeKB then
			local usedKB = gcinfo() - beforeKB
			print(string.format("[ObjectPool] %s (%d objects) used about %.2f KB", folderName, amount, usedKB))
		end

		folder.Name = `POOL.{folderName}`
		folder.Parent = mainPoolFolder

		return self
	end,
}
