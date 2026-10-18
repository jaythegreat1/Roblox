-- Echo data: the superpowers. Values follow the Echo Codex tab of the master plan.
-- Server and client both read this. cast = wind-up in seconds before the Echo takes effect;
-- a hit during the wind-up interrupts it and refunds half the cooldown (unless armored).
local Echoes = {}

Echoes.Rarity = {
	Common = { cost = 1, color = Color3.fromRGB(200, 200, 210) },
	Rare = { cost = 2, color = Color3.fromRGB(80, 160, 255) },
	Epic = { cost = 3, color = Color3.fromRGB(190, 90, 255) },
	Legendary = { cost = 4, color = Color3.fromRGB(255, 180, 50) },
	Mythic = { cost = 0, color = Color3.fromRGB(255, 70, 110) },
}

Echoes.Elements = {
	Fire = { color = Color3.fromRGB(255, 120, 40), glow = Color3.fromRGB(255, 200, 80) },
	Lightning = { color = Color3.fromRGB(90, 200, 255), glow = Color3.fromRGB(220, 245, 255) },
	Rift = { color = Color3.fromRGB(230, 60, 220), glow = Color3.fromRGB(255, 170, 250) },
}

Echoes.Statuses = {
	Burn = { duration = 3, color = Color3.fromRGB(255, 120, 40) },
	Shock = { duration = 2, color = Color3.fromRGB(120, 210, 255) },
	Mark = { duration = 6, color = Color3.fromRGB(255, 240, 120) },
	Blind = { duration = 2, color = Color3.fromRGB(80, 40, 120) },
}

local list = {
	-- Fire (Pyre) ---------------------------------------------------------------------
	{
		id = "EmberDash",
		name = "Ember Dash",
		element = "Fire",
		rarity = "Common",
		type = "Dash",
		cooldown = 7,
		cast = 0.08,
		anim = "EchoEmberDash",
		text = "Dash 18 studs through enemies for 8 damage, leaving a flame trail that Burns for 3 s.",
	},
	{
		id = "FlameFang",
		name = "Flame Fang",
		element = "Fire",
		rarity = "Common",
		type = "Projectile",
		cooldown = 6,
		cast = 0.18,
		anim = "EchoFlameFang",
		text = "A crescent of fire flies 40 studs: 7 damage and Burn.",
	},
	{
		id = "BlazeSpiral",
		name = "Blaze Spiral",
		element = "Fire",
		rarity = "Rare",
		type = "Area",
		cooldown = 11,
		cast = 0.25,
		anim = "EchoBlazeSpiral",
		text = "Launches everyone within 8 studs: 11 damage and Burn.",
	},
	{
		id = "InfernoCage",
		name = "Inferno Cage",
		element = "Fire",
		rarity = "Rare",
		type = "Control",
		cooldown = 12,
		cast = 0.3,
		anim = "EchoInfernoCage",
		text = "A 14-stud ring of fire for 4 s. Crossing it deals 8 damage, Burns and knocks back.",
	},
	{
		id = "SolarFlare",
		name = "Solar Flare",
		element = "Fire",
		rarity = "Epic",
		type = "Projectile",
		cooldown = 15,
		cast = 0.35,
		anim = "EchoSolarFlare",
		text = "A fireball bursts into a small sun: 15 damage within 10 studs and Blind for 1.5 s.",
	},
	{
		id = "MeteorBrand",
		name = "Meteor Brand",
		element = "Fire",
		rarity = "Legendary",
		type = "Area",
		cooldown = 20,
		cast = 0.4,
		anim = "EchoMeteorBrand",
		text = "Five meteors hit a marked zone over 3 s: up to 18 damage to one target and burning craters.",
	},
	{
		id = "PhoenixDescent",
		name = "Phoenix Descent",
		element = "Fire",
		rarity = "Mythic",
		type = "Ultimate",
		cooldown = 0,
		cast = 0.2,
		anim = "EchoPhoenixRise",
		text = "Climb on fire wings and dive-bomb: 35 damage within 20 studs and burning ground for 6 s.",
	},
	-- Lightning (Storm) ---------------------------------------------------------------
	{
		id = "FlashStep",
		name = "Flash Step",
		element = "Lightning",
		rarity = "Common",
		type = "Dash",
		cooldown = 7,
		cast = 0.08,
		anim = "EchoFlashStep",
		text = "Blink 25 studs (behind your lock-on target if you have one), 6 damage to anyone passed. Your next light within 1 s Shocks.",
	},
	{
		id = "VoltLance",
		name = "Volt Lance",
		element = "Lightning",
		rarity = "Common",
		type = "Projectile",
		cooldown = 6,
		cast = 0.2,
		anim = "EchoVoltLance",
		text = "A lightning javelin hits instantly up to 45 studs away: 7 damage and Mark.",
	},
	{
		id = "Thunderclap",
		name = "Thunderclap",
		element = "Lightning",
		rarity = "Rare",
		type = "Area",
		cooldown = 11,
		cast = 0.25,
		anim = "EchoThunderclap",
		text = "Bolts strike everywhere within 12 studs: 10 damage, Shock and a small launch.",
	},
	{
		id = "ArcChain",
		name = "Arc Chain",
		element = "Lightning",
		rarity = "Rare",
		type = "Control",
		cooldown = 12,
		cast = 0.2,
		anim = "EchoArcChain",
		text = "Lightning jumps between up to 4 enemies: 9 to the first, 6 to each after, and Shock.",
	},
	{
		id = "RaijuRush",
		name = "Raiju Rush",
		element = "Lightning",
		rarity = "Epic",
		type = "Dash",
		cooldown = 15,
		cast = 0.12,
		anim = "EchoRaijuRush",
		text = "Three zigzag dashes of 15 studs, 5 damage each; the last one launches.",
	},
	{
		id = "StormPillar",
		name = "Storm Pillar",
		element = "Lightning",
		rarity = "Legendary",
		type = "Construct",
		cooldown = 20,
		cast = 0.35,
		anim = "EchoStormPillar",
		text = "A lightning rod stands for 8 s and strikes the nearest enemy within 25 studs every second: 3 damage and Shock.",
	},
	{
		id = "RaijinsWrath",
		name = "Raijin's Wrath",
		element = "Lightning",
		rarity = "Mythic",
		type = "Ultimate",
		cooldown = 0,
		cast = 0.5,
		anim = "EchoRaijinsWrath",
		text = "Lightning rains on every enemy within 40 studs for 5 s, then one giant bolt: up to 34 damage.",
	},
	-- Rift (neutral) ------------------------------------------------------------------
	{
		id = "RiftBlink",
		name = "Rift Blink",
		element = "Rift",
		rarity = "Common",
		type = "Dash",
		cooldown = 6,
		cast = 0,
		anim = "EchoRiftBlink",
		text = "Teleport 10 studs the way you are moving.",
	},
	{
		id = "SecondWind",
		name = "Second Wind",
		element = "Rift",
		rarity = "Common",
		type = "Buff",
		cooldown = 9,
		cast = 0.2,
		anim = "EchoSecondWind",
		text = "Heal 12 over 3 s. Any damage cancels it.",
	},
	{
		id = "BattleCry",
		name = "Battle Cry",
		element = "Rift",
		rarity = "Rare",
		type = "Buff",
		cooldown = 12,
		cast = 0.25,
		anim = "EchoBattleCry",
		text = "15% more damage and attack speed for 5 s, and a push on enemies within 6 studs.",
	},
	{
		id = "IronWill",
		name = "Iron Will",
		element = "Rift",
		rarity = "Rare",
		type = "Buff",
		cooldown = 12,
		cast = 0,
		anim = "EchoIronWill",
		text = "Clear every status effect and gain 1 s of hyper armor.",
	},
}

Echoes.List = list
Echoes.ById = {}
for _, e in list do
	Echoes.ById[e.id] = e
end

Echoes.DefaultLoadout = { "FlameFang", "FlashStep", "BlazeSpiral", "PhoenixDescent" }
Echoes.Slots = { "Echo1", "Echo2", "Echo3", "EchoSurge" }

-- Surge meter (master plan): fills from fighting, fires the Mythic in the Surge slot when full.
Echoes.Surge = {
	max = 100,
	perDamageDealt = 0.8,
	perDamageTaken = 0.5,
	perParry = 10,
	perClash = 15,
	riftBurstCost = 40,
	riftBurstCooldown = 8,
}

function Echoes.get(id: any)
	return if typeof(id) == "string" then Echoes.ById[id] else nil
end

-- Which slots an Echo may go in: Mythics only in the Surge slot, everything else in 1 to 3.
function Echoes.fits(id: any, slot: string): boolean
	local e = Echoes.get(id)
	if not e then
		return false
	end
	if slot == "EchoSurge" then
		return e.rarity == "Mythic"
	end
	return e.rarity ~= "Mythic" and (slot == "Echo1" or slot == "Echo2" or slot == "Echo3")
end

return Echoes
