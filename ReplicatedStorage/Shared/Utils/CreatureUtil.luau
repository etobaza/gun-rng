local CreatureUtil = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreatureConstants = require(ReplicatedStorage.Shared.Constants.CreatureConstants)

function CreatureUtil.getPosition(snapshot: CreatureConstants.Snapshot, serverTime: number): Vector3
   local species = CreatureConstants.SpeciesById[snapshot.SpeciesId]
   if not species then
      return snapshot.Origin
   end

   local elapsed = math.max(0, serverTime - snapshot.SpawnedAt)
   local angle = snapshot.Phase + elapsed * species.MoveSpeed
   local secondaryAngle = snapshot.Phase * 1.7 + elapsed * species.MoveSpeed * 0.73

   return snapshot.Origin
      + Vector3.new(
         math.sin(angle) * species.MoveRadius,
         math.sin(elapsed * 2.1 + snapshot.Phase) * 0.35,
         math.cos(secondaryAngle) * species.MoveRadius
      )
end

return CreatureUtil
