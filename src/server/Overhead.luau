-- Name, health and posture bars above every fighter's head.
local Overhead = {}

local function bar(parent: Instance, y: number, height: number, color: Color3): Frame
	local back = Instance.new("Frame")
	back.Position = UDim2.new(0, 0, 0, y)
	back.Size = UDim2.new(1, 0, 0, height)
	back.BackgroundColor3 = Color3.fromRGB(20, 18, 28)
	back.BackgroundTransparency = 0.3
	back.BorderSizePixel = 0
	back.Parent = parent
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back
	return fill
end

function Overhead.attach(model: Model, label: string, hideFrom: Player?)
	local head = model:FindFirstChild("Head") :: BasePart?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not head or not humanoid then
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local gui = Instance.new("BillboardGui")
	gui.Name = "Overhead"
	gui.Size = UDim2.fromOffset(120, 34)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80
	gui.PlayerToHideFrom = hideFrom
	gui.Parent = head

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 16)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 13
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.4
	name.Text = label
	name.Parent = gui
	-- Players show their level in front of their name.
	if hideFrom then
		local function setName()
			name.Text = `Lv {hideFrom:GetAttribute("Level") or 1} · {label}`
		end
		hideFrom:GetAttributeChangedSignal("Level"):Connect(setName)
		setName()
	end

	local health = bar(gui, 18, 7, Color3.fromRGB(90, 220, 120))
	local posture = bar(gui, 27, 4, Color3.fromRGB(250, 200, 70))

	local function update()
		health.Size = UDim2.fromScale(math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1), 1)
		local p = model:GetAttribute("Posture")
		posture.Size = UDim2.fromScale(math.clamp((if typeof(p) == "number" then p else 100) / 100, 0, 1), 1)
	end
	humanoid.HealthChanged:Connect(update)
	model:GetAttributeChangedSignal("Posture"):Connect(update)
	update()
end

return Overhead
