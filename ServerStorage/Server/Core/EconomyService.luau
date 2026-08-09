--[[
  EconomyService

  Description:
  Handles server-side economy operations

  Author:
  @SixthAtom

  Date:
  20-02-2026
]]

local EconomyService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local EconomyConstants = require(ReplicatedStorage.Shared.Constants.EconomyConstants)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local CURRENCIES = EconomyConstants.Currencies

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getPlayerCurrencies(player: Player)
	return PlayerDataService.get(player).Currencies
end

local function getPlayerBalance(player: Player, currency: EconomyConstants.Currency)
	return getPlayerCurrencies(player)[currency]
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function EconomyService.transact(player: Player, currency: EconomyConstants.Currency, amount: number)
	if currency == CURRENCIES.Free then
		return true
	elseif EconomyConstants.isLiquid(currency) then
		if amount < 0 then
			if not EconomyService.canAfford(player, { Currency = currency, Amount = math.abs(amount) }) then
				return false
			end
		end

		local newBalance = math.max(0, getPlayerBalance(player, currency) + amount)
		getPlayerCurrencies(player)[currency] = newBalance
		return true
	end

	return false -- likely a developer product or gamepass, return false and handle off somewhere else
end

function EconomyService.canAfford(player: Player, price: EconomyConstants.Price)
	if not EconomyConstants.isLiquid(price.Currency) then
		return true
	end

	return getPlayerBalance(player, price.Currency) >= price.Amount
end

return EconomyService
