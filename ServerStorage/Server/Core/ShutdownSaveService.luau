--[[
  ShutdownSaveService

  Description:
  Handles shutdown data saves

  Author:
  @SixthAtom

  Date:
  12-03-2026
]]

local SoftSDService = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local MESSAGE_DELAY = 4

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local isShuttingDown = false

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function createMessage(text: string)
	local message = Instance.new("Message")
	message.Text = text
	message.Parent = workspace
	return message
end

local function onServerClosing()
	if isShuttingDown then
		return
	end
	isShuttingDown = true

	if RunService:IsStudio() or #Players:GetPlayers() == 0 then
		return
	end

	local message = createMessage("Server restart imminent. Saving your data...")

	for player, profile in PlayerDataService.getProfiles() do
		if Players:IsAncestorOf(player) then
			local ok, saveError = pcall(profile.Save, profile)
			if not ok then
				warn(`Profile save failed for {player.Name}: {saveError}`)
			end
		end
	end

	message.Text = "Server restart imminent. Your data has been saved."
	task.wait(MESSAGE_DELAY)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function SoftSDService.init()
	game:BindToClose(onServerClosing)
end

function SoftSDService.start() end

function SoftSDService.test() end

return SoftSDService
