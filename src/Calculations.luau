--!strict
--!optimize 2

local Types = require(script.Parent.Types)
local Calculations = {}

-- Predicts future target's position using proportional navigation
@native
function Calculations.CalculatePN(ToTarget: Vector3, ToTargetDistance: number, ToTargetDirection: Vector3,
	TargetVelocity: Vector3, Velocity: Vector3): Vector3
	local relativeVel = TargetVelocity - Velocity

	local closingVelocity = (-relativeVel):Dot(ToTargetDirection)

	if closingVelocity >= 0 then 
		local LOSCrossVel = ToTarget:Cross(relativeVel)

		local pnAcceleration = 3 * relativeVel:Cross(LOSCrossVel / ToTargetDistance ^ 2)
		return (ToTargetDirection * 10 + pnAcceleration).Unit
	end

	return ToTargetDirection
end

-- Calculates new direction for non-physics projectiles
@native
function Calculations.limitDirectionNonPhysics(currentDirection: Vector3, targetDirection: Vector3, rotationSpeed: number)
	local rotationAxis = currentDirection:Cross(targetDirection)
	if rotationAxis.Magnitude < 1e-6 then return targetDirection end

	local dotProduct = math.clamp(currentDirection:Dot(targetDirection), -1, 1)

	rotationAxis = rotationAxis.Unit

	local actualAngle = math.min(math.acos(dotProduct), rotationSpeed)

	local cosTheta = math.cos(actualAngle)
	local sinTheta = math.sin(actualAngle)
	local newDirection = currentDirection * cosTheta + (rotationAxis:Cross(currentDirection)) * sinTheta + rotationAxis * (rotationAxis:Dot(currentDirection)) * (1 - cosTheta)

	return newDirection
end

-- Calculates new direction for physics projectiles
@native
function Calculations.limitDirectionPhysics(
	currentDirection: Vector3, targetDirection: Vector3, velocity: number, 
	liftPower: number, mass: number, force: number, dt: number)
	
	local rotationAxis = currentDirection:Cross(targetDirection)
	if rotationAxis.Magnitude < 1e-6 then return targetDirection end

	local dotProduct = math.clamp(currentDirection:Dot(targetDirection), -1, 1)

	rotationAxis = rotationAxis.Unit

	local actualAngle = math.min(math.acos(dotProduct), (math.min(liftPower * math.pow(velocity, 2) / mass, force) / velocity) * dt)

	local cosTheta = math.cos(actualAngle)
	local sinTheta = math.sin(actualAngle)
	local newDirection = currentDirection * cosTheta + (rotationAxis:Cross(currentDirection)) * sinTheta + rotationAxis * (rotationAxis:Dot(currentDirection)) * (1 - cosTheta)

	return newDirection
end

@native
local function Evaluate(AoA: number, Table: {{Value: number, AoA: number}}): number
	if AoA <= Table[1].AoA then return Table[1].Value end
	if AoA >= Table[#Table].AoA then return Table[#Table].Value end

	for i = 1, #Table - 1 do
		local lower = Table[i]
		local upper = Table[i + 1]

		if AoA >= lower.AoA and AoA <= upper.AoA then
			local t = (AoA - lower.AoA) / (upper.AoA - lower.AoA)
			return lower.Value + t * (upper.Value - lower.Value)
		end
	end

	return 0
end

@native
local function CalculateAoA(currentDirection: Vector3, currentSpeed: Vector3): (number, number)
	local rightAxis = Vector3.yAxis:Cross(currentDirection)
	local upAxis = currentDirection:Cross(rightAxis)

	local UpVelocity = currentSpeed:Dot(upAxis)
	local ForwardVelocity = currentSpeed:Dot(currentDirection)
	local RightVelocity = currentSpeed:Dot(rightAxis)

	return math.deg(math.atan2(-UpVelocity, ForwardVelocity)), math.deg(math.atan2(RightVelocity, ForwardVelocity))
end

@native
local function CalculateLiftAndYaw(
	PitchAoA: number,
	YawAoA: number,
	CurrentSpeed: Vector3,
	CurrentDirection: Vector3,
	projectile: Types.Projectile
): Vector3
	-------[LIFT FORCE]-------
	local rightAxis = Vector3.yAxis:Cross(CurrentDirection)
	local UpAxis = CurrentSpeed.Unit:Cross(rightAxis)

	local LiftCoefficient = Evaluate(PitchAoA, projectile.PitchAoA :: {{AoA: number, Value: number}})
	local LiftForce = 0.5 * math.pow(CurrentSpeed.Magnitude, 2) * LiftCoefficient * projectile.LiftPower :: number
	local Lift = LiftForce * UpAxis

	local InducedDragForceLift = math.pow(LiftForce, 2) / (math.pi * 4 * 0.8 * math.pow(CurrentSpeed.Magnitude, 2))
	local InducedDragLift = -CurrentSpeed.Unit * InducedDragForceLift

	-------[YAW FORCE]-------
	local YawDirection = CurrentDirection:Cross(UpAxis)
	local YawCoefficient = Evaluate(YawAoA, projectile.YawAoA :: {{AoA: number, Value: number}})

	local YawForce = 0.5 * math.pow(CurrentSpeed.Magnitude, 2) * YawCoefficient * projectile.YawPower :: number
	local Yaw = YawForce * YawDirection

	local InducedDragForceYaw = math.pow(YawForce, 2) / (math.pi * 4 * 0.8 * math.pow(CurrentSpeed.Magnitude, 2))
	local InducedDragYaw = -CurrentSpeed.Unit * InducedDragForceYaw

	return Lift + InducedDragLift + Yaw + InducedDragYaw
end

@native
function Calculations.CalculateLiftYaw(projectile: Types.Projectile, currentDirection: Vector3, currentSpeed: Vector3): Vector3
	local PitchAoA, YawAoA = CalculateAoA(currentDirection, currentSpeed)
	return CalculateLiftAndYaw(PitchAoA, YawAoA, currentSpeed, currentDirection, projectile)
end

return Calculations
