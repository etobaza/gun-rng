--[[
  ItemController

  Description:
  Handles client item updates

  Author:
  @SixthAtom

  Date:
  12-03-2026
]]

local ItemController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
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

type ItemEventTask = (itemName: string, deltaAmount: number) -> ()
type ItemAcquiredTask = (itemName: string) -> ()
type InventoryLoadedTask = (inventory: { [string]: number | true }) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local itemRemoteEvent = SimpleRemotes.getEvent("Item")
local itemRemoteFunction = SimpleRemotes.getFunction("Item")

local itemInventory: { [string]: number | true } = {}

local loaded = false

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

ItemController.ItemGrantedTasks = TasksList.new() :: TasksList.TasksList<ItemEventTask>
ItemController.ItemConsumedTasks = TasksList.new() :: TasksList.TasksList<ItemEventTask>
ItemController.ItemAcquiredTasks = TasksList.new() :: TasksList.TasksList<ItemAcquiredTask>
ItemController.InventoryLoadedTasks = TasksList.new() :: TasksList.TasksList<InventoryLoadedTask>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getItemAmount(itemName: string): number
	local item = ItemConstants.getItem(itemName)
	if not item then
		return 0 -- RETURN: Unknown item
	end

	local value = itemInventory[itemName]
	if item.OwnershipMode == OWNERSHIP_MODES.Permanent then
		return if value == true then 1 else 0
	end

	return if type(value) == "number" then math.max(0, value) else 0
end

local function loadItemRemote()
	SimpleRemotesUtil.bindRemoteEventActions(itemRemoteEvent, {
		[EVENT_CODES.Granted] = function(b: buffer)
			local hash, delta
			local offset = 0

			hash, offset = BufferUtil.readu32(b, offset)
			delta, offset = BufferUtil.readu32(b, offset)

			local item = ItemConstants.getItemFromHash(hash)
			if not item then
				return -- RETURN: Unknown item
			end

			local itemName = item.Name
			if item.OwnershipMode == OWNERSHIP_MODES.Permanent then
				itemInventory[itemName] = true
			else
				local current = ItemController.getAmount(itemName)
				itemInventory[itemName] = current + delta
			end

			ItemController.ItemGrantedTasks:Execute("parallel", itemName, delta)
		end,

		[EVENT_CODES.Consumed] = function(b: buffer)
			local hash, delta
			local offset = 0

			hash, offset = BufferUtil.readu32(b, offset)
			delta, offset = BufferUtil.readu32(b, offset)

			local item = ItemConstants.getItemFromHash(hash)
			if not item then
				return -- RETURN: Unknown item
			end

			local itemName = item.Name
			if item.OwnershipMode == OWNERSHIP_MODES.Consumable then
				local current = ItemController.getAmount(itemName)
				local nextAmount = math.max(0, current - delta)
				itemInventory[itemName] = if nextAmount > 0 then nextAmount else nil
			end

			ItemController.ItemConsumedTasks:Execute("parallel", itemName, delta)
		end,

		[EVENT_CODES.Acquired] = function(b: buffer)
			local hash
			local offset = 0

			hash, offset = BufferUtil.readu32(b, offset)

			local item = ItemConstants.getItemFromHash(hash)
			if not item then
				return -- RETURN: Unknown item
			end

			itemInventory[item.Name] = true
			ItemController.ItemAcquiredTasks:Execute("parallel", item.Name)
		end,
	}, SimpleRemotesUtil.DecodeActionBuffer)
end

local function loadInventorySnapshot()
	local b = buffer.create(1)
	BufferUtil.writeu8(b, 0, FUNCTION_CODES.Get)

	local snapshot = itemRemoteFunction:InvokeServer(b)
	itemInventory = if type(snapshot) == "table" then snapshot else {}

	-- Pass the state
	loaded = true
	ItemController.InventoryLoadedTasks:Execute("parallel", itemInventory)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ItemController.isLoaded()
	return loaded
end

function ItemController.onLoaded(callback: InventoryLoadedTask): () -> ()
	if ItemController.isLoaded() then
		task.spawn(callback, itemInventory)
		return function() end -- Empty disconnect func
	end

	return ItemController.InventoryLoadedTasks:Add(callback)
end

function ItemController.requestPurchase(itemName: string): number
	local item = ItemConstants.getItem(itemName)
	if not item then
		return ResponseCodes.NotFound -- RETURN: Unknown item
	end

	local b = buffer.create(1 + 4)
	local offset = BufferUtil.writeu8(b, 0, EVENT_CODES.Purchase)
	BufferUtil.writeu32(b, offset, CRC32C(buffer.fromstring(item.Name)))

	itemRemoteEvent:FireServer(b)
	return ResponseCodes.Sent
end

function ItemController.hasItem(itemName: string): boolean
	return getItemAmount(itemName) > 0
end

function ItemController.getAmount(itemName: string): number
	return getItemAmount(itemName)
end

function ItemController.getInventory()
	return itemInventory
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function ItemController.init()
	loadItemRemote()
end

function ItemController.start()
	loadInventorySnapshot()
end

-- function ItemController.test() end

return ItemController
