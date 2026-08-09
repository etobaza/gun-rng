--[[
	TasksList

	A lightweight, object-oriented T list with efficient memory usage.
	Preferred over Signal-like modules whenever memory efficiency is wanted.
]]

local TasksList = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArrayUtil = require(ReplicatedStorage.Shared.Utils.ArrayUtil)
local TaskUtil = require(ReplicatedStorage.Shared.Utils.TaskUtil)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type DisconnectFunction = () -> ()

export type TasksList<T> = {
	_tasks: { T },

	Add: (self: TasksList<T>, T: T) -> DisconnectFunction,
	Execute: (self: TasksList<T>, mode: TaskUtil.ExecutionMode, ...any) -> (),
}

export type Id<T> = TasksList<T>

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function TasksList.Add<T>(self: TasksList<T>, T: T)
	table.insert(self._tasks, T)

	return function()
		local index = table.find(self._tasks, T)
		if index then
			ArrayUtil.swapbackRemove(self._tasks, index)
		end
	end
end

function TasksList.Execute<T>(self: TasksList<T>, mode: TaskUtil.ExecutionMode, ...)
	return TaskUtil.execute(self._tasks, mode, ...)
end

-------------------------------------------------------------------------------
-- RETURN
-------------------------------------------------------------------------------

return {
	new = function<T>()
		local self = table.clone(TasksList) :: TasksList<T>
		self._tasks = {}
		return self
	end,
}
