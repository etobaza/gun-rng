local EquipmentConstants = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GeneralUtil = require(ReplicatedStorage.Shared.Utils.GeneralUtil)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type Slot = keyof<typeof(EquipmentConstants.Slots)>

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

EquipmentConstants.Slots = GeneralUtil.deepFreeze({
	Gun = "Gun",
})

return EquipmentConstants
