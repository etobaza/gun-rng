--[[
	These I use in remotes so they're easily bufferized
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GeneralUtil = require(ReplicatedStorage.Shared.Utils.GeneralUtil)

export type Code = number

local RemoteCodes = GeneralUtil.deepFreeze({
	Tycoon = {
		Functions = {
			Purchase = 0,
		},
	},

	Dropper = {
		Events = {
			BatchCreated = 0,
		},
	},

	LoadingZones = {
		Events = {
			PromptVisibilityChanged = 0,
		},

		Functions = {
			LoadVehicle = 0,
		},
	},

	Guns = {
		Functions = {
			GetRC = 0,
		},

		Events = {
			Reload = 0,
			Shoot = 1,
			Damage = 2,

			NotifyKill = 254,
			CastTracers = 255,
		},
	},

	Instances = {
		Events = {
			SendAll = 0,
			Update = 1,
		},
	},

	Delivery = {
		Events = {
			DeliveryCompleted = 0,
		},
	},

	SpawnPad = {
		Functions = {
			SpawnCar = 0,
		},
	},

	Equipment = {
		Events = {
			Equip = 0,
		},
	},

	Item = {
		Events = {
			Granted = 0,
			Consumed = 1,
			Acquired = 2,
			Purchase = 3,
		},

		Functions = {
			Get = 0,
		},
	},

	Character = {
		Unreliable = {
			SetTargetsBulk = 0,
		},
	},
})

return RemoteCodes
