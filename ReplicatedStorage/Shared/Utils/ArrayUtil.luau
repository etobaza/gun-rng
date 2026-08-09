--!strict
local ArrayUtil = {}

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type Array = { any }

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ArrayUtil.swapbackRemove<T>(tbl: { T }, index: number): T
	local len = #tbl
	local new = tbl[len]
	tbl[index] = new
	tbl[len] = nil
	return new
end

function ArrayUtil.range(len: number)
	local array = {}
	for n = 1, len do
		table.insert(array, n)
	end
	return array
end

function ArrayUtil.dictToArray(dict: { [any]: any })
	local array = {}
	for _, v in dict do
		table.insert(array, v)
	end
	return array
end

return ArrayUtil
