local CreatureProtocol = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreatureConstants = require(ReplicatedStorage.Shared.Constants.CreatureConstants)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)

local SNAPSHOT_SIZE = 46

local function writeSnapshot(b: buffer, offset: number, snapshot: CreatureConstants.Snapshot): number
   offset = BufferUtil.writeu32(b, offset, snapshot.Id)
   offset = BufferUtil.writeu8(b, offset, snapshot.SpeciesId)
   offset = BufferUtil.writeu8(b, offset, snapshot.MutationId)
   offset = BufferUtil.writef32(b, offset, snapshot.Health)
   offset = BufferUtil.writef32(b, offset, snapshot.MaxHealth)
   offset = BufferUtil.writef64(b, offset, snapshot.SpawnedAt)
   offset = BufferUtil.writef64(b, offset, snapshot.ExpiresAt)
   offset = BufferUtil.writeVector3_96(b, offset, snapshot.Origin)
   offset = BufferUtil.writef32(b, offset, snapshot.Phase)
   return offset
end

local function readSnapshot(b: buffer, offset: number): (CreatureConstants.Snapshot, number)
   local id, speciesId, mutationId, health, maxHealth, spawnedAt, expiresAt, origin, phase
   id, offset = BufferUtil.readu32(b, offset)
   speciesId, offset = BufferUtil.readu8(b, offset)
   mutationId, offset = BufferUtil.readu8(b, offset)
   health, offset = BufferUtil.readf32(b, offset)
   maxHealth, offset = BufferUtil.readf32(b, offset)
   spawnedAt, offset = BufferUtil.readf64(b, offset)
   expiresAt, offset = BufferUtil.readf64(b, offset)
   origin, offset = BufferUtil.readVector3_96(b, offset)
   phase, offset = BufferUtil.readf32(b, offset)

   return {
      Id = id,
      SpeciesId = speciesId,
      MutationId = mutationId,
      Health = health,
      MaxHealth = maxHealth,
      SpawnedAt = spawnedAt,
      ExpiresAt = expiresAt,
      Origin = origin,
      Phase = phase,
   },
      offset
end

CreatureProtocol.SnapshotSize = SNAPSHOT_SIZE

function CreatureProtocol.encodeSnapshot(snapshot: CreatureConstants.Snapshot): buffer
   local b = buffer.create(SNAPSHOT_SIZE)
   writeSnapshot(b, 0, snapshot)
   return b
end

function CreatureProtocol.decodeSnapshot(b: buffer, offset: number?): (CreatureConstants.Snapshot, number)
   return readSnapshot(b, offset or 0)
end

function CreatureProtocol.encodeSnapshotList(snapshots: { CreatureConstants.Snapshot }): buffer
   local b = buffer.create(2 + #snapshots * SNAPSHOT_SIZE)
   local offset = BufferUtil.writeu16(b, 0, #snapshots)

   for _, snapshot in snapshots do
      offset = writeSnapshot(b, offset, snapshot)
   end

   return b
end

function CreatureProtocol.decodeSnapshotList(b: buffer): { CreatureConstants.Snapshot }
   local amount, offset = BufferUtil.readu16(b, 0)
   local snapshots = table.create(amount)

   for index = 1, amount do
      snapshots[index], offset = readSnapshot(b, offset)
   end

   return snapshots
end

return CreatureProtocol
