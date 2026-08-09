--[[
  CollisionService

  Description:
  Service responsible for handling collision groups

  Author:
  @SixthAtom

  Date:
  23-03-2026
]]

local CollisionService = {}

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollisionConstants = require(ReplicatedStorage.Shared.Constants.CollisionConstants)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function loadCollisionGroups()
	-- Register all groups
	for group: CollisionConstants.Group in CollisionConstants.Groups do
		if group ~= CollisionConstants.Groups.Default then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end

	-- Register group relations
	for group: CollisionConstants.Group in CollisionConstants.Groups do
		local relations = CollisionConstants.getRelations(group)
		if relations then
			for i, otherGroup in next, relations.Groups do
				PhysicsService:CollisionGroupSetCollidable(
					group,
					otherGroup,
					if relations.Collidables[i] == nil then true else relations.Collidables[i]
				)
			end
		end
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function CollisionService.init()
	loadCollisionGroups()
end

function CollisionService.start() end

function CollisionService.test() end

return CollisionService
