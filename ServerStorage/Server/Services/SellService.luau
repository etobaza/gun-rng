local SellService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local EconomyConstants = require(ReplicatedStorage.Shared.Constants.EconomyConstants)
local ItemConstants = require(ReplicatedStorage.Shared.Constants.ItemConstants)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local ResponseCodes = require(ReplicatedStorage.Shared.Networking.ResponseCodes)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local SimpleRemotesUtil = require(ReplicatedStorage.Shared.Networking.SimpleRemotesUtil)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)
local EconomyService = require(ServerStorage.Server.Core.EconomyService)
local ItemService = require(ServerStorage.Server.Core.ItemService)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

local EVENT_CODES = RemoteCodes.Sell.Events
local FUNCTION_CODES = RemoteCodes.Sell.Functions
local VALUE_MULTIPLIER_PER_LEVEL = 0.1
local INTERACTION_TOLERANCE = 5

local sellRemoteEvent = SimpleRemotes.getEvent("Sell")
local sellRemoteFunction = SimpleRemotes.getFunction("Sell")

local sellInteraction: BasePart?
local sellPrompt: ProximityPrompt?

local function findSellStand(): (BasePart?, ProximityPrompt?)
   local world = workspace:FindFirstChild("World")
   local stand = world and world:FindFirstChild("SellStand")
   local interaction = stand and stand:FindFirstChild("Interaction")
   local prompt = interaction and interaction:FindFirstChildOfClass("ProximityPrompt")

   return if interaction and interaction:IsA("BasePart") then interaction else nil, prompt
end

local function isNearStand(player: Player): boolean
   if not (sellInteraction and sellPrompt) then
      return false
   end

   local character = player.Character
   local root = character and (character.PrimaryPart or character:FindFirstChild("HumanoidRootPart"))
   if not root or not root:IsA("BasePart") then
      return false
   end

   return (root.Position - sellInteraction.Position).Magnitude
      <= sellPrompt.MaxActivationDistance + INTERACTION_TOLERANCE
end

local function sellAll(player: Player): (number, number, number)
   if not isNearStand(player) then
      return ResponseCodes.Forbidden, 0, 0
   end

   local inventory = ItemService.getInventory(player)
   local data = PlayerDataService.get(player)
   if not (inventory and data) then
      return ResponseCodes.ServiceUnavailable, 0, 0
   end

   local soldAmount = 0
   local baseValue = 0
   local saleEntries: { { Name: string, Amount: number } } = {}

   for itemName, rawAmount in inventory do
      local item = ItemConstants.getItem(itemName)
      if not (item and item.Category == ItemConstants.Categories.Loot and item.Loot) then
         continue
      end

      local amount = if type(rawAmount) == "number" then math.max(0, math.floor(rawAmount)) else 0
      if amount <= 0 then
         continue
      end

      soldAmount += amount
      baseValue += item.Loot.SellValue * amount
      table.insert(saleEntries, { Name = itemName, Amount = amount })
   end

   if soldAmount == 0 then
      return ResponseCodes.Ok, 0, 0
   end

   local valueLevel = data.Progression.Upgrades.ValueMultiplier
   local cashEarned = math.floor(baseValue * (1 + valueLevel * VALUE_MULTIPLIER_PER_LEVEL))

   for _, entry in saleEntries do
      ItemService.consumeItem(player, entry.Name, entry.Amount)
   end

   EconomyService.transact(player, EconomyConstants.Currencies.Cash, cashEarned)
   return ResponseCodes.Ok, soldAmount, cashEarned
end

local function loadRemotes()
   SimpleRemotesUtil.bindRemoteFunctionActions(sellRemoteFunction, {
      [FUNCTION_CODES.SellAll] = sellAll,
   }, SimpleRemotesUtil.DecodeActionBuffer)
end

function SellService.init()
   loadRemotes()
end

function SellService.start()
   sellInteraction, sellPrompt = findSellStand()
   if not sellPrompt then
      warn("SellService requires Workspace.World.SellStand.Interaction.ProximityPrompt")
      return
   end

   sellPrompt.Triggered:Connect(function(player: Player)
      sellRemoteEvent:FireClient(player, BufferUtil.construct({ { Type = "U8", Value = EVENT_CODES.Open } }))
   end)
end

return SellService
