-- Visuals for the Ice, Wind, Shadow and Earth Echoes, the extra Rift Echoes, and the new
-- statuses and buffs (Freeze blocks, Chill frost, shields, invisibility, granite, mirrors).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

return function(k)
	local Show = k.Show
	local part, tween, emitter, holder, burst = k.part, k.tween, k.emitter, k.holder, k.burst
	local ring, flash, bolt, afterimage, near = k.ring, k.flash, k.bolt, k.afterimage, k.near
	local screenFlash, fly, withTrail, hrpOf, active = k.screenFlash, k.fly, k.withTrail, k.hrpOf, k.active
	local FIRE, SMOKE, SPARK = k.FIRE, k.SMOKE, k.SPARK
	local function Combat()
		return k.combat()
	end

	local ICE = Color3.fromRGB(150, 215, 255)
	local ICE_WHITE = Color3.fromRGB(230, 248, 255)
	local WIND = Color3.fromRGB(200, 255, 220)
	local SHADOW = Color3.fromRGB(140, 60, 220)
	local DARK = Color3.fromRGB(25, 10, 40)
	local EARTH = Color3.fromRGB(150, 110, 70)
	local STONE = Color3.fromRGB(115, 105, 95)
	local MAGENTA = Color3.fromRGB(230, 60, 220)
	local WHITE = Color3.new(1, 1, 1)
	local UP = Vector3.new(0, 1, 0)
	local localKey = -1

	local function nextKey(): number
		localKey -= 1
		return localKey
	end

	local function shake(pos: Vector3, radius: number, strength: number, seconds: number)
		if near(pos, radius) then
			Combat().shake(strength, seconds)
		end
	end

	local function pop(pos: Vector3, text: string, color: Color3, big: boolean?)
		Combat().popText(pos, text, color, big)
	end

	-- A spike or slab that shoots out of the ground and sinks back.
	local function spike(
		pos: Vector3,
		size: Vector3,
		color: Color3,
		material: Enum.Material,
		life: number,
		tilt: number?
	)
		local final = CFrame.new(pos + UP * size.Y / 2)
			* CFrame.Angles(math.rad(tilt or 0), math.random() * 6, math.rad(tilt or 0))
		local p = part({ Color = color, Material = material, Size = size, CFrame = final - UP * size.Y })
		tween(p, 0.12, { CFrame = final }, Enum.EasingStyle.Back)
		task.delay(life, function()
			tween(p, 0.4, { CFrame = final - UP * size.Y, Transparency = 1 })
		end)
		Debris:AddItem(p, life + 0.45)
		return p
	end

	local function disc(pos: Vector3, radius: number, color: Color3, material: Enum.Material?, life: number)
		local d = part({
			Shape = Enum.PartType.Cylinder,
			Color = color,
			Material = material or Enum.Material.Neon,
			Size = Vector3.new(0.2, radius * 2, radius * 2),
			CFrame = CFrame.new(pos + UP * 0.1) * CFrame.Angles(0, 0, math.rad(90)),
			Transparency = 0.3,
		})
		task.delay(life * 0.7, function()
			tween(d, life * 0.3, { Transparency = 1 })
		end)
		Debris:AddItem(d, life + 0.05)
		return d
	end

	-- Ice -------------------------------------------------------------------------------------

	Show.FrostLance = function(_, d)
		if d.phase == "fly" then
			local spear = part({ Color = ICE, Size = Vector3.new(0.45, 0.45, 4.5), Transparency = 0.1 })
			emitter(
				spear,
				SMOKE,
				ICE_WHITE,
				{ Rate = 40, Size = NumberSequence.new(1, 0), Speed = NumberRange.new(0, 1), LightEmission = 0.3 }
			)
			withTrail(spear, ICE, 0.4)
			fly(d.key, spear, d.origin, d.dir, d.speed, d.range)
		elseif d.phase == "end" then
			local p = k.projectiles[d.key]
			if p then
				p.stop()
			end
			burst(d.pos, SPARK, ICE_WHITE, 25, 22, 1)
		end
	end

	Show.GlacialGuard = function(_, d)
		ring(d.pos - UP * 2.6, 1, 5, ICE, 0.3)
		burst(d.pos, SPARK, ICE_WHITE, 20, 10, 0.8)
	end

	Show.GlacierWall = function(_, d)
		if d.phase == "shatter" then
			burst(d.pos, SPARK, ICE_WHITE, 50, 25, 1.4)
			burst(d.pos, SMOKE, ICE_WHITE, 15, 10, 3)
		else
			burst(d.pos + UP * 2, SMOKE, ICE_WHITE, 30, 18, 3)
			shake(d.pos, 30, 0.35, 0.2)
		end
	end

	Show.FrozenPath = function(_, d)
		if d.phase == "slip" then
			pop(d.pos, "SLIP", ICE)
		else
			burst(d.pos, SPARK, ICE_WHITE, 20, 12, 0.8)
		end
	end

	Show.AvalancheCrash = function(_, d)
		if not d.from then
			return
		end
		local length = (d.to - d.from).Magnitude
		local dir = if length > 0 then (d.to - d.from).Unit else Vector3.new(0, 0, -1)
		flash(d.from + UP, 2, 12, ICE_WHITE, 0.3)
		shake(d.from, 35, 0.6, 0.3)
		for i = 0, math.floor(length / 3.5) do
			task.delay(i * 0.035, function()
				local pos = d.from + dir * i * 3.5 + dir:Cross(UP) * (math.random() - 0.5) * 2
				spike(
					pos,
					Vector3.new(1.6, 4 + math.random() * 3, 1.6),
					ICE,
					Enum.Material.Ice,
					1,
					(math.random() - 0.5) * 30
				)
				burst(pos + UP, SPARK, ICE_WHITE, 4, 10, 0.7)
			end)
		end
	end

	Show.WintersCoffin = function(_, d)
		if d.phase == "fly" then
			local orb = part({ Shape = Enum.PartType.Ball, Color = ICE, Size = Vector3.one * 2.2, Transparency = 0.2 })
			emitter(orb, SPARK, ICE_WHITE, { Rate = 40, Size = NumberSequence.new(0.8, 0) })
			withTrail(orb, ICE, 0.9)
			fly(d.key, orb, d.origin, d.dir, d.speed, d.range)
		elseif d.phase == "end" then
			local p = k.projectiles[d.key]
			if p then
				p.stop()
			end
		elseif d.phase == "tomb" then
			local tomb = part({
				Material = Enum.Material.Ice,
				Color = ICE,
				Size = Vector3.new(5, 7.5, 5),
				CFrame = CFrame.new(d.pos + UP * 0.6),
				Transparency = 0.35,
			})
			tomb.Size = Vector3.new(5, 0.5, 5)
			tween(tomb, 0.2, { Size = Vector3.new(5, 7.5, 5) }, Enum.EasingStyle.Back)
			Debris:AddItem(tomb, 2)
			burst(d.pos, SPARK, ICE_WHITE, 30, 15, 1)
		elseif d.phase == "shatter" then
			burst(d.pos, SPARK, ICE_WHITE, 60, 30, 1.4)
			flash(d.pos, 3, 12, ICE_WHITE, 0.3)
			pop(d.pos, "SHATTER", ICE, true)
			shake(d.pos, 30, 0.5, 0.2)
		end
	end

	Show.AbsoluteZero = function(_, d)
		if d.phase == "wave" then
			ring(d.pos + UP * 0.2, 2, 31, ICE, 0.6, 1)
			ring(d.pos + UP * 0.2, 1, 25, ICE_WHITE, 0.8)
			flash(d.pos, 4, 30, ICE_WHITE, 0.5)
			burst(d.pos + UP * 2, SMOKE, ICE_WHITE, 50, 40, 4)
			if near(d.pos, 35) then
				screenFlash(ICE_WHITE, 0.6)
				Combat().shake(0.8, 0.4)
			end
		elseif d.phase == "shatter" then
			burst(d.pos, SPARK, ICE_WHITE, 50, 35, 1.5)
			flash(d.pos, 2, 10, ICE, 0.3)
		end
	end

	-- Wind ------------------------------------------------------------------------------------

	Show.GaleRoll = function(_, d)
		ring(d.pos - UP * 2.5, 1, 9, WIND, 0.35, 0.6)
		burst(d.pos - UP * 2, SMOKE, Color3.fromRGB(220, 210, 190), 20, 25, 2)
	end

	Show.WindScythe = function(_, d)
		if d.phase == "fly" then
			local blade = part({ Color = WIND, Size = Vector3.new(4.5, 0.2, 0.9), Transparency = 0.25 })
			withTrail(blade, WIND, 2)
			fly(d.key, blade, d.origin, d.dir, d.speed, d.range, true)
		elseif d.phase == "end" then
			local p = k.projectiles[d.key]
			if p then
				p.stop()
			end
			burst(d.pos, SPARK, WIND, 10, 18, 0.8)
		end
	end

	local function twister(pos: Vector3, height: number, life: number): Part
		local h = part({ Transparency = 1, Size = Vector3.new(4, height, 4), Position = pos + UP * height / 2 })
		emitter(h, SMOKE, WHITE, {
			Rate = 90,
			Size = NumberSequence.new(3, 1),
			Speed = NumberRange.new(4, 8),
			SpreadAngle = Vector2.new(180, 15),
			RotSpeed = NumberRange.new(300, 500),
			Transparency = NumberSequence.new(0.5, 1),
			LightEmission = 0.2,
		})
		emitter(h, SPARK, WIND, {
			Rate = 40,
			Size = NumberSequence.new(0.7, 0),
			Speed = NumberRange.new(8, 14),
			SpreadAngle = Vector2.new(180, 180),
		})
		Debris:AddItem(h, life)
		return h
	end

	Show.Updraft = function(_, d)
		local t = twister(d.pos, 14, 0.9)
		task.delay(0.6, function()
			for _, e in t:GetChildren() do
				(e :: ParticleEmitter).Enabled = false
			end
		end)
		ring(d.pos + UP * 0.2, 1, 9, WIND, 0.4)
		shake(d.pos, 25, 0.35, 0.2)
	end

	Show.TempestStep = function(_, d)
		ring(d.pos - UP * 2.5, 1, 6, WIND, 0.35)
		burst(d.pos, SPARK, WIND, 25, 15, 0.8)
	end

	Show.CycloneCutter = function(_, d)
		if not d.origin then
			return
		end
		local t = twister(d.origin - UP * 2.5, 12, d.range / d.speed + 0.5)
		local start = os.clock()
		task.spawn(function()
			while t.Parent do
				local dist = math.min((os.clock() - start) * d.speed, d.range)
				t.CFrame = CFrame.new(d.origin - UP * 2.5 + d.dir * dist + UP * 6)
				if dist >= d.range then
					break
				end
				task.wait()
			end
		end)
	end

	Show.VacuumBlade = function(_, d)
		if d.phase == "open" then
			local sphere = part({
				Shape = Enum.PartType.Ball,
				Color = WIND,
				Size = Vector3.one * 24,
				Position = d.pos,
				Transparency = 0.75,
			})
			tween(sphere, d.time, { Size = Vector3.one * 3, Transparency = 0.3 }, Enum.EasingStyle.Quad)
			Debris:AddItem(sphere, d.time + 0.05)
			for i = 0, 3 do
				task.delay(i * d.time / 4, function()
					ring(d.pos, 12, 1, WHITE, d.time / 4)
				end)
			end
		elseif d.phase == "burst" then
			flash(d.pos, 2, 16, WHITE, 0.35)
			ring(d.pos, 1, 10, WIND, 0.35, 0.8)
			burst(d.pos, SPARK, WIND, 40, 40, 1.2)
			shake(d.pos, 30, 0.6, 0.25)
		end
	end

	Show.HeavenSplitter = function(_, d)
		if not d.from then
			return
		end
		local mid = (d.from + d.to) / 2
		local length = (d.to - d.from).Magnitude
		local slash = part({
			Color = WHITE,
			Size = Vector3.new(10, 0.6, length),
			CFrame = CFrame.lookAt(mid, d.to) * CFrame.Angles(0, 0, math.rad(90)),
			Transparency = 0.05,
		})
		slash.Size = Vector3.new(10, 0.6, 2)
		tween(slash, 0.12, { Size = Vector3.new(10, 0.6, length) }, Enum.EasingStyle.Linear)
		task.delay(0.15, function()
			tween(slash, 0.5, { Transparency = 1, Size = Vector3.new(14, 0.2, length) })
		end)
		Debris:AddItem(slash, 0.7)
		local glow =
			part({ Color = WIND, Size = Vector3.new(20, 0.3, length), CFrame = slash.CFrame, Transparency = 0.6 })
		tween(glow, 0.6, { Transparency = 1 })
		Debris:AddItem(glow, 0.65)
		burst(d.from, SPARK, WHITE, 40, 30, 1.4)
		local character = Players.LocalPlayer and Players.LocalPlayer.Character
		local hrp = hrpOf(character)
		if hrp then
			local p = hrp.Position
			local ab = d.to - d.from
			local t = math.clamp((p - d.from):Dot(ab) / ab:Dot(ab), 0, 1)
			if (p - (d.from + ab * t)).Magnitude < 40 then
				screenFlash(WHITE, 0.5)
				Combat().shake(1, 0.4)
			end
		end
	end

	-- Shadow ----------------------------------------------------------------------------------

	local function pool(pos: Vector3, radius: number, life: number)
		local p = disc(pos, radius, DARK, Enum.Material.SmoothPlastic, life)
		p.Transparency = 0.1
		emitter(p, SMOKE, SHADOW, {
			Rate = 40,
			Size = NumberSequence.new(2, 0),
			Speed = NumberRange.new(1, 3),
			LightEmission = 0,
			EmissionDirection = Enum.NormalId.Right,
		})
		return p
	end

	Show.ShadeStep = function(caster, d)
		if d.phase == "sink" then
			pool(d.pos, 3, 0.6)
			afterimage(caster, SHADOW, 0.3)
		else
			pool(d.pos, 3, 0.6)
			burst(d.pos + UP * 2, SMOKE, SHADOW, 25, 15, 2.5)
		end
	end

	Show.UmbralFangs = function(_, d)
		if d.phase == "tendril" then
			spike(d.pos - UP * 3, Vector3.new(0.8, 6, 0.8), DARK, Enum.Material.Neon, 0.3, (math.random() - 0.5) * 40)
			burst(d.pos, SMOKE, SHADOW, 10, 10, 1.5)
		else
			burst(d.pos, SMOKE, SHADOW, 25, 12, 2)
		end
	end

	Show.ShadeClone = function(_, d)
		burst(d.pos, SMOKE, SHADOW, 35, 14, 2.5)
	end

	Show.VoidGrasp = function(_, d)
		if d.phase == "hands" then
			pool(d.pos, 5, 0.8)
			for i = 1, 5 do
				local a = i / 5 * math.pi * 2
				local spot = d.pos + Vector3.new(math.cos(a), 0, math.sin(a)) * 2.5
				task.delay(0.3, function()
					spike(spot, Vector3.new(1, 5, 1), DARK, Enum.Material.Neon, 0.4, 20)
				end)
			end
		elseif d.phase == "drag" then
			bolt(d.from, d.to, SHADOW, 0.6, 0.35)
			burst(d.from, SMOKE, SHADOW, 15, 12, 2)
		end
	end

	Show.NightfallVeil = function(_, d)
		if d.phase == "dome" then
			local dome = part({
				Shape = Enum.PartType.Ball,
				Material = Enum.Material.SmoothPlastic,
				Color = DARK,
				Size = Vector3.one * 2,
				Position = d.pos,
				Transparency = 0.45,
			})
			tween(dome, 0.4, { Size = Vector3.one * d.radius * 2 })
			emitter(dome, SPARK, Color3.fromRGB(210, 190, 255), {
				Rate = 25,
				Size = NumberSequence.new(0.5, 0),
				Speed = NumberRange.new(0, 1),
				Lifetime = NumberRange.new(1, 2),
			})
			task.delay(d.time, function()
				if dome.Parent then
					dome:Destroy()
				end
			end)
		else
			local dome = part({
				Shape = Enum.PartType.Ball,
				Color = SHADOW,
				Size = Vector3.one * 36,
				Position = d.pos,
				Transparency = 0.5,
			})
			tween(dome, 0.3, { Size = Vector3.one, Transparency = 0.1 })
			Debris:AddItem(dome, 0.3)
			task.delay(0.3, function()
				flash(d.pos, 2, 20, SHADOW, 0.35)
				burst(d.pos, SMOKE, SHADOW, 40, 30, 3)
			end)
		end
	end

	Show.EclipseRend = function(caster, d)
		afterimage(caster, SHADOW, 0.35)
		bolt(d.from, d.to, SHADOW, 0.3, 0.2)
		local mark = part({
			Color = SHADOW,
			Size = Vector3.new(0.3, 0.3, 7),
			CFrame = CFrame.lookAt(d.to, d.to + Vector3.new(1, 0.8, 0.3)),
		})
		task.delay(0.35, function()
			tween(mark, 0.2, { Size = Vector3.new(0.05, 0.05, 9), Transparency = 1 })
		end)
		Debris:AddItem(mark, 0.6)
	end

	Show.Eclipse = function(_, d)
		if d.phase == "moonrise" then
			local moon = part({
				Shape = Enum.PartType.Ball,
				Color = DARK,
				Material = Enum.Material.SmoothPlastic,
				Size = Vector3.one * 2,
				Position = d.pos + UP * 45,
			})
			emitter(moon, SPARK, SHADOW, { Rate = 50, Size = NumberSequence.new(3, 0), Speed = NumberRange.new(1, 3) })
			tween(moon, 0.6, { Size = Vector3.one * 16 })
			Debris:AddItem(moon, 1.6)
			if near(d.pos, 60) then
				screenFlash(DARK, 0.8)
			end
		elseif d.phase == "moonfall" then
			local moon = part({
				Shape = Enum.PartType.Ball,
				Color = DARK,
				Material = Enum.Material.SmoothPlastic,
				Size = Vector3.one * 16,
				Position = d.pos + UP * 60,
			})
			emitter(moon, SPARK, SHADOW, { Rate = 100, Size = NumberSequence.new(4, 0), Speed = NumberRange.new(1, 3) })
			withTrail(moon, SHADOW, 6)
			tween(moon, 0.6, { Position = d.pos }, Enum.EasingStyle.Quad)
			task.delay(0.6, function()
				moon:Destroy()
				flash(d.pos, 6, 36, SHADOW, 0.6)
				ring(d.pos + UP * 0.2, 2, 24, SHADOW, 0.6, 1)
				burst(d.pos, SMOKE, DARK, 60, 50, 5)
				if near(d.pos, 50) then
					screenFlash(SHADOW, 0.5)
					Combat().shake(1.2, 0.5)
				end
			end)
		end
	end

	-- Earth -----------------------------------------------------------------------------------

	local function dust(pos: Vector3, count: number, speed: number)
		burst(pos, SMOKE, Color3.fromRGB(170, 150, 120), count, speed, 3)
	end

	local function crackLine(from: Vector3, to: Vector3, seconds: number)
		local length = (to - from).Magnitude
		local dir = if length > 0 then (to - from).Unit else Vector3.new(0, 0, -1)
		for i = 0, math.floor(length / 2) do
			task.delay(seconds * i * 2 / math.max(length, 1), function()
				local p = part({
					Color = Color3.fromRGB(40, 30, 25),
					Material = Enum.Material.Slate,
					Size = Vector3.new(0.5, 0.15, 2.2),
					CFrame = CFrame.lookAt(from + dir * i * 2 + UP * 0.08, from + dir * (i * 2 + 1))
						* CFrame.Angles(0, math.rad((math.random() - 0.5) * 30), 0),
				})
				task.delay(1.5, function()
					tween(p, 0.5, { Transparency = 1 })
				end)
				Debris:AddItem(p, 2.05)
			end)
		end
	end

	Show.StonePillar = function(_, d)
		if d.phase == "crack" then
			crackLine(d.from, d.to, 0.35)
		else
			spike(d.pos, Vector3.new(4, 10, 4), STONE, Enum.Material.Slate, 1.4)
			dust(d.pos, 25, 20)
			shake(d.pos, 30, 0.4, 0.2)
		end
	end

	Show.RockToss = function(_, d)
		if d.phase == "fly" then
			local rock = part({
				Shape = Enum.PartType.Ball,
				Color = STONE,
				Material = Enum.Material.Slate,
				Size = Vector3.one * 3,
			})
			emitter(
				rock,
				SMOKE,
				Color3.fromRGB(170, 150, 120),
				{ Rate = 30, Size = NumberSequence.new(1.5, 0), LightEmission = 0 }
			)
			fly(d.key, rock, d.origin, d.dir, d.speed, d.range, true)
		elseif d.phase == "end" then
			local p = k.projectiles[d.key]
			if p then
				p.stop()
			end
		elseif d.phase == "smash" then
			dust(d.pos, 25, 25)
			for _ = 1, 5 do
				local chunk = part({
					Anchored = false,
					Color = STONE,
					Material = Enum.Material.Slate,
					Size = Vector3.one * (0.6 + math.random()),
					Position = d.pos + UP,
				})
				chunk.AssemblyLinearVelocity =
					Vector3.new(math.random(-20, 20), math.random(15, 30), math.random(-20, 20))
				Debris:AddItem(chunk, 1.5)
			end
		end
	end

	Show.QuakeStomp = function(_, d)
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			crackLine(d.pos, d.pos + Vector3.new(math.cos(a), 0, math.sin(a)) * 14, 0.2)
		end
		ring(d.pos + UP * 0.3, 1, 15, EARTH, 0.45, 1)
		dust(d.pos + UP, 40, 35)
		shake(d.pos, 35, 0.8, 0.35)
	end

	Show.GraniteSkin = function(_, d)
		burst(d.pos, SMOKE, STONE, 30, 12, 2)
		pop(d.pos, "GRANITE SKIN", Color3.fromRGB(210, 190, 160), true)
	end

	Show.TectonicRift = function(_, d)
		if d.phase == "break" then
			burst(d.pos, SPARK, WHITE, 40, 30, 1.2)
			pop(d.pos, "BROKEN", WHITE, true)
			return
		end
		local length = (d.to - d.from).Magnitude
		local dir = if length > 0 then (d.to - d.from).Unit else Vector3.new(0, 0, -1)
		crackLine(d.from, d.to, 0.6)
		for i = 0, math.floor(length / 4) do
			task.delay(0.6 * i * 4 / math.max(length, 1), function()
				local pos = d.from + dir * i * 4 + dir:Cross(UP) * (math.random() - 0.5) * 3
				spike(
					pos,
					Vector3.new(2, 3 + math.random() * 3, 2),
					STONE,
					Enum.Material.Slate,
					1.2,
					(math.random() - 0.5) * 50
				)
				dust(pos, 6, 12)
			end)
		end
		shake(d.from, 40, 0.6, 0.6)
	end

	Show.EarthenPrison = function(_, d)
		if d.phase == "dome" then
			local dome = part({
				Shape = Enum.PartType.Ball,
				Color = STONE,
				Material = Enum.Material.Slate,
				Size = Vector3.one * 9,
				Position = d.pos - UP * 9,
			})
			tween(dome, 0.25, { Position = d.pos }, Enum.EasingStyle.Back)
			Debris:AddItem(dome, 2)
			dust(d.pos, 25, 20)
		else
			dust(d.pos, 40, 35)
			flash(d.pos, 3, 14, EARTH, 0.3)
			for _ = 1, 8 do
				local chunk = part({
					Anchored = false,
					Color = STONE,
					Material = Enum.Material.Slate,
					Size = Vector3.one * (1 + math.random()),
					Position = d.pos + UP,
				})
				chunk.AssemblyLinearVelocity =
					Vector3.new(math.random(-30, 30), math.random(20, 40), math.random(-30, 30))
				Debris:AddItem(chunk, 1.5)
			end
			shake(d.pos, 30, 0.6, 0.25)
		end
	end

	Show.MountainsWrath = function(_, d)
		if d.phase == "rise" then
			local fist = part({
				Color = STONE,
				Material = Enum.Material.Slate,
				Size = Vector3.new(4, 6, 4),
				CFrame = CFrame.new(d.pos + UP * 40),
			})
			fist.Name = "Fist"
			tween(fist, 0.8, { Size = Vector3.new(14, 18, 14) }, Enum.EasingStyle.Back)
			disc(d.pos, 20, Color3.fromRGB(60, 40, 30), Enum.Material.SmoothPlastic, 1.1).Transparency = 0.5
			task.delay(0.9, function()
				tween(fist, 0.15, { CFrame = CFrame.new(d.pos + UP * 9) }, Enum.EasingStyle.Linear)
				task.delay(1.2, function()
					tween(fist, 0.6, { Transparency = 1, CFrame = CFrame.new(d.pos - UP * 4) })
				end)
				Debris:AddItem(fist, 2)
			end)
			if near(d.pos, 60) then
				Combat().shake(0.3, 0.8)
			end
		elseif d.phase == "slam" then
			ring(d.pos + UP * 0.3, 2, 24, EARTH, 0.6, 1.2)
			dust(d.pos + UP * 2, 80, 60)
			for i = 1, 10 do
				local a = i / 10 * math.pi * 2
				crackLine(d.pos, d.pos + Vector3.new(math.cos(a), 0, math.sin(a)) * 20, 0.25)
			end
			if near(d.pos, 60) then
				screenFlash(Color3.fromRGB(200, 160, 110), 0.4)
				Combat().shake(1.4, 0.5)
			end
		elseif d.phase == "rain" then
			for i = 1, 12 do
				task.delay(i * d.time / 12, function()
					local a = math.random() * math.pi * 2
					local spot = d.pos + Vector3.new(math.cos(a), 0, math.sin(a)) * math.random() * 18
					local rock = part({
						Shape = Enum.PartType.Ball,
						Color = STONE,
						Material = Enum.Material.Slate,
						Size = Vector3.one * 2.5,
						Position = spot + UP * 50,
					})
					tween(rock, 0.35, { Position = spot }, Enum.EasingStyle.Linear)
					task.delay(0.35, function()
						rock:Destroy()
						dust(spot, 12, 18)
					end)
				end)
			end
		end
	end

	-- Rift ------------------------------------------------------------------------------------

	Show.GrappleHook = function(_, d)
		local links = math.clamp(math.floor((d.to - d.from).Magnitude / 1.5), 2, 25)
		local made = {}
		for i = 1, links do
			task.delay(0.12 * i / links, function()
				local p = part({
					Color = MAGENTA,
					Size = Vector3.new(0.35, 0.35, 1),
					CFrame = CFrame.lookAt(d.from:Lerp(d.to, i / links), d.to),
				})
				table.insert(made, p)
				Debris:AddItem(p, 0.6)
			end)
		end
		task.delay(0.15, function()
			if d.miss then
				for _, p in made do
					tween(p, 0.2, { Transparency = 1 })
				end
			else
				burst(d.to, SPARK, MAGENTA, 15, 15, 1)
			end
		end)
	end

	Show.Afterimage = function(_, d)
		if d.phase == "explode" then
			flash(d.pos, 3, 16, MAGENTA, 0.35)
			ring(d.pos - UP * 2.5, 1, 8, MAGENTA, 0.35, 0.8)
			burst(d.pos, SPARK, MAGENTA, 50, 35, 1.4)
			shake(d.pos, 25, 0.5, 0.2)
		else
			ring(d.pos - UP * 2.5, 1, 5, MAGENTA, 0.3)
		end
	end

	Show.RiftBarrier = function(_, d)
		burst(d.pos, SPARK, MAGENTA, 25, 12, 1)
	end

	Show.MirrorGuard = function(_, d)
		flash(d.pos, 1, 7, WHITE, 0.25)
		pop(d.pos, "MIRROR GUARD", Color3.fromRGB(255, 200, 250), true)
	end

	-- Other effect messages --------------------------------------------------------------------

	k.extraKinds.counter = function(defender, attacker, pos)
		if pos then
			burst(pos, SPARK, ICE_WHITE, 40, 25, 1.2)
			pop(pos, "COUNTER", ICE, true)
		end
		local _ = defender
		local __ = attacker
	end
	k.extraKinds.shatter = function(_, target, pos)
		if pos then
			burst(pos, SPARK, ICE_WHITE, 40, 25, 1.2)
			pop(pos + UP, "SHATTER +8", ICE, true)
		end
		local _ = target
	end
	k.extraKinds.shieldbreak = function(_, _, pos)
		if pos then
			burst(pos, SPARK, MAGENTA, 40, 25, 1.2)
			pop(pos, "SHIELD BROKEN", Color3.fromRGB(255, 150, 240), true)
		end
	end

	-- Status and buff looks ---------------------------------------------------------------------

	k.STATUS_LOOKS.Silence = { texture = SPARK, color = SHADOW, rate = 20, size = 0.7, head = true }
	k.STATUS_LOOKS.Root = { texture = SMOKE, color = EARTH, rate = 15, size = 1.6 }
	k.STATUS_LOOKS.Fracture = { texture = SMOKE, color = STONE, rate = 12, size = 1.2 }
	k.STATUS_LOOKS.Airborne = { texture = SMOKE, color = WHITE, rate = 25, size = 1.5 }
	k.STATUS_LOOKS.Granite = { texture = SMOKE, color = STONE, rate = 20, size = 1.4, attribute = "GraniteUntil" }
	k.STATUS_LOOKS.Tempest = { texture = SPARK, color = WIND, rate = 30, size = 0.8, attribute = "TempestUntil" }
	k.STATUS_LOOKS.Umbral = { texture = SMOKE, color = SHADOW, rate = 25, size = 1.2, attribute = "UmbralUntil" }

	local attached: { [Model]: { [string]: Instance } } = {}
	local lastPathDisc: { [Model]: number } = {}

	-- Shows `make()`'s part on a fighter while `on`, welded to its root.
	local function attachWhile(model: Model, key: string, on: boolean, make: () -> BasePart)
		local list = attached[model]
		if not list then
			list = {}
			attached[model] = list
			model.Destroying:Connect(function()
				attached[model] = nil
			end)
		end
		local existing = list[key]
		if on and not existing then
			local hrp = hrpOf(model)
			if hrp then
				local p = make()
				p.Anchored = false
				p.Massless = true
				p.CFrame = hrp.CFrame * (p:GetAttribute("Offset") or CFrame.identity)
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = hrp
				weld.Part1 = p
				weld.Parent = p
				list[key] = p
			end
		elseif not on and existing then
			existing:Destroy()
			list[key] = nil
		end
	end

	local invisibleSet: { [Model]: boolean } = {}

	table.insert(k.statusUpdaters, function(model: Model, torso: BasePart)
		local t = workspace:GetServerTimeNow()
		local function on(attribute: string): boolean
			return active(model, attribute)
		end

		-- Freeze: a block of ice; Chill: frost that thickens with stacks.
		attachWhile(model, "Freeze", on("Status_Freeze"), function()
			return part({
				Material = Enum.Material.Ice,
				Color = ICE,
				Size = Vector3.new(4.5, 6.5, 4.5),
				Transparency = 0.35,
			})
		end)
		local stacks = model:GetAttribute("ChillStacks")
		local frost = torso:FindFirstChild("Fx_Chill") :: ParticleEmitter?
		if typeof(stacks) == "number" and stacks > 0 then
			if not frost then
				frost = emitter(torso, SPARK, ICE_WHITE, {
					Size = NumberSequence.new(0.6, 0),
					SpreadAngle = Vector2.new(180, 180),
					Speed = NumberRange.new(1, 2),
				})
				frost.Name = "Fx_Chill"
			end
			frost.Rate = 15 * stacks
			frost.Enabled = true
		elseif frost then
			frost.Enabled = false
		end

		-- Rift Barrier bubble, Mirror Guard disc, Glacial Guard crystals.
		attachWhile(model, "Shield", on("ShieldUntil"), function()
			return part({
				Shape = Enum.PartType.Ball,
				Material = Enum.Material.ForceField,
				Color = MAGENTA,
				Size = Vector3.one * 7.5,
			})
		end)
		local counter = model:GetAttribute("CounterKind")
		local countering = on("CounterUntil")
		attachWhile(model, "Mirror", countering and counter == "MirrorGuard", function()
			local p = part({
				Shape = Enum.PartType.Cylinder,
				Material = Enum.Material.Glass,
				Color = Color3.fromRGB(255, 210, 250),
				Size = Vector3.new(0.3, 6, 6),
				Transparency = 0.3,
			})
			p:SetAttribute("Offset", CFrame.new(0, 0.5, -2.5) * CFrame.Angles(0, math.rad(90), 0))
			return p
		end)
		attachWhile(model, "IceGuard", countering and counter == "GlacialGuard", function()
			local p =
				part({ Material = Enum.Material.Ice, Color = ICE, Size = Vector3.new(5, 6, 1), Transparency = 0.4 })
			p:SetAttribute("Offset", CFrame.new(0, 0.3, -2))
			return p
		end)

		-- Frozen Path leaves ice under your feet as you skate.
		local hrp = hrpOf(model)
		if hrp and on("FrozenPathUntil") and os.clock() - (lastPathDisc[model] or 0) > 0.12 then
			lastPathDisc[model] = os.clock()
			disc(hrp.Position - UP * 2.9, 2.5, ICE, Enum.Material.Ice, 3)
		end

		-- Shade Clone invisibility: gone for everyone else, a faint shadow for you.
		local invisible = on("InvisibleUntil")
		if invisible or invisibleSet[model] then
			local me = Players.LocalPlayer and Players.LocalPlayer.Character == model
			local amount = if invisible then (if me then 0.7 else 1) else 0
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") or d:IsA("Decal") then
					(d :: any).LocalTransparencyModifier = amount
				end
			end
			local overhead = model:FindFirstChild("Overhead", true)
			if overhead and overhead:IsA("BillboardGui") then
				overhead.Enabled = not invisible
			end
			invisibleSet[model] = if invisible then true else nil
		end
		local _ = t
	end)
end
