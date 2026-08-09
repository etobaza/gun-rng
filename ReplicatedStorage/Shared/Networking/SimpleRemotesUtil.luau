local SimpleRemotesUtil = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)
-- local Promise = require(ReplicatedStorage.Shared.Promise)

local IS_SERVER = RunService:IsServer()

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type Action = string | number
type Actions = { [Action]: (...any) -> ...any }
type Deserializer = (...any) -> (Action, ...any)

type FunctionActions = {
	[Action]: (...any) -> ...any,
}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function ActionsExecutor(actions: FunctionActions | Actions, action: Action, ...)
	action = tostring(action)

	local handler = actions[action] or actions[tonumber(action)]
	if handler then
		return handler(...)
	else
		error(`Action {action} was not present in actions list.`)
	end
end

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

SimpleRemotesUtil.DecodeActionBuffer = @native function(raw: any, ...: any): (number, ...any)
	local b = raw :: buffer
	local remoteCode, offset = BufferUtil.readu8(b, 0)
	return remoteCode, select(1, BufferUtil.deallocate(b, 0, offset)), ...
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function SimpleRemotesUtil.bindRemoteFunctionActions(remote: RemoteFunction, actions: Actions, deserializer: Deserializer?)
	if IS_SERVER then
		remote.OnServerInvoke = function(player: Player, ...)
			local action: Action?
			local args = { ... }

			if deserializer then
				local deserialized = { deserializer(...) }
				action = deserialized[1]
				args = { unpack(deserialized, 2) }
			else
				action = args[1]
				table.remove(args, 1)
			end

			return ActionsExecutor(actions, action, player, unpack(args))
		end
	else
		remote.OnClientInvoke = function(...)
			local action: Action?
			local args = { ... }

			if deserializer then
				local deserialized = { deserializer(...) }
				action = deserialized[1]
				args = { unpack(deserialized, 2) }
			else
				action = args[1]
				table.remove(args, 1)
			end

			return ActionsExecutor(actions, action, unpack(args))
		end
	end
end

function SimpleRemotesUtil.bindRemoteEventActions(remote: RemoteEvent, actions: Actions, deserializer: Deserializer?)
	if IS_SERVER then
		return remote.OnServerEvent:Connect(function(player: Player, ...)
			local action: Action?
			local args = { ... }

			if deserializer then
				local deserialized = { deserializer(...) }
				action = deserialized[1]
				args = { unpack(deserialized, 2) }
			else
				action = args[1]
				table.remove(args, 1)
			end

			ActionsExecutor(actions, action, player, unpack(args))
		end)
	else
		return remote.OnClientEvent:Connect(function(...)
			local action: Action?
			local args = { ... }

			if deserializer then
				local deserialized = { deserializer(...) }
				action = deserialized[1]
				args = { unpack(deserialized, 2) }
			else
				action = args[1]
				table.remove(args, 1)
			end

			ActionsExecutor(actions, action, unpack(args))
		end)
	end
end

function SimpleRemotesUtil.fireAllClientsExcept(remote: RemoteEvent, except: Player, ...)
	for _, player in next, Players:GetPlayers() do
		if player ~= except then
			remote:FireClient(player, ...)
		end
	end
end

-------------------------------------------------------------------------------
-- LOGIC
-------------------------------------------------------------------------------

return SimpleRemotesUtil
