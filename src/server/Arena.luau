--!strict
-- Builds the Phase 0 test arena from code: a stone ring, pillars, and a spawn pad.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local Arena = {}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

function Arena.build(): BasePart
	local folder = Instance.new("Folder")
	folder.Name = "Arena"
	folder.Parent = workspace

	local r = Config.Arena.Radius
	part({
		Name = "Floor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4, r * 2, r * 2),
		CFrame = CFrame.new(0, -2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(70, 66, 78),
		Parent = folder,
	})

	for i = 1, Config.Arena.PillarCount do
		local angle = (i / Config.Arena.PillarCount) * math.pi * 2
		local pos = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (r * 0.7)
		local pillar = part({
			Name = "Pillar",
			Size = Vector3.new(8, 36, 8),
			CFrame = CFrame.new(pos + Vector3.new(0, 18, 0)),
			Material = Enum.Material.Cobblestone,
			Color = Color3.fromRGB(110, 104, 118),
			Parent = folder,
		})
		local glow = part({
			Name = "RiftGlow",
			Size = Vector3.new(8.4, 1, 8.4),
			CFrame = pillar.CFrame * CFrame.new(0, 10, 0),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(220, 60, 200),
			CanCollide = false,
			Parent = folder,
		})
		local light = Instance.new("PointLight")
		light.Color = glow.Color
		light.Range = 18
		light.Brightness = 1.5
		light.Parent = glow
	end

	local spawn = part({
		Name = "SpawnPad",
		Size = Vector3.new(16, 1, 16),
		CFrame = CFrame.new(0, 0.5, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(120, 90, 255),
		Parent = folder,
	})

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.35
	atmosphere.Color = Color3.fromRGB(200, 170, 220)
	atmosphere.Decay = Color3.fromRGB(90, 60, 120)
	atmosphere.Parent = game:GetService("Lighting")

	return spawn
end

return Arena
