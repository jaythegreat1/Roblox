--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Config = require(ReplicatedStorage.Shared.Config)
local Engine = require(ReplicatedStorage.Shared.Anim.Engine)

local remotes = Instance.new("Folder")
remotes.Name = Config.RemoteFolderName
local clientError = Instance.new("RemoteEvent")
clientError.Name = "ClientError"
clientError.Parent = remotes
local action = Instance.new("RemoteEvent")
action.Name = "Action"
action.Parent = remotes

local Combat = require(script.Parent.Combat)
Combat.start(remotes)
local Echoes = require(script.Parent.Echoes)
Echoes.start(remotes)
local Profile = require(script.Parent.Profile)
Profile.start(remotes)
local Quests = require(script.Parent.Quests)
Quests.start()
-- Only swords you own and Echoes you have earned (within your Echo Capacity) can be equipped.
Combat.canEquipSword = Profile.ownsSword
Echoes.canEquip = Profile.canEquipEcho
remotes.Parent = ReplicatedStorage

local ErrorLog = require(script.Parent.ErrorLog)
ErrorLog.start(clientError)

local DODGES = { RollForward = true, RollBack = true, CartwheelLeft = true, CartwheelRight = true }

-- Relay movement animations so every client can play them on the mover's character.
local lastAction: { [Player]: { number } } = {}
action.OnServerEvent:Connect(function(player, name)
	if typeof(name) ~= "string" or not Engine.exists(name) then
		return
	end
	local stamps = lastAction[player] or {}
	local now = os.clock()
	while stamps[1] and now - stamps[1] > 1 do
		table.remove(stamps, 1)
	end
	if #stamps >= 8 then
		return
	end
	table.insert(stamps, now)
	lastAction[player] = stamps
	Quests.onAction(player, name)
	local character = player.Character
	if character and DODGES[name] then
		-- Rolls are invulnerable for their first 0.25 s; the server is the one that checks it.
		character:SetAttribute("InvulnerableUntil", workspace:GetServerTimeNow() + Config.Movement.RollIFrames)
		-- A dodge roll puts out Burn.
		character:SetAttribute("Status_Burn", nil)
		Echoes.onDodge(character)
	end
	for _, other in Players:GetPlayers() do
		if other ~= player then
			action:FireClient(other, player, name)
		end
	end
end)
Players.PlayerRemoving:Connect(function(player)
	lastAction[player] = nil
end)

local spawnPad = require(script.Parent.Arena).build()
local Sword = require(script.Parent.Sword)
local Overhead = require(script.Parent.Overhead)
require(script.Parent.Characters).start(spawnPad, function(model, player)
	Profile.waitLoaded(player)
	Sword.attach(model, player:GetAttribute("SwordId") :: string?)
	Overhead.attach(model, player.DisplayName, player)
	Combat.register(model)
	Echoes.setup(model, player)
end)
require(script.Parent.Dummies).spawn(spawnPad.Position)
require(script.Parent.Bot).spawn(spawnPad.Position + Vector3.new(0, 0, 40))

print(`Blade Rift server started, version {Config.Version}`)
