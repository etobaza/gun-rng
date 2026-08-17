--[[
  GlobalInstanceController

  Description:
  Handles global instancing on the client

  Author:
  @SixthAtom

  Date:
  04-04-2026
]]

local GlobalInstanceController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local SimpleRemotesUtil = require(ReplicatedStorage.Shared.Networking.SimpleRemotesUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local EVENT_CODES = RemoteCodes.Instances.Events

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type UpdatePayload = {
	Add: { Instance },
	Id: number?,
	Remove: { number },
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local remoteEvent = SimpleRemotes.getEvent("GlobalInstanceService")

local idList: { [number]: Instance } = {}
local idLUT: { [Instance]: number } = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function loadRemotes()
	SimpleRemotesUtil.bindRemoteEventActions(remoteEvent, {
		[EVENT_CODES.Update] = function(data: UpdatePayload)
			if data.Id ~= nil then
				local id = data.Id

				for _, instance in next, data.Add do
					idList[id] = instance
					idLUT[instance] = id
					id += 1
				end
			end

			for _, id in data.Remove do
				local instance = idList[id]
				if instance then
					idLUT[instance] = nil
				end

				idList[id] = nil
			end
		end,

		[EVENT_CODES.SendAll] = function(data: { [number]: Instance })
			for id, instance in next, data do
				idList[id] = instance
				idLUT[instance] = id
			end
		end,
	})
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function GlobalInstanceController.getId(instance: Instance)
	return idLUT[instance] or instance
end

function GlobalInstanceController.getInstance(idOrInstance: number | Instance): Instance?
	if typeof(idOrInstance) == "Instance" then
		return idOrInstance
	end

	return idList[idOrInstance]
end

function GlobalInstanceController.getIdList()
	return idList
end

function GlobalInstanceController.getIdLUT()
	return idLUT
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function GlobalInstanceController.init()
	loadRemotes()
end

-- function GlobalInstanceController.start() end

-- function GlobalInstanceController.test() end

return GlobalInstanceController
