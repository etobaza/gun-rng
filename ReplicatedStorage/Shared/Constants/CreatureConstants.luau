local CreatureConstants = {}

export type Mutation = "None" | "Golden" | "Diamond" | "Celestial"

export type Snapshot = {
   Id: number,
   SpeciesId: number,
   MutationId: number,
   Health: number,
   MaxHealth: number,
   SpawnedAt: number,
   ExpiresAt: number,
   Origin: Vector3,
   Phase: number,
}

export type SpeciesData = {
   Id: number,
   DisplayName: string,
   MaxHealth: number,
   Radius: number,
   MoveRadius: number,
   MoveSpeed: number,
   Color: Color3,
}

export type MutationData = {
   Id: number,
   SpawnWeight: number,
   LuckMultiplier: number,
   Color: Color3?,
}

local species = {
   Slime = {
      Id = 1,
      DisplayName = "Slime",
      MaxHealth = 68,
      Radius = 2.25,
      MoveRadius = 4,
      MoveSpeed = 0.65,
      Color = Color3.fromRGB(92, 222, 112),
   },
}

local mutations: { [Mutation]: MutationData } = {
   None = {
      Id = 0,
      SpawnWeight = 97_000,
      LuckMultiplier = 1,
   },
   Golden = {
      Id = 1,
      SpawnWeight = 2_500,
      LuckMultiplier = 2,
      Color = Color3.fromRGB(255, 202, 57),
   },
   Diamond = {
      Id = 2,
      SpawnWeight = 450,
      LuckMultiplier = 5,
      Color = Color3.fromRGB(76, 231, 255),
   },
   Celestial = {
      Id = 3,
      SpawnWeight = 50,
      LuckMultiplier = 12,
      Color = Color3.fromRGB(197, 117, 255),
   },
}

local speciesById: { [number]: SpeciesData } = {}
local mutationsById: { [number]: MutationData & { Name: Mutation } } = {}

for _, data in species do
   speciesById[data.Id] = data
end

for name, data in mutations do
   mutationsById[data.Id] = {
      Name = name,
      Id = data.Id,
      SpawnWeight = data.SpawnWeight,
      LuckMultiplier = data.LuckMultiplier,
      Color = data.Color,
   }
end

CreatureConstants.Species = table.freeze(species)
CreatureConstants.SpeciesById = table.freeze(speciesById)
CreatureConstants.Mutations = table.freeze(mutations)
CreatureConstants.MutationsById = table.freeze(mutationsById)

CreatureConstants.TargetCount = 8
CreatureConstants.Lifetime = 45
CreatureConstants.RespawnInterval = 0.75
CreatureConstants.SpawnMargin = 8
CreatureConstants.HitPositionTolerance = 3
CreatureConstants.MaxHitDistance = 600
CreatureConstants.CreatureIdAttribute = "CreatureId"

CreatureConstants.RemovalReasons = table.freeze({
   Expired = 0,
   Killed = 1,
})

return CreatureConstants
