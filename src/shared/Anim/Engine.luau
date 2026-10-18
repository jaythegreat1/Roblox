-- Custom animation engine. Every client animates every character locally by writing
-- Motor6D.Transform each frame: a procedural locomotion layer plus keyframed actions on top.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Library = require(script.Parent.Library)

local Engine = {}

local JOINTS = {
	"Root",
	"Waist",
	"Neck",
	"LeftShoulder",
	"LeftElbow",
	"LeftWrist",
	"RightShoulder",
	"RightElbow",
	"RightWrist",
	"LeftHip",
	"LeftKnee",
	"LeftAnkle",
	"RightHip",
	"RightKnee",
	"RightAnkle",
}

local FADE_IN, FADE_OUT = 0.06, 0.1
local rad = math.rad

type Rig = {
	character: Model,
	hrp: BasePart,
	motors: { [string]: Motor6D },
	loco: { [string]: CFrame },
	phase: number,
	action: any?,
	actionTime: number,
	actionSpeed: number,
	rayParams: RaycastParams,
}

local rigs: { [Model]: Rig } = {}

local function ease(kind: string?, a: number): number
	if kind == "in" then
		return a * a
	elseif kind == "out" then
		return 1 - (1 - a) * (1 - a)
	elseif kind == "inout" then
		return if a < 0.5 then 2 * a * a else 1 - (-2 * a + 2) ^ 2 / 2
	end
	return a
end

local function toCFrame(j): CFrame
	if not j then
		return CFrame.identity
	end
	return CFrame.new(0, j.py or 0, j.pz or 0) * CFrame.Angles(rad(j.x or 0), rad(j.y or 0), rad(j.z or 0))
end

local function lerpJoint(a, b, alpha)
	a = a or {}
	b = b or {}
	local function l(k)
		return (a[k] or 0) + ((b[k] or 0) - (a[k] or 0)) * alpha
	end
	return { x = l("x"), y = l("y"), z = l("z"), py = l("py"), pz = l("pz") }
end

local function sampleAction(anim, t: number): { [string]: CFrame }
	local keys = anim.keys
	local out = {}
	local prev, nxt = keys[1], keys[#keys]
	for i = 1, #keys - 1 do
		if t >= keys[i].t and t <= keys[i + 1].t then
			prev, nxt = keys[i], keys[i + 1]
			break
		end
	end
	local span = nxt.t - prev.t
	local alpha = if span > 0 then ease(nxt.ease, math.clamp((t - prev.t) / span, 0, 1)) else 1
	for _, name in JOINTS do
		local a, b = prev.pose[name], nxt.pose[name]
		if a or b then
			out[name] = toCFrame(lerpJoint(a, b, alpha))
		end
	end
	return out
end

local function getRig(character: Model): Rig?
	local existing = rigs[character]
	if existing then
		return existing
	end
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return nil
	end
	local motors = {}
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") and table.find(JOINTS, d.Name) then
			motors[d.Name] = d
		end
	end
	if not motors.Root then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local rig: Rig = {
		character = character,
		hrp = hrp,
		motors = motors,
		loco = {},
		phase = 0,
		action = nil,
		actionTime = 0,
		actionSpeed = 1,
		rayParams = params,
	}
	rigs[character] = rig
	character.Destroying:Connect(function()
		rigs[character] = nil
	end)
	return rig
end

-- Procedural locomotion target pose (degrees), from velocity and ground contact.
local function locomotionPose(rig: Rig, dt: number, now: number)
	local v = rig.hrp.AssemblyLinearVelocity
	local horiz = Vector3.new(v.X, 0, v.Z).Magnitude
	local grounded = workspace:Raycast(rig.hrp.Position, Vector3.new(0, -4.2, 0), rig.rayParams) ~= nil
	local p = {}
	if not grounded then
		if v.Y > 0 then
			p.LeftHip = { x = 35 }
			p.RightHip = { x = 10 }
			p.LeftKnee = { x = -60 }
			p.RightKnee = { x = -20 }
			p.LeftShoulder = { x = 40, z = -20 }
			p.RightShoulder = { x = -20, z = 20 }
		else
			p.LeftHip = { x = 15, z = -10 }
			p.RightHip = { x = -5, z = 10 }
			p.LeftKnee = { x = -25 }
			p.RightKnee = { x = -15 }
			p.LeftShoulder = { z = -70 }
			p.RightShoulder = { z = 70 }
		end
		return p
	end
	if horiz < 1 then
		local breath = math.sin(now * 2)
		p.Root = { py = -0.15 + breath * 0.04 }
		p.Waist = { x = breath * 1.5 }
		p.LeftHip = { x = 6, z = -4 }
		p.RightHip = { x = -4, z = 4 }
		p.LeftKnee = { x = -10 }
		p.RightKnee = { x = -6 }
		p.LeftShoulder = { x = 4, z = -6 }
		p.RightShoulder = { x = 4, z = 6 }
		p.LeftElbow = { x = 12 }
		p.RightElbow = { x = 12 }
		return p
	end
	local s = math.clamp(horiz / 16, 0, 1.8)
	local sprint = math.clamp((horiz - 18) / 8, 0, 1)
	rig.phase += dt * (6 + horiz * 0.3)
	local sw = math.sin(rig.phase)
	local amp = 30 * math.min(s, 1) + 15 * sprint
	p.Root = { x = -(4 + 12 * sprint), py = -math.abs(math.cos(rig.phase)) * 0.3 }
	p.Waist = { y = 8 * sw, x = -4 * sprint }
	p.LeftHip = { x = amp * sw }
	p.RightHip = { x = -amp * sw }
	p.LeftKnee = { x = -(15 + 50 * math.max(0, -sw)) }
	p.RightKnee = { x = -(15 + 50 * math.max(0, sw)) }
	local armAmp = amp * (0.8 - 0.3 * sprint)
	p.LeftShoulder = { x = -armAmp * sw - 25 * sprint, z = -8 }
	p.RightShoulder = { x = armAmp * sw - 25 * sprint, z = 8 }
	p.LeftElbow = { x = 25 + 45 * sprint }
	p.RightElbow = { x = 25 + 45 * sprint }
	return p
end

local function step(dt: number)
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local rig = character and getRig(character)
		if rig then
			local target = locomotionPose(rig, dt, now)
			local smooth = 1 - math.exp(-18 * dt)
			local actionPose, weight = nil, 0
			if rig.action then
				rig.actionTime += dt * rig.actionSpeed
				local d = rig.action.duration
				if rig.actionTime >= d + FADE_OUT then
					rig.action = nil
				else
					actionPose = sampleAction(rig.action, math.min(rig.actionTime, d))
					weight = math.min(rig.actionTime / FADE_IN, 1)
					if rig.actionTime > d then
						weight = 1 - (rig.actionTime - d) / FADE_OUT
					end
				end
			end
			for name, motor in rig.motors do
				local goal = toCFrame(target[name])
				local current = (rig.loco[name] or CFrame.identity):Lerp(goal, smooth)
				rig.loco[name] = current
				local final = current
				if actionPose and actionPose[name] then
					final = current:Lerp(actionPose[name], weight)
				elseif actionPose and weight > 0 then
					final = current:Lerp(CFrame.identity, weight)
				end
				motor.Transform = final
			end
		end
	end
end

function Engine.play(character: Model?, name: string, speed: number?)
	local anim = Library[name]
	local rig = character and getRig(character)
	if not anim or not rig then
		return
	end
	rig.action = anim
	rig.actionTime = 0
	rig.actionSpeed = speed or 1
end

function Engine.exists(name: string): boolean
	return Library[name] ~= nil
end

function Engine.start()
	RunService.PreSimulation:Connect(step)
end

return Engine
