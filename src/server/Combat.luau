-- Server-authoritative combat: the client only says "I pressed attack"; the server decides
-- timing, hits, blocks, parries, posture, stuns and damage, then tells every client what to show.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Swords = require(ReplicatedStorage.Shared.Combat.Swords)

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
}

local states: { [Model]: State } = {}
local fxRemote: RemoteEvent
local knockbackRemote: RemoteEvent
local swingListeners: { (Model, any, boolean, number) -> () } = {}

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

local function stun(s: State, seconds: number)
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

local function knockback(target: State, from: Vector3, strength: number)
	local dir = (target.hrp.Position - from) * Vector3.new(1, 0, 1)
	dir = if dir.Magnitude > 0.01 then dir.Unit else target.hrp.CFrame.LookVector * -1
	local velocity = dir * strength + Vector3.new(0, strength * 0.3, 0)
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

	-- Clash: both fighters' strikes land within 0.12 s of each other while facing.
	local pending = target.pendingStrikeAt
	if pending and math.abs(pending - t) <= 0.12 and facing(target.hrp, attacker.hrp.Position, 120) then
		stun(target, 0.5)
		stun(attacker, 0.5)
		for _, s in { attacker, target } do
			s.lastPostureHit = t
			setPosture(s, s.posture - 15)
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

	local blockingNow = target.blocking and facing(target.hrp, attacker.hrp.Position, C.blockArc)
	local dummyParry = target.dummyMode == "Parry" and math.random() < 0.5
	local parryWindow = swordOf(target).parryWindow or C.parryWindow
	if dummyParry or (blockingNow and t - target.blockStart <= parryWindow) then
		target.parriedDuringBlock = true
		target.riposteUntil = t + 1
		stun(attacker, C.parriedStun)
		fx("parry", attacker.model, target.model, hitPos)
		return
	end

	if blockingNow then
		local chip = amount * (1 - C.blockReduction)
		damage(target, chip)
		target.lastPostureHit = t
		local postureCost = move.posture * (if swordOf(target).passive == "steadfast" then 0.85 else 1)
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
	damage(target, amount)
	-- Hyper armor (Titan's Maw): light hits still hurt but cannot interrupt a heavy.
	local armored = swordOf(target).passive == "unstoppable" and (target.chargingSince ~= nil or t < target.armorUntil)
	if armored and not isHeavy then
		fx("hit", attacker.model, target.model, hitPos, amount, false)
		fx("armor", nil, target.model, hitPos)
		return
	end
	stun(target, if isHeavy then C.heavyStun else C.hitStun)
	if move.knockback then
		knockback(target, attacker.hrp.Position, move.knockback)
	end
	fx("hit", attacker.model, target.model, hitPos, amount, isHeavy or move.knockback ~= nil)
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
	local lock = move.lock
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

local handlers = {
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
	}
	states[model] = s
	setPosture(s, C.maxPosture)
	model.Destroying:Connect(function()
		states[model] = nil
	end)
	humanoid.Died:Connect(function()
		states[model] = nil
	end)
end

-- Lets AI fighters react to swings: (attacker, move, isHeavy, server time the hit lands).
function Combat.onSwing(fn: (Model, any, boolean, number) -> ())
	table.insert(swingListeners, fn)
end

function Combat.isBlocking(model: Model): boolean
	local s = states[model]
	return s ~= nil and s.blocking
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
			if not s.blocking and s.posture < C.maxPosture and t - s.lastPostureHit > C.postureRegenDelay then
				setPosture(s, s.posture + C.postureRegenPerSecond * dt)
			end
			local h = s.humanoid
			if h.Health > 0 and h.Health < h.MaxHealth and t - s.lastDamageAt > C.regenDelay then
				h.Health = math.min(h.Health + C.regenPerSecond * dt, h.MaxHealth)
			end
		end
	end)
end

return Combat
