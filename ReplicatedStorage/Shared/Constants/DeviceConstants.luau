local DeviceConstants = {}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local DEVICE_TYPES = table.freeze({
	Mobile = "Mobile",
	Console = "Console",
	Desktop = "Desktop",
})

local DEVICE_INPUTS = table.freeze({
	[Enum.PreferredInput.Touch] = DEVICE_TYPES.Mobile,
	[Enum.PreferredInput.Gamepad] = DEVICE_TYPES.Console,
	[Enum.PreferredInput.KeyboardAndMouse] = DEVICE_TYPES.Desktop,
})

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type DeviceType = keyof<typeof(DEVICE_TYPES)>

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

DeviceConstants.DeviceTypes = DEVICE_TYPES
DeviceConstants.DeviceInputs = DEVICE_INPUTS

return DeviceConstants
