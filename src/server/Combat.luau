-- Server-authoritative combat: the client only says "I pressed attack"; the server decides
-- timing, hits, blocks, parries, posture, stuns and damage, then tells every client what to show.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Swords = require(ReplicatedStorage.Shared.Combat.Swords)
local Echoes = require(ReplicatedStorage.Shared.Combat.Echoes)

local Combat = {}

local C = Swords.Combat

type State = {
	model: Model,
	humanoid: Humanoid,
	hrp: BasePart,
	posture: number,
	lastPostureHit: number,
	lastDamageAt: number,
	blocking: boolean,
	blockStart: number,
	blockLockUntil: number,
	parriedDuringBlock: boolean,
	comboIndex: number,
	lastLightAt: number,
	busyUntil: number,
	chargingSince: number?,
	guardBroken: boolean,
	dummyMode: string?,
	pendingStrikeAt: number?,
	strikeToken: number,
	swordId: string,
	lastAttackAt: number,
	lastHitLandedAt: number,
	frenzyStacks: number,
	armorUntil: number,
	riposteUntil: number,
	empowerUntil: number,
	empowerStatus: string?,
	chainCount: number,
	chainLastAt: number,
	statusOrder: { string },
	burnSource: any?,
	baseWalkSpeed: number?,
	nextBurnAt: number?,
}

local states: { [Model]: State } = {}
local updateSpeed
local fxRemote: RemoteEvent
local knockbackRemote: RemoteEvent
local swingListeners: { (Model, any, boolean, number) -> () } = {}
local landedListeners: { (any, any, any, boolean) -> () } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function fx(kind: string, attacker: Model?, target: Model?, position: Vector3?, amount: number?, extra: any?)
	fxRemote:FireAllClients(kind, attacker, target, position, amount, extra)
end

local function swordOf(s: State)
	return Swords.get(s.swordId)
end

local function alive(s: State?): boolean
	return s ~= nil and s.model.Parent ~= nil and s.humanoid.Health > 0
end

local function stunned(s: State): boolean
	local untilTime = s.model:GetAttribute("StunnedUntil")
	return typeof(untilTime) == "number" and now() < untilTime
end

local function hasStatus(s: State, name: string): boolean
	local untilTime = s.model:GetAttribute("Status_" .. name)
	return typeof(untilTime) == "number" and now() < untilTime
end

local function stun(s: State, seconds: number)
	-- Shock: every hit taken adds a 0.15 s micro-stun.
	if hasStatus(s, "Shock") then
		seconds += 0.15
	end
	local untilTime = now() + seconds
	local current = s.model:GetAttribute("StunnedUntil")
	if typeof(current) ~= "number" or current < untilTime then
		s.model:SetAttribute("StunnedUntil", untilTime)
	end
	s.chargingSince = nil
	-- Getting hit during a wind-up cancels the attack.
	s.strikeToken += 1
	s.pendingStrikeAt = nil
	if s.blocking then
		s.blocking = false
		fx("stop", s.model, nil, nil, nil, "Block")
	end
end

local function setPosture(s: State, value: number)
	s.posture = math.clamp(value, 0, C.maxPosture)
	s.model:SetAttribute("Posture", math.floor(s.posture + 0.5))
end

local function damage(s: State, amount: number)
	s.lastDamageAt = now()
	local h = s.humanoid
	if s.dummyMode then
		-- Dummies never die; they reset after a "KO".
		h.Health = math.max(h.Health - amount, 1)
		if h.Health <= 1 then
			fx("ko", nil, s.model, s.hrp.Position)
			task.delay(1.5, function()
				if s.model.Parent then
					h.Health = h.MaxHealth
					setPosture(s, C.maxPosture)
				end
			end)
		end
	else
		h.Health = math.max(h.Health - amount, 0)
	end
end

local function addSurge(s: State?, amount: number)
	if not s or amount <= 0 then
		return
	end
	local current = s.model:GetAttribute("Surge")
	local value = math.clamp((if typeof(current) == "number" then current else 0) + amount, 0, Echoes.Surge.max)
	s.model:SetAttribute("Surge", value)
end

-- Every damaging hit goes through here: buffs, Mark, and Surge for both sides.
local function active(model: Model, attribute: string): boolean
	local untilTime = model:GetAttribute(attribute)
	return typeof(untilTime) == "number" and now() < untilTime
end

local function hurt(attacker: State?, target: State, amount: number, tick: boolean?): number
	-- Freeze: the next real hit shatters the ice for 8 bonus damage and frees the target.
	if not tick and hasStatus(target, "Freeze") then
		amount += 8
		target.model:SetAttribute("Status_Freeze", nil)
		target.model:SetAttribute("StunnedUntil", nil)
		fx("shatter", nil, target.model, target.hrp.Position)
	end
	if active(target.model, "GraniteUntil") then
		amount *= 0.6
	end
	if active(target.model, "EntombedUntil") then
		amount *= 0.5
	end
	-- Rift Barrier soaks damage first.
	local shield = target.model:GetAttribute("Shield")
	if typeof(shield) == "number" and shield > 0 and active(target.model, "ShieldUntil") then
		local soaked = math.min(shield, amount)
		amount -= soaked
		target.model:SetAttribute("Shield", if shield - soaked > 0 then shield - soaked else nil)
		if shield - soaked <= 0 then
			target.model:SetAttribute("ShieldUntil", nil)
			fx("shieldbreak", nil, target.model, target.hrp.Position)
		end
	end
	if attacker and typeof(attacker.model:GetAttribute("BattleCryUntil")) == "number" then
		if now() < attacker.model:GetAttribute("BattleCryUntil") then
			amount *= 1.15
		end
	end
	if hasStatus(target, "Mark") then
		amount *= 1.2
		target.model:SetAttribute("Status_Mark", nil)
	end
	damage(target, amount)
	addSurge(attacker, amount * Echoes.Surge.perDamageDealt)
	addSurge(target, amount * Echoes.Surge.perDamageTaken)
	return amount
end

-- Statuses (master plan): at most two different ones at a time, a third replaces the oldest;
-- reapplying refreshes. Stored as Status_<name> = server time it ends, so clients can show it.
local applyStatus
function applyStatus(target: State, name: string, duration: number?, source: State?)
	local info = Echoes.Statuses[name]
	if not info or not alive(target) then
		return
	end
	local seconds = duration or info.duration
	if source and source.model:GetAttribute("Attuned") then
		seconds *= 1.15
	end
	local order = target.statusOrder
	local i = table.find(order, name)
	if i then
		table.remove(order, i)
	else
		-- Drop expired entries, then make room.
		for j = #order, 1, -1 do
			if not hasStatus(target, order[j]) then
				table.remove(order, j)
			end
		end
		if #order >= 2 then
			target.model:SetAttribute("Status_" .. table.remove(order, 1), nil)
		end
	end
	table.insert(order, name)
	if name == "Chill" then
		-- Chill stacks up to 3; the third stack Freezes. Status_Chill is the next decay time.
		local stacks = (target.model:GetAttribute("ChillStacks") or 0) + 1
		if stacks >= 3 then
			target.model:SetAttribute("ChillStacks", nil)
			target.model:SetAttribute("Status_Chill", nil)
			table.remove(order, table.find(order, "Chill"))
			applyStatus(target, "Freeze", nil, source)
			return
		end
		target.model:SetAttribute("ChillStacks", stacks)
		target.model:SetAttribute("Status_Chill", now() + 1)
		return
	end
	target.model:SetAttribute("Status_" .. name, now() + seconds)
	if name == "Burn" then
		target.burnSource = source
	elseif name == "Freeze" then
		stun(target, seconds)
	elseif name == "Airborne" and target.blocking then
		target.blocking = false
		fx("stop", target.model, nil, nil, nil, "Block")
	end
end

local function clearStatuses(s: State)
	for name in Echoes.Statuses do
		s.model:SetAttribute("Status_" .. name, nil)
	end
	table.clear(s.statusOrder)
end

local function knockback(target: State, from: Vector3, strength: number, lift: number?)
	local dir = (target.hrp.Position - from) * Vector3.new(1, 0, 1)
	dir = if dir.Magnitude > 0.01 then dir.Unit else target.hrp.CFrame.LookVector * -1
	local velocity = dir * strength + Vector3.new(0, lift or strength * 0.3, 0)
	local player = Players:GetPlayerFromCharacter(target.model)
	if player then
		knockbackRemote:FireClient(player, velocity)
	else
		target.hrp.AssemblyLinearVelocity = velocity
	end
end

local function facing(from: BasePart, toPosition: Vector3, arcDegrees: number): boolean
	local dir = (toPosition - from.Position) * Vector3.new(1, 0, 1)
	if dir.Magnitude < 0.01 then
		return true
	end
	local look = from.CFrame.LookVector * Vector3.new(1, 0, 1)
	return look.Unit:Dot(dir.Unit) >= math.cos(math.rad(arcDegrees / 2))
end

local function applyHit(attacker: State, target: State, move, isHeavy: boolean, amount: number)
	local t = now()
	local invul = target.model:GetAttribute("InvulnerableUntil")
	if typeof(invul) == "number" and t < invul then
		fx("dodge", attacker.model, target.model, target.hrp.Position)
		return
	end
	local hitPos = target.hrp.Position + Vector3.new(0, 0.8, 0)

	-- Counter stances (Glacial Guard, Mirror Guard) answer the hit instead of taking it.
	local counter = target.model:GetAttribute("CounterKind")
	if counter and active(target.model, "CounterUntil") then
		if counter == "GlacialGuard" then
			target.model:SetAttribute("CounterKind", nil)
			fx("counter", target.model, attacker.model, hitPos, nil, counter)
			-- The counter-slash lands first, then the attacker freezes (so it does not shatter it).
			if (attacker.hrp.Position - target.hrp.Position).Magnitude < 10 then
				local dealt = hurt(target, attacker, 8)
				fx("hit", target.model, attacker.model, attacker.hrp.Position, dealt, true)
			end
			applyStatus(attacker, "Freeze", 0.8, target)
			return
		elseif counter == "MirrorGuard" and not move.projectile then
			fx("parry", attacker.model, target.model, hitPos)
			if not move.ranged then
				stun(attacker, C.parriedStun)
				local dealt = hurt(target, attacker, 15)
				fx("hit", target.model, attacker.model, attacker.hrp.Position, dealt, true)
			end
			return
		end
	end

	-- Clash: both fighters' strikes land within 0.12 s of each other while facing.
	local pending = target.pendingStrikeAt
	if
		not move.echo
		and pending
		and math.abs(pending - t) <= 0.12
		and facing(target.hrp, attacker.hrp.Position, 120)
	then
		stun(target, 0.5)
		stun(attacker, 0.5)
		for _, s in { attacker, target } do
			s.lastPostureHit = t
			setPosture(s, s.posture - 15)
			addSurge(s, Echoes.Surge.perClash)
		end
		knockback(target, attacker.hrp.Position, 28)
		knockback(attacker, target.hrp.Position, 28)
		fx(
			"clash",
			attacker.model,
			target.model,
			(attacker.hrp.Position + target.hrp.Position) / 2 + Vector3.new(0, 1, 0)
		)
		return
	end

	local from = move.from or attacker.hrp.Position
	local blockingNow = not move.unblockable and target.blocking and facing(target.hrp, from, C.blockArc)
	local canParry = not move.unblockable and not move.unparryable
	-- The parry dummy practises sword timing only; Echoes go through it.
	local dummyParry = canParry and not move.echo and target.dummyMode == "Parry" and math.random() < 0.5
	local parryWindow = swordOf(target).parryWindow or C.parryWindow
	if canParry and (dummyParry or (blockingNow and t - target.blockStart <= parryWindow)) then
		target.parriedDuringBlock = true
		target.riposteUntil = t + 1
		addSurge(target, Echoes.Surge.perParry)
		if not move.ranged then
			stun(attacker, C.parriedStun)
		end
		fx("parry", attacker.model, target.model, hitPos)
		return
	end

	if blockingNow then
		local chip = amount * (1 - C.blockReduction)
		hurt(attacker, target, chip)
		target.lastPostureHit = t
		local postureCost = move.posture * (if swordOf(target).passive == "steadfast" then 0.85 else 1)
		if hasStatus(target, "Fracture") then
			postureCost *= 1.5
		end
		setPosture(target, target.posture - postureCost)
		if target.posture <= 0 then
			target.guardBroken = true
			stun(target, C.guardBreakStun)
			fx("guardbreak", attacker.model, target.model, hitPos)
			task.delay(C.guardBreakStun, function()
				target.guardBroken = false
				if target.model.Parent then
					setPosture(target, C.maxPosture * 0.5)
				end
			end)
		else
			fx("block", attacker.model, target.model, hitPos, chip)
		end
		return
	end

	if target.guardBroken then
		amount *= 1 + C.guardBreakDamageBonus
	end
	-- Frenzy (Twin Fangs): consecutive hits speed up the next attacks.
	if t - attacker.lastHitLandedAt < 1.5 then
		attacker.frenzyStacks = math.min(attacker.frenzyStacks + 1, 5)
	else
		attacker.frenzyStacks = 1
	end
	attacker.lastHitLandedAt = t
	amount = hurt(attacker, target, amount)
	if t - target.chainLastAt > 1.5 then
		target.chainCount = 0
	end
	target.chainCount += 1
	target.chainLastAt = t
	if target.chainCount >= 3 then
		-- Taking 3 hits in a row opens the Rift Burst combo breaker for a moment.
		target.model:SetAttribute("BurstUntil", t + 1.5)
	end
	if move.status then
		applyStatus(target, move.status, move.statusTime, attacker)
	end
	for _, fn in landedListeners do
		task.spawn(fn, attacker, target, move, isHeavy)
	end
	-- Hyper armor (Titan's Maw heavies, Iron Will): light hits still hurt but cannot interrupt.
	local armored = (swordOf(target).passive == "unstoppable" and target.chargingSince ~= nil) or t < target.armorUntil
	if armored and not isHeavy then
		fx("hit", attacker.model, target.model, hitPos, amount, false)
		fx("armor", nil, target.model, hitPos)
		return
	end
	stun(target, move.stun or (if isHeavy then C.heavyStun else C.hitStun))
	if move.knockback or move.lift then
		knockback(target, from, move.knockback or 0, move.lift)
	end
	fx("hit", attacker.model, target.model, hitPos, amount, isHeavy or move.knockback ~= nil or move.lift ~= nil)
end

local function resolve(attacker: State, move, isHeavy: boolean, amount: number, token: number, final: boolean)
	local armoredSwing = isHeavy and swordOf(attacker).passive == "unstoppable"
	if not alive(attacker) or (stunned(attacker) and not armoredSwing) or token ~= attacker.strikeToken then
		return -- interrupted during the wind-up
	end
	if final then
		attacker.pendingStrikeAt = nil
	end
	local precision = swordOf(attacker).passive == "precision"
	for _, target in states do
		if target ~= attacker and alive(target) then
			local offset = (target.hrp.Position - attacker.hrp.Position) * Vector3.new(1, 0, 1)
			local dist = offset.Magnitude
			if dist <= move.range + 1.5 and (dist < 3 or facing(attacker.hrp, target.hrp.Position, move.arc)) then
				-- Precision (Fleuret): hits with the very tip of the blade deal 25% more.
				local tip = precision and dist >= move.range - 2
				applyHit(attacker, target, move, isHeavy, if tip then amount * 1.25 else amount)
			end
		end
	end
end

local function onLight(s: State)
	local t = now()
	if t < s.busyUntil or stunned(s) or s.blocking or s.chargingSince then
		return
	end
	local sword = swordOf(s)
	if t - s.lastLightAt > sword.comboReset or s.comboIndex >= #sword.light then
		s.comboIndex = 0
	end
	s.comboIndex += 1
	s.lastLightAt = t
	local move = sword.light[s.comboIndex]
	local amount = move.damage
	-- Sheath Draw (Kage): the first strike after 2 s of calm deals 40% more.
	if sword.passive == "sheathDraw" and t - s.lastAttackAt > 2 then
		amount *= 1.4
	end
	-- Riposte (Fleuret): the first light after a parry deals 30% more.
	if sword.passive == "precision" and t < s.riposteUntil then
		amount *= 1.3
		s.riposteUntil = 0
	end
	s.lastAttackAt = t
	if t < s.empowerUntil and s.empowerStatus then
		-- Flash Step: the next light applies a status.
		move = table.clone(move)
		move.status = s.empowerStatus
		s.empowerUntil = 0
	end
	local lock = move.lock
	local haste = s.model:GetAttribute("BattleCryUntil")
	if typeof(haste) == "number" and t < haste then
		lock *= 0.85
	end
	if sword.passive == "frenzy" and t - s.lastHitLandedAt < 1.5 then
		lock *= 1 - 0.05 * s.frenzyStacks
	end
	s.busyUntil = t + lock - 0.05 -- small tolerance for network jitter
	fx("swing", s.model, nil, nil, nil, move.anim)
	Combat.schedule(s, move, false, amount)
end

local function onHeavyStart(s: State)
	local t = now()
	if t < s.busyUntil or stunned(s) or s.blocking or s.chargingSince then
		return
	end
	s.chargingSince = t
	fx("swing", s.model, nil, nil, nil, swordOf(s).heavy.charge)
	fx("charge", s.model)
end

local function onHeavyRelease(s: State)
	local started = s.chargingSince
	if not started or stunned(s) then
		return
	end
	s.chargingSince = nil
	local h = swordOf(s).heavy
	local charge = math.clamp((now() - started - h.minCharge) / (h.fullCharge - h.minCharge), 0, 1)
	local amount = h.damage + (h.chargedDamage - h.damage) * charge
	s.busyUntil = now() + h.lock - 0.05
	s.comboIndex = 0
	s.lastAttackAt = now()
	if h.hyperArmor then
		s.armorUntil = now() + h.lock
	end
	fx("swing", s.model, nil, nil, nil, h.anim)
	if h.toss then
		fx("toss", s.model)
	end
	-- Players move themselves during a lunge; AI fighters are moved here.
	if h.lunge and not Players:GetPlayerFromCharacter(s.model) then
		task.spawn(function()
			local dir = s.hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
			local speed = h.lunge.distance / h.lunge.time
			local stop = os.clock() + h.lunge.time
			while os.clock() < stop and s.model.Parent do
				s.hrp.AssemblyLinearVelocity = dir.Unit * speed + Vector3.new(0, s.hrp.AssemblyLinearVelocity.Y, 0)
				task.wait()
			end
		end)
	end
	Combat.schedule(s, h, true, amount)
end

local function onHeavyCancel(s: State)
	if not s.chargingSince then
		return
	end
	s.chargingSince = nil
	setPosture(s, s.posture - 15)
	s.lastPostureHit = now()
	fx("stop", s.model, nil, nil, nil, swordOf(s).heavy.charge)
end

local function onBlockStart(s: State)
	local t = now()
	if hasStatus(s, "Airborne") then
		return
	end
	if stunned(s) or t < s.blockLockUntil or t < s.busyUntil - 0.1 then
		return
	end
	s.chargingSince = nil
	s.blocking = true
	s.blockStart = t
	s.parriedDuringBlock = false
	fx("swing", s.model, nil, nil, nil, "Block")
end

local function onBlockEnd(s: State)
	if not s.blocking then
		return
	end
	s.blocking = false
	local t = now()
	-- Tapping block without parrying anything locks the guard briefly, so spamming parry fails.
	if t - s.blockStart < 0.3 and not s.parriedDuringBlock then
		s.blockLockUntil = t + C.whiffLock
	end
	fx("stop", s.model, nil, nil, nil, "Block")
end

-- Schedules a move's hits. Multi-hit moves split the total damage across their hits.
function Combat.schedule(s: State, move, isHeavy: boolean, amount: number)
	s.strikeToken += 1
	local token = s.strikeToken
	local hits = move.hits or { { at = move.hitAt, damage = move.damage } }
	local total = 0
	for _, hit in hits do
		total += hit.damage
	end
	local scale = if total > 0 then amount / total else 1
	s.pendingStrikeAt = now() + hits[1].at
	for _, fn in swingListeners do
		task.spawn(fn, s.model, move, isHeavy, s.pendingStrikeAt)
	end
	for i, hit in hits do
		task.delay(hit.at, resolve, s, move, isHeavy, hit.damage * scale, token, i == #hits)
	end
end

local function nearestInFront(s: State, range: number, arc: number, filter: ((State) -> boolean)?): State?
	local best, bestDist = nil, math.huge
	for _, target in states do
		if target ~= s and alive(target) and (not filter or filter(target)) then
			local dist = ((target.hrp.Position - s.hrp.Position) * Vector3.new(1, 0, 1)).Magnitude
			if dist <= range and dist < bestDist and (dist < 2.5 or facing(s.hrp, target.hrp.Position, arc)) then
				best, bestDist = target, dist
			end
		end
	end
	return best
end

-- Grab: slow start, ignores blocking, loses to any attack that lands first.
local function onGrab(s: State)
	local t = now()
	if t < s.busyUntil or stunned(s) or s.blocking or s.chargingSince then
		return
	end
	s.busyUntil = t + 0.9
	s.comboIndex = 0
	s.strikeToken += 1
	local token = s.strikeToken
	fx("swing", s.model, nil, nil, nil, "GrabReach")
	task.delay(0.3, function()
		if token ~= s.strikeToken or not alive(s) or stunned(s) then
			return
		end
		local target = nearestInFront(s, 5.5, 100)
		if not target then
			return
		end
		local invul = target.model:GetAttribute("InvulnerableUntil")
		if typeof(invul) == "number" and now() < invul then
			fx("dodge", s.model, target.model, target.hrp.Position)
			return
		end
		damage(target, 12)
		stun(target, 0.9)
		knockback(target, s.hrp.Position, 42)
		fx("grab", s.model, target.model, target.hrp.Position + Vector3.new(0, 1, 0), 12)
	end)
end

-- Finisher: on an enemy at 15 health or less who is stunned. Anyone can interrupt it.
local FINISH_HEALTH = 15
local function onFinish(s: State)
	local t = now()
	if t < s.busyUntil or stunned(s) or s.blocking then
		return
	end
	local target = nearestInFront(s, 7, 160, function(target)
		return target.humanoid.Health <= FINISH_HEALTH
			and stunned(target)
			and not target.model:GetAttribute("BeingFinished")
	end)
	if not target then
		return
	end
	s.busyUntil = t + 1.5
	s.strikeToken += 1
	local token = s.strikeToken
	target.model:SetAttribute("BeingFinished", true)
	stun(target, 1.6)
	fx("finish", s.model, target.model, target.hrp.Position)
	task.delay(1.1, function()
		if target.model.Parent then
			target.model:SetAttribute("BeingFinished", nil)
		end
		if token ~= s.strikeToken or not alive(s) then
			fx("finishbroken", s.model, target.model, target.hrp.Position)
			return
		end
		fx("finished", s.model, target.model, target.hrp.Position + Vector3.new(0, 1, 0))
		damage(target, target.humanoid.Health)
	end)
end

local function onEquip(s: State, id: any)
	if typeof(id) ~= "string" or not table.find(Swords.Order, id) then
		return
	end
	if stunned(s) or s.blocking or s.chargingSince or now() < s.busyUntil then
		return
	end
	s.swordId = id
	s.comboIndex = 0
	local player = Players:GetPlayerFromCharacter(s.model)
	if player then
		player:SetAttribute("SwordId", id) -- remembered across respawns
	end
	require(script.Parent.Sword).attach(s.model, id)
	fx("equip", s.model, nil, s.hrp.Position, nil, id)
end

local handlers: { [string]: (State, any) -> () } = {
	Equip = onEquip,
	Grab = onGrab,
	Finish = onFinish,
	Light = onLight,
	HeavyStart = onHeavyStart,
	HeavyRelease = onHeavyRelease,
	HeavyCancel = onHeavyCancel,
	BlockStart = onBlockStart,
	BlockEnd = onBlockEnd,
}

-- Other modules (Echoes) add their own actions here.
function Combat.addHandler(name: string, fn: (State, any) -> ())
	handlers[name] = fn
end

-- Entry point for an action from any fighter: player remotes and, later, AI bots.
function Combat.request(model: Model, action: any, arg: any?)
	local handler = typeof(action) == "string" and handlers[action]
	local s = states[model]
	if handler and alive(s) then
		handler(s, arg)
	end
end

function Combat.register(model: Model, dummyMode: string?)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not hrp then
		return
	end
	local s: State = {
		model = model,
		humanoid = humanoid,
		hrp = hrp,
		posture = C.maxPosture,
		lastPostureHit = 0,
		lastDamageAt = 0,
		blocking = dummyMode == "Block",
		blockStart = -100,
		blockLockUntil = 0,
		parriedDuringBlock = false,
		comboIndex = 0,
		lastLightAt = 0,
		busyUntil = 0,
		chargingSince = nil,
		guardBroken = false,
		dummyMode = dummyMode,
		pendingStrikeAt = nil,
		strikeToken = 0,
		swordId = (model:GetAttribute("SwordId") :: string?) or "IronOath",
		lastAttackAt = 0,
		lastHitLandedAt = 0,
		frenzyStacks = 0,
		armorUntil = 0,
		riposteUntil = 0,
		empowerUntil = 0,
		empowerStatus = nil,
		chainCount = 0,
		chainLastAt = 0,
		statusOrder = {},
	}
	states[model] = s
	setPosture(s, C.maxPosture)
	model.Destroying:Connect(function()
		states[model] = nil
	end)
	local player = Players:GetPlayerFromCharacter(model)
	local carried = player and player:GetAttribute("SurgeCarry")
	model:SetAttribute("Surge", if typeof(carried) == "number" then carried else 0)
	humanoid.Died:Connect(function()
		states[model] = nil
		-- Half of the Surge meter is lost on a KO.
		if player then
			local surge = model:GetAttribute("Surge")
			player:SetAttribute("SurgeCarry", if typeof(surge) == "number" then math.floor(surge / 2) else 0)
		end
	end)
end

-- Shared tools for Echoes and other systems built on the same rules.
Combat.now = now
Combat.fx = fx
Combat.alive = alive
Combat.stunned = stunned
Combat.stun = stun
Combat.knockback = knockback
Combat.facing = facing
Combat.addSurge = addSurge
Combat.applyStatus = applyStatus
Combat.clearStatuses = clearStatuses
Combat.hasStatus = hasStatus
Combat.hurt = hurt
Combat.active = active

-- Runs after every hit that lands (Umbral Fangs and similar Strike Echoes use it).
function Combat.onLanded(fn: (any, any, any, boolean) -> ())
	table.insert(landedListeners, fn)
end

-- A short message shown only to one player.
function Combat.notice(player: Player, text: string)
	fxRemote:FireClient(player, "notice", nil, nil, nil, nil, text)
end

function Combat.state(model: Model?): State?
	return if model then states[model] else nil
end

function Combat.all(): { [Model]: State }
	return states
end

-- An Echo hit. It is blockable and parryable like a sword hit unless opts say otherwise.
-- opts: posture, knockback, lift, status, statusTime, stun, heavy, unblockable, unparryable,
-- ranged (a parry does not stagger the caster), from (where the hit comes from).
function Combat.echoHit(attacker: State, target: State, amount: number, opts)
	local move = table.clone(opts or {})
	move.echo = true
	move.posture = move.posture or 10
	applyHit(attacker, target, move, opts and opts.heavy == true, amount)
end

-- Lets AI fighters react to swings: (attacker, move, isHeavy, server time the hit lands).
function Combat.onSwing(fn: (Model, any, boolean, number) -> ())
	table.insert(swingListeners, fn)
end

function Combat.isBlocking(model: Model): boolean
	local s = states[model]
	return s ~= nil and s.blocking
end

-- Movement speed from statuses and buffs. Players' own clients read SpeedMult; AI is set here.
function updateSpeed(s: State)
	local mult = 1
	if hasStatus(s, "Root") or hasStatus(s, "Freeze") then
		mult = 0
	else
		mult *= 1 - 0.15 * (s.model:GetAttribute("ChillStacks") or 0)
		if active(s.model, "GraniteUntil") then
			mult *= 0.8
		end
		if active(s.model, "FrozenPathUntil") then
			mult *= 1.3
		end
		if active(s.model, "TempestUntil") then
			mult *= 1.15
		end
		if active(s.model, "NightfallBoostUntil") then
			mult *= 1.2
		end
	end
	mult = math.floor(mult * 100 + 0.5) / 100
	if (s.model:GetAttribute("SpeedMult") or 1) ~= mult then
		s.model:SetAttribute("SpeedMult", if mult == 1 then nil else mult)
		if not Players:GetPlayerFromCharacter(s.model) then
			s.baseWalkSpeed = s.baseWalkSpeed or s.humanoid.WalkSpeed
			s.humanoid.WalkSpeed = s.baseWalkSpeed * mult
		end
	end
end

function Combat.start(remotes: Folder)
	local request = Instance.new("RemoteEvent")
	request.Name = "Combat"
	request.Parent = remotes
	fxRemote = Instance.new("RemoteEvent")
	fxRemote.Name = "CombatFx"
	fxRemote.Parent = remotes
	knockbackRemote = Instance.new("RemoteEvent")
	knockbackRemote.Name = "Knockback"
	knockbackRemote.Parent = remotes

	request.OnServerEvent:Connect(function(player, action, arg)
		if player.Character then
			Combat.request(player.Character, action, arg)
		end
	end)

	-- Posture and health regeneration.
	RunService.Heartbeat:Connect(function(dt)
		local t = now()
		for _, s in states do
			-- Chill loses a stack every second you are not hit.
			local stacks = s.model:GetAttribute("ChillStacks")
			if typeof(stacks) == "number" and not hasStatus(s, "Chill") then
				s.model:SetAttribute("ChillStacks", if stacks > 1 then stacks - 1 else nil)
				if stacks > 1 then
					s.model:SetAttribute("Status_Chill", t + 1)
				end
			end
			updateSpeed(s)
			if
				not s.blocking
				and not hasStatus(s, "Fracture")
				and s.posture < C.maxPosture
				and t - s.lastPostureHit > C.postureRegenDelay
			then
				setPosture(s, s.posture + C.postureRegenPerSecond * dt)
			end
			-- Burn: 2 damage every 0.5 s.
			if hasStatus(s, "Burn") and t >= (s.nextBurnAt or 0) then
				s.nextBurnAt = t + 0.5
				local source = s.burnSource
				hurt(if alive(source) then source else nil, s, 2, true)
				fx("burntick", nil, s.model, s.hrp.Position + Vector3.new(0, 1, 0), 2)
			end
			local h = s.humanoid
			if h.Health > 0 and h.Health < h.MaxHealth and t - s.lastDamageAt > C.regenDelay then
				h.Health = math.min(h.Health + C.regenPerSecond * dt, h.MaxHealth)
			end
		end
	end)
end

return Combat
