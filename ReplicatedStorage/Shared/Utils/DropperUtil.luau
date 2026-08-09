local DropperUtil = {}

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function DropperUtil.getAnimationTracks(dropper: BasePart)
	local tracks: { string } = {}
	for i, v in dropper.DropAnimations:GetAttributes() do
		tracks[tonumber(i)] = v
	end
	return tracks
end

return DropperUtil
