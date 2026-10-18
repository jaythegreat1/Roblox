-- Server-authoritative combat: the client only says "I pressed attack"; the server decides
-- timing, hits, blocks, parries, posture, stuns and damage, then tells every client what to show.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Swords = require(ReplicatedStorage.Shared.Combat.Swords)

local Combat = {}

local C = Swords.Combat
local SWORD = Swords.IronOath

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
}

local states: { [Model]: State } = {}
local fxRemote: RemoteEvent
local knockbackRemote: RemoteEvent

local function now(): number
	return workspace:GetServerTimeNow()
end

local function fx(kind: string, attacker: Model?, target: Model?, position: Vector3?, amount: number?, extra: any?)
	fxRemote:FireAllClients(kind, attacker, target, position, amount, extra)
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

	local blockingNow = target.blocking and facing(target.hrp, attacker.hrp.Position, C.blockArc)
	local dummyParry = target.dummyMode == "Parry" and math.random() < 0.5
	if dummyParry or (blockingNow and t - target.blockStart <= C.parryWindow) then
		target.parriedDuringBlock = true
		stun(attacker, C.parriedStun)
		fx("parry", attacker.model, target.model, hitPos)
		return
	end

	if blockingNow then
		local chip = amount * (1 - C.blockReduction)
		damage(target, chip)
		target.lastPostureHit = t
		setPosture(target, target.posture - move.posture)
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
	damage(target, amount)
	stun(target, if isHeavy then C.heavyStun else C.hitStun)
	if move.knockback then
		knockback(target, attacker.hrp.Position, move.knockback)
	end
	fx("hit", attacker.model, target.model, hitPos, amount, isHeavy or move.knockback ~= nil)
end

local function resolve(attacker: State, move, isHeavy: boolean, amount: number)
	if not alive(attacker) or stunned(attacker) then
		return -- interrupted during the wind-up
	end
	for _, target in states do
		if target ~= attacker and alive(target) then
			local offset = (target.hrp.Position - attacker.hrp.Position) * Vector3.new(1, 0, 1)
			local dist = offset.Magnitude
			if dist <= move.range + 1.5 and (dist < 3 or facing(attacker.hrp, target.hrp.Position, move.arc)) then
				applyHit(attacker, target, move, isHeavy, amount)
			end
		end
	end
end

local function onLight(s: State)
	local t = now()
	if t < s.busyUntil or stunned(s) or s.blocking or s.chargingSince then
		return
	end
	if t - s.lastLightAt > SWORD.comboReset or s.comboIndex >= #SWORD.light then
		s.comboIndex = 0
	end
	s.comboIndex += 1
	s.lastLightAt = t
	local move = SWORD.light[s.comboIndex]
	s.busyUntil = t + move.lock - 0.05 -- small tolerance for network jitter
	fx("swing", s.model, nil, nil, nil, move.anim)
	task.delay(move.hitAt, resolve, s, move, false, move.damage)
end

local function onHeavyStart(s: State)
	local t = now()
	if t < s.busyUntil or stunned(s) or s.blocking or s.chargingSince then
		return
	end
	s.chargingSince = t
	fx("swing", s.model, nil, nil, nil, "HeavyCharge")
	fx("charge", s.model)
end

local function onHeavyRelease(s: State)
	local started = s.chargingSince
	if not started or stunned(s) then
		return
	end
	s.chargingSince = nil
	local h = SWORD.heavy
	local charge = math.clamp((now() - started - h.minCharge) / (h.fullCharge - h.minCharge), 0, 1)
	local amount = h.damage + (h.chargedDamage - h.damage) * charge
	s.busyUntil = now() + h.lock - 0.05
	s.comboIndex = 0
	fx("swing", s.model, nil, nil, nil, h.anim)
	task.delay(h.hitAt, resolve, s, h, true, amount)
end

local function onHeavyCancel(s: State)
	if not s.chargingSince then
		return
	end
	s.chargingSince = nil
	setPosture(s, s.posture - 15)
	s.lastPostureHit = now()
	fx("stop", s.model, nil, nil, nil, "HeavyCharge")
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

local handlers = {
	Light = onLight,
	HeavyStart = onHeavyStart,
	HeavyRelease = onHeavyRelease,
	HeavyCancel = onHeavyCancel,
	BlockStart = onBlockStart,
	BlockEnd = onBlockEnd,
}

-- Entry point for an action from any fighter: player remotes and, later, AI bots.
function Combat.request(model: Model, action: any)
	local handler = typeof(action) == "string" and handlers[action]
	local s = states[model]
	if handler and alive(s) then
		handler(s)
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

	request.OnServerEvent:Connect(function(player, action)
		if player.Character then
			Combat.request(player.Character, action)
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
