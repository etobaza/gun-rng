local TaskUtil = {}

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type ExecutionMode = "serial" | "parallel" | "deferred"

type Tasks = { (any) -> any }

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function TaskUtil.serial(tasks: Tasks, ...)
	for _, t in next, tasks do
		t(...)
	end
end

function TaskUtil.parallel(tasks: Tasks, ...)
	for _, t in next, tasks do
		task.spawn(t, ...)
	end
end

function TaskUtil.deferred(tasks: Tasks, ...)
	for _, t in next, tasks do
		task.defer(t, ...)
	end
end

function TaskUtil.execute(tasks: Tasks, mode: ExecutionMode, ...)
	if mode == "serial" then
		return TaskUtil.serial(tasks, ...)
	elseif mode == "parallel" then
		return TaskUtil.parallel(tasks, ...)
	elseif mode == "deferred" then
		return TaskUtil.deferred(tasks, ...)
	else
		error(`Invalid TaskUtil execution mode: "{mode}"`, 2)
	end
end

return TaskUtil
