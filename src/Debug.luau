--!strict
--!optimize 2

local Debug = {}

local function VisualizeSegment(startPos: Vector3, direction: Vector3, length: number, castSize: Vector3, color: Color3)
	local dirUnit = direction.Unit
	
	local halfDepth = castSize.Z / 2
	local visualLength = length + halfDepth

	local mid = startPos + dirUnit * (visualLength / 2)

	local p = Instance.new("Part")
	p.CFrame = CFrame.lookAt(mid, mid + dirUnit)
	p.Size = Vector3.new(castSize.X, castSize.Y, visualLength)

	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.Transparency = 0.5
	p.Parent = workspace.Projectiles
end

local function VisualizeDot(castStartPosition: Vector3, Color: Color3, Size: Vector3)
	local adornment = Instance.new("Part")
	adornment.CastShadow = false
	adornment.CanCollide = false
	adornment.CanTouch = false
	adornment.CanQuery = false
	adornment.Anchored = true
	adornment.Shape = Enum.PartType.Ball
	adornment.Position = castStartPosition
	adornment.Reflectance = 0
	adornment.Material = Enum.Material.SmoothPlastic
	adornment.Size = Size
	adornment.Color = Color
	adornment.Parent = workspace.Visualization
end

Debug.VisualizeSegment = VisualizeSegment
Debug.VisualizeDot = VisualizeDot

return Debug
