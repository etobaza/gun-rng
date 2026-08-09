--[[
  ProductBootstrapService

  Description:
  Bootstraps product handlers

  Author:
  @SixthAtom

  Date:
  04-03-2026
]]

local ProductBootstrapService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ProductService = require(ServerStorage.Server.Core.ProductService)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function loadCashProducts()
	ProductService.registerDevProducts({
		--[[[3553824652] = function(player: Player)
			warn("Granted the test purchase to", player.Name)
			return true
		end,]]
	})
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function ProductBootstrapService.init()
	loadCashProducts()
end

function ProductBootstrapService.start() end

function ProductBootstrapService.test() end

return ProductBootstrapService
