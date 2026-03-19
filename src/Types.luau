--!strict

export type CanPierce = (CanPierceCallback | boolean)
export type OffsetFunction = (Offset | Vector3)

export type RaycastFunction = (rayOrigin: Vector3, rayDirection: Vector3, raycastParams: RaycastParams?, projectile: Projectile, iteration: number) -> (RaycastResult?)

export type PostTransform = (projectile: Projectile) -> ()
export type PostTransformSafe = (projectile: Projectile) -> ()
export type OnStep = (projectile: Projectile, newPosition: Vector3, oldPosition: Vector3) -> ()
export type OnPositionChange = (projectile: Projectile, newPosition: Vector3, oldPosition: Vector3) -> ()
export type OnHit = (projectile: Projectile, result: RaycastResult, hasPierced: boolean) -> ()
export type OnDestroy = (projectile: Projectile, reason: string | "MaxTime" | "MaxDistance" | "Hit" | nil) -> ()
export type CanPierceCallback = (projectile: Projectile, result: RaycastResult) -> (boolean)
export type OnTargetLost = (projectile: Projectile, target: BasePart | Vector3) -> ()
export type OnWaypointReached = (projectile: Projectile, waypoint: string) -> ()
export type Offset = (projectile: Projectile, deltaTime: number, targetPosition: Vector3, targetVelocity: Vector3) -> (Vector3)

export type EventCallback = (projectile: Projectile, arg1: any, arg2: any) -> ()
export type ProjectileEvent = {Callback: EventCallback, Projectile: Projectile, Arg1: any, Arg2: any}

export type Config = {
	UseProtectedCalls: boolean,
	StartOnRequire: boolean,
	MovementMethod: "BulkMoveTo" | "Transform",
	RaySearchOffset: number,
}

export type TrajectoryNode = {
	Yscale: number,
	Xscale: number,
	State: string,
	Waypoint: string?,
	MaxHeight: number
}

export type PhysicsSettings = {
	Mass: number,
	Gravity: number?,
	LiftPower: number,
	YawPower: number,
	DragCoefficient: number,
	InducedDragYaw: number,
	InducedDragPitch: number,
	ThrustPower: number,
	G_Limit: number,
	PitchAoA: {{Value: number, AoA: number}},
	YawAoA: {{Value: number, AoA: number}},
	Direction: Vector3,
	AdditionalForces: Vector3?
}

export type ProjectileSettings = {
	MaxFlyTime: number,
	MaxFlyDistance: number,
	MaxPiercesPerStep: number,
	RotationSpeed: number,
	MaxTrackAngle: number,
	Prediction: boolean,
	Target: Model | BasePart | Vector3 | nil,
	Trajectory: {TrajectoryNode}?,

	RaycastParams: RaycastParams?,
	RaycastFunction: RaycastFunction,
	CanPierce: CanPierce,
	Offset: OffsetFunction,

	BlockcastSize: Vector3?,
	SpherecastRadius: number?,
	ShapecastPart: BasePart?,
}

export type ProjectileSettingsOptional = {
	MaxFlyTime: number?,
	MaxFlyDistance: number?,
	MaxPiercesPerStep: number?,
	RotationSpeed: number?,
	MaxTrackAngle: number?,
	Prediction: boolean?,
	Target: BasePart | Vector3 | nil,
	Trajectory: {TrajectoryNode}?,

	RaycastParams: RaycastParams?,
	RaycastFunction: RaycastFunction?,
	CanPierce: CanPierce?,
	Offset: OffsetFunction?,

	BlockcastSize: Vector3?,
	SpherecastRadius: number?,
	ShapecastPart: BasePart?,
}

export type ProjectileConstructorArgs = {
	MaxFlyTime: number?,
	MaxFlyDistance: number?,
	MaxPiercesPerStep: number?,
	RotationSpeed: number?,
	MaxTrackAngle: number?,
	Prediction: boolean?,
	Target: Model | BasePart | Vector3 | nil,
	Trajectory: {TrajectoryNode}?,

	RaycastParams: RaycastParams?,
	RaycastFunction: RaycastFunction?,
	CanPierce: CanPierce?,
	Offset: OffsetFunction?,

	Position: Vector3?,
	Velocity: Vector3?,

	OnHit: OnHit?,
	OnStep: OnStep?,
	OnPositionChange: OnPositionChange?,
	OnDestroy: OnDestroy?,
	OnTargetLost: OnTargetLost?,
	OnWaypointReached: OnWaypointReached?, 
	PostTransform: PostTransform?,
	PostTransformSafe: PostTransformSafe?,

	ProjectilePart: BasePart?,
	ProjectilePartRotation: CFrame?,

	BlockcastSize: Vector3?,
	SpherecastRadius: number?,
	ShapecastPart: BasePart?,
	UserData: any?,
}

export type Projectile = {
	-- Lifetime
	_Active: boolean,
	_Destroyed: boolean,
	_IsPhysics: boolean,
	_Origin: Vector3,
	_MarkedForDestruction: boolean,
	_Index: number,
	_ProjectileArray: {Projectile}?,
	_ProjectileMotor6D: Motor6D,
	_PostTransformFireConnection: RBXScriptConnection?,

	-- State
	Position: Vector3,
	Velocity: Vector3,
	Elapsed: number,
	DistanceTravelled: number,
	IsTrajectoryPaused: boolean,

	-- Data
	MaxFlyTime: number,
	MaxFlyDistance: number,
	MaxPiercesPerStep: number,
	RotationSpeed: number,
	MaxTrackAngle: number,
	Prediction: boolean,
	Target: BasePart | Vector3 | nil,
	Trajectory: {TrajectoryNode}?,
	RaycastParams: RaycastParams?,
	RaycastFunction: RaycastFunction,
	ProjectilePart: BasePart?,
	ProjectilePartRotation: CFrame,
	
	-- Physics
	Mass: number?,
	Gravity: number?,
	LiftPower: number?,
	YawPower: number?,
	DragCoefficient: number?,
	InducedDragYaw: number?,
	InducedDragPitch: number?,
	ThrustPower: number?,
	G_Limit: number?,
	PitchAoA: {{Value: number, AoA: number}}?,
	YawAoA: {{Value: number, AoA: number}}?,
	Direction: Vector3?,
	AdditionalForces: Vector3?,

	-- Callbacks
	CanPierce: CanPierce,
	Offset: OffsetFunction,
	OnHit: OnHit?,
	OnStep: OnStep?,
	OnPositionChange: OnPositionChange?,
	OnDestroy: OnDestroy?,
	OnTargetLost: OnTargetLost?,
	OnWaypointReached: OnWaypointReached?, 
	PostTransform: PostTransform?,
	PostTransformSafe: PostTransformSafe?,

	-- Optional data
	BlockcastSize: Vector3?,
	SpherecastRadius: number?,
	ShapecastPart: BasePart?,
	UserData: any,
}

return nil