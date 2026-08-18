local SellScreen = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIConstants = require(ReplicatedStorage.Client.UI.UIConstants)
local UIController = require(ReplicatedStorage.Client.UI.UIController)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local ResponseCodes = require(ReplicatedStorage.Shared.Networking.ResponseCodes)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local SimpleRemotesUtil = require(ReplicatedStorage.Shared.Networking.SimpleRemotesUtil)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)
local GeneralUtil = require(ReplicatedStorage.Shared.Utils.GeneralUtil)

local STATE = UIConstants.States.Sell
local EVENT_CODES = RemoteCodes.Sell.Events
local FUNCTION_CODES = RemoteCodes.Sell.Functions

local sellRemoteEvent = SimpleRemotes.getEvent("Sell")
local sellRemoteFunction = SimpleRemotes.getFunction("Sell")

local screen: ScreenGui
local sellAllButton: TextButton
local statusLabel: TextLabel
local busy = false

local function setVisible(visible: boolean)
   screen.Enabled = visible
end

local function close()
   UIController.close(STATE)
end

local function sellAll()
   if busy then
      return
   end

   busy = true
   sellAllButton.Active = false
   sellAllButton.Text = "SELLING..."

   local request = BufferUtil.construct({ { Type = "U8", Value = FUNCTION_CODES.SellAll } })
   local responseCode, soldAmount, cashEarned = sellRemoteFunction:InvokeServer(request)

   if responseCode == ResponseCodes.Ok then
      statusLabel.Text = if soldAmount > 0
         then "Sold " .. GeneralUtil.formatNumber(soldAmount) .. (if soldAmount == 1
            then " item for $"
            else " items for $") .. GeneralUtil.formatNumber(cashEarned)
         else "You do not have any loot to sell."
   else
      statusLabel.Text = "Move closer to the Sell stand and try again."
   end

   sellAllButton.Text = "SELL ALL"
   sellAllButton.Active = true
   busy = false
end

local function loadRemote()
   SimpleRemotesUtil.bindRemoteEventActions(sellRemoteEvent, {
      [EVENT_CODES.Open] = function()
         UIController.open(STATE)
      end,
   }, SimpleRemotesUtil.DecodeActionBuffer)
end

function SellScreen.init()
   local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
   screen = playerGui:WaitForChild("SellUI") :: ScreenGui

   local main = screen:WaitForChild("Main") :: Frame
   local header = main:WaitForChild("Header") :: Frame
   local content = main:WaitForChild("Content") :: Frame
   sellAllButton = content:WaitForChild("SellAllButton") :: TextButton
   statusLabel = content:WaitForChild("StatusLabel") :: TextLabel

   UIController.registerCallbacks(STATE, {
      Open = function()
         setVisible(true)
      end,
      Close = function()
         setVisible(false)
      end,
      Minimize = function()
         setVisible(false)
      end,
      Maximize = function()
         setVisible(true)
      end,
   })

   local closeButton = header:WaitForChild("CloseButton") :: TextButton
   local dimButton = screen:WaitForChild("Dim") :: TextButton
   closeButton.Activated:Connect(close)
   dimButton.Activated:Connect(close)
   sellAllButton.Activated:Connect(sellAll)
   loadRemote()
end

return SellScreen
