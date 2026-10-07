--!strict
--!optimize 2

local Types = require(script.Parent.Types)
local Calculations = {}

-- Predicts future target's position using proportional navigation
@native
local function CalculatePN(ToTarget: Vector3, ToTargetDistance: number, ToTargetDirection: Vector3,
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
local function LimitDirectionNonPhysics(currentDirection: Vector3, targetDirection: Vector3, rotationSpeed: number): Vector3
	local rotationAxis = currentDirection:Cross(targetDirection)

	if rotationAxis:Dot(rotationAxis) < 1e-12 then return targetDirection end

	local dotProduct = math.clamp(currentDirection:Dot(targetDirection), -1, 1)
	local cosTheta = math.cos(rotationSpeed)

	if dotProduct >= cosTheta then return targetDirection end

	return currentDirection * cosTheta + rotationAxis:Cross(currentDirection) * math.sin(rotationSpeed)
end


-- Calculates new direction for physics projectiles
@native
local function LimitDirectionPhysics(currentDirection: Vector3, targetDirection: Vector3, velocity: number, maxNormalAcceleration: number, rotationSpeed: number, dt: number): Vector3
	local rotationAxis = currentDirection:Cross(targetDirection)
	local axisSquared = rotationAxis:Dot(rotationAxis)

	if axisSquared < 1e-12 then return targetDirection end

	local dotProduct = math.clamp(currentDirection:Dot(targetDirection), -1, 1)

	local maxAngle = math.min(maxNormalAcceleration / velocity, rotationSpeed) * dt

	if maxAngle >= math.pi then return targetDirection end

	local cosTheta = math.cos(maxAngle)

	if dotProduct >= cosTheta then return targetDirection end

	rotationAxis /= math.sqrt(axisSquared)

	return currentDirection * cosTheta + rotationAxis:Cross(currentDirection) * math.sin(maxAngle)
end

@native
local function Evaluate(AoA: number, tbl: {number} --[[Value, AoA]]): number
	local n = #tbl

	if AoA <= tbl[2] then return tbl[1] end
	if AoA >= tbl[n] then return tbl[n - 1] end

	for i = 1, n - 2, 2 do
		local lowerAoA = tbl[i + 1]
		local upperAoA = tbl[i + 3]

		if AoA <= upperAoA then
			local lowerValue = tbl[i]
			local upperValue = tbl[i + 2]

			return lowerValue + (AoA - lowerAoA) / (upperAoA - lowerAoA) * (upperValue - lowerValue)
		end
	end

	return tbl[n - 1]
end

@native
local function CalculateLiftYaw(projectile: Types.Projectile, currentVelocity: Vector3, currentDirection: Vector3): Vector3
	local speedSquared = currentVelocity:Dot(currentVelocity)

	local rightAxis = (Vector3.yAxis:Cross(currentDirection))

	local upAxis = currentDirection:Cross(rightAxis)

	local forwardVelocity = currentVelocity:Dot(currentDirection)
	local pitchAoA = math.atan2(-currentVelocity:Dot(upAxis), forwardVelocity)
	local yawAoA = math.atan2(currentVelocity:Dot(rightAxis), forwardVelocity)

	local dynamicPressure = 0.5 * speedSquared

	-------[LIFT / YAW FORCE]-------

	local liftForce = dynamicPressure * Evaluate(pitchAoA, projectile.PitchAoA :: {number}) * (projectile.LiftPower :: number)
	local yawForce = dynamicPressure * Evaluate(yawAoA, projectile.YawAoA :: {number}) * (projectile.YawPower :: number)

	local aerodynamicForce = liftForce * upAxis - yawForce * rightAxis

	-------[INDUCED DRAG]-------

	local inducedDragForce = (liftForce * liftForce + yawForce * yawForce) / (math.pi * 3.2 * speedSquared)
	local inducedDrag = -currentVelocity * (inducedDragForce / math.sqrt(speedSquared))

	return aerodynamicForce + inducedDrag
end

Calculations.CalculatePN = CalculatePN
Calculations.LimitDirectionNonPhysics = LimitDirectionNonPhysics
Calculations.LimitDirectionPhysics = LimitDirectionPhysics
Calculations.CalculateLiftYaw = CalculateLiftYaw

return Calculations
