local WeaponConstants = {}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local GUN_ACTIONS = table.freeze({
	Pump = "Pump",
	Bolt = "Bolt",
	Single = "Single",
})

local GUN_FIREMODES = table.freeze({
	Semi = "Semi",
	Auto = "Auto",
})

-- Stable network IDs. Append new calibres; don't renumber existing entries.
local GUN_CALIBERS = table.freeze({
	["9mm"] = 0,
	[".45 ACP"] = 1,
	["12g"] = 2,
	["5.56x45mm"] = 3,
	["7.62x39mm"] = 4,
	[".50 AE"] = 5,
	["7.62x51mm NATO"] = 6,
})

local GUN_CALIBER_NAMES = table.freeze({
	[GUN_CALIBERS["9mm"]] = "9mm",
	[GUN_CALIBERS[".45 ACP"]] = ".45 ACP",
	[GUN_CALIBERS["12g"]] = "12g",
	[GUN_CALIBERS["5.56x45mm"]] = "5.56x45mm",
	[GUN_CALIBERS["7.62x39mm"]] = "7.62x39mm",
	[GUN_CALIBERS[".50 AE"]] = ".50 AE",
	[GUN_CALIBERS["7.62x51mm NATO"]] = "7.62x51mm NATO",
})

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

WeaponConstants.GunActions = GUN_ACTIONS
WeaponConstants.GunFiremodes = GUN_FIREMODES
WeaponConstants.Calibers = GUN_CALIBERS
WeaponConstants.CaliberNames = GUN_CALIBER_NAMES

return WeaponConstants
