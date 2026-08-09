--!strict
--!optimize 2

local pi, hpi = math.pi, math.pi / 2
local fwd = Vector3.new(0, 0, -1)
local empty = CFrame.new()

local solver = {}

export type IkSolver = {
	a: number,
	ab2: number,
	asqrd: number,
	b: number,
	bsqrd: number,
	clampDistance: number,
	defaults: { CFrame },
	difference: Vector3,
	ec0: CFrame,
	elbow: Motor6D,
	flip: boolean,
	hand: Motor6D,
	hc0: CFrame,
	sc0: CFrame,
	shoulder: Motor6D,
	z: number,

	solve: (IkSolver, CFrame) -> (),
	reset: (IkSolver) -> (),
}

local order = Enum.RotationOrder.ZYX

@native
function solver.solve(data: IkSolver, targetCFrame: CFrame)
	local shoulder, elbow, hand, difference = data.shoulder, data.elbow, data.hand, data.difference
	local a, b, asqrd, bsqrd = data.a, data.b, data.asqrd, data.bsqrd

	shoulder.C0, elbow.C0, hand.C0 = data.sc0, data.ec0, data.hc0

	assert(shoulder.Part0, "Shoulder base part missing")
	assert(hand.Part0, "Hand base part is missing")

	local target = targetCFrame * hand.C1
	local shoulderSpace = shoulder.Part0.CFrame * shoulder.C0
	local toTarget = shoulderSpace:PointToObjectSpace(target.Position)
	local c = toTarget.Magnitude
	local axis = fwd:Cross(toTarget)
	local angle = math.acos(-toTarget.Z / c)

	if data.clampDistance > c then
		local csqrd = c ^ 2
		local ac, ab = math.acos((asqrd + csqrd - bsqrd) / (2 * a * c)), math.acos((bsqrd + asqrd - csqrd) / data.ab2)
		local flip = data.flip

		shoulder.C0 = data.sc0
			* CFrame.fromAxisAngle(axis, angle)
			* CFrame.fromEulerAngles(flip and ac + hpi or hpi - ac, math.asin(difference.X / c), data.z, order)
		elbow.C0 = data.ec0 * CFrame.fromEulerAnglesYXZ(flip and -pi + ab or -ab + pi, 0, 0)
	else
		shoulder.C0 = data.sc0
			* CFrame.fromAxisAngle(axis, angle)
			* CFrame.fromEulerAngles(hpi, math.asin(difference.X / c), data.z, order)
			* CFrame.new(0, a + b - c, 0)
	end

	hand.C0 = data.hc0 * (hand.Part0.CFrame * hand.C0):ToObjectSpace(target)
end

@native
function solver.reset(data: IkSolver)
	local shoulder, elbow, hand = data.shoulder, data.elbow, data.hand
	shoulder.C0 = data.defaults[1]
	elbow.C0 = data.defaults[2]
	hand.C0 = data.defaults[3]
end

@native
function solver.new(
	shoulder: Motor6D,
	elbow: Motor6D,
	hand: Motor6D,
	lengthScale: number?,
	flip: boolean?,
	inclanationAngle: number?,
	startOffset: CFrame?
): IkSolver
	local data = {}

	local armLengthScale = lengthScale or 1

	data.flip = if flip then true else false
	data.sc0, data.ec0, data.hc0 = shoulder.C0, elbow.C0, hand.C0

	data.defaults = { data.sc0, data.ec0, data.hc0 }

	if startOffset then
		data.sc0 *= startOffset
	end

	shoulder.Transform, elbow.Transform, hand.Transform = empty, empty, empty

	local shoulderSpace = (shoulder.Part0 :: BasePart).CFrame * shoulder.C0
	local shoulderpos = shoulderSpace.Position
	local elbowSpace = shoulderSpace * (shoulder.C1:Inverse()) * elbow.C0
	local elbowpos = elbowSpace.Position
	local handSpace = elbowSpace * (elbow.C1:Inverse()) * hand.C0
	local handpos = handSpace.Position

	local difference = (shoulderSpace:Inverse() * handSpace).Position
	shoulderSpace = shoulderSpace * CFrame.new(difference.X, 0, 0)

	data.shoulder, data.elbow, data.hand = shoulder, elbow, hand

	if not elbow:GetAttribute("changedForIk") then -- prevents z-fighting a bit
		elbow:SetAttribute("changedForIk", true)
		elbow.C1 *= CFrame.new(0.001, 0, 0)
	end

	data.difference = difference
	data.z = math.rad(inclanationAngle or 0)
	data.a, data.b =
		math.abs(elbowpos.Y - shoulderpos.Y) * armLengthScale, math.abs(elbowpos.Y - handpos.Y) * armLengthScale
	data.asqrd, data.bsqrd = data.a ^ 2, data.b ^ 2

	data.ab2 = data.a * data.b * 2
	data.clampDistance = data.a + data.b

	data.solve = solver.solve
	data.reset = solver.reset

	return data
end

return solver
