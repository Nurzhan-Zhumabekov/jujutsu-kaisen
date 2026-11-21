-- Server-authoritative combat for the free-for-all arena.
-- The client only asks "use ability X aiming there"; the server checks cooldown,
-- energy and aliveness, then applies damage, knockback and kill credit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

Players.RespawnTime = Config.RespawnTime

local function getOrCreate(parent: Instance, className: string, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = parent
	return created
end

local remotes = getOrCreate(ReplicatedStorage, "Folder", "Remotes")
local useAbility = getOrCreate(remotes, "RemoteEvent", "UseAbility") :: RemoteEvent
local effect = getOrCreate(remotes, "RemoteEvent", "Effect") :: RemoteEvent

local cooldowns: { [Player]: { [string]: number } } = {}

---------------------------------------------------------------- helpers

local function burst(position: Vector3, color: Color3, finalSize: number)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.3
	p.Size = Vector3.new(1, 1, 1)
	p.Position = position
	p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(0.35), { Size = Vector3.new(finalSize, finalSize, finalSize), Transparency = 1 }):Play()
	Debris:AddItem(p, 0.5)
end

local function humanoidsInRadius(origin: Vector3, radius: number, exclude: Instance): { Humanoid }
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { exclude }
	local found: { Humanoid } = {}
	local seen: { [Humanoid]: boolean } = {}
	for _, part in ipairs(workspace:GetPartBoundsInRadius(origin, radius, params)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if humanoid and not seen[humanoid] then
			seen[humanoid] = true
			table.insert(found, humanoid)
		end
	end
	return found
end

local function damage(attacker: Player, humanoid: Humanoid, amount: number)
	if humanoid.Health <= 0 then
		return
	end
	if attacker.Character and humanoid:IsDescendantOf(attacker.Character) then
		return
	end
	humanoid:SetAttribute("LastAttacker", attacker.UserId)
	humanoid:SetAttribute("LastHit", os.clock())
	humanoid:TakeDamage(amount) -- ForceField (spawn protection) blocks this by itself
end

local function knockback(humanoid: Humanoid, direction: Vector3, power: number)
	if direction.Magnitude < 0.01 then
		direction = Vector3.new(0, 0, -1)
	end
	local velocity = direction.Unit * power + Vector3.new(0, power * 0.3, 0)
	local victim = Players:GetPlayerFromCharacter(humanoid.Parent)
	if victim then
		-- a player's character is simulated by their own client
		effect:FireClient(victim, "Knockback", velocity)
	else
		local root = humanoid.Parent and humanoid.Parent:FindFirstChild("HumanoidRootPart")
		if root and not root.Anchored then
			root.AssemblyLinearVelocity = velocity
		end
	end
end

---------------------------------------------------------------- abilities

local handlers = {}

function handlers.Strike(player: Player, character: Model, root: BasePart, _aim: Vector3, cfg)
	local look = root.CFrame.LookVector
	for _, humanoid in ipairs(humanoidsInRadius(root.Position, cfg.Range, character)) do
		local targetRoot = humanoid.Parent and humanoid.Parent:FindFirstChild("HumanoidRootPart")
		if targetRoot then
			local offset = targetRoot.Position - root.Position
			if offset.Magnitude < 0.01 or offset.Unit:Dot(look) > 0.2 then
				damage(player, humanoid, cfg.Damage)
				knockback(humanoid, offset, cfg.Knockback)
				burst(targetRoot.Position, Color3.fromRGB(255, 255, 255), 5)
			end
		end
	end
end

function handlers.Blast(player: Player, character: Model, root: BasePart, aim: Vector3, cfg)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(2.5, 2.5, 2.5)
	ball.Material = Enum.Material.Neon
	ball.Color = Color3.fromRGB(150, 90, 255)
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.Position = root.Position + aim * 3 + Vector3.new(0, 1, 0)
	ball.Parent = workspace

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, ball }

	local traveled = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt)
		local step = aim * cfg.Speed * dt
		local result = workspace:Raycast(ball.Position, step, params)
		if result then
			connection:Disconnect()
			local model = result.Instance:FindFirstAncestorOfClass("Model")
			local humanoid = model and model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				damage(player, humanoid, cfg.Damage)
				knockback(humanoid, aim, cfg.Knockback)
			end
			burst(result.Position, ball.Color, 9)
			ball:Destroy()
			return
		end
		ball.Position += step
		traveled += step.Magnitude
		if traveled >= cfg.Range then
			connection:Disconnect()
			ball:Destroy()
		end
	end)
end

function handlers.Dash(player: Player, _character: Model, root: BasePart, aim: Vector3, cfg)
	local flat = Vector3.new(aim.X, 0, aim.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	effect:FireClient(player, "Dash", flat.Unit * cfg.Speed)
end

function handlers.Shockwave(player: Player, character: Model, root: BasePart, _aim: Vector3, cfg)
	burst(root.Position, Color3.fromRGB(170, 120, 255), cfg.Radius * 2)
	for _, humanoid in ipairs(humanoidsInRadius(root.Position, cfg.Radius, character)) do
		local targetRoot = humanoid.Parent and humanoid.Parent:FindFirstChild("HumanoidRootPart")
		if targetRoot then
			damage(player, humanoid, cfg.Damage)
			knockback(humanoid, targetRoot.Position - root.Position, cfg.Knockback)
		end
	end
end

useAbility.OnServerEvent:Connect(function(player: Player, name: any, aim: any)
	if typeof(name) ~= "string" then
		return
	end
	local cfg = Config.Abilities[name]
	local handler = handlers[name]
	if not cfg or not handler then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local playerCooldowns = cooldowns[player]
	if not humanoid or not root or humanoid.Health <= 0 or not playerCooldowns then
		return
	end

	local now = os.clock()
	if (playerCooldowns[name] or 0) > now then
		return
	end
	local energy = player:GetAttribute("Energy") or 0
	if energy < cfg.Cost then
		return
	end

	-- the client sends where it is aiming; never trust it beyond a direction
	local direction = root.CFrame.LookVector
	if typeof(aim) == "Vector3" and aim.Magnitude > 0.1 and aim.Magnitude < 1e6 then
		direction = aim.Unit
	end

	playerCooldowns[name] = now + cfg.Cooldown
	player:SetAttribute("Energy", energy - cfg.Cost)
	handler(player, character, root, direction, cfg)
end)

---------------------------------------------------------------- players

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	player:SetAttribute("Energy", Config.MaxEnergy)
	humanoid.Died:Connect(function()
		local attackerId = humanoid:GetAttribute("LastAttacker")
		local lastHit = humanoid:GetAttribute("LastHit") or 0
		if attackerId and os.clock() - lastHit <= Config.KillCreditWindow then
			local attacker = Players:GetPlayerByUserId(attackerId)
			local stats = attacker and attacker:FindFirstChild("leaderstats")
			if attacker and attacker ~= player and stats then
				stats.Kills.Value += 1
			end
		end
	end)
end

local function setupPlayer(player: Player)
	cooldowns[player] = {}

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	local kills = Instance.new("IntValue")
	kills.Name = "Kills"
	kills.Parent = leaderstats

	player:SetAttribute("Energy", Config.MaxEnergy)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end
Players.PlayerRemoving:Connect(function(player)
	cooldowns[player] = nil
end)

-- energy regeneration
task.spawn(function()
	while true do
		task.wait(0.2)
		for _, player in ipairs(Players:GetPlayers()) do
			local energy = player:GetAttribute("Energy")
			if energy then
				player:SetAttribute("Energy", math.min(Config.MaxEnergy, energy + Config.EnergyRegen * 0.2))
			end
		end
	end
end)
