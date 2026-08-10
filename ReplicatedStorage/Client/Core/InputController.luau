--[[
  InputController

  Description:
  Handles client input for mobile, desktop and console

  Author:
  @SixthAtom

  Date:
  13-04-2026
]]

local InputController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local InputScreen = require(ReplicatedStorage.Client.UI.Screens.InputScreen)
local UIConstants = require(ReplicatedStorage.Client.UI.UIConstants)
local UIController = require(ReplicatedStorage.Client.UI.UIController)
local Counter = require(ReplicatedStorage.Shared.Classes.Counter)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type Binding = Enum.KeyCode | Enum.UserInputType

type MobileButtonProps = InputScreen.MobileButtonProps

type InputOptions = {
	RequiresHUD: boolean?,
	RequiresAlive: boolean?,
	OverrideGameInput: boolean?,
	MobileButton: MobileButtonProps?,
}

type RegisteredInput = {
	RegistrationOrder: number,

	DesktopBinding: Binding?,
	ConsoleBinding: Binding?,

	Handler: (state: Enum.UserInputState) -> (),
	Options: InputOptions?,
	Enabled: boolean,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local registeredInputs: { [string]: RegisteredInput } = {}
local bindingToActionIds: { [Binding]: { string } } = {}
local activeActionByBindingToken: { [string]: { [string]: true } } = {}

local registrationOrderCounter = Counter.new()

local player = Players.LocalPlayer

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function addInputToActionId(binding: Binding, actionId: string)
	if not bindingToActionIds[binding] then
		bindingToActionIds[binding] = {}
	end

	local actionIds = bindingToActionIds[binding]
	if not table.find(actionIds, actionId) then
		table.insert(actionIds, actionId)

		table.sort(actionIds, function(a, b)
			return registeredInputs[a].RegistrationOrder < registeredInputs[b].RegistrationOrder
		end)
	end
end

local function removeInputFromActionId(binding: Binding, actionId: string)
	if not bindingToActionIds[binding] then
		return
	end

	local index = table.find(bindingToActionIds[binding], actionId)
	if index then
		table.remove(bindingToActionIds[binding], index)
	end

	if #bindingToActionIds[binding] == 0 then
		bindingToActionIds[binding] = nil
	end
end

local function inputObjectToBinding(inputObject: InputObject): Binding?
	if inputObject.KeyCode ~= Enum.KeyCode.None then
		return inputObject.KeyCode
	end

	local userInputType = inputObject.UserInputType
	if userInputType ~= Enum.UserInputType.None then
		return userInputType
	end

	return nil
end

local function markBegin(binding: Binding, actionId: string)
	local token = tostring(binding)

	local active = activeActionByBindingToken[token]
	if not active then
		active = {}
		activeActionByBindingToken[token] = active
	end
	active[actionId] = true
end

local function tryConsumeEnd(binding: Binding, actionId: string): boolean
	local token = tostring(binding)

	local active = activeActionByBindingToken[token]
	if not active or not active[actionId] then
		return false
	end

	active[actionId] = nil
	if next(active) == nil then
		activeActionByBindingToken[token] = nil
	end

	return true
end

local function endActionOnAllBindingsIfActive(actionId: string)
	local registeredInput = registeredInputs[actionId]
	if not registeredInput then
		return
	end

	local desktopBinding = registeredInput.DesktopBinding
	if desktopBinding and tryConsumeEnd(desktopBinding, actionId) then
		registeredInput.Handler(Enum.UserInputState.End)
	end

	local consoleBinding = registeredInput.ConsoleBinding
	if consoleBinding and consoleBinding ~= desktopBinding and tryConsumeEnd(consoleBinding, actionId) then
		registeredInput.Handler(Enum.UserInputState.End)
	end
end

local function passesOptions(registeredInput: RegisteredInput): boolean
	local options = registeredInput.Options
	if not options then
		return true
	end

	if options.RequiresHUD then
		local current = UIController.getCurrent()
		if current ~= nil and current ~= UIConstants.BaseState then
			return false
		end
	end

	if options.RequiresAlive ~= false then
		if not PlayersUtil.isAlive(player) then
			return false
		end
	end

	return true
end

local function isBlockedByGameProcessed(registeredInput: RegisteredInput, gameProcessed: boolean): boolean
	if not gameProcessed then
		return false
	end
	local options = registeredInput.Options
	return not (options and options.OverrideGameInput == true)
end

local function syncMobileButtonForAction(actionId: string, registeredInput: RegisteredInput)
	local options = registeredInput.Options
	local mobileButton = options and options.MobileButton
	if not mobileButton then
		InputScreen.removeButton(actionId)
		return
	end

	if registeredInput.Enabled then
		InputScreen.createMobileButton(actionId, mobileButton, registeredInput.Handler)
	else
		InputScreen.removeButton(actionId)
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function InputController.registerInput(
	actionId: string,
	desktopBinding: Binding?,
	consoleBinding: Binding?,
	handler: (state: Enum.UserInputState) -> (),
	options: InputOptions?,
	disabled: boolean?
)
	if registeredInputs[actionId] then
		error(`Input with actionId {actionId} already registered`)
	end

	registeredInputs[actionId] = {
		RegistrationOrder = registrationOrderCounter:Increment(),
		DesktopBinding = desktopBinding,
		ConsoleBinding = consoleBinding,
		Handler = handler,
		Options = options,
		Enabled = disabled ~= true,
	}

	if desktopBinding then
		addInputToActionId(desktopBinding, actionId)
	end

	if consoleBinding and consoleBinding ~= desktopBinding then
		addInputToActionId(consoleBinding, actionId)
	end

	syncMobileButtonForAction(actionId, registeredInputs[actionId])
end

function InputController.unregisterInput(actionId: string)
	local registeredInput = registeredInputs[actionId]
	if not registeredInput then
		return
	end

	endActionOnAllBindingsIfActive(actionId)

	local desktopBinding = registeredInput.DesktopBinding
	if desktopBinding then
		removeInputFromActionId(desktopBinding, actionId)
	end

	local consoleBinding = registeredInput.ConsoleBinding
	if consoleBinding and consoleBinding ~= desktopBinding then
		removeInputFromActionId(consoleBinding, actionId)
	end

	InputScreen.removeButton(actionId)

	registeredInputs[actionId] = nil
end

function InputController.enableInput(actionId: string)
	local registeredInput = registeredInputs[actionId]
	if not registeredInput then
		error(`Input with actionId {actionId} not found`)
	end

	registeredInput.Enabled = true
	syncMobileButtonForAction(actionId, registeredInput)
end

function InputController.enableInputs(actionIds: { string })
	for _, actionId in next, actionIds do
		InputController.enableInput(actionId)
	end
end

function InputController.disableInput(actionId: string)
	local registeredInput = registeredInputs[actionId]
	if not registeredInput then
		error(`Input with actionId {actionId} not found`)
	end

	endActionOnAllBindingsIfActive(actionId)
	registeredInput.Enabled = false
	syncMobileButtonForAction(actionId, registeredInput)
end

function InputController.disableInputs(actionIds: { string })
	for _, actionId in next, actionIds do
		InputController.disableInput(actionId)
	end
end

function InputController.setDesktopBinding(actionId: string, binding: Binding?)
	local registeredInput = registeredInputs[actionId]
	if not registeredInput then
		error(`Input with actionId {actionId} not found`)
	end

	local oldBinding = registeredInput.DesktopBinding
	if oldBinding == binding then
		return
	end

	if oldBinding then
		if tryConsumeEnd(oldBinding, actionId) then
			registeredInput.Handler(Enum.UserInputState.End)
		end
		if oldBinding ~= registeredInput.ConsoleBinding then
			removeInputFromActionId(oldBinding, actionId)
		end
	end

	registeredInput.DesktopBinding = binding

	if binding and binding ~= registeredInput.ConsoleBinding then
		addInputToActionId(binding, actionId)
	end
end

function InputController.setConsoleBinding(actionId: string, binding: Binding?)
	local registeredInput = registeredInputs[actionId]
	if not registeredInput then
		error(`Input with actionId {actionId} not found`)
	end

	local oldBinding = registeredInput.ConsoleBinding
	if oldBinding == binding then
		return
	end

	if oldBinding then
		if tryConsumeEnd(oldBinding, actionId) then
			registeredInput.Handler(Enum.UserInputState.End)
		end
		if oldBinding ~= registeredInput.DesktopBinding then
			removeInputFromActionId(oldBinding, actionId)
		end
	end

	registeredInput.ConsoleBinding = binding

	if binding and binding ~= registeredInput.DesktopBinding then
		addInputToActionId(binding, actionId)
	end
end

function InputController.setBindings(actionId: string, desktopBinding: Binding?, consoleBinding: Binding?)
	local registeredInput = registeredInputs[actionId]
	if not registeredInput then
		error(`Input with actionId {actionId} not found`)
	end

	endActionOnAllBindingsIfActive(actionId)

	local oldDesktopBinding = registeredInput.DesktopBinding
	if oldDesktopBinding then
		removeInputFromActionId(oldDesktopBinding, actionId)
	end

	local oldConsoleBinding = registeredInput.ConsoleBinding
	if oldConsoleBinding and oldConsoleBinding ~= oldDesktopBinding then
		removeInputFromActionId(oldConsoleBinding, actionId)
	end

	registeredInput.DesktopBinding = desktopBinding
	registeredInput.ConsoleBinding = consoleBinding

	if desktopBinding then
		addInputToActionId(desktopBinding, actionId)
	end

	if consoleBinding and consoleBinding ~= desktopBinding then
		addInputToActionId(consoleBinding, actionId)
	end
end

function InputController.getBindings(actionId: string): (Binding?, Binding?)
	local registeredInput = registeredInputs[actionId]
	if not registeredInput then
		return
	end

	return registeredInput.DesktopBinding, registeredInput.ConsoleBinding
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function InputController.init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		local binding = inputObjectToBinding(input)
		local actionIds = binding and bindingToActionIds[binding]
		if not actionIds then
			return
		end

		for _, actionId in next, actionIds do
			local registeredInput = registeredInputs[actionId]

			if not registeredInput or not registeredInput.Enabled then
				continue
			end
			if isBlockedByGameProcessed(registeredInput, gameProcessed) then
				continue
			end
			if not passesOptions(registeredInput) then
				continue
			end

			registeredInput.Handler(Enum.UserInputState.Begin)
			markBegin(binding :: Binding, actionId)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		local binding = inputObjectToBinding(input)
		local actionIds = binding and bindingToActionIds[binding]
		if not actionIds then
			return
		end

		for _, actionId in next, actionIds do
			local registeredInput = registeredInputs[actionId]
			if not registeredInput then
				continue
			end
			if not tryConsumeEnd(binding :: Binding, actionId) then
				continue
			end

			registeredInput.Handler(Enum.UserInputState.End)
		end
	end)
end

-- function InputController.start() end

-- function InputController.test() end

return InputController
