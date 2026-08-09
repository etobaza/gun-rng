local EconomyUtil = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyConstants = require(ReplicatedStorage.Shared.Constants.EconomyConstants)
local GeneralUtil = require(ReplicatedStorage.Shared.Utils.GeneralUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local CURRENCIES = EconomyConstants.Currencies

local ROBUX_ICON = ""

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function EconomyUtil.getPricePrefix(price: EconomyConstants.Price)
	local currency = price.Currency
	if currency == CURRENCIES.Cash then
		return "$"
	elseif currency == CURRENCIES.Gems then
		return "💎"
	elseif currency == CURRENCIES.Gamepass or currency == CURRENCIES.DevProduct then
		return ROBUX_ICON
	end

	return ""
end

function EconomyUtil.getPriceDisplayString(price: EconomyConstants.Price)
	local amount = price.Amount
	if not amount or amount == 0 then
		return "Free"
	else
		return `{EconomyUtil.getPricePrefix(price)}{GeneralUtil.formatNumber(amount)}`
	end
end

return EconomyUtil
