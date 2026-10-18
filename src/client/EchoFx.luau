-- Echo visuals: fire, lightning and rift effects for every Echo, plus status effects drawn on
-- fighters (burning, crackling, marked, blinded). Everything here is cosmetic; the server
-- decides what actually hits.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Shared.Combat.Echoes)
local Engine = require(ReplicatedStorage.Shared.Anim.Engine)

local EchoFx = {}

local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local ORANGE = Color3.fromRGB(255, 120, 40)
local GOLD = Color3.fromRGB(255, 210, 90)
local CYAN = Color3.fromRGB(110, 210, 255)
local WHITE = Color3.new(1, 1, 1)
local MAGENTA = Color3.fromRGB(230, 60, 220)

local player = Players.LocalPlayer
local folder: Folder
local Combat -- client Combat module, for shake and pop text
local projectiles: { [number]: { stop: () -> () } } = {}
local auras: { [Model]: ParticleEmitter } = {}

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = folder
	return p
end

local function tween(inst: Instance, seconds: number, goal, style: Enum.EasingStyle?)
	local t = TweenService:Create(
		inst,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

local function emitter(parent: Instance, texture: string, color: Color3, props): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new(1.5, 0)
	e.Transparency = NumberSequence.new(0.1, 1)
	e.Lifetime = NumberRange.new(0.3, 0.6)
	e.Speed = NumberRange.new(4, 8)
	e.Rate = 30
	for k, v in props or {} do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

-- An invisible anchored holder for particles at a position.
local function holder(pos: Vector3, life: number): Part
	local h = part({ Transparency = 1, Size = Vector3.one, Position = pos })
	Debris:AddItem(h, life)
	return h
end

local function burst(pos: Vector3, texture: string, color: Color3, count: number, speed: number, size: number)
	local h = holder(pos, 2)
	local e = emitter(h, texture, color, {
		Rate = 0,
		Speed = NumberRange.new(speed * 0.5, speed),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(size, 0),
		Lifetime = NumberRange.new(0.3, 0.7),
		Drag = 4,
	})
	e:Emit(count)
end

-- A flat ring that expands and fades.
local function ring(pos: Vector3, from: number, to: number, color: Color3, seconds: number, thickness: number?)
	local r = part({
		Shape = Enum.PartType.Cylinder,
		Color = color,
		Size = Vector3.new(thickness or 0.4, from * 2, from * 2),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
		Transparency = 0.15,
	})
	tween(r, seconds, { Size = Vector3.new(thickness or 0.4, to * 2, to * 2), Transparency = 1 })
	Debris:AddItem(r, seconds + 0.05)
end

-- A glowing sphere flash.
local function flash(pos: Vector3, from: number, to: number, color: Color3, seconds: number)
	local b = part({ Shape = Enum.PartType.Ball, Color = color, Size = Vector3.one * from, Position = pos })
	tween(b, seconds, { Size = Vector3.one * to, Transparency = 1 })
	Debris:AddItem(b, seconds + 0.05)
end

-- A jagged lightning bolt between two points.
local function bolt(from: Vector3, to: Vector3, color: Color3, width: number, seconds: number)
	local segments = math.clamp(math.floor((to - from).Magnitude / 3), 3, 14)
	local points = { from }
	for i = 1, segments - 1 do
		local a = i / segments
		local jitter = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2.4
		table.insert(points, from:Lerp(to, a) + jitter)
	end
	table.insert(points, to)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local seg = part({
			Color = color,
			Size = Vector3.new(width, width, (b - a).Magnitude + width * 0.5),
			CFrame = CFrame.lookAt((a + b) / 2, b),
		})
		tween(seg, seconds, { Transparency = 1, Size = Vector3.new(width * 0.2, width * 0.2, seg.Size.Z) })
		Debris:AddItem(seg, seconds + 0.05)
	end
end

-- A see-through neon copy of a character, left behind by blinks and dashes.
local function afterimage(model: Model?, color: Color3, seconds: number)
	if not model then
		return
	end
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.Transparency < 1 then
			local copy = part({ Color = color, Size = p.Size, CFrame = p.CFrame, Transparency = 0.45 })
			tween(copy, seconds, { Transparency = 1 })
			Debris:AddItem(copy, seconds + 0.05)
		end
	end
end

local function near(pos: Vector3, radius: number): boolean
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return hrp ~= nil and (hrp.Position - pos).Magnitude <= radius
end

local function screenFlash(color: Color3, seconds: number)
	local gui = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("BladeRiftHUD")
	if not gui then
		return
	end
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 0.1
	f.BorderSizePixel = 0
	f.ZIndex = 50
	f.Parent = gui
	tween(f, seconds, { BackgroundTransparency = 1 })
	Debris:AddItem(f, seconds + 0.05)
end

-- Moves a visual along a straight path until it arrives or the server says it hit something.
local function fly(
	key: number,
	visual: BasePart,
	origin: Vector3,
	dir: Vector3,
	speed: number,
	range: number,
	spin: boolean?
)
	local stopped = false
	local function stop()
		if stopped then
			return
		end
		stopped = true
		projectiles[key] = nil
		for _, c in visual:GetDescendants() do
			if c:IsA("ParticleEmitter") or c:IsA("Trail") then
				c.Enabled = false
			end
		end
		tween(visual, 0.15, { Transparency = 1 })
		Debris:AddItem(visual, 1)
	end
	projectiles[key] = { stop = stop }
	local start = os.clock()
	task.spawn(function()
		while not stopped do
			local d = (os.clock() - start) * speed
			if d >= range then
				stop()
				break
			end
			local cf = CFrame.lookAt(origin + dir * d, origin + dir * (d + 1))
			if spin then
				cf *= CFrame.Angles(0, 0, (os.clock() - start) * 20)
			end
			visual.CFrame = cf
			RunService.RenderStepped:Wait()
		end
	end)
end

local function withTrail(p: BasePart, color: Color3, width: number)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(-width, 0, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(width, 0, 0)
	a1.Parent = p
	local t = Instance.new("Trail")
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Lifetime = 0.25
	t.LightEmission = 1
	t.Color = ColorSequence.new(WHITE, color)
	t.Transparency = NumberSequence.new(0.1, 1)
	t.Parent = p
end

local function hrpOf(model: Model?): BasePart?
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Per-Echo visuals --------------------------------------------------------------------------

local Show = {}

Show.EmberDash = function(caster, d)
	if not d.from then
		return
	end
	afterimage(caster, ORANGE, 0.35)
	local length = (d.to - d.from).Magnitude
	local ground = d.from - Vector3.new(0, 2.6, 0)
	local strip = part({
		Transparency = 1,
		Size = Vector3.new(2, 0.5, math.max(length, 1)),
		CFrame = CFrame.lookAt((ground + d.to - Vector3.new(0, 2.6, 0)) / 2, d.to - Vector3.new(0, 2.6, 0)),
	})
	emitter(strip, FIRE, ORANGE, {
		Rate = 60 + length * 4,
		Size = NumberSequence.new(2, 0),
		Speed = NumberRange.new(2, 5),
		EmissionDirection = Enum.NormalId.Top,
	})
	Debris:AddItem(strip, 3)
	task.delay(0.3, function()
		burst(d.to, FIRE, GOLD, 30, 20, 2)
		ring(d.to - Vector3.new(0, 2.5, 0), 1, 8, ORANGE, 0.35)
	end)
end

Show.FlameFang = function(_, d)
	if d.phase == "fly" then
		local core = part({ Color = ORANGE, Size = Vector3.new(7, 0.35, 1.2), Transparency = 0.1 })
		for i = -2, 2 do
			if i ~= 0 then
				local tip = part({ Color = GOLD, Size = Vector3.new(1.6, 0.3, 0.9), Transparency = 0.15 })
				local weld = Instance.new("WeldConstraint")
				tip.Anchored = false
				tip.CFrame = core.CFrame * CFrame.new(i * 1.6, 0, math.abs(i) * 0.6)
				weld.Part0 = core
				weld.Part1 = tip
				weld.Parent = tip
				tip.Parent = core
			end
		end
		emitter(core, FIRE, ORANGE, {
			Rate = 120,
			Size = NumberSequence.new(2.2, 0),
			Speed = NumberRange.new(1, 3),
			Lifetime = NumberRange.new(0.2, 0.4),
		})
		withTrail(core, ORANGE, 3)
		fly(d.key, core, d.origin, d.dir, d.speed, d.range)
	elseif d.phase == "end" then
		local p = projectiles[d.key]
		if p then
			p.stop()
		end
		burst(d.pos, FIRE, ORANGE, 25, 18, 1.8)
	end
end

Show.BlazeSpiral = function(caster, d)
	if not d.pos then
		return
	end
	local base = d.pos - Vector3.new(0, 3, 0)
	ring(base, 1, 9, ORANGE, 0.4)
	for i = 0, 5 do
		local h = holder(base + Vector3.new(0, i * 2, 0), 1.2)
		emitter(h, FIRE, if i % 2 == 0 then ORANGE else GOLD, {
			Rate = 80,
			Size = NumberSequence.new(3 - i * 0.3, 0),
			Speed = NumberRange.new(6, 10),
			SpreadAngle = Vector2.new(180, 10),
			RotSpeed = NumberRange.new(200, 400),
			Lifetime = NumberRange.new(0.3, 0.5),
		})
		task.delay(0.7, function()
			for _, c in h:GetChildren() do
				(c :: ParticleEmitter).Enabled = false
			end
		end)
	end
	if near(d.pos, 30) then
		Combat.shake(0.4, 0.25)
	end
	local _ = caster
end

Show.InfernoCage = function(_, d)
	if not d.radius then
		return
	end
	local center = d.pos
	local count = 28
	local band = part({
		Shape = Enum.PartType.Cylinder,
		Color = ORANGE,
		Size = Vector3.new(0.3, d.radius * 2, d.radius * 2),
		CFrame = CFrame.new(center + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Transparency = 0.6,
	})
	Debris:AddItem(band, d.time)
	for i = 1, count do
		local a = i / count * math.pi * 2
		local pos = center + Vector3.new(math.cos(a), 0, math.sin(a)) * d.radius
		local h = holder(pos, d.time + 0.6)
		local e = emitter(h, FIRE, if i % 2 == 0 then ORANGE else GOLD, {
			Rate = 25,
			Size = NumberSequence.new(3, 0.5),
			Speed = NumberRange.new(6, 12),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(8, 8),
			Lifetime = NumberRange.new(0.5, 0.8),
		})
		task.delay(d.time, function()
			e.Enabled = false
		end)
	end
	ring(center, 2, d.radius, GOLD, 0.4)
end

Show.SolarFlare = function(caster, d)
	if d.phase == "fly" then
		local sun = part({ Shape = Enum.PartType.Ball, Color = GOLD, Size = Vector3.one * 2.6 })
		local light = Instance.new("PointLight")
		light.Color = GOLD
		light.Range = 16
		light.Brightness = 3
		light.Parent = sun
		emitter(sun, FIRE, ORANGE, { Rate = 100, Size = NumberSequence.new(3, 0), Speed = NumberRange.new(1, 3) })
		withTrail(sun, ORANGE, 1.2)
		fly(d.key, sun, d.origin, d.dir, d.speed, d.range)
	elseif d.phase == "end" then
		local p = projectiles[d.key]
		if p then
			p.stop()
		end
	elseif d.phase == "boom" then
		flash(d.pos, 4, 22, Color3.fromRGB(255, 250, 220), 0.45)
		flash(d.pos, 2, 16, GOLD, 0.6)
		burst(d.pos, FIRE, ORANGE, 60, 40, 3)
		ring(d.pos, 2, 12, GOLD, 0.5)
		if near(d.pos, 30) then
			screenFlash(Color3.fromRGB(255, 245, 210), 0.6)
			Combat.shake(0.7, 0.3)
		end
	end
	local _ = caster
end

Show.MeteorBrand = function(_, d)
	if d.phase == "mark" then
		local mark = part({
			Shape = Enum.PartType.Cylinder,
			Color = Color3.fromRGB(255, 60, 30),
			Size = Vector3.new(0.2, 14, 14),
			CFrame = CFrame.new(d.pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Transparency = 0.5,
		})
		local t = TweenService:Create(
			mark,
			TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.8 }
		)
		t:Play()
		Debris:AddItem(mark, 3.3)
	elseif d.phase == "impact" then
		local sky = d.pos + Vector3.new(25, 70, 10)
		local rock = part({ Shape = Enum.PartType.Ball, Color = ORANGE, Size = Vector3.one * 3.5, Position = sky })
		emitter(rock, FIRE, ORANGE, { Rate = 150, Size = NumberSequence.new(4, 0), Speed = NumberRange.new(1, 2) })
		withTrail(rock, ORANGE, 1.5)
		tween(rock, 0.25, { Position = d.pos }, Enum.EasingStyle.Linear)
		task.delay(0.25, function()
			rock:Destroy()
			flash(d.pos, 3, 16, GOLD, 0.35)
			burst(d.pos, SMOKE, Color3.fromRGB(90, 70, 60), 20, 25, 3)
			burst(d.pos, FIRE, ORANGE, 30, 30, 2.5)
			ring(d.pos, 1, 9, ORANGE, 0.35)
			local crater = part({
				Shape = Enum.PartType.Cylinder,
				Material = Enum.Material.Basalt,
				Color = Color3.fromRGB(40, 30, 28),
				Size = Vector3.new(0.3, 7, 7),
				CFrame = CFrame.new(d.pos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			})
			emitter(
				crater,
				FIRE,
				ORANGE,
				{ Rate = 15, EmissionDirection = Enum.NormalId.Right, Size = NumberSequence.new(1.5, 0) }
			)
			task.delay(3, function()
				tween(crater, 1, { Transparency = 1 })
			end)
			Debris:AddItem(crater, 4.1)
			if near(d.pos, 35) then
				Combat.shake(0.5, 0.2)
			end
		end)
	end
end

Show.PhoenixDescent = function(caster, d)
	if d.phase == "rise" then
		local torso = caster and caster:FindFirstChild("UpperTorso") :: BasePart?
		if torso then
			for side = -1, 1, 2 do
				local wing = part({
					Anchored = false,
					Massless = true,
					Color = ORANGE,
					Size = Vector3.new(7, 0.3, 3),
					Transparency = 0.2,
				})
				wing.CFrame = torso.CFrame * CFrame.new(side * 4, 1, 0.8) * CFrame.Angles(0, 0, math.rad(side * 25))
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = torso
				weld.Part1 = wing
				weld.Parent = wing
				emitter(wing, FIRE, if side < 0 then ORANGE else GOLD, {
					Rate = 120,
					Size = NumberSequence.new(2.5, 0),
					Speed = NumberRange.new(2, 5),
					Lifetime = NumberRange.new(0.3, 0.6),
				})
				wing.Size = Vector3.new(0.5, 0.3, 0.5)
				tween(wing, 0.3, { Size = Vector3.new(7, 0.3, 3) }, Enum.EasingStyle.Back)
				Debris:AddItem(wing, 1.35)
			end
		end
		burst(d.pos, FIRE, ORANGE, 50, 30, 3)
		ring(d.pos - Vector3.new(0, 2.8, 0), 2, 14, ORANGE, 0.5)
	elseif d.phase == "dive" then
		if caster then
			Engine.play(caster, "EchoPhoenixDive")
			afterimage(caster, ORANGE, 0.4)
		end
		local mark = part({
			Shape = Enum.PartType.Cylinder,
			Color = ORANGE,
			Size = Vector3.new(0.2, 40, 40),
			CFrame = CFrame.new(d.pos - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Transparency = 0.7,
		})
		Debris:AddItem(mark, 0.45)
	elseif d.phase == "boom" then
		flash(d.pos, 6, 44, GOLD, 0.6)
		flash(d.pos, 4, 30, ORANGE, 0.8)
		burst(d.pos, FIRE, ORANGE, 120, 60, 4)
		burst(d.pos, SMOKE, Color3.fromRGB(80, 60, 50), 40, 40, 5)
		ring(d.pos, 2, 22, GOLD, 0.6, 1)
		ring(d.pos, 2, 30, ORANGE, 0.9)
		-- Burning ground for 6 s.
		for i = 1, 16 do
			local a = i / 16 * math.pi * 2
			local r = math.random() * 13
			local h = holder(d.pos + Vector3.new(math.cos(a) * r, 0.5, math.sin(a) * r), 6.6)
			local e = emitter(
				h,
				FIRE,
				ORANGE,
				{ Rate = 12, Size = NumberSequence.new(2.5, 0), EmissionDirection = Enum.NormalId.Top }
			)
			task.delay(6, function()
				e.Enabled = false
			end)
		end
		if near(d.pos, 60) then
			screenFlash(Color3.fromRGB(255, 160, 60), 0.5)
			Combat.shake(1.2, 0.5)
		end
	end
end

Show.FlashStep = function(caster, d)
	if not d.from then
		return
	end
	afterimage(caster, CYAN, 0.45)
	-- The afterimage was drawn where the caster is now; draw the start one from the old spot.
	burst(d.from, SPARK, CYAN, 20, 20, 1)
	bolt(d.from, d.to, CYAN, 0.35, 0.25)
	burst(d.to, SPARK, WHITE, 30, 28, 1.2)
	ring(d.to - Vector3.new(0, 2.6, 0), 1, 7, CYAN, 0.3)
end

Show.VoltLance = function(_, d)
	if not d.from then
		return
	end
	bolt(d.from, d.to, CYAN, 0.6, 0.3)
	bolt(d.from, d.to, WHITE, 0.25, 0.2)
	flash(d.to, 1, 8, CYAN, 0.25)
	burst(d.to, SPARK, CYAN, 25, 30, 1.2)
	if near(d.to, 25) then
		Combat.shake(0.35, 0.15)
	end
end

Show.Thunderclap = function(_, d)
	if not d.pos then
		return
	end
	ring(d.pos + Vector3.new(0, 0.2, 0), 1, 13, CYAN, 0.4, 0.8)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local spot = d.pos + Vector3.new(math.cos(a), 0, math.sin(a)) * (6 + math.random() * 5)
		task.delay(i * 0.02, function()
			bolt(spot + Vector3.new(0, 35, 0), spot, CYAN, 0.5, 0.25)
			burst(spot, SPARK, WHITE, 8, 18, 1)
		end)
	end
	if near(d.pos, 30) then
		Combat.shake(0.6, 0.25)
	end
end

Show.ArcChain = function(_, d)
	if not d.points then
		return
	end
	for i = 1, #d.points - 1 do
		task.delay(0.08 * (i - 1), function()
			bolt(d.points[i], d.points[i + 1], CYAN, 0.45, 0.3)
			bolt(d.points[i], d.points[i + 1], WHITE, 0.2, 0.2)
			burst(d.points[i + 1], SPARK, CYAN, 15, 20, 1)
		end)
	end
end

Show.RaijuRush = function(caster, d)
	if not d.pos then
		return
	end
	local hrp = hrpOf(caster)
	if hrp then
		local wolf = emitter(hrp, SPARK, CYAN, {
			Rate = 200,
			Size = NumberSequence.new(1.6, 0),
			Speed = NumberRange.new(2, 6),
			SpreadAngle = Vector2.new(180, 180),
			Lifetime = NumberRange.new(0.15, 0.35),
		})
		Debris:AddItem(wolf, 0.6)
		for i = 0, 3 do
			task.delay(i * 0.16, function()
				afterimage(caster, CYAN, 0.3)
			end)
		end
		task.delay(0.5, function()
			flash(hrp.Position, 2, 12, WHITE, 0.3)
			burst(hrp.Position, SPARK, CYAN, 30, 30, 1.4)
			if near(hrp.Position, 30) then
				Combat.shake(0.5, 0.2)
			end
		end)
	end
end

Show.StormPillar = function(_, d)
	if d.phase == "rise" then
		ring(d.pos + Vector3.new(0, 0.2, 0), 1, 8, CYAN, 0.4)
		burst(d.pos, SPARK, CYAN, 30, 25, 1.4)
	elseif d.phase == "strike" then
		bolt(d.from, d.to, CYAN, 0.45, 0.25)
		burst(d.to, SPARK, WHITE, 10, 18, 1)
	end
end

Show.RaijinsWrath = function(caster, d)
	if d.phase == "storm" then
		local sky = d.pos + Vector3.new(0, 28, 0)
		local cloud = part({
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(40, 45, 70),
			Size = Vector3.new(3, 4, 4),
			CFrame = CFrame.new(sky) * CFrame.Angles(0, 0, math.rad(90)),
			Transparency = 0.2,
		})
		tween(cloud, 0.8, { Size = Vector3.new(3, 80, 80) })
		emitter(cloud, SPARK, CYAN, { Rate = 40, Size = NumberSequence.new(2, 0), SpreadAngle = Vector2.new(180, 180) })
		task.delay(d.time, function()
			tween(cloud, 0.6, { Transparency = 1 })
		end)
		Debris:AddItem(cloud, d.time + 0.7)
		if caster then
			flash(d.pos, 2, 10, CYAN, 0.5)
		end
	elseif d.phase == "bolt" then
		bolt(d.pos + Vector3.new(0, 30, 0), d.pos, CYAN, 0.5, 0.25)
		burst(d.pos, SPARK, WHITE, 8, 18, 1)
	elseif d.phase == "final" then
		bolt(d.pos + Vector3.new(0, 60, 0), d.pos, WHITE, 2.2, 0.5)
		bolt(d.pos + Vector3.new(0, 60, 0), d.pos, CYAN, 1.2, 0.6)
		flash(d.pos, 4, 24, WHITE, 0.5)
		ring(d.pos - Vector3.new(0, 2.6, 0), 2, 16, CYAN, 0.5, 0.8)
		if near(d.pos, 45) then
			screenFlash(WHITE, 0.5)
			Combat.shake(1, 0.4)
		end
	end
end

Show.RiftBlink = function(caster, d)
	if not d.from then
		return
	end
	ring(d.from - Vector3.new(0, 1, 0), 0.5, 5, MAGENTA, 0.35)
	ring(d.to - Vector3.new(0, 1, 0), 0.5, 5, MAGENTA, 0.35)
	burst(d.to, SPARK, MAGENTA, 18, 18, 1)
	afterimage(caster, MAGENTA, 0.3)
end

Show.SecondWind = function(caster, d)
	if d.phase == "start" then
		local hrp = hrpOf(caster)
		if hrp and caster then
			local e = emitter(hrp, SPARK, Color3.fromRGB(140, 255, 170), {
				Rate = 40,
				Size = NumberSequence.new(0.8, 0),
				Speed = NumberRange.new(1, 2),
				SpreadAngle = Vector2.new(180, 180),
				RotSpeed = NumberRange.new(100, 200),
			})
			auras[caster] = e
			Debris:AddItem(e, 3.2)
		end
	elseif caster and auras[caster] then
		auras[caster]:Destroy()
		auras[caster] = nil
		if d.phase == "cancel" and d.pos then
			Combat.popText(d.pos, "CANCELLED", Color3.fromRGB(200, 200, 200))
		end
	end
end

Show.BattleCry = function(_, d)
	if not d.pos then
		return
	end
	ring(d.pos - Vector3.new(0, 2.5, 0), 1, 12, MAGENTA, 0.45, 0.8)
	flash(d.pos, 2, 10, MAGENTA, 0.3)
	Combat.popText(d.pos, "BATTLE CRY", Color3.fromRGB(255, 120, 230), true)
end

Show.IronWill = function(_, d)
	if not d.pos then
		return
	end
	burst(d.pos, SPARK, WHITE, 40, 30, 1.2)
	flash(d.pos, 2, 8, Color3.fromRGB(220, 220, 240), 0.3)
	Combat.popText(d.pos, "IRON WILL", Color3.fromRGB(230, 230, 255), true)
end

Show.RiftBurst = function(_, d)
	ring(d.pos - Vector3.new(0, 2.5, 0), 1, 11, MAGENTA, 0.4, 1)
	flash(d.pos, 3, 20, MAGENTA, 0.35)
	burst(d.pos, SPARK, MAGENTA, 50, 45, 1.6)
	Combat.popText(d.pos, "RIFT BURST", Color3.fromRGB(255, 120, 230), true)
	if near(d.pos, 20) then
		Combat.shake(0.6, 0.25)
	end
end

local function onEcho(caster: Model?, data)
	local e = Data.get(data.id)
	if data.phase == "cast" then
		local color = if e then Data.Elements[e.element].color else MAGENTA
		local hrp = hrpOf(caster)
		if hrp then
			burst(hrp.Position, SPARK, color, 14, 12, 1)
			if e then
				Combat.popText(hrp.Position + Vector3.new(0, 2, 0), e.name, Data.Rarity[e.rarity].color)
			end
		end
		return
	elseif data.phase == "interrupted" then
		if data.pos then
			Combat.popText(data.pos, "INTERRUPTED", Color3.fromRGB(200, 200, 255), true)
		end
		return
	end
	local show = Show[data.id]
	if show then
		show(caster, data)
	end
end

-- Status effects drawn on every fighter --------------------------------------------------

local STATUS_LOOKS = {
	Burn = { texture = FIRE, color = ORANGE, rate = 25, size = 1.6 },
	Shock = { texture = SPARK, color = CYAN, rate = 30, size = 0.9 },
	Blind = { texture = SMOKE, color = Color3.fromRGB(40, 20, 60), rate = 15, size = 2.5, head = true },
	BattleCry = {
		texture = SPARK,
		color = Color3.fromRGB(255, 60, 120),
		rate = 20,
		size = 0.8,
		attribute = "BattleCryUntil",
	},
}

local function fighters(): { Model }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	for _, m in CollectionService:GetTagged("BladeRiftRig") do
		table.insert(list, m)
	end
	return list
end

local function active(model: Model, attribute: string): boolean
	local untilTime = model:GetAttribute(attribute)
	return typeof(untilTime) == "number" and workspace:GetServerTimeNow() < untilTime
end

local function updateStatusLooks()
	for _, model in fighters() do
		local torso = model:FindFirstChild("UpperTorso")
		local head = model:FindFirstChild("Head")
		if torso and head then
			for name, look in STATUS_LOOKS do
				local on = active(model, look.attribute or ("Status_" .. name))
				local parent = if look.head then head else torso
				local e = parent:FindFirstChild("Fx_" .. name) :: ParticleEmitter?
				if on and not e then
					e = emitter(parent, look.texture, look.color, {
						Rate = look.rate,
						Size = NumberSequence.new(look.size, 0),
						SpreadAngle = Vector2.new(180, 180),
						Speed = NumberRange.new(1, 3),
						LightEmission = if name == "Blind" then 0 else 1,
					})
					e.Name = "Fx_" .. name
				end
				if e then
					e.Enabled = on
				end
			end
			-- Mark: a gold diamond over the head.
			local marked = active(model, "Status_Mark")
			local tag = head:FindFirstChild("Fx_Mark") :: BillboardGui?
			if marked and not tag then
				local gui = Instance.new("BillboardGui")
				gui.Name = "Fx_Mark"
				gui.Size = UDim2.fromOffset(30, 30)
				gui.StudsOffset = Vector3.new(0, 3.2, 0)
				gui.AlwaysOnTop = true
				local label = Instance.new("TextLabel")
				label.BackgroundTransparency = 1
				label.Size = UDim2.fromScale(1, 1)
				label.Font = Enum.Font.GothamBlack
				label.TextScaled = true
				label.TextColor3 = Color3.fromRGB(255, 230, 90)
				label.TextStrokeTransparency = 0.2
				label.Text = "◆"
				label.Parent = gui
				gui.Parent = head
			elseif not marked and tag then
				tag:Destroy()
			end
		end
	end
end

function EchoFx.handle(
	kind: string,
	attacker: Model?,
	target: Model?,
	position: Vector3?,
	amount: number?,
	extra: any
): boolean
	if kind == "echo" and typeof(extra) == "table" then
		onEcho(attacker, extra)
		return true
	elseif kind == "burntick" and position then
		Combat.popText(position, tostring(amount or 2), ORANGE)
		return true
	end
	local _ = target
	return false
end

function EchoFx.start(combat)
	Combat = combat
	folder = Instance.new("Folder")
	folder.Name = "EchoFx"
	folder.Parent = workspace
	task.spawn(function()
		while true do
			pcall(updateStatusLooks)
			task.wait(0.15)
		end
	end)
end

return EchoFx
