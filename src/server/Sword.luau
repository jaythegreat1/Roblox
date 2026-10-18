-- Builds each sword from parts and welds it into the hand. Every design is listed as pieces
-- relative to the grip, with the blade running along +Y; a Trail between two attachments
-- draws the swing.
local Sword = {}

local GOLD = Color3.fromRGB(200, 170, 90)
local STEEL = Color3.fromRGB(205, 210, 220)
local DARK = Color3.fromRGB(45, 40, 50)

type Piece = {
	name: string,
	size: Vector3,
	at: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
}

local function p(name, size, at, color, material, shape): Piece
	return { name = name, size = size, at = at, color = color, material = material, shape = shape }
end

local function deg(x, y, z)
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end

-- Each design: pieces, trail base/tip as (piece name, local offset), trail colour.
local DESIGNS = {
	IronOath = {
		pieces = {
			p("Handle", Vector3.new(0.28, 1.1, 0.28), CFrame.identity, Color3.fromRGB(60, 40, 30), Enum.Material.Wood),
			p(
				"Pommel",
				Vector3.new(0.42, 0.42, 0.42),
				CFrame.new(0, -0.68, 0),
				GOLD,
				Enum.Material.Metal,
				Enum.PartType.Ball
			),
			p("Guard", Vector3.new(1.3, 0.2, 0.32), CFrame.new(0, 0.65, 0), GOLD, Enum.Material.Metal),
			p("Blade", Vector3.new(0.14, 4.2, 0.4), CFrame.new(0, 2.85, 0), STEEL, Enum.Material.Metal),
			p(
				"Edge",
				Vector3.new(0.05, 4.0, 0.08),
				CFrame.new(0, 2.85, -0.21),
				Color3.fromRGB(235, 240, 255),
				Enum.Material.Neon
			),
			p("Tip", Vector3.new(0.14, 0.4, 0.28), CFrame.new(0, 5.05, 0) * deg(45), STEEL, Enum.Material.Metal),
		},
		trail = { "Blade", Vector3.new(0, -1.9, 0), "Blade", Vector3.new(0, 2.2, 0) },
		trailColor = Color3.fromRGB(170, 140, 255),
	},
	Kage = {
		pieces = {
			p(
				"Handle",
				Vector3.new(0.24, 1.3, 0.24),
				CFrame.identity,
				Color3.fromRGB(30, 30, 40),
				Enum.Material.Fabric
			),
			p(
				"Guard",
				Vector3.new(0.12, 0.7, 0.7),
				CFrame.new(0, 0.72, 0) * deg(0, 0, 90),
				Color3.fromRGB(40, 35, 30),
				Enum.Material.Metal,
				Enum.PartType.Cylinder
			),
			p("Blade", Vector3.new(0.1, 2.3, 0.3), CFrame.new(0, 1.95, 0), STEEL, Enum.Material.Metal),
			p("Blade2", Vector3.new(0.1, 2.3, 0.28), CFrame.new(0, 4.15, 0.08) * deg(-5), STEEL, Enum.Material.Metal),
			p(
				"Edge",
				Vector3.new(0.04, 4.4, 0.06),
				CFrame.new(0, 3.05, -0.16) * deg(-2.5),
				Color3.fromRGB(255, 120, 140),
				Enum.Material.Neon
			),
		},
		trail = { "Blade", Vector3.new(0, -1, 0), "Blade2", Vector3.new(0, 1.1, 0) },
		trailColor = Color3.fromRGB(255, 90, 120),
	},
	TwinFangs = {
		pieces = {
			p("Handle", Vector3.new(0.2, 0.7, 0.2), CFrame.identity, Color3.fromRGB(40, 70, 50), Enum.Material.Fabric),
			p("Guard", Vector3.new(0.7, 0.14, 0.22), CFrame.new(0, 0.42, 0), GOLD, Enum.Material.Metal),
			p("Blade", Vector3.new(0.08, 1.6, 0.3), CFrame.new(0, 1.3, 0), STEEL, Enum.Material.Metal),
			p(
				"Edge",
				Vector3.new(0.03, 1.5, 0.05),
				CFrame.new(0, 1.3, -0.16),
				Color3.fromRGB(140, 255, 170),
				Enum.Material.Neon
			),
		},
		trail = { "Blade", Vector3.new(0, -0.7, 0), "Blade", Vector3.new(0, 0.8, 0) },
		trailColor = Color3.fromRGB(120, 255, 160),
	},
	TitansMaw = {
		pieces = {
			p(
				"Handle",
				Vector3.new(0.36, 2, 0.36),
				CFrame.new(0, 0.3, 0),
				Color3.fromRGB(50, 35, 30),
				Enum.Material.Wood
			),
			p("Pommel", Vector3.new(0.6, 0.5, 0.6), CFrame.new(0, -0.85, 0), DARK, Enum.Material.Metal),
			p("Guard", Vector3.new(2.4, 0.4, 0.55), CFrame.new(0, 1.45, 0), DARK, Enum.Material.Metal),
			p(
				"Blade",
				Vector3.new(0.32, 6.4, 1.4),
				CFrame.new(0, 4.85, 0),
				Color3.fromRGB(110, 110, 125),
				Enum.Material.Metal
			),
			p(
				"Rune",
				Vector3.new(0.34, 5, 0.18),
				CFrame.new(0, 4.6, 0),
				Color3.fromRGB(255, 110, 40),
				Enum.Material.Neon
			),
			p(
				"Tip",
				Vector3.new(0.32, 0.9, 1),
				CFrame.new(0, 8.2, 0) * deg(45),
				Color3.fromRGB(110, 110, 125),
				Enum.Material.Metal
			),
		},
		trail = { "Blade", Vector3.new(0, -3, 0), "Blade", Vector3.new(0, 3.3, 0) },
		trailColor = Color3.fromRGB(255, 130, 60),
	},
	Fleuret = {
		pieces = {
			p(
				"Handle",
				Vector3.new(0.2, 0.9, 0.2),
				CFrame.identity,
				Color3.fromRGB(240, 235, 220),
				Enum.Material.Marble
			),
			p(
				"Guard",
				Vector3.new(0.75, 0.75, 0.75),
				CFrame.new(0, 0.55, 0),
				GOLD,
				Enum.Material.Metal,
				Enum.PartType.Ball
			),
			p(
				"Blade",
				Vector3.new(0.07, 5, 0.1),
				CFrame.new(0, 3.3, 0),
				Color3.fromRGB(225, 230, 240),
				Enum.Material.Metal
			),
			p(
				"Edge",
				Vector3.new(0.03, 4.6, 0.03),
				CFrame.new(0, 3.3, -0.06),
				Color3.fromRGB(140, 200, 255),
				Enum.Material.Neon
			),
		},
		trail = { "Blade", Vector3.new(0, -2, 0), "Blade", Vector3.new(0, 2.5, 0) },
		trailColor = Color3.fromRGB(140, 200, 255),
	},
	Sirocco = {
		pieces = {
			p("Handle", Vector3.new(0.24, 1, 0.24), CFrame.identity, Color3.fromRGB(80, 40, 30), Enum.Material.Leather),
			p("Guard", Vector3.new(1.1, 0.18, 0.3), CFrame.new(0, 0.6, 0) * deg(0, 0, 10), GOLD, Enum.Material.Metal),
			p(
				"Blade",
				Vector3.new(0.12, 1.6, 0.45),
				CFrame.new(0, 1.45, 0),
				Color3.fromRGB(230, 215, 180),
				Enum.Material.Metal
			),
			p(
				"Blade2",
				Vector3.new(0.12, 1.5, 0.55),
				CFrame.new(0, 2.9, 0.12) * deg(-12),
				Color3.fromRGB(230, 215, 180),
				Enum.Material.Metal
			),
			p(
				"Blade3",
				Vector3.new(0.12, 1.3, 0.62),
				CFrame.new(0, 4.2, 0.42) * deg(-26),
				Color3.fromRGB(230, 215, 180),
				Enum.Material.Metal
			),
			p(
				"Gem",
				Vector3.new(0.3, 0.3, 0.3),
				CFrame.new(0, 0.6, -0.18),
				Color3.fromRGB(255, 190, 60),
				Enum.Material.Neon,
				Enum.PartType.Ball
			),
		},
		trail = { "Blade", Vector3.new(0, -0.7, 0), "Blade3", Vector3.new(0, 0.6, 0) },
		trailColor = Color3.fromRGB(255, 200, 100),
	},
}

local function makePart(piece: Piece): Part
	local part = Instance.new("Part")
	part.Name = piece.name
	part.Size = piece.size
	part.Color = piece.color
	part.Material = piece.material or Enum.Material.SmoothPlastic
	if piece.shape then
		part.Shape = piece.shape
	end
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- Builds one sword and welds every piece straight to the hand: the grip point is the centre
-- of the handle, so the fist always closes around the handle.
local function build(hand: BasePart, design, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	local grip = CFrame.new(0, -0.2, 0) * deg(-90)
	for _, piece in design.pieces do
		local part = makePart(piece)
		part.CFrame = hand.CFrame * grip * piece.at
		local weld = Instance.new("Weld")
		weld.Name = "SwordWeld"
		weld.Part0 = hand
		weld.Part1 = part
		weld.C0 = grip * piece.at
		weld.Parent = part
		part.Parent = model
	end
	local t = design.trail
	local base = Instance.new("Attachment")
	base.Name = "TrailBase"
	base.Position = t[2]
	base.Parent = model:FindFirstChild(t[1])
	local tip = Instance.new("Attachment")
	tip.Name = "TrailTip"
	tip.Position = t[4]
	tip.Parent = model:FindFirstChild(t[3])
	local trail = Instance.new("Trail")
	trail.Attachment0 = base
	trail.Attachment1 = tip
	trail.Lifetime = 0.18
	trail.MinLength = 0.05
	trail.FaceCamera = true
	trail.LightEmission = 0.8
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1), design.trailColor)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Enabled = false
	trail.Parent = model:FindFirstChild("Blade")
	model.PrimaryPart = model:FindFirstChild("Handle") :: BasePart
	return model
end

function Sword.attach(character: Model, swordId: string?)
	local id = if swordId and DESIGNS[swordId] then swordId else "IronOath"
	for _, old in { "Sword", "SwordOffhand" } do
		local existing = character:FindFirstChild(old)
		if existing then
			existing:Destroy()
		end
	end
	local right = character:FindFirstChild("RightHand") :: BasePart?
	if not right then
		return
	end
	local design = DESIGNS[id]
	build(right, design, "Sword").Parent = character
	if id == "TwinFangs" then
		local left = character:FindFirstChild("LeftHand") :: BasePart?
		if left then
			build(left, design, "SwordOffhand").Parent = character
		end
	end
	character:SetAttribute("SwordId", id)
	character:SetAttribute("Armed", true)
end

return Sword
