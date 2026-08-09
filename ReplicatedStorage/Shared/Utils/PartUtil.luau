local PartUtil = {}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local rng = Random.new()

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function PartUtil.weld(p0: BasePart, p1: BasePart, parent: Instance?)
	local w = Instance.new("Weld")
	w.Part0, w.Part1 = p0, p1
	w.C0 = p0.CFrame:ToObjectSpace(p1.CFrame)
	w.Parent = parent or p0
	return w
end

function PartUtil.createHitbox(model: Model)
	local cf, size = model:GetBoundingBox()

	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Size, hitbox.CFrame = size, cf
	hitbox.CanCollide = false
	hitbox.Transparency = 1

	local primaryPart = model.PrimaryPart
	if primaryPart then
		PartUtil.weld(primaryPart, hitbox)
	end

	hitbox.Parent = model
	return hitbox
end

function PartUtil.playVFX(template: Instance, target: BasePart | Attachment)
	local clonedVFXs: { ParticleEmitter } = {}
	local maxLifetime = 0

	for _, v in next, template:QueryDescendants("ParticleEmitter[$EmitCount]") :: { ParticleEmitter } do
		maxLifetime = math.max(maxLifetime, v.Lifetime.Max)

		local vfxClone = v:Clone()
		vfxClone.Rate = 0
		vfxClone.Parent = target

		local emitCountAtt = vfxClone:GetAttribute("EmitCount") :: number | NumberRange
		local emitCount = if typeof(emitCountAtt) == "NumberRange" then rng:NextInteger(emitCountAtt.Min, emitCountAtt.Max) else emitCountAtt
		vfxClone:Emit(emitCount)

		table.insert(clonedVFXs, vfxClone)
	end

	task.delay(maxLifetime, function()
		for _, v in next, clonedVFXs do
			if v then
				v:Destroy()
			end
		end
	end)
end

return PartUtil
