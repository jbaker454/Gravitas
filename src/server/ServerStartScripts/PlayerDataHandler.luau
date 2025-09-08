local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local ProfileService = require(ServerScriptService.Modules.ProfileService :: ModuleScript)
local Events = ReplicatedStorage:WaitForChild("Events")
local RequestPlayerDataRemoteFunction = Events:WaitForChild("RequestPlayerDataRemoteFunction")

local DATA_STORE_NAME = "PlayerDataStore"
local PROFILE_TEMPLATE = {
	levelData = {
		currentLevel = 1,
		maxUnlockedLevel = 1,
	},
	settings = {
		music = true,
		graphics = "High",
	},
}

local function _retrieveTemplate()
	return PROFILE_TEMPLATE
end

local ProfileStore = ProfileService.GetProfileStore(DATA_STORE_NAME, PROFILE_TEMPLATE)
local Profiles = {} -- Stores active player profiles

local function GetData(player)
	local startTime = tick()
	while not Profiles[player] do
		if tick() - startTime > 5 then
			warn("Profile setup timed out for ", player.Name)
			return nil
		end
		task.wait()
	end
	local profile = Profiles[player]
	return profile and profile.Data or nil
end

local function _UpdateData(player, keyPath, value)
	local profile = Profiles[player]
	if not profile then return end

	local data = profile.Data
	local keys = string.split(keyPath, ".") 

	for i = 1, #keys - 1 do
		local k = keys[i]
		if not data[k] then
			warn("Invalid key path:", keyPath)
			return
		end
		data = data[k] -- Navigate deeper
	end

	local finalKey = keys[#keys]
	if data[finalKey] ~= nil then
		data[finalKey] = value
	else
		warn("Invalid key:", finalKey, "in path:", keyPath)
	end
end

Players.PlayerAdded:Connect(function(player)
	local profile = ProfileStore:LoadProfileAsync("Player_" .. player.UserId)

	if profile then
		profile:AddUserId(player.UserId) 
		profile:Reconcile() -- Merges missing data fields with defaults
		profile:ListenToRelease(function()
			Profiles[player] = nil
			player:Kick("Your data session expired. Please rejoin.")
		end)

		if player:IsDescendantOf(Players) then
			Profiles[player] = profile
		else
			profile:Release()
		end
	else
		player:Kick("Failed to load data. Try again.")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local profile = Profiles[player]
	if profile then
		profile:Release()
	end
end)

RequestPlayerDataRemoteFunction.OnServerInvoke = function(player)
	return GetData(player)
end