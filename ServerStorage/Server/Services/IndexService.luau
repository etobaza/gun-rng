local IndexService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ItemService = require(ServerStorage.Server.Core.ItemService)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)
local ItemConstants = require(ReplicatedStorage.Shared.Constants.ItemConstants)
local LootConstants = require(ReplicatedStorage.Shared.Constants.LootConstants)
local IndexUtil = require(ReplicatedStorage.Shared.Utils.IndexUtil)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local discoveriesByPlayer: { [Player]: IndexUtil.DiscoverySet } = {}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getDiscoveries(player: Player): IndexUtil.DiscoverySet?
   local discoveries = discoveriesByPlayer[player]
   if discoveries then
      return discoveries
   end

   local data = PlayerDataService.get(player)
   if not data then
      return nil
   end

   discoveries = IndexUtil.decodeDiscoveredLoot(data.Index.DiscoveredLoot)
   discoveriesByPlayer[player] = discoveries
   return discoveries
end

local function saveDiscoveries(player: Player, discoveries: IndexUtil.DiscoverySet)
   local data = PlayerDataService.get(player)
   if not data then
      return
   end

   data.Index.DiscoveredLoot = IndexUtil.encodeDiscoveredLoot(discoveries)
end

local function discoverLoot(player: Player, itemName: string): boolean
   local loot = LootConstants.getItem(itemName)
   if not loot then
      return false
   end

   local discoveries = getDiscoveries(player)
   if not discoveries then
      return false
   end

   local hash = ItemConstants.getItemHash(itemName)
   if discoveries[hash] then
      return false
   end

   discoveries[hash] = true
   saveDiscoveries(player, discoveries)
   return true
end

local function onInventoryLoaded(player: Player, inventory: { [string]: number | true })
   local discoveries = getDiscoveries(player)
   if not discoveries then
      return
   end

   local changed = false
   for itemName, rawAmount in inventory do
      local item = ItemConstants.getItem(itemName)
      if not item or item.Category ~= ItemConstants.Categories.Loot then
         continue
      end

      local hasItem = rawAmount == true or (type(rawAmount) == "number" and rawAmount > 0)
      local hash = ItemConstants.getItemHash(itemName)
      if not hasItem or discoveries[hash] then
         continue
      end

      discoveries[hash] = true
      changed = true
   end

   if changed then
      saveDiscoveries(player, discoveries)
   end
end

local function onProfileRemoved(player: Player)
   discoveriesByPlayer[player] = nil
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function IndexService.getLuckMultiplier(player: Player): number
   local discoveries = getDiscoveries(player)
   if not discoveries then
      return 1
   end

   local discoveredCount = 0
   for _ in discoveries do
      discoveredCount += 1
   end

   return 1 + LootConstants.getIndexLuckPercent(discoveredCount) / 100
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function IndexService.init()
   ItemService.InventoryLoadedTasks:Add(onInventoryLoaded)
   ItemService.ItemGrantedTasks:Add(function(player: Player, itemName: string)
      discoverLoot(player, itemName)
   end)
   PlayerDataService.ProfileRemovedTasks:Add(onProfileRemoved)
end

return IndexService
