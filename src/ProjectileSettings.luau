--!strict
--!optimize 2

local ProjectileSettings = {}

local Types = require(script.Parent.Types)
local RaycastFunctions = require(script.Parent.RaycastFunctions)

function ProjectileSettings.new(projectileSettings: Types.ProjectileSettingsOptional?): Types.ProjectileSettings
	local projectileSettings: Types.ProjectileSettingsOptional = projectileSettings or {}
	return {
		MaxFlyTime = projectileSettings.MaxFlyTime or math.huge,
		MaxFlyDistance = projectileSettings.MaxFlyDistance or math.huge,
		MaxPiercesPerStep = projectileSettings.MaxPiercesPerStep or 1,
		MaxTrackAngle = projectileSettings.MaxTrackAngle
			and math.clamp(math.cos(math.rad(projectileSettings.MaxTrackAngle)), -1, 1)
			or math.clamp(math.cos(math.rad(180)), -1, 1),
		Prediction = projectileSettings.Prediction or false,
		Trajectory = projectileSettings.Trajectory or nil,
		Target = projectileSettings.Target or nil,
		RotationSpeed = projectileSettings.RotationSpeed or 30,
		RaycastParams = projectileSettings.RaycastParams or nil,
		RaycastFunction = projectileSettings.RaycastFunction or RaycastFunctions.Default,
		BlockcastSize = projectileSettings.BlockcastSize,
		SpherecastRadius = projectileSettings.SpherecastRadius,
		ShapecastPart = projectileSettings.ShapecastPart,

		CanPierce = projectileSettings.CanPierce or false,
		Offset = projectileSettings.Offset or Vector3.zero,
		OnHit = projectileSettings.OnHit or nil,
		OnStep = projectileSettings.OnStep or nil,
		OnPositionChange = projectileSettings.OnPositionChange or nil,
		OnDestroy = projectileSettings.OnDestroy or nil,
		OnTargetLost = projectileSettings.OnTargetLost or nil,
		OnCheckpointReached = projectileSettings.OnCheckpointReached or nil,
		PostTransform = projectileSettings.PostTransform or nil,
		PostTransformSafe = projectileSettings.PostTransformSafe or nil
	}
end

return table.freeze(ProjectileSettings)
