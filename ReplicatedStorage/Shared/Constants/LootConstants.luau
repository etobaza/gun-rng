local LootConstants = {}

export type Rarity =
   "Common"
   | "Rare"
   | "Epic"
   | "Legendary"
   | "Mythic"
   | "Godly"
   | "Unforeseen"
   | "Paranormal"
   | "Secret"

export type RarityData = {
   Index: number,
   Weight: number,
   LuckExponent: number,
   Color: Color3,
}

export type LootDefinition = {
   Name: string,
   DisplayName: string,
   Description: string,
   Rarity: Rarity,
   SellValue: number,
   Icon: string?,
}

export type IndexMilestone = {
   RequiredDiscoveries: number,
   RewardPercent: number,
}

local rarityOrder: { Rarity } = {
   "Common",
   "Rare",
   "Epic",
   "Legendary",
   "Mythic",
   "Godly",
   "Unforeseen",
   "Paranormal",
   "Secret",
}

local rarityData: { [Rarity]: RarityData } = {
   Common = { Index = 1, Weight = 60_000, LuckExponent = 0, Color = Color3.fromRGB(191, 198, 209) },
   Rare = { Index = 2, Weight = 25_000, LuckExponent = 0.45, Color = Color3.fromRGB(63, 140, 255) },
   Epic = { Index = 3, Weight = 10_000, LuckExponent = 0.9, Color = Color3.fromRGB(174, 77, 255) },
   Legendary = { Index = 4, Weight = 3_500, LuckExponent = 1.35, Color = Color3.fromRGB(255, 174, 45) },
   Mythic = { Index = 5, Weight = 1_000, LuckExponent = 1.8, Color = Color3.fromRGB(255, 63, 111) },
   Godly = { Index = 6, Weight = 350, LuckExponent = 2.25, Color = Color3.fromRGB(255, 241, 118) },
   Unforeseen = { Index = 7, Weight = 100, LuckExponent = 2.7, Color = Color3.fromRGB(88, 255, 203) },
   Paranormal = { Index = 8, Weight = 30, LuckExponent = 3.15, Color = Color3.fromRGB(144, 255, 73) },
   Secret = { Index = 9, Weight = 5, LuckExponent = 3.6, Color = Color3.fromRGB(255, 255, 255) },
}

local indexMilestones: { IndexMilestone } = {
   { RequiredDiscoveries = 3, RewardPercent = 1 },
   { RequiredDiscoveries = 5, RewardPercent = 2 },
   { RequiredDiscoveries = 7, RewardPercent = 3 },
   { RequiredDiscoveries = 9, RewardPercent = 4 },
}

local items: { LootDefinition } = {
   {
      Name = "BentTinCan",
      DisplayName = "Bent Tin Can",
      Description = "It is dented, but somebody will still buy it.",
      Rarity = "Common",
      SellValue = 8,
   },
   {
      Name = "BlueGeode",
      DisplayName = "Blue Geode",
      Description = "A bright mineral with a clean blue core.",
      Rarity = "Rare",
      SellValue = 25,
   },
   {
      Name = "VoidMushroom",
      DisplayName = "Void Mushroom",
      Description = "Its cap glows even in daylight.",
      Rarity = "Epic",
      SellValue = 80,
   },
   {
      Name = "SunRelic",
      DisplayName = "Sun Relic",
      Description = "A warm relic stamped with an unknown crest.",
      Rarity = "Legendary",
      SellValue = 250,
   },
   {
      Name = "DragonHeart",
      DisplayName = "Dragon Heart",
      Description = "A crystalline heart that pulses faintly.",
      Rarity = "Mythic",
      SellValue = 900,
   },
   {
      Name = "HaloFragment",
      DisplayName = "Halo Fragment",
      Description = "A shard that refuses to cast a shadow.",
      Rarity = "Godly",
      SellValue = 3_500,
   },
   {
      Name = "ImpossibleDie",
      DisplayName = "Impossible Die",
      Description = "Every side appears to face upward.",
      Rarity = "Unforeseen",
      SellValue = 15_000,
   },
   {
      Name = "SpectralCrown",
      DisplayName = "Spectral Crown",
      Description = "It flickers between this world and the next.",
      Rarity = "Paranormal",
      SellValue = 75_000,
   },
   {
      Name = "RedactedArtifact",
      DisplayName = "[REDACTED] Artifact",
      Description = "No record acknowledges that this object exists.",
      Rarity = "Secret",
      SellValue = 500_000,
   },
}

local itemsByName: { [string]: LootDefinition } = {}
local itemsByRarity: { [Rarity]: { LootDefinition } } = {}
local defaultRng = Random.new()

for _, rarity in rarityOrder do
   itemsByRarity[rarity] = {}
end

for _, item in items do
   itemsByName[item.Name] = item
   table.insert(itemsByRarity[item.Rarity], item)
end

LootConstants.RarityOrder = table.freeze(rarityOrder)
LootConstants.RarityData = table.freeze(rarityData)
LootConstants.Items = table.freeze(items)
LootConstants.IndexMilestones = table.freeze(indexMilestones)

function LootConstants.getItem(itemName: string): LootDefinition?
   return itemsByName[itemName]
end

function LootConstants.getItemsInRarity(rarity: Rarity): { LootDefinition }
   return itemsByRarity[rarity]
end

function LootConstants.getIndexLuckPercent(discoveredCount: number): number
   local luckPercent = 0
   for _, milestone in indexMilestones do
      if discoveredCount < milestone.RequiredDiscoveries then
         break
      end

      luckPercent += milestone.RewardPercent
   end

   return luckPercent
end

function LootConstants.getNextIndexMilestone(discoveredCount: number): IndexMilestone?
   for _, milestone in indexMilestones do
      if discoveredCount < milestone.RequiredDiscoveries then
         return milestone
      end
   end

   return nil
end

function LootConstants.roll(luckMultiplier: number, random: Random?): LootDefinition
   local source = random or defaultRng
   local luck = math.max(1, luckMultiplier)
   local totalWeight = 0
   local adjustedWeights = table.create(#rarityOrder)

   for index, rarity in rarityOrder do
      local data = rarityData[rarity]
      local adjustedWeight = data.Weight * luck ^ data.LuckExponent
      adjustedWeights[index] = adjustedWeight
      totalWeight += adjustedWeight
   end

   local roll = source:NextNumber(0, totalWeight)
   local selectedRarity = rarityOrder[1]

   for index, rarity in rarityOrder do
      roll -= adjustedWeights[index]
      if roll <= 0 then
         selectedRarity = rarity
         break
      end
   end

   local rarityItems = itemsByRarity[selectedRarity]
   return rarityItems[source:NextInteger(1, #rarityItems)]
end

return LootConstants
