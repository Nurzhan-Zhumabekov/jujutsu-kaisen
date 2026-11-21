-- Builds the free-for-all arena at server start: round floor, wall ring, pillars,
-- a raised centre platform and 10 spawn pads around the edge.

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

-- remove the default template / any previous build
for _, name in ipairs({ "Arena", "Obby", "Baseplate", "SpawnLocation", "StartBase" }) do
	local old = Workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

Lighting.ClockTime = 21
Lighting.Ambient = Color3.fromRGB(70, 60, 110)

local arena = Instance.new("Folder")
arena.Name = "Arena"
arena.Parent = Workspace

local RADIUS = 90
local WALL_SEGMENTS = 32
local SPAWNS = 10

local function block(name: string, cframe: CFrame, size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = arena
	return p
end

local function disc(name: string, topY: number, thickness: number, radius: number, color: Color3, material: Enum.Material?)
	local p = block(
		name,
		CFrame.new(0, topY - thickness / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(thickness, radius * 2, radius * 2),
		color,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- floor (top surface at y = 0) and a raised centre platform (top at y = 3)
disc("Floor", 0, 2, RADIUS, Color3.fromRGB(45, 45, 60), Enum.Material.Slate)
disc("CenterPlatform", 3, 3, 14, Color3.fromRGB(80, 70, 120), Enum.Material.Slate)

-- wall ring, each segment faces the centre
local segmentWidth = 2 * math.pi * RADIUS / WALL_SEGMENTS + 1
for i = 0, WALL_SEGMENTS - 1 do
	local angle = i * 2 * math.pi / WALL_SEGMENTS
	local position = Vector3.new(math.cos(angle) * RADIUS, 20, math.sin(angle) * RADIUS)
	block(
		"Wall" .. i,
		CFrame.lookAt(position, Vector3.new(0, 20, 0)),
		Vector3.new(segmentWidth, 40, 3),
		Color3.fromRGB(30, 30, 45),
		Enum.Material.Concrete
	)
end

-- pillars for cover
for i = 0, 5 do
	local angle = i * math.pi / 3 + math.pi / 6
	local position = Vector3.new(math.cos(angle) * 42, 8, math.sin(angle) * 42)
	block("Pillar" .. i, CFrame.new(position), Vector3.new(6, 16, 6), Color3.fromRGB(110, 90, 160), Enum.Material.Marble)
end

-- spawn pads on a ring, looking at the centre
for i = 0, SPAWNS - 1 do
	local angle = i * 2 * math.pi / SPAWNS
	local position = Vector3.new(math.cos(angle) * 72, 0.5, math.sin(angle) * 72)
	local pad = Instance.new("SpawnLocation")
	pad.Name = "Spawn" .. i
	pad.Anchored = true
	pad.Neutral = true
	pad.Duration = 3 -- spawn protection (ForceField)
	pad.Size = Vector3.new(6, 1, 6)
	pad.CFrame = CFrame.lookAt(position, Vector3.new(0, 0.5, 0))
	pad.Color = Color3.fromRGB(160, 90, 255)
	pad.Material = Enum.Material.Neon
	pad.Transparency = 0.4
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.Parent = arena
end
