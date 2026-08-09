local ItemConstants = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyConstants = require(ReplicatedStorage.Shared.Constants.EconomyConstants)
local EquipmentConstants = require(ReplicatedStorage.Shared.Constants.EquipmentConstants)
local CRC32C = require(ReplicatedStorage.Shared.Hashing.CRC32C)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local CURRENCIES = EconomyConstants.Currencies
local EQUIPMENT_SLOTS = EquipmentConstants.Slots

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type ItemId = string
export type Category = keyof<typeof(ItemConstants.Categories)>
export type OwnershipMode = keyof<typeof(ItemConstants.OwnershipModes)>

export type ItemBase = {
	Name: string,
	DisplayName: string,
	Category: Category,
	OwnershipMode: OwnershipMode,
	Price: EconomyConstants.Price,
	EquipmentSlot: EquipmentConstants.Slot?,
	DefaultUnlocked: boolean?,

	Description: string?,
	Icon: string?,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local categories = {
	Car = "Car",
	Skin = "Skin",
	Cosmetic = "Cosmetic",
	Gun = "Gun",
}

local ownershipModes = {
	Permanent = "Permanent",
	Consumable = "Consumable",
}

local itemsByCategory: { [Category]: { [string]: ItemBase } } = {}
local itemsByHash: { [number]: ItemBase } = {}
local itemsToHash: { [string]: number } = {}

local itemsByName: { [string]: ItemBase } = {
	-- Cars
	Test = {
		Name = "Test",
		DisplayName = "Test Car",
		Category = categories.Car,
		OwnershipMode = ownershipModes.Permanent,
		Price = { Currency = CURRENCIES.Free },
		Description = "Placeholder car for spawn and handling tests.",
	},

	Lada = {
		Name = "Lada",
		DisplayName = "Lada",
		Category = categories.Car,
		OwnershipMode = ownershipModes.Permanent,
		Price = { Currency = CURRENCIES.Free },
		Description = "Soviet sedan: slow, loud, oddly dependable.",
	},

	-- Guns
	["M1911"] = {
		Name = "M1911",
		DisplayName = "M1911",
		Category = categories.Gun,
		EquipmentSlot = EQUIPMENT_SLOTS.Gun,
		OwnershipMode = ownershipModes.Permanent,
		Price = { Currency = CURRENCIES.Free },
		DefaultUnlocked = true,
		Description = "Classic .45 starter pistol, free forever.",
	},

	["AK-103"] = {
		Name = "AK-103",
		DisplayName = "AK-103",
		Category = categories.Gun,
		EquipmentSlot = EQUIPMENT_SLOTS.Gun,
		OwnershipMode = ownershipModes.Permanent,
		Price = { Currency = CURRENCIES.Cash, Amount = 10_000 },
		Description = "Tactical AK",
	},

	["SPAS-12"] = {
		Name = "SPAS-12",
		DisplayName = "SPAS-12",
		Category = categories.Gun,
		EquipmentSlot = EQUIPMENT_SLOTS.Gun,
		OwnershipMode = ownershipModes.Permanent,
		Price = { Currency = CURRENCIES.Cash, Amount = 25_000 },
		Description = "Heavy pump shotgun for close-range work.",
	},

   ["M249"] = {
      Name = "M249",
      DisplayName = "M249 SAW",
      Category = categories.Gun,
      EquipmentSlot = EQUIPMENT_SLOTS.Gun,
      OwnershipMode = ownershipModes.Permanent,
      Price = { Currency = CURRENCIES.Cash, Amount = 10_000 },
      Description = "One heck of an LMG.",
   },

   ["Desert Eagle .50"] = {
      Name = "Desert Eagle .50",
      DisplayName = "Deagle",
      Category = categories.Gun,
      EquipmentSlot = EQUIPMENT_SLOTS.Gun,
      OwnershipMode = ownershipModes.Permanent,
      Price = { Currency = CURRENCIES.Cash, Amount = 10_000 },
      Description = "Packs quite the punch.",
   },

   ["M24"] = {
      Name = "M24",
      Displayname = "M24",
      Category = categories.Gun,
      EquipmentSlot = EQUIPMENT_SLOTS.Gun,
      OwnershipMode = ownershipModes.Permanent,
      Price = { Currency = CURRENCIES.Cash, Amount = 10_000 },
      Description = "Who said you had to get close?",
   }
}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

ItemConstants.Categories = categories
ItemConstants.OwnershipModes = ownershipModes

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ItemConstants.getItem(itemName: string)
	return itemsByName[itemName]
end

function ItemConstants.getItemFromHash(hash: number)
	return itemsByHash[hash]
end

function ItemConstants.getItemHash(itemName: string)
	return itemsToHash[itemName] or CRC32C(buffer.fromstring(itemName))
end

function ItemConstants.getItemsInCategory(category: Category)
	return itemsByCategory[category]
end

function ItemConstants.getAllItems()
	return itemsByName
end

-------------------------------------------------------------------------------
-- LOGIC
-------------------------------------------------------------------------------

for itemName, item in itemsByName do
	local bucket = itemsByCategory[item.Category]
	if not bucket then
		bucket = {}
		itemsByCategory[item.Category] = bucket
	end

	local hash = CRC32C(buffer.fromstring(itemName))
	if itemsByHash[hash] then
		error(`Duplicate hash {hash} on {itemName} & {itemsByHash[hash].Name}`)
	end

	itemsByHash[hash] = item
	itemsToHash[itemName] = hash
	bucket[itemName] = item
end

return ItemConstants
