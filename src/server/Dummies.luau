-- Training dummies for practising combos, guard breaks and parries.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Characters = require(script.Parent.Characters)
local Sword = require(script.Parent.Sword)
local Combat = require(script.Parent.Combat)
local Overhead = require(script.Parent.Overhead)

local Dummies = {}

local MODES = {
	{ mode = "Stand", label = "Dummy: stands still", offset = Vector3.new(-20, 0, -24) },
	{ mode = "Block", label = "Dummy: always blocks", offset = Vector3.new(0, 0, -28) },
	{ mode = "Parry", label = "Dummy: parries half", offset = Vector3.new(20, 0, -24) },
	{ mode = "Attack", label = "Dummy: attacks you (block, parry, roll)", offset = Vector3.new(-34, 0, -10) },
}

function Dummies.spawn(center: Vector3)
	for _, info in MODES do
		task.spawn(function()
			local desc = Instance.new("HumanoidDescription")
			desc.HeadColor = Color3.fromRGB(160, 140, 110)
			desc.TorsoColor = Color3.fromRGB(150, 120, 90)
			desc.LeftArmColor = desc.HeadColor
			desc.RightArmColor = desc.HeadColor
			desc.LeftLegColor = desc.TorsoColor
			desc.RightLegColor = desc.TorsoColor
			local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
			model.Name = "Dummy" .. info.mode
			local animate = model:FindFirstChild("Animate")
			if animate then
				animate:Destroy()
			end
			local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
			humanoid.WalkSpeed = 0
			humanoid.JumpHeight = 0
			humanoid.BreakJointsOnDeath = false
			local pos = center + info.offset + Vector3.new(0, 4, 0)
			model:PivotTo(CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)))
			model.Parent = workspace
			Characters.waitForJoints(model)
			Characters.convertJoints(model)
			Sword.attach(model)
			CollectionService:AddTag(model, "BladeRiftRig")
			Overhead.attach(model, info.label)
			Combat.register(model, info.mode)
			pcall(function()
				(model:FindFirstChild("HumanoidRootPart") :: BasePart):SetNetworkOwner(nil)
			end)
			if info.mode == "Attack" then
				-- Swings slowly at whoever stands in front of it, for blocking, parry and roll practice.
				task.spawn(function()
					local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart
					local home = hrp.CFrame
					while model.Parent do
						task.wait(2.2)
						local target, best = nil, 9
						for _, player in Players:GetPlayers() do
							local thrp = player.Character
								and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
							local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
							if thrp and h and h.Health > 0 and (thrp.Position - hrp.Position).Magnitude < best then
								target, best = thrp, (thrp.Position - hrp.Position).Magnitude
							end
						end
						if target then
							hrp.CFrame = CFrame.lookAt(
								hrp.Position,
								Vector3.new(target.Position.X, hrp.Position.Y, target.Position.Z)
							)
							Combat.request(model, "Light")
						else
							hrp.CFrame = home
						end
					end
				end)
			end
			if info.mode == "Block" then
				-- Clients learn the dummy is blocking through the same effect message players use.
				task.wait(2)
				model:SetAttribute("BlockingPose", true)
			end
		end)
	end
end

return Dummies
