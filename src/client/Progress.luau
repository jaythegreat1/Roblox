-- Progression on screen: level and XP bar, coins, the quest tracker, the Quest Journal with
-- daily tasks, level-up and reward pop-ups (with the Echo reveal), and the owner's dev panel.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progression = require(ReplicatedStorage.Shared.Progression)
local EchoData = require(ReplicatedStorage.Shared.Combat.Echoes)
local Swords = require(ReplicatedStorage.Shared.Combat.Swords)
local Engine = require(ReplicatedStorage.Shared.Anim.Engine)

local Progress = {}

local player = Players.LocalPlayer
local snapshot: any = nil
local listeners: { () -> () } = {}
local actionRemote: RemoteEvent

function Progress.data()
	return snapshot
end

function Progress.onChange(fn: () -> ())
	table.insert(listeners, fn)
	if snapshot then
		fn()
	end
end

function Progress.action(name: string, arg: any?)
	actionRemote:FireServer(name, arg)
end

local function corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = parent
end

local function label(parent: Instance, props): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.5
	l.TextXAlignment = Enum.TextXAlignment.Left
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, color: Color3, props): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextSize = 14
	b.Text = text
	for k, v in props or {} do
		(b :: any)[k] = v
	end
	b.Parent = parent
	corner(b)
	return b
end

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function questState(quest)
	if snapshot.completed[quest.id] then
		return "done"
	elseif quest.soon then
		return "soon"
	elseif snapshot.level < quest.level then
		return "level"
	end
	local prev = Progression.previous(quest)
	if prev and not snapshot.completed[prev.id] then
		return "previous"
	end
	return "open"
end

local function stepText(quest): (string, number, number)
	local state = snapshot.quests[quest.id] or { step = 1, n = 0 }
	local step = quest.steps[state.step] or quest.steps[#quest.steps]
	return step.text, math.floor(state.n), step.count
end

-- Pop-ups --------------------------------------------------------------------------------------

local popupQueue: { () -> () } = {}
local popupBusy = false

local function runPopups()
	if popupBusy then
		return
	end
	popupBusy = true
	task.spawn(function()
		while #popupQueue > 0 do
			table.remove(popupQueue, 1)()
		end
		popupBusy = false
	end)
end

local function banner(gui: ScreenGui, title: string, subtitle: string, color: Color3, seconds: number)
	table.insert(popupQueue, function()
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0)
		frame.Position = UDim2.new(0.5, 0, 0, -90)
		frame.Size = UDim2.fromOffset(360, 74)
		frame.BackgroundColor3 = Color3.fromRGB(20, 16, 30)
		frame.BackgroundTransparency = 0.1
		frame.ZIndex = 40
		frame.Parent = gui
		corner(frame, 14)
		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = 2
		stroke.Parent = frame
		label(frame, {
			Position = UDim2.fromOffset(14, 6),
			Size = UDim2.new(1, -28, 0, 30),
			Font = Enum.Font.GothamBlack,
			TextSize = 22,
			TextColor3 = color,
			Text = title,
			ZIndex = 41,
		})
		label(frame, {
			Position = UDim2.fromOffset(14, 36),
			Size = UDim2.new(1, -28, 0, 34),
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = subtitle,
			ZIndex = 41,
		})
		TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 70) })
			:Play()
		task.wait(seconds)
		TweenService:Create(frame, TweenInfo.new(0.25), { Position = UDim2.new(0.5, 0, 0, -90) }):Play()
		task.wait(0.3)
		frame:Destroy()
	end)
	runPopups()
end

-- The reveal moment: a name card in the Echo's rarity colour while you perform it once.
local function reveal(gui: ScreenGui, id: string)
	local e = EchoData.get(id)
	if not e then
		return
	end
	table.insert(popupQueue, function()
		local color = EchoData.Rarity[e.rarity].color
		local dim = Instance.new("Frame")
		dim.Size = UDim2.fromScale(1, 1)
		dim.BackgroundColor3 = Color3.new(0, 0, 0)
		dim.BackgroundTransparency = 1
		dim.ZIndex = 45
		dim.Parent = gui
		TweenService:Create(dim, TweenInfo.new(0.3), { BackgroundTransparency = 0.55 }):Play()
		local card = Instance.new("Frame")
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.fromScale(0.5, 0.32)
		card.Size = UDim2.fromOffset(20, 120)
		card.BackgroundColor3 = Color3.fromRGB(18, 14, 26)
		card.ZIndex = 46
		card.ClipsDescendants = true
		card.Parent = gui
		corner(card, 16)
		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = 3
		stroke.Parent = card
		label(card, {
			Position = UDim2.fromOffset(0, 10),
			Size = UDim2.new(1, 0, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = 13,
			TextColor3 = color,
			Text = `NEW ECHO · {string.upper(e.rarity)} {string.upper(e.element)}`,
			ZIndex = 47,
		})
		label(card, {
			Position = UDim2.fromOffset(0, 30),
			Size = UDim2.new(1, 0, 0, 40),
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Enum.Font.GothamBlack,
			TextSize = 34,
			TextColor3 = Color3.new(1, 1, 1),
			Text = e.name,
			ZIndex = 47,
		})
		label(card, {
			Position = UDim2.fromOffset(16, 74),
			Size = UDim2.new(1, -32, 0, 40),
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextWrapped = true,
			Text = e.text,
			ZIndex = 47,
		})
		TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(420, 120) })
			:Play()
		Engine.play(player.Character, e.anim)
		task.wait(3)
		TweenService:Create(dim, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(card, TweenInfo.new(0.25), { Size = UDim2.fromOffset(20, 120) }):Play()
		task.wait(0.3)
		dim:Destroy()
		card:Destroy()
	end)
	runPopups()
end

-- HUD: level, XP, coins and the tracker ------------------------------------------------------

local function buildHud(gui: ScreenGui)
	local row = Instance.new("Frame")
	row.Name = "LevelRow"
	row.Position = UDim2.fromOffset(16, 84)
	row.Size = UDim2.fromOffset(230, 26)
	row.BackgroundColor3 = Color3.fromRGB(20, 18, 28)
	row.BackgroundTransparency = 0.35
	row.Parent = gui
	corner(row, 8)
	local level = label(row, {
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.fromOffset(50, 26),
		Font = Enum.Font.GothamBlack,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(255, 220, 120),
		Text = "Lv 1",
	})
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(56, 9)
	back.Size = UDim2.fromOffset(92, 8)
	back.BackgroundColor3 = Color3.fromRGB(45, 40, 60)
	back.BorderSizePixel = 0
	back.Parent = row
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(110, 200, 255)
	fill.BorderSizePixel = 0
	fill.Parent = back
	local coins = label(row, {
		Position = UDim2.fromOffset(152, 0),
		Size = UDim2.fromOffset(74, 26),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(255, 210, 90),
		Text = "0",
	})

	-- Tracked quests, top right under the menu buttons.
	local tracker = Instance.new("Frame")
	tracker.Name = "Tracker"
	tracker.AnchorPoint = Vector2.new(1, 0)
	tracker.Position = UDim2.new(1, -16, 0, 146)
	tracker.Size = UDim2.fromOffset(250, 10)
	tracker.AutomaticSize = Enum.AutomaticSize.Y
	tracker.BackgroundTransparency = 1
	tracker.Parent = gui
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.Parent = tracker

	Progress.onChange(function()
		level.Text = `Lv {snapshot.level}`
		fill.Size = UDim2.fromScale(math.clamp(snapshot.xp / math.max(snapshot.xpNext, 1), 0, 1), 1)
		coins.Text = `{commas(snapshot.coins)} ◎`
		for _, c in tracker:GetChildren() do
			if c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		for i, id in snapshot.tracked do
			local quest = Progression.QuestById[id]
			if quest then
				local text, n, count = stepText(quest)
				label(tracker, {
					Size = UDim2.fromOffset(250, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					TextXAlignment = Enum.TextXAlignment.Right,
					TextWrapped = true,
					RichText = true,
					TextSize = 13,
					LayoutOrder = i,
					Text = `<font color="#ffd27a">{quest.name}</font>\n{text} <b>{n}/{count}</b>`,
				})
			end
		end
	end)
end

-- Quest Journal -------------------------------------------------------------------------------

local function buildJournal(gui: ScreenGui)
	local open = button(gui, "Quests", Color3.fromRGB(70, 170, 110), {
		Name = "QuestsButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 100),
		Size = UDim2.fromOffset(96, 36),
		BackgroundTransparency = 0.15,
		TextSize = 15,
	})
	local panel = Instance.new("ScrollingFrame")
	panel.Name = "Journal"
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
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	local function rebuild()
		for _, c in panel:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local order = 0
		local function heading(text: string, color: Color3, size: number?)
			order += 1
			label(panel, {
				Size = UDim2.new(1, 0, 0, (size or 16) + 8),
				Font = Enum.Font.GothamBlack,
				TextSize = size or 16,
				TextColor3 = color,
				Text = text,
				LayoutOrder = order,
				ZIndex = 21,
			})
		end
		heading(`Quest Journal  ·  Level {snapshot.level}`, Color3.new(1, 1, 1), 22)

		-- Daily tasks.
		local xp, coins = Progression.dailyReward(snapshot.level)
		heading(
			`DAILY TASKS  ·  {xp} XP + {coins} coins each  ·  rerolls left: {snapshot.daily.rerolls}`,
			Color3.fromRGB(255, 210, 90),
			14
		)
		for i, entry in snapshot.daily.tasks do
			local task_ = nil
			for _, t in Progression.Daily do
				if t.id == entry.id then
					task_ = t
				end
			end
			if task_ then
				order += 1
				local card = Instance.new("Frame")
				card.Size = UDim2.new(1, 0, 0, 40)
				card.BackgroundColor3 = if entry.done then Color3.fromRGB(40, 70, 50) else Color3.fromRGB(38, 34, 52)
				card.LayoutOrder = order
				card.ZIndex = 21
				card.Parent = panel
				corner(card, 8)
				label(card, {
					Position = UDim2.fromOffset(12, 0),
					Size = UDim2.new(1, -110, 1, 0),
					TextSize = 14,
					Text = `{if entry.done then "✓ " else ""}{task_.text}  {math.floor(entry.n)}/{task_.count}`,
					ZIndex = 22,
				})
				if not entry.done and snapshot.daily.rerolls > 0 then
					local b = button(card, "Reroll", Color3.fromRGB(90, 70, 160), {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -8, 0.5, 0),
						Size = UDim2.fromOffset(80, 30),
						ZIndex = 22,
					})
					b.Activated:Connect(function()
						Progress.action("Reroll", i)
					end)
				end
			end
		end

		for _, path in Progression.Paths do
			heading(`{string.upper(path.name)}  ·  {path.keeper}`, path.color, 15)
			for _, quest in Progression.Quests do
				if quest.path == path.id then
					order += 1
					local state = questState(quest)
					local card = Instance.new("Frame")
					card.Size = UDim2.new(1, 0, 0, 58)
					card.BackgroundColor3 = if state == "done"
						then Color3.fromRGB(40, 70, 50)
						elseif state == "open" then Color3.fromRGB(45, 40, 64)
						else Color3.fromRGB(32, 30, 40)
					card.LayoutOrder = order
					card.ZIndex = 21
					card.Parent = panel
					corner(card, 8)
					local tier = Progression.Tiers[quest.tier]
					local reward = if quest.reward then EchoData.get(quest.reward) else nil
					label(card, {
						Position = UDim2.fromOffset(12, 4),
						Size = UDim2.new(1, -120, 0, 20),
						TextSize = 15,
						TextColor3 = if state == "open" or state == "done"
							then Color3.new(1, 1, 1)
							else Color3.fromRGB(150, 145, 165),
						Text = `{quest.name}  ·  Tier {tier.name} · Lv {quest.level}{if reward
							then "  ·  " .. reward.name
							else ""}`,
						ZIndex = 22,
					})
					local detail
					if state == "done" then
						detail = "✓ Complete"
					elseif state == "soon" then
						detail = quest.soon
					elseif state == "level" then
						detail = `Locked: reach level {quest.level}`
					elseif state == "previous" then
						detail = `Locked: finish {Progression.previous(quest).name} first`
					else
						local text, n, count = stepText(quest)
						local s = snapshot.quests[quest.id]
						detail = `Step {s and s.step or 1}/{#quest.steps}: {text}  {n}/{count}`
					end
					label(card, {
						Position = UDim2.fromOffset(12, 26),
						Size = UDim2.new(1, -120, 0, 28),
						Font = Enum.Font.GothamMedium,
						TextSize = 12,
						TextWrapped = true,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextColor3 = Color3.fromRGB(205, 200, 225),
						Text = detail,
						ZIndex = 22,
					})
					if state == "open" then
						local tracked = table.find(snapshot.tracked, quest.id) ~= nil
						local b = button(
							card,
							if tracked then "Tracking" else "Track",
							if tracked then Color3.fromRGB(60, 160, 100) else Color3.fromRGB(90, 70, 160),
							{
								AnchorPoint = Vector2.new(1, 0.5),
								Position = UDim2.new(1, -8, 0.5, 0),
								Size = UDim2.fromOffset(96, 34),
								ZIndex = 22,
							}
						)
						b.Activated:Connect(function()
							Progress.action("Track", quest.id)
						end)
					end
				end
			end
		end
	end

	open.Activated:Connect(function()
		panel.Visible = not panel.Visible
		open.Text = if panel.Visible then "Close" else "Quests"
		if panel.Visible then
			rebuild()
		end
	end)
	Progress.onChange(function()
		if panel.Visible then
			rebuild()
		end
	end)
end

-- Developer panel (only the game's owner sees it) ------------------------------------------------

local function buildDev(gui: ScreenGui)
	local open = button(gui, "DEV", Color3.fromRGB(200, 60, 60), {
		Position = UDim2.new(0, 12, 1, -64),
		Size = UDim2.fromOffset(52, 30),
		TextSize = 13,
		Visible = false,
	})
	local panel = Instance.new("Frame")
	panel.Position = UDim2.new(0, 12, 1, -300)
	panel.Size = UDim2.fromOffset(200, 228)
	panel.BackgroundColor3 = Color3.fromRGB(30, 20, 24)
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.ZIndex = 30
	panel.Parent = gui
	corner(panel, 10)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.Parent = panel
	local resetArmed = false
	for _, entry in
		{
			{ "+1 Level", "DevLevel", 1 },
			{ "+10 Levels", "DevLevel", 10 },
			{ "+5,000 Coins", "DevCoins" },
			{ "Unlock everything", "DevUnlockAll" },
			{ "Reset progress", "DevReset" },
		}
	do
		local b = button(panel, entry[1], Color3.fromRGB(90, 50, 60), { Size = UDim2.fromOffset(180, 34), ZIndex = 31 })
		b.Activated:Connect(function()
			if entry[2] == "DevReset" and not resetArmed then
				resetArmed = true
				b.Text = "Tap again to reset"
				task.delay(3, function()
					resetArmed = false
					b.Text = entry[1]
				end)
				return
			end
			Progress.action(entry[2], entry[3])
		end)
	end
	open.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
	Progress.onChange(function()
		open.Visible = snapshot.dev == true
	end)
end

function Progress.start(remotes: Folder, gui: ScreenGui)
	actionRemote = remotes:WaitForChild("ProfileAction") :: RemoteEvent
	local snapshotRemote = remotes:WaitForChild("ProfileSnapshot") :: RemoteEvent
	local eventRemote = remotes:WaitForChild("ProfileEvent") :: RemoteEvent
	buildHud(gui)
	buildJournal(gui)
	buildDev(gui)
	snapshotRemote.OnClientEvent:Connect(function(data)
		snapshot = data
		for _, fn in listeners do
			task.spawn(fn)
		end
	end)
	eventRemote.OnClientEvent:Connect(function(kind, payload)
		if kind == "levelup" then
			local lines = { `+{commas(payload.coins)} coins` }
			for _, u in payload.unlocked do
				table.insert(lines, u)
			end
			banner(gui, `LEVEL {payload.level}!`, table.concat(lines, "  ·  "), Color3.fromRGB(255, 220, 120), 3)
		elseif kind == "quest" then
			local quest = Progression.QuestById[payload.id]
			banner(
				gui,
				"QUEST COMPLETE",
				`{quest and quest.name or ""}  ·  +{commas(payload.xp)} XP  ·  +{commas(payload.coins)} coins`,
				Color3.fromRGB(120, 230, 150),
				2.5
			)
			if payload.echo then
				reveal(gui, payload.echo)
			end
		elseif kind == "step" then
			local quest = Progression.QuestById[payload.quest]
			if quest then
				banner(gui, quest.name, `Next: {quest.steps[payload.step].text}`, Color3.fromRGB(200, 190, 255), 2)
			end
		elseif kind == "daily" then
			banner(
				gui,
				"DAILY TASK DONE",
				`{payload.text}  ·  +{commas(payload.xp)} XP  ·  +{commas(payload.coins)} coins`,
				Color3.fromRGB(255, 210, 90),
				2.5
			)
		elseif kind == "reward" and payload.kind == "sword" then
			banner(
				gui,
				"NEW SWORD",
				`{Swords.get(payload.id).name} is yours. Equip it in the Armory.`,
				Color3.fromRGB(120, 90, 255),
				2.5
			)
		elseif kind == "notice" then
			banner(gui, "", tostring(payload), Color3.fromRGB(220, 220, 255), 2.5)
		end
	end)
	actionRemote:FireServer("Refresh")
end

Progress.commas = commas

return Progress
