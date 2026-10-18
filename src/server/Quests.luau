-- Quests, daily tasks, and XP/coins from fighting. Listens to Combat's fight events, moves
-- every open quest step and daily task forward, and pays rewards.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progression = require(ReplicatedStorage.Shared.Progression)
local EchoData = require(ReplicatedStorage.Shared.Combat.Echoes)
local Combat = require(script.Parent.Combat)
local Profile = require(script.Parent.Profile)

local Quests = {}

-- Per-player fight memory that is not saved.
type Session = {
	lastDashAt: number,
	comboCount: number,
	comboDummyOnly: boolean,
	lastHitAt: number,
	fights: { [Model]: { start: number, rolls: number, feints: number, minHealth: number } },
	koLog: { [string]: { number } },
}
local sessions: { [Player]: Session } = {}

local function session(player: Player): Session
	local s = sessions[player]
	if not s then
		s = { lastDashAt = -100, comboCount = 0, comboDummyOnly = true, lastHitAt = 0, fights = {}, koLog = {} }
		sessions[player] = s
	end
	return s
end

-- Which player controls a fighter (replaceable in tests).
function Quests.playerOf(state): Player?
	return state and Players:GetPlayerFromCharacter(state.model) or nil
end
local function playerOf(state): Player?
	return Quests.playerOf(state)
end

local function isBot(state): boolean
	return state ~= nil and state.model:GetAttribute("IsBot") == true
end

local function isDummy(state): boolean
	return state ~= nil and state.dummyMode ~= nil
end

-- Whether a quest is open for this player right now.
function Quests.available(data, quest): boolean
	if quest.soon or data.completed[quest.id] or data.level < quest.level then
		return false
	end
	local prev = Progression.previous(quest)
	return prev == nil or data.completed[prev.id] == true
end

-- Every filter a step sets must hold in the event's context.
local FILTERS = { "dummy", "behind", "afterDash", "airborne", "heavy", "onAirborne", "punish" }
local function matches(step, ctx): boolean
	for _, key in FILTERS do
		if step[key] and not ctx[key] then
			return false
		end
	end
	if step.names and not table.find(step.names, ctx.name) then
		return false
	end
	if step.type == "beatBot" then
		if step.within and (ctx.elapsed or math.huge) > step.within then
			return false
		end
		if step.noRolls and (ctx.rolls or 0) > 0 then
			return false
		end
		if step.feints and (ctx.feints or 0) < step.feints then
			return false
		end
		if step.lowHealth and (ctx.minHealth or 100) >= step.lowHealth then
			return false
		end
		if step.element and ctx.element ~= step.element then
			return false
		end
	end
	return true
end

local function completeQuest(player: Player, data, quest)
	data.quests[quest.id] = nil
	data.completed[quest.id] = true
	local i = table.find(data.tracked, quest.id)
	if i then
		table.remove(data.tracked, i)
	end
	local tier = Progression.Tiers[quest.tier]
	local xp = quest.xp or tier.xp
	local coins = quest.coins or tier.coins
	if quest.reward then
		Profile.grantEcho(player, quest.reward)
	end
	Profile.event(player, "quest", { id = quest.id, echo = quest.reward, xp = xp, coins = coins })
	Profile.addCoins(player, coins)
	if quest.setLevel then
		Profile.setLevelAtLeast(player, quest.setLevel)
	end
	Profile.addXP(player, xp)
	-- Track the next quest on the path automatically.
	for _, other in Progression.Quests do
		if other.path == quest.path and Quests.available(data, other) and not table.find(data.tracked, other.id) then
			if #data.tracked < 3 then
				table.insert(data.tracked, other.id)
			end
			break
		end
	end
end

local function dailyDay(): number
	return math.floor(os.time() / 86400)
end

local function rollDaily(data, exclude: { string }?)
	local pool = {}
	for _, task in Progression.Daily do
		if not exclude or not table.find(exclude, task.id) then
			table.insert(pool, task)
		end
	end
	return table.remove(pool, math.random(1, #pool))
end

local function ensureDaily(data)
	if data.daily.day == dailyDay() then
		return
	end
	data.daily = { day = dailyDay(), tasks = {}, rerolls = 1 }
	local picked = {}
	for _ = 1, 3 do
		local task = rollDaily(data, picked)
		table.insert(picked, task.id)
		table.insert(data.daily.tasks, { id = task.id, n = 0, done = false })
	end
end

-- Adds progress of `kind` to every open quest step and daily task it fits.
-- mode "max" keeps the best value (combos); "set" replaces it (streaks).
local function progress(player: Player, kind: string, amount: number, ctx: { [string]: any }?, mode: string?)
	local data = Profile.get(player)
	if not data then
		return
	end
	ctx = ctx or {}
	local changed = false
	for _, quest in Progression.Quests do
		if Quests.available(data, quest) then
			local state = data.quests[quest.id] or { step = 1, n = 0 }
			local step = quest.steps[state.step]
			if step and step.type == kind and matches(step, ctx) then
				local before = state.n
				if mode == "max" then
					state.n = math.max(state.n, amount)
				elseif mode == "set" then
					state.n = amount
				else
					state.n += amount
				end
				state.n = math.min(state.n, step.count)
				data.quests[quest.id] = state
				if state.n ~= before then
					changed = true
				end
				if state.n >= step.count then
					if state.step >= #quest.steps then
						completeQuest(player, data, quest)
					else
						state.step += 1
						state.n = 0
						Profile.event(player, "step", { quest = quest.id, step = state.step })
					end
				end
			end
		end
	end
	ensureDaily(data)
	for _, entry in data.daily.tasks do
		local task = nil
		for _, t in Progression.Daily do
			if t.id == entry.id then
				task = t
			end
		end
		if task and not entry.done and task.type == kind and matches(task, ctx) then
			if mode == "max" then
				entry.n = math.max(entry.n, amount)
			elseif mode ~= "set" then
				entry.n += amount
			end
			entry.n = math.min(entry.n, task.count)
			changed = true
			if entry.n >= task.count then
				entry.done = true
				local xp, coins = Progression.dailyReward(data.level)
				Profile.event(player, "daily", { text = task.text, xp = xp, coins = coins })
				Profile.addCoins(player, coins)
				Profile.addXP(player, xp)
			end
		end
	end
	if changed then
		Profile.changed(player)
	end
end
Quests.progress = progress

-- The element every equipped Echo shares, if they all share one.
local function loadoutElement(player: Player): string?
	local element = nil
	for i = 1, 3 do
		local e = EchoData.get(player:GetAttribute("Echo" .. i))
		if e then
			if element and element ~= e.element then
				return nil
			end
			element = e.element
		end
	end
	return element
end

local function fightWith(player: Player, bot: Model)
	local s = session(player)
	local fight = s.fights[bot]
	if not fight then
		fight = { start = os.clock(), rolls = 0, feints = 0, minHealth = 100 }
		s.fights[bot] = fight
		bot.Destroying:Connect(function()
			s.fights[bot] = nil
		end)
	end
	return fight
end

local function koReward(player: Player, victimKey: string, finisher: boolean, bot: boolean)
	local s = session(player)
	local log = s.koLog[victimKey] or {}
	local now = os.clock()
	for i = #log, 1, -1 do
		if now - log[i] > 600 then
			table.remove(log, i)
		end
	end
	-- Anti-farming: each repeat KO of the same victim within 10 minutes pays 25% less.
	local mult = math.max(Progression.XP.minRepeat, 1 - Progression.XP.repeatFalloff * #log)
	table.insert(log, now)
	s.koLog[victimKey] = log
	local xp = Progression.XP.ko * mult * (if finisher then 1 + Progression.XP.finisherBonus else 1)
	Profile.addXP(player, xp)
	Profile.addCoins(player, math.floor((if bot then 10 else Progression.Coins.ko) * mult))
end

local function onHit(attacker, target, move, isHeavy, info)
	local player = playerOf(attacker)
	if not player then
		return
	end
	local s = session(player)
	local now = os.clock()
	local dummy = isDummy(target)
	if not dummy then
		Profile.addXP(player, Progression.XP.hit)
	end
	if isBot(target) then
		fightWith(player, target.model)
	end
	local ctx = {
		dummy = dummy,
		behind = info.behind,
		afterDash = now - s.lastDashAt < 1,
		airborne = info.airborne,
		heavy = isHeavy and not move.echo,
		onAirborne = info.onAirborne,
		punish = info.punish,
	}
	progress(player, "hits", 1, ctx)
	-- Combos: hits no more than 1.5 s apart.
	if now - s.lastHitAt < 1.5 then
		s.comboCount += 1
		s.comboDummyOnly = s.comboDummyOnly and dummy
	else
		s.comboCount = 1
		s.comboDummyOnly = dummy
	end
	s.lastHitAt = now
	progress(player, "combo", s.comboCount, { dummy = s.comboDummyOnly }, "max")
	if info.counterHit then
		progress(player, "counterHits", 1)
	end
	if move.lift then
		progress(player, "launches", 1)
	end
	local cast = move.cast
	if cast and not cast.counted then
		cast.targets[target] = true
		local n = 0
		for _ in cast.targets do
			n += 1
		end
		if n >= 3 then
			cast.counted = true
			progress(player, "echoMulti", 1)
		end
	end
end

function Quests.start()
	Combat.on("hit", onHit)
	Combat.on("damage", function(attacker, target, amount)
		local player = playerOf(attacker)
		if player then
			progress(player, "damage", amount)
		end
		-- Remember how low you dropped in a fight with the bot.
		local victim = playerOf(target)
		if victim and isBot(attacker) then
			local fight = fightWith(victim, attacker.model)
			fight.minHealth = math.min(fight.minHealth, target.humanoid.Health - amount)
		end
	end)
	Combat.on("block", function(defender, _, absorbed)
		local player = playerOf(defender)
		if player then
			progress(player, "blocks", 1)
			progress(player, "blockAbsorb", absorbed)
		end
	end)
	Combat.on("parry", function(defender, _, move)
		local player = playerOf(defender)
		if player then
			progress(player, "parries", 1)
			if move.projectile then
				progress(player, "projectileParries", 1)
			end
		end
	end)
	Combat.on("dodge", function(defender, _, riftStep)
		local player = playerOf(defender)
		if player then
			progress(player, "dodges", 1)
			if riftStep then
				progress(player, "riftSteps", 1)
			end
		end
	end)
	Combat.on("guardbreak", function(attacker, target)
		local player = playerOf(attacker)
		if player then
			progress(player, "guardBreaks", 1, { dummy = isDummy(target) })
		end
	end)
	Combat.on("clash", function(a, b)
		for _, st in { a, b } do
			local player = playerOf(st)
			if player then
				progress(player, "clashes", 1)
			end
		end
	end)
	Combat.on("grab", function(attacker, target)
		local player = playerOf(attacker)
		if player and not isDummy(target) then
			progress(player, "grabs", 1)
		end
	end)
	Combat.on("finisher", function(attacker)
		local player = playerOf(attacker)
		if player then
			progress(player, "finishers", 1)
		end
	end)
	Combat.on("feint", function(st)
		local player = playerOf(st)
		if player then
			for _, fight in session(player).fights do
				fight.feints += 1
			end
		end
	end)
	Combat.on("status", function(source, target, name)
		local player = playerOf(source)
		if player and source ~= target then
			progress(player, "statuses", 1, { name = name })
			if name == "Freeze" then
				progress(player, "freezes", 1)
			end
		end
		local victim = playerOf(target)
		if victim then
			progress(victim, "suffered", 1)
		end
	end)
	Combat.on("echo", function(st)
		local player = playerOf(st)
		if player then
			progress(player, "echoUses", 1)
		end
	end)
	Combat.on("riftburst", function(st)
		local player = playerOf(st)
		if player then
			progress(player, "riftBursts", 1)
		end
	end)
	Combat.on("ko", function(killer, victim, finisher)
		local victimPlayer = playerOf(victim)
		if victimPlayer then
			local data = Profile.get(victimPlayer)
			if data then
				data.stats.botStreak = 0
				progress(victimPlayer, "botStreak", 0, nil, "set")
			end
		end
		local player = playerOf(killer)
		if not player then
			return
		end
		if isBot(victim) then
			local fight = fightWith(player, victim.model)
			local ctx = {
				elapsed = os.clock() - fight.start,
				rolls = fight.rolls,
				feints = fight.feints,
				minHealth = fight.minHealth,
				element = loadoutElement(player),
			}
			progress(player, "beatBot", 1, ctx)
			progress(player, "kos", 1)
			local data = Profile.get(player)
			if data then
				data.stats.botStreak = (data.stats.botStreak or 0) + 1
				progress(player, "botStreak", data.stats.botStreak, nil, "set")
			end
			koReward(player, "bot", finisher, true)
		elseif victimPlayer then
			progress(player, "kos", 1)
			koReward(player, tostring(victimPlayer.UserId), finisher, false)
		end
	end)

	-- Airborne time in fights (Walk the Sky).
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				local st = player.Character and Combat.state(player.Character)
				if st and Combat.alive(st) and st.humanoid.FloorMaterial == Enum.Material.Air then
					local t = Combat.now()
					if t - st.lastDamageAt < 5 or t - st.lastAttackAt < 5 then
						progress(player, "airTime", 0.5)
					end
				end
			end
		end
	end)

	Profile.actions.Track = function(player, id)
		local data = Profile.get(player)
		local quest = Progression.QuestById[id]
		if not data or not quest then
			return
		end
		local i = table.find(data.tracked, id)
		if i then
			table.remove(data.tracked, i)
		elseif Quests.available(data, quest) then
			if #data.tracked >= 3 then
				table.remove(data.tracked, 1)
			end
			table.insert(data.tracked, id)
		end
		Profile.changed(player)
	end
	Profile.actions.Reroll = function(player, index)
		local data = Profile.get(player)
		if not data or typeof(index) ~= "number" then
			return
		end
		ensureDaily(data)
		local entry = data.daily.tasks[index]
		if not entry or entry.done or data.daily.rerolls <= 0 then
			return
		end
		local exclude = {}
		for _, e in data.daily.tasks do
			table.insert(exclude, e.id)
		end
		data.daily.rerolls -= 1
		data.daily.tasks[index] = { id = rollDaily(data, exclude).id, n = 0, done = false }
		Profile.changed(player)
	end

	-- New players start with the tutorial and their first path quests tracked.
	local function initTracked(player)
		local data = Profile.waitLoaded(player)
		if not data then
			return
		end
		ensureDaily(data)
		if #data.tracked == 0 and next(data.completed) == nil then
			data.tracked = { "SteelAndFootwork", "FirstSpark" }
		end
		Profile.changed(player)
	end
	Profile.onReset = function(player)
		sessions[player] = nil
		task.spawn(initTracked, player)
	end
	Players.PlayerAdded:Connect(initTracked)
	for _, player in Players:GetPlayers() do
		task.spawn(initTracked, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
	local _ = RunService
end

-- Movement the server hears about from the action relay (flips, dashes, rolls).
function Quests.onAction(player: Player, name: string)
	local s = session(player)
	if string.sub(name, 1, 4) == "Flip" then
		progress(player, "flips", 1)
	elseif name == "Dash" or name == "Slide" or name == "AirDash" then
		s.lastDashAt = os.clock()
	elseif string.sub(name, 1, 4) == "Roll" or string.sub(name, 1, 9) == "Cartwheel" then
		for _, fight in s.fights do
			fight.rolls += 1
		end
	end
end

return Quests
