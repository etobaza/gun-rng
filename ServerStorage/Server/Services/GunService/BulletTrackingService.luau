--[[
  BulletTrackingService

  Description:
  Tracks bullet projectiles and handles VFX/SFX of them.

  Author:
  @SixthAtom

  Date:
  04-04-2026
]]

local BulletTrackingService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local GlobalInstanceService = require(ServerStorage.Server.Services.GlobalInstanceService)
local BulletTrackingProtocol = require(ReplicatedStorage.Shared.Networking.Protocols.BulletTrackingProtocol)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local EVENT_CODES = RemoteCodes.Guns.Events

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type ReplicatedShot = {
	OwnerType: number,
	OwnerId: number,
	InstanceId: number,
	Caliber: number,
	Velocities: { Vector3 },
	IgnoreList: { Instance },
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local remoteEvent = SimpleRemotes.getEvent("BulletTracking")

local replicationSchedule: { ReplicatedShot } = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function onPostSimulation()
	if #replicationSchedule <= 0 then
		return
	end

	const scheduledShots = replicationSchedule
	replicationSchedule = {}

	task.defer(task.defer, function()
		const ignoreLists: { [number]: { Instance } } = {}
		local payloadSize = 1
		for shotId = 1, #scheduledShots do
			local shot = scheduledShots[shotId]
			payloadSize += (
				BulletTrackingProtocol.ShotHeaderSizeBytes
				+ BulletTrackingProtocol.VelocitySizeBytes * #shot.Velocities
			)
		end

		local b, offset = buffer.create(payloadSize), 0
		offset = BufferUtil.writeu8(b, offset, EVENT_CODES.CastTracers)

		for shotId = 1, #scheduledShots do
			const shot = scheduledShots[shotId]
			const pelletCount = #shot.Velocities

			offset = BufferUtil.writeu16(b, offset, shotId)
			offset = BufferUtil.writeu8(b, offset, shot.OwnerType)
			offset = BufferUtil.writef64(b, offset, shot.OwnerId)
			offset = BufferUtil.writeu32(b, offset, shot.InstanceId)
			offset = BufferUtil.writeu8(b, offset, shot.Caliber)
			offset = BufferUtil.writeu8(b, offset, pelletCount)

			for pelletIndex = 1, pelletCount do
				offset = BufferUtil.writeVector3_96(b, offset, shot.Velocities[pelletIndex])
			end

			ignoreLists[shotId] = shot.IgnoreList
		end

		remoteEvent:FireAllClients(b, ignoreLists)
	end)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function BulletTrackingService.replicateShot(
	node: BasePart,
	velocities: { Vector3 },
	ownerType: number,
	ownerId: number,
	ignoreList: { Instance },
	caliber: number
)
	local instanceId = GlobalInstanceService.getId(node)

	if instanceId and #velocities > 0 then
		table.insert(replicationSchedule, {
			InstanceId = instanceId,
			Velocities = velocities,
			OwnerType = ownerType,
			OwnerId = ownerId,
			Caliber = caliber,
			IgnoreList = ignoreList,
		})
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function BulletTrackingService.init()
	RunService.PostSimulation:Connect(onPostSimulation)
end

-- function BulletTrackingService.start() end

-- function BulletTrackingService.test() end

return BulletTrackingService
