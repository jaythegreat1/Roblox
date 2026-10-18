-- Sword data. Every timing here is in seconds after the move starts; damage and posture
-- numbers come from the master plan. Server and client both read this, so they always agree.
local Swords = {}

Swords.IronOath = {
	name = "Iron Oath",
	light = {
		{ anim = "Slash1", hitAt = 0.15, damage = 5, posture = 10, range = 8, arc = 140, lock = 0.3 },
		{ anim = "Slash2", hitAt = 0.16, damage = 5, posture = 10, range = 8, arc = 140, lock = 0.3 },
		{ anim = "Slash3", hitAt = 0.18, damage = 5, posture = 10, range = 8, arc = 120, lock = 0.32 },
		{ anim = "Slash4", hitAt = 0.24, damage = 5, posture = 12, range = 9, arc = 110, lock = 0.55, knockback = 45 },
	},
	comboReset = 0.9,
	heavy = {
		anim = "HeavyRelease",
		hitAt = 0.12,
		damage = 14,
		chargedDamage = 21,
		posture = 35,
		range = 9,
		arc = 100,
		lock = 0.55,
		knockback = 55,
		minCharge = 0.25,
		fullCharge = 1.0,
	},
}

Swords.Combat = {
	maxPosture = 100,
	postureRegenDelay = 2,
	postureRegenPerSecond = 15,
	blockArc = 120,
	blockReduction = 0.85,
	parryWindow = 0.18,
	parriedStun = 0.6,
	whiffLock = 0.5,
	hitStun = 0.35,
	heavyStun = 0.6,
	guardBreakStun = 1.2,
	guardBreakDamageBonus = 0.25,
	regenDelay = 8,
	regenPerSecond = 5,
}

return Swords
