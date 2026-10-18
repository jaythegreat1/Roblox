-- Echo HUD: the three Echo buttons and the Surge button (names, cooldown sweeps, Surge fill),
-- your own status effects, and the Blind darkness. Also the Echo loadout menu.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Shared.Combat.Echoes)

local EchoHud = {}

local player = Players.LocalPlayer

local function corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = if radius then UDim.new(0, radius) else UDim.new(1, 0)
	c.Parent = parent
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function attr(name: string): any
	local character = player.Character
	return character and character:GetAttribute(name)
end

-- Adds a dark cooldown sweep (fills from the top and drains) inside a round button.
local function addSweep(button: GuiObject): (Frame, TextLabel)
	local holder = Instance.new("Frame")
	holder.Name = "SweepHolder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ClipsDescendants = true
	holder.ZIndex = button.ZIndex + 1
	holder.Parent = button
	corner(holder)
	local sweep = Instance.new("Frame")
	sweep.Name = "Sweep"
	sweep.BackgroundColor3 = Color3.new(0, 0, 0)
	sweep.BackgroundTransparency = 0.35
	sweep.BorderSizePixel = 0
	sweep.AnchorPoint = Vector2.new(0, 1)
	sweep.Position = UDim2.fromScale(0, 1)
	sweep.Size = UDim2.fromScale(1, 0)
	sweep.ZIndex = holder.ZIndex
	sweep.Parent = holder
	local seconds = Instance.new("TextLabel")
	seconds.BackgroundTransparency = 1
	seconds.Size = UDim2.fromScale(1, 1)
	seconds.Font = Enum.Font.GothamBlack
	seconds.TextSize = 18
	seconds.TextColor3 = Color3.new(1, 1, 1)
	seconds.TextStrokeTransparency = 0.3
	seconds.Text = ""
	seconds.ZIndex = holder.ZIndex + 1
	seconds.Parent = holder
	return sweep, seconds
end

-- PC players get a row of slots at the bottom of the screen instead of touch buttons.
local function pcSlots(gui: ScreenGui): { [string]: TextButton }
	local slots = {}
	local keys = { Echo1 = "1", Echo2 = "2", Echo3 = "3", EchoSurge = "G" }
	for i, slot in Data.Slots do
		local b = Instance.new("TextButton")
		b.Name = slot
		b.AnchorPoint = Vector2.new(0.5, 1)
		b.Position = UDim2.new(0.5, (i - 2.5) * 74, 1, -16)
		b.Size = UDim2.fromOffset(66, 66)
		b.BackgroundColor3 = Color3.fromRGB(30, 26, 40)
		b.BackgroundTransparency = 0.2
		b.Font = Enum.Font.GothamBold
		b.TextSize = 11
		b.TextWrapped = true
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Parent = gui
		corner(b)
		local key = Instance.new("TextLabel")
		key.BackgroundTransparency = 1
		key.Position = UDim2.fromOffset(0, -16)
		key.Size = UDim2.new(1, 0, 0, 14)
		key.Font = Enum.Font.GothamBold
		key.TextSize = 12
		key.TextColor3 = Color3.fromRGB(200, 190, 230)
		key.Text = keys[slot]
		key.Parent = b
		slots[slot] = b
	end
	return slots
end

function EchoHud.build(gui: ScreenGui, buttons: { [string]: TextButton }?, Combat)
	local slots = buttons or pcSlots(gui)
	if not buttons then
		for slot, b in slots do
			b.Activated:Connect(function()
				Combat.castEcho(slot)
			end)
		end
	end
	local sweeps = {}
	for slot, b in slots do
		local sweep, seconds = addSweep(b)
		sweeps[slot] = { sweep = sweep, seconds = seconds }
		b.TextWrapped = true
		local stroke = b:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = b
	end

	-- Your statuses, under the health panel.
	local statusLine = Instance.new("TextLabel")
	statusLine.BackgroundTransparency = 1
	statusLine.Position = UDim2.fromOffset(18, 86)
	statusLine.Size = UDim2.fromOffset(320, 22)
	statusLine.Font = Enum.Font.GothamBold
	statusLine.TextSize = 14
	statusLine.TextXAlignment = Enum.TextXAlignment.Left
	statusLine.RichText = true
	statusLine.TextStrokeTransparency = 0.4
	statusLine.TextColor3 = Color3.new(1, 1, 1)
	statusLine.Text = ""
	statusLine.Parent = gui

	local blind = Instance.new("Frame")
	blind.Size = UDim2.fromScale(1, 1)
	blind.BackgroundColor3 = Color3.fromRGB(10, 0, 20)
	blind.BackgroundTransparency = 1
	blind.BorderSizePixel = 0
	blind.ZIndex = 0
	blind.Parent = gui

	local function hex(c: Color3): string
		return string.format("#%02x%02x%02x", c.R * 255, c.G * 255, c.B * 255)
	end

	RunService.Heartbeat:Connect(function()
		local t = serverNow()
		for slot, b in slots do
			local s = sweeps[slot]
			local e = Data.get(attr(slot))
			local stroke = b:FindFirstChildOfClass("UIStroke") :: UIStroke
			if slot == "EchoSurge" then
				local surge = attr("Surge")
				surge = if typeof(surge) == "number" then surge else 0
				local full = surge >= Data.Surge.max
				local burst = not full and Combat.canBurst()
				s.sweep.Size = UDim2.fromScale(1, 1 - surge / Data.Surge.max)
				s.seconds.Text = ""
				if burst then
					b.Text = "RIFT\nBURST"
					b.BackgroundColor3 = Color3.fromRGB(230, 60, 220)
				elseif full then
					b.Text = (if e then e.name else "SURGE") .. "\nREADY"
					b.BackgroundColor3 = Color3.fromRGB(255, 70, 110)
				else
					b.Text = `SURGE\n{math.floor(surge)}%`
					b.BackgroundColor3 = Color3.fromRGB(120, 90, 255)
				end
				stroke.Color = if full then Color3.fromRGB(255, 220, 120) else Color3.fromRGB(200, 180, 255)
				stroke.Thickness = if full then 3 + math.sin(os.clock() * 8) else 2
			elseif e then
				b.Text = e.name
				stroke.Color = Data.Elements[e.element].color
				b.BackgroundColor3 = Data.Elements[e.element].color:Lerp(Color3.new(0, 0, 0), 0.6)
				local readyAt = attr("CD_" .. e.id)
				local left = if typeof(readyAt) == "number" then readyAt - t else 0
				if left > 0 then
					s.sweep.Size = UDim2.fromScale(1, math.clamp(left / e.cooldown, 0, 1))
					s.seconds.Text = tostring(math.ceil(left))
				else
					s.sweep.Size = UDim2.fromScale(1, 0)
					s.seconds.Text = ""
				end
			else
				b.Text = "Empty"
			end
		end

		-- Status effects on you.
		local parts = {}
		for name, info in Data.Statuses do
			local untilTime = attr("Status_" .. name)
			if typeof(untilTime) == "number" and untilTime > t then
				table.insert(
					parts,
					`<font color="{hex(info.color)}">{string.upper(name)} {string.format("%.1f", untilTime - t)}s</font>`
				)
			end
		end
		local cry = attr("BattleCryUntil")
		if typeof(cry) == "number" and cry > t then
			table.insert(parts, `<font color="#ff6ad5">BATTLE CRY {string.format("%.1f", cry - t)}s</font>`)
		end
		statusLine.Text = table.concat(parts, "   ")

		-- Blind: darkness closes in, enemy health bars vanish, and lock-on breaks.
		local blindUntil = attr("Status_Blind")
		local blinded = typeof(blindUntil) == "number" and blindUntil > t
		blind.BackgroundTransparency = if blinded then 0.25 else 1
		if blinded then
			Combat.unlock()
		end
		for _, p in Players:GetPlayers() do
			local overhead = p ~= player and p.Character and p.Character:FindFirstChild("Overhead", true)
			if overhead and overhead:IsA("BillboardGui") then
				overhead.Enabled = not blinded
			end
		end
		for _, m in game:GetService("CollectionService"):GetTagged("BladeRiftRig") do
			local overhead = m:FindFirstChild("Overhead", true)
			if overhead and overhead:IsA("BillboardGui") then
				overhead.Enabled = not blinded
			end
		end
	end)

	EchoHud.buildMenu(gui, Combat)
end

-- The loadout menu: every Echo, grouped by element, with buttons to slot it.
function EchoHud.buildMenu(gui: ScreenGui, Combat)
	local open = Instance.new("TextButton")
	open.Name = "EchoesButton"
	open.AnchorPoint = Vector2.new(1, 0)
	open.Position = UDim2.new(1, -16, 0, 58)
	open.Size = UDim2.fromOffset(96, 36)
	open.BackgroundColor3 = Color3.fromRGB(255, 110, 60)
	open.BackgroundTransparency = 0.15
	open.Font = Enum.Font.GothamBold
	open.TextSize = 15
	open.TextColor3 = Color3.new(1, 1, 1)
	open.Text = "Echoes"
	open.Parent = gui
	corner(open, 10)

	local panel = Instance.new("ScrollingFrame")
	panel.Name = "EchoMenu"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.86, 0.84)
	panel.BackgroundColor3 = Color3.fromRGB(20, 18, 28)
	panel.BackgroundTransparency = 0.06
	panel.ScrollBarThickness = 6
	panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
	panel.CanvasSize = UDim2.new()
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
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	local function label(text: string, size: number, color: Color3, order: number, height: number)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, height)
		l.Font = Enum.Font.GothamBlack
		l.TextSize = size
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextWrapped = true
		l.TextColor3 = color
		l.Text = text
		l.LayoutOrder = order
		l.ZIndex = 21
		l.Parent = panel
		return l
	end

	label("Echo Loadout", 22, Color3.new(1, 1, 1), 0, 28)
	label(
		"All Echoes are unlocked for testing. Quests and capacity limits arrive with progression. Change Echoes out of combat; Mythics go in the Surge slot and fire when Surge is full.",
		13,
		Color3.fromRGB(200, 195, 220),
		1,
		36
	)
	local current = label("", 14, Color3.fromRGB(255, 220, 120), 2, 40)
	current.RichText = true

	local slotButtons: { { button: TextButton, slot: string, id: string } } = {}
	local order = 3
	local lastElement = nil
	for _, e in Data.List do
		if e.element ~= lastElement then
			lastElement = e.element
			order += 1
			label(string.upper(e.element), 16, Data.Elements[e.element].color, order, 22)
		end
		order += 1
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, 0, 0, 84)
		card.BackgroundColor3 = Color3.fromRGB(38, 34, 52)
		card.LayoutOrder = order
		card.ZIndex = 21
		card.Parent = panel
		corner(card, 10)
		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(0, 5, 1, 0)
		bar.BackgroundColor3 = Data.Rarity[e.rarity].color
		bar.BorderSizePixel = 0
		bar.ZIndex = 22
		bar.Parent = card

		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromOffset(14, 5)
		title.Size = UDim2.new(1, -170, 0, 20)
		title.Font = Enum.Font.GothamBold
		title.TextSize = 16
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = Data.Rarity[e.rarity].color
		title.Text = e.name
		title.ZIndex = 22
		title.Parent = card

		local meta = Instance.new("TextLabel")
		meta.BackgroundTransparency = 1
		meta.Position = UDim2.fromOffset(14, 25)
		meta.Size = UDim2.new(1, -170, 0, 16)
		meta.Font = Enum.Font.GothamMedium
		meta.TextSize = 12
		meta.TextXAlignment = Enum.TextXAlignment.Left
		meta.TextColor3 = Color3.fromRGB(180, 175, 200)
		meta.Text = if e.rarity == "Mythic"
			then `Mythic · {e.type} · full Surge`
			else `{e.rarity} · {e.type} · {e.cooldown} s · cost {Data.Rarity[e.rarity].cost}`
		meta.ZIndex = 22
		meta.Parent = card

		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Position = UDim2.fromOffset(14, 42)
		text.Size = UDim2.new(1, -170, 0, 38)
		text.Font = Enum.Font.Gotham
		text.TextSize = 12
		text.TextWrapped = true
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextYAlignment = Enum.TextYAlignment.Top
		text.TextColor3 = Color3.fromRGB(225, 220, 240)
		text.Text = e.text
		text.ZIndex = 22
		text.Parent = card

		local targets = if e.rarity == "Mythic" then { "EchoSurge" } else { "Echo1", "Echo2", "Echo3" }
		for i, slot in targets do
			local b = Instance.new("TextButton")
			b.AnchorPoint = Vector2.new(1, 0.5)
			b.Position = UDim2.new(1, -10 - (#targets - i) * 50, 0.5, 0)
			b.Size = UDim2.fromOffset(if slot == "EchoSurge" then 96 else 44, 44)
			b.Font = Enum.Font.GothamBold
			b.TextSize = 15
			b.TextColor3 = Color3.new(1, 1, 1)
			b.Text = if slot == "EchoSurge" then "Surge" else tostring(i)
			b.ZIndex = 22
			b.Parent = card
			corner(b, 10)
			b.Activated:Connect(function()
				Combat.setLoadout(slot, e.id)
			end)
			table.insert(slotButtons, { button = b, slot = slot, id = e.id })
		end
	end

	local function refresh()
		for _, sb in slotButtons do
			local equipped = attr(sb.slot) == sb.id
			sb.button.BackgroundColor3 = if equipped then Color3.fromRGB(60, 160, 100) else Color3.fromRGB(90, 70, 160)
		end
		local names = {}
		for i, slot in Data.Slots do
			local e = Data.get(attr(slot))
			local key = if slot == "EchoSurge" then "Surge" else tostring(i)
			table.insert(names, `{key}: <b>{if e then e.name else "empty"}</b>`)
		end
		local attuned = if attr("Attuned") then "   ·   Attuned: statuses last 15% longer" else ""
		current.Text = table.concat(names, "   ") .. attuned
	end

	open.Activated:Connect(function()
		panel.Visible = not panel.Visible
		open.Text = if panel.Visible then "Close" else "Echoes"
	end)
	RunService.Heartbeat:Connect(function()
		if panel.Visible then
			refresh()
		end
	end)
end

return EchoHud
