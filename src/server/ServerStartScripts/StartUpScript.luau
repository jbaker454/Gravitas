local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local StarterCharacter = ServerStorage:WaitForChild("SphereCharacter")
local AdminUI = ServerStorage:WaitForChild("AdminUI")

local adminUserNames = {
	"Crazyminion1971"
}

local function loadCustomCharacter(player)
	local customChar = StarterCharacter:Clone()
	customChar.Name = player.Name
	customChar.Parent = workspace
	player.Character = customChar


end

local function lockPlayer(player)
	local PlayerCage = workspace:FindFirstChild("PlayerCage")
	player.Character.HumanoidRootPart.Anchored = true
	player.Character.HumanoidRootPart.CFrame = PlayerCage.CFrame
end

local function GiveAdminUI(player)
	local clonedAdminUI = AdminUI:Clone()
	clonedAdminUI.Parent = player
end

Players.PlayerAdded:Connect(function(player)
	-- When a character is added, hook up the death handler
	player.CharacterAdded:Connect(function(character)
		local SphereBody = character:WaitForChild("SphereBody")
		task.spawn(function()
			while SphereBody.Parent do
				task.wait(1)
			end
			-- SphereBody was removed = death
			loadCustomCharacter(player)
		end)
	end)

	loadCustomCharacter(player)
	lockPlayer(player)

	print(player.UserId)
	for _, name in ipairs(adminUserNames) do
		if player.Name == name then
			GiveAdminUI(player)
		end
	end
	
end)
