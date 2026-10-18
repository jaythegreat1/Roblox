-- Ice, Wind, Shadow, Earth and the rest of the Rift Echoes. Each one is registered into the
-- shared Behaviour table and uses the same tools (aiming, projectiles, sweeps, constructs) as
-- the Fire and Lightning sets in Echoes.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Combat = require(script.Parent.Combat)
local Data = require(ReplicatedStorage.Shared.Combat.Echoes)

return function(kit)
	local B = kit.Behaviour
	local now, flat, aim, aimDirection = kit.now, kit.flat, kit.aim, kit.aimDirection
	local face, teleport, drive, sweepPath = kit.face, kit.teleport, kit.drive, kit.sweepPath
	local projectile, area, groundAt, clearDistance = kit.projectile, kit.area, kit.groundAt, kit.clearDistance
	local distToSegment, enemiesOf, echoFx = kit.distToSegment, kit.enemiesOf, kit.echoFx

	local UP = Vector3.new(0, 1, 0)

	local function look(s): Vector3
		return flat(s.hrp.CFrame.LookVector)
	end

	-- The direction you are moving (sent by your client), else where you face.
	local function moveDir(s, arg): Vector3
		if
			typeof(arg) == "table"
			and typeof(arg.dir) == "Vector3"
			and (arg.dir * Vector3.new(1, 0, 1)).Magnitude > 0.1
		then
			return flat(arg.dir)
		end
		return look(s)
	end

	-- Pulls a fighter toward `point` (knockback from the mirrored side of them).
	local function pull(t, point: Vector3, strength: number, lift: number?)
		Combat.knockback(t, t.hrp.Position * 2 - point, strength, lift or 6)
	end

	local function sorted(s, center: Vector3, range: number, count: number)
		local list = {}
		for _, t in enemiesOf(s) do
			local d = (t.hrp.Position - center).Magnitude
			if d <= range then
				table.insert(list, { t = t, d = d })
			end
		end
		table.sort(list, function(a, b)
			return a.d < b.d
		end)
		local out = {}
		for i = 1, math.min(count, #list) do
			out[i] = list[i].t
		end
		return out
	end

	-- A copy of a fighter left behind (Shade Clone, Afterimage).
	local function makeDecoy(s, tint: Color3?, life: number): Model?
		local archivable = s.model.Archivable
		s.model.Archivable = true
		local ok, clone = pcall(function()
			return s.model:Clone()
		end)
		s.model.Archivable = archivable
		if not ok or not clone then
			return nil
		end
		for _, d in clone:GetDescendants() do
			if
				d:IsA("LuaSourceContainer")
				or d:IsA("Sound")
				or d:IsA("ParticleEmitter")
				or d:IsA("BillboardGui")
				or d:IsA("ForceField")
			then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.Anchored = d.Name == "HumanoidRootPart"
				if tint then
					d.Color = tint
					d.Material = Enum.Material.Neon
					d.Transparency = if d.Name == "HumanoidRootPart" then 1 else 0.45
				end
			end
		end
		for name in clone:GetAttributes() do
			if name ~= "SwordId" and name ~= "Armed" then
				clone:SetAttribute(name, nil)
			end
		end
		local humanoid = clone:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		clone.Name = s.model.Name
		CollectionService:AddTag(clone, "BladeRiftRig")
		clone.Parent = kit.effects()
		task.delay(life, function()
			if clone.Parent then
				clone:Destroy()
			end
		end)
		return clone
	end

	------------------------------------------------------------------------------------------
	-- Ice (Frost): slows that build into freezes, walls and counters.

	B.FrostLance = {
		run = function(s, arg)
			local dir = aimDirection(s, arg, 40)
			face(s, dir)
			projectile(s, "FrostLance", s.hrp.Position + Vector3.new(0, 0.6, 0), dir, 90, 40, 3.5, function(o, t, pos)
				Combat.echoHit(
					o,
					t,
					7,
					{ status = "Chill", posture = 10, knockback = 12, ranged = true, projectile = true, from = pos }
				)
				return true
			end)
		end,
	}

	B.GlacialGuard = {
		run = function(s)
			s.model:SetAttribute("CounterKind", "GlacialGuard")
			s.model:SetAttribute("CounterUntil", now() + 1)
			echoFx(s, "GlacialGuard", { pos = s.hrp.Position })
			task.delay(1.05, function()
				if s.model:GetAttribute("CounterKind") == "GlacialGuard" then
					s.model:SetAttribute("CounterKind", nil)
				end
			end)
		end,
	}

	B.GlacierWall = {
		run = function(s)
			local dir = look(s)
			local base = groundAt(s.hrp.Position + dir * 7)
			local final = CFrame.lookAt(base + UP * 4, base + UP * 4 + dir)
			local wall = Instance.new("Part")
			wall.Name = "GlacierWall"
			wall.Anchored = true
			wall.CanCollide = true
			wall.Material = Enum.Material.Ice
			wall.Color = Color3.fromRGB(170, 225, 255)
			wall.Transparency = 0.25
			wall.Size = Vector3.new(20, 8, 2)
			wall.CFrame = final - UP * 8
			wall.Parent = kit.walls()
			TweenService:Create(wall, TweenInfo.new(0.25, Enum.EasingStyle.Back), { CFrame = final }):Play()
			kit.addConstruct(s, wall, "GlacierWall", base + UP * 4)
			echoFx(s, "GlacierWall", { pos = base, dir = dir })
			-- Anyone the wall rises under is thrown clear of it.
			for _, t in enemiesOf(s) do
				local local_ = final:PointToObjectSpace(t.hrp.Position)
				if math.abs(local_.X) < 10.5 and math.abs(local_.Z) < 2.5 and math.abs(local_.Y) < 6 then
					Combat.knockback(t, t.hrp.Position - dir, 35, 15)
				end
			end
			task.delay(6, function()
				if wall.Parent then
					echoFx(s, "GlacierWall", { phase = "shatter", pos = wall.Position })
					wall:Destroy()
				end
			end)
		end,
	}

	B.FrozenPath = {
		run = function(s)
			local stop = now() + 4
			s.model:SetAttribute("FrozenPathUntil", stop)
			echoFx(s, "FrozenPath", { pos = s.hrp.Position })
			task.spawn(function()
				local points: { { p: Vector3, until_: number } } = {}
				local lastChill = {}
				while now() < stop + 2 and s.model.Parent do
					if now() < stop then
						table.insert(points, { p = s.hrp.Position, until_ = now() + 3 })
					end
					for i = #points, 1, -1 do
						if now() > points[i].until_ then
							table.remove(points, i)
						end
					end
					for _, t in enemiesOf(s) do
						for _, pt in points do
							if (t.hrp.Position - pt.p).Magnitude < 3 and os.clock() - (lastChill[t] or 0) > 1 then
								lastChill[t] = os.clock()
								Combat.applyStatus(t, "Chill", nil, s)
								echoFx(s, "FrozenPath", { phase = "slip", pos = t.hrp.Position })
								break
							end
						end
					end
					task.wait(0.15)
				end
			end)
		end,
	}

	B.AvalancheCrash = {
		run = function(s, arg)
			local dir = aimDirection(s, arg, 40)
			face(s, dir)
			local start = s.hrp.Position
			drive(s, {
				{ v = UP * 45 + dir * 10, t = 0.25 },
				{ v = UP * -80 + dir * 5, t = 0.2 },
				{ v = Vector3.zero, t = 0.05 },
			})
			task.delay(0.45, function()
				if not Combat.alive(s) then
					return
				end
				local origin = start + dir * 4
				local finish = origin + dir * clearDistance(origin, dir, 40)
				echoFx(s, "AvalancheCrash", { from = groundAt(origin), to = groundAt(finish) })
				sweepPath(s, { origin, finish }, 0.45, 3.8, function(t)
					Combat.echoHit(
						s,
						t,
						14,
						{ status = "Chill", posture = 18, lift = 55, knockback = 8, from = origin }
					)
				end)
			end)
		end,
	}

	B.WintersCoffin = {
		run = function(s, arg)
			local dir = aimDirection(s, arg, 35)
			face(s, dir)
			projectile(s, "WintersCoffin", s.hrp.Position + Vector3.new(0, 0.8, 0), dir, 50, 35, 3.5, function(o, t)
				local invul = t.model:GetAttribute("InvulnerableUntil")
				if typeof(invul) == "number" and now() < invul then
					Combat.fx("dodge", o.model, t.model, t.hrp.Position)
					return false
				end
				t.model:SetAttribute("EntombedUntil", now() + 2)
				Combat.stun(t, 2)
				echoFx(o, "WintersCoffin", { phase = "tomb", pos = t.hrp.Position })
				task.delay(2, function()
					t.model:SetAttribute("EntombedUntil", nil)
					if Combat.alive(t) then
						echoFx(o, "WintersCoffin", { phase = "shatter", pos = t.hrp.Position })
						Combat.echoHit(o, t, 20, {
							posture = 20,
							knockback = 30,
							lift = 20,
							unblockable = true,
							ranged = true,
							from = t.hrp.Position + look(o),
						})
					end
				end)
				return true
			end)
		end,
	}

	B.AbsoluteZero = {
		run = function(s)
			local center = s.hrp.Position
			echoFx(s, "AbsoluteZero", { phase = "wave", pos = groundAt(center) })
			local frozen = {}
			area(s, center, 30, function(t)
				Combat.applyStatus(t, "Freeze", 2.7, s)
				table.insert(frozen, t)
			end)
			task.delay(2.5, function()
				for _, t in frozen do
					if Combat.alive(t) then
						echoFx(s, "AbsoluteZero", { phase = "shatter", pos = t.hrp.Position })
						-- 22 plus the Freeze shatter bonus of 8: 30 in all.
						Combat.echoHit(s, t, 22, {
							posture = 30,
							heavy = true,
							lift = 25,
							knockback = 20,
							unblockable = true,
							unparryable = true,
							ranged = true,
							from = center,
						})
					end
				end
			end)
		end,
	}

	------------------------------------------------------------------------------------------
	-- Wind (Gale): mobility, knockbacks and juggles.

	B.GaleRoll = {
		run = function(s, arg)
			local dir = moveDir(s, arg)
			local start = s.hrp.Position
			s.model:SetAttribute("InvulnerableUntil", now() + 0.3)
			drive(s, { { v = dir * (14 / 0.42), t = 0.42 } })
			echoFx(s, "GaleRoll", { pos = start })
			area(s, start, 8, function(t)
				Combat.echoHit(s, t, 6, { posture = 8, knockback = 45, lift = 14, from = start })
			end)
		end,
	}

	B.WindScythe = {
		run = function(s, arg)
			local dir = aimDirection(s, arg, 35)
			face(s, dir)
			local right = dir:Cross(UP)
			for side = -1, 1, 2 do
				local origin = s.hrp.Position + Vector3.new(0, 0.8, 0) + right * side * 1.2
				projectile(s, "WindScythe", origin, dir, 80, 35, 3, function(o, t, pos)
					Combat.echoHit(
						o,
						t,
						4,
						{ posture = 6, knockback = 8, ranged = true, projectile = true, from = pos }
					)
					return true
				end)
			end
		end,
	}

	B.Updraft = {
		run = function(s)
			local center = s.hrp.Position
			drive(s, { { v = UP * 55, t = 0.22 } })
			echoFx(s, "Updraft", { pos = groundAt(center) })
			area(s, center, 8, function(t)
				Combat.echoHit(
					s,
					t,
					9,
					{ status = "Airborne", posture = 10, lift = 62, knockback = 2, stun = 0.8, from = center }
				)
			end)
		end,
	}

	B.TempestStep = {
		run = function(s)
			s.model:SetAttribute("TempestUntil", now() + 5)
			echoFx(s, "TempestStep", { pos = s.hrp.Position })
		end,
	}

	B.CycloneCutter = {
		run = function(s, arg)
			local dir = aimDirection(s, arg, 30)
			face(s, dir)
			local origin = s.hrp.Position
			local travel = clearDistance(origin, dir, 30)
			local speed = 15
			echoFx(s, "CycloneCutter", { origin = origin, dir = dir, speed = speed, range = travel })
			task.spawn(function()
				local start = os.clock()
				local dealt = {}
				while os.clock() - start < travel / speed + 0.1 and Combat.alive(s) do
					local pos = origin + dir * math.min((os.clock() - start) * speed, travel)
					for _, t in enemiesOf(s) do
						local d = ((t.hrp.Position - pos) * Vector3.new(1, 0, 1)).Magnitude
						if d <= 7 and (dealt[t] or 0) < 15 then
							local amount = math.min(1.875, 15 - (dealt[t] or 0))
							dealt[t] = (dealt[t] or 0) + amount
							Combat.echoHit(s, t, amount, {
								status = if dealt[t] <= amount then "Airborne" else nil,
								posture = 4,
								stun = 0.4,
								ranged = true,
								from = pos,
							})
							pull(t, pos, math.clamp(d * 4, 8, 25), 22)
						end
					end
					task.wait(0.25)
				end
			end)
		end,
	}

	B.VacuumBlade = {
		run = function(s)
			local dir = look(s)
			local center = s.hrp.Position + dir * clearDistance(s.hrp.Position, dir, 15)
			echoFx(s, "VacuumBlade", { phase = "open", pos = center, time = 1.5 })
			task.spawn(function()
				local stop = os.clock() + 1.5
				while os.clock() < stop and Combat.alive(s) do
					for _, t in enemiesOf(s) do
						local d = (t.hrp.Position - center).Magnitude
						if d <= 12 and d > 1.5 then
							pull(t, center, math.min(d * 3.5, 40), 4)
						end
					end
					task.wait(0.15)
				end
				echoFx(s, "VacuumBlade", { phase = "burst", pos = center })
				area(s, center, 7, function(t)
					Combat.echoHit(
						s,
						t,
						18,
						{ posture = 25, knockback = 45, lift = 20, heavy = true, ranged = true, from = center }
					)
				end)
			end)
		end,
	}

	B.HeavenSplitter = {
		run = function(s, arg)
			local dir = aimDirection(s, arg, 120)
			face(s, dir)
			local origin = s.hrp.Position
			local finish = origin + dir * 120
			echoFx(s, "HeavenSplitter", { from = origin, to = finish })
			task.delay(0.12, function()
				for _, t in enemiesOf(s) do
					local p = t.hrp.Position
					if
						distToSegment(
								p * Vector3.new(1, 0, 1),
								origin * Vector3.new(1, 0, 1),
								finish * Vector3.new(1, 0, 1)
							)
							<= 5
						and math.abs(p.Y - origin.Y) < 14
					then
						Combat.echoHit(s, t, 32, {
							posture = 40,
							lift = 60,
							knockback = 15,
							heavy = true,
							unparryable = true,
							ranged = true,
							from = origin,
						})
					end
				end
			end)
		end,
	}

	------------------------------------------------------------------------------------------
	-- Shadow (Umbra): vanishing, decoys, pulls and darkness.

	B.ShadeStep = {
		run = function(s, arg)
			local dir = moveDir(s, arg)
			local from = s.hrp.Position
			s.model:SetAttribute("InvulnerableUntil", now() + 0.55)
			echoFx(s, "ShadeStep", { phase = "sink", pos = groundAt(from) })
			local dest = from + dir * clearDistance(from, dir, 20)
			task.delay(0.25, function()
				if not Combat.alive(s) then
					return
				end
				teleport(s, CFrame.lookAt(dest, dest + dir))
				echoFx(s, "ShadeStep", { phase = "rise", pos = groundAt(dest) })
				area(s, dest, 4.5, function(t)
					Combat.echoHit(s, t, 6, { posture = 8, lift = 35, from = dest - dir })
				end)
			end)
		end,
	}

	B.UmbralFangs = {
		run = function(s)
			s.model:SetAttribute("UmbralUntil", now() + 4)
			s.model:SetAttribute("UmbralHits", 3)
			echoFx(s, "UmbralFangs", { phase = "on", pos = s.hrp.Position })
		end,
	}
	Combat.onLanded(function(attacker, target, move)
		if move.echo or not Combat.active(attacker.model, "UmbralUntil") then
			return
		end
		local left = attacker.model:GetAttribute("UmbralHits") or 0
		if left <= 0 or not Combat.alive(target) then
			return
		end
		attacker.model:SetAttribute("UmbralHits", if left > 1 then left - 1 else nil)
		task.wait(0.08)
		local dealt = Combat.hurt(attacker, target, 3)
		echoFx(attacker, "UmbralFangs", { phase = "tendril", pos = target.hrp.Position })
		Combat.fx("hit", attacker.model, target.model, target.hrp.Position, dealt, false)
	end)

	B.ShadeClone = {
		run = function(s)
			local decoy = makeDecoy(s, nil, 2.6)
			s.model:SetAttribute("InvisibleUntil", now() + 2)
			echoFx(s, "ShadeClone", { phase = "fade", pos = s.hrp.Position })
			if not decoy then
				return
			end
			local root = decoy:FindFirstChild("HumanoidRootPart") :: BasePart
			kit.addConstruct(s, decoy, "ShadeClone", root.Position)
			task.delay(0.7, function()
				if not decoy.Parent then
					return
				end
				Combat.fx("swing", decoy, nil, nil, nil, "Slash1")
				task.wait(0.15)
				for _, t in enemiesOf(s) do
					local offset = t.hrp.Position - root.Position
					if offset.Magnitude <= 8 and root.CFrame.LookVector:Dot(flat(offset)) > -0.2 then
						Combat.echoHit(s, t, 8, { posture = 10, knockback = 15, from = root.Position })
					end
				end
			end)
			task.delay(2.5, function()
				if decoy.Parent then
					echoFx(s, "ShadeClone", { phase = "vanish", pos = root.Position })
				end
			end)
		end,
	}

	B.VoidGrasp = {
		run = function(s, arg)
			local target = aim(s, arg, 30, 120)
			local spot = groundAt(if target then target.hrp.Position else s.hrp.Position + look(s) * 20)
			echoFx(s, "VoidGrasp", { phase = "hands", pos = spot })
			task.delay(0.35, function()
				if not Combat.alive(s) then
					return
				end
				local caught = sorted(s, spot + UP * 3, 5.5, 1)[1]
				if not caught then
					return
				end
				local invul = caught.model:GetAttribute("InvulnerableUntil")
				if typeof(invul) == "number" and now() < invul then
					Combat.fx("dodge", s.model, caught.model, caught.hrp.Position)
					return
				end
				echoFx(s, "VoidGrasp", { phase = "drag", from = caught.hrp.Position, to = s.hrp.Position })
				Combat.echoHit(s, caught, 8, { posture = 10, stun = 0.7, unblockable = true, ranged = true })
				local distance = (caught.hrp.Position - s.hrp.Position).Magnitude
				pull(caught, s.hrp.Position, math.clamp(distance * 2.6, 20, 80), 14)
			end)
		end,
	}

	B.NightfallVeil = {
		run = function(s)
			local center = s.hrp.Position
			echoFx(s, "NightfallVeil", { phase = "dome", pos = groundAt(center), time = 5, radius = 18 })
			task.spawn(function()
				local stop = os.clock() + 5
				while os.clock() < stop and s.model.Parent do
					area(s, center, 18, function(t)
						Combat.applyStatus(t, "Blind", 0.6, s)
					end)
					if (s.hrp.Position - center).Magnitude <= 18 then
						s.model:SetAttribute("NightfallBoostUntil", now() + 0.35)
					end
					task.wait(0.2)
				end
				echoFx(s, "NightfallVeil", { phase = "collapse", pos = groundAt(center) })
				if Combat.alive(s) then
					area(s, center, 18, function(t)
						Combat.echoHit(
							s,
							t,
							12,
							{ posture = 15, knockback = 20, unblockable = true, ranged = true, from = center }
						)
					end)
				end
			end)
		end,
	}

	local function blinkStrike(s, t, amount: number, opts)
		local back = flat(t.hrp.CFrame.LookVector)
		local dest = t.hrp.Position - back * 3
		echoFx(s, "EclipseRend", { phase = "blink", from = s.hrp.Position, to = dest })
		teleport(s, CFrame.lookAt(dest, t.hrp.Position))
		Combat.echoHit(s, t, amount, opts)
	end

	B.EclipseRend = {
		check = function(s)
			return #sorted(s, s.hrp.Position, 30, 1) > 0, "No target in range"
		end,
		run = function(s)
			local targets = sorted(s, s.hrp.Position, 30, 5)
			s.model:SetAttribute("InvulnerableUntil", now() + 0.15 * #targets + 0.3)
			for i, t in targets do
				task.delay(0.15 * (i - 1), function()
					if Combat.alive(s) and Combat.alive(t) then
						blinkStrike(
							s,
							t,
							18,
							{ status = "Silence", posture = 15, knockback = 10, from = t.hrp.Position + look(t) }
						)
					end
				end)
			end
		end,
	}

	B.Eclipse = {
		check = function(s)
			return #sorted(s, s.hrp.Position, 40, 1) > 0, "No target in range"
		end,
		run = function(s)
			local targets = sorted(s, s.hrp.Position, 40, 6)
			local start = s.hrp.Position
			echoFx(s, "Eclipse", { phase = "moonrise", pos = start })
			s.model:SetAttribute("InvulnerableUntil", now() + 0.18 * #targets + 1)
			for i, t in targets do
				task.delay(0.18 * (i - 1), function()
					if Combat.alive(s) and Combat.alive(t) then
						blinkStrike(s, t, 6, { posture = 10, unparryable = true, from = t.hrp.Position + look(t) })
					end
				end)
			end
			task.delay(0.18 * #targets + 0.1, function()
				local last = targets[#targets]
				local spot = groundAt(if last and Combat.alive(last) then last.hrp.Position else s.hrp.Position)
				echoFx(s, "Eclipse", { phase = "moonfall", pos = spot })
				task.wait(0.6)
				if not Combat.alive(s) then
					return
				end
				area(s, spot + UP * 3, 8, function(t)
					Combat.echoHit(s, t, 30, {
						posture = 40,
						heavy = true,
						knockback = 50,
						lift = 40,
						stun = 1.2,
						unblockable = true,
						unparryable = true,
						ranged = true,
						from = spot,
					})
				end)
				area(s, spot, 40, function(t)
					Combat.applyStatus(t, "Blind", 2, s)
				end)
			end)
		end,
	}

	------------------------------------------------------------------------------------------
	-- Earth (Terra): pillars, boulders, stone armour.

	B.StonePillar = {
		run = function(s, arg)
			local target = aim(s, arg, 25, 120)
			local spot = groundAt(if target then target.hrp.Position else s.hrp.Position + look(s) * 12)
			echoFx(s, "StonePillar", { phase = "crack", from = groundAt(s.hrp.Position), to = spot })
			task.delay(0.35, function()
				if not Combat.alive(s) then
					return
				end
				echoFx(s, "StonePillar", { phase = "pillar", pos = spot })
				area(s, spot + UP * 3, 4.5, function(t)
					Combat.echoHit(
						s,
						t,
						8,
						{ posture = 12, lift = 65, knockback = 4, ranged = true, from = spot - look(s) }
					)
				end)
			end)
		end,
	}

	B.RockToss = {
		run = function(s, arg)
			local dir = aimDirection(s, arg, 35)
			face(s, dir)
			projectile(s, "RockToss", s.hrp.Position + Vector3.new(0, 2, 0), dir, 65, 35, 4, function(o, t, pos)
				Combat.echoHit(o, t, 9, {
					posture = 15,
					knockback = 35,
					lift = 15,
					stun = 0.8,
					ranged = true,
					projectile = true,
					from = pos,
				})
				return true
			end, function(o, pos)
				echoFx(o, "RockToss", { phase = "smash", pos = pos })
			end)
		end,
	}

	B.QuakeStomp = {
		run = function(s)
			local center = s.hrp.Position
			echoFx(s, "QuakeStomp", { pos = groundAt(center) })
			area(s, center, 15, function(t)
				Combat.echoHit(
					s,
					t,
					10,
					{ status = "Fracture", posture = 20, stun = 0.6, knockback = 15, lift = 8, from = center }
				)
			end)
		end,
	}

	B.GraniteSkin = {
		run = function(s)
			s.model:SetAttribute("GraniteUntil", now() + 4)
			s.armorUntil = math.max(s.armorUntil, now() + 4)
			echoFx(s, "GraniteSkin", { pos = s.hrp.Position })
		end,
	}

	B.TectonicRift = {
		run = function(s, arg)
			local dir = aimDirection(s, arg, 50)
			face(s, dir)
			local origin = s.hrp.Position
			local finish = origin + dir * clearDistance(origin, dir, 50)
			drive(s, { { v = dir * 33, t = 0.45 }, { v = Vector3.zero, t = 0.05 } })
			echoFx(s, "TectonicRift", { from = groundAt(origin), to = groundAt(finish) })
			kit.breakConstructs(s, origin, finish, 5)
			sweepPath(s, { origin, finish }, 0.6, 3.8, function(t)
				Combat.echoHit(s, t, 14, { status = "Root", posture = 18, lift = 28, from = origin })
			end)
		end,
	}

	B.EarthenPrison = {
		check = function(s, arg)
			return aim(s, arg, 25, 140) ~= nil, "No target in range"
		end,
		run = function(s, arg)
			local t = aim(s, arg, 25, 140)
			if not t then
				return
			end
			local invul = t.model:GetAttribute("InvulnerableUntil")
			if typeof(invul) == "number" and now() < invul then
				Combat.fx("dodge", s.model, t.model, t.hrp.Position)
				return
			end
			echoFx(s, "EarthenPrison", { phase = "dome", pos = groundAt(t.hrp.Position) })
			Combat.stun(t, 2)
			Combat.applyStatus(t, "Root", 2, s)
			task.delay(2, function()
				if Combat.alive(t) and Combat.alive(s) then
					echoFx(s, "EarthenPrison", { phase = "burst", pos = t.hrp.Position })
					Combat.echoHit(s, t, 16, {
						posture = 25,
						knockback = 40,
						lift = 30,
						unblockable = true,
						unparryable = true,
						ranged = true,
						from = t.hrp.Position + look(s),
					})
				end
			end)
		end,
	}

	B.MountainsWrath = {
		run = function(s, arg)
			local target = aim(s, arg, 40, 160)
			local spot = groundAt(if target then target.hrp.Position else s.hrp.Position + look(s) * 15)
			echoFx(s, "MountainsWrath", { phase = "rise", pos = spot })
			task.delay(0.9, function()
				if not Combat.alive(s) then
					return
				end
				echoFx(s, "MountainsWrath", { phase = "slam", pos = spot })
				area(s, spot + UP * 3, 20, function(t)
					Combat.echoHit(s, t, 34, {
						posture = 40,
						heavy = true,
						stun = 1.3,
						knockback = 60,
						lift = 45,
						unparryable = true,
						ranged = true,
						from = spot,
					})
				end)
				echoFx(s, "MountainsWrath", { phase = "rain", pos = spot, time = 3 })
			end)
		end,
	}

	------------------------------------------------------------------------------------------
	-- Rift (neutral): grapples, afterimages, shields and mirrors.

	B.GrappleHook = {
		run = function(s, arg)
			local dir = aimDirection(s, arg, 30)
			face(s, dir)
			local origin = s.hrp.Position + Vector3.new(0, 0.8, 0)
			local reach = clearDistance(origin, dir, 30)
			local best, bestAlong = nil, math.huge
			for _, t in enemiesOf(s) do
				local offset = t.hrp.Position - origin
				local along = offset:Dot(dir)
				if along > 0 and along <= reach and (offset - dir * along).Magnitude < 3 and along < bestAlong then
					best, bestAlong = t, along
				end
			end
			if best then
				echoFx(s, "GrappleHook", { from = origin, to = best.hrp.Position, pull = true })
				Combat.echoHit(s, best, 8, { posture = 10, stun = 0.6, unblockable = true, ranged = true })
				pull(best, s.hrp.Position, 34, 10)
				return
			end
			local hit = workspace:Raycast(origin, dir * 30, kit.rayParams())
			if hit then
				local distance = math.max((hit.Position - origin).Magnitude - 3, 0)
				echoFx(s, "GrappleHook", { from = origin, to = hit.Position })
				drive(s, { { v = dir * 70 + UP * 8, t = distance / 70 }, { v = Vector3.zero, t = 0.05 } })
			else
				echoFx(s, "GrappleHook", { from = origin, to = origin + dir * 30, miss = true })
			end
		end,
	}

	B.Afterimage = {
		run = function(s)
			s.model:SetAttribute("AfterimageUntil", now() + 3)
			echoFx(s, "Afterimage", { phase = "ready", pos = s.hrp.Position })
		end,
	}
	kit.onDodge(function(s)
		if not Combat.active(s.model, "AfterimageUntil") then
			return
		end
		s.model:SetAttribute("AfterimageUntil", nil)
		local decoy = makeDecoy(s, Data.Elements.Rift.color, 3.2)
		if not decoy then
			return
		end
		local root = decoy:FindFirstChild("HumanoidRootPart") :: BasePart
		local spot = root.Position
		kit.addConstruct(s, decoy, "Afterimage", spot)
		local stop = os.clock() + 3
		while os.clock() < stop and decoy.Parent do
			if #sorted(s, spot, 5, 1) > 0 then
				echoFx(s, "Afterimage", { phase = "explode", pos = spot })
				decoy:Destroy()
				area(s, spot, 7, function(t)
					Combat.echoHit(s, t, 14, { posture = 20, stun = 0.8, knockback = 30, ranged = true, from = spot })
				end)
				return
			end
			task.wait(0.1)
		end
		if decoy.Parent then
			echoFx(s, "Afterimage", { phase = "fade", pos = spot })
		end
	end)

	B.RiftBarrier = {
		run = function(s)
			s.model:SetAttribute("Shield", 25)
			s.model:SetAttribute("ShieldUntil", now() + 4)
			echoFx(s, "RiftBarrier", { pos = s.hrp.Position })
		end,
	}

	B.MirrorGuard = {
		run = function(s)
			s.model:SetAttribute("CounterKind", "MirrorGuard")
			s.model:SetAttribute("CounterUntil", now() + 1.2)
			echoFx(s, "MirrorGuard", { pos = s.hrp.Position })
			task.delay(1.25, function()
				if s.model:GetAttribute("CounterKind") == "MirrorGuard" then
					s.model:SetAttribute("CounterKind", nil)
				end
			end)
		end,
	}
end
