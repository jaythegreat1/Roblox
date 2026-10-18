-- Client combat: reads input, previews your own swings instantly, and draws everything the
-- server reports (hits, blocks, parries, guard breaks) with sparks, numbers, freezes and shake.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Engine = require(ReplicatedStorage.Shared.Anim.Engine)
local Swords = require(ReplicatedStorage.Shared.Combat.Swords)
local EchoData = require(ReplicatedStorage.Shared.Combat.Echoes)
local EchoFx = require(script.Parent.EchoFx)

local Combat = {}

-- The sword you are holding right now (changes when you equip another in the Armory).
local function currentSword()
	local character = Players.LocalPlayer.Character
	return Swords.get(character and character:GetAttribute("SwordId"))
end
local player = Players.LocalPlayer
local request: RemoteEvent
local Movement

local pressing = false
local pressStart = 0
local charging = false
local blocking = false
local lockUntil = 0
local comboIndex = 0
local lastLightAt = 0
local comboCount = 0
local comboExpires = 0
local comboListeners: { (number) -> () } = {}
local lastWasLight = false
local shakeUntil, shakeStrength = 0, 0

local function myCharacter(): Model?
	return player.Character
end

local function setTrail(model: Model?, seconds: number)
	for _, name in { "Sword", "SwordOffhand" } do
		local sword = model and model:FindFirstChild(name)
		local blade = sword and sword:FindFirstChild("Blade")
		local trail = blade and blade:FindFirstChildOfClass("Trail")
		if trail then
			trail.Enabled = true
			task.delay(seconds, function()
				trail.Enabled = false
			end)
		end
	end
end

local function playSwing(model: Model?, anim: string)
	Engine.play(model, anim)
	if anim ~= "Block" and anim ~= "HeavyCharge" then
		setTrail(model, 0.35)
	end
end

local function shake(strength: number, seconds: number)
	shakeUntil = os.clock() + seconds
	shakeStrength = strength
end

local function bumpCombo()
	local t = os.clock()
	comboCount = if t < comboExpires then comboCount + 1 else 1
	comboExpires = t + 1.5
	for _, fn in comboListeners do
		fn(comboCount)
	end
end

-- Visual effects -----------------------------------------------------------------------

local function burst(position: Vector3, color: Color3, count: number, size: number)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = position
	holder.Parent = workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(size, 0)
	emitter.Speed = NumberRange.new(18, 34)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(0.15, 0.35)
	emitter.Drag = 6
	emitter.Enabled = false
	emitter.Parent = holder
	emitter:Emit(count)

	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Material = Enum.Material.Neon
	flash.Color = color
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.Size = Vector3.one * size * 2
	flash.Position = position
	flash.Parent = workspace
	TweenService:Create(flash, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * size * 6,
		Transparency = 1,
	}):Play()
	Debris:AddItem(flash, 0.2)
	Debris:AddItem(holder, 0.6)
end

local function popText(position: Vector3, text: string, color: Color3, big: boolean?)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position + Vector3.new(math.random(-10, 10) / 10, 1.5, 0)
	anchor.Parent = workspace
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 40)
	gui.AlwaysOnTop = true
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = if big then 28 else 20
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
	TweenService:Create(anchor, TweenInfo.new(0.7), { Position = anchor.Position + Vector3.new(0, 2.5, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(anchor, 0.75)
end

local function extraFx(kind: string, attacker: Model?, target: Model?, position: Vector3?, amount: number?, extra: any?)
	local me = myCharacter()
	if EchoFx.handle(kind, attacker, target, position, amount, extra) then
		return true
	end
	if kind == "notice" then
		local hrp = me and me:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			popText(hrp.Position + Vector3.new(0, 2, 0), tostring(extra), Color3.fromRGB(220, 220, 255))
		end
	elseif kind == "clash" and position then
		burst(position, Color3.fromRGB(255, 255, 255), 45, 1.2)
		burst(position, Color3.fromRGB(255, 200, 90), 25, 0.8)
		popText(position, "CLASH", Color3.fromRGB(255, 230, 150), true)
		Engine.play(attacker, "Clash")
		Engine.play(target, "Clash")
		Engine.freeze(attacker, 0.18)
		Engine.freeze(target, 0.18)
		if attacker == me or target == me then
			shake(0.8, 0.3)
		end
	elseif kind == "grab" and position then
		burst(position, Color3.fromRGB(255, 120, 80), 18, 0.8)
		popText(position, tostring(amount or 0), Color3.fromRGB(255, 150, 90), true)
		Engine.play(target, "Thrown")
		if attacker == me or target == me then
			shake(0.5, 0.2)
		end
	elseif kind == "finish" then
		Engine.play(attacker, "FinisherOath")
		Engine.play(target, "FinisherVictim")
		setTrail(attacker, 1.2)
	elseif kind == "finished" and position then
		burst(position, Color3.fromRGB(220, 60, 200), 60, 1.6)
		burst(position, Color3.fromRGB(255, 255, 255), 30, 1)
		popText(position, "FINISHED", Color3.fromRGB(255, 120, 230), true)
		Engine.stop(target)
		if attacker == me or target == me then
			shake(0.9, 0.35)
		end
	elseif kind == "toss" and attacker then
		-- Twin Fangs heavy: both daggers spin out 20 studs and fly back.
		local hrp = attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
		local sword = attacker:FindFirstChild("Sword")
		local blade = sword and sword:FindFirstChild("Blade") :: BasePart?
		if hrp and blade then
			for side = -1, 1, 2 do
				local copy = blade:Clone()
				for _, c in copy:GetChildren() do
					if not c:IsA("Trail") and not c:IsA("Attachment") then
						c:Destroy()
					end
				end
				copy.Anchored = true
				local trail = copy:FindFirstChildOfClass("Trail")
				if trail then
					trail.Enabled = true
				end
				copy.Parent = workspace
				local start = hrp.Position + Vector3.new(0, 1, 0)
				local outPos = start + hrp.CFrame.LookVector * 20 + hrp.CFrame.RightVector * side * 3
				task.spawn(function()
					local t0 = os.clock()
					while os.clock() - t0 < 0.65 and copy.Parent do
						local a = (os.clock() - t0) / 0.65
						local pos = start:Lerp(outPos, math.sin(a * math.pi))
						copy.CFrame = CFrame.new(pos) * CFrame.Angles(0, a * 40, math.pi / 2)
						task.wait()
					end
					copy:Destroy()
				end)
			end
		end
	elseif kind == "armor" and position then
		popText(position, "UNSTOPPABLE", Color3.fromRGB(255, 150, 60))
	elseif kind == "equip" and position then
		burst(position + Vector3.new(0, 1, 0), Color3.fromRGB(220, 60, 200), 30, 1)
	elseif kind == "finishbroken" and position then
		popText(position, "INTERRUPTED", Color3.fromRGB(200, 200, 255), true)
		Engine.stop(target)
	else
		return false
	end
	return true
end

local function involvesMe(a: Model?, b: Model?): boolean
	local me = myCharacter()
	return me ~= nil and (a == me or b == me)
end

local function onFx(kind: string, attacker: Model?, target: Model?, position: Vector3?, amount: number?, extra: any)
	local me = myCharacter()
	if kind == "swing" then
		if attacker ~= me then
			playSwing(attacker, extra)
		end
	elseif kind == "stop" then
		if attacker ~= me then
			Engine.stop(attacker, extra)
		end
	elseif kind == "charge" then
		local sword = attacker and attacker:FindFirstChild("Sword")
		local tip = sword and sword:FindFirstChild("Tip") :: BasePart?
		if tip then
			burst(tip.Position, Color3.fromRGB(255, 255, 255), 8, 0.6)
		end
	elseif kind == "hit" and position then
		local heavy = extra == true
		burst(
			position,
			if heavy then Color3.fromRGB(255, 170, 60) else Color3.fromRGB(255, 240, 200),
			if heavy then 26 else 14,
			if heavy then 0.9 else 0.6
		)
		popText(
			position,
			tostring(math.floor((amount or 0) + 0.5)),
			if heavy then Color3.fromRGB(255, 160, 60) else Color3.new(1, 1, 1),
			heavy
		)
		Engine.play(target, if heavy then "HitHeavy" else "HitFront")
		local freeze = if heavy then 0.12 else 0.07
		Engine.freeze(attacker, freeze)
		Engine.freeze(target, freeze)
		if attacker == me then
			bumpCombo()
		end
		if involvesMe(attacker, target) then
			shake(if heavy then 0.6 else 0.3, if heavy then 0.25 else 0.12)
		end
	elseif kind == "block" and position then
		burst(position, Color3.fromRGB(120, 190, 255), 10, 0.5)
		Engine.play(target, "BlockImpact")
		Engine.freeze(attacker, 0.05)
		if involvesMe(attacker, target) then
			shake(0.15, 0.1)
		end
	elseif kind == "parry" and position then
		burst(position, Color3.fromRGB(255, 255, 255), 30, 1.1)
		popText(position, "PARRY", Color3.fromRGB(180, 220, 255), true)
		Engine.play(target, "Parry")
		Engine.play(attacker, "Parried")
		Engine.freeze(attacker, 0.15)
		if involvesMe(attacker, target) then
			shake(0.5, 0.2)
		end
	elseif kind == "guardbreak" and position then
		burst(position, Color3.fromRGB(255, 210, 60), 40, 1.3)
		popText(position, "GUARD BREAK", Color3.fromRGB(255, 210, 60), true)
		Engine.play(target, "GuardBreak")
		if involvesMe(attacker, target) then
			shake(0.7, 0.3)
		end
	elseif kind == "dodge" and position then
		popText(position, "DODGED", Color3.fromRGB(200, 170, 255))
	elseif kind == "ko" and position then
		burst(position, Color3.fromRGB(220, 60, 200), 50, 1.4)
		popText(position, "K.O.", Color3.fromRGB(255, 120, 230), true)
	end
end

-- Input --------------------------------------------------------------------------------

local function stunned(): boolean
	return Movement.isStunned()
end

local function light()
	local t = os.clock()
	if t < lockUntil or stunned() or blocking or Movement.isBusy() then
		return
	end
	local sword = currentSword()
	if t - lastLightAt > sword.comboReset or comboIndex >= #sword.light then
		comboIndex = 0
	end
	comboIndex += 1
	lastLightAt = t
	local move = sword.light[comboIndex]
	local lock = move.lock
	if sword.passive == "frenzy" and t < comboExpires then
		lock *= 1 - 0.05 * math.min(comboCount, 5)
	end
	local haste = myCharacter() and myCharacter():GetAttribute("BattleCryUntil")
	if typeof(haste) == "number" and workspace:GetServerTimeNow() < haste then
		lock *= 0.85
	end
	lockUntil = t + lock
	lastWasLight = true
	Movement.lockFor(move.lock * 0.6)
	playSwing(myCharacter(), move.anim)
	request:FireServer("Light")
end

local function startCharge()
	if charging or blocking or stunned() or os.clock() < lockUntil then
		return
	end
	charging = true
	Engine.play(myCharacter(), currentSword().heavy.charge)
	request:FireServer("HeavyStart")
end

function Combat.attackDown()
	pressing = true
	pressStart = os.clock()
	local minCharge = currentSword().heavy.minCharge
	task.delay(minCharge, function()
		if pressing and os.clock() - pressStart >= minCharge - 0.01 then
			startCharge()
		end
	end)
end

function Combat.attackUp()
	if not pressing then
		return
	end
	pressing = false
	if charging then
		charging = false
		if stunned() then
			return
		end
		local heavy = currentSword().heavy
		lastWasLight = false
		lockUntil = os.clock() + heavy.lock
		comboIndex = 0
		Movement.lockFor(heavy.lock * 0.7)
		playSwing(myCharacter(), heavy.anim)
		if heavy.lunge then
			Movement.lunge(heavy.lunge.distance, heavy.lunge.time)
		end
		request:FireServer("HeavyRelease")
	else
		light()
	end
end

function Combat.blockDown()
	if blocking or stunned() then
		return
	end
	if charging then
		-- Block during a heavy's wind-up is a feint.
		charging = false
		pressing = false
		Engine.stop(myCharacter(), currentSword().heavy.charge)
		request:FireServer("HeavyCancel")
		return
	end
	blocking = true
	Engine.play(myCharacter(), "Block")
	request:FireServer("BlockStart")
end

function Combat.blockUp()
	if not blocking then
		return
	end
	blocking = false
	Engine.stop(myCharacter(), "Block")
	request:FireServer("BlockEnd")
end

-- The nearest enemy you could finish right now, if any.
local function finishTarget(): Model?
	local me = myCharacter()
	local hrp = me and me:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return nil
	end
	local candidates = {}
	for _, p in Players:GetPlayers() do
		if p.Character and p.Character ~= me then
			table.insert(candidates, p.Character)
		end
	end
	for _, m in CollectionService:GetTagged("BladeRiftRig") do
		table.insert(candidates, m)
	end
	for _, m in candidates do
		local h = m:FindFirstChildOfClass("Humanoid")
		local thrp = m:FindFirstChild("HumanoidRootPart") :: BasePart?
		local untilTime = m:GetAttribute("StunnedUntil")
		if
			h
			and thrp
			and h.Health > 0
			and h.Health <= 15
			and typeof(untilTime) == "number"
			and workspace:GetServerTimeNow() < untilTime
			and (thrp.Position - hrp.Position).Magnitude <= 7
		then
			return m
		end
	end
	return nil
end
Combat.finishTarget = finishTarget

-- Grab, or Finish when an enemy is low and stunned.
function Combat.grabOrFinish()
	if stunned() or blocking or charging or os.clock() < lockUntil then
		return
	end
	if finishTarget() then
		lockUntil = os.clock() + 1.5
		Movement.lockFor(1.4)
		request:FireServer("Finish")
	else
		lockUntil = os.clock() + 0.9
		Movement.lockFor(0.8)
		playSwing(myCharacter(), "GrabReach")
		request:FireServer("Grab")
	end
end

-- Lock-on: your character keeps facing the target, which is marked with a ring.
local lockTarget: Model? = nil
local lockMarker: BillboardGui? = nil
local lockListeners: { (boolean) -> () } = {}

local function clearLock()
	lockTarget = nil
	if lockMarker then
		lockMarker:Destroy()
		lockMarker = nil
	end
	local me = myCharacter()
	local h = me and me:FindFirstChildOfClass("Humanoid")
	if h then
		h.AutoRotate = true
	end
	for _, fn in lockListeners do
		fn(false)
	end
end

function Combat.toggleLock()
	if lockTarget then
		clearLock()
		return
	end
	local me = myCharacter()
	local hrp = me and me:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	local camLook = workspace.CurrentCamera.CFrame.LookVector
	local best, bestScore = nil, -math.huge
	local candidates = {}
	for _, p in Players:GetPlayers() do
		if p.Character and p.Character ~= me then
			table.insert(candidates, p.Character)
		end
	end
	for _, m in CollectionService:GetTagged("BladeRiftRig") do
		table.insert(candidates, m)
	end
	for _, m in candidates do
		local thrp = m:FindFirstChild("HumanoidRootPart") :: BasePart?
		local h = m:FindFirstChildOfClass("Humanoid")
		if thrp and h and h.Health > 0 then
			local offset = thrp.Position - hrp.Position
			local dist = offset.Magnitude
			if dist < 60 then
				local score = camLook:Dot(offset.Unit) * 2 - dist / 30
				if score > bestScore then
					best, bestScore = m, score
				end
			end
		end
	end
	if not best then
		return
	end
	lockTarget = best
	local marker = Instance.new("BillboardGui")
	marker.Size = UDim2.fromOffset(46, 46)
	marker.AlwaysOnTop = true
	marker.Adornee = best:FindFirstChild("UpperTorso") or best:FindFirstChild("HumanoidRootPart")
	local ring = Instance.new("ImageLabel")
	ring.BackgroundTransparency = 1
	ring.Size = UDim2.fromScale(1, 1)
	ring.Image = "rbxasset://textures/ui/Controls/DesignSystem/ButtonA@2x.png"
	ring.ImageTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 80, 120)
	stroke.Thickness = 3
	stroke.Parent = ring
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ring
	ring.Parent = marker
	marker.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	lockMarker = marker
	for _, fn in lockListeners do
		fn(true)
	end
end

function Combat.onLock(fn: (boolean) -> ())
	table.insert(lockListeners, fn)
end

-- Echoes ---------------------------------------------------------------------------------

local function attr(name: string): any
	local character = myCharacter()
	return character and character:GetAttribute(name)
end

local function untilNow(name: string): boolean
	local v = attr(name)
	return typeof(v) == "number" and workspace:GetServerTimeNow() < v
end

-- Whether the Surge button would fire Rift Burst (the combo breaker) right now.
function Combat.canBurst(): boolean
	local surge = attr("Surge")
	return typeof(surge) == "number"
		and surge >= EchoData.Surge.riftBurstCost
		and untilNow("BurstUntil")
		and not untilNow("CD_RiftBurst")
end

function Combat.castEcho(slot: string)
	local character = myCharacter()
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	if slot == "EchoSurge" then
		local surge = attr("Surge")
		if (typeof(surge) ~= "number" or surge < EchoData.Surge.max) and Combat.canBurst() then
			-- Rift Burst works even while you are stunned.
			Engine.play(character, "RiftBurst")
			request:FireServer("Echo", { slot = "RiftBurst" })
			return
		end
		if typeof(surge) ~= "number" or surge < EchoData.Surge.max then
			return
		end
	end
	local e = EchoData.get(attr(slot))
	if not e or stunned() or blocking or charging then
		return
	end
	local t = os.clock()
	local afterLight = lastWasLight and t - lastLightAt < 1
	if (t < lockUntil and not afterLight) or (Movement.isBusy() and not afterLight) then
		return
	end
	if e.rarity ~= "Mythic" and untilNow("CD_" .. e.id) then
		return
	end
	lastWasLight = false
	comboIndex = 0
	lockUntil = t + e.cast + 0.3
	Movement.lockFor(e.cast + 0.2)
	playSwing(character, e.anim)
	request:FireServer("Echo", { slot = slot, target = lockTarget, dir = humanoid.MoveDirection })
end

function Combat.setLoadout(slot: string, id: string)
	request:FireServer("Loadout", { slot = slot, id = id })
end

function Combat.equip(id: string)
	request:FireServer("Equip", id)
end

function Combat.onCombo(fn: (number) -> ())
	table.insert(comboListeners, fn)
end

Combat.shake = shake
Combat.popText = popText

function Combat.unlock()
	if lockTarget then
		clearLock()
	end
end

function Combat.start(remotes: Folder, movement)
	Movement = movement
	EchoFx.start(Combat)
	local echoMove = remotes:WaitForChild("EchoMove") :: RemoteEvent
	echoMove.OnClientEvent:Connect(function(segments)
		Movement.path(segments)
	end)
	request = remotes:WaitForChild("Combat") :: RemoteEvent
	local fxRemote = remotes:WaitForChild("CombatFx") :: RemoteEvent
	local knockbackRemote = remotes:WaitForChild("Knockback") :: RemoteEvent
	fxRemote.OnClientEvent:Connect(function(kind, attacker, target, position, amount, extra)
		if not extraFx(kind, attacker, target, position, amount, extra) then
			onFx(kind, attacker, target, position, amount, extra)
		end
	end)

	knockbackRemote.OnClientEvent:Connect(function(velocity: Vector3)
		local character = myCharacter()
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			hrp.AssemblyLinearVelocity = velocity
			Movement.lockFor(0.35)
		end
	end)

	-- Dummies that always block hold the block pose.
	local function watchDummy(model: Instance)
		if model:IsA("Model") then
			local function apply()
				if model:GetAttribute("BlockingPose") then
					task.wait(0.5)
					Engine.play(model, "Block")
				end
			end
			model:GetAttributeChangedSignal("BlockingPose"):Connect(apply)
			apply()
		end
	end
	CollectionService:GetInstanceAddedSignal("BladeRiftRig"):Connect(watchDummy)
	for _, m in CollectionService:GetTagged("BladeRiftRig") do
		task.spawn(watchDummy, m)
	end

	-- Getting hit or stunned cancels whatever you were doing.
	RunService.Heartbeat:Connect(function()
		local character = myCharacter()
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if stunned() then
			if blocking then
				blocking = false
				Engine.stop(character, "Block")
			end
			charging = false
			pressing = false
		end
		if lockTarget then
			local thrp = lockTarget:FindFirstChild("HumanoidRootPart") :: BasePart?
			local lh = lockTarget:FindFirstChildOfClass("Humanoid")
			local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not thrp or not lh or lh.Health <= 0 or not hrp or (thrp.Position - hrp.Position).Magnitude > 80 then
				clearLock()
			elseif humanoid and not Movement.isBusy() then
				humanoid.AutoRotate = false
				local flat = Vector3.new(thrp.Position.X, hrp.Position.Y, thrp.Position.Z)
				if (flat - hrp.Position).Magnitude > 0.5 then
					hrp.CFrame = CFrame.lookAt(hrp.Position, flat)
				end
			end
		end
		if humanoid then
			humanoid.CameraOffset = if os.clock() < shakeUntil
				then Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * shakeStrength
				else Vector3.zero
		end
	end)

	-- PC controls: click to attack (hold for heavy), F to block.
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			Combat.attackDown()
		elseif input.KeyCode == Enum.KeyCode.F then
			Combat.blockDown()
		elseif input.KeyCode == Enum.KeyCode.T or input.KeyCode == Enum.KeyCode.V then
			Combat.grabOrFinish()
		elseif input.UserInputType == Enum.UserInputType.MouseButton3 or input.KeyCode == Enum.KeyCode.LeftControl then
			Combat.toggleLock()
		elseif input.KeyCode == Enum.KeyCode.One or input.KeyCode == Enum.KeyCode.Z then
			Combat.castEcho("Echo1")
		elseif input.KeyCode == Enum.KeyCode.Two or input.KeyCode == Enum.KeyCode.X then
			Combat.castEcho("Echo2")
		elseif input.KeyCode == Enum.KeyCode.Three or input.KeyCode == Enum.KeyCode.C then
			Combat.castEcho("Echo3")
		elseif input.KeyCode == Enum.KeyCode.G then
			Combat.castEcho("EchoSurge")
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			Combat.attackUp()
		elseif input.KeyCode == Enum.KeyCode.F then
			Combat.blockUp()
		end
	end)
end

return Combat
