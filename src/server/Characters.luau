--!strict
-- Spawns every player as an R15 body with standard proportions while keeping their outfit.
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local Characters = {}

-- New Roblox avatars are built with AnimationConstraint joints. Our engine animates by writing
-- Motor6D.Transform, so swap each AnimationConstraint for an equivalent Motor6D.
local function convertJoints(model: Model): number
	local converted = 0
	for _, c in model:GetDescendants() do
		if c:IsA("AnimationConstraint") and c.Attachment0 and c.Attachment1 then
			local a0, a1 = c.Attachment0, c.Attachment1
			local motor = Instance.new("Motor6D")
			motor.Name = c.Name
			motor.Part0 = a0.Parent :: BasePart
			motor.Part1 = a1.Parent :: BasePart
			motor.C0 = a0.CFrame
			motor.C1 = a1.CFrame
			local parent = c.Parent
			c:Destroy()
			motor.Parent = parent
			converted += 1
		end
	end
	for _, c in model:GetDescendants() do
		if c:IsA("BallSocketConstraint") and string.find(c.Name, "BallSocket") then
			c:Destroy()
		end
	end
	return converted
end

local function waitForJoints(model: Model)
	for _ = 1, 60 do
		for _, c in model:GetDescendants() do
			if (c:IsA("AnimationConstraint") or c:IsA("Motor6D")) and c.Name == "Root" then
				return
			end
		end
		task.wait()
	end
end

local function normalizedDescription(player: Player): HumanoidDescription
	local ok, desc = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(player.UserId)
	end)
	local d: HumanoidDescription = if ok and desc then desc else Instance.new("HumanoidDescription")
	local s = Config.Character.Scale
	d.HeightScale = s.Height
	d.WidthScale = s.Width
	d.DepthScale = s.Depth
	d.HeadScale = s.Head
	d.BodyTypeScale = s.BodyType
	d.ProportionScale = s.Proportion
	-- Body part meshes change limb shapes; reset them so every rig is identical.
	d.Head = 0
	d.Torso = 0
	d.LeftArm = 0
	d.RightArm = 0
	d.LeftLeg = 0
	d.RightLeg = 0
	return d
end

function Characters.start(spawnPad: BasePart)
	local function spawnPlayer(player: Player)
		local model =
			Players:CreateHumanoidModelFromDescription(normalizedDescription(player), Enum.HumanoidRigType.R15)
		model.Name = player.Name
		-- Our own engine animates everyone; the default Animate script would fight it.
		local animate = model:FindFirstChild("Animate")
		if animate then
			animate:Destroy()
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.MaxHealth = Config.Character.MaxHealth
		humanoid.Health = Config.Character.MaxHealth
		humanoid.WalkSpeed = Config.Character.WalkSpeed
		local offset = Vector3.new(math.random(-5, 5), 4, math.random(-5, 5))
		model:PivotTo(CFrame.new(spawnPad.Position + offset))
		model.Parent = workspace
		waitForJoints(model)
		convertJoints(model)
		player.Character = model
		humanoid.Died:Connect(function()
			task.wait(4)
			if player.Parent then
				spawnPlayer(player)
			end
		end)
	end

	Players.PlayerAdded:Connect(spawnPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(spawnPlayer, player)
	end
end

return Characters
