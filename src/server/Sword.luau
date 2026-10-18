-- Builds the Iron Oath from parts and welds it into the right hand.
-- Blade runs along the handle's +Y axis; a Trail between two blade attachments draws the swing.
local Sword = {}

local function piece(
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = offset
	p.Color = color
	p.Material = material
	if shape then
		p.Shape = shape
	end
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

function Sword.attach(character: Model)
	local hand = character:FindFirstChild("RightHand") :: BasePart?
	if not hand then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Sword"

	local handle =
		piece("Handle", Vector3.new(0.28, 1.1, 0.28), CFrame.identity, Color3.fromRGB(60, 40, 30), Enum.Material.Wood)
	local parts = {
		piece(
			"Pommel",
			Vector3.new(0.42, 0.42, 0.42),
			CFrame.new(0, -0.68, 0),
			Color3.fromRGB(200, 170, 90),
			Enum.Material.Metal,
			Enum.PartType.Ball
		),
		piece(
			"Guard",
			Vector3.new(1.3, 0.2, 0.32),
			CFrame.new(0, 0.65, 0),
			Color3.fromRGB(200, 170, 90),
			Enum.Material.Metal
		),
		piece(
			"Blade",
			Vector3.new(0.14, 4.2, 0.4),
			CFrame.new(0, 2.85, 0),
			Color3.fromRGB(205, 210, 220),
			Enum.Material.Metal
		),
		piece(
			"Edge",
			Vector3.new(0.05, 4.0, 0.08),
			CFrame.new(0, 2.85, -0.21),
			Color3.fromRGB(235, 240, 255),
			Enum.Material.Neon
		),
		piece(
			"Tip",
			Vector3.new(0.14, 0.4, 0.28),
			CFrame.new(0, 5.05, 0) * CFrame.Angles(math.rad(45), 0, 0),
			Color3.fromRGB(205, 210, 220),
			Enum.Material.Metal
		),
	}
	-- Weld every piece straight to the hand. The grip point is the centre of the handle, so the
	-- fist always closes around the handle no matter how the model was positioned before.
	local grip = CFrame.new(0, -0.2, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	local function weldToHand(p: Part)
		local offset = p.CFrame
		p.CFrame = hand.CFrame * grip * offset
		local weld = Instance.new("Weld")
		weld.Name = "SwordWeld"
		weld.Part0 = hand
		weld.Part1 = p
		weld.C0 = grip * offset
		weld.Parent = p
		p.Parent = model
	end
	weldToHand(handle)
	for _, p in parts do
		weldToHand(p)
	end

	local blade = model:FindFirstChild("Blade") :: Part
	local base = Instance.new("Attachment")
	base.Name = "TrailBase"
	base.Position = Vector3.new(0, -1.9, 0)
	base.Parent = blade
	local tip = Instance.new("Attachment")
	tip.Name = "TrailTip"
	tip.Position = Vector3.new(0, 2.2, 0)
	tip.Parent = blade
	local trail = Instance.new("Trail")
	trail.Attachment0 = base
	trail.Attachment1 = tip
	trail.Lifetime = 0.18
	trail.MinLength = 0.05
	trail.FaceCamera = true
	trail.LightEmission = 0.8
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 140, 255))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Enabled = false
	trail.Parent = blade

	model.PrimaryPart = handle
	model.Parent = character
	character:SetAttribute("Armed", true)
end

return Sword
