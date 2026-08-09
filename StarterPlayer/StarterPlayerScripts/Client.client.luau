local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local CLIENT = ReplicatedStorage.Client

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer

-------------------------------------------------------------------------------
-- LOGIC
-------------------------------------------------------------------------------

do
	local start = os.clock()

	-- Load interfaces
	local interfaces: Folder = ReplicatedStorage:WaitForChild("__INTERFACES")
	for _, v in interfaces:GetChildren() do
		v:Clone().Parent = player.PlayerGui
	end

	-- Require modules
	local modules: { { Name: string, Module: any } } = {}
	local folderOrder = { CLIENT.Core, CLIENT.Controllers, CLIENT.UI }

	for _, folder in folderOrder do
		for _, module in next, folder:QueryDescendants("ModuleScript") do
			if not (string.find(module.Name, "Controller") or string.find(module.Name, "Screen")) then
				continue
			end

			table.insert(modules, { Name = module.Name, Module = require(module) })
		end
	end

	-- Run .init
	for _, m in next, modules do
		if m.Module.init then
			m.Module.init()
			m.Module.init = nil
		end
	end

	-- Run .start
	for _, m in next, modules do
		if m.Module.start then
			task.spawn(m.Module.start)
			m.Module.start = nil
		end
	end

	-- Run studio/unit .test
	if RunService:IsStudio() then
		for _, m in next, modules do
			if m.Module.test then
				task.spawn(m.Module.test)
				m.Module.test = nil
			end
		end
	end

	print(`Hello {player.DisplayName}, welcome!`)
	print(string.format("✅ Client loaded in %.6f seconds", os.clock() - start))
end
