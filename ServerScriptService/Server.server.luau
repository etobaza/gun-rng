local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local SERVER = ServerStorage.Server

-------------------------------------------------------------------------------
-- LOGIC
-------------------------------------------------------------------------------

do
	-- This fixes the "Write Marshalled" freeze bug
	if RunService:IsStudio() then
		for _ = 1, 10 do
			local s = Instance.new("Script")
			s.Parent = workspace
			task.delay(math.random(20, 30) / 10, s.Destroy, s)
		end
	end

	local start = os.clock()

	-- Load interfaces
	local interfaces = Instance.new("Folder")
	interfaces.Name = "__INTERFACES"
	for _, v in next, StarterGui:GetChildren() do
		v.Parent = interfaces
	end
	interfaces.Parent = ReplicatedStorage

	-- Require modules
	local modules: { { Name: string, Module: any } } = {}
	local folderOrder = { SERVER.Core, SERVER.Services }

	for _, folder in folderOrder do
		for _, module in next, folder:QueryDescendants("ModuleScript") do
			if not module.Name:find("Service") then
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

	print(string.format("✅ Server loaded in %.6f seconds", os.clock() - start))
end
