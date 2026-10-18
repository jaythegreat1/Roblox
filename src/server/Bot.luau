-- Sparring bot: an AI swordsman that uses exactly the same combat rules as players.
-- It sees swings coming (with a human-like reaction delay) and chooses to block, parry,
-- back off or trade, and it attacks with combos, heavies and grabs when it has an opening.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Characters = require(script.Parent.Characters)
local Sword = require(script.Parent.Sword)
local Combat = require(script.Parent.Combat)
local Overhead = require(script.Parent.Overhead)

local Bot = {}

-- Adept difficulty from the master plan.
local PROFILE = {
	label = "Sparring Bot (Adept)",
	reaction = 0.33,
	parryChance = 0.3,
	blockChance = 0.45,
	backstepChance = 0.15,
	aggression = 0.7,
	sightRange = 45,
}

local function nearestPlayer(from: Vector3): (Model?, number)
	local best, bestDist = nil, math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and hrp and humanoid.Health > 0 then
			local d = (hrp.Position - from).Magnitude
			if d < bestDist then
				best, bestDist = character, d
			end
		end
	end
	return best, bestDist
end

local function stunned(model: Model): boolean
	local untilTime = model:GetAttribute("StunnedUntil")
	return typeof(untilTime) == "number" and workspace:GetServerTimeNow() < untilTime
end

local function build(home: Vector3): Model
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = Color3.fromRGB(90, 80, 120)
	desc.TorsoColor = Color3.fromRGB(60, 50, 90)
	desc.LeftArmColor = desc.HeadColor
	desc.RightArmColor = desc.HeadColor
	desc.LeftLegColor = desc.TorsoColor
	desc.RightLegColor = desc.TorsoColor
	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	model.Name = "SparringBot"
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.WalkSpeed = 16
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	model:PivotTo(CFrame.new(home + Vector3.new(0, 4, 0)))
	model.Parent = workspace
	Characters.waitForJoints(model)
	Characters.convertJoints(model)
	Sword.attach(model)
	CollectionService:AddTag(model, "BladeRiftRig")
	Overhead.attach(model, PROFILE.label)
	Combat.register(model)
	pcall(function()
		(model:FindFirstChild("HumanoidRootPart") :: BasePart):SetNetworkOwner(nil)
	end)
	return model
end

local function run(model: Model, home: Vector3)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local comboLeft = 0

	-- React to incoming swings aimed at us.
	Combat.onSwing(function(attacker, move, isHeavy, hitAt)
		if attacker == model or humanoid.Health <= 0 or not model.Parent then
			return
		end
		local ahrp = attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not ahrp or (ahrp.Position - hrp.Position).Magnitude > move.range + 3 then
			return
		end
		local timeLeft = hitAt - workspace:GetServerTimeNow()
		if timeLeft < PROFILE.reaction * 0.5 or stunned(model) then
			return -- too fast to react to
		end
		local roll = math.random()
		if roll < PROFILE.parryChance then
			-- Tap block just before the hit lands.
			task.wait(math.max(timeLeft - 0.1, 0))
			Combat.request(model, "BlockStart")
			task.wait(0.2)
			Combat.request(model, "BlockEnd")
		elseif roll < PROFILE.parryChance + PROFILE.blockChance and not isHeavy then
			task.wait(PROFILE.reaction * 0.6)
			Combat.request(model, "BlockStart")
			task.wait(timeLeft + 0.25)
			Combat.request(model, "BlockEnd")
		elseif roll < PROFILE.parryChance + PROFILE.blockChance + PROFILE.backstepChance then
			humanoid:MoveTo(hrp.Position + (hrp.Position - ahrp.Position).Unit * 10)
		end
	end)

	while model.Parent and humanoid.Health > 0 do
		task.wait(0.15)
		local target, dist = nearestPlayer(hrp.Position)
		if not target or dist > PROFILE.sightRange then
			humanoid:MoveTo(home)
			continue
		end
		local thrp = target:FindFirstChild("HumanoidRootPart") :: BasePart
		if stunned(model) or Combat.isBlocking(model) then
			continue
		end
		-- Face the target.
		local flat = Vector3.new(thrp.Position.X, hrp.Position.Y, thrp.Position.Z)
		if (flat - hrp.Position).Magnitude > 0.1 then
			hrp.CFrame = CFrame.lookAt(hrp.Position, flat)
		end
		if dist > 7 then
			humanoid:MoveTo(thrp.Position)
			comboLeft = 0
		else
			humanoid:MoveTo(hrp.Position)
			if math.random() < PROFILE.aggression then
				if comboLeft <= 0 then
					local pick = math.random()
					if pick < 0.15 then
						Combat.request(model, "Grab")
						task.wait(0.8)
					elseif pick < 0.3 then
						Combat.request(model, "HeavyStart")
						task.wait(0.4 + math.random() * 0.5)
						Combat.request(model, "HeavyRelease")
						task.wait(0.6)
					else
						comboLeft = math.random(2, 4)
					end
				end
				if comboLeft > 0 then
					Combat.request(model, "Light")
					comboLeft -= 1
					task.wait(0.35)
					if comboLeft == 0 then
						task.wait(0.4)
					end
				end
			end
			-- Finish the job when the target is low and stunned.
			if target:FindFirstChildOfClass("Humanoid").Health <= 15 and stunned(target) then
				Combat.request(model, "Finish")
			end
		end
	end
end

function Bot.spawn(home: Vector3)
	task.spawn(function()
		while true do
			local model = build(home)
			run(model, home)
			task.wait(5)
			if model.Parent then
				model:Destroy()
			end
		end
	end)
end

return Bot
