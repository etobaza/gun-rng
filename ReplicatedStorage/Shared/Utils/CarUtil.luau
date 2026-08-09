local CarUtil = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarConstants = require(ReplicatedStorage.Shared.Constants.CarConstants)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local CARS_FOLDER = workspace:WaitForChild("Cars")

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function CarUtil.getCarsContainer()
	return CARS_FOLDER
end

function CarUtil.getPlayerDrivenCarModel(player: Player)
	local character = player.Character
	if not character then
		return nil
	end

	for _, v in next, CARS_FOLDER:GetChildren() do
		if not v:IsA("Model") then
			continue
		end

		if CarUtil.getCarDriver(v) == character then
			return v
		end
	end

	return nil
end

function CarUtil.getPlayerCarModel(player: Player)
	for _, v in next, CARS_FOLDER:GetChildren() do
		if v:IsA("Model") and v:GetAttribute(CarConstants.Attributes.OriginalOwner) == player.UserId then
			return v
		end
	end
	return nil
end

function CarUtil.getOriginalOwner(carModel: Model): number?
	local originalOwner = carModel:GetAttribute(CarConstants.Attributes.OriginalOwner)
	return if type(originalOwner) == "number" then originalOwner else nil
end

function CarUtil.isCharacterDriving(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart

	return seat and seat:GetAttribute("SeatType", "Car") and seat:IsA("VehicleSeat")
end

function CarUtil.getCarDriver(carModel: Model): Model?
	for _, v in next, carModel:QueryDescendants("VehicleSeat") do
		if v.Occupant then
			return v.Occupant.Parent
		end
	end
	return nil
end

function CarUtil.flipCar(carModel: Model)
	local carRoot = carModel.PrimaryPart
	if not carRoot then
		return
	end

	local ry = select(2, carRoot.CFrame:ToOrientation())
	local bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.one * 40_000
	bodyGyro.CFrame = CFrame.fromOrientation(0, ry, 0)
	bodyGyro.Parent = carRoot

	task.delay(2, bodyGyro.Destroy, bodyGyro)
end

function CarUtil.anySeatOccupied(carModel: Model): boolean
	local seatsFolder = carModel:FindFirstChild("Seats")
	if not seatsFolder then
		return false
	end

	for _, seat in next, seatsFolder:GetChildren() do
		if seat:IsA("Seat") or seat:IsA("VehicleSeat") then
			local seatWeld = seat:FindFirstChild("SeatWeld")
			if seatWeld and seatWeld:IsA("Weld") then
				return true
			end
		end
	end

	return false
end

function CarUtil.getWheels(carModel: Model): { BasePart }
	local wheels = {}
	for _, v in next, carModel:WaitForChild("Wheels") do
		if v:IsA("BasePart") then
			table.insert(wheels, v)
		end
	end
	return wheels
end

function CarUtil.isWheelFront(carRoot: BasePart, wheel: BasePart)
	return carRoot.CFrame:ToObjectSpace(wheel.CFrame).Z < 0
end

return CarUtil
