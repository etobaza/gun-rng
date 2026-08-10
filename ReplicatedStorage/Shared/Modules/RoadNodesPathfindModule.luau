--!strict
--!optimize 2

--[[
  RoadNodesPathfindModule

  Description:
  Handles pathfinding between road notes from a start vector to target vector

  Author:
  @SixthAtom

  Date:
  24-04-2026
]]

local RoadNodesPathfindModule = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Astar = require(ReplicatedStorage.Shared.Modules.Astar)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local MERGE_DISTANCE = 50

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type Node = Astar.Node

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local roadNodeByPart: { [BasePart]: Node } = {}
local roadNodes: { Node } = {}
local roadParts: { BasePart } = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local processPart: (part: BasePart) -> Node?
processPart = function(part: BasePart): Node?
	if roadNodeByPart[part] then
		return nil
	end

	local p = part.Position

	local node: Node = {
		Position = vector.create(p.X, p.Y, p.Z),
		LinkedNodes = {},
	}

	table.insert(roadNodes, node)
	roadNodeByPart[part] = node

	for _, oV in next, part:QueryDescendants("ObjectValue") do
		if not oV:IsA("ObjectValue") then
			continue
		end

		local linkedPartValue = oV.Value
		if not (linkedPartValue and linkedPartValue:IsA("BasePart")) then
			continue
		end

		local linkedNode = roadNodeByPart[linkedPartValue] or processPart(linkedPartValue)
		if linkedNode then
			table.insert(node.LinkedNodes, linkedNode)
			table.insert(linkedNode.LinkedNodes, node)
		end
	end

	return node
end

local mergeNodes = function(nodes: { Node }, nodeIxByNode: { [Node]: number }, maxDist: number)
	local maxDistSq = maxDist * maxDist
	local seenIx: { [number]: boolean } = {}
	local repIxByIx: { [number]: number } = {}

	-- BFS Clustering
	for i = 1, #nodes do
		if seenIx[i] then
			continue
		end
		seenIx[i] = true

		local queue = { i }
		local cluster: { number } = {}

		while #queue > 0 do
			local curIx = table.remove(queue, 1)
			if not curIx then
				break
			end

			table.insert(cluster, curIx)
			repIxByIx[curIx] = i

			for j = 1, #nodes do
				if seenIx[j] then
					continue
				end

				local offset = nodes[j].Position - nodes[curIx].Position
				if vector.dot(offset, offset) <= maxDistSq then
					seenIx[j] = true
					table.insert(queue, j)
				end
			end
		end

		-- Compute centroid and assign to representative
		local sum = vector.zero
		for _, index in next, cluster do
			sum += nodes[index].Position
		end
		nodes[i].Position = sum / #cluster
	end

	-- Snapshot original links before clearing, keyed by node index
	local linksByIx: { [number]: { Node } } = {}
	for i = 1, #nodes do
		local node = nodes[i]
		linksByIx[i] = node.LinkedNodes
		node.LinkedNodes = {}
	end

	-- Rebuild LinkedNodes using representatives, deduplicated
	for i = 1, #nodes do
		local repIx = repIxByIx[i] or i
		if repIx ~= i then
			continue
		end

		local seen: { [Node]: boolean } = {}
		local newLinks: { Node } = {}

		for j = 1, #nodes do
			if (repIxByIx[j] or j) ~= repIx then
				continue
			end

			for _, linked in next, linksByIx[j] do
				local linkedIx = nodeIxByNode[linked] or 1
				local linkedRepIx = repIxByIx[linkedIx] or linkedIx
				local linkedRepNode = nodes[linkedRepIx]

				if linkedRepNode ~= nodes[repIx] and not seen[linkedRepNode] then
					seen[linkedRepNode] = true
					table.insert(newLinks, linkedRepNode)
				end
			end
		end

		nodes[repIx].LinkedNodes = newLinks
	end

	-- Compact to only representatives
	local compacted: { Node } = {}
	for i = 1, #nodes do
		if (repIxByIx[i] or i) == i then
			table.insert(compacted, nodes[i])
		end
	end

	return compacted
end

local _test = function(rounds: number)
	local successRounds, failRounds = 0, 0
	local s = os.clock()

	for _ = 1, rounds do
		local startNode = roadNodes[math.random(#roadNodes)]
		local targetNode = roadNodes[math.random(#roadNodes)]

		local path = Astar.compute(startNode, targetNode)

		if path then
			successRounds += 1
		else
			failRounds += 1
		end
	end

	local tS = os.clock() - s
	warn(`Time spent: {tS}s`)
	warn(`Averate time spent: {tS / rounds}s`)

	print(`Results: success={successRounds}, fail={failRounds}, total={rounds}`)
end

local findNodeClosestToPosition = function(position: vector): Node?
	local closestNode: Node? = nil
	local closestDistSq = math.huge

	for _, node in next, roadNodes do
		local offset = node.Position - position
		local distSq = vector.dot(offset, offset)

		if distSq < closestDistSq then
			closestDistSq = distSq
			closestNode = node
		end
	end

	return closestNode
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function RoadNodesPathfindModule.findPath(from: vector, to: vector): { vector }?
	local closestNodeFrom = findNodeClosestToPosition(from)
	local closestNodeTo = findNodeClosestToPosition(to)

	if not (closestNodeFrom and closestNodeTo) then
		return nil
	end

	local toFromOffset, closestNodeFromOffset = to - from, closestNodeTo.Position - from
	if vector.dot(toFromOffset, toFromOffset) <= vector.dot(closestNodeFromOffset, closestNodeFromOffset) then
		return { from, to }
	end

	local path = Astar.compute(closestNodeFrom, closestNodeTo)
	if not path then
		return nil
	end

	table.insert(path, 1, { Position = from, LinkedNodes = { path[1] } })
	table.insert(path, { Position = to, LinkedNodes = { path[#path] } })

	local waypoints: { vector } = {}
	for i, v in next, path do
		waypoints[i] = v.Position
	end
	return waypoints
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

-- function RoadNodesPathfindModule.init() end

-- function RoadNodesPathfindModule.start() end

-- function RoadNodesPathfindModule.test() end

-------------------------------------------------------------------------------
-- LOGIC
-------------------------------------------------------------------------------

do
	local map = workspace:WaitForChild("Map") :: Folder
	local roads = map:WaitForChild("Roads") :: Folder

	roadParts = roads:QueryDescendants("BasePart") :: { BasePart }
	for _, v in next, roadParts do
		processPart(v)
	end

	local nodeIxByNode: { [Node]: number } = {}
	for i, n in next, roadNodes do
		nodeIxByNode[n] = i
	end

	roadNodes = mergeNodes(roadNodes, nodeIxByNode, MERGE_DISTANCE)
end

return RoadNodesPathfindModule
