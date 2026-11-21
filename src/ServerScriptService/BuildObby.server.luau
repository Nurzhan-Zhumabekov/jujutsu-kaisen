--!strict
-- Builds the whole obby course at server start, so the course lives in git as code
-- instead of an unreadable .rbxl file. Edit the numbers below and re-run to change it.

local Workspace = game:GetService("Workspace")

-- remove leftovers (default template baseplate, an old build)
for _, name in ipairs({ "Obby", "Baseplate" }) do
	local old = Workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

local obby = Instance.new("Folder")
obby.Name = "Obby"
obby.Parent = Workspace

local kill = Instance.new("Folder")
kill.Name = "Kill"
kill.Parent = obby

local checkpoints = Instance.new("Folder")
checkpoints.Name = "Checkpoints"
checkpoints.Parent = obby

local function part(
	name: string,
	position: Vector3,
	size: Vector3,
	color: Color3,
	material: Enum.Material?,
	parent: Instance?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or obby
	return p
end

local function spawnPad(name: string, position: Vector3, parent: Instance): SpawnLocation
	local sp = Instance.new("SpawnLocation")
	sp.Name = name
	sp.Anchored = true
	sp.Neutral = true
	sp.Size = Vector3.new(10, 1, 10)
	sp.Position = position
	sp.Color = Color3.fromRGB(80, 220, 100)
	sp.TopSurface = Enum.SurfaceType.Smooth
	sp.Parent = parent
	return sp
end

local colors = {
	Color3.fromRGB(99, 95, 255),
	Color3.fromRGB(255, 170, 0),
	Color3.fromRGB(0, 190, 220),
	Color3.fromRGB(255, 105, 180),
}

local function checkpoint(n: number, center: Vector3)
	part("CheckpointBase" .. n, center, Vector3.new(16, 2, 16), Color3.fromRGB(235, 235, 235))
	spawnPad(tostring(n), center + Vector3.new(0, 1.5, 0), checkpoints)
end

-- START (platform top is y = 1). The pad is named "SpawnLocation": ObbyScript looks it up by that name.
part("StartBase", Vector3.new(0, 0, 0), Vector3.new(20, 2, 20), Color3.fromRGB(200, 200, 200))
local start = Workspace:FindFirstChild("SpawnLocation")
if start then
	start:Destroy()
end
spawnPad("SpawnLocation", Vector3.new(0, 1.5, 0), Workspace)

-- STAGE 1: jumping platforms
local xs = { 20, 34, 48, 62 }
local zs = { 0, 5, -5, 0 }
for i, x in ipairs(xs) do
	part("S1_" .. i, Vector3.new(x, 0, zs[i]), Vector3.new(8, 2, 8), colors[(i - 1) % #colors + 1])
end
checkpoint(1, Vector3.new(80, 0, 0))

-- STAGE 2: stepping stones over lava
part("Lava", Vector3.new(124, -0.5, 0), Vector3.new(72, 1, 30), Color3.fromRGB(255, 60, 30), Enum.Material.Neon, kill)
for i = 0, 6 do
	local z = if i % 2 == 0 then 3 else -3
	part("S2_" .. (i + 1), Vector3.new(92 + i * 10, 0, z), Vector3.new(4, 2, 4), colors[i % #colors + 1])
end
checkpoint(2, Vector3.new(168, 0, 0))

-- STAGE 3: staircase up
for i = 1, 6 do
	part("S3_" .. i, Vector3.new(183 + 11 * (i - 1), 3 * i, 0), Vector3.new(6, 2, 6), colors[i % #colors + 1])
end
checkpoint(3, Vector3.new(255, 18, 0))

-- STAGE 4: beam, landing, then red strips to jump over
part("Beam", Vector3.new(275, 18, 0), Vector3.new(24, 2, 2), Color3.fromRGB(120, 120, 130))
part("S4_Landing", Vector3.new(291, 18, 0), Vector3.new(8, 2, 8), colors[1])
part("S4_Long", Vector3.new(321, 18, 0), Vector3.new(40, 2, 12), colors[3])
for i, x in ipairs({ 309, 319, 329 }) do
	part(
		"Strip" .. i,
		Vector3.new(x, 19.5, 0),
		Vector3.new(2, 1, 12),
		Color3.fromRGB(255, 40, 40),
		Enum.Material.Neon,
		kill
	)
end

-- FINISH
part("FinishBase", Vector3.new(356, 18, 0), Vector3.new(20, 2, 20), Color3.fromRGB(235, 235, 235))
local finish = part("Finish", Vector3.new(360, 19.5, 0), Vector3.new(8, 1, 8), Color3.fromRGB(255, 200, 0), Enum.Material.Neon)

local billboard = Instance.new("BillboardGui")
billboard.Size = UDim2.fromOffset(160, 50)
billboard.StudsOffset = Vector3.new(0, 4, 0)
billboard.AlwaysOnTop = true
billboard.Parent = finish

local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.Text = "FINISH!"
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.Parent = billboard

-- invisible kill plane under the whole course
local plane = part("KillPlane", Vector3.new(180, -40, 0), Vector3.new(700, 2, 300), Color3.new(0, 0, 0), nil, kill)
plane.Transparency = 1
plane.CanCollide = false
