local SettingConstants = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DeviceConstants = require(ReplicatedStorage.Shared.Constants.DeviceConstants)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local SETTING_TYPES = table.freeze({
	Toggle = "Toggle",
})

local SETTING_NAMES = table.freeze({
	RenderReplicatedCasings = "RenderReplicatedCasings",
})

local DEVICE_TYPES = DeviceConstants.DeviceTypes

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type SettingType = keyof<typeof(SETTING_TYPES)>
export type SettingName = keyof<typeof(SETTING_NAMES)>

type Setting = { DisplayName: string } & {
	Type: "Toggle",
	DefaultValues: { [DeviceConstants.DeviceType]: boolean },
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local settings: { [SettingName]: Setting } = {
	[SETTING_NAMES.RenderReplicatedCasings] = {
		DisplayName = "Render Replicated Casings",
		Type = SETTING_TYPES.Toggle,
		DefaultValues = { [DEVICE_TYPES.Mobile] = false, [DEVICE_TYPES.Console] = true, [DEVICE_TYPES.Desktop] = true },
	},
}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

SettingConstants.Settings = settings

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function SettingConstants.getDefaultValue(settingName: SettingName, deviceType: DeviceConstants.DeviceType)
	return settings[settingName].DefaultValues[deviceType]
end

return SettingConstants
