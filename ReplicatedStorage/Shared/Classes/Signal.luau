local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArrayUtil = require(ReplicatedStorage.Shared.Utils.ArrayUtil)
--[[
  Signal

  Description:
  Typechecked and lightweight signal class.

  Author:
  @SixthAtom
]]

local Signal = {}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local BEHAVIOUR_TYPES = {
	Serial = "Serial",
	Parallel = "Parallel",
	Deferred = "Deferred",
}

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type Connection<T...> = {
	Index: number,
	Callback: (T...) -> (),
	Disconnect: (connection: Connection<T...>) -> (),
	Destroy: (connection: Connection<T...>) -> (),
	Connected: boolean,
}

export type Signal<T...> = {
	_connections: { Connection<T...> },
	_yields: { thread },
	_fireEvents: (T...) -> (),

	Fire: (self: Signal<T...>, T...) -> (),
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection<T...>,
	Once: (self: Signal<T...>, callback: (T...) -> ()) -> Connection<T...>,
	Wait: (self: Signal<T...>) -> T...,
	Destroy: (self: Signal<T...>) -> (),
}

type BehaviourType = keyof<typeof(BEHAVIOUR_TYPES)>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getFireEventsMethod<T...>(self: Signal<T...>, behaviourType: BehaviourType)
	return if behaviourType == BEHAVIOUR_TYPES.Parallel
		then function(...: T...)
			for _, v in self._connections do
				task.spawn(v.Callback, ...)
			end
		end
		elseif behaviourType == BEHAVIOUR_TYPES.Deferred then function(...: T...)
			for _, v in self._connections do
				task.defer(v.Callback, ...)
			end
		end
		else function(...: T...)
			for _, v in self._connections do
				v.Callback(...)
			end
		end
end

local function resumeAllThreads<T...>(self: Signal<T...>, ...)
	for _, thread in next, self._yields do
		local s, e = coroutine.resume(thread, ...)
		if not s then
			warn(e)
		end
	end
	table.clear(self._yields)
end

local function disconnect<T...>(self: Signal<T...>, connection: Connection<T...>)
	connection.Connected = false
	local swappedConnection = ArrayUtil.swapbackRemove(self._connections, connection.Index)
	swappedConnection.Index = connection.Index
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function Signal.Fire<T...>(self: Signal<T...>, ...: T...)
	resumeAllThreads(self, ...)
	self._fireEvents(...)
end

function Signal.Connect<T...>(self: Signal<T...>, callback: (T...) -> ())
	local connection: Connection<T...> = {
		Index = #self._connections + 1,
		Callback = callback,
		Disconnect = disconnect,
		Destroy = disconnect,
		Connected = true,
	}

	self._connections[connection.Index] = connection
	return connection
end

function Signal.Once<T...>(self: Signal<T...>, callback: (T...) -> ())
	local connection: Connection<T...>

	connection = self:Connect(function(...)
		connection:Disconnect()
		callback(...)
	end)

	return connection
end

function Signal.Wait<T...>(self: Signal<T...>)
	table.insert(self._yields, coroutine.running())
	return coroutine.yield()
end

function Signal.Destroy<T...>(self: Signal<T...>)
	table.clear(self._connections)
	resumeAllThreads(self)
end

-------------------------------------------------------------------------------
-- RETURN
-------------------------------------------------------------------------------

return {
	new = function<T...>(behaviourType: BehaviourType?)
		local self = table.clone(Signal) :: Signal<T...>

		self._connections = {}
		self._yields = {}
		self._fireEvents = getFireEventsMethod(self, behaviourType)

		return self
	end,
}
