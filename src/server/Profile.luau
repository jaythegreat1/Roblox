-- Player profiles: level, XP, coins, owned swords and Echoes, loadout, quest progress and
-- daily tasks, saved in a DataStore. The client gets a snapshot whenever something changes.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progression = require(ReplicatedStorage.Shared.Progression)
local EchoData = require(ReplicatedStorage.Shared.Combat.Echoes)
local Swords = require(ReplicatedStorage.Shared.Combat.Swords)

local Profile = {}

local KEY_PREFIX = "p_"
local SAVE_EVERY = 90

local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore("Profiles_v1")
end)

local profiles: { [Player]: any } = {}
local loadedSignals: { [Player]: BindableEvent } = {}
local pushQueued: { [Player]: boolean } = {}
local snapshotRemote: RemoteEvent
local eventRemote: RemoteEvent

local function default()
	return {
		v = 1,
		level = 1,
		xp = 0,
		coins = 0,
		swords = { IronOath = true },
		echoes = {},
		loadout = {},
		sword = "IronOath",
		quests = {}, -- [questId] = { step = n, n = progress }
		completed = {}, -- [questId] = true
		tracked = {},
		daily = { day = 0, tasks = {}, rerolls = 1 },
		stats = { botStreak = 0 },
	}
end

-- Fills in anything an older save is missing.
local function upgrade(data)
	local fresh = default()
	for k, v in fresh do
		if data[k] == nil then
			data[k] = v
		end
	end
	data.swords.IronOath = true
	return data
end

function Profile.isDev(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(function()
		return player:GetRankInGroup(game.CreatorId)
	end)
	return ok and rank >= 254
end

function Profile.get(player: Player)
	return profiles[player]
end

function Profile.waitLoaded(player: Player)
	if profiles[player] then
		return profiles[player]
	end
	local signal = loadedSignals[player]
	if not signal then
		signal = Instance.new("BindableEvent")
		loadedSignals[player] = signal
	end
	local start = os.clock()
	while not profiles[player] and player.Parent and os.clock() - start < 20 do
		signal.Event:Wait()
	end
	return profiles[player]
end

local function capacityUsed(player: Player, override: { [string]: any }?): number
	local used = 0
	for i = 1, 3 do
		local slot = "Echo" .. i
		local id = if override and override[slot] ~= nil then override[slot] else player:GetAttribute(slot)
		local e = EchoData.get(id)
		if e then
			used += EchoData.Rarity[e.rarity].cost
		end
	end
	return used
end

-- Mirrors the profile onto player attributes (read by combat, Echoes and the HUD).
local function applyAttributes(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	player:SetAttribute("Level", data.level)
	player:SetAttribute("XP", data.xp)
	player:SetAttribute("XPNext", Progression.xpToNext(data.level))
	player:SetAttribute("Coins", data.coins)
	player:SetAttribute("Capacity", Progression.capacity(data.level))
end

local function snapshot(player: Player)
	local data = profiles[player]
	return {
		level = data.level,
		xp = data.xp,
		xpNext = Progression.xpToNext(data.level),
		coins = data.coins,
		capacity = Progression.capacity(data.level),
		swords = data.swords,
		echoes = data.echoes,
		quests = data.quests,
		completed = data.completed,
		tracked = data.tracked,
		daily = data.daily,
		stats = data.stats,
		unsaved = data.unsaved,
		dev = Profile.isDev(player),
	}
end

-- Sends the client a fresh snapshot (batched to one per frame).
function Profile.changed(player: Player)
	applyAttributes(player)
	if pushQueued[player] then
		return
	end
	pushQueued[player] = true
	task.defer(function()
		pushQueued[player] = nil
		if profiles[player] and player.Parent then
			snapshotRemote:FireClient(player, snapshot(player))
		end
	end)
end

-- Pop-ups on the player's screen: level ups, rewards, quest steps.
function Profile.event(player: Player, kind: string, payload: any)
	eventRemote:FireClient(player, kind, payload)
end

function Profile.addCoins(player: Player, amount: number)
	local data = profiles[player]
	if not data or amount == 0 then
		return
	end
	data.coins = math.max(0, math.floor(data.coins + amount))
	Profile.changed(player)
end

local function levelUp(player: Player, data)
	data.level += 1
	local coins = Progression.levelReward(data.level)
	data.coins += coins
	local unlocked = {}
	for id, info in Progression.Swords do
		if info.level == data.level then
			table.insert(unlocked, `{Swords.get(id).name} in the Armory`)
		end
	end
	for _, quest in Progression.Quests do
		if quest.level == data.level and not quest.soon then
			table.insert(unlocked, `Quest: {quest.name}`)
		end
	end
	if Progression.capacity(data.level) > Progression.capacity(data.level - 1) then
		table.insert(unlocked, `Echo Capacity {Progression.capacity(data.level)}`)
	end
	Profile.event(player, "levelup", { level = data.level, coins = coins, unlocked = unlocked })
end

function Profile.addXP(player: Player, amount: number)
	local data = profiles[player]
	if not data or amount <= 0 then
		return
	end
	data.xp += math.floor(amount + 0.5)
	while data.level < Progression.MaxLevel and data.xp >= Progression.xpToNext(data.level) do
		data.xp -= Progression.xpToNext(data.level)
		levelUp(player, data)
	end
	Profile.changed(player)
end

function Profile.setLevelAtLeast(player: Player, level: number)
	local data = profiles[player]
	if not data then
		return
	end
	while data.level < math.min(level, Progression.MaxLevel) do
		data.xp = 0
		levelUp(player, data)
	end
	Profile.changed(player)
end

-- Gives an Echo and slots it straight in if there is room, so new powers are ready to use.
function Profile.grantEcho(player: Player, id: string)
	local data = profiles[player]
	local e = EchoData.get(id)
	if not data or not e then
		return
	end
	data.echoes[id] = true
	local character = player.Character
	local function equip(slot: string)
		player:SetAttribute(slot, id)
		if character then
			character:SetAttribute(slot, id)
		end
	end
	if e.rarity == "Mythic" then
		if not player:GetAttribute("EchoSurge") then
			equip("EchoSurge")
		end
	else
		for i = 1, 3 do
			local slot = "Echo" .. i
			if not player:GetAttribute(slot) then
				if capacityUsed(player, { [slot] = id }) <= Progression.capacity(data.level) then
					equip(slot)
				end
				break
			end
		end
	end
	Profile.changed(player)
end

function Profile.ownsEcho(player: Player, id: string): boolean
	local data = profiles[player]
	return data ~= nil and data.echoes[id] == true
end

function Profile.ownsSword(player: Player, id: string): boolean
	local data = profiles[player]
	return data ~= nil and data.swords[id] == true
end

-- Validates an Echo loadout change: owned, and the three slots fit your Echo Capacity.
function Profile.canEquipEcho(player: Player, model: Model, slot: string, id: string): (boolean, string?)
	local data = profiles[player]
	if not data then
		return false, "Profile still loading"
	end
	if not data.echoes[id] then
		local quest = Progression.QuestForEcho[id]
		return false, if quest then `Locked: earn it from the quest {quest.name}` else "Locked"
	end
	if slot == "EchoSurge" then
		return true
	end
	-- After the change (and the swap if the Echo was in another slot).
	local override = { [slot] = id }
	for i = 1, 3 do
		local other = "Echo" .. i
		if other ~= slot and model:GetAttribute(other) == id then
			override[other] = model:GetAttribute(slot) or false
		end
	end
	local used = capacityUsed(player, override)
	local cap = Progression.capacity(data.level)
	if used > cap then
		return false, `Over Echo Capacity ({used}/{cap}). Level up for more.`
	end
	return true
end

function Profile.buySword(player: Player, id: string)
	local data = profiles[player]
	local info = Progression.Swords[id]
	if not data or not info or data.swords[id] then
		return
	end
	if data.level < info.level then
		Profile.event(player, "notice", `Reach level {info.level} to buy this sword`)
		return
	end
	if data.coins < info.coins then
		Profile.event(player, "notice", `You need {info.coins - data.coins} more coins`)
		return
	end
	data.coins -= info.coins
	data.swords[id] = true
	Profile.event(player, "reward", { kind = "sword", id = id })
	Profile.changed(player)
end

-- Saving ---------------------------------------------------------------------------------------

local function save(player: Player)
	local data = profiles[player]
	if not data or data.unsaved or not store then
		return
	end
	data.sword = player:GetAttribute("SwordId") or data.sword
	data.loadout = {}
	for _, slot in EchoData.Slots do
		data.loadout[slot] = player:GetAttribute(slot)
	end
	local copy = table.clone(data)
	copy.unsaved = nil
	local ok, err = pcall(function()
		(store :: DataStore):SetAsync(KEY_PREFIX .. player.UserId, copy, { player.UserId })
	end)
	if not ok then
		warn(`[Profile] save failed for {player.Name}: {err}`)
	end
end
Profile.save = save

local function load(player: Player)
	local data = nil
	local failed = store == nil
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return (store :: DataStore):GetAsync(KEY_PREFIX .. player.UserId)
			end)
			if ok then
				data = result
				failed = false
				break
			end
			failed = true
			task.wait(attempt)
		end
	end
	data = upgrade(if typeof(data) == "table" then data else default())
	if failed then
		-- Never overwrite a real save with a blank one when the DataStore is down.
		data.unsaved = true
	end
	profiles[player] = data
	player:SetAttribute("SwordId", if data.swords[data.sword] then data.sword else "IronOath")
	for _, slot in EchoData.Slots do
		local id = data.loadout[slot]
		player:SetAttribute(slot, if id and data.echoes[id] and EchoData.fits(id, slot) then id else nil)
	end
	player:SetAttribute("IsDev", Profile.isDev(player))
	applyAttributes(player)
	local signal = loadedSignals[player]
	if signal then
		signal:Fire()
	end
	Profile.changed(player)
	if failed then
		task.delay(3, function()
			Profile.event(player, "notice", "Saving is unavailable right now; progress this session won't be kept")
		end)
	end
end

Profile.loadPlayer = load

-- Developer tools for testing progression (only the game's owner sees them).
local function devAction(player: Player, action: string, arg: any)
	local data = profiles[player]
	if not data or not Profile.isDev(player) then
		return
	end
	if action == "DevLevel" and typeof(arg) == "number" then
		Profile.setLevelAtLeast(player, data.level + math.clamp(math.floor(arg), 1, 99))
	elseif action == "DevCoins" then
		Profile.addCoins(player, 5000)
	elseif action == "DevUnlockAll" then
		for _, e in EchoData.List do
			data.echoes[e.id] = true
		end
		for id in Progression.Swords do
			data.swords[id] = true
		end
		Profile.changed(player)
	elseif action == "DevReset" then
		profiles[player] = default()
		for _, slot in EchoData.Slots do
			player:SetAttribute(slot, nil)
			if player.Character then
				player.Character:SetAttribute(slot, nil)
			end
		end
		player:SetAttribute("SwordId", "IronOath")
		Profile.changed(player)
		if Profile.onReset then
			Profile.onReset(player)
		end
	end
end

function Profile.start(remotes: Folder)
	snapshotRemote = Instance.new("RemoteEvent")
	snapshotRemote.Name = "ProfileSnapshot"
	snapshotRemote.Parent = remotes
	eventRemote = Instance.new("RemoteEvent")
	eventRemote.Name = "ProfileEvent"
	eventRemote.Parent = remotes
	local actionRemote = Instance.new("RemoteEvent")
	actionRemote.Name = "ProfileAction"
	actionRemote.Parent = remotes

	actionRemote.OnServerEvent:Connect(function(player, action, arg)
		if typeof(action) ~= "string" or not profiles[player] then
			return
		end
		if action == "BuySword" and typeof(arg) == "string" then
			Profile.buySword(player, arg)
		elseif action == "Refresh" then
			Profile.changed(player)
		elseif string.sub(action, 1, 3) == "Dev" then
			devAction(player, action, arg)
		elseif Profile.actions[action] then
			Profile.actions[action](player, arg)
		end
	end)

	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
		loadedSignals[player] = nil
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			task.spawn(save, player)
		end
		task.wait(3)
	end)
	task.spawn(function()
		while true do
			task.wait(SAVE_EVERY)
			for _, player in Players:GetPlayers() do
				task.spawn(save, player)
			end
		end
	end)
end

-- Other modules (Quests) add client actions here: Profile.actions[name] = fn(player, arg).
Profile.actions = {}

return Profile
