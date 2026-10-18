-- Progression data from the master plan: levels and XP, Echo capacity, sword prices, quests
-- and daily tasks. Server and client both read this.
local Progression = {}

Progression.MaxLevel = 100

-- XP needed to go from level L to the next: 85 × L^1.27, rounded.
function Progression.xpToNext(level: number): number
	if level >= Progression.MaxLevel then
		return math.huge
	end
	return math.floor(85 * level ^ 1.27 + 0.5)
end

-- Echo Capacity grows with level (Commons cost 1, Rares 2, Epics 3, Legendaries 4).
local CAPACITY =
	{ { 1, 3 }, { 5, 4 }, { 10, 5 }, { 18, 6 }, { 25, 7 }, { 35, 8 }, { 45, 9 }, { 55, 10 }, { 70, 11 }, { 85, 12 } }
function Progression.capacity(level: number): number
	local value = 3
	for _, row in CAPACITY do
		if level >= row[1] then
			value = row[2]
		end
	end
	return value
end

-- Every level pays 50 coins times the new level, capped at 2,500.
function Progression.levelReward(level: number): number
	return math.min(50 * level, 2500)
end

Progression.Swords = {
	IronOath = { level = 1, coins = 0 },
	Kage = { level = 5, coins = 1500 },
	TwinFangs = { level = 8, coins = 2500 },
	TitansMaw = { level = 12, coins = 4000 },
	Fleuret = { level = 16, coins = 5500 },
	Sirocco = { level = 20, coins = 7000 },
}

Progression.Tiers = {
	[1] = { xp = 500, coins = 200, name = "I" },
	[2] = { xp = 2000, coins = 600, name = "II" },
	[3] = { xp = 6000, coins = 1500, name = "III" },
	[4] = { xp = 15000, coins = 4000, name = "IV" },
	[5] = { xp = 40000, coins = 10000, name = "V" },
}

Progression.XP = {
	hit = 2, -- per hit landed on a player or bot (dummies only count for quests)
	ko = 60,
	finisherBonus = 0.5,
	repeatFalloff = 0.25, -- each repeat KO of the same victim within 10 minutes
	minRepeat = 0.1,
}
Progression.Coins = { ko = 25 }

-- Objective types (the server counts them from fight events):
--   hits {dummy, behind, afterDash, airborne, heavy, onAirborne, punish}  beatBot {within, noRolls, feints, element, lowHealth}
--   kos  damage  dodges  riftSteps  blocks  blockAbsorb  parries  projectileParries  guardBreaks {dummy}
--   flips  launches  counterHits  grabs  statuses {names}  freezes  echoMulti  riftBursts  airTime  combo {dummy}
--   suffered (statuses suffered)  botStreak (bot wins in a row without a KO against you)
-- A quest with `soon` is shown in the journal but opens with a later update (Trials, Wardens).
local function q(id, path, tier, level, name, reward, steps, extra)
	local quest = { id = id, path = path, tier = tier, level = level, name = name, reward = reward, steps = steps }
	for k, v in extra or {} do
		quest[k] = v
	end
	return quest
end

local TRIAL = "Opens with Trials in a coming update"
local WARDEN = "Opens with the Wardens in a coming update"

Progression.Paths = {
	{ id = "Rift", name = "The Riftwalker's Way", keeper = "The Wanderer", color = Color3.fromRGB(230, 60, 220) },
	{ id = "Fire", name = "Path of Embers", keeper = "Keeper Ashka", color = Color3.fromRGB(255, 120, 40) },
	{ id = "Lightning", name = "Path of Storms", keeper = "Keeper Volka", color = Color3.fromRGB(90, 200, 255) },
	{ id = "Ice", name = "Path of Frost", keeper = "Keeper Sorin", color = Color3.fromRGB(140, 210, 255) },
	{ id = "Wind", name = "Path of Gales", keeper = "Keeper Aero", color = Color3.fromRGB(170, 250, 200) },
	{ id = "Shadow", name = "Path of Shadows", keeper = "Keeper Nyx", color = Color3.fromRGB(150, 70, 230) },
	{ id = "Earth", name = "Path of Stone", keeper = "Keeper Bramm", color = Color3.fromRGB(190, 140, 80) },
}

local function step(type, count, text, opts)
	local s = { type = type, count = count, text = text }
	for k, v in opts or {} do
		s[k] = v
	end
	return s
end

Progression.Quests = {
	-- Rift (neutral) -------------------------------------------------------------------------
	q("SteelAndFootwork", "Rift", 1, 1, "Steel and Footwork", "RiftBlink", {
		step("combo", 4, "Land a full 4-hit light string on a dummy", { dummy = true }),
		step("blocks", 3, "Block 3 attacks (the Attack Dummy swings at you)"),
		step("parries", 1, "Parry an attack: tap Block just before it lands"),
		step("dodges", 1, "Roll through an attack"),
		step("hits", 1, "Dash, then attack straight out of it", { afterDash = true }),
	}, { setLevel = 2, hint = "Sensei Orin's tutorial: every core move once." }),
	q("FirstDuel", "Rift", 1, 1, "First Duel", nil, {
		step("beatBot", 1, "Beat the Sparring Bot"),
	}, { setLevel = 3, coins = 300, xp = 0, hint = "Beat Orin's sparring bot in a fair fight." }),
	q("CatchYourBreath", "Rift", 1, 3, "Catch Your Breath", "SecondWind", {
		step("botStreak", 3, "Beat the Sparring Bot 3 times in a row without being KO'd"),
	}),
	q("VoiceOfSteel", "Rift", 2, 12, "Voice of Steel", "BattleCry", {
		step("kos", 10, "Score 10 KOs (players or bots)"),
	}),
	q("Unshaken", "Rift", 2, 18, "Unshaken", "IronWill", {
		step("riftBursts", 5, "Use Rift Burst 5 times"),
		step("suffered", 30, "Shrug off 30 status effects in fights"),
	}),
	q("SkyreachRun", "Rift", 2, 20, "Skyreach Run", "GrappleHook", {
		step("soon", 1, "Finish the Skyreach Run parkour course in under 2 minutes"),
	}, { soon = TRIAL }),
	q("GhostStep", "Rift", 3, 30, "Ghost Step", "Afterimage", {
		step("riftSteps", 30, "Perform 30 Rift Steps: rolls in the last instant before a hit"),
	}),
	q("HoldTheLine", "Rift", 3, 35, "Hold the Line", "RiftBarrier", {
		step("blocks", 200, "Block 200 hits"),
		step("parries", 30, "Parry 30 attacks"),
	}),
	q("PerfectReflection", "Rift", 4, 50, "Perfect Reflection", "MirrorGuard", {
		step("projectileParries", 15, "Parry 15 projectile Echoes"),
		step("beatBot", 1, "Beat the Sparring Bot"),
	}),

	-- Fire ------------------------------------------------------------------------------------
	q("FirstSpark", "Fire", 1, 1, "First Spark", "EmberDash", {
		step("hits", 50, "Land 50 hits on dummies", { dummy = true }),
		step("beatBot", 1, "Beat the Sparring Bot"),
	}),
	q("Kindling", "Fire", 1, 5, "Kindling", "FlameFang", {
		step("kos", 3, "Score 3 KOs (players or bots)"),
		step("damage", 500, "Deal 500 damage"),
	}),
	q("TrialOfEmbers", "Fire", 2, 10, "Trial of Embers", "BlazeSpiral", {
		step("soon", 1, "Survive 5 waves of Ember Wraiths in under 6 minutes"),
	}, { soon = TRIAL }),
	q("RingOfFire", "Fire", 2, 15, "Ring of Fire", "InfernoCage", {
		step("statuses", 40, "Burn enemies 40 times", { names = { "Burn" } }),
		step("beatBot", 1, "Beat the Sparring Bot with only Fire Echoes equipped", { element = "Fire" }),
	}),
	q("WardensFlame", "Fire", 3, 25, "The Warden's Flame", "SolarFlare", {
		step("soon", 1, "Defeat Ignivar on Normal, landing 3 parries"),
	}, { soon = WARDEN }),
	q("Cinderstorm", "Fire", 4, 45, "Cinderstorm", "MeteorBrand", {
		step("soon", 1, "Defeat Ignivar on Hard without being KO'd"),
	}, { soon = WARDEN }),
	q("PhoenixAscension", "Fire", 5, 70, "Phoenix Ascension", "PhoenixDescent", {
		step("soon", 1, "Collect 3 Phoenix Feathers from Nightmare Ignivar"),
	}, { soon = WARDEN }),

	-- Lightning -------------------------------------------------------------------------------
	q("FirstThunder", "Lightning", 1, 1, "First Thunder", "FlashStep", {
		step("dodges", 10, "Roll through 10 attacks"),
		step("beatBot", 1, "Beat the Sparring Bot within 60 s of your first hit", { within = 60 }),
	}),
	q("ChargedSteps", "Lightning", 1, 5, "Charged Steps", "VoltLance", {
		step("hits", 20, "Land 20 hits within 1 s of a dash", { afterDash = true }),
		step("beatBot", 2, "Beat the Sparring Bot twice"),
	}),
	q("StormTrial", "Lightning", 2, 10, "Storm Trial", "Thunderclap", {
		step("soon", 1, "Climb Stormspire and touch all 5 copper rods"),
	}, { soon = TRIAL }),
	q("Conductor", "Lightning", 2, 15, "Conductor", "ArcChain", {
		step("statuses", 40, "Shock enemies 40 times", { names = { "Shock" } }),
		step("echoMulti", 1, "Hit 3 enemies with a single Echo (try the dummies)"),
	}),
	q("StormWarden", "Lightning", 3, 25, "The Storm Warden", "RaijuRush", {
		step("soon", 1, "Defeat Voltaris on Normal"),
	}, { soon = WARDEN }),
	q("EyeOfTheStorm", "Lightning", 4, 45, "Eye of the Storm", "StormPillar", {
		step("soon", 1, "Defeat Voltaris on Hard in under 4 minutes"),
	}, { soon = WARDEN }),
	q("ThunderGodsTrial", "Lightning", 5, 70, "Thunder God's Trial", "RaijinsWrath", {
		step("soon", 1, "Collect 3 Storm Cores from Nightmare Voltaris"),
	}, { soon = WARDEN }),

	-- Ice -------------------------------------------------------------------------------------
	q("FirstFrost", "Ice", 1, 1, "First Frost", "FrostLance", {
		step("blocks", 30, "Block 30 hits (the Attack Dummy swings at you)"),
		step("beatBot", 1, "Beat the Sparring Bot"),
	}),
	q("ColdPatience", "Ice", 1, 5, "Cold Patience", "GlacialGuard", {
		step("parries", 10, "Land 10 parries"),
		step("beatBot", 1, "Beat the Sparring Bot without a single roll", { noRolls = true }),
	}),
	q("FrozenLakeTrial", "Ice", 2, 10, "Frozen Lake Trial", "GlacierWall", {
		step("soon", 1, "Defeat 12 Frost Imps on cracking lake ice"),
	}, { soon = TRIAL }),
	q("BlackIce", "Ice", 2, 15, "Black Ice", "FrozenPath", {
		step("statuses", 45, "Chill enemies 45 times", { names = { "Chill" } }),
		step("freezes", 3, "Freeze an enemy 3 times"),
	}),
	q("FrostWarden", "Ice", 3, 25, "The Frost Warden", "AvalancheCrash", {
		step("soon", 1, "Defeat Brumalis on Normal"),
	}, { soon = WARDEN }),
	q("EternalWinter", "Ice", 4, 45, "Eternal Winter", "WintersCoffin", {
		step("soon", 1, "Defeat Brumalis on Hard without being Frozen"),
	}, { soon = WARDEN }),
	q("HeartOfWinter", "Ice", 5, 70, "Heart of Winter", "AbsoluteZero", {
		step("soon", 1, "Collect 3 Glacial Hearts from Nightmare Brumalis"),
	}, { soon = WARDEN }),

	-- Wind ------------------------------------------------------------------------------------
	q("FirstBreeze", "Wind", 1, 1, "First Breeze", "GaleRoll", {
		step("flips", 20, "Double-jump flip 20 times"),
		step("beatBot", 1, "Beat the Sparring Bot"),
	}),
	q("CuttingWind", "Wind", 1, 5, "Cutting Wind", "WindScythe", {
		step("hits", 15, "Land 15 hits while in the air", { airborne = true }),
		step("launches", 10, "Launch enemies 10 times"),
	}),
	q("SkywardTrial", "Wind", 2, 10, "Skyward Trial", "Updraft", {
		step("soon", 1, "Cross the Skyreach jump-pad course"),
	}, { soon = TRIAL }),
	q("WalkTheSky", "Wind", 2, 15, "Walk the Sky", "TempestStep", {
		step("airTime", 180, "Spend 3 minutes airborne during fights"),
		step(
			"hits",
			10,
			"Hit Airborne enemies 10 times while in the air yourself",
			{ airborne = true, onAirborne = true }
		),
	}),
	q("SkyWarden", "Wind", 3, 25, "The Sky Warden", "CycloneCutter", {
		step("soon", 1, "Defeat Zephyrus on Normal"),
	}, { soon = WARDEN }),
	q("EyeOfTheTempest", "Wind", 4, 45, "Eye of the Tempest", "VacuumBlade", {
		step("soon", 1, "Defeat Zephyrus on Hard"),
	}, { soon = WARDEN }),
	q("HeavensEdge", "Wind", 5, 70, "Heaven's Edge", "HeavenSplitter", {
		step("soon", 1, "Collect 3 Gale Crowns from Nightmare Zephyrus"),
	}, { soon = WARDEN }),

	-- Shadow ----------------------------------------------------------------------------------
	q("FirstShadow", "Shadow", 1, 1, "First Shadow", "ShadeStep", {
		step("hits", 20, "Hit dummies from behind 20 times", { dummy = true, behind = true }),
		step("beatBot", 1, "Beat the Sparring Bot"),
	}),
	q("NightsBite", "Shadow", 1, 5, "Night's Bite", "UmbralFangs", {
		step("counterHits", 10, "Land 10 Counter Hits: hit enemies during their wind-up"),
		step("beatBot", 1, "Beat the Sparring Bot using at least 3 feints", { feints = 3 }),
	}),
	q("TwoShadows", "Shadow", 2, 10, "Two Shadows", "ShadeClone", {
		step("soon", 1, "Cross Umbral Hollow unseen, then defeat the Shade Hunter"),
	}, { soon = TRIAL }),
	q("GraspOfNight", "Shadow", 2, 15, "Grasp of Night", "VoidGrasp", {
		step("statuses", 40, "Blind or Silence enemies 40 times", { names = { "Blind", "Silence" } }),
		step("hits", 10, "Land 10 Punish hits: hit within 1 s of a parry", { punish = true }),
	}),
	q("ShadowWarden", "Shadow", 3, 25, "The Shadow Warden", "NightfallVeil", {
		step("soon", 1, "Defeat Umbrael on Normal"),
	}, { soon = WARDEN }),
	q("MoonlessNight", "Shadow", 4, 45, "Moonless Night", "EclipseRend", {
		step("soon", 1, "Defeat Umbrael on Hard"),
	}, { soon = WARDEN }),
	q("NightEternal", "Shadow", 5, 70, "Night Eternal", "Eclipse", {
		step("soon", 1, "Collect 3 Moon Shards from Nightmare Umbrael"),
	}, { soon = WARDEN }),

	-- Earth -----------------------------------------------------------------------------------
	q("FirstStone", "Earth", 1, 1, "First Stone", "StonePillar", {
		step("guardBreaks", 5, "Break the Block Dummy's guard 5 times", { dummy = true }),
		step("beatBot", 1, "Beat the Sparring Bot"),
	}),
	q("HeavyHands", "Earth", 1, 5, "Heavy Hands", "RockToss", {
		step("hits", 20, "Land 20 heavy attacks", { heavy = true }),
		step("grabs", 3, "Land 3 grabs on players or bots"),
	}),
	q("CanyonTrial", "Earth", 2, 10, "Canyon Trial", "QuakeStomp", {
		step("soon", 1, "Hold the Terra Gorge pass against 4 waves of Stone Golems"),
	}, { soon = TRIAL }),
	q("Unbreakable", "Earth", 2, 15, "Unbreakable", "GraniteSkin", {
		step("blockAbsorb", 500, "Absorb 500 damage by blocking"),
		step("beatBot", 3, "Beat the Sparring Bot 3 times after dropping below 30 health", { lowHealth = 30 }),
	}),
	q("StoneWarden", "Earth", 3, 25, "The Stone Warden", "TectonicRift", {
		step("soon", 1, "Defeat Ordo on Normal"),
	}, { soon = WARDEN }),
	q("MountainsGrip", "Earth", 4, 45, "Mountain's Grip", "EarthenPrison", {
		step("soon", 1, "Defeat Ordo on Hard with nobody KO'd"),
	}, { soon = WARDEN }),
	q("HeartOfTheMountain", "Earth", 5, 70, "Heart of the Mountain", "MountainsWrath", {
		step("soon", 1, "Collect 3 Mountain Hearts from Nightmare Ordo"),
	}, { soon = WARDEN }),
}

Progression.QuestById = {}
for i, quest in Progression.Quests do
	quest.order = i
	Progression.QuestById[quest.id] = quest
end

-- The quest before this one on the same path (it must be finished first).
function Progression.previous(quest)
	local prev = nil
	for _, other in Progression.Quests do
		if other == quest then
			return prev
		end
		if other.path == quest.path then
			prev = other
		end
	end
	return nil
end

-- Which quest grants an Echo (for the locked cards in the Echo menu).
Progression.QuestForEcho = {}
for _, quest in Progression.Quests do
	if quest.reward then
		Progression.QuestForEcho[quest.reward] = quest
	end
end

-- Daily tasks: three a day from this pool, one free reroll. Reward 400 XP + 25 per level and 300 coins.
Progression.Daily = {
	{ id = "hits150", type = "hits", count = 150, text = "Land 150 hits" },
	{ id = "parry20", type = "parries", count = 20, text = "Parry 20 attacks" },
	{ id = "echo30", type = "echoUses", count = 30, text = "Use Echoes 30 times" },
	{ id = "finish2", type = "finishers", count = 2, text = "Land 2 finishers" },
	{ id = "combo10", type = "combo", count = 10, text = "Land a 10-hit combo" },
	{ id = "roll40", type = "dodges", count = 40, text = "Roll through 40 attacks" },
	{ id = "status30", type = "statuses", count = 30, text = "Apply 30 status effects" },
	{ id = "break10", type = "guardBreaks", count = 10, text = "Break 10 guards" },
	{ id = "clash3", type = "clashes", count = 3, text = "Win 3 Clashes" },
	{ id = "bot3", type = "beatBot", count = 3, text = "Beat the Sparring Bot 3 times" },
	{ id = "damage1500", type = "damage", count = 1500, text = "Deal 1,500 damage" },
	{ id = "aerial10", type = "hits", count = 10, text = "Land 10 hits in the air", airborne = true },
}
function Progression.dailyReward(level: number)
	return 400 + 25 * level, 300
end

return Progression
