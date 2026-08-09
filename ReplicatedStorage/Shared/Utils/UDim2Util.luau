local UDim2Util = {}

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function UDim2Util.multiply(udim2: UDim2, multiplier: number)
	return UDim2.new(udim2.X.Scale * multiplier, udim2.X.Offset * multiplier, udim2.Y.Scale * multiplier, udim2.Y.Offset * multiplier)
end

return UDim2Util
