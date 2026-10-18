--!strict
-- Phase 0 client: phone-first button layout, sprint, and error reporting.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptContext = game:GetService("ScriptContext")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild(Config.RemoteFolderName)
local clientError = remotes:WaitForChild("ClientError") :: RemoteEvent

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
local function button(name: string, x: number, y: number, size: number, accent: boolean?)
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
		feedback.Text = name
		task.delay(0.6, function()
			if feedback.Text == name then
				feedback.Text = ""
			end
		end)
	end)
	return b
end

if UserInputService.TouchEnabled then
	button("Attack", -110, -110, 88, true)
	button("Block", -210, -70, 56)
	button("Dodge", -175, -185, 56)
	button("Dash", -255, -150, 48)
	button("Grab", -285, -60, 48)
	button("Echo 1", -275, -245, 50)
	button("Echo 2", -205, -285, 50)
	button("Echo 3", -135, -295, 50)
	button("Surge", -60, -265, 56, true)
	button("Lock", -330, -210, 42)
end

-- Sprint: Shift on PC, joystick at its edge on phones (approximated by move speed input).
local function setSpeed(sprinting: boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = if sprinting then Config.Character.SprintSpeed else Config.Character.WalkSpeed
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.LeftShift then
		setSpeed(true)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		setSpeed(false)
	end
end)
