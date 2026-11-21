-- Client: input (LMB / Q / E / R), the HUD (aura bar + ability slots) and movement effects.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local useAbility = remotes:WaitForChild("UseAbility") :: RemoteEvent
local effect = remotes:WaitForChild("Effect") :: RemoteEvent

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local slots = {
	{ name = "Strike", label = "LMB", input = Enum.UserInputType.MouseButton1 },
	{ name = "Blast", label = "Q", input = Enum.KeyCode.Q },
	{ name = "Dash", label = "E", input = Enum.KeyCode.E },
	{ name = "Shockwave", label = "R", input = Enum.KeyCode.R },
}

---------------------------------------------------------------- HUD

local gui = Instance.new("ScreenGui")
gui.Name = "CombatHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local barBack = Instance.new("Frame")
barBack.AnchorPoint = Vector2.new(0.5, 1)
barBack.Position = UDim2.new(0.5, 0, 1, -100)
barBack.Size = UDim2.fromOffset(320, 22)
barBack.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
barBack.BorderSizePixel = 0
barBack.Parent = gui

local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(1, 1)
barFill.BackgroundColor3 = Color3.fromRGB(150, 90, 255)
barFill.BorderSizePixel = 0
barFill.Parent = barBack

local barText = Instance.new("TextLabel")
barText.Size = UDim2.fromScale(1, 1)
barText.BackgroundTransparency = 1
barText.Font = Enum.Font.GothamBold
barText.TextSize = 14
barText.TextColor3 = Color3.new(1, 1, 1)
barText.Parent = barBack

local overlays: { [string]: Frame } = {}
for i, slot in ipairs(slots) do
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, (i - 2.5) * 80, 1, -20)
	frame.Size = UDim2.fromOffset(72, 72)
	frame.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.Parent = gui

	local key = Instance.new("TextLabel")
	key.Size = UDim2.new(1, 0, 0, 28)
	key.BackgroundTransparency = 1
	key.Font = Enum.Font.GothamBold
	key.TextSize = 22
	key.Text = slot.label
	key.TextColor3 = Color3.new(1, 1, 1)
	key.Parent = frame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.AnchorPoint = Vector2.new(0, 1)
	nameLabel.Position = UDim2.fromScale(0, 1)
	nameLabel.Size = UDim2.new(1, 0, 0, 22)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.TextSize = 13
	nameLabel.Text = slot.name
	nameLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
	nameLabel.Parent = frame

	local overlay = Instance.new("Frame")
	overlay.AnchorPoint = Vector2.new(0, 1)
	overlay.Position = UDim2.fromScale(0, 1)
	overlay.Size = UDim2.fromScale(1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.45
	overlay.BorderSizePixel = 0
	overlay.Parent = frame
	overlays[slot.name] = overlay
end

---------------------------------------------------------------- input

local readyAt: { [string]: number } = {}

local function trigger(slotName: string)
	local cfg = Config.Abilities[slotName]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not cfg or not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	if (readyAt[slotName] or 0) > now then
		return
	end
	if (player:GetAttribute("Energy") or 0) < cfg.Cost then
		return
	end
	readyAt[slotName] = now + cfg.Cooldown

	local aim = mouse.Hit.Position - root.Position
	if aim.Magnitude < 0.1 then
		aim = root.CFrame.LookVector
	end
	useAbility:FireServer(slotName, aim.Unit)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	for _, slot in ipairs(slots) do
		if input.UserInputType == slot.input or input.KeyCode == slot.input then
			trigger(slot.name)
		end
	end
end)

---------------------------------------------------------------- effects from the server

effect.OnClientEvent:Connect(function(kind: string, velocity: Vector3)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or typeof(velocity) ~= "Vector3" then
		return
	end
	if kind == "Dash" or kind == "Knockback" then
		-- a short-lived LinearVelocity beats the humanoid's own walking force
		local attachment = Instance.new("Attachment")
		attachment.Parent = root
		local mover = Instance.new("LinearVelocity")
		mover.Attachment0 = attachment
		mover.MaxForce = math.huge
		mover.RelativeTo = Enum.ActuatorRelativeTo.World
		mover.VectorVelocity = velocity
		mover.Parent = root
		Debris:AddItem(mover, kind == "Dash" and 0.2 or 0.25)
		Debris:AddItem(attachment, 0.3)
	end
end)

---------------------------------------------------------------- HUD update

RunService.RenderStepped:Connect(function()
	local energy = player:GetAttribute("Energy") or 0
	barFill.Size = UDim2.fromScale(math.clamp(energy / Config.MaxEnergy, 0, 1), 1)
	barText.Text = string.format("AURA  %d / %d", energy, Config.MaxEnergy)

	local now = os.clock()
	for _, slot in ipairs(slots) do
		local remaining = math.max(0, (readyAt[slot.name] or 0) - now)
		local ratio = remaining / Config.Abilities[slot.name].Cooldown
		overlays[slot.name].Size = UDim2.fromScale(1, math.clamp(ratio, 0, 1))
	end
end)
