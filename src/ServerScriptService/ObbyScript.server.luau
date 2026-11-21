--!strict
-- Obby game logic: kill parts, checkpoints, leaderstats (Stage / Wins) and the finish.
-- Needs the course from BuildObby.server.luau (it waits for it with WaitForChild).

local Players = game:GetService("Players")

local obby = workspace:WaitForChild("Obby")
local kill = obby:WaitForChild("Kill")
local checkpoints = obby:WaitForChild("Checkpoints")
local finish = obby:WaitForChild("Finish")
local start = workspace:WaitForChild("SpawnLocation") :: SpawnLocation

local function setupPlayer(player: Player)
	if player:FindFirstChild("leaderstats") then
		return
	end
	-- several neutral SpawnLocations exist; without this Roblox picks one at random
	player.RespawnLocation = start

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local stage = Instance.new("IntValue")
	stage.Name = "Stage"
	stage.Parent = leaderstats

	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = leaderstats
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

local function getPlayerAndHumanoid(hit: BasePart): (Player?, Humanoid?)
	local character = hit.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return Players:GetPlayerFromCharacter(character), humanoid
	end
	return nil, nil
end

-- lava, red strips and the kill plane
for _, part in ipairs(kill:GetChildren()) do
	if part:IsA("BasePart") then
		part.Touched:Connect(function(hit)
			local _, humanoid = getPlayerAndHumanoid(hit)
			if humanoid then
				humanoid.Health = 0
			end
		end)
	end
end

-- checkpoints: remember the furthest one reached
for _, checkpoint in ipairs(checkpoints:GetChildren()) do
	local number = tonumber(checkpoint.Name)
	if number and checkpoint:IsA("SpawnLocation") then
		checkpoint.Touched:Connect(function(hit)
			local player = getPlayerAndHumanoid(hit)
			if not player then
				return
			end
			setupPlayer(player)
			local stage = player.leaderstats.Stage :: IntValue
			if number > stage.Value then
				stage.Value = number
				player.RespawnLocation = checkpoint
			end
		end)
	end
end

-- finish: +1 win, progress reset, back to the start
local cooldown: { [Player]: boolean } = {}
finish.Touched:Connect(function(hit)
	local player, humanoid = getPlayerAndHumanoid(hit)
	if not player or not humanoid or cooldown[player] then
		return
	end
	cooldown[player] = true
	setupPlayer(player)
	local leaderstats = player.leaderstats
	leaderstats.Wins.Value += 1
	leaderstats.Stage.Value = 0
	player.RespawnLocation = start
	local character = humanoid.Parent :: Model
	character:PivotTo(start.CFrame + Vector3.new(0, 4, 0))
	task.delay(3, function()
		cooldown[player] = nil
	end)
end)
