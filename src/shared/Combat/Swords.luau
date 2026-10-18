-- Sword data. Every timing is in seconds after the move starts; damage and posture numbers
-- follow the master plan's Sword Arsenal. Server and client both read this, so they always agree.
-- A move either lands once (hitAt, damage) or several times (hits = { { at, damage } }).
-- lunge = { distance, time } moves the attacker forward during the move.
local Swords = {}

Swords.IronOath = {
	name = "Iron Oath",
	family = "Longsword",
	style = "Balanced knight; blocking drains 15% less posture.",
	ratings = { damage = 3, speed = 3, reach = 3, guardBreak = 3, mobility = 3 },
	passive = "steadfast",
	light = {
		{ anim = "Slash1", hitAt = 0.15, damage = 5, posture = 10, range = 8, arc = 140, lock = 0.3 },
		{ anim = "Slash2", hitAt = 0.16, damage = 5, posture = 10, range = 8, arc = 140, lock = 0.3 },
		{ anim = "Slash3", hitAt = 0.18, damage = 5, posture = 10, range = 8, arc = 120, lock = 0.32 },
		{ anim = "Slash4", hitAt = 0.24, damage = 5, posture = 12, range = 9, arc = 110, lock = 0.55, knockback = 45 },
	},
	comboReset = 0.9,
	heavy = {
		charge = "HeavyCharge",
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

Swords.Kage = {
	name = "Kage",
	family = "Katana",
	style = "Quick-draw dash cuts; the first strike after 2 s of calm deals 40% more.",
	ratings = { damage = 2, speed = 5, reach = 3, guardBreak = 2, mobility = 4 },
	passive = "sheathDraw",
	light = {
		{ anim = "Kage1", hitAt = 0.1, damage = 4, posture = 8, range = 8, arc = 140, lock = 0.24 },
		{ anim = "Kage2", hitAt = 0.1, damage = 4, posture = 8, range = 8, arc = 140, lock = 0.24 },
		{ anim = "Kage3", hitAt = 0.16, damage = 4, posture = 8, range = 8, arc = 300, lock = 0.3 },
		{ anim = "Kage4", hitAt = 0.12, damage = 4, posture = 8, range = 8, arc = 110, lock = 0.26 },
		{ anim = "Kage5", hitAt = 0.32, damage = 4, posture = 9, range = 8.5, arc = 120, lock = 0.5, knockback = 35 },
	},
	comboReset = 0.8,
	heavy = {
		charge = "KageCharge",
		anim = "KageFlash",
		hitAt = 0.24,
		damage = 13,
		chargedDamage = 19,
		posture = 30,
		range = 6,
		arc = 360,
		lock = 0.6,
		lunge = { distance = 15, time = 0.2 },
		minCharge = 0.25,
		fullCharge = 1.0,
	},
}

Swords.TwinFangs = {
	name = "Twin Fangs",
	family = "Dual daggers",
	style = "Spinning acrobat; every hit in a streak attacks 5% faster, up to 25%.",
	ratings = { damage = 1, speed = 5, reach = 1, guardBreak = 1, mobility = 5 },
	passive = "frenzy",
	dual = true,
	light = {
		{ anim = "Fang1", hitAt = 0.08, damage = 3, posture = 6, range = 6, arc = 130, lock = 0.2 },
		{ anim = "Fang2", hitAt = 0.08, damage = 3, posture = 6, range = 6, arc = 130, lock = 0.2 },
		{ anim = "Fang3", hitAt = 0.15, damage = 3, posture = 6, range = 6, arc = 200, lock = 0.28 },
		{ anim = "Fang4", hitAt = 0.18, damage = 3, posture = 6, range = 6, arc = 360, lock = 0.3 },
		{ anim = "Fang5", hitAt = 0.12, damage = 3, posture = 6, range = 6, arc = 120, lock = 0.24 },
		{ anim = "Fang6", hitAt = 0.2, damage = 3, posture = 7, range = 6.5, arc = 120, lock = 0.42, knockback = 30 },
	},
	comboReset = 0.7,
	heavy = {
		charge = "FangCharge",
		anim = "FangToss",
		hits = { { at = 0.22, damage = 5 }, { at = 0.62, damage = 3 } },
		damage = 8,
		chargedDamage = 12,
		posture = 12,
		range = 20,
		arc = 30,
		lock = 0.7,
		toss = true,
		minCharge = 0.25,
		fullCharge = 1.0,
	},
}

Swords.TitansMaw = {
	name = "Titan's Maw",
	family = "Greatsword",
	style = "Huge spins and slams; heavy attacks cannot be interrupted by light hits.",
	ratings = { damage = 5, speed = 1, reach = 4, guardBreak = 5, mobility = 1 },
	passive = "unstoppable",
	light = {
		{ anim = "Titan1", hitAt = 0.3, damage = 7, posture = 14, range = 10, arc = 120, lock = 0.65 },
		{ anim = "Titan2", hitAt = 0.32, damage = 7, posture = 14, range = 10, arc = 270, lock = 0.7 },
		{ anim = "Titan3", hitAt = 0.42, damage = 9, posture = 16, range = 10, arc = 360, lock = 0.85, knockback = 50 },
	},
	comboReset = 1.1,
	heavy = {
		charge = "TitanCharge",
		anim = "TitanCyclone",
		hits = {
			{ at = 0.25, damage = 6 },
			{ at = 0.45, damage = 6 },
			{ at = 0.65, damage = 6 },
			{ at = 0.9, damage = 8 },
		},
		damage = 26,
		chargedDamage = 34,
		posture = 14,
		range = 9,
		arc = 360,
		lock = 1.1,
		knockback = 40,
		lunge = { distance = 10, time = 0.9 },
		hyperArmor = true,
		minCharge = 0.25,
		fullCharge = 1.0,
	},
}

Swords.Fleuret = {
	name = "Fleuret",
	family = "Rapier",
	style = "Lunges and thrusts; widest parry window, tip hits deal 25% more, ripostes 30% more.",
	ratings = { damage = 3, speed = 4, reach = 4, guardBreak = 1, mobility = 4 },
	passive = "precision",
	parryWindow = 0.23,
	light = {
		{ anim = "Fleuret1", hitAt = 0.08, damage = 4, posture = 6, range = 10, arc = 50, lock = 0.24 },
		{ anim = "Fleuret2", hitAt = 0.12, damage = 4, posture = 6, range = 10, arc = 50, lock = 0.26 },
		{ anim = "Fleuret3", hitAt = 0.22, damage = 5, posture = 6, range = 10, arc = 60, lock = 0.34 },
		{ anim = "Fleuret4", hitAt = 0.14, damage = 5, posture = 6, range = 11, arc = 50, lock = 0.3 },
		{ anim = "Fleuret5", hitAt = 0.12, damage = 6, posture = 7, range = 9, arc = 70, lock = 0.32, knockback = 25 },
	},
	comboReset = 0.85,
	heavy = {
		charge = "FleuretCharge",
		anim = "FleuretFleche",
		hitAt = 0.25,
		damage = 12,
		chargedDamage = 18,
		posture = 25,
		range = 6,
		arc = 360,
		lock = 0.6,
		lunge = { distance = 20, time = 0.25 },
		minCharge = 0.25,
		fullCharge = 1.0,
	},
}

Swords.Sirocco = {
	name = "Sirocco",
	family = "Scimitar",
	style = "A whirling dance; every swing sweeps 220 degrees and hits crowds.",
	ratings = { damage = 3, speed = 4, reach = 3, guardBreak = 2, mobility = 3 },
	passive = "whirl",
	light = {
		{ anim = "Sirocco1", hitAt = 0.16, damage = 5, posture = 8, range = 8, arc = 300, lock = 0.32 },
		{ anim = "Sirocco2", hitAt = 0.16, damage = 5, posture = 8, range = 8, arc = 300, lock = 0.32 },
		{ anim = "Sirocco3", hitAt = 0.24, damage = 6, posture = 8, range = 8, arc = 360, lock = 0.42 },
		{ anim = "Sirocco4", hitAt = 0.2, damage = 6, posture = 9, range = 8, arc = 360, lock = 0.42, knockback = 22 },
	},
	comboReset = 0.9,
	heavy = {
		charge = "SiroccoCharge",
		anim = "SiroccoWaltz",
		hits = {
			{ at = 0.15, damage = 4 },
			{ at = 0.35, damage = 4 },
			{ at = 0.55, damage = 4 },
			{ at = 0.8, damage = 6 },
		},
		damage = 18,
		chargedDamage = 24,
		posture = 8,
		range = 7.5,
		arc = 360,
		lock = 1.0,
		lunge = { distance = 12, time = 0.85 },
		minCharge = 0.25,
		fullCharge = 1.0,
	},
}

-- Order shown in the Armory.
Swords.Order = { "IronOath", "Kage", "TwinFangs", "TitansMaw", "Fleuret", "Sirocco" }

function Swords.get(id: any)
	local sword = if typeof(id) == "string" then Swords[id] else nil
	if typeof(sword) == "table" and sword.light then
		return sword
	end
	return Swords.IronOath
end

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
