--[[
  EquipmentController

  Description:
  Handles client equipped-item state using replicated PlayerData

  Author:
  @SixthAtom

  Date:
  09-05-2026
]]

local EquipmentController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataController = require(ReplicatedStorage.Client.Core.PlayerDataController)
local Signal = require(ReplicatedStorage.Shared.Classes.Signal)
local EquipmentConstants = require(ReplicatedStorage.Shared.Constants.EquipmentConstants)
local ItemConstants = require(ReplicatedStorage.Shared.Constants.ItemConstants)
local CRC32C = require(ReplicatedStorage.Shared.Hashing.CRC32C)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local ResponseCodes = require(ReplicatedStorage.Shared.Networking.ResponseCodes)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local EVENT_CODES = RemoteCodes.Equipment.Events

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type Slot = EquipmentConstants.Slot

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

const equippedItems: { [Slot]: string } = {}

local remoteEvent = SimpleRemotes.getEvent("Equipment")

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

EquipmentController.EquippedChanged = Signal.new("Parallel") :: Signal.Signal<Slot, string?, string?>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function EquipmentController.getEquippedItemName(slot: Slot): string?
   return equippedItems[slot]
end

function EquipmentController.getEquippedItems(): { [Slot]: string? }
	return table.clone(equippedItems)
end

function EquipmentController.isEquipped(itemName: string): boolean
   const item = ItemConstants.getItem(itemName)
   if not (item and item.EquipmentSlot) then return false end

   return equippedItems[item.EquipmentSlot] == itemName
end

--- Calls back immediately with current value, then on future changes.
function EquipmentController.onSlotChanged(slot: Slot, callback: (string?, string?) -> ()): RBXScriptConnection
	callback(equippedItems[slot], nil)

	return EquipmentController.EquippedChanged:Connect(function(changedSlot, newItemName, previousItemName)
		if changedSlot == slot then
			callback(newItemName, previousItemName)
		end
	end)
end

function EquipmentController.requestEquip(itemName: string): number
	local item = ItemConstants.getItem(itemName)
	if not item then
		return ResponseCodes.NotFound
	end

	if not item.EquipmentSlot then
		return ResponseCodes.Forbidden
	end

	local b = buffer.create(1 + 4)
	local offset = BufferUtil.writeu8(b, 0, EVENT_CODES.Equip)
	BufferUtil.writeu32(b, offset, CRC32C(buffer.fromstring(item.Name)))

	remoteEvent:FireServer(b)
	return ResponseCodes.Sent
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function EquipmentController.init()
   PlayerDataController.getAsync(function(data)
      for slot, itemName in data.EquippedItems do
         equippedItems[slot] = itemName
      end
   end)
   
   PlayerDataController.UpdatedTasks:Add(function(index: number | string, value, path: {number | string})
      if path[1] == "EquippedItems" then
         const slot = index :: Slot

         const previousItemName = equippedItems[slot]
         equippedItems[slot] = value

         EquipmentController.EquippedChanged:Fire(slot, value, previousItemName)
      end
   end)
end

-- function EquipmentController.start() end

-- function EquipmentController.test() end

return EquipmentController