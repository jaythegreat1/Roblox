-- Echoes: the superpowers. Loadouts, cooldowns, casting, the Surge meter, Rift Burst, and what
-- every Echo actually does. All damage goes through Combat, so blocks, parries, dodges, Surge
-- and statuses follow the same rules as sword hits.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Shared.Combat.Echoes)
local Combat = require(script.Parent.Combat)

local Echoes = {}

local moveRemote: RemoteEvent
local effects: Folder
local projectileKey = 0
local pillars: { [Model]: BasePart } = {}

local FLAT = Vector3.new(1, 0, 1)

local function now()
	return Combat.now()
end

local function flat(v: Vector3): Vector3
	local f = v * FLAT
	return if f.Magnitude > 0.001 then f.Unit else Vector3.new(0, 0, -1)
end

local function enemiesOf(s)
	local list = {}
	for _, other in Combat.all() do
		if other ~= s and Combat.alive(other) then
			table.insert(list, other)
		end
	end
	return list
end

local function rayParams(): RaycastParams
	local ignore = { effects }
	for model in Combat.all() do
		table.insert(ignore, model)
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return params
end

-- How far you can travel from `from` along `dir` before hitting a wall (minus a margin).
local function clearDistance(from: Vector3, dir: Vector3, distance: number): number
	local hit = workspace:Raycast(from, dir * distance, rayParams())
	return if hit then math.max((hit.Position - from).Magnitude - 2, 0) else distance
end

local function groundAt(pos: Vector3): Vector3
	local hit = workspace:Raycast(pos + Vector3.new(0, 30, 0), Vector3.new(0, -200, 0), rayParams())
	return if hit then hit.Position else pos - Vector3.new(0, 3, 0)
end

local function distToSegment(p: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local len2 = ab:Dot(ab)
	local t = if len2 > 0 then math.clamp((p - a):Dot(ab) / len2, 0, 1) else 0
	return (p - (a + ab * t)).Magnitude
end

-- Who an Echo aims at: your lock-on target if it is valid, else the nearest enemy in front.
local function aim(s, arg, range: number, arc: number?)
	local wanted = typeof(arg) == "table" and arg.target or nil
	if typeof(wanted) == "Instance" and wanted:IsA("Model") then
		local t = Combat.state(wanted)
		if t and t ~= s and Combat.alive(t) and (t.hrp.Position - s.hrp.Position).Magnitude <= range then
			return t
		end
	end
	local best, bestDist = nil, math.huge
	for _, t in enemiesOf(s) do
		local d = (t.hrp.Position - s.hrp.Position).Magnitude
		if d <= range and d < bestDist and Combat.facing(s.hrp, t.hrp.Position, arc or 90) then
			best, bestDist = t, d
		end
	end
	return best
end

local function aimDirection(s, arg, range: number): Vector3
	local t = aim(s, arg, range, 70)
	return if t then flat(t.hrp.Position - s.hrp.Position) else flat(s.hrp.CFrame.LookVector)
end

-- Players own their character's physics, so the server never moves them directly (that
-- fights their own movement and rubber-bands); it asks their client to do it instead.
local function face(s, dir: Vector3)
	local player = Players:GetPlayerFromCharacter(s.model)
	if player then
		moveRemote:FireClient(player, { { face = flat(dir), t = 0 } })
	else
		s.hrp.CFrame = CFrame.lookAt(s.hrp.Position, s.hrp.Position + flat(dir))
	end
end

local function teleport(s, cf: CFrame)
	local player = Players:GetPlayerFromCharacter(s.model)
	if player then
		moveRemote:FireClient(player, { { cf = cf, t = 0 } })
	else
		s.model:PivotTo(cf)
	end
end

local function echoFx(s, id: string, data)
	data.id = id
	Combat.fx("echo", s.model, data.target, data.pos, nil, data)
end

-- Moves the caster through velocity segments. Players move their own character (smooth on
-- their screen); AI fighters are moved here.
local function drive(s, segments: { { v: Vector3, t: number } }): number
	local total = 0
	for _, seg in segments do
		total += seg.t
	end
	local player = Players:GetPlayerFromCharacter(s.model)
	if player then
		moveRemote:FireClient(player, segments)
	else
		task.spawn(function()
			for _, seg in segments do
				local stop = os.clock() + seg.t
				while os.clock() < stop and s.model.Parent do
					s.hrp.AssemblyLinearVelocity = seg.v
					RunService.Heartbeat:Wait()
				end
			end
		end)
	end
	return total
end

-- Hits along a planned route (a list of points travelled in `seconds`) instead of the
-- caster's live position, which the server only sees a moment late for players.
local function sweepPath(s, points: { Vector3 }, seconds: number, radius: number, onHit: (any) -> ())
	local lengths, total = {}, 0
	for i = 1, #points - 1 do
		lengths[i] = (points[i + 1] - points[i]).Magnitude
		total += lengths[i]
	end
	local function at(distance: number): Vector3
		for i = 1, #points - 1 do
			if distance <= lengths[i] or i == #points - 1 then
				return points[i]:Lerp(
					points[i + 1],
					if lengths[i] > 0 then math.clamp(distance / lengths[i], 0, 1) else 1
				)
			end
			distance -= lengths[i]
		end
		return points[#points]
	end
	local hit = {}
	task.spawn(function()
		local start = os.clock()
		local last = points[1]
		while Combat.alive(s) do
			local elapsed = os.clock() - start
			local current = at(total * math.clamp(elapsed / seconds, 0, 1))
			for _, t in enemiesOf(s) do
				if not hit[t] and distToSegment(t.hrp.Position, last, current) <= radius then
					hit[t] = true
					onHit(t)
				end
			end
			last = current
			if elapsed > seconds + 0.1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

-- A travelling hit simulated on the server; clients draw the same path from the same data.
local function projectile(
	s,
	id: string,
	origin: Vector3,
	dir: Vector3,
	speed: number,
	range: number,
	radius: number,
	onHit,
	onEnd
)
	projectileKey += 1
	local key = projectileKey
	local travel = clearDistance(origin, dir, range)
	echoFx(s, id, { phase = "fly", key = key, origin = origin, dir = dir, speed = speed, range = travel })
	task.spawn(function()
		local start = os.clock()
		local hit = {}
		local pos = origin
		while true do
			local d = math.min((os.clock() - start) * speed, travel)
			pos = origin + dir * d
			for _, t in enemiesOf(s) do
				if not hit[t] and (t.hrp.Position - pos).Magnitude <= radius then
					hit[t] = true
					if onHit(t, pos) then
						echoFx(s, id, { phase = "end", key = key, pos = pos })
						if onEnd then
							onEnd(pos)
						end
						return
					end
				end
			end
			if d >= travel then
				break
			end
			RunService.Heartbeat:Wait()
		end
		echoFx(s, id, { phase = "end", key = key, pos = pos })
		if onEnd then
			onEnd(pos)
		end
	end)
end

local function area(s, center: Vector3, radius: number, fn: (any) -> ())
	for _, t in enemiesOf(s) do
		if (t.hrp.Position - center).Magnitude <= radius then
			fn(t)
		end
	end
end

-- A lingering zone that keeps applying Burn to enemies inside it.
local function burningGround(s, center: Vector3, radius: number, seconds: number)
	task.spawn(function()
		local stop = os.clock() + seconds
		while os.clock() < stop do
			area(s, center, radius, function(t)
				if math.abs(t.hrp.Position.Y - center.Y) < 8 then
					Combat.applyStatus(t, "Burn", nil, s)
				end
			end)
			task.wait(0.5)
		end
	end)
end

-- Echo behaviours ------------------------------------------------------------------------
-- check(s, arg) (optional) refuses a cast before any cooldown is spent, e.g. no target.

local Behaviour = {}

Behaviour.EmberDash = {
	run = function(s, arg)
		local dir = aimDirection(s, arg, 18)
		face(s, dir)
		local start = s.hrp.Position
		local distance = clearDistance(start, dir, 18)
		local finish = start + dir * distance
		drive(s, { { v = dir * (distance / 0.25), t = 0.25 }, { v = Vector3.zero, t = 0.05 } })
		echoFx(s, "EmberDash", { from = start, to = finish })
		sweepPath(s, { start, finish }, 0.25, 4.5, function(t)
			Combat.echoHit(s, t, 8, { status = "Burn", posture = 10, knockback = 12 })
		end)
		-- The flame trail Burns anyone who steps on it for 3 s.
		task.spawn(function()
			local stop = os.clock() + 3
			while os.clock() < stop do
				for _, t in enemiesOf(s) do
					if distToSegment(t.hrp.Position * FLAT, start * FLAT, finish * FLAT) < 2.5 then
						Combat.applyStatus(t, "Burn", nil, s)
					end
				end
				task.wait(0.25)
			end
		end)
	end,
}

Behaviour.FlameFang = {
	run = function(s, arg)
		local dir = aimDirection(s, arg, 40)
		face(s, dir)
		projectile(s, "FlameFang", s.hrp.Position + Vector3.new(0, 0.6, 0), dir, 85, 40, 3.5, function(t, pos)
			Combat.echoHit(s, t, 7, { status = "Burn", posture = 10, knockback = 18, ranged = true, from = pos })
			return true
		end)
	end,
}

Behaviour.BlazeSpiral = {
	run = function(s)
		drive(s, { { v = Vector3.new(0, 40, 0), t = 0.22 } })
		local center = s.hrp.Position
		echoFx(s, "BlazeSpiral", { pos = center })
		area(s, center, 8, function(t)
			Combat.echoHit(
				s,
				t,
				11,
				{ status = "Burn", posture = 15, knockback = 8, lift = 60, stun = 0.8, from = center }
			)
		end)
	end,
}

Behaviour.InfernoCage = {
	run = function(s)
		local center = groundAt(s.hrp.Position)
		local radius = 14
		echoFx(s, "InfernoCage", { pos = center, radius = radius, time = 4 })
		task.spawn(function()
			local lastHit = {}
			local stop = os.clock() + 4
			while os.clock() < stop do
				for _, t in enemiesOf(s) do
					local offset = (t.hrp.Position - center) * FLAT
					local d = offset.Magnitude
					if math.abs(d - radius) < 2 and os.clock() - (lastHit[t] or 0) > 0.7 then
						lastHit[t] = os.clock()
						-- Thrown back to whichever side they came from.
						local inside = d < radius
						local from = if inside then center + flat(offset) * (radius + 20) else center
						Combat.echoHit(s, t, 8, {
							status = "Burn",
							posture = 10,
							knockback = 40,
							unblockable = true,
							from = from,
						})
					end
				end
				task.wait(0.1)
			end
		end)
	end,
}

Behaviour.SolarFlare = {
	run = function(s, arg)
		local dir = aimDirection(s, arg, 40)
		face(s, dir)
		drive(s, { { v = Vector3.new(0, 30, 0) + dir * -6, t = 0.2 } })
		local function boom(pos: Vector3)
			echoFx(s, "SolarFlare", { phase = "boom", pos = pos })
			area(s, pos, 10, function(t)
				Combat.echoHit(s, t, 15, { posture = 20, knockback = 35, ranged = true, from = pos })
				Combat.applyStatus(t, "Blind", 1.5, s)
			end)
		end
		projectile(s, "SolarFlare", s.hrp.Position + Vector3.new(0, 2, 0), dir, 60, 40, 3.5, function()
			return true
		end, boom)
	end,
}

Behaviour.MeteorBrand = {
	run = function(s, arg)
		local t = aim(s, arg, 40, 120)
		local center = groundAt(if t then t.hrp.Position else s.hrp.Position + flat(s.hrp.CFrame.LookVector) * 18)
		echoFx(s, "MeteorBrand", { phase = "mark", pos = center })
		local dealt = {}
		for i = 1, 5 do
			task.delay(0.6 * i, function()
				if not s.model.Parent then
					return
				end
				local angle = math.random() * math.pi * 2
				local impact = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * math.random() * 5
				echoFx(s, "MeteorBrand", { phase = "impact", pos = impact })
				area(s, impact + Vector3.new(0, 3, 0), 7, function(target)
					local amount = math.min(4, 18 - (dealt[target] or 0))
					if amount > 0 then
						dealt[target] = (dealt[target] or 0) + amount
						Combat.echoHit(s, target, amount, {
							status = "Burn",
							posture = 8,
							knockback = 15,
							lift = 25,
							ranged = true,
							from = impact,
						})
					end
				end)
			end)
		end
	end,
}

Behaviour.PhoenixDescent = {
	run = function(s, arg)
		local start = s.hrp.Position
		local rise = 55
		local t = aim(s, arg, 50, 160)
		local landing = groundAt(if t then t.hrp.Position else start + flat(s.hrp.CFrame.LookVector) * 20)
			+ Vector3.new(0, 3, 0)
		local apex = start + Vector3.new(0, rise, 0)
		s.model:SetAttribute("InvulnerableUntil", now() + 1.35)
		s.armorUntil = now() + 1.6
		echoFx(s, "PhoenixDescent", { phase = "rise", pos = start })
		drive(s, {
			{ v = Vector3.new(0, rise / 0.5, 0), t = 0.5 },
			{ v = Vector3.zero, t = 0.35 },
			{ v = (landing - apex) / 0.35, t = 0.35 },
			{ v = Vector3.zero, t = 0.1 },
		})
		task.delay(0.85, function()
			echoFx(s, "PhoenixDescent", { phase = "dive", pos = landing })
		end)
		task.delay(1.22, function()
			if not Combat.alive(s) then
				return
			end
			-- The dive always lands on the marked spot.
			local center = landing
			echoFx(s, "PhoenixDescent", { phase = "boom", pos = groundAt(center) })
			area(s, center, 20, function(target)
				Combat.echoHit(s, target, 35, {
					status = "Burn",
					posture = 40,
					knockback = 70,
					lift = 55,
					stun = 1.3,
					heavy = true,
					unparryable = true,
					ranged = true,
					from = center,
				})
			end)
			burningGround(s, groundAt(center), 14, 6)
		end)
	end,
}

Behaviour.FlashStep = {
	run = function(s, arg)
		local from = s.hrp.Position
		local t = aim(s, arg, 40, 360)
		local dest, lookAt
		if t and typeof(arg) == "table" and arg.target == t.model then
			-- Behind your lock-on target.
			local back = flat(t.hrp.CFrame.LookVector)
			dest = t.hrp.Position - back * 3.5
			lookAt = t.hrp.Position
		else
			local dir = aimDirection(s, arg, 25)
			dest = from + dir * clearDistance(from, dir, 25)
			lookAt = dest + dir
		end
		s.model:SetAttribute("InvulnerableUntil", now() + 0.2)
		teleport(s, CFrame.lookAt(dest, Vector3.new(lookAt.X, dest.Y, lookAt.Z)))
		echoFx(s, "FlashStep", { from = from, to = dest })
		for _, e in enemiesOf(s) do
			if distToSegment(e.hrp.Position, from, dest) < 3.5 then
				Combat.echoHit(s, e, 6, { posture = 8, ranged = true, unparryable = true, from = from })
			end
		end
		s.empowerUntil = now() + 1.2
		s.empowerStatus = "Shock"
	end,
}

Behaviour.VoltLance = {
	run = function(s, arg)
		local dir = aimDirection(s, arg, 45)
		face(s, dir)
		local origin = s.hrp.Position + Vector3.new(0, 1, 0)
		local reach = clearDistance(origin, dir, 45)
		local best, bestAlong = nil, math.huge
		for _, t in enemiesOf(s) do
			local offset = t.hrp.Position - origin
			local along = offset:Dot(dir)
			if along > 0 and along <= reach and (offset - dir * along).Magnitude < 3 and along < bestAlong then
				best, bestAlong = t, along
			end
		end
		local finish = if best then best.hrp.Position else origin + dir * reach
		echoFx(s, "VoltLance", { from = origin, to = finish })
		if best then
			Combat.echoHit(s, best, 7, { status = "Mark", posture = 10, knockback = 10, ranged = true, from = origin })
		end
	end,
}

Behaviour.Thunderclap = {
	run = function(s)
		local center = s.hrp.Position
		echoFx(s, "Thunderclap", { pos = groundAt(center) })
		area(s, center, 12, function(t)
			Combat.echoHit(s, t, 10, { status = "Shock", posture = 15, knockback = 10, lift = 30, from = center })
		end)
	end,
}

Behaviour.ArcChain = {
	check = function(s, arg)
		return aim(s, arg, 15, 140) ~= nil, "No target in range"
	end,
	run = function(s, arg)
		local first = aim(s, arg, 15, 140)
		if not first then
			return
		end
		face(s, first.hrp.Position - s.hrp.Position)
		local chain = { first }
		local seen = { [first] = true }
		while #chain < 4 do
			local last = chain[#chain]
			local nextTarget, bestDist = nil, 15
			for _, t in enemiesOf(s) do
				local d = (t.hrp.Position - last.hrp.Position).Magnitude
				if not seen[t] and d <= bestDist then
					nextTarget, bestDist = t, d
				end
			end
			if not nextTarget then
				break
			end
			seen[nextTarget] = true
			table.insert(chain, nextTarget)
		end
		local points = { s.hrp.Position + Vector3.new(0, 1, 0) }
		for i, t in chain do
			table.insert(points, t.hrp.Position)
			task.delay(0.08 * (i - 1), function()
				Combat.echoHit(s, t, if i == 1 then 9 else 6, {
					status = "Shock",
					posture = 10,
					ranged = true,
					from = points[i],
				})
			end)
		end
		echoFx(s, "ArcChain", { points = points })
	end,
}

Behaviour.RaijuRush = {
	run = function(s, arg)
		local base = aimDirection(s, arg, 30)
		face(s, base)
		local dirs = {
			(CFrame.Angles(0, math.rad(35), 0) * CFrame.new(Vector3.zero, base)).LookVector,
			(CFrame.Angles(0, math.rad(-35), 0) * CFrame.new(Vector3.zero, base)).LookVector,
			base,
		}
		local segments = {}
		local points = { s.hrp.Position }
		for _, d in dirs do
			local here = points[#points]
			local length = clearDistance(here, flat(d), 15)
			table.insert(points, here + flat(d) * length)
			table.insert(segments, { v = flat(d) * (length / 0.16), t = 0.16 })
		end
		table.insert(segments, { v = Vector3.zero, t = 0.05 })
		drive(s, segments)
		echoFx(s, "RaijuRush", { pos = s.hrp.Position })
		for i = 1, 3 do
			task.delay(0.16 * (i - 1), function()
				sweepPath(s, { points[i], points[i + 1] }, 0.16, 4.5, function(t)
					Combat.echoHit(s, t, 5, {
						posture = 8,
						lift = if i == 3 then 50 else nil,
						knockback = if i == 3 then 15 else nil,
						status = if i == 3 then "Shock" else nil,
					})
				end)
			end)
		end
	end,
}

Behaviour.StormPillar = {
	run = function(s)
		local old = pillars[s.model]
		if old then
			old:Destroy()
		end
		local base = groundAt(s.hrp.Position + flat(s.hrp.CFrame.LookVector) * 4)
		local rod = Instance.new("Part")
		rod.Name = "StormPillar"
		rod.Anchored = true
		rod.CanCollide = true
		rod.Material = Enum.Material.Neon
		rod.Color = Color3.fromRGB(120, 210, 255)
		rod.Size = Vector3.new(1, 9, 1)
		rod.CFrame = CFrame.new(base + Vector3.new(0, 4.5, 0))
		rod.Parent = effects
		local cloud = Instance.new("Part")
		cloud.Name = "Cloud"
		cloud.Anchored = true
		cloud.CanCollide = false
		cloud.CanQuery = false
		cloud.Shape = Enum.PartType.Ball
		cloud.Material = Enum.Material.SmoothPlastic
		cloud.Color = Color3.fromRGB(50, 55, 75)
		cloud.Transparency = 0.25
		cloud.Size = Vector3.new(12, 12, 12)
		cloud.CFrame = CFrame.new(base + Vector3.new(0, 13, 0))
		cloud.Parent = rod
		pillars[s.model] = rod
		echoFx(s, "StormPillar", { phase = "rise", pos = base })
		local top = base + Vector3.new(0, 9, 0)
		local dealt = {}
		task.spawn(function()
			for _ = 1, 8 do
				task.wait(1)
				if not rod.Parent then
					return
				end
				local best, bestDist = nil, 25
				for _, t in enemiesOf(s) do
					local d = (t.hrp.Position - base).Magnitude
					if d <= bestDist and (dealt[t] or 0) < 18 then
						best, bestDist = t, d
					end
				end
				if best then
					dealt[best] = (dealt[best] or 0) + 3
					echoFx(s, "StormPillar", { phase = "strike", from = top, to = best.hrp.Position })
					Combat.echoHit(s, best, 3, { status = "Shock", posture = 5, ranged = true, from = base })
				end
			end
			rod:Destroy()
			if pillars[s.model] == rod then
				pillars[s.model] = nil
			end
		end)
	end,
}

Behaviour.RaijinsWrath = {
	run = function(s)
		s.armorUntil = now() + 1
		drive(s, { { v = Vector3.new(0, 30, 0), t = 0.35 }, { v = Vector3.zero, t = 0.9 } })
		echoFx(s, "RaijinsWrath", { phase = "storm", pos = s.hrp.Position, time = 5.3 })
		local opts = { status = "Shock", posture = 4, ranged = true, unparryable = true, stun = 0.2 }
		for i = 1, 10 do
			task.delay(0.5 * i, function()
				if not Combat.alive(s) then
					return
				end
				area(s, s.hrp.Position, 40, function(t)
					echoFx(s, "RaijinsWrath", { phase = "bolt", pos = t.hrp.Position })
					Combat.echoHit(s, t, 2.4, opts)
				end)
			end)
		end
		task.delay(5.4, function()
			if not Combat.alive(s) then
				return
			end
			area(s, s.hrp.Position, 40, function(t)
				echoFx(s, "RaijinsWrath", { phase = "final", pos = t.hrp.Position })
				Combat.echoHit(s, t, 10, {
					status = "Shock",
					posture = 30,
					lift = 45,
					knockback = 10,
					heavy = true,
					ranged = true,
					unparryable = true,
					from = t.hrp.Position + Vector3.new(0, 20, 0),
				})
			end)
		end)
	end,
}

Behaviour.RiftBlink = {
	run = function(s, arg)
		local dir = if typeof(arg) == "table"
				and typeof(arg.dir) == "Vector3"
				and (arg.dir * FLAT).Magnitude > 0.1
			then flat(arg.dir)
			else flat(s.hrp.CFrame.LookVector)
		local from = s.hrp.Position
		local dest = from + dir * clearDistance(from, dir, 10)
		teleport(s, s.hrp.CFrame - from + dest)
		echoFx(s, "RiftBlink", { from = from, to = dest })
	end,
}

Behaviour.SecondWind = {
	run = function(s)
		local started = now()
		echoFx(s, "SecondWind", { phase = "start", pos = s.hrp.Position })
		task.spawn(function()
			for _ = 1, 12 do
				task.wait(0.25)
				if not Combat.alive(s) then
					return
				end
				if s.lastDamageAt > started then
					echoFx(s, "SecondWind", { phase = "cancel", pos = s.hrp.Position })
					return
				end
				s.humanoid.Health = math.min(s.humanoid.Health + 1, s.humanoid.MaxHealth)
			end
			echoFx(s, "SecondWind", { phase = "done", pos = s.hrp.Position })
		end)
	end,
}

Behaviour.BattleCry = {
	run = function(s)
		s.model:SetAttribute("BattleCryUntil", now() + 5)
		echoFx(s, "BattleCry", { pos = s.hrp.Position })
		area(s, s.hrp.Position, 6, function(t)
			Combat.knockback(t, s.hrp.Position, 40, 10)
		end)
	end,
}

Behaviour.IronWill = {
	run = function(s)
		Combat.clearStatuses(s)
		s.armorUntil = math.max(s.armorUntil, now() + 1)
		echoFx(s, "IronWill", { pos = s.hrp.Position })
	end,
}

-- Loadouts --------------------------------------------------------------------------------

local function refreshAttunement(model: Model)
	local counts = {}
	local attuned = false
	for i = 1, 3 do
		local e = Data.get(model:GetAttribute("Echo" .. i))
		if e and e.element ~= "Rift" then
			counts[e.element] = (counts[e.element] or 0) + 1
			attuned = attuned or counts[e.element] >= 2
		end
	end
	model:SetAttribute("Attuned", attuned or nil)
end

-- Copies a player's saved loadout (or the default) onto a freshly spawned fighter.
function Echoes.setup(model: Model, player: Player?, loadout: { string }?)
	for i, slot in Data.Slots do
		local saved = player and player:GetAttribute(slot)
		local id = if Data.fits(saved, slot) then saved else (loadout or Data.DefaultLoadout)[i]
		model:SetAttribute(slot, id)
	end
	refreshAttunement(model)
end

local function notify(s, text: string)
	local player = Players:GetPlayerFromCharacter(s.model)
	if player then
		Combat.notice(player, text)
	end
end

local function onLoadout(s, arg)
	if typeof(arg) ~= "table" then
		return
	end
	local slot, id = arg.slot, arg.id
	if typeof(slot) ~= "string" or not Data.fits(id, slot) then
		return
	end
	-- The master plan only allows loadout changes out of combat.
	if now() - s.lastDamageAt < 3 then
		notify(s, "Can't change Echoes while taking hits")
		return
	end
	local model = s.model
	local player = Players:GetPlayerFromCharacter(model)
	-- Putting an Echo that is already in another slot swaps the two.
	local previous = model:GetAttribute(slot)
	for _, other in Data.Slots do
		if other ~= slot and model:GetAttribute(other) == id then
			model:SetAttribute(other, previous)
			if player then
				player:SetAttribute(other, previous)
			end
		end
	end
	model:SetAttribute(slot, id)
	if player then
		player:SetAttribute(slot, id)
	end
	refreshAttunement(model)
end

-- Casting ---------------------------------------------------------------------------------

local function cooldownKey(id: string): string
	return "CD_" .. id
end

local function ready(s, id: string): boolean
	local at = s.model:GetAttribute(cooldownKey(id))
	return typeof(at) ~= "number" or now() >= at
end

local function riftBurst(s)
	local t = now()
	local surge = s.model:GetAttribute("Surge") or 0
	local burstUntil = s.model:GetAttribute("BurstUntil")
	if surge < Data.Surge.riftBurstCost or typeof(burstUntil) ~= "number" or t > burstUntil then
		return
	end
	if not ready(s, "RiftBurst") then
		return
	end
	s.model:SetAttribute(cooldownKey("RiftBurst"), t + Data.Surge.riftBurstCooldown)
	s.model:SetAttribute("Surge", surge - Data.Surge.riftBurstCost)
	s.model:SetAttribute("StunnedUntil", nil)
	s.model:SetAttribute("BurstUntil", nil)
	s.model:SetAttribute("InvulnerableUntil", t + 0.4)
	s.chainCount = 0
	s.busyUntil = t + 0.4
	Combat.fx("swing", s.model, nil, nil, nil, "RiftBurst")
	echoFx(s, "RiftBurst", { pos = s.hrp.Position })
	area(s, s.hrp.Position, 10, function(target)
		Combat.knockback(target, s.hrp.Position, 70, 25)
		Combat.stun(target, 0.5)
	end)
end

local function cast(s, arg)
	local slot = if typeof(arg) == "table" then arg.slot else arg
	if slot == "RiftBurst" then
		riftBurst(s)
		return
	end
	if typeof(slot) ~= "string" or not table.find(Data.Slots, slot) then
		return
	end
	local e = Data.get(s.model:GetAttribute(slot))
	local behaviour = e and Behaviour[e.id]
	if not e or not behaviour then
		return
	end
	local t = now()
	-- A light's recovery can be cancelled into an Echo; a heavy's cannot.
	local afterLight = s.lastLightAt == s.lastAttackAt and t - s.lastLightAt < 1
	-- Every refusal says why, so a button press never just does nothing.
	if Combat.stunned(s) then
		notify(s, "Stunned")
		return
	elseif s.blocking or s.chargingSince then
		notify(s, "Busy")
		return
	elseif t < s.busyUntil - 0.15 and not afterLight then
		notify(s, "Busy")
		return
	end
	if Combat.hasStatus(s, "Silence") then
		notify(s, "Silenced")
		return
	end
	local mythic = e.rarity == "Mythic"
	if mythic then
		local surge = s.model:GetAttribute("Surge") or 0
		if surge < Data.Surge.max then
			notify(s, `Surge {math.floor(surge)}%: fill it to 100%`)
			return
		end
	elseif not ready(s, e.id) then
		notify(s, "Cooldown")
		return
	end
	if behaviour.check then
		local ok, why = behaviour.check(s, arg)
		if not ok then
			notify(s, why or "Can't use that now")
			return
		end
	end
	if mythic then
		s.model:SetAttribute("Surge", 0)
		s.armorUntil = math.max(s.armorUntil, t + 0.5)
	else
		s.model:SetAttribute(cooldownKey(e.id), t + e.cooldown)
	end
	s.busyUntil = t + e.cast + 0.3
	s.comboIndex = 0
	s.lastAttackAt = t
	s.strikeToken += 1
	local token = s.strikeToken
	Combat.fx("swing", s.model, nil, nil, nil, e.anim)
	echoFx(s, e.id, { phase = "cast", pos = s.hrp.Position })
	local function go()
		local armored = mythic or now() < s.armorUntil
		if not Combat.alive(s) then
			return
		end
		if token ~= s.strikeToken and not armored then
			-- Interrupted during the wind-up: half the cooldown comes back.
			if not mythic then
				s.model:SetAttribute(cooldownKey(e.id), now() + e.cooldown / 2)
			end
			echoFx(s, e.id, { phase = "interrupted", pos = s.hrp.Position })
			return
		end
		behaviour.run(s, arg)
	end
	if e.cast > 0 then
		task.delay(e.cast, go)
	else
		go()
	end
end

function Echoes.start(remotes: Folder)
	moveRemote = Instance.new("RemoteEvent")
	moveRemote.Name = "EchoMove"
	moveRemote.Parent = remotes
	effects = Instance.new("Folder")
	effects.Name = "EchoEffects"
	effects.Parent = workspace
	Combat.addHandler("Echo", cast)
	Combat.addHandler("Loadout", onLoadout)
end

Echoes.Behaviour = Behaviour

return Echoes
