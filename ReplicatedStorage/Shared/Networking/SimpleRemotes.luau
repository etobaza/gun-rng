--!strict

local SimpleRemotes = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InstanceUtil = require(ReplicatedStorage.Shared.Utils.InstanceUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local IS_SERVER = RunService:IsServer()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local communicationFolder: Folder
local unreliableFolder: Folder
local eventFolder: Folder
local functionFolder: Folder

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getOrCreateInstance(name: string, class: string, parent: Instance)
	if not IS_SERVER then
		return parent:WaitForChild(name)
	end

	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end

	local remote = Instance.new(class)
	remote.Name = name
	remote.Parent = parent
	return remote
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

--- Creates or gets an UnreliableRemoteEvent
function SimpleRemotes.getUnreliableEvent(name: string, parent: Instance?)
	return getOrCreateInstance(name, "UnreliableRemoteEvent", parent or unreliableFolder) :: UnreliableRemoteEvent
end

--- Creates or gets a RemoteEvent
function SimpleRemotes.getEvent(name: string, parent: Instance?)
	return getOrCreateInstance(name, "RemoteEvent", parent or eventFolder) :: RemoteEvent
end

--- Creates or gets a RemoteFunction
function SimpleRemotes.getFunction(name: string, parent: Instance?)
	return getOrCreateInstance(name, "RemoteFunction", parent or functionFolder) :: RemoteFunction
end

-------------------------------------------------------------------------------
-- LOGIC
-------------------------------------------------------------------------------

if IS_SERVER then
	communicationFolder = InstanceUtil.newNameParent("Folder", "__SIMPLEREMOTES", ReplicatedStorage) :: Folder
	unreliableFolder = InstanceUtil.newNameParent("Folder", "UnreliableEvents", communicationFolder) :: Folder
	eventFolder = InstanceUtil.newNameParent("Folder", "Events", communicationFolder) :: Folder
	functionFolder = InstanceUtil.newNameParent("Folder", "Functions", communicationFolder) :: Folder
else
	communicationFolder = ReplicatedStorage:WaitForChild("__SIMPLEREMOTES") :: Folder
	unreliableFolder = communicationFolder:WaitForChild("UnreliableEvents") :: Folder
	eventFolder = communicationFolder:WaitForChild("Events") :: Folder
	functionFolder = communicationFolder:WaitForChild("Functions") :: Folder
end

return SimpleRemotes
