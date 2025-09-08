local Players = game:GetService("Players")
local StarterCharacter = game:GetService("ServerStorage"):WaitForChild("SphereCharacter")

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
end)
