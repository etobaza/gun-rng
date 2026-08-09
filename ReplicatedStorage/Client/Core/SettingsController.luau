--[[
  SettingsController

  Description:
  Handles the settings on the client

  Author:
  @SixthAtom

  Date:
  10-04-2026
]]

local SettingsController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingConstants = require(ReplicatedStorage.Shared.Constants.SettingConstants)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function SettingsController.getValue(settingName: SettingConstants.SettingName)
	return SettingConstants.getDefaultValue(settingName, "Computer")
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function SettingsController.init() end

-- function SettingsController.start() end

-- function SettingsController.test() end

return SettingsController
