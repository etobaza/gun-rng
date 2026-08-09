--[[
   PlayerDataService
   
   Description:
   Handles server-side player data
   
   Author:
   @SixthAtom
   
   Date:
   20-02-2026
]]


const PlayerDataService = {}

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const ServerStorage = game:GetService("ServerStorage")
const HttpService = game:GetService("HttpService")

const TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
const ProfileStore = require(ServerStorage.Packages.ProfileStore)
const ProfileTemplate = require(ReplicatedStorage.Shared.Data.ProfileTemplate)
const SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
const GeneralUtil = require(ReplicatedStorage.Shared.Utils.GeneralUtil)
const PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

const NON_WIPABLE_INDEXES = { "BanData" }

const DATA_KEY = `GunDealerTycoon.{RunService:IsStudio() and "Dev" or "Live"}`

-- Mock datastore config
const USE_MOCK_DATASTORE = GeneralUtil.canDebug(true)
const MOCK_DATASTORE_URL = `http://127.0.0.1:42195/?store={DATA_KEY}&key=`
const MOCK_DATASTORE_USERIDS = {
	[1076099385] = "SixthAtom",
}

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type Profile = typeof(ProfileStore.New("", ProfileTemplate.get()):StartSessionAsync(...)) & { DataProxy: ProfileTemplate.Template }

export type Data = ProfileTemplate.Template

type UpdateTask = (player: Player, index: Index, value: any, path: { string | number }) -> ()
type ProfileAddedTask = (player: Player, data: ProfileTemplate.Template, profile: Profile) -> ()
type ProfileRemovedTask = (player: Player, profile: Profile) -> ()

type Index = string | number
type EventMeta = { [string]: any }

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

const updateDataRemote = SimpleRemotes.getEvent("UpdateData")
const getDataRemote = SimpleRemotes.getFunction("GetData")

const store = ProfileStore.New(DATA_KEY, ProfileTemplate.get() :: any)

const profiles: { [Player]: Profile } = {}
local replicationSchedule: { [Player]: { { any } } } = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

PlayerDataService.UpdatedTasks = TasksList.new() :: TasksList.TasksList<UpdateTask>
PlayerDataService.ProfileAddedTasks = TasksList.new() :: TasksList.TasksList<ProfileAddedTask>
PlayerDataService.ProfileRemovedTasks = TasksList.new() :: TasksList.TasksList<ProfileRemovedTask>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function scheduleReplication(player: Player, path: { string | number }, i: any, v: any)
	if not replicationSchedule[player] then
		replicationSchedule[player] = {}
	end

	table.insert(replicationSchedule[player], { path, i, v })
end

local function loadReplication(player: Player, tbl: { [any]: any }, _path: { string | number }?)
	const path = _path or {}

	const childProxies = {}
	const proxy = setmetatable({}, {
		__newindex = function(_, i, v)
			if type(v) == "table" then
				const newPath = table.clone(path)
				table.insert(newPath, i)
				childProxies[i] = loadReplication(player, v, newPath)
			else
				tbl[i] = v
			end
			scheduleReplication(player, path, i, v)
			PlayerDataService.UpdatedTasks:Execute("parallel", player, i, v, path)
		end,

		__index = function(_, i)
			return childProxies[i] or tbl[i]
		end,

		__call = function()
			return tbl
		end,

		__iter = function()
			local lastKey: any
			return function()
				local i, v = next(tbl, lastKey)
				lastKey = i
				return i, v
			end
		end,
	})

	for i, v in tbl do
		if type(v) == "table" then
			const newPath = table.clone(path)
			table.insert(newPath, i)
			childProxies[i] = loadReplication(player, v, newPath)
		end
	end

	return proxy
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

--[[
	Returns the live data proxy for the given player.
	The returned table is a replicated proxy:
	- Writing to it automatically schedules client replication.
	- Nested tables are also proxied.
	@return ProfileTemplate.Template? -- The player's data proxy, or nil if the profile is not loaded.
]]
function PlayerDataService.get(player: Player): ProfileTemplate.Template?
	const profile = profiles[player]
	if profile then
		return profile.DataProxy
	end
	return nil
end

--[[
	Calls the callback() when the data is finished loading.
	The returned table is a replicated proxy:
	- Writing to it automatically schedules client replication.
	- Nested tables are also proxied.
	@return ProfileTemplate.Template? -- The player's data proxy, or nil if the profile is not loaded.
]]
function PlayerDataService.getAsync(player: Player, callback: (data: ProfileTemplate.Template) -> ())
	const profile = profiles[player]
	if not profile then
		player:GetAttributeChangedSignal("DataInitialized"):Once(function()
			callback(profiles[player].DataProxy)
		end)
		return
	end

	task.spawn(callback, profile.DataProxy)
end

--[[
	Completely resets a player's profile to the default template.
	This immediately overwrites stored data and forcibly removes the player
	from the server to prevent continued play with wiped data.
	@return nil
]]
function PlayerDataService.wipe(player: Player, dontKick: true?)
	const profile = profiles[player]
	if profile then
		const oldData = profile.Data
		const newData = ProfileTemplate.get()

		for _, v in next, NON_WIPABLE_INDEXES do
			if oldData[v] then
				newData[v] = oldData[v]
			end
		end

		profile.Data = newData
		profile:Save()

		if not dontKick then
			player:Kick(`DATA WIPED {player.Name}`)
		end
	end
end

--[[
	Returns the live profile object for the given player.
	This includes both `Data` and `DataProxy`.
	@return Profile? -- The player's profile, or nil if not loaded.
]]
function PlayerDataService.getProfile(player: Player): Profile?
	return profiles[player]
end

--[[
	Returns all currently loaded profiles keyed by Player.
	Returns live profile objects so callers CAN mutate internal state directly.
	@return { [Player]: Profile }
]]
function PlayerDataService.getProfiles()
	return profiles
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function PlayerDataService.start()
	-- On start, so this is absolute last.
	PlayersUtil.onPlayerAdded(function(player: Player)
		const profile = store:StartSessionAsync(`{player.UserId}`, {
			Cancel = function()
				return not Players:IsAncestorOf(player)
			end,
		}) :: Profile

		if profile then
			profile:AddUserId(player.UserId)

			if USE_MOCK_DATASTORE and MOCK_DATASTORE_USERIDS[player.UserId] ~= nil then
				local response = nil
				const success, err = pcall(function()
					response = HttpService:GetAsync(`{MOCK_DATASTORE_URL}{player.UserId}`, true)
				end)

				if success and response and response ~= "" then
					const dataSuccess, decoded = pcall(HttpService.JSONDecode, HttpService, response)
					if dataSuccess and type(decoded) == "table" then
						profile.Data = decoded
					end
				elseif not success then
					warn(`Failed to fetch mock data: {err}`)
				end
			end

			profile:Reconcile()

			profile.OnSave:Connect(function()
				if USE_MOCK_DATASTORE and MOCK_DATASTORE_USERIDS[player.UserId] ~= nil then
					const success, err = pcall(function()
						HttpService:PostAsync(
							`{MOCK_DATASTORE_URL}{player.UserId}`,
							HttpService:JSONEncode(profile.Data),
							Enum.HttpContentType.ApplicationJson
						)
					end)

					if not success then
						warn(`Failed to save mock data: {err}`)
					end
				end
			end)

			profile.OnSessionEnd:Connect(function()
				profiles[player] = nil
				player:Kick(`Profile session end - Please rejoin`)
			end)

			if Players:IsAncestorOf(player) then
				profiles[player] = profile

				profile.DataProxy = loadReplication(player, profile.Data)
				player:SetAttribute("DataInitialized", true)
				PlayerDataService.ProfileAddedTasks:Execute("parallel", player, profile.DataProxy, profile)

				warn(`Loaded profile for {player.Name}: `, profile)
			else
				profile:EndSession()
			end
		else
			player:Kick("Profile load fail - Please rejoin")
		end
	end)
end

function PlayerDataService.init()
	-- Removing profiles
	Players.PlayerRemoving:Connect(function(player)
		const profile = profiles[player]
		if profile then
			profile:EndSession()
			PlayerDataService.ProfileRemovedTasks:Execute("parallel", player, profile)
			profiles[player] = nil
		end
	end)

	-- Pushing schedules
	RunService.PostSimulation:Connect(function()
		task.defer(task.defer, function()
			for player, schedule in replicationSchedule do
				updateDataRemote:FireClient(player, schedule)
			end
			replicationSchedule = {}
		end)
	end)

	-- Remotes
	getDataRemote.OnServerInvoke = function(player: Player)
		if not player:GetAttribute("DataInitialized") then
			player:GetAttributeChangedSignal("DataInitialized"):Wait()
		end

		return profiles[player].Data
	end
end

return PlayerDataService
