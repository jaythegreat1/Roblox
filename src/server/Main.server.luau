--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local remotes = Instance.new("Folder")
remotes.Name = Config.RemoteFolderName
local clientError = Instance.new("RemoteEvent")
clientError.Name = "ClientError"
clientError.Parent = remotes
remotes.Parent = ReplicatedStorage

local ErrorLog = require(script.Parent.ErrorLog)
ErrorLog.start(clientError)

local spawnPad = require(script.Parent.Arena).build()
require(script.Parent.Characters).start(spawnPad)

print(`Blade Rift server started, version {Config.Version}`)
