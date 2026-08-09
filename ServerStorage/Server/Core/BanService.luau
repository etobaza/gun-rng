--[[
  BanService

  Description:
  Handles player banning, safely and securely.

  Author:
  @SixthAtom

  Date:
  02-04-2026
]]

local BanService = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local MAX_RETRIES = 3
local RETRY_MIN, RETRY_MAX = 5, 10

local DEFAULT_BAN_DELAY_TIME = 1_209_600

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type BanConfig = {
	BaseDuration: number,
	PrivateReason: string,
	PublicReason: string?,
	DelayAmount: number?,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local rng = Random.new()

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

BanService.Times = {
	Day = 86_400,
	Week = 604_800,
	Month = 2_419_200,
	Year = 29_030_400,
}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function safeBanAsync(config: {
	UserIds: { number },
	Duration: number,
	DisplayReason: string,
	PrivateReason: string,
	ExcludeAltAccounts: boolean?,
	ApplyToUniverse: boolean?,
}): { Response: true } | { Response: false, Error: string }
	for attempt = 1, MAX_RETRIES do
		local success, result = pcall(Players.BanAsync, Players, config)

		if success then
			return { Response = true }
		end

		if attempt < MAX_RETRIES then
			task.wait(rng:NextNumber(RETRY_MIN, RETRY_MAX))
		else
			return { Response = false, Error = tostring(result) }
		end
	end

	return { Response = false, Error = "Unreachable" }
end

local function getAccountAgeMultiplier(age: number)
	if age <= 30 then
		return math.huge
	elseif age <= 90 then
		return 50
	elseif age <= 180 then
		return 10
	else
		return 1
	end
end

local function getBanOffenseMultiplier(offenses: number)
	if offenses == 0 then
		return 1
	elseif offenses <= 1 then
		return 3
	else
		return math.huge
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function BanService.ban(player: Player, config: BanConfig)
	local duration = config.BaseDuration
	duration *= getAccountAgeMultiplier(player.AccountAge)

	local publicReason = config.PublicReason or "Banned by a moderator"

	local data = PlayerDataService.get(player)
	if not data then
		safeBanAsync({
			UserIds = { player.UserId },
			Duration = duration,
			DisplayReason = publicReason,
			PrivateReason = config.PrivateReason,
		})
		return
	end

	duration *= getBanOffenseMultiplier(data.BanData.BanAmount)

	if RunService:IsStudio() then
		player:Kick(`STUDIO BAN - Banned for "{publicReason}" | Duration: {duration}s} | Private Reason: {config.PrivateReason}`)
		return
	end

	local pendingBan = data.BanData.Pending
	if pendingBan then
		if pendingBan.Duration < duration then
			pendingBan.Duration = duration
			pendingBan.PrivateReason = config.PrivateReason
			pendingBan.PublicReason = publicReason
		end
	else
		data.BanData.Pending = {
			ExecuteAt = os.time() + (config.DelayAmount or DEFAULT_BAN_DELAY_TIME),
			Duration = duration,
			PrivateReason = config.PrivateReason,
			PublicReason = publicReason,
		}
	end
end
-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function BanService.init()
	PlayerDataService.ProfileAddedTasks:Add(function(player, data)
		local pendingBan = data.BanData.Pending
		if not pendingBan or os.time() < pendingBan.ExecuteAt then
			return -- RETURN: No pending OR not yet execute
		end

		data.BanData.BanAmount += 1
		data.BanData.Pending = nil
		PlayerDataService.wipe(player, true)

		safeBanAsync({
			UserIds = { player.UserId },
			DisplayReason = pendingBan.PublicReason,
			PrivateReason = pendingBan.PrivateReason,
			Duration = pendingBan.Duration,
		})
	end)
end

-- function BanService.start() end

-- function BanService.test() end

return BanService
