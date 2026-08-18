local IndexController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataController = require(ReplicatedStorage.Client.Core.PlayerDataController)
local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local ItemConstants = require(ReplicatedStorage.Shared.Constants.ItemConstants)
local LootConstants = require(ReplicatedStorage.Shared.Constants.LootConstants)
local IndexUtil = require(ReplicatedStorage.Shared.Utils.IndexUtil)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type ChangedTask = (discoveredCount: number) -> ()
type NewDiscoveryTask = (itemName: string) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local discovered: IndexUtil.DiscoverySet = {}
local discoveredCount = 0
local loaded = false

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

IndexController.ChangedTasks = TasksList.new() :: TasksList.TasksList<ChangedTask>
IndexController.NewDiscoveryTasks = TasksList.new() :: TasksList.TasksList<NewDiscoveryTask>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function applySnapshot(b: buffer, notifyNewDiscoveries: boolean)
   local nextDiscovered, nextCount = IndexUtil.decodeDiscoveredLoot(b)

   if notifyNewDiscoveries then
      for hash in nextDiscovered do
         if discovered[hash] then
            continue
         end

         local item = ItemConstants.getItemFromHash(hash)
         if item and item.Category == ItemConstants.Categories.Loot then
            IndexController.NewDiscoveryTasks:Execute("parallel", item.Name)
         end
      end
   end

   discovered = nextDiscovered
   discoveredCount = nextCount
   loaded = true
   IndexController.ChangedTasks:Execute("parallel", discoveredCount)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function IndexController.isLoaded(): boolean
   return loaded
end

function IndexController.isDiscovered(itemName: string): boolean
   return discovered[ItemConstants.getItemHash(itemName)] == true
end

function IndexController.getDiscoveredCount(): number
   return discoveredCount
end

function IndexController.getTotalCount(): number
   return #LootConstants.Items
end

function IndexController.getLuckPercent(): number
   return LootConstants.getIndexLuckPercent(discoveredCount)
end

function IndexController.getNextMilestone(): LootConstants.IndexMilestone?
   return LootConstants.getNextIndexMilestone(discoveredCount)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function IndexController.init()
   PlayerDataController.UpdatedTasks:Add(function(index, value, path)
      if path[1] ~= "Index" or index ~= "DiscoveredLoot" or typeof(value) ~= "buffer" then
         return
      end

      applySnapshot(value, true)
   end)

   PlayerDataController.getAsync(function(data)
      applySnapshot(data.Index.DiscoveredLoot, false)
   end)
end

return IndexController
