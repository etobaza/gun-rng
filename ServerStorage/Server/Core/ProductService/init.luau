--[[
  ProductService

  Description:
  Handles product purchases

  Author:
  @SixthAtom

  Date:
  02-03-2026
]]

local ProductService = {}

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local PRODUCT_GRANTED_DECISION = Enum.ProductPurchaseDecision.PurchaseGranted
local PRODUCT_NOT_PROCESSED_DECISION = Enum.ProductPurchaseDecision.NotProcessedYet

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type ProductHandler = (player: Player) -> boolean
type GamepassHandler = (player: Player) -> ()

type ReceiptInfo = {
	PurchaseId: string,
	PlayerId: number,
	ProductId: number,
	PlaceIdWherePurchased: number,
	CurrencySpent: number,
	CurrencyType: Enum.CurrencyType,
	ProductPurchaseChannel: Enum.ProductPurchaseChannel,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local devProductHandlers: { [number]: ProductHandler } = {}
local gamepassHandlers: { [number]: GamepassHandler } = {}
local gamepassRewardGranted: { [Player]: { [number]: boolean } } = {} -- Tracks granted passes per player to avoid redundant handler calls

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function processReceipt(receiptInfo: ReceiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return PRODUCT_NOT_PROCESSED_DECISION
	end

	local profile = PlayerDataService.getProfile(player)
	if not profile then
		return PRODUCT_NOT_PROCESSED_DECISION
	end

	local handler = devProductHandlers[receiptInfo.ProductId]
	if not handler then
		return PRODUCT_NOT_PROCESSED_DECISION
	end

	local ok, granted = pcall(handler, player)
	if not ok or not granted then
		return PRODUCT_NOT_PROCESSED_DECISION
	end

	profile:Save()

	return PRODUCT_GRANTED_DECISION
end

local function passPurchaseFinished(player: Player, id: number, purchased: boolean)
	if not purchased then
		return -- RETURN: Purchase was cancelled or failed
	end

	local handler = gamepassHandlers[id]
	if not handler then
		return -- RETURN: No handler registered for this gamepass
	end

	local playerGranted = gamepassRewardGranted[player]
	if not playerGranted or playerGranted[id] then
		return -- RETURN: Player left or already granted this session
	end

	playerGranted[id] = true
	handler(player)
end

local function scanAllGamepasses(player: Player)
	for id, handler in next, gamepassHandlers do
		task.spawn(function()
			local playerGranted = gamepassRewardGranted[player]
			if not playerGranted then
				return -- RETURN: Player left before scan completed
			end

			if playerGranted[id] then
				return -- RETURN: Already granted this session
			end

			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
			if not ok or not owns then
				return -- RETURN: MPS call failed or player doesn't own pass
			end

			playerGranted[id] = true
			handler(player)
		end)
	end
end

local function onPlayerAdded(player: Player)
	gamepassRewardGranted[player] = {}
	scanAllGamepasses(player)
end

local function onPlayerRemoving(player: Player)
	gamepassRewardGranted[player] = nil
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ProductService.registerDevProducts(products: { [number]: ProductHandler })
	for id, handler in next, products do
		if devProductHandlers[id] then
			error(`DevProductHandler with id {id} already exists.`)
		end
		devProductHandlers[id] = handler
	end
end

function ProductService.registerGamepasses(passes: { [number]: GamepassHandler })
	for id, handler in next, passes do
		if gamepassHandlers[id] then
			error(`GamePassHandler with id {id} already exists.`)
		end
		gamepassHandlers[id] = handler
	end

	for _, player in next, Players:GetPlayers() do
		task.spawn(scanAllGamepasses, player)
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function ProductService.init()
	MarketplaceService.ProcessReceipt = processReceipt
	PlayersUtil.onPlayerAdded(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(passPurchaseFinished)
end

function ProductService.start() end

function ProductService.test() end

return ProductService
