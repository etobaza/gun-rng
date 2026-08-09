--[[
  UIController

  Description:
  Handles client UI state and screens

  Author:
  @SixthAtom

  Date:
  13-03-2026
]]

local UIController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIConstants = require(ReplicatedStorage.Client.UI.UIConstants)
local Stack = require(ReplicatedStorage.Shared.Classes.Stack)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local BASE_STATE = UIConstants.BaseState

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type UICallback = ((...any) -> ())?

type UIStateCallbacks = { Open: UICallback, Close: UICallback, Minimize: UICallback, Maximize: UICallback }

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local uiStack: Stack.Stack<string> = Stack.new()
local registeredCallbacks: { [string]: UIStateCallbacks } = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function maximizeCurrent(...)
	local current = uiStack:Peek()
	if not current then
		return
	end

	local callbacks = registeredCallbacks[current]
	if callbacks and callbacks.Maximize then
		callbacks.Maximize(...)
	end
end

local function closeInternal(name: string, shouldMaximize: boolean, ...)
	if name == BASE_STATE then
		return
	end

	local current = UIController.getCurrent()
	local removedIndex = uiStack:Find(name)
	if not removedIndex then
		return
	end

	local wasCurrent = current == name
	uiStack:Remove(name)

	local callbacks = registeredCallbacks[name]
	if callbacks and callbacks.Close then
		callbacks.Close(...)
	end

	if shouldMaximize and wasCurrent then
		maximizeCurrent(...)
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function UIController.registerCallbacks(name: string, callbacks: UIStateCallbacks)
	assert(registeredCallbacks[name] == nil, `Already callbacks registered with name {name}`)
	registeredCallbacks[name] = callbacks
end

function UIController.getCurrent(): string?
	return uiStack:Peek()
end

function UIController.isOpen(name: string)
	return uiStack:Find(name) ~= nil
end

function UIController.open(name: string, ...)
	local current = UIController.getCurrent()

	if current == name then
		return
	end

	assert(name ~= BASE_STATE, `{BASE_STATE} cannot be opened through UIController.open`)

	local existingIndex = uiStack:Find(name)

	if current then
		local currentCallbacks = registeredCallbacks[current]
		if currentCallbacks and currentCallbacks.Minimize then
			currentCallbacks.Minimize()
		end
	end

	if existingIndex then
		-- Re-insert into stack
		uiStack:Remove(name)
		uiStack:Push(name)

		local callbacks = registeredCallbacks[name]
		if callbacks and callbacks.Maximize then
			callbacks.Maximize(...)
		end

		return
	end

	uiStack:Push(name)

	local callbacks = registeredCallbacks[name]
	if callbacks and callbacks.Open then
		callbacks.Open(...)
	else
		warn(`No open callback found for State '{name}'`)
	end
end

function UIController.close(name: string, ...)
	closeInternal(name, true, ...)
end

function UIController.closeTo(name: string, ...)
	while uiStack:Peek() and uiStack:Peek() ~= name do
		local current = uiStack:Peek()
		if not current or current == BASE_STATE then
			break
		end

		closeInternal(current, false, ...)
	end

	if uiStack:Peek() == name then
		maximizeCurrent(...)
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function UIController.init() end

function UIController.start() end

function UIController.test() end

return UIController
