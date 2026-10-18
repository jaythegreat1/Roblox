-- Armory: pick your sword. In this test build every sword is unlocked; level and coin
-- requirements from the master plan arrive with progression in Phase 5.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Swords = require(ReplicatedStorage.Shared.Combat.Swords)
local Progression = require(ReplicatedStorage.Shared.Progression)

local Armory = {}

local RATING_LABELS = {
	{ "damage", "DMG" },
	{ "speed", "SPD" },
	{ "reach", "RCH" },
	{ "guardBreak", "BRK" },
	{ "mobility", "MOV" },
}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

function Armory.build(gui: ScreenGui, onEquip: (string) -> (), Progress)
	local player = Players.LocalPlayer

	local open = Instance.new("TextButton")
	open.Name = "ArmoryButton"
	open.AnchorPoint = Vector2.new(1, 0)
	open.Position = UDim2.new(1, -16, 0, 16)
	open.Size = UDim2.fromOffset(96, 36)
	open.BackgroundColor3 = Color3.fromRGB(120, 90, 255)
	open.BackgroundTransparency = 0.15
	open.Font = Enum.Font.GothamBold
	open.TextSize = 15
	open.TextColor3 = Color3.new(1, 1, 1)
	open.Text = "Swords"
	open.Parent = gui
	corner(open, 10)

	local panel = Instance.new("ScrollingFrame")
	panel.Name = "Armory"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.8, 0, 0.8, 0)
	panel.BackgroundColor3 = Color3.fromRGB(20, 18, 28)
	panel.BackgroundTransparency = 0.08
	panel.ScrollBarThickness = 6
	panel.CanvasSize = UDim2.new(0, 0, 0, 0)
	panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
	panel.Visible = false
	panel.ZIndex = 20
	panel.Parent = gui
	corner(panel, 14)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 30)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 22
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Armory  ·  swords unlock with levels and coins"
	title.LayoutOrder = 0
	title.ZIndex = 21
	title.Parent = panel

	local equipButtons: { [string]: TextButton } = {}

	local function refresh()
		local current = player.Character and player.Character:GetAttribute("SwordId") or "IronOath"
		local data = Progress.data()
		for id, b in equipButtons do
			local info = Progression.Swords[id]
			if data and not data.swords[id] then
				-- Not owned yet: shows the level gate, then the price.
				if data.level < info.level then
					b.Text = `Lv {info.level}`
					b.BackgroundColor3 = Color3.fromRGB(70, 66, 84)
				else
					b.Text = `Buy {Progress.commas(info.coins)}`
					b.BackgroundColor3 = if data.coins >= info.coins
						then Color3.fromRGB(200, 150, 40)
						else Color3.fromRGB(110, 90, 50)
				end
			else
				local equipped = id == current
				b.Text = if equipped then "Equipped" else "Equip"
				b.BackgroundColor3 = if equipped then Color3.fromRGB(60, 160, 100) else Color3.fromRGB(120, 90, 255)
			end
		end
	end

	for i, id in Swords.Order do
		local sword = Swords.get(id)
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, 0, 0, 92)
		card.BackgroundColor3 = Color3.fromRGB(40, 36, 56)
		card.LayoutOrder = i
		card.ZIndex = 21
		card.Parent = panel
		corner(card, 10)

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(12, 6)
		name.Size = UDim2.new(1, -130, 0, 22)
		name.Font = Enum.Font.GothamBold
		name.TextSize = 18
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = Color3.new(1, 1, 1)
		name.Text = `{sword.name}  ·  {sword.family}`
		name.ZIndex = 22
		name.Parent = card

		local style = Instance.new("TextLabel")
		style.BackgroundTransparency = 1
		style.Position = UDim2.fromOffset(12, 30)
		style.Size = UDim2.new(1, -130, 0, 30)
		style.Font = Enum.Font.Gotham
		style.TextSize = 13
		style.TextWrapped = true
		style.TextXAlignment = Enum.TextXAlignment.Left
		style.TextYAlignment = Enum.TextYAlignment.Top
		style.TextColor3 = Color3.fromRGB(200, 195, 220)
		style.Text = sword.style
		style.ZIndex = 22
		style.Parent = card

		local ratings = {}
		for _, r in RATING_LABELS do
			local value = sword.ratings[r[1]]
			table.insert(ratings, `{r[2]} {string.rep("■", value)}{string.rep("□", 5 - value)}`)
		end
		local stats = Instance.new("TextLabel")
		stats.BackgroundTransparency = 1
		stats.Position = UDim2.fromOffset(12, 64)
		stats.Size = UDim2.new(1, -130, 0, 20)
		stats.Font = Enum.Font.Code
		stats.TextSize = 13
		stats.TextXAlignment = Enum.TextXAlignment.Left
		stats.TextColor3 = Color3.fromRGB(255, 220, 120)
		stats.Text = table.concat(ratings, "  ")
		stats.ZIndex = 22
		stats.Parent = card

		local equip = Instance.new("TextButton")
		equip.AnchorPoint = Vector2.new(1, 0.5)
		equip.Position = UDim2.new(1, -12, 0.5, 0)
		equip.Size = UDim2.fromOffset(100, 40)
		equip.Font = Enum.Font.GothamBold
		equip.TextSize = 15
		equip.TextColor3 = Color3.new(1, 1, 1)
		equip.ZIndex = 22
		equip.Parent = card
		corner(equip, 10)
		equip.Activated:Connect(function()
			local data = Progress.data()
			if data and not data.swords[id] then
				Progress.action("BuySword", id)
			else
				onEquip(id)
			end
			task.delay(0.4, refresh)
		end)
		equipButtons[id] = equip
	end

	open.Activated:Connect(function()
		panel.Visible = not panel.Visible
		open.Text = if panel.Visible then "Close" else "Swords"
		refresh()
	end)
	Progress.onChange(refresh)
end

return Armory
