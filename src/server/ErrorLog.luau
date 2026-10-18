--!strict
-- Records server and client script errors to a DataStore so they can be read remotely.
local DataStoreService = game:GetService("DataStoreService")
local ScriptContext = game:GetService("ScriptContext")
local HttpService = game:GetService("HttpService")

local ErrorLog = {}

local MAX_PER_MINUTE = 20
local store: DataStore? = nil
local sentThisMinute = 0
local minuteStart = os.clock()

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("ErrorLog")
	end)
	if ok then
		store = result
	end
	return store
end

function ErrorLog.record(source: string, message: string, trace: string?)
	if os.clock() - minuteStart > 60 then
		minuteStart = os.clock()
		sentThisMinute = 0
	end
	if sentThisMinute >= MAX_PER_MINUTE then
		return
	end
	sentThisMinute += 1
	warn(`[ErrorLog] {source}: {message}`)
	local ds = getStore()
	if not ds then
		return
	end
	local entry = {
		source = source,
		message = string.sub(message, 1, 500),
		trace = string.sub(trace or "", 1, 1500),
		time = os.time(),
		jobId = game.JobId,
		placeVersion = game.PlaceVersion,
	}
	task.spawn(function()
		pcall(function()
			ds:SetAsync(`err_{os.time()}_{HttpService:GenerateGUID(false)}`, entry)
		end)
	end)
end

function ErrorLog.start(clientRemote: RemoteEvent)
	ScriptContext.Error:Connect(function(message, trace)
		ErrorLog.record("server", message, trace)
	end)
	clientRemote.OnServerEvent:Connect(function(player, message, trace)
		if typeof(message) ~= "string" then
			return
		end
		ErrorLog.record(`client:{player.UserId}`, message, if typeof(trace) == "string" then trace else nil)
	end)
end

return ErrorLog
