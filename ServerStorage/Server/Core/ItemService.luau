--[[
  ItemService

  Description:
  Handles server-side item operations

  Author:
  @SixthAtom

  Date:
  12-03-2026
]]

local ItemService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local EconomyService = require(ServerStorage.Server.Core.EconomyService)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)
local ItemConstants = require(ReplicatedStorage.Shared.Constants.ItemConstants)
local CRC32C = require(ReplicatedStorage.Shared.Hashing.CRC32C)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local ResponseCodes = require(ReplicatedStorage.Shared.Networking.ResponseCodes)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local SimpleRemotesUtil = require(ReplicatedStorage.Shared.Networking.SimpleRemotesUtil)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local OWNERSHIP_MODES = ItemConstants.OwnershipModes
local EVENT_CODES = RemoteCodes.Item.Events
local FUNCTION_CODES = RemoteCodes.Item.Functions

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type ItemEventTask = (player: Player, itemName: string, deltaAmount: number) -> ()
type ItemAcquiredTask = (player: Player, itemName: string) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local playerItemInventories: { [Player]: { [string]: number | true } } = {} -- [string] = itemName, number = itemAmount | boolean = isOwned
local itemRemoteEvent = SimpleRemotes.getEvent("Item")
local itemRemoteFunction = SimpleRemotes.getFunction("Item")

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

ItemService.ItemGrantedTasks = TasksList.new() :: TasksList.TasksList<ItemEventTask>
ItemService.ItemConsumedTasks = TasksList.new() :: TasksList.TasksList<ItemEventTask>
ItemService.ItemAcquiredTasks = TasksList.new() :: TasksList.TasksList<ItemAcquiredTask>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function dispatchAction(
	taskList: TasksList.TasksList<any>,
	eventCode: number,
	player: Player,
	itemName: string,
	amount: number?
)
	local hasAmount = amount ~= nil

	taskList:Execute("parallel", player, itemName, amount)

	local b = buffer.create(1 + 4 + (hasAmount and 4 or 0))
	local offset = 0
	offset = BufferUtil.writeu8(b, offset, eventCode)
	offset = BufferUtil.writeu32(b, offset, CRC32C(buffer.fromstring(itemName)))

	if hasAmount then
		offset = BufferUtil.writeu32(b, offset, amount)
	end

	itemRemoteEvent:FireClient(player, b)
end

local function resolveItemAndInventory(player: Player, itemName: string)
	local itemInventory = playerItemInventories[player]
	if not itemInventory then
		return nil, nil -- RETURN: No inventory
	end

	local item = ItemConstants.getItem(itemName)
	if not item then
		return nil, nil -- RETURN: Unknown item
	end

	return itemInventory, item
end

local function getItemAmountFromInventory(itemInventory: { [string]: number | true }, itemName: string, ownershipMode)
	local value = itemInventory[itemName]
	if ownershipMode == OWNERSHIP_MODES.Permanent then
		return if value == true then 1 else 0
	end

	return if type(value) == "number" then math.max(0, value) else 0
end

local function onProfileAdded(player: Player, data: PlayerDataService.Data, profile: PlayerDataService.Profile)
	-- Encode inventory array before save
	profile.OnSave:Connect(function()
		local itemInventory = playerItemInventories[player]
		if not itemInventory then
			return
		end

		local validItems: { string } = {}
		for itemName, value in next, itemInventory do
			local item = ItemConstants.getItem(itemName)
			if not item then
				continue
			end

			-- Skip invalid/empty consumables
			if item.OwnershipMode == OWNERSHIP_MODES.Consumable then
				if type(value) ~= "number" or value <= 0 then
					continue
				end
			end

			table.insert(validItems, itemName)
		end

		local b, offset = buffer.create(2 + #validItems * 8), 0
		offset = BufferUtil.writeu16(b, offset, #validItems)

		for _, itemName in next, validItems do
			local item = ItemConstants.getItem(itemName)
			if not item then
				continue
			end

			local rawValue = itemInventory[itemName]
			local amount = if item.OwnershipMode == OWNERSHIP_MODES.Permanent then 1 else rawValue :: number

			offset = BufferUtil.writeu32(b, offset, CRC32C(buffer.fromstring(itemName)))
			offset = BufferUtil.writeu32(b, offset, amount)
		end

		data.ItemInventory = b
	end)

	-- Load & decode inventory
	local itemInventory: { [string]: number | true } = {}

	local b, offset, entryAmount = data.ItemInventory, 0, 0
	if buffer.len(b) > 0 then
		entryAmount, offset = BufferUtil.readu16(b, offset)

		for _ = 1, entryAmount do
			local hash, amount
			hash, offset = BufferUtil.readu32(b, offset)
			amount, offset = BufferUtil.readu32(b, offset)

			local item = ItemConstants.getItemFromHash(hash)
			if not item then
				continue
			end

			if item.OwnershipMode == OWNERSHIP_MODES.Permanent then
				if amount > 0 then
					itemInventory[item.Name] = true
				end
			elseif item.OwnershipMode == OWNERSHIP_MODES.Consumable then
				if amount > 0 then
					itemInventory[item.Name] = amount
				end
			end
		end
	end

	-- Reconcile default unlocked items
	for itemName, item in ItemConstants.getAllItems() do
		if item.DefaultUnlocked and item.OwnershipMode == OWNERSHIP_MODES.Permanent then
			if itemInventory[itemName] ~= true then
				itemInventory[itemName] = true
			end

			-- Optional: auto-equip default item only if slot is currently empty
			local slot = item.EquipmentSlot
			if slot and data.EquippedItems[slot] == nil then
				data.EquippedItems[slot] = itemName
			end
		end
	end

	playerItemInventories[player] = itemInventory
end

local function onProfileRemoved(player: Player)
	playerItemInventories[player] = nil
end

local function loadItemRemotes()
	SimpleRemotesUtil.bindRemoteEventActions(itemRemoteEvent, {
		[EVENT_CODES.Purchase] = function(player: Player, b: buffer)
			local hash, _offset = BufferUtil.readu32(b, 0)

			local item = ItemConstants.getItemFromHash(hash)
			if not item then
				return
			end -- No item found

			ItemService.purchaseItem(player, item.Name)
		end,
	}, SimpleRemotesUtil.DecodeActionBuffer)

	SimpleRemotesUtil.bindRemoteFunctionActions(itemRemoteFunction, {
		[FUNCTION_CODES.Get] = function(player: Player)
			return playerItemInventories[player]
		end,
	}, SimpleRemotesUtil.DecodeActionBuffer)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ItemService.hasItem(player: Player, itemName: string)
	local inventory, item = resolveItemAndInventory(player, itemName)
	if not inventory or not item then
		return false
	end

	return getItemAmountFromInventory(inventory, itemName, item.OwnershipMode) > 0
end

function ItemService.getAmount(player: Player, itemName: string): number
	local inventory, item = resolveItemAndInventory(player, itemName)
	if not inventory or not item then
		return 0
	end

	return getItemAmountFromInventory(inventory, itemName, item.OwnershipMode)
end

function ItemService.grantItem(player: Player, itemName: string, amount: number?): boolean
	local inventory, item = resolveItemAndInventory(player, itemName)
	if not inventory or not item then
		return false -- RETURN: Invalid context
	end

	if item.OwnershipMode == OWNERSHIP_MODES.Permanent then
		if inventory[itemName] == true then
			return false -- RETURN: Already owned
		end

		inventory[itemName] = true
		dispatchAction(ItemService.ItemAcquiredTasks, EVENT_CODES.Acquired, player, itemName)
		return true
	end

	local addAmount = math.max(1, amount or 1)
	local currentAmount = getItemAmountFromInventory(inventory, itemName, item.OwnershipMode)
	inventory[itemName] = currentAmount + addAmount
	dispatchAction(ItemService.ItemGrantedTasks, EVENT_CODES.Granted, player, itemName, addAmount)

	return true
end

function ItemService.consumeItem(player: Player, itemName: string, amount: number?): boolean
	local inventory, item = resolveItemAndInventory(player, itemName)
	if not inventory or not item then
		return false -- RETURN: Invalid context
	end

	if item.OwnershipMode == OWNERSHIP_MODES.Permanent then
		return false -- RETURN: Non-consumable
	end

	local takeAmount = math.max(1, amount or 1)
	local currentAmount = getItemAmountFromInventory(inventory, itemName, item.OwnershipMode)
	if currentAmount < takeAmount then
		return false -- RETURN: Not enough
	end

	local nextAmount = currentAmount - takeAmount
	inventory[itemName] = if nextAmount > 0 then nextAmount else nil
	dispatchAction(ItemService.ItemConsumedTasks, EVENT_CODES.Consumed, player, itemName, takeAmount)

	return true
end

function ItemService.purchaseItem(player: Player, itemName: string): number
	local inventory, item = resolveItemAndInventory(player, itemName)
	if not inventory or not item then
		return ResponseCodes.ServiceUnavailable -- RETURN: Not ready
	end

	local currentAmount = getItemAmountFromInventory(inventory, itemName, item.OwnershipMode)
	if item.OwnershipMode == OWNERSHIP_MODES.Permanent and currentAmount > 0 then
		return ResponseCodes.Conflict -- RETURN: Already owned
	end

	local priceAmount = item.Price.Amount or 0
	if not EconomyService.transact(player, item.Price.Currency, -priceAmount) then
		return ResponseCodes.UnprocessableEntity -- RETURN: Can't afford
	end

	ItemService.grantItem(player, itemName, 1)
	return ResponseCodes.Ok
end

function ItemService.getInventory(player: Player)
	return playerItemInventories[player]
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function ItemService.init()
	PlayerDataService.ProfileAddedTasks:Add(onProfileAdded)
	PlayerDataService.ProfileRemovedTasks:Add(onProfileRemoved)

	loadItemRemotes()
end

-- function ItemService.start() end

-- function ItemService.test() end

return ItemService
