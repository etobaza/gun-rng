local DeviceUtil = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local DeviceConstants = require(ReplicatedStorage.Shared.Constants.DeviceConstants)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local DEVICE_TYPES = DeviceConstants.DeviceTypes
local DEVICE_INPUTS = DeviceConstants.DeviceInputs

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function DeviceUtil.getDevice(): DeviceConstants.DeviceType
	return DEVICE_INPUTS[UserInputService.PreferredInput] or DEVICE_TYPES.Desktop
end

function DeviceUtil.isMobile(): boolean
	return DeviceUtil.getDevice() == DEVICE_TYPES.Mobile
end

function DeviceUtil.onDeviceChanged(callback: (device: DeviceConstants.DeviceType) -> ()): RBXScriptConnection
	callback(DeviceUtil.getDevice())
	return UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
		callback(DeviceUtil.getDevice())
	end)
end

return DeviceUtil
