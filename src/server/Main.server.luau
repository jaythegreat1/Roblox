--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local remotes = Instance.new("Folder")
remotes.Name = Config.RemoteFolderName
local clientError = Instance.new("RemoteEvent")
clientError.Name = "ClientError"
clientError.Parent = remotes
local action = Instance.new("RemoteEvent")
action.Name = "Action"
action.Parent = remotes
remotes.Parent = ReplicatedStorage

local ErrorLog = require(script.Parent.ErrorLog)
ErrorLog.start(clientError)

-- Relay movement animations so every client can play them on the mover's character.
local Engine = require(ReplicatedStorage.Shared.Anim.Engine)
local Players = game:GetService("Players")
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
require(script.Parent.Characters).start(spawnPad)

print(`Blade Rift server started, version {Config.Version}`)
