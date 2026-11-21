-- Client: draws the pixel-art sprite effects (pixelfx sheets, 8x8 grid) for Blast.
--   * every part the server tags "BlastOrb" gets a looping orb sprite while it flies
--   * the server event Effect("BlastHit", position) plays a one-shot explosion there
-- Frames are stepped locally with ImageRectOffset, so nothing about the animation is replicated.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local effect = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Effect") :: RemoteEvent

-- Puts an animated sprite on `part`. Returns a function that stops it.
local function attachSprite(part: BasePart, def): () -> ()
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sprite"
	gui.Adornee = part
	gui.Size = UDim2.fromScale(def.Size, def.Size) -- scale = studs for a BillboardGui
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Parent = part

	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = def.Image
	image.ImageRectSize = Vector2.new(def.Cell, def.Cell)
	image.ResampleMode = Enum.ResamplerMode.Pixelated
	image.Parent = gui

	local startedAt = os.clock()
	local connection: RBXScriptConnection
	local function stop()
		connection:Disconnect()
		gui:Destroy()
	end

	connection = RunService.RenderStepped:Connect(function()
		local frame = math.floor((os.clock() - startedAt) * def.Fps)
		if frame >= def.Frames then
			if not def.Loop then
				stop()
				return
			end
			frame %= def.Frames
		end
		image.ImageRectOffset = Vector2.new((frame % def.Grid) * def.Cell, (frame // def.Grid) * def.Cell)
	end)

	part.Destroying:Connect(function()
		if connection.Connected then
			stop()
		end
	end)
	return stop
end

-- flying projectiles
local function onOrb(part: Instance)
	if part:IsA("BasePart") then
		attachSprite(part, Config.Effects.BlastOrb)
	end
end
CollectionService:GetInstanceAddedSignal("BlastOrb"):Connect(onOrb)
for _, part in ipairs(CollectionService:GetTagged("BlastOrb")) do
	onOrb(part)
end

-- impact explosion
effect.OnClientEvent:Connect(function(kind: string, position: Vector3)
	if kind ~= "BlastHit" or typeof(position) ~= "Vector3" then
		return
	end
	local def = Config.Effects.BlastHit
	local anchor = Instance.new("Part")
	anchor.Name = "BlastHitFx"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position = position
	anchor.Parent = workspace
	attachSprite(anchor, def)
	Debris:AddItem(anchor, def.Frames / def.Fps + 0.2)
end)
