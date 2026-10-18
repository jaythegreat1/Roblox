--!strict
-- Shared constants for Blade Rift. Values come from the master plan.
local Config = {}

Config.Version = "0.2.1-alpha (Phase 1 fix)"

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

Config.Movement = {
	DodgeCharges = 2,
	DodgeRefill = 4,
	RollDistance = 14,
	RollTime = 0.42,
	RollIFrames = 0.25,
	DashDistance = 12,
	DashTime = 0.3,
	SlideSpeed = 34,
	SlideTime = 0.8,
	AirDashDistance = 10,
	DoubleJumpVelocity = 55,
	HardLandingSpeed = 90,
}

Config.Arena = {
	Radius = 120,
	PillarCount = 8,
}

Config.RemoteFolderName = "BladeRiftRemotes"

return Config
