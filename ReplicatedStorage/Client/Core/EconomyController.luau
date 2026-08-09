--[[
  EconomyController

  Description:
  Handles the economy on the client

  Author:
  @SixthAtom

  Date:
  16-04-2026
]]

local EconomyController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataController = require(ReplicatedStorage.Client.Core.PlayerDataController)
local Signal = require(ReplicatedStorage.Shared.Classes.Signal)
local EconomyConstants = require(ReplicatedStorage.Shared.Constants.EconomyConstants)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local function getPlayerCurrencies()
	return PlayerDataController.get().Currencies
end

local function getPlayerBalance(currency: EconomyConstants.Currency)
	return getPlayerCurrencies()[currency]
end

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

EconomyController.BalanceChanged = Signal.new("Parallel") :: Signal.Signal<EconomyConstants.Currency, number>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function EconomyController.canAfford(price: EconomyConstants.Price)
	if not EconomyConstants.isLiquid(price.Currency) then
		return true
	end

	return getPlayerBalance(price.Currency) >= price.Amount
end

--[[
	Invokes `callback` once per currency with current amounts, then subscribes to
	`BalanceChanged`. Same arguments as live updates: (currency, amount).
]]
function EconomyController.onBalanceChanged(callback: (EconomyConstants.Currency, number) -> ())
	for currency, amount in getPlayerCurrencies() do
		callback(currency, amount)
	end

	return EconomyController.BalanceChanged:Connect(callback)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function EconomyController.init()
	PlayerDataController.UpdatedTasks:Add(function(index: number | string, value, path: { number | string })
		if path[1] == "Currencies" then
			EconomyController.BalanceChanged:Fire(index, value)
		end
	end)
end

function EconomyController.start() end

function EconomyController.test() end

return EconomyController
