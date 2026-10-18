-- Client entry: HUD, phone buttons, movement, combat and error reporting.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptContext = game:GetService("ScriptContext")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage.Shared.Config)
local Engine = require(ReplicatedStorage.Shared.Anim.Engine)
local Movement = require(script.Parent.Movement)
local Combat = require(script.Parent.Combat)
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild(Config.RemoteFolderName)
local clientError = remotes:WaitForChild("ClientError") :: RemoteEvent
local actionRemote = remotes:WaitForChild("Action") :: RemoteEvent

Engine.start()
Movement.start(actionRemote)
Combat.start(remotes, Movement)

-- Other players' moves arrive here and play on their characters locally.
actionRemote.OnClientEvent:Connect(function(who: Player, name: string)
	if who ~= player and who.Character then
		Engine.play(who.Character, name)
	end
end)

ScriptContext.Error:Connect(function(message, trace)
	clientError:FireServer(message, trace)
end)

local gui = Instance.new("ScreenGui")
gui.Name = "BladeRiftHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local version = Instance.new("TextLabel")
version.BackgroundTransparency = 1
version.Position = UDim2.new(0, 12, 1, -28)
version.Size = UDim2.fromOffset(300, 20)
version.TextXAlignment = Enum.TextXAlignment.Left
version.Font = Enum.Font.GothamMedium
version.TextSize = 14
version.TextColor3 = Color3.fromRGB(230, 220, 255)
version.Text = `Blade Rift {Config.Version}`
version.Parent = gui

local feedback = Instance.new("TextLabel")
feedback.BackgroundTransparency = 1
feedback.AnchorPoint = Vector2.new(0.5, 0)
feedback.Position = UDim2.new(0.5, 0, 0, 60)
feedback.Size = UDim2.fromOffset(300, 30)
feedback.Font = Enum.Font.GothamBold
feedback.TextSize = 22
feedback.TextColor3 = Color3.new(1, 1, 1)
feedback.TextStrokeTransparency = 0.5
feedback.Text = ""
feedback.Parent = gui

-- Buttons sit in the right-thumb cluster; positions mirror the master plan mock-up.
local function button(name: string, x: number, y: number, size: number, accent: boolean?, onTap: (() -> ())?)
	local b = Instance.new("TextButton")
	b.Name = name
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.new(1, x, 1, y)
	b.Size = UDim2.fromOffset(size, size)
	b.BackgroundColor3 = if accent then Color3.fromRGB(120, 90, 255) else Color3.fromRGB(30, 26, 40)
	b.BackgroundTransparency = 0.25
	b.Font = Enum.Font.GothamBold
	b.TextSize = if size > 70 then 18 else 13
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = name
	b.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(200, 180, 255)
	stroke.Transparency = 0.4
	stroke.Parent = b
	b.Parent = gui
	b.Activated:Connect(function()
		if onTap then
			onTap()
			return
		end
		feedback.Text = name .. " (coming later)"
		task.delay(0.6, function()
			if feedback.Text == name .. " (coming later)" then
				feedback.Text = ""
			end
		end)
	end)
	return b
end

if UserInputService.TouchEnabled then
	local attack = button("Attack", -110, -110, 88, true, function() end)
	attack.MouseButton1Down:Connect(Combat.attackDown)
	attack.MouseButton1Up:Connect(Combat.attackUp)
	attack.MouseLeave:Connect(Combat.attackUp)
	local block = button("Block", -210, -70, 56, false, function() end)
	block.MouseButton1Down:Connect(Combat.blockDown)
	block.MouseButton1Up:Connect(Combat.blockUp)
	block.MouseLeave:Connect(Combat.blockUp)
	local dodge = button("Dodge", -175, -185, 56, false, Movement.dodge)
	button("Dash", -255, -150, 48, false, Movement.dash)
	local grab = button("Grab", -285, -60, 48, false, Combat.grabOrFinish)
	button("Echo 1", -275, -245, 50)
	button("Echo 2", -205, -285, 50)
	button("Echo 3", -135, -295, 50)
	button("Surge", -60, -265, 56, true)
	local lock = button("Lock", -330, -210, 42, false, Combat.toggleLock)
	Combat.onLock(function(on)
		lock.BackgroundColor3 = if on then Color3.fromRGB(255, 80, 120) else Color3.fromRGB(30, 26, 40)
	end)
	-- The Grab button turns into FINISH when an enemy can be finished.
	RunService.Heartbeat:Connect(function()
		local canFinish = Combat.finishTarget() ~= nil
		grab.Text = if canFinish then "FINISH" else "Grab"
		grab.BackgroundColor3 = if canFinish then Color3.fromRGB(220, 60, 200) else Color3.fromRGB(30, 26, 40)
	end)
	local sprint = button("Sprint", -340, -110, 48, false, function() end)
	sprint.Activated:Connect(function()
		Movement.toggleSprint()
		sprint.BackgroundColor3 = if sprint.BackgroundColor3 == Color3.fromRGB(30, 26, 40)
			then Color3.fromRGB(120, 90, 255)
			else Color3.fromRGB(30, 26, 40)
	end)
	Movement.onCharges(function(n)
		dodge.Text = "Dodge\n" .. string.rep("● ", n) .. string.rep("○ ", 2 - n)
	end)
end

-- Health, posture and combo counter (top left).
local panel = Instance.new("Frame")
panel.BackgroundColor3 = Color3.fromRGB(20, 18, 28)
panel.BackgroundTransparency = 0.35
panel.Position = UDim2.fromOffset(16, 16)
panel.Size = UDim2.fromOffset(230, 52)
panel.Parent = gui
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = panel

local function hudBar(y: number, height: number, color: Color3): Frame
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(10, y)
	back.Size = UDim2.new(1, -20, 0, height)
	back.BackgroundColor3 = Color3.fromRGB(45, 40, 60)
	back.BorderSizePixel = 0
	back.Parent = panel
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back
	return fill
end

local healthFill = hudBar(10, 16, Color3.fromRGB(90, 220, 120))
local postureFill = hudBar(32, 9, Color3.fromRGB(250, 200, 70))
local healthText = Instance.new("TextLabel")
healthText.BackgroundTransparency = 1
healthText.Position = UDim2.fromOffset(10, 10)
healthText.Size = UDim2.new(1, -20, 0, 16)
healthText.Font = Enum.Font.GothamBold
healthText.TextSize = 12
healthText.TextColor3 = Color3.new(1, 1, 1)
healthText.ZIndex = 2
healthText.Parent = panel

local combo = Instance.new("TextLabel")
combo.BackgroundTransparency = 1
combo.AnchorPoint = Vector2.new(1, 0.5)
combo.Position = UDim2.new(1, -24, 0.4, 0)
combo.Size = UDim2.fromOffset(200, 50)
combo.Font = Enum.Font.GothamBlack
combo.TextSize = 34
combo.TextXAlignment = Enum.TextXAlignment.Right
combo.TextColor3 = Color3.fromRGB(255, 220, 120)
combo.TextStrokeTransparency = 0.3
combo.Text = ""
combo.Parent = gui
local comboClearAt = 0
Combat.onCombo(function(n)
	combo.Text = if n >= 2 then `{n} HITS` else ""
	comboClearAt = os.clock() + 1.5
end)

RunService.Heartbeat:Connect(function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		healthFill.Size = UDim2.fromScale(math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1), 1)
		healthText.Text = `{math.ceil(humanoid.Health)} / {humanoid.MaxHealth}`
		local p = character:GetAttribute("Posture")
		postureFill.Size = UDim2.fromScale(math.clamp((if typeof(p) == "number" then p else 100) / 100, 0, 1), 1)
	end
	if os.clock() > comboClearAt then
		combo.Text = ""
	end
end)

-- Defeat overlay and a clean camera hand-off on respawn.
local defeat = Instance.new("TextLabel")
defeat.BackgroundColor3 = Color3.new(0, 0, 0)
defeat.BackgroundTransparency = 1
defeat.Size = UDim2.fromScale(1, 1)
defeat.Font = Enum.Font.GothamBlack
defeat.TextSize = 40
defeat.TextColor3 = Color3.fromRGB(255, 120, 230)
defeat.TextStrokeTransparency = 0.3
defeat.Text = ""
defeat.Visible = false
defeat.ZIndex = 10
defeat.Parent = gui

local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = humanoid
	defeat.Visible = false
	humanoid.Died:Connect(function()
		defeat.Visible = true
		defeat.BackgroundTransparency = 0.6
		for i = Config.RespawnTime, 1, -1 do
			if not defeat.Visible then
				return
			end
			defeat.Text = `DEFEATED\nRespawning in {i}`
			task.wait(1)
		end
	end)
end
if player.Character then
	task.spawn(onCharacter, player.Character)
end
player.CharacterAdded:Connect(onCharacter)
