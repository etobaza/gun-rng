local LootHUDScreen = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemController = require(ReplicatedStorage.Client.Core.ItemController)
local PlayerDataController = require(ReplicatedStorage.Client.Core.PlayerDataController)
local ItemConstants = require(ReplicatedStorage.Shared.Constants.ItemConstants)
local LootConstants = require(ReplicatedStorage.Shared.Constants.LootConstants)
local GeneralUtil = require(ReplicatedStorage.Shared.Utils.GeneralUtil)

local cashLabel: TextLabel
local lootLabel: TextLabel
local dropToast: Frame
local rarityLabel: TextLabel
local itemLabel: TextLabel
local toastSequence = 0

local function updateCash(cash: number)
   cashLabel.Text = "$" .. GeneralUtil.formatNumber(cash)
end

local function updateLootCount()
   local total = 0
   for itemName, rawAmount in ItemController.getInventory() do
      local item = ItemConstants.getItem(itemName)
      if item and item.Category == ItemConstants.Categories.Loot and type(rawAmount) == "number" then
         total += math.max(0, rawAmount)
      end
   end

   lootLabel.Text = "LOOT  " .. GeneralUtil.formatNumber(total) .. " " .. (if total == 1 then "item" else "items")
end

local function showDrop(itemName: string)
   local loot = LootConstants.getItem(itemName)
   if not loot then
      return
   end

   local rarity = LootConstants.RarityData[loot.Rarity]
   toastSequence += 1
   local sequence = toastSequence

   rarityLabel.Text = string.upper(loot.Rarity)
   rarityLabel.TextColor3 = rarity.Color
   itemLabel.Text = loot.DisplayName
   dropToast.Visible = true

   task.delay(2.5, function()
      if sequence == toastSequence then
         dropToast.Visible = false
      end
   end)
end

function LootHUDScreen.init()
   local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
   local screen = playerGui:WaitForChild("LootHUD") :: ScreenGui
   local panel = screen:WaitForChild("Panel") :: Frame

   cashLabel = panel:WaitForChild("CashLabel") :: TextLabel
   lootLabel = panel:WaitForChild("LootLabel") :: TextLabel
   dropToast = screen:WaitForChild("DropToast") :: Frame
   rarityLabel = dropToast:WaitForChild("RarityLabel") :: TextLabel
   itemLabel = dropToast:WaitForChild("ItemLabel") :: TextLabel

   local data = PlayerDataController.get()
   updateCash(data.Currencies.Cash)
   updateLootCount()

   PlayerDataController.UpdatedTasks:Add(function(index, value, path)
      if path[1] == "Currencies" and index == "Cash" and type(value) == "number" then
         updateCash(value)
      end
   end)

   ItemController.InventoryLoadedTasks:Add(updateLootCount)
   ItemController.ItemGrantedTasks:Add(function(itemName)
      updateLootCount()
      showDrop(itemName)
   end)
   ItemController.ItemConsumedTasks:Add(updateLootCount)
end

return LootHUDScreen
