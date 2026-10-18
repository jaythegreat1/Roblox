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

local Combat = {}

local SWORD = Swords.IronOath
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
local shakeUntil, shakeStrength = 0, 0

local function myCharacter(): Model?
	return player.Character
end

local function setTrail(model: Model?, seconds: number)
	local sword = model and model:FindFirstChild("Sword")
	local blade = sword and sword:FindFirstChild("Blade")
	local trail = blade and blade:FindFirstChildOfClass("Trail")
	if trail then
		trail.Enabled = true
		task.delay(seconds, function()
			trail.Enabled = false
		end)
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
	if t - lastLightAt > SWORD.comboReset or comboIndex >= #SWORD.light then
		comboIndex = 0
	end
	comboIndex += 1
	lastLightAt = t
	local move = SWORD.light[comboIndex]
	lockUntil = t + move.lock
	Movement.lockFor(move.lock * 0.6)
	playSwing(myCharacter(), move.anim)
	request:FireServer("Light")
end

local function startCharge()
	if charging or blocking or stunned() or os.clock() < lockUntil then
		return
	end
	charging = true
	Engine.play(myCharacter(), "HeavyCharge")
	request:FireServer("HeavyStart")
end

function Combat.attackDown()
	pressing = true
	pressStart = os.clock()
	task.delay(SWORD.heavy.minCharge, function()
		if pressing and os.clock() - pressStart >= SWORD.heavy.minCharge - 0.01 then
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
		lockUntil = os.clock() + SWORD.heavy.lock
		comboIndex = 0
		Movement.lockFor(SWORD.heavy.lock * 0.7)
		playSwing(myCharacter(), SWORD.heavy.anim)
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
		Engine.stop(myCharacter(), "HeavyCharge")
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

function Combat.onCombo(fn: (number) -> ())
	table.insert(comboListeners, fn)
end

function Combat.start(remotes: Folder, movement)
	Movement = movement
	request = remotes:WaitForChild("Combat") :: RemoteEvent
	local fxRemote = remotes:WaitForChild("CombatFx") :: RemoteEvent
	local knockbackRemote = remotes:WaitForChild("Knockback") :: RemoteEvent
	fxRemote.OnClientEvent:Connect(onFx)

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
