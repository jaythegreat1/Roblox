--!strict
-- Spawns every player as an R15 body with standard proportions while keeping their outfit.
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local Characters = {}

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
		local model = Players:CreateHumanoidModelFromDescription(normalizedDescription(player), Enum.HumanoidRigType.R15)
		model.Name = player.Name
		local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.MaxHealth = Config.Character.MaxHealth
		humanoid.Health = Config.Character.MaxHealth
		humanoid.WalkSpeed = Config.Character.WalkSpeed
		local offset = Vector3.new(math.random(-5, 5), 4, math.random(-5, 5))
		model:PivotTo(CFrame.new(spawnPad.Position + offset))
		player.Character = model
		model.Parent = workspace
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
