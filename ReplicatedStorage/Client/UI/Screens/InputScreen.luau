--[[
  InputScreen

  Description:
  Displays and handles mobile input buttons

  Author:
  @SixthAtom

  Date:
  14-04-2026
]]

local InputScreen = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ConnectionsList = require(ReplicatedStorage.Shared.Classes.ConnectionsList)
local DeviceUtil = require(ReplicatedStorage.Shared.Utils.DeviceUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type MobileButtonProps = {
	SizeMultiplier: number,
	PositionOffsetScalar: Vector2,

	Radius: UDim,
	IsToggle: boolean,
	ButtonGuiObject: GuiButton?,
}

type Handler = (Enum.UserInputState) -> ()

type MobileEntry = {
	Button: GuiButton,
	BaseVisible: boolean,
	OwnsGuiObject: boolean,
	ButtonProps: MobileButtonProps,
}

type PendingMobileButton = {
	Handler: Handler,
	ButtonProps: MobileButtonProps,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer

local inputUI = player.PlayerGui.InputUI

local mobileContainer = inputUI.Mobile

local mobileEntries: { [string]: MobileEntry } = {}
local pendingMobileButtons: { [string]: PendingMobileButton } = {}

local cleanupLists = {
	Mobile = {},
}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function cleanupEntry(actionId: string)
	local entry = mobileEntries[actionId]
	local cleanupList = cleanupLists.Mobile[actionId]
	if cleanupList then
		cleanupList:Destroy()
		cleanupLists.Mobile[actionId] = nil
	end

	if entry then
		if entry.OwnsGuiObject then
			if entry.Button.Parent then
				entry.Button:Destroy()
			end
		else
			entry.Button.Visible = false
		end
	end
end

local function updateMobileVisibility()
	local isMobileInput = DeviceUtil.isMobile()

	mobileContainer.Visible = isMobileInput
	for _, entry in mobileEntries do
		entry.Button.Visible = entry.BaseVisible and isMobileInput
	end
end

local function getJumpButton(): GuiButton?
	local touchUI = player.PlayerGui:FindFirstChild("TouchGui")
	if not touchUI then
		return nil
	end

	local touchControlFrame = touchUI:FindFirstChild("TouchControlFrame")
	if not touchControlFrame then
		return nil
	end

	local jumpButton = touchControlFrame:FindFirstChild("JumpButton")
	if jumpButton and jumpButton:IsA("GuiButton") then
		return jumpButton
	end

	return nil
end

local function applyJumpButtonLayout(button: GuiButton, buttonProps: MobileButtonProps, jumpButton: GuiButton)
	local jumpAbsoluteSize = jumpButton.AbsoluteSize
	local jumpPosition = jumpButton.Position

	local scaledSize = jumpAbsoluteSize * buttonProps.SizeMultiplier

	button.Size = UDim2.fromOffset(math.round(scaledSize.X), math.round(scaledSize.Y))
	button.Position = UDim2.new(
		jumpPosition.X.Scale,
		jumpPosition.X.Offset + jumpAbsoluteSize.X * buttonProps.PositionOffsetScalar.X,
		jumpPosition.Y.Scale,
		jumpPosition.Y.Offset + jumpAbsoluteSize.Y * buttonProps.PositionOffsetScalar.Y
	)
end

local function refreshRegisteredButtonLayouts()
	local jumpButton = getJumpButton()
	if not jumpButton then
		return
	end

	for _, entry in mobileEntries do
		applyJumpButtonLayout(entry.Button, entry.ButtonProps, jumpButton)
	end
end

local function flushPendingMobileButtons()
	if next(pendingMobileButtons) == nil then
		return
	end

	if not getJumpButton() then
		return
	end

	for actionId, pending in pendingMobileButtons do
		InputScreen.createMobileButton(actionId, pending.ButtonProps, pending.Handler)
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function InputScreen.createMobileButton(actionId: string, buttonProps: MobileButtonProps, handler: Handler)
	cleanupEntry(actionId)
	mobileEntries[actionId] = nil

	local button: GuiButton
	local ownsGuiObject = false

	if buttonProps.ButtonGuiObject then
		button = buttonProps.ButtonGuiObject
	else
		local presetButton = mobileContainer:FindFirstChild(actionId)
		button = if presetButton and presetButton:IsA("GuiButton") then presetButton else nil

		local robloxJumpButton = getJumpButton()
		if not robloxJumpButton then
			pendingMobileButtons[actionId] = {
				Handler = handler,
				ButtonProps = buttonProps,
			}
			return
		end

		if not button then
			local tempButton = mobileContainer:FindFirstChild("TEMP_BUTTON")
			if tempButton and tempButton:IsA("GuiButton") then
				button = tempButton:Clone()
				button.Name = actionId
				button.Parent = mobileContainer
				ownsGuiObject = true
			else
				warn(`InputScreen: no preset mobile button found for actionId '{actionId}'`)
				return
			end
		end

		applyJumpButtonLayout(button, buttonProps, robloxJumpButton)

		local corner = button:FindFirstChild("UICorner", true)
		if corner and corner:IsA("UICorner") then
			corner.CornerRadius = buttonProps.Radius
		end
	end

	pendingMobileButtons[actionId] = nil
	button.Visible = true

	local cleanupList = ConnectionsList.new()
	local toggleState = false

	if buttonProps.IsToggle then
		cleanupList:Add(button.Activated:Connect(function()
			toggleState = not toggleState
			handler(toggleState and Enum.UserInputState.Begin or Enum.UserInputState.End)
		end))
	else
		cleanupList:Add(button.InputBegan:Connect(function(inputObject: InputObject)
			if
				inputObject.UserInputType ~= Enum.UserInputType.Touch
				and inputObject.UserInputType ~= Enum.UserInputType.MouseButton1
			then
				return
			end

			handler(Enum.UserInputState.Begin)
		end))

		cleanupList:Add(button.InputEnded:Connect(function(inputObject: InputObject)
			if
				inputObject.UserInputType ~= Enum.UserInputType.Touch
				and inputObject.UserInputType ~= Enum.UserInputType.MouseButton1
			then
				return
			end

			handler(Enum.UserInputState.End)
		end))
	end

	mobileEntries[actionId] = {
		Button = button,
		BaseVisible = if ownsGuiObject then true else button.Visible,
		OwnsGuiObject = ownsGuiObject,
		ButtonProps = buttonProps,
	}
	cleanupLists.Mobile[actionId] = cleanupList

	updateMobileVisibility()
end

function InputScreen.removeButton(actionId: string)
	cleanupEntry(actionId)
	mobileEntries[actionId] = nil
	pendingMobileButtons[actionId] = nil
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function InputScreen.init()
	DeviceUtil.onDeviceChanged(function()
		updateMobileVisibility()
		refreshRegisteredButtonLayouts()
		flushPendingMobileButtons()
	end)

	player.PlayerGui.ChildAdded:Connect(function(child)
		if child:IsA("ScreenGui") and child.Name == "TouchGui" then
			refreshRegisteredButtonLayouts()
			flushPendingMobileButtons()
		end
	end)
end

function InputScreen.start() end

function InputScreen.test() end

return InputScreen
