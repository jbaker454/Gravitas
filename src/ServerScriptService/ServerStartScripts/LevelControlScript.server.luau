local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Levels = ServerStorage:WaitForChild("Levels")
local Events = ReplicatedStorage:WaitForChild("Events")
local LevelChosenRemoteEvent = Events:WaitForChild("LevelChosenRemoteEvent")
local LevelLoadedRemoteEvent = Events:WaitForChild("LevelLoadedRemoteEvent")
local LevelCompleteRemoteEvent = Events:WaitForChild("LevelCompleteRemoteEvent")

local function securePlayer()
	local PlayerCage = ServerStorage:FindFirstChild("PlayerCage"):Clone()
	PlayerCage.Parent = workspace
	for _, player in Players:GetChildren() do
		player.Character.HumanoidRootPart.Anchored = true
		player.Character.HumanoidRootPart.CFrame = PlayerCage.CFrame
	end
end

local function ResetWorkspace()
	for _, child in workspace:GetChildren() do
		if string.match(child.Name, "^level %d+$") and child:IsA("Folder") then
			child:Destroy()
		end
	end
end

-- helper function used to round floating point numbers
local function round(num:number, decimalPlaces:number)
	local mult = 10 ^ (decimalPlaces or 0)
	return math.floor(num * mult + 0.5) / mult
end

-- helper function used to round floating point vector3
local function roundVector3(vector3:Vector3)
	return Vector3.new(round(vector3.X,3), round(vector3.Y,3), round(vector3.Z,3))
end

-- helper function used to create a part inside of another part
local function createInsidePart(part: Part)
	local inside = part:Clone()
	inside.Parent = part.Parent
	inside.Name = "InsidePart"

	inside.Size = part.Size - Vector3.new(0.2, 0.2, 0.2)
	if part.Shape == Enum.PartType.Wedge then
		local slopeAngle = math.atan(part.Size.Y/ part.Size.Z)
		local negativePart = part:Clone()
		negativePart.Parent = part.Parent
		negativePart.Name = "NegativePart"
		negativePart.Shape = Enum.PartType.Block
		negativePart.Size = negativePart.Size * Vector3.new(1, 2, 0) + Vector3.new(0,0,0.2)
		negativePart.CFrame = part.CFrame * CFrame.Angles(slopeAngle, 0, 0)
		local newInside = inside:SubtractAsync({negativePart})
		negativePart:Destroy()
		inside:Destroy()
		
		inside = newInside
		inside.Parent = part.Parent
	end
	
	return inside
end

local function createOutline(part:Part, material:string, color:BrickColor)
	local solid = part:Clone()
	solid.BrickColor = color
	solid.Material = material
	solid.Parent = part.Parent
	
	local shellThickness = 0.1
	local cutClearance = 0.04
	local negatives = {}

	if part.Shape == Enum.PartType.Wedge then
		local negative1 = solid:Clone() -- negative slope
		negative1.Size = roundVector3(part.Size + Vector3.new(-(shellThickness * 2), 0, 0))
		negative1.CFrame = part.CFrame * CFrame.new(0, 0.1, 0.1)
		table.insert(negatives,negative1)
		local negative2 = solid:Clone() -- bottom
		negative2.Shape = "Block"
		negative2.Size = roundVector3(part.Size + Vector3.new(-(shellThickness * 2),(cutClearance * 2),-(shellThickness * 2)))
		table.insert(negatives,negative2)
		local negative3 = solid:Clone() -- side
		negative3.Shape = "Block"
		negative3.Size = roundVector3(part.Size + Vector3.new(-(shellThickness * 2),-(shellThickness * 2),(cutClearance * 2)))
		table.insert(negatives,negative3)
		local negative4 = createInsidePart(part)
		negative4.Size = roundVector3(negative4.Size + Vector3.new((cutClearance * 2) + 0.2,0,0))
		table.insert(negatives,negative4)
	elseif part.Shape == Enum.PartType.Cylinder then
		local negative1 = solid:Clone() -- Top
		negative1.Size = roundVector3(part.Size + Vector3.new((cutClearance * 2),-(shellThickness * 2),-(shellThickness * 2)))
		table.insert(negatives,negative1)
		local negative2 = solid:Clone() -- Side
		negative2.Size = (part.Size + Vector3.new(-(shellThickness * 2),(cutClearance * 2),(cutClearance * 2)))
		table.insert(negatives,negative2)
	else
		local negative1 = solid:Clone() -- X
		negative1.Size = roundVector3(part.Size + Vector3.new((cutClearance * 2),-(shellThickness * 2),-(shellThickness * 2)))
		table.insert(negatives,negative1)
		local negative2 = solid:Clone() -- Y
		negative2.Size = roundVector3(part.Size + Vector3.new(-(shellThickness * 2),(cutClearance * 2),-(shellThickness * 2)))
		table.insert(negatives,negative2)
		local negative3 = solid:Clone() -- Z
		negative3.Size = roundVector3(part.Size + Vector3.new(-(shellThickness * 2),-(shellThickness * 2),(cutClearance * 2)))
		table.insert(negatives,negative3)
	end

	local outline = solid
	for _, negative in ipairs(negatives) do
		negative.Parent = part.Parent
		negative.Name = "NegativePart"
		
		local newOutline = outline:SubtractAsync({negative})
		outline:Destroy()
		negative:Destroy()
		
		outline = newOutline
	end

	outline.Name = "Outline"
	outline.Parent = part.Parent
	return outline
end


local function createBasicModelOutline(Model:Model)
	local PrimaryPart = Model.PrimaryPart
	local outline = createOutline(PrimaryPart, "DiamondPlate" ,BrickColor.new("Really black"))
	
	PrimaryPart.Size = PrimaryPart.Size - Vector3.new(0.01,0.01,0.01)
	local newPrimaryPart = PrimaryPart:SubtractAsync({outline})
	newPrimaryPart.Size = roundVector3(newPrimaryPart.Size + Vector3.new(0.01,0.01,0.01))
	
	newPrimaryPart.Name = "PrimaryPart"
	newPrimaryPart.Parent = Model
	PrimaryPart:Destroy()
end

local function createGravityModelOutline(Model:Model) 
	local PrimaryPart = Model.PrimaryPart
	createOutline(PrimaryPart, "Neon" , BrickColor.new("Cyan"))
	createInsidePart(PrimaryPart)
	PrimaryPart.Transparency = 0.75
end

local function cloneLevelToWorkspace(level:string)
	local levelFolder = Levels:FindFirstChild(level)
	local clonedLevel = levelFolder:Clone()
	clonedLevel.Parent = workspace
	return clonedLevel
end

local function createPartOutlines(clonedLevel:Folder)
	local BasicModels = clonedLevel:FindFirstChild("BasicModels")
	local GravityModels = clonedLevel:FindFirstChild("GravityModels")
	for _, BasicModel in BasicModels:GetChildren() do
		createBasicModelOutline(BasicModel)
	end
	for _, GravityModel in GravityModels:GetChildren() do
		createGravityModelOutline(GravityModel)
	end
end

local function loadLevel(level:string)
	local clonedLevel = cloneLevelToWorkspace(level)
	createPartOutlines(clonedLevel)
end

local function getLevelData(level:string)
	local levelData = {}
	return levelData
end

local function createLevel(levelData:{})
	local createdLevel = nil
	return createdLevel
end

local function loadCustomlevel(level:string)
	local levelData = getLevelData(level)
	local createdLevel = createLevel(levelData)
	createPartOutlines(createdLevel)
end

local function spawnPlayer()
	local PlayerCage = workspace:FindFirstChild("PlayerCage")
	PlayerCage.Destroy()
	for _, player in Players:GetChildren() do
		player.Character.HumanoidRootPart.Anchored = false
	end
end

local function startLevel(level:string, levelType:string)
	ResetWorkspace()
	if levelType == "campaign" then
		loadLevel(level)
	elseif levelType == "custom" then
		loadCustomlevel(level)
	end
	spawnPlayer()
end

LevelCompleteRemoteEvent.OnServerEvent:Connect(function()
	securePlayer()
end)

LevelChosenRemoteEvent.OnServerEvent:Connect(function(player, level, levelType)
	startLevel(level, levelType)
	LevelLoadedRemoteEvent:FireAllClients()
	LevelLoadedRemoteEvent:FireServer()
end)