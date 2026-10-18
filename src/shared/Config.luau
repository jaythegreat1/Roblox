--!strict
-- Shared constants for Blade Rift. Values come from the master plan.
local Config = {}

Config.Version = "0.1.0-alpha (Phase 0)"

Config.Character = {
	WalkSpeed = 16,
	SprintSpeed = 26,
	MaxHealth = 100,
	-- Everyone fights with the same body size so animations line up and hitboxes are fair.
	Scale = {
		Height = 1,
		Width = 1,
		Depth = 1,
		Head = 1,
		BodyType = 0,
		Proportion = 0,
	},
}

Config.Arena = {
	Radius = 120,
	PillarCount = 8,
}

Config.RemoteFolderName = "BladeRiftRemotes"

return Config
