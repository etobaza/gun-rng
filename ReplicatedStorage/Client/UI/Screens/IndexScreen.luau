local IndexScreen = {}

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local IndexController = require(ReplicatedStorage.Client.Core.IndexController)
local UIConstants = require(ReplicatedStorage.Client.UI.UIConstants)
local UIController = require(ReplicatedStorage.Client.UI.UIController)
local LootConstants = require(ReplicatedStorage.Shared.Constants.LootConstants)
local GeneralUtil = require(ReplicatedStorage.Shared.Utils.GeneralUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local STATE = UIConstants.States.Index
local ALL_TAB_KEY = "All"
local MOBILE_BREAKPOINT = 760
local TABLET_BREAKPOINT = 1_000

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local screen: ScreenGui
local dim: TextButton
local openButton: TextButton
local newBadge: Frame
local main: Frame
local sizeConstraint: UISizeConstraint
local header: Frame
local titleLabel: TextLabel
local subtitleLabel: TextLabel
local discoveryLabel: TextLabel
local luckLabel: TextLabel
local closeButton: TextButton
local tabs: ScrollingFrame
local tabTemplate: TextButton
local body: Frame
local grid: ScrollingFrame
local gridLayout: UIGridLayout
local cardTemplate: ImageButton
local details: Frame
local detailsBackButton: TextButton
local detailsIcon: ImageLabel
local detailsPlaceholder: TextLabel
local detailsName: TextLabel
local detailsRarity: TextLabel
local detailsDescription: TextLabel
local detailsSellValue: TextLabel
local detailsStatus: TextLabel
local milestone: Frame
local milestoneTitle: TextLabel
local milestoneProgressFill: Frame
local milestoneProgressLabel: TextLabel
local milestoneReward: TextLabel

local selectedRarity: LootConstants.Rarity? = nil
local selectedLoot: LootConstants.LootDefinition? = nil
local compactLayout = false
local showingCompactDetails = false
local tabButtons: { [string]: TextButton } = {}
local cardButtons: { [string]: ImageButton } = {}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function setOverlayVisible(visible: boolean)
   dim.Visible = visible
   main.Visible = visible
   openButton.Visible = not visible

   if visible then
      newBadge.Visible = false
   end
end

local function close()
   UIController.close(STATE)
end

local function getRarityColor(rarity: LootConstants.Rarity): Color3
   return LootConstants.RarityData[rarity].Color
end

local function countDiscovered(items: { LootConstants.LootDefinition }): number
   local count = 0
   for _, loot in items do
      if IndexController.isDiscovered(loot.Name) then
         count += 1
      end
   end

   return count
end

local function updateHeaderAndMilestone()
   local discoveredCount = IndexController.getDiscoveredCount()
   local totalCount = IndexController.getTotalCount()
   local luckPercent = IndexController.getLuckPercent()
   local nextMilestone = IndexController.getNextMilestone()

   discoveryLabel.Text = `{discoveredCount} / {totalCount} DISCOVERED`
   luckLabel.Text = `INDEX LUCK +{luckPercent}%`

   if nextMilestone then
      local progress = math.clamp(discoveredCount / nextMilestone.RequiredDiscoveries, 0, 1)
      milestoneTitle.Text = `NEXT MILESTONE: {nextMilestone.RequiredDiscoveries} UNIQUE LOOT`
      milestoneProgressLabel.Text = `{discoveredCount} / {nextMilestone.RequiredDiscoveries}`
      milestoneReward.Text = `REWARD: +{nextMilestone.RewardPercent}% LUCK`
      milestoneProgressFill.Size = UDim2.fromScale(progress, 1)
      return
   end

   milestoneTitle.Text = "COLLECTION COMPLETE"
   milestoneProgressLabel.Text = `{discoveredCount} / {totalCount}`
   milestoneReward.Text = `INDEX LUCK: +{luckPercent}%`
   milestoneProgressFill.Size = UDim2.fromScale(1, 1)
end

local function updateDetails(loot: LootConstants.LootDefinition)
   selectedLoot = loot

   local discovered = IndexController.isDiscovered(loot.Name)
   local color = getRarityColor(loot.Rarity)
   local hasIcon = discovered and loot.Icon ~= nil and loot.Icon ~= ""

   detailsIcon.Image = loot.Icon or ""
   detailsIcon.Visible = hasIcon
   detailsPlaceholder.Visible = not hasIcon
   detailsPlaceholder.Text = if discovered then "◆" else "?"
   detailsPlaceholder.TextColor3 = if discovered then color else Color3.fromRGB(91, 101, 119)
   detailsName.Text = if discovered then loot.DisplayName else "???"
   detailsRarity.Text = string.upper(loot.Rarity)
   detailsRarity.TextColor3 = color
   detailsDescription.Text = if discovered then loot.Description else "Discover this loot to reveal its details."
   detailsSellValue.Text = if discovered then `SELL VALUE  ${GeneralUtil.formatNumber(loot.SellValue)}` else ""
   detailsStatus.Text = if discovered then "DISCOVERED" else "UNDISCOVERED"
   detailsStatus.TextColor3 = if discovered then Color3.fromRGB(77, 221, 128) else Color3.fromRGB(143, 153, 171)

   for itemName, button in cardButtons do
      local stroke = button:FindFirstChildOfClass("UIStroke")
      if stroke then
         stroke.Thickness = if itemName == loot.Name then 3 else 1.5
      end
   end

   if compactLayout then
      showingCompactDetails = true
      grid.Visible = false
      details.Visible = true
      detailsBackButton.Visible = true
      GuiService.SelectedObject = detailsBackButton
   end
end

local function updateGridCellSize()
   if not grid.Visible then
      return
   end

   local columns = if compactLayout then 2 else if main.AbsoluteSize.X < TABLET_BREAKPOINT then 3 else 5
   local gap = gridLayout.CellPadding.X.Offset
   local availableWidth = math.max(1, grid.AbsoluteSize.X - gap * (columns - 1) - 28)
   local cellWidth = math.max(112, availableWidth // columns)
   gridLayout.FillDirectionMaxCells = columns
   gridLayout.CellSize = UDim2.fromOffset(cellWidth, math.round(cellWidth * 1.2))
end

local function getFilteredItems(): { LootConstants.LootDefinition }
   if selectedRarity then
      return LootConstants.getItemsInRarity(selectedRarity)
   end

   return LootConstants.Items
end

local function rebuildCards()
   for _, child in grid:GetChildren() do
      if child:IsA("GuiButton") and child ~= cardTemplate then
         child:Destroy()
      end
   end

   cardButtons = {}
   local filteredItems = getFilteredItems()

   for layoutOrder, loot in filteredItems do
      local discovered = IndexController.isDiscovered(loot.Name)
      local color = getRarityColor(loot.Rarity)
      local button = cardTemplate:Clone()
      button.Name = loot.Name
      button.LayoutOrder = layoutOrder
      button.Visible = true
      button.Parent = grid

      local icon = button:FindFirstChild("Icon") :: ImageLabel
      local placeholder = button:FindFirstChild("Placeholder") :: TextLabel
      local nameLabel = button:FindFirstChild("NameLabel") :: TextLabel
      local rarityLabel = button:FindFirstChild("RarityLabel") :: TextLabel
      local stroke = button:FindFirstChildOfClass("UIStroke")
      local hasIcon = discovered and loot.Icon ~= nil and loot.Icon ~= ""

      icon.Image = loot.Icon or ""
      icon.Visible = hasIcon
      placeholder.Visible = not hasIcon
      placeholder.Text = if discovered then "◆" else "?"
      placeholder.TextColor3 = if discovered then color else Color3.fromRGB(91, 101, 119)
      nameLabel.Text = if discovered then loot.DisplayName else "???"
      rarityLabel.Text = string.upper(loot.Rarity)
      rarityLabel.TextColor3 = color
      if stroke then
         stroke.Color = color
         stroke.Thickness = if selectedLoot and selectedLoot.Name == loot.Name then 3 else 1.5
      end

      button.Activated:Connect(function()
         updateDetails(loot)
      end)
      cardButtons[loot.Name] = button
   end

   if selectedLoot then
      local selectedIsVisible = selectedRarity == nil or selectedLoot.Rarity == selectedRarity
      if selectedIsVisible then
         updateDetails(selectedLoot)
      else
         selectedLoot = nil
      end
   end

   if not selectedLoot and filteredItems[1] then
      updateDetails(filteredItems[1])
      if compactLayout then
         showingCompactDetails = false
         grid.Visible = true
         details.Visible = false
      end
   end

   task.defer(updateGridCellSize)
end

local function updateTabSelection()
   for tabKey, button in tabButtons do
      local isSelected = if selectedRarity then tabKey == selectedRarity else tabKey == ALL_TAB_KEY
      local rarity = if tabKey == ALL_TAB_KEY then nil else tabKey :: LootConstants.Rarity
      local color = if rarity then getRarityColor(rarity) else Color3.fromRGB(255, 226, 112)

      button.BackgroundColor3 = if isSelected then color else Color3.fromRGB(31, 39, 54)
      button.TextColor3 = if isSelected then Color3.fromRGB(17, 21, 29) else color
   end
end

local function selectTab(rarity: LootConstants.Rarity?)
   selectedRarity = rarity
   selectedLoot = nil
   showingCompactDetails = false
   grid.Visible = true
   details.Visible = not compactLayout
   updateTabSelection()
   rebuildCards()
end

local function rebuildTabs()
   for _, child in tabs:GetChildren() do
      if child:IsA("GuiButton") and child ~= tabTemplate then
         child:Destroy()
      end
   end

   tabButtons = {}

   local allButton = tabTemplate:Clone()
   allButton.Name = ALL_TAB_KEY
   allButton.Text = `ALL  {IndexController.getDiscoveredCount()}/{IndexController.getTotalCount()}`
   allButton.LayoutOrder = 0
   allButton.Visible = true
   allButton.Parent = tabs
   allButton.Activated:Connect(function()
      selectTab(nil)
   end)
   tabButtons[ALL_TAB_KEY] = allButton

   for layoutOrder, rarity in LootConstants.RarityOrder do
      local items = LootConstants.getItemsInRarity(rarity)
      local button = tabTemplate:Clone()
      button.Name = rarity
      button.Text = `{string.upper(rarity)}  {countDiscovered(items)}/{#items}`
      button.LayoutOrder = layoutOrder
      button.Visible = true
      button.Parent = tabs
      button.Activated:Connect(function()
         selectTab(rarity)
      end)
      tabButtons[rarity] = button
   end

   updateTabSelection()
end

local function refresh()
   updateHeaderAndMilestone()
   rebuildTabs()
   rebuildCards()
end

local function applyResponsiveLayout()
   local camera = workspace.CurrentCamera
   if not camera then
      return
   end

   compactLayout = camera.ViewportSize.X < MOBILE_BREAKPOINT
   main.Size = if compactLayout then UDim2.fromScale(0.96, 0.92) else UDim2.fromScale(0.88, 0.82)
   sizeConstraint.MinSize = if compactLayout then Vector2.zero else Vector2.new(720, 480)

   if compactLayout then
      openButton.Position = UDim2.new(0, 14, 0.42, 0)
      openButton.Size = UDim2.fromOffset(112, 48)
      header.Size = UDim2.new(1, 0, 0, 74)
      titleLabel.Position = UDim2.fromOffset(16, 7)
      titleLabel.Size = UDim2.new(0.45, -16, 0, 28)
      titleLabel.TextSize = 20
      subtitleLabel.Visible = false
      discoveryLabel.Position = UDim2.fromOffset(16, 37)
      discoveryLabel.Size = UDim2.new(0.48, -16, 0, 25)
      discoveryLabel.TextSize = 11
      luckLabel.Position = UDim2.new(0.48, 0, 0, 37)
      luckLabel.Size = UDim2.new(0.52, -62, 0, 25)
      luckLabel.TextSize = 11
      closeButton.Position = UDim2.new(1, -12, 0.5, 0)
      closeButton.Size = UDim2.fromOffset(40, 40)
      tabs.Position = UDim2.fromOffset(0, 74)
      tabs.Size = UDim2.new(1, 0, 0, 52)
      milestone.Position = UDim2.fromOffset(0, 126)
      milestone.Size = UDim2.new(1, 0, 0, 82)
      body.Position = UDim2.fromOffset(0, 208)
      body.Size = UDim2.new(1, 0, 1, -208)
      grid.Size = UDim2.fromScale(1, 1)
      details.Position = UDim2.fromScale(0, 0)
      details.Size = UDim2.fromScale(1, 1)
      grid.Visible = not showingCompactDetails
      details.Visible = showingCompactDetails
      detailsBackButton.Visible = showingCompactDetails
   else
      showingCompactDetails = false
      openButton.Position = UDim2.new(0, 22, 0.5, -30)
      openButton.Size = UDim2.fromOffset(132, 54)
      header.Size = UDim2.new(1, 0, 0, 84)
      titleLabel.Position = UDim2.fromOffset(22, 10)
      titleLabel.Size = UDim2.fromOffset(220, 32)
      titleLabel.TextSize = 26
      subtitleLabel.Visible = true
      discoveryLabel.Position = UDim2.new(0.48, 0, 0, 18)
      discoveryLabel.Size = UDim2.new(0.22, 0, 0, 48)
      discoveryLabel.TextSize = 15
      luckLabel.Position = UDim2.new(0.7, 0, 0, 18)
      luckLabel.Size = UDim2.new(0.22, -8, 0, 48)
      luckLabel.TextSize = 15
      closeButton.Position = UDim2.new(1, -18, 0.5, 0)
      closeButton.Size = UDim2.fromOffset(46, 46)
      tabs.Position = UDim2.fromOffset(0, 84)
      tabs.Size = UDim2.new(1, 0, 0, 58)
      body.Position = UDim2.fromOffset(0, 142)
      body.Size = UDim2.new(1, 0, 1, -238)
      milestone.Position = UDim2.new(0, 0, 1, -96)
      milestone.Size = UDim2.new(1, 0, 0, 96)
      grid.Size = UDim2.new(0.68, -8, 1, 0)
      details.Position = UDim2.new(0.68, 8, 0, 0)
      details.Size = UDim2.new(0.32, -8, 1, 0)
      grid.Visible = true
      details.Visible = true
      detailsBackButton.Visible = false
   end

   task.defer(updateGridCellSize)
end

local function showGridOnCompact()
   if not compactLayout then
      return
   end

   showingCompactDetails = false
   details.Visible = false
   grid.Visible = true
   task.defer(updateGridCellSize)

   local firstCard = next(cardButtons)
   if firstCard then
      GuiService.SelectedObject = cardButtons[firstCard]
   end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function IndexScreen.init()
   local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
   assert(playerGui, "IndexScreen requires PlayerGui")

   screen = playerGui:FindFirstChild("IndexUI") :: ScreenGui
   assert(screen, "IndexScreen requires IndexUI")
   dim = screen:FindFirstChild("Dim") :: TextButton
   openButton = screen:FindFirstChild("OpenButton") :: TextButton
   newBadge = openButton:FindFirstChild("NewBadge") :: Frame
   main = screen:FindFirstChild("Main") :: Frame
   sizeConstraint = main:FindFirstChildOfClass("UISizeConstraint") :: UISizeConstraint
   header = main:FindFirstChild("Header") :: Frame
   titleLabel = header:FindFirstChild("Title") :: TextLabel
   subtitleLabel = header:FindFirstChild("Subtitle") :: TextLabel
   discoveryLabel = header:FindFirstChild("DiscoveryLabel") :: TextLabel
   luckLabel = header:FindFirstChild("LuckLabel") :: TextLabel
   closeButton = header:FindFirstChild("CloseButton") :: TextButton
   tabs = main:FindFirstChild("Tabs") :: ScrollingFrame
   tabTemplate = tabs:FindFirstChild("TabTemplate") :: TextButton
   body = main:FindFirstChild("Body") :: Frame
   grid = body:FindFirstChild("Grid") :: ScrollingFrame
   gridLayout = grid:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
   cardTemplate = grid:FindFirstChild("CardTemplate") :: ImageButton
   details = body:FindFirstChild("Details") :: Frame
   detailsBackButton = details:FindFirstChild("BackButton") :: TextButton
   detailsIcon = details:FindFirstChild("Icon") :: ImageLabel
   detailsPlaceholder = details:FindFirstChild("Placeholder") :: TextLabel
   detailsName = details:FindFirstChild("NameLabel") :: TextLabel
   detailsRarity = details:FindFirstChild("RarityLabel") :: TextLabel
   detailsDescription = details:FindFirstChild("DescriptionLabel") :: TextLabel
   detailsSellValue = details:FindFirstChild("SellValueLabel") :: TextLabel
   detailsStatus = details:FindFirstChild("StatusLabel") :: TextLabel
   milestone = main:FindFirstChild("Milestone") :: Frame
   milestoneTitle = milestone:FindFirstChild("Title") :: TextLabel
   milestoneProgressFill = milestone:FindFirstChild("ProgressFill", true) :: Frame
   milestoneProgressLabel = milestone:FindFirstChild("ProgressLabel") :: TextLabel
   milestoneReward = milestone:FindFirstChild("RewardLabel") :: TextLabel

   UIController.registerCallbacks(STATE, {
      Open = function()
         setOverlayVisible(true)
         refresh()
         applyResponsiveLayout()
         GuiService.SelectedObject = tabButtons[ALL_TAB_KEY]
      end,
      Close = function()
         setOverlayVisible(false)
      end,
      Minimize = function()
         setOverlayVisible(false)
      end,
      Maximize = function()
         setOverlayVisible(true)
         refresh()
         applyResponsiveLayout()
      end,
   })

   openButton.Activated:Connect(function()
      UIController.open(STATE)
   end)
   dim.Activated:Connect(close)
   closeButton.Activated:Connect(close)
   detailsBackButton.Activated:Connect(showGridOnCompact)

   UserInputService.InputBegan:Connect(function(input, gameProcessed)
      if gameProcessed or UIController.getCurrent() ~= STATE then
         return
      end

      if input.KeyCode ~= Enum.KeyCode.Escape and input.KeyCode ~= Enum.KeyCode.ButtonB then
         return
      end

      if showingCompactDetails then
         showGridOnCompact()
      else
         close()
      end
   end)

   IndexController.ChangedTasks:Add(function()
      refresh()
   end)
   IndexController.NewDiscoveryTasks:Add(function()
      if UIController.getCurrent() ~= STATE then
         newBadge.Visible = true
      end
   end)

   local camera = workspace.CurrentCamera
   if camera then
      camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveLayout)
   end

   setOverlayVisible(false)
   applyResponsiveLayout()
   refresh()
end

return IndexScreen
