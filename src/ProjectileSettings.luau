--!strict
--!optimize 2

local ProjectileSettings = {}

local Types = require(script.Parent.Types)
local RaycastFunctions = require(script.Parent.RaycastFunctions)

local function Convert(angle: number): number
	return math.clamp(math.cos(math.rad(angle)), -1, 1)
end

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
		Target = projectileSettings.Target or nil,
		Offset = projectileSettings.Offset or Vector3.zero,
		RotationSpeed = projectileSettings.RotationSpeed or 30,
		RaycastParams = projectileSettings.RaycastParams or nil,
		RaycastFunction = projectileSettings.RaycastFunction or RaycastFunctions.Default,
		CanPierce = projectileSettings.CanPierce or false,
		BlockcastSize = projectileSettings.BlockcastSize,
		SpherecastRadius = projectileSettings.SpherecastRadius,
		ShapecastPart = projectileSettings.ShapecastPart,
	}
end

return table.freeze(ProjectileSettings)