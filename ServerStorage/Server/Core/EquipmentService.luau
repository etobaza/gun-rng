--[[
  EquipmentService

  Description:
  Handles equipment state and actions

  Author:
  @SixthAtom

  Date:
  13-03-2026
]]

local EquipmentService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local ItemService = require(ServerStorage.Server.Core.ItemService)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)
local EquipmentConstants = require(ReplicatedStorage.Shared.Constants.EquipmentConstants)
local ItemConstants = require(ReplicatedStorage.Shared.Constants.ItemConstants)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local SimpleRemotesUtil = require(ReplicatedStorage.Shared.Networking.SimpleRemotesUtil)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local EQUIPMENT_SLOTS = EquipmentConstants.Slots
local EVENT_CODES = RemoteCodes.Equipment.Events

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type Slot = EquipmentConstants.Slot
type EquipmentTask = (player: Player, slot: Slot, itemName: string) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local remoteEvent = SimpleRemotes.getEvent("Equipment")

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

EquipmentService.ItemEquippedTasks = TasksList.new() :: TasksList.Id<EquipmentTask>
EquipmentService.ItemUnequippedTasks = TasksList.new() :: TasksList.Id<EquipmentTask>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function loadEquipmentRemotes()
	SimpleRemotesUtil.bindRemoteEventActions(remoteEvent, {
		[EVENT_CODES.Equip] = function(player: Player, b: buffer)
			local hash, _offset = BufferUtil.readu32(b, 0)

			local item = ItemConstants.getItemFromHash(hash)
			if not item then
				return
			end

			EquipmentService.equipItem(player, item.Name)
		end,
	}, SimpleRemotesUtil.DecodeActionBuffer)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function EquipmentService.getEquippedItemName(player: Player, slot: Slot): string?
	local data = PlayerDataService.get(player)
	if data then
		return data.EquippedItems[slot]
	end
	return nil
end

function EquipmentService.isEquipped(player: Player, itemName: string)
	local item = ItemConstants.getItem(itemName)
	if not (item and item.EquipmentSlot) then
		return false
	end

	return EquipmentService.getEquippedItemName(player, item.EquipmentSlot) == itemName
end

function EquipmentService.unequipSlot(player: Player, slot: Slot)
	local data = PlayerDataService.get(player)
	if not data then
		return false -- RETURN: No data available
	end

	local equippedItemName = EquipmentService.getEquippedItemName(player, slot)
	if not equippedItemName then
		return false -- RETURN: Nothing's equipped
	end

	data.EquippedItems[slot] = nil
	EquipmentService.ItemUnequippedTasks:Execute("parallel", player, slot, equippedItemName)

	return true
end

function EquipmentService.equipItem(player: Player, itemName: string): boolean
	if not ItemService.hasItem(player, itemName) then
		return false -- RETURN: Item isn't owned
	end

	local item = ItemConstants.getItem(itemName)
	if not item then
		return false -- RETURN: Invalid item
	end

	local slot = item.EquipmentSlot
	if not slot then
		return false -- RETURN: Item is not equipable
	end

	if EQUIPMENT_SLOTS[slot] ~= slot then
		return false -- RETURN: Invalid equipment slot
	end

	if EquipmentService.getEquippedItemName(player, slot) == itemName then
		return false -- RETURN: Already equipped
	end

	local data = PlayerDataService.get(player)
	if not data then
		return false -- RETURN: No player data available
	end

	local previousItemName = data.EquippedItems[slot]
	if previousItemName then
		data.EquippedItems[slot] = nil
		EquipmentService.ItemUnequippedTasks:Execute("parallel", player, slot, previousItemName)
	end

	data.EquippedItems[slot] = itemName
	EquipmentService.ItemEquippedTasks:Execute("parallel", player, slot, itemName)

	return true
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function EquipmentService.init()
	loadEquipmentRemotes()

	ItemService.ItemAcquiredTasks:Add(function(player, itemName)
		local item = ItemConstants.getItem(itemName)
		if item and item.EquipmentSlot then
			EquipmentService.equipItem(player, itemName)
		end
	end)
end

function EquipmentService.start() end

function EquipmentService.test() end

return EquipmentService
