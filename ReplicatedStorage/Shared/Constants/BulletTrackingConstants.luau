local BulletTrackingConstants = {}

const ReplicatedStorage = game:GetService("ReplicatedStorage")

const WeaponConstants = require(ReplicatedStorage.Shared.Constants.WeaponConstants)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

const CALIBERS = WeaponConstants.Calibers

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

BulletTrackingConstants.OwnerTypes = table.freeze({
	Player = 0,
	NPC = 1,
	Other = 2,
})

BulletTrackingConstants.TracerPixelWidths = table.freeze({
	[CALIBERS["9mm"]] = 2.2,
	[CALIBERS[".45 ACP"]] = 2.8,
	[CALIBERS["12g"]] = 1.6, -- One buckshot pellet, not the full shell diameter
	[CALIBERS["5.56x45mm"]] = 3.2,
	[CALIBERS["7.62x39mm"]] = 4,
	[CALIBERS[".50 AE"]] = 5.4,
   [CALIBERS["7.62x51mm NATO"]] = 4.6,
})

BulletTrackingConstants.BulletHoleScales = table.freeze({
	[CALIBERS["9mm"]] = 0.9,
	[CALIBERS[".45 ACP"]] = 1.2, 
	[CALIBERS["12g"]] = 0.75,
	[CALIBERS["5.56x45mm"]] = 0.62,
	[CALIBERS["7.62x39mm"]] = 0.85,
	[CALIBERS[".50 AE"]] = 1.7,
   [CALIBERS["7.62x51mm NATO"]] = 1.3,
})

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function BulletTrackingConstants.getOwnerTypeKey(value: number)
	for i, v in next, BulletTrackingConstants.OwnerTypes do
		if v == value then
			return i
		end
	end
	return nil
end

function BulletTrackingConstants.getTracerPixelWidth(caliber: number): number
	return BulletTrackingConstants.TracerPixelWidths[caliber] or 4
end

function BulletTrackingConstants.getBulletHoleScale(caliber: number): number
	return BulletTrackingConstants.BulletHoleScales[caliber] or 1
end

return BulletTrackingConstants
