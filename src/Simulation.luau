--!strict
--!optimize 2

local Simulation = {}
Simulation.IsRunning = false

local RunService = game:GetService("RunService")
local Types = require(script.Parent.Types)
local Debug = require(script.Parent.Debug)
local Config = require(script.Parent.Config)
local ProjectileSettings = require(script.Parent.ProjectileSettings)
local Calculations = require(script.Parent.Calculations)

local RotateNonPhysics = Calculations.limitDirectionNonPhysics
local RotatePhysics = Calculations.limitDirectionPhysics
local CalculatePN = Calculations.CalculatePN
local CalculateLiftYaw = Calculations.CalculateLiftYaw

type Projectile = Types.Projectile
type ProjectileEvent = Types.ProjectileEvent
type ProjectileSettings = Types.ProjectileSettings
type PhysicsSettings = Types.PhysicsSettings
type ProjectileConstructorArgs = Types.ProjectileConstructorArgs

local EPSILON = 1e-6
local RAY_SEARCH_OFFSET = Config.RaySearchOffset

local ActiveInstancedNonPhysicsProjectiles: {Projectile} = {}
local ActiveInstancedPhysicsProjectiles: {Projectile} = {}
local ActiveInstancelessNonPhysicsProjectiles: {Projectile} = {}
local ActiveInstancelessPhysicsProjectiles: {Projectile} = {}

local QueuedProjectileEvents: {ProjectileEvent} = {}

local PartTemplate = Instance.new("Part") :: BasePart
local Motor6DTemplate = Instance.new("Motor6D")
local Motor6DAnchor: BasePart = nil
if Config.MovementMethod == "Transform" then
	Motor6DAnchor = Instance.new("Part")
	Motor6DAnchor.Name = "SwiftCastAnchor"
	Motor6DAnchor.Transparency = 1
	Motor6DAnchor.CanCollide = false
	Motor6DAnchor.CanQuery = false
	Motor6DAnchor.CanTouch = false
	Motor6DAnchor.AudioCanCollide = false
	Motor6DAnchor.EnableFluidForces = false
	Motor6DAnchor.Anchored = true
	Motor6DAnchor.CFrame = CFrame.identity
	Motor6DAnchor.Parent = workspace
	Motor6DAnchor:GetPropertyChangedSignal("CFrame"):Connect(function()
		if Motor6DAnchor.CFrame == CFrame.identity then return end
		warn("[SwiftCast]: Motor6DAnchor part cframe has changed. Transform mode may not work properly.")
	end)
end

local DefaultProjectileSettings = ProjectileSettings.new()
local StepConnection: RBXScriptConnection? = nil

local function OnError(errorMessage: string)
	warn(debug.traceback(errorMessage, 2))
end

local function ClearPostTransformConnections(projectile: Projectile)
	local connection = projectile._PostTransformFireConnection
	if connection then
		connection:Disconnect()
		projectile._PostTransformFireConnection = nil
	end
end

local function DestroyProjectileMotor6D(projectile: Projectile)
	if projectile._ProjectileMotor6D ~= Motor6DTemplate then
		projectile._ProjectileMotor6D:Destroy()
	end
end

local function ConnectTransform(projectile: Projectile)
	local projectilePart = projectile.ProjectilePart
	if not projectilePart then return end
	projectilePart.Anchored = false
	local motor6d = Instance.new("Motor6D")
	motor6d.Transform = projectilePart.CFrame
	motor6d.Part0 = Motor6DAnchor
	motor6d.Part1 = projectile.ProjectilePart
	motor6d.Parent = Motor6DAnchor
	ClearPostTransformConnections(projectile)
	projectile._ProjectileMotor6D = motor6d
	if projectile.PostTransform or projectile.PostTransformSafe then
		projectile._PostTransformFireConnection = RunService.Heartbeat:Once(function(deltaTime: number)
			if projectile.PostTransform then
				projectile.PostTransform(projectile)
			end
			if projectile.PostTransformSafe then
				projectile._PostTransformFireConnection = RunService.Heartbeat:Once(function(deltaTime: number)
					projectile.PostTransformSafe(projectile)
				end)
			end
		end)
	end
	return motor6d
end

local function HasRayPierced(projectile: Projectile, raycastResult: RaycastResult): boolean
	if typeof(projectile.CanPierce) == "function" then
		return projectile.CanPierce(projectile, raycastResult)
	else
		return projectile.CanPierce
	end
end

local function GetOffset(projectile: Projectile, deltaTime: number, targetPosition: Vector3, targetVelocity: Vector3): Vector3
	if typeof(projectile.Offset) == "function" then
		return projectile.Offset(projectile, deltaTime, targetPosition, targetVelocity)
	else
		return projectile.Offset
	end
end

local function QueueProjectileEvent(callback: (Types.EventCallback)?, projectile: Projectile, arg1: any, arg2: any)
	if not callback then return end
	table.insert(QueuedProjectileEvents, { Callback = callback, Projectile = projectile, Arg1 = arg1, Arg2 = arg2 })
end

local DispatchAllProjectileEvents: () -> ()
local DispatchLastProjectileEvents: (removeCount: number) -> ()
if Config.UseProtectedCalls == true then
	DispatchAllProjectileEvents = function()
		for _, event in QueuedProjectileEvents do
			xpcall(event.Callback, OnError, event.Projectile, event.Arg1, event.Arg2)
		end
		table.clear(QueuedProjectileEvents)
	end
	DispatchLastProjectileEvents = function(removeCount)
		if removeCount <= 0 then return end
		local eventCount = #QueuedProjectileEvents
		for eventIndex = (eventCount - removeCount + 1), eventCount do
			local event = QueuedProjectileEvents[eventIndex]
			xpcall(event.Callback, OnError, event.Projectile, event.Arg1, event.Arg2)
		end
		for i = 1, removeCount do
			table.remove(QueuedProjectileEvents)
		end
	end
else
	DispatchAllProjectileEvents = function()
		for _, event in QueuedProjectileEvents do
			event.Callback(event.Projectile, event.Arg1, event.Arg2)
		end
		table.clear(QueuedProjectileEvents)
	end
	DispatchLastProjectileEvents = function(removeCount)
		if removeCount <= 0 then return end
		local eventCount = #QueuedProjectileEvents
		for eventIndex = (eventCount - removeCount + 1), eventCount do
			local event = QueuedProjectileEvents[eventIndex]
			event.Callback(event.Projectile, event.Arg1, event.Arg2)
		end
		for i = 1, removeCount do
			table.remove(QueuedProjectileEvents)
		end
	end
end

local function InsertProjectile(projectileArray: {Projectile}, projectile: Projectile)
	local index = #projectileArray + 1
	projectile._Index = index
	table.insert(projectileArray, projectile)
	projectile._ProjectileArray = projectileArray
end

local function RemoveProjectile(projectile: Projectile)
	if not projectile._ProjectileArray then return end
	local projectileArray = projectile._ProjectileArray
	local index = projectile._Index
	local lastProjectile = table.remove(projectileArray) :: Projectile
	if lastProjectile ~= projectile then
		projectileArray[index] = lastProjectile
		lastProjectile._Index = index
	end
	projectile._ProjectileArray = nil
end

local function DestroyProjectile(projectile: Projectile)
	if projectile._Destroyed then return end
	RemoveProjectile(projectile)
	DestroyProjectileMotor6D(projectile)
	ClearPostTransformConnections(projectile)
	projectile._MarkedForDestruction = true
	projectile._Destroyed = true
end

local function MoveProjectileToArray(targetProjectileArray: {Projectile}, projectile: Projectile)
	RemoveProjectile(projectile)
	InsertProjectile(targetProjectileArray, projectile)
end

local function MarkProjectileAsDestroyed(projectile: Projectile, reason: string?)
	QueueProjectileEvent(projectile.OnDestroy, projectile, reason)
	projectile._MarkedForDestruction = true
end

@native
local function CalculateTrajectoryNode(node: Types.TrajectoryNode, origin: Vector3, targetPosition: Vector3): Vector3
	local PosX: Vector3, PosY: Vector3

	local toTarget = targetPosition - origin
	local direction = toTarget.Unit
	local right = Vector3.yAxis:Cross(direction)
	local up = direction:Cross(right)

	if node.State == 'Free' then
		PosX = origin + (toTarget * node.Xscale)
		return PosX + up * (node.MaxHeight * node.Yscale)
	else
		local difference = targetPosition - origin
		local flatDifference = difference * Vector3.new(1, 0, 1)
		PosX = origin + (flatDifference * node.Xscale)

		return Vector3.new(PosX.X, node.MaxHeight * node.Yscale, PosX.Z)
	end
end

@native
local function ProjectOnPlane(startPoint: Vector3, endPoint: Vector3, position: Vector3): Vector3
	local AB = endPoint - startPoint
	local AP = position - startPoint
	local t = AP:Dot(AB) / AB:Dot(AB)
	t = math.clamp(t, 0, 1)

	return startPoint + AB * (t + 0.2)
end

local function GetTrajectoryPosition(projectile: Projectile, origin: Vector3, targetPosition: Vector3, currentPosition: Vector3, currentDirection: Vector3, trajectoryTable: {Types.TrajectoryNode}): Vector3
	local Distance = 0

	for index = 1, #trajectoryTable do
		local currentNode = trajectoryTable[index]
		local nextNode = trajectoryTable[index + 1]

		local currentNodePosition = CalculateTrajectoryNode(currentNode, origin, targetPosition)

		local nextNodePosition: Vector3 = targetPosition

		if nextNode then
			nextNodePosition = CalculateTrajectoryNode(nextNode, origin, targetPosition)
		end

		Distance += (currentNodePosition - nextNodePosition).Magnitude
		if projectile.DistanceTravelled > Distance then continue end
		if currentNode.Waypoint ~= nil then
			QueueProjectileEvent(projectile.OnWaypointReached, projectile, currentNode.Waypoint)
			currentNode.Waypoint = nil
		end

		return ProjectOnPlane(currentNodePosition, nextNodePosition, currentPosition)
	end

	return targetPosition
end

local function UpdateNonPhysicsProjectile(projectile: Projectile, dt: number)
	projectile.Elapsed += dt
	if projectile.Elapsed >= projectile.MaxFlyTime then
		MarkProjectileAsDestroyed(projectile, "MaxTime")
		return
	end
	
	local position = projectile.Position
	local velocity = projectile.Velocity
	local direction = velocity.Unit

	local newPosition = position + velocity * dt
	local deltaPosition = newPosition - position
	local distance = deltaPosition.Magnitude

	if distance <= EPSILON then
		QueueProjectileEvent(projectile.OnStep, projectile, dt)
		return
	end
	
	projectile.DistanceTravelled += distance
	if projectile.DistanceTravelled >= projectile.MaxFlyDistance then
		MarkProjectileAsDestroyed(projectile, "MaxDistance")
		return
	end
	
	QueueProjectileEvent(projectile.OnStep, projectile, dt)

	local target = projectile.Target
	local targetPosition = Vector3.zero
	local targetVelocity = Vector3.zero
	if target then
		if typeof(target) == "Vector3" then
			targetPosition = target
		else
			targetPosition = target.Position
			targetVelocity = target.AssemblyLinearVelocity
		end
	else
		targetPosition = newPosition + direction * 1e9
	end

	targetPosition += GetOffset(projectile, dt, targetPosition, targetVelocity)
	
	local toTarget = targetPosition - newPosition
	local toTargetMagnitude = toTarget.Magnitude
	local toTargetDirection = toTarget.Unit

	local trajectory = projectile.Trajectory
	if trajectory and not projectile.IsTrajectoryPaused then
		targetPosition = GetTrajectoryPosition(projectile, projectile._Origin, targetPosition, newPosition, direction, trajectory)
	end

	if projectile.Prediction then
		toTargetDirection = CalculatePN(toTarget, toTargetMagnitude, toTargetDirection, targetVelocity, velocity)
	end

	if target and math.clamp(toTargetDirection:Dot(direction), -1, 1) < projectile.MaxTrackAngle then
		QueueProjectileEvent(projectile.OnTargetLost, projectile, target)
		projectile.Target = nil
	end
	
	local raycastFunction = projectile.RaycastFunction
	local raycastParams = projectile.RaycastParams
	
	local remainingDistance = distance
	local rayOffset = direction * RAY_SEARCH_OFFSET
	local currentPosition = position
	
	for iteration = 1, projectile.MaxPiercesPerStep do
		local raycastResult = raycastFunction(currentPosition, direction * remainingDistance, raycastParams, projectile, iteration)
		if not raycastResult then break end

		local hasPierced = HasRayPierced(projectile, raycastResult)
		QueueProjectileEvent(projectile.OnHit, projectile, raycastResult, hasPierced)
		if hasPierced ~= true then
			MarkProjectileAsDestroyed(projectile, "Hit")
			projectile.Position = raycastResult.Position
			QueueProjectileEvent(projectile.OnPositionChange, projectile, newPosition, position)
			return
		end

		remainingDistance -= raycastResult.Distance + RAY_SEARCH_OFFSET
		if remainingDistance <= 0 then
			break
		end

		currentPosition = raycastResult.Position + rayOffset
	end

	QueueProjectileEvent(projectile.OnPositionChange, projectile, newPosition, position)

	projectile.Position = newPosition
	projectile.Velocity = RotateNonPhysics(direction, toTargetDirection, projectile.RotationSpeed * dt) * velocity.Magnitude
end

local function UpdatePhysicsProjectile(projectile: Projectile, dt: number)
	projectile.Elapsed += dt
	if projectile.Elapsed >= projectile.MaxFlyTime then
		MarkProjectileAsDestroyed(projectile, "MaxTime")
		return
	end
	
	local velocity = projectile.Velocity
	local position = projectile.Position
	local cachedDirection = projectile.Direction :: Vector3
	
	local liftyaw = CalculateLiftYaw(projectile, cachedDirection, velocity)
	local magnitude = velocity.Magnitude

	velocity += (
		(
			cachedDirection * projectile.ThrustPower :: number +
				Vector3.new(0, projectile.Gravity :: number * projectile.Mass :: number, 0) + 
				liftyaw +
				projectile.AdditionalForces :: Vector3 +
				(
					magnitude > 1e-6 and
					(-(0.5 * math.pow(magnitude, 2) * projectile.DragCoefficient :: number) * velocity.Unit)
					or Vector3.zero
				)
		) / projectile.Mass :: number
	) * dt
	
	local newPosition = position + velocity * dt
	local deltaPosition = newPosition - position
	local distance = deltaPosition.Magnitude
	local direction = deltaPosition.Unit
	
	if distance <= EPSILON then
		QueueProjectileEvent(projectile.OnStep, projectile, dt)
		return
	end
	
	projectile.DistanceTravelled += distance
	if projectile.DistanceTravelled >= projectile.MaxFlyDistance then
		MarkProjectileAsDestroyed(projectile, "MaxDistance")
		return
	end
	
	QueueProjectileEvent(projectile.OnStep, projectile, newPosition, position)
	
	local target = projectile.Target
	local targetPosition = Vector3.zero
	local targetVelocity = Vector3.zero
	if target then
		if typeof(target) == "Vector3" then
			targetPosition = target
		else
			targetPosition = target.Position
			targetVelocity = target.AssemblyLinearVelocity
		end
	else
		targetPosition = newPosition + direction * 1e9
	end

	targetPosition += GetOffset(projectile, dt, targetPosition, targetVelocity)

	local trajectory = projectile.Trajectory
	if trajectory and not projectile.IsTrajectoryPaused then
		targetPosition = GetTrajectoryPosition(projectile, projectile._Origin, targetPosition, newPosition, direction, trajectory)
	end
	
	local toTarget = targetPosition - newPosition
	local toTargetMagnitude = toTarget.Magnitude
	local toTargetDirection = toTarget.Unit

	if projectile.Prediction then
		toTargetDirection = CalculatePN(toTarget, toTargetMagnitude, toTargetDirection, targetVelocity, velocity)
	end

	if target and math.clamp(toTargetDirection:Dot(direction), -1, 1) < projectile.MaxTrackAngle then
		QueueProjectileEvent(projectile.OnTargetLost, projectile, target)
		projectile.Target = nil
	end

	local raycastFunction = projectile.RaycastFunction
	local raycastParams = projectile.RaycastParams

	local remainingDistance = distance
	local rayOffset = direction * RAY_SEARCH_OFFSET
	local currentPosition = position

	for iteration = 1, projectile.MaxPiercesPerStep do
		local raycastResult = raycastFunction(currentPosition, direction * remainingDistance, raycastParams, projectile, iteration)
		if not raycastResult then break end

		local hasPierced = HasRayPierced(projectile, raycastResult)
		QueueProjectileEvent(projectile.OnHit, projectile, raycastResult, hasPierced)
		if hasPierced ~= true then
			MarkProjectileAsDestroyed(projectile, "Hit")
			projectile.Position = raycastResult.Position
			QueueProjectileEvent(projectile.OnPositionChange, projectile, newPosition, position)
			return
		end

		remainingDistance -= raycastResult.Distance + RAY_SEARCH_OFFSET
		if remainingDistance <= 0 then
			break
		end

		currentPosition = raycastResult.Position + rayOffset
	end
	
	QueueProjectileEvent(projectile.OnPositionChange, projectile, dt)
	
	projectile.Position = newPosition
	projectile.Velocity = velocity
	projectile.Direction = RotatePhysics(
		cachedDirection, 
		toTargetDirection,
		magnitude,
		projectile.LiftPower :: number,
		projectile.Mass :: number,
		projectile.G_Limit :: number * math.abs(projectile.Gravity :: number),
		dt
	)
end

local UpdateInstancedProjectiles: (deltaTime: number, destroyedProjectiles: {Projectile}) -> ()
if Config.MovementMethod == "Transform" then
	UpdateInstancedProjectiles = function(deltaTime: number, destroyedProjectiles: {Projectile})
		for index, projectile in ActiveInstancedNonPhysicsProjectiles do
			UpdateNonPhysicsProjectile(projectile, deltaTime)
			projectile._ProjectileMotor6D.Transform = projectile.ProjectilePartRotation.Rotation + projectile.Position
			if projectile._MarkedForDestruction then
				table.insert(destroyedProjectiles, projectile)
			end
		end
		for index, projectile in ActiveInstancedPhysicsProjectiles do	
			UpdatePhysicsProjectile(projectile, deltaTime)
			projectile._ProjectileMotor6D.Transform = projectile.ProjectilePartRotation.Rotation + projectile.Position
			if projectile._MarkedForDestruction then
				table.insert(destroyedProjectiles, projectile)
			end
		end
	end
else
	UpdateInstancedProjectiles = function(deltaTime: number, destroyedProjectiles: {Projectile})
		local sum = #ActiveInstancedNonPhysicsProjectiles + #ActiveInstancedPhysicsProjectiles
		local cframes = table.create(sum, CFrame.identity) :: {CFrame}
		local parts = table.create(sum, PartTemplate) :: {BasePart}
		for index, projectile in ActiveInstancedNonPhysicsProjectiles do
			UpdateNonPhysicsProjectile(projectile, deltaTime)
			cframes[index] = projectile.ProjectilePartRotation.Rotation + projectile.Position
			parts[index] = projectile.ProjectilePart :: BasePart
			if projectile._MarkedForDestruction then
				table.insert(destroyedProjectiles, projectile)
			end
		end
		for index, projectile in ActiveInstancedPhysicsProjectiles do
			UpdatePhysicsProjectile(projectile, deltaTime)
			cframes[index] = projectile.ProjectilePartRotation.Rotation + projectile.Position
			parts[index] = projectile.ProjectilePart :: BasePart
			if projectile._MarkedForDestruction then
				table.insert(destroyedProjectiles, projectile)
			end
		end
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function NewProjectile(constructorArgs: ProjectileConstructorArgs, projectileSettings: ProjectileSettings?, physicsSettings: PhysicsSettings?): Projectile
	local projectileSettings = projectileSettings or DefaultProjectileSettings
	local position = constructorArgs.Position or Vector3.zero
	
	local canPierce = constructorArgs.CanPierce :: Types.CanPierce
	local offset = constructorArgs.Offset :: Types.OffsetFunction
	
	if canPierce == nil then canPierce = projectileSettings.CanPierce end
	if offset == nil then offset = projectileSettings.Offset end
	
	local projectilePart = constructorArgs.ProjectilePart
	local projectilePartRotation = CFrame.identity
	if projectilePart then
		projectilePartRotation = projectilePart.CFrame.Rotation
	end
	local projectile: Projectile = {
		_Active = false,
		_Destroyed = false,
		_IsPhysics = false,
		_Origin = position,
		_MarkedForDestruction = false,
		_ProjectileArray = nil,
		_Index = 0,
		_ProjectileMotor6D = Motor6DTemplate,
		_PostTransformFireConnection = nil,

		Position = position,
		PreviousPosition = position,
		Velocity = constructorArgs.Velocity or Vector3.zero,

		Elapsed = 0,
		DistanceTravelled = 0,
		IsTrajectoryPaused = false,
	
		MaxFlyTime = constructorArgs.MaxFlyTime or projectileSettings.MaxFlyTime,
		MaxFlyDistance = constructorArgs.MaxFlyDistance or projectileSettings.MaxFlyDistance,
		MaxPiercesPerStep = constructorArgs.MaxPiercesPerStep or projectileSettings.MaxPiercesPerStep,
		RotationSpeed = constructorArgs.RotationSpeed or projectileSettings.RotationSpeed,
		MaxTrackAngle = constructorArgs.MaxTrackAngle or projectileSettings.MaxTrackAngle,
		Prediction = constructorArgs.Prediction or projectileSettings.Prediction,
		Trajectory = constructorArgs.Trajectory or projectileSettings.Trajectory,
		RaycastParams = constructorArgs.RaycastParams or projectileSettings.RaycastParams,
		RaycastFunction = constructorArgs.RaycastFunction or projectileSettings.RaycastFunction,
		ProjectilePart = projectilePart,
		ProjectilePartRotation = projectilePartRotation,

		CanPierce = canPierce,
		Offset = offset,

		OnHit = constructorArgs.OnHit,
		OnStep = constructorArgs.OnStep,
		OnPositionChange = constructorArgs.OnPositionChange,
		OnDestroy = constructorArgs.OnDestroy,
		OnTargetLost = constructorArgs.OnTargetLost,
		OnWaypointReached = constructorArgs.OnWaypointReached,
		PostTransform = constructorArgs.PostTransform,
		PostTransformSafe = constructorArgs.PostTransformSafe,

		BlockcastSize = constructorArgs.BlockcastSize or projectileSettings.BlockcastSize,
		SpherecastRadius = constructorArgs.SpherecastRadius or projectileSettings.SpherecastRadius,
		ShapecastPart = constructorArgs.ShapecastPart or projectileSettings.ShapecastPart,
		UserData = constructorArgs.UserData,
	}
	
	local TargetCached = constructorArgs.Target
	local Target: BasePart | Vector3 | nil = nil
	if TargetCached then
		if typeof(TargetCached) ~= 'Vector3' and TargetCached:IsA('Model') then
			if not TargetCached.PrimaryPart then 
				error(`Primary part was not set for the model: `..'[ '..TargetCached.Name..' ]') 
			end
			Target = TargetCached.PrimaryPart :: BasePart
		else
			Target = TargetCached :: BasePart | Vector3
		end	
	end
	
	projectile.Target = Target
	
	if physicsSettings then
		projectile.Mass = physicsSettings.Mass
		projectile.Gravity = physicsSettings.Gravity or -9.81
		projectile.LiftPower = physicsSettings.LiftPower
		projectile.YawPower = physicsSettings.YawPower
		projectile.DragCoefficient = physicsSettings.DragCoefficient
		projectile.InducedDragYaw = physicsSettings.InducedDragYaw
		projectile.InducedDragPitch = physicsSettings.InducedDragPitch
		projectile.ThrustPower = physicsSettings.ThrustPower
		projectile.G_Limit = physicsSettings.G_Limit
		projectile.PitchAoA = physicsSettings.PitchAoA
		projectile.YawAoA = physicsSettings.YawAoA
		projectile.Direction = physicsSettings.Direction
		projectile.AdditionalForces = physicsSettings.AdditionalForces or Vector3.zero
		projectile._IsPhysics = true
	end

	if Config.MovementMethod == "Transform" then
		ConnectTransform(projectile)
	end

	return projectile
end

function Simulation.SpawnProjectile(constructorArgs: ProjectileConstructorArgs, projectileSettings: ProjectileSettings?, physicsSettings: PhysicsSettings?): Projectile
	local projectile = NewProjectile(constructorArgs, projectileSettings, physicsSettings)
	projectile._Active = true
	if projectile.ProjectilePart then
		if projectile._IsPhysics then
			InsertProjectile(ActiveInstancedPhysicsProjectiles, projectile)
		else
			InsertProjectile(ActiveInstancedNonPhysicsProjectiles, projectile)
		end
	else
		if projectile._IsPhysics then
			InsertProjectile(ActiveInstancelessPhysicsProjectiles, projectile)
		else
			InsertProjectile(ActiveInstancelessNonPhysicsProjectiles, projectile)
		end
	end
	return projectile
end

-- Creates a projectile
function Simulation.CreateProjectile(constructorArgs: ProjectileConstructorArgs, projectileSettings: ProjectileSettings?, physicsSettings: PhysicsSettings?): Projectile
	local projectile = NewProjectile(constructorArgs, projectileSettings, physicsSettings)
	projectile._Active = false
	return projectile
end

-- Marks projectile as destroyed, emits destroyed event and destroys the projectile
function Simulation.TerminateProjectile(projectile: Projectile, reason: string?)
	local lastEventIndex = #QueuedProjectileEvents
	MarkProjectileAsDestroyed(projectile, reason)

	local newEventCount = #QueuedProjectileEvents - lastEventIndex
	DispatchLastProjectileEvents(newEventCount)

	DestroyProjectile(projectile)
end

-- Activates a projectile making it start simulating
function Simulation.ActivateProjectile(projectile: Projectile)
	if projectile._Active then return end
	projectile._Active = true
	if projectile.ProjectilePart then
		if projectile._IsPhysics then
			InsertProjectile(ActiveInstancedPhysicsProjectiles, projectile)
		else
			InsertProjectile(ActiveInstancedNonPhysicsProjectiles, projectile)
		end
	else
		if projectile._IsPhysics then
			InsertProjectile(ActiveInstancelessPhysicsProjectiles, projectile)
		else
			InsertProjectile(ActiveInstancelessNonPhysicsProjectiles, projectile)
		end
	end
end

-- Deactivates a projectile making it stop simulating
function Simulation.DeactivateProjectile(projectile: Projectile)
	if not projectile._Active then return end
	projectile._Active = false
	RemoveProjectile(projectile)
end

-- Steps a projectile
function Simulation.StepProjectile(projectile: Projectile, deltaTime: number)
	local lastEventIndex = #QueuedProjectileEvents

	if projectile._IsPhysics then
		UpdatePhysicsProjectile(projectile, deltaTime)
	else
		UpdateNonPhysicsProjectile(projectile, deltaTime)
	end
	
	if projectile.ProjectilePart then
		projectile.ProjectilePart.CFrame = projectile.ProjectilePartRotation.Rotation + projectile.Position
	end

	local newEventCount = #QueuedProjectileEvents - lastEventIndex
	if newEventCount > 0 then
		DispatchLastProjectileEvents(newEventCount)
	end

	if projectile._MarkedForDestruction then
		DestroyProjectile(projectile)
	end
end

-- Sets a projectile part for the projectile
function Simulation.SetProjectilePart(projectile: Projectile, basePart: BasePart?)
	local oldPart = projectile.ProjectilePart
	projectile.ProjectilePart = basePart
	if (oldPart == nil) == (basePart == nil) then return end

	DestroyProjectileMotor6D(projectile)
	if Config.MovementMethod == "Transform" then
		ConnectTransform(projectile)
	end

	if projectile.ProjectilePart then
		if projectile._IsPhysics then
			InsertProjectile(ActiveInstancedPhysicsProjectiles, projectile)
		else
			InsertProjectile(ActiveInstancedNonPhysicsProjectiles, projectile)
		end
	else
		if projectile._IsPhysics then
			InsertProjectile(ActiveInstancelessPhysicsProjectiles, projectile)
		else
			InsertProjectile(ActiveInstancelessNonPhysicsProjectiles, projectile)
		end
	end
end

-- Starts SwiftCast simulation
function Simulation.Start()
	if Simulation.IsRunning then return end
	Simulation.IsRunning = true
	StepConnection = RunService.PreSimulation:Connect(Simulation.Step)
end

-- Stops SwiftCast simulation
function Simulation.Stop()
	if not Simulation.IsRunning then return end
	Simulation.IsRunning = false
	if StepConnection then
		StepConnection:Disconnect()
		StepConnection = nil
	end
end

-- Steps SwiftCast simulation
function Simulation.Step(deltaTime: number)
	local destroyedProjectiles: {Projectile} = {}
	for index, projectile in ActiveInstancelessNonPhysicsProjectiles do
		UpdateNonPhysicsProjectile(projectile, deltaTime)
		if projectile._MarkedForDestruction then
			table.insert(destroyedProjectiles, projectile)
		end
	end
	for index, projectile in ActiveInstancelessPhysicsProjectiles do
		UpdatePhysicsProjectile(projectile, deltaTime)
		if projectile._MarkedForDestruction then
			table.insert(destroyedProjectiles, projectile)
		end
	end

	if #ActiveInstancedNonPhysicsProjectiles > 0 then
		UpdateInstancedProjectiles(deltaTime, destroyedProjectiles)
	end
	if #ActiveInstancedPhysicsProjectiles > 0 then
		UpdateInstancedProjectiles(deltaTime, destroyedProjectiles)
	end

	for _, projectile in destroyedProjectiles do
		DestroyProjectile(projectile)
	end
	
	DispatchAllProjectileEvents()	
end

if Config.StartOnRequire then
	Simulation.Start()
end

return Simulation
