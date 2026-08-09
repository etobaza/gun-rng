--[[
  DailyRewardsService

  Description:
  Handles daily reward claims

  Author:
  @SixthAtom

  Date:
  20-02-2026
]]

local DailyRewardsService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DailyRewardsConstants = require(ReplicatedStorage.Shared.Constants.DailyRewardsConstants)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local SECONDS_IN_DAY = 86_400

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local claimRemoteFunction = SimpleRemotes.getFunction("ClaimDailyReward")

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function isClaimable(player: Player)
	local data = PlayerDataService.get(player)
	if not data then
		return false
	end

	local lastClaim = data.DailyRewards.LastClaim
	return lastClaim == 0 or (os.time() - lastClaim >= SECONDS_IN_DAY)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function DailyRewardsService.claim(player: Player)
	if not isClaimable(player) then
		return false
	end

	local data = PlayerDataService.get(player)
	if not data then
		return false
	end

	data.DailyRewards.Streak = (data.DailyRewards.Streak % DailyRewardsConstants.MaxStreakDays) + 1
	data.DailyRewards.LastClaim = os.time()
	warn(`{player.Name} claimed!`)

	return true
end

-------------------------------------------------------------------------------
-- LOGIC
-------------------------------------------------------------------------------

function DailyRewardsService.init()
	PlayerDataService.ProfileAddedTasks:Add(function(player, data)
		-- RETURN: Daily reward isn't claimed yet
		if data.DailyRewards.LastClaim == 0 then
			return
		end

		local timeSinceClaim = os.time() - data.DailyRewards.LastClaim
		if timeSinceClaim >= SECONDS_IN_DAY * 2 then
			data.DailyRewards.Streak = 0
			data.DailyRewards.LastClaim = 0
		end
	end)

	claimRemoteFunction.OnServerInvoke = function(player: Player)
		return DailyRewardsService.claim(player)
	end
end

return DailyRewardsService
