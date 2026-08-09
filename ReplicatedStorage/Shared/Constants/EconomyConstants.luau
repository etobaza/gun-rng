local EconomyConstants = {}

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type Currency = keyof<typeof(EconomyConstants.Currencies)>
export type Price = { Currency: "Free" } | { Currency: "Cash" | "Gems", Amount: number }

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local currencies = {
	Free = "Free",
	Cash = "Cash",
	Gems = "Gems",
	Gamepass = "Gamepass",
	DevProduct = "DevProduct",
}

local liquidCurrencies = {
	currencies.Cash,
	currencies.Gems,
}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

EconomyConstants.Currencies = currencies

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function EconomyConstants.isLiquid(currency: Currency)
	return table.find(liquidCurrencies, currency) ~= nil
end

return EconomyConstants
