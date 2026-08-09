local InputConstants = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

InputConstants.Actions = table.freeze({
	Sprint = "Sprint",
	Shoot = "Shoot",
	Reload = "Reload",
	Aim = "Aim",
})

InputConstants.DebugActions = table.freeze({
	ToggleMouseUnlock = "ToggleMouseUnlock",
})

return InputConstants
