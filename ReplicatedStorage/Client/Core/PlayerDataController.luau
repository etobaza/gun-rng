--[[
  PlayerDataController

  Description:
  Handles client player data state

  Author:
  @SixthAtom

  Date:
  20-02-2026
]]

local PlayerDataController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local ProfileTemplate = require(ReplicatedStorage.Shared.Constants.Data.ProfileTemplate)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type UpdateTask = (index: string | number, value: any, path: { string | number }) -> ()
type DataLoadedTask = (data: ProfileTemplate.Template) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local updateDataRemote = SimpleRemotes.getEvent("UpdateData")
local getDataRemote = SimpleRemotes.getFunction("GetData")

local bank: ProfileTemplate.Template

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

PlayerDataController.UpdatedTasks = TasksList.new() :: TasksList.TasksList<UpdateTask>
PlayerDataController.DataLoadedTasks = TasksList.new() :: TasksList.TasksList<DataLoadedTask>

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function PlayerDataController.get()
	return bank
end

function PlayerDataController.getAsync(callback: (data: ProfileTemplate.Template) -> ())
	if bank then
		task.spawn(callback, bank)
	else
		PlayerDataController.DataLoadedTasks:Add(callback)
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function PlayerDataController.init()
	bank = getDataRemote:InvokeServer()
	PlayerDataController.DataLoadedTasks:Execute("parallel", bank)
end

function PlayerDataController.start()
	updateDataRemote.OnClientEvent:Connect(function(schedule: { { any } })
		for _, v in schedule do
			local path: { string | number }, index, value = unpack(v)

			local parent = bank
			for _, w in path do
				parent = parent[w]
				if not parent then
					warn(`Invalid PlayerDataController path: {table.concat(path, ".")} -> {tostring(w)}`)

					return
				end
			end

			parent[index] = value
			PlayerDataController.UpdatedTasks:Execute("parallel", index, value, path)
		end
	end)
end

function PlayerDataController.test()
	warn("Local Bank:", bank)
end

return PlayerDataController
