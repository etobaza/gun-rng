local CreatureService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CreatureConstants = require(ReplicatedStorage.Shared.Constants.CreatureConstants)
local LootConstants = require(ReplicatedStorage.Shared.Constants.LootConstants)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local CreatureProtocol = require(ReplicatedStorage.Shared.Networking.Protocols.CreatureProtocol)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local SimpleRemotesUtil = require(ReplicatedStorage.Shared.Networking.SimpleRemotesUtil)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)
local CreatureUtil = require(ReplicatedStorage.Shared.Utils.CreatureUtil)
local ItemService = require(ServerStorage.Server.Core.ItemService)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

local EVENT_CODES = RemoteCodes.Creature.Events
local FUNCTION_CODES = RemoteCodes.Creature.Functions
local REMOVAL_REASONS = CreatureConstants.RemovalReasons

local LUCK_PER_UPGRADE_LEVEL = 0.05
local WORLD_LUCK_PER_LEVEL = 0.5

local creatureRemoteEvent = SimpleRemotes.getEvent("Creature")
local creatureRemoteFunction = SimpleRemotes.getFunction("Creature")

local creaturesByPlayer: { [Player]: { [number]: CreatureConstants.Snapshot } } = {}
local nextCreatureIdByPlayer: { [Player]: number } = {}
local spawnThreadsByPlayer: { [Player]: thread } = {}
local rng = Random.new()

local function isFiniteVector(value: Vector3): boolean
   return value.X == value.X
      and value.Y == value.Y
      and value.Z == value.Z
      and math.abs(value.X) < math.huge
      and math.abs(value.Y) < math.huge
      and math.abs(value.Z) < math.huge
end

local function addAction(action: number, payload: buffer): buffer
   return BufferUtil.combine(BufferUtil.construct({ { Type = "U8", Value = action } }), payload)
end

local function getFarmingZone(): BasePart?
   local world = workspace:FindFirstChild("World")
   local farmingZone = world and world:FindFirstChild("FarmingZone")
   return if farmingZone and farmingZone:IsA("BasePart") then farmingZone else nil
end

local function rollMutationId(): number
   local totalWeight = 0
   for _, mutation in CreatureConstants.Mutations do
      totalWeight += mutation.SpawnWeight
   end

   local roll = rng:NextNumber(0, totalWeight)
   for _, mutation in CreatureConstants.Mutations do
      roll -= mutation.SpawnWeight
      if roll <= 0 then
         return mutation.Id
      end
   end

   return CreatureConstants.Mutations.None.Id
end

local function createSnapshot(player: Player, farmingZone: BasePart): CreatureConstants.Snapshot
   local species = CreatureConstants.Species.Slime
   local halfSize = farmingZone.Size * 0.5
   local horizontalMargin = CreatureConstants.SpawnMargin + species.MoveRadius
   local xRange = math.max(0, halfSize.X - horizontalMargin)
   local zRange = math.max(0, halfSize.Z - horizontalMargin)
   local now = workspace:GetServerTimeNow()

   local nextId = nextCreatureIdByPlayer[player] or 1
   nextCreatureIdByPlayer[player] = if nextId >= 4_294_967_295 then 1 else nextId + 1

   return {
      Id = nextId,
      SpeciesId = species.Id,
      MutationId = rollMutationId(),
      Health = species.MaxHealth,
      MaxHealth = species.MaxHealth,
      SpawnedAt = now,
      ExpiresAt = now + CreatureConstants.Lifetime,
      Origin = farmingZone.Position
         + Vector3.new(rng:NextNumber(-xRange, xRange), halfSize.Y + species.Radius, rng:NextNumber(-zRange, zRange)),
      Phase = rng:NextNumber(0, math.pi * 2),
   }
end

local function fireSpawned(player: Player, snapshot: CreatureConstants.Snapshot)
   creatureRemoteEvent:FireClient(player, addAction(EVENT_CODES.Spawned, CreatureProtocol.encodeSnapshot(snapshot)))
end

local function fireHealthChanged(player: Player, creatureId: number, health: number)
   creatureRemoteEvent:FireClient(
      player,
      BufferUtil.construct({
         { Type = "U8", Value = EVENT_CODES.HealthChanged },
         { Type = "U32", Value = creatureId },
         { Type = "F32", Value = health },
      })
   )
end

local function fireRemoved(player: Player, creatureId: number, reason: number)
   creatureRemoteEvent:FireClient(
      player,
      BufferUtil.construct({
         { Type = "U8", Value = EVENT_CODES.Removed },
         { Type = "U32", Value = creatureId },
         { Type = "U8", Value = reason },
      })
   )
end

local function removeCreature(player: Player, creatureId: number, reason: number)
   local creatures = creaturesByPlayer[player]
   if not creatures or not creatures[creatureId] then
      return
   end

   creatures[creatureId] = nil
   fireRemoved(player, creatureId, reason)
end

local function getLuckMultiplier(player: Player, mutationId: number): number
   local data = PlayerDataService.get(player)
   local mutation = CreatureConstants.MutationsById[mutationId]
   if not data or not mutation then
      return 1
   end

   local progression = data.Progression
   local upgradeLuck = 1 + progression.Upgrades.Luck * LUCK_PER_UPGRADE_LEVEL
   local worldLuck = 1 + math.max(0, progression.World - 1) * WORLD_LUCK_PER_LEVEL
   return upgradeLuck * worldLuck * mutation.LuckMultiplier
end

local function rewardKill(player: Player, snapshot: CreatureConstants.Snapshot)
   local loot = LootConstants.roll(getLuckMultiplier(player, snapshot.MutationId), rng)
   ItemService.grantItem(player, loot.Name, 1)
end

local function startSpawning(player: Player)
   creaturesByPlayer[player] = {}
   nextCreatureIdByPlayer[player] = 1

   spawnThreadsByPlayer[player] = task.spawn(function()
      while player:IsDescendantOf(game) and creaturesByPlayer[player] do
         local creatures = creaturesByPlayer[player]
         local now = workspace:GetServerTimeNow()
         local creatureCount = 0

         for creatureId, snapshot in creatures do
            if now >= snapshot.ExpiresAt then
               removeCreature(player, creatureId, REMOVAL_REASONS.Expired)
            else
               creatureCount += 1
            end
         end

         if creatureCount < CreatureConstants.TargetCount then
            local farmingZone = getFarmingZone()
            if farmingZone then
               local snapshot = createSnapshot(player, farmingZone)
               creatures[snapshot.Id] = snapshot
               fireSpawned(player, snapshot)
            end
         end

         task.wait(CreatureConstants.RespawnInterval)
      end
   end)
end

local function stopSpawning(player: Player)
   local spawnThread = spawnThreadsByPlayer[player]
   if spawnThread then
      task.cancel(spawnThread)
   end

   spawnThreadsByPlayer[player] = nil
   creaturesByPlayer[player] = nil
   nextCreatureIdByPlayer[player] = nil
end

local function loadRemotes()
   SimpleRemotesUtil.bindRemoteFunctionActions(creatureRemoteFunction, {
      [FUNCTION_CODES.GetSnapshot] = function(player: Player)
         local snapshots = {}
         for _, snapshot in creaturesByPlayer[player] or {} do
            table.insert(snapshots, snapshot)
         end

         return CreatureProtocol.encodeSnapshotList(snapshots)
      end,
   }, SimpleRemotesUtil.DecodeActionBuffer)
end

function CreatureService.damage(
   player: Player,
   creatureId: number,
   damage: number,
   hitPosition: Vector3,
   shotOrigin: Vector3
): boolean
   local creatures = creaturesByPlayer[player]
   local snapshot = creatures and creatures[creatureId]
   local species = snapshot and CreatureConstants.SpeciesById[snapshot.SpeciesId]
   if not (creatures and snapshot and species) then
      return false
   end

   local now = workspace:GetServerTimeNow()
   if now >= snapshot.ExpiresAt then
      removeCreature(player, creatureId, REMOVAL_REASONS.Expired)
      return false
   end

   if not isFiniteVector(hitPosition) or not isFiniteVector(shotOrigin) then
      return false
   end

   local expectedPosition = CreatureUtil.getPosition(snapshot, now)
   if (expectedPosition - hitPosition).Magnitude > species.Radius + CreatureConstants.HitPositionTolerance then
      return false
   end

   local shotDirection = hitPosition - shotOrigin
   if shotDirection.Magnitude > CreatureConstants.MaxHitDistance then
      return false
   end

   local raycastParams = RaycastParams.new()
   if player.Character then
      raycastParams.ExcludeInstances = { player.Character }
   end

   local obstruction = workspace:Raycast(shotOrigin, shotDirection, raycastParams)
   if obstruction and obstruction.Distance + CreatureConstants.HitPositionTolerance < shotDirection.Magnitude then
      return false
   end

   snapshot.Health = math.max(0, snapshot.Health - math.max(0, damage))
   if snapshot.Health > 0 then
      fireHealthChanged(player, creatureId, snapshot.Health)
      return true
   end

   removeCreature(player, creatureId, REMOVAL_REASONS.Killed)
   rewardKill(player, snapshot)
   return true
end

function CreatureService.init()
   PlayerDataService.ProfileAddedTasks:Add(function(player: Player)
      startSpawning(player)
   end)
   PlayerDataService.ProfileRemovedTasks:Add(stopSpawning)
   loadRemotes()
end

function CreatureService.start()
   if not getFarmingZone() then
      warn("CreatureService requires Workspace.World.FarmingZone")
   end
end

return CreatureService
