--!strict
--!optimize 2

local HomingCast = {}

local Types = require(script.Types)
local Simulation = require(script.Simulation)
local RaycastFunctions = require(script.RaycastFunctions)
local ProjectileSettings = require(script.ProjectileSettings)

HomingCast.ProjectileSettings = ProjectileSettings
HomingCast.RaycastFunctions = RaycastFunctions

HomingCast.SpawnProjectile = Simulation.SpawnProjectile
HomingCast.CreateProjectile = Simulation.CreateProjectile
HomingCast.ActivateProjectile = Simulation.ActivateProjectile
HomingCast.DeactivateProjectile = Simulation.DeactivateProjectile
HomingCast.TerminateProjectile = Simulation.TerminateProjectile

-- Converts angle to rads for rotation speed
-- Can be assigned manually by using projectile.RotationSpeed = math.rad(angle)
HomingCast.SetRotationSpeed = function(projectile: Types.Projectile, angle: number)
	projectile.RotationSpeed = math.rad(angle)
end

-- Properly sets MaxTrackAngle for the projectile
-- Can be assigned manually by using projectile.MaxTrackAngle = math.clamp(math.cos(math.rad(angle)), -1, 1) 
HomingCast.SetMaxTrackAngle = function(projectile: Types.Projectile, angle: number)
	projectile.MaxTrackAngle = math.clamp(math.cos(math.rad(angle)), -1, 1) 
end

-- Properly sets Target for the projectile
HomingCast.SetTarget = function(projectile: Types.Projectile, target: Model | BasePart | Vector3 | nil)
	local newTarget: BasePart | Vector3 | nil = nil
	if target then
		if typeof(target) ~= 'Vector3' and target:IsA('Model') then
			if not target.PrimaryPart then 
				error(`Primary part was not set for the model: `..'[ '..target.Name..' ]') 
			end
			newTarget = target.PrimaryPart :: BasePart
		else
			newTarget = target :: BasePart | Vector3
		end	
	end

	projectile.Target = newTarget
end

HomingCast.Start = Simulation.Start
HomingCast.Stop = Simulation.Stop
HomingCast.Step = Simulation.Step
HomingCast.StepProjectile = Simulation.StepProjectile
HomingCast.SetProjectilePart = Simulation.SetProjectilePart

function HomingCast.IsRunning(): boolean
	return Simulation.IsRunning
end

return table.freeze(HomingCast)