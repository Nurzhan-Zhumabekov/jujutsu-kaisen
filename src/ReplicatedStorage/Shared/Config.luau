-- Shared balance numbers. Server uses them for real, the client only for the HUD.
-- Change a number here and both sides stay in sync.

local Config = {}

Config.MaxEnergy = 100 -- "Aura" bar
Config.EnergyRegen = 10 -- per second
Config.RespawnTime = 3 -- seconds
Config.SpawnProtection = 3 -- seconds of ForceField after spawning
Config.KillCreditWindow = 10 -- a kill counts if the last hit was this recent

Config.Abilities = {
	Strike = { Cooldown = 0.45, Cost = 0, Damage = 12, Range = 7, Knockback = 35 },
	Blast = { Cooldown = 3, Cost = 25, Damage = 25, Speed = 100, Range = 140, Knockback = 55 },
	Dash = { Cooldown = 4, Cost = 15, Speed = 90 },
	Shockwave = { Cooldown = 10, Cost = 50, Damage = 35, Radius = 20, Knockback = 90 },
}

-- Sprite-sheet effects (made with pixelfx, MIT, see assets/fx/blast). Each sheet is a 8x8 grid
-- of 128x128 frames. Size is the billboard size in studs.
Config.Effects = {
	BlastOrb = { Image = "rbxassetid://83381780059424", Grid = 8, Cell = 128, Frames = 64, Fps = 30, Loop = true, Size = 8 },
	BlastHit = { Image = "rbxassetid://79013741942279", Grid = 8, Cell = 128, Frames = 52, Fps = 30, Loop = false, Size = 22 },
}

return Config
