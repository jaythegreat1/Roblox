-- Training dummies for practising combos, guard breaks and parries.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Characters = require(script.Parent.Characters)
local Sword = require(script.Parent.Sword)
local Combat = require(script.Parent.Combat)
local Overhead = require(script.Parent.Overhead)

local Dummies = {}

local MODES = {
	{ mode = "Stand", label = "Dummy: stands still", offset = Vector3.new(-14, 0, -24) },
	{ mode = "Block", label = "Dummy: always blocks", offset = Vector3.new(0, 0, -28) },
	{ mode = "Parry", label = "Dummy: parries half", offset = Vector3.new(14, 0, -24) },
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
			if info.mode == "Block" then
				-- Clients learn the dummy is blocking through the same effect message players use.
				task.wait(2)
				model:SetAttribute("BlockingPose", true)
			end
		end)
	end
end

return Dummies
