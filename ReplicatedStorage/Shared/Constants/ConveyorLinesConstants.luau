local ConveyorLinesConstants = {}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local MODEL_LINE_NAMES = table.freeze({
	PistolsBasic = "PistolsBasic",
})

local MODEL_LINES: { [ModelLineName]: ModelLine } = table.freeze({
	[MODEL_LINE_NAMES.PistolsBasic] = {
		Id = 0,
		ModelPath = {
			[1] = "M1911",
			[2] = "M1911",
			[3] = "M1911",
		},
	},
})

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type ModelLineName = keyof<typeof(ConveyorLinesConstants.ModelLineNames)>

export type ModelLine = { Id: number, ModelPath: { [number]: string } }

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local modelLineIdLUT = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

ConveyorLinesConstants.ModelLineNames = MODEL_LINE_NAMES

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ConveyorLinesConstants.getModelLine(name: string)
	return MODEL_LINES[name]
end

function ConveyorLinesConstants.getModelLineFromId(id: number)
	return modelLineIdLUT[id]
end

-------------------------------------------------------------------------------
-- LOGIC
-------------------------------------------------------------------------------

for _, v in next, MODEL_LINES do
	modelLineIdLUT[v.Id] = v
end

return ConveyorLinesConstants
