--!strict
--!optimize 2

local Astar = {}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local NODE_MERGE_DISTANCE = 1

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type Node = {
	Position: vector,
	LinkedNodes: { Node },
}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local heuristic = function(start: Node, target: Node)
	return vector.magnitude(target.Position - start.Position)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

@native
function Astar.compute(start: Node, target: Node): { Node }?
	local openList: { [Node]: boolean } = { [start] = true }
	local closedList: { [Node]: boolean } = {}

	local gScore: { [Node]: number } = { [start] = 0 }
	local fScore: { [Node]: number } = { [start] = heuristic(start, target) }

	local bestLink: { [Node]: Node } = {}

	while next(openList) do
		-- Find the node with the least 'f' on the open list, called 'q'
		local q: Node
		for node in next, openList do
			if not q or fScore[node] < fScore[q] then
				q = node
			end
		end
		openList[q] = nil

		-- Break if 'q' becomes invalid
		if not q then
			break
		end

		-- Return if target is reached
		if q == target then
			local path, current = {}, target

			while current do
				table.insert(path, 1, current)
				current = bestLink[current]
			end

			return path
		end

		-- Iterate over every linked node of 'q'
		for _, linkedNode in next, q.LinkedNodes do
			-- Skip if already evaluated
			if closedList[linkedNode] then
				continue
			end

			-- Calculate g, h & f
			local tentativeG = gScore[q] + vector.magnitude(q.Position - linkedNode.Position)

			-- If we already have a better path, skip
			local existingG = gScore[linkedNode]
			if existingG and tentativeG >= existingG then
				continue
			end

			local h = heuristic(linkedNode, target)
			local f = tentativeG + h

			-- If a node with almost the same position is in the OPEN list with a lower 'f', then skip
			local shouldSkip = false
			for openNode in next, openList do
				if fScore[openNode] and fScore[openNode] < f then
					if vector.magnitude(openNode.Position - linkedNode.Position) <= NODE_MERGE_DISTANCE then
						shouldSkip = true
						break
					end
				end
			end

			if shouldSkip then
				continue
			end

			-- Otherwise, update scores and add the node to the open list
			gScore[linkedNode] = tentativeG
			fScore[linkedNode] = f
			bestLink[linkedNode] = q
			openList[linkedNode] = true
		end

		closedList[q] = true
	end

	return nil
end

return Astar
