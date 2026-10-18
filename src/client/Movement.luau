-- Local player's movement: sprint, dodge rolls, dash, slide, double-jump flips, air dash, landing rolls.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Engine = require(ReplicatedStorage.Shared.Anim.Engine)

local Movement = {}

local M = Config.Movement
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local actionRemote: RemoteEvent

local charges = M.DodgeCharges
local refillAt: { number } = {}
local busyUntil = 0
local sprinting = false
local airJumpUsed, airDashUsed = false, false
local lastJumpAt = 0
local minFallSpeed = 0
local drive: { dir: Vector3, from: number, to: number, startTime: number, duration: number, keepY: boolean }? = nil
local listeners: { (number) -> () } = {}

local function parts()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and hrp and humanoid.Health > 0 then
		return character, humanoid, hrp
	end
	return nil, nil, nil
end

local function notify()
	for _, fn in listeners do
		fn(charges)
	end
end

local function setFov(fov: number)
	TweenService
		:Create(camera, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = fov })
		:Play()
end

local function play(name: string)
	local character = player.Character
	Engine.play(character, name)
	actionRemote:FireServer(name)
end

local function spendCharge(): boolean
	if charges <= 0 then
		return false
	end
	charges -= 1
	table.insert(refillAt, os.clock() + M.DodgeRefill * (#refillAt + 1))
	notify()
	return true
end

local function inputDirection(hrp: BasePart, humanoid: Humanoid): Vector3
	local dir = humanoid.MoveDirection
	if dir.Magnitude < 0.1 then
		return -hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	return Vector3.new(dir.X, 0, dir.Z).Unit
end

local function startDrive(dir: Vector3, from: number, to: number, duration: number, keepY: boolean)
	drive = { dir = dir, from = from, to = to, startTime = os.clock(), duration = duration, keepY = keepY }
end

local function grounded(humanoid: Humanoid): boolean
	return humanoid.FloorMaterial ~= Enum.Material.Air
end

function Movement.dodge()
	local character, humanoid, hrp = parts()
	if not character or os.clock() < busyUntil or not grounded(humanoid) or not spendCharge() then
		return
	end
	local dir = inputDirection(hrp, humanoid)
	local loc = hrp.CFrame:VectorToObjectSpace(dir)
	local anim
	if math.abs(loc.Z) >= math.abs(loc.X) then
		anim = if loc.Z < 0 then "RollForward" else "RollBack"
	else
		anim = if loc.X < 0 then "CartwheelLeft" else "CartwheelRight"
	end
	busyUntil = os.clock() + M.RollTime
	humanoid.AutoRotate = false
	character:SetAttribute("Invulnerable", true)
	task.delay(M.RollIFrames, function()
		character:SetAttribute("Invulnerable", nil)
	end)
	task.delay(M.RollTime, function()
		humanoid.AutoRotate = true
	end)
	startDrive(dir, M.RollDistance / M.RollTime, M.RollDistance / M.RollTime * 0.6, M.RollTime, true)
	play(anim)
end

function Movement.dash()
	local character, humanoid, hrp = parts()
	if not character or os.clock() < busyUntil then
		return
	end
	local dir = inputDirection(hrp, humanoid)
	if not grounded(humanoid) then
		if airDashUsed then
			return
		end
		airDashUsed = true
		busyUntil = os.clock() + 0.25
		startDrive(dir, M.AirDashDistance / 0.25, 20, 0.25, false)
		play("AirDash")
		return
	end
	if not spendCharge() then
		return
	end
	if sprinting then
		busyUntil = os.clock() + M.SlideTime
		startDrive(
			hrp.CFrame.LookVector * Vector3.new(1, 0, 1),
			M.SlideSpeed,
			Config.Character.WalkSpeed,
			M.SlideTime,
			true
		)
		play("Slide")
	else
		busyUntil = os.clock() + M.DashTime
		startDrive(dir, M.DashDistance / M.DashTime, Config.Character.WalkSpeed, M.DashTime, true)
		play("Dash")
	end
	setFov(80)
	task.delay(0.3, function()
		setFov(if sprinting then 76 else 70)
	end)
end

function Movement.setSprint(on: boolean)
	sprinting = on
	local _, humanoid = parts()
	if humanoid then
		humanoid.WalkSpeed = if on then Config.Character.SprintSpeed else Config.Character.WalkSpeed
	end
	setFov(if on then 76 else 70)
end

function Movement.toggleSprint()
	Movement.setSprint(not sprinting)
end

function Movement.onCharges(fn: (number) -> ())
	table.insert(listeners, fn)
	fn(charges)
end

local function onJumpRequest()
	local character, humanoid, hrp = parts()
	if
		not character
		or grounded(humanoid)
		or airJumpUsed
		or os.clock() - lastJumpAt < 0.2
		or os.clock() < busyUntil
	then
		return
	end
	airJumpUsed = true
	local v = hrp.AssemblyLinearVelocity
	hrp.AssemblyLinearVelocity = Vector3.new(v.X, M.DoubleJumpVelocity, v.Z)
	local loc = hrp.CFrame:VectorToObjectSpace(humanoid.MoveDirection)
	local anim = "FlipFront"
	if humanoid.MoveDirection.Magnitude > 0.1 then
		if math.abs(loc.X) > math.abs(loc.Z) then
			anim = if loc.X < 0 then "FlipLeft" else "FlipRight"
		elseif loc.Z > 0 then
			anim = "FlipBack"
		end
	end
	play(anim)
end

local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	airJumpUsed, airDashUsed, drive, busyUntil = false, false, nil, 0
	humanoid.WalkSpeed = if sprinting then Config.Character.SprintSpeed else Config.Character.WalkSpeed
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping then
			lastJumpAt = os.clock()
		elseif new == Enum.HumanoidStateType.Landed then
			airJumpUsed, airDashUsed = false, false
			if minFallSpeed < -M.HardLandingSpeed then
				play("LandRoll")
			end
			minFallSpeed = 0
		end
	end)
end

function Movement.start(remote: RemoteEvent)
	actionRemote = remote
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
	UserInputService.JumpRequest:Connect(onJumpRequest)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftShift then
			Movement.setSprint(true)
		elseif input.KeyCode == Enum.KeyCode.Q then
			Movement.dodge()
		elseif input.KeyCode == Enum.KeyCode.E then
			Movement.dash()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			Movement.setSprint(false)
		end
	end)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		while refillAt[1] and now >= refillAt[1] do
			table.remove(refillAt, 1)
			charges = math.min(charges + 1, M.DodgeCharges)
			notify()
		end
		local _, humanoid, hrp = parts()
		if not hrp then
			return
		end
		local v = hrp.AssemblyLinearVelocity
		if not grounded(humanoid) then
			minFallSpeed = math.min(minFallSpeed, v.Y)
		end
		if drive then
			local a = (now - drive.startTime) / drive.duration
			if a >= 1 then
				drive = nil
			else
				local speed = drive.from + (drive.to - drive.from) * a
				local y = if drive.keepY then math.min(v.Y, 0) else 0
				hrp.AssemblyLinearVelocity = drive.dir * speed + Vector3.new(0, y, 0)
			end
		end
	end)
end

return Movement
