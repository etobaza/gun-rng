--!optimize 2

const abs = math.abs

const getBoxFitDistance = function(boxCF: CFrame, half: Vector3, tanH: number, tanV: number): number
	const x = boxCF.XVector * half.X
	const y = boxCF.YVector * half.Y
	const z = boxCF.ZVector * half.Z

	const h1 =
		abs(x.Z + x.X / tanH) +
		abs(y.Z + y.X / tanH) +
		abs(z.Z + z.X / tanH)

	const h2 =
		abs(x.Z - x.X / tanH) +
		abs(y.Z - y.X / tanH) +
		abs(z.Z - z.X / tanH)

	const v1 =
		abs(x.Z + x.Y / tanV) +
		abs(y.Z + y.Y / tanV) +
		abs(z.Z + z.Y / tanV)

	const v2 =
		abs(x.Z - x.Y / tanV) +
		abs(y.Z - y.Y / tanV) +
		abs(z.Z - z.Y / tanV)

	return math.max(h1, h2, v1, v2)
end

const getDistance = function(data: VPFData)
	const aspect = data.aspect

	const vfov = math.rad(data.fov/2)
	const marginScale = 1 - data.fovMargin

	const tanV = math.tan(vfov) * marginScale
	const tanH = tanV * aspect

	const boxCF = data.cf * data.boxLocalCF

	return getBoxFitDistance(boxCF, data.halfSize, tanH, tanV)
end

const update = function(data: VPFData)
	const dist = getDistance(data)
	data.camera.CFrame = CFrame.new(0, 0, dist)
	data.dist = dist
end

const setCFrame = function(data:VPFData, cf:CFrame, ignoreUpdate: boolean?)
	data.model:PivotTo(cf)
	data.cf = cf
	update(data)
end

const setFov = function(data:VPFData, fov:number)
	data.fov = fov
	data.camera.FieldOfView = fov
	update(data)
end

const fit = function(vpf:ViewportFrame, item:Instance, fov:number?, fovMargin:number?, rot:CFrame?)
	fov = fov or 10
	fovMargin = fovMargin or .2
	rot = if rot then rot.Rotation else CFrame.identity

	vpf:ClearAllChildren()
	const camera = Instance.new('Camera')
	camera.FieldOfView = fov
	camera.Parent = vpf
	vpf.CurrentCamera = camera
	const vpfSize = vpf.AbsoluteSize
	const aspect = vpfSize.X/vpfSize.Y

	const model = Instance.new('Model')
	item:Clone().Parent = model
	--model.WorldPivot = model:GetBoundingBox()
	model:PivotTo(rot)
	model.Parent = vpf

	const boxCF, boxSize = model:GetBoundingBox()

	const data = {
		halfSize = boxSize/2;
		boxLocalCF = rot:ToObjectSpace(boxCF);

		cf = rot;
		model = model;
		vpf = vpf;
		camera = camera;
		fov = fov;

		aspect = aspect;
		dist = 5,

		fovMargin = fovMargin;

		update = update;
		setCFrame = setCFrame;
		setFov = setFov;
	}
	
	update(data)

	--local f = Instance.new('Frame', vpf)
	--f.Position = UDim2.fromScale(.5, .5)
	--f.AnchorPoint = Vector2.one/2
	--f.Size = UDim2.fromOffset(2, 2)

	return data
end

type VPFData = typeof(fit(Instance.new('ViewportFrame'), Instance.new('Part'), 10, 10, CFrame.identity))

return fit