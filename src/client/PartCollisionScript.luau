local player = game:GetService("Players").LocalPlayer

-- helper function to get the value of a single entry dictionary
local function getOnlyEntry(dict:{ [string]: any })
	local count = 0
	local onlyKey, onlyValue = nil, nil

	for k, v in pairs(dict) do
		count += 1
		if count > 1 then
			return nil -- more than one entry
		end
		onlyKey, onlyValue = k, v
	end

	if count == 1 then
		return onlyKey, onlyValue
	else
		return nil -- empty dict
	end
end

local TOLERANCE = 0.1 -- studs
local SLOPETOLERANCE = 0.3 -- studs

local function findSurfaceDistances(playerLocation: Vector3, collidedPart: Part)
	local distances
	local localPos = collidedPart.CFrame:PointToObjectSpace(playerLocation)
	local halfSize = collidedPart.Size / 2

	if collidedPart.Shape == Enum.PartType.Block then
		distances = {
			topSurface    = localPos.Y - halfSize.Y,
			bottomSurface = -(localPos.Y + halfSize.Y),
			rightSurface  = localPos.X - halfSize.X,
			leftSurface   = -(localPos.X + halfSize.X),
			frontSurface  = localPos.Z - halfSize.Z,
			backSurface   = -(localPos.Z + halfSize.Z),
		}
	end

	if collidedPart.Shape == Enum.PartType.Cylinder then
		local radius = halfSize.X -- Roblox cylinder: X=Z radius
		local radialDist = math.sqrt(localPos.Y^2 + localPos.Z^2)

		distances = {
			topSurface    = localPos.X - halfSize.X,
			circleSurface = radialDist - radius,
			bottomSurface = -(localPos.X + halfSize.X),
		}
	end

	if collidedPart.Shape == Enum.PartType.Wedge then
		local SZ = halfSize.Z * 2 -- triangle size Z
		local SY = halfSize.Y * 2 -- triangle size Y
		local DZ = -(localPos.Z - halfSize.Z) -- position z
		local DY = localPos.Y + halfSize.Y -- position y
		local H = math.sqrt(SZ^2 + SY^2) -- triangle hypotenuse
		local slopeDistance = (SY*DZ + SZ*DY - SZ*SY) / H

		distances = {
			slopeSurface  = slopeDistance,
			leftSurface   = -(localPos.X + halfSize.X),
			rightSurface  = localPos.X - halfSize.X,
			backSurface   = localPos.Z - halfSize.Z, 
			bottomSurface = -(localPos.Y + halfSize.Y),
		}
	end

	return distances
end

local function findSurface(distances:{ [string]: number }, radius: number)
	local newDistances = {}
	for surf, dist in pairs(distances) do
		if surf == "slopeSurface" then
			if (dist < (radius + TOLERANCE + SLOPETOLERANCE)) and (dist > (radius - TOLERANCE - SLOPETOLERANCE)) then
				newDistances[surf] = dist
			end
		else
			if (dist < (radius + TOLERANCE)) and (dist > (radius - TOLERANCE)) then
				newDistances[surf] = dist
			end
		end
	end

	local surf, dist = getOnlyEntry(newDistances)

	if not surf or not dist then
		return nil
	else
		return surf
	end
end

-- find the most likely touched surface
local function findProbableTouchedSurface(playerLocation: Vector3, collidedPart: Part)
	local distances = findSurfaceDistances(playerLocation,collidedPart)
	return findSurface(distances, 2)
end

local function findLookRightUp(collidedPart: Part)
	local look, right, up
	if collidedPart.Shape == Enum.PartType.Wedge then
		look = -collidedPart.CFrame.LookVector
		right = collidedPart.CFrame.RightVector
		up = look:Cross(right).Unit

	elseif collidedPart.Shape == Enum.PartType.Cylinder then
		up = collidedPart.CFrame.RightVector
		look = collidedPart.CFrame.LookVector
		right = up:Cross(look).Unit

	else -- default
		look = collidedPart.CFrame.LookVector
		right = collidedPart.CFrame.RightVector
		up = collidedPart.CFrame.UpVector
	end
	return look, right, up
end

-- Get the world-facing direction of a surface
local function collisionDirectionFromSurface(playerLocation: Vector3, surface: string, collidedPart: Part)
	local look, right, up = findLookRightUp(collidedPart)


	if surface == "topSurface" then
		return up
	elseif surface == "bottomSurface" then
		return -up
	elseif surface == "rightSurface" then
		return right
	elseif surface == "leftSurface" then
		return -right
	elseif surface == "frontSurface" then
		return -look
	elseif surface == "backSurface" then
		return look
	elseif surface == "slopeSurface" then
		-- Recompute slope normal in world space
		local size = collidedPart.Size

		-- pick three points on the slope in local space
		local A = Vector3.new(-size.X/2,  size.Y/2,  size.Z/2)  -- front bottom left
		local B = Vector3.new( size.X/2,  size.Y/2,  size.Z/2)  -- front bottom right
		local C = Vector3.new(-size.X/2,  -size.Y/2, -size.Z/2)  -- back top left

		-- slope normal (in local space)
		local slopeNormalLocal = (B - A):Cross(C - A).Unit
		return collidedPart.CFrame:VectorToWorldSpace(slopeNormalLocal)
	elseif surface == "circleSurface" then
		-- Circle side normal: vector from cylinder center to player
		local localPos = collidedPart.CFrame:PointToObjectSpace(playerLocation)
		local radial = Vector3.new(0, localPos.Y, localPos.Z).Unit
		return collidedPart.CFrame:VectorToWorldSpace(radial)
	end

	return Vector3.new(0, 1, 0) -- fallback up
end

-- Finds collision direction between two parts
local function findCollisionDirection(playerLocation:Vector3, collidedPart:Part)
	local surface = findProbableTouchedSurface(playerLocation, collidedPart)
	if not surface then
		return nil
	end
	local collisionDirection = collisionDirectionFromSurface(playerLocation, surface, collidedPart)
	return -collisionDirection
end

-- checks for a part with a specific property Gravity
local function getGravityEnabled(collidedPart: Part)
	if not collidedPart or not collidedPart.Parent then
		return nil
	end

	local gravityObj = collidedPart.Parent:FindFirstChild("Gravity")
	if gravityObj and gravityObj:IsA("BoolValue") then
		return gravityObj.Value
	end

	return nil
end

-- change local gravity of player.
local function changeGravity(collisionDirection: Vector3, localGravity:{ Value: Vector3 })
	local newLocalGravity = collisionDirection.Unit * 100
	localGravity.Value = newLocalGravity
end

-- Listener setup for characters
local function onCharacterAdded(char:Model)
	local SphereBody = char:WaitForChild("SphereBody")
	local localGravity = SphereBody:FindFirstChild("LocalGravity")

	SphereBody.Touched:Connect(function(collidedPart)
		local playerLocation = SphereBody.Position
		if not (collidedPart and collidedPart.Parent and collidedPart.Parent:IsA("Model")) then
			return
		else
			collidedPart = collidedPart.Parent:FindFirstChild("PrimaryPart")
		end

		local GravityEnabled = getGravityEnabled(collidedPart)
		if not GravityEnabled then
			return
		end

		local collisionDirection = findCollisionDirection(playerLocation, collidedPart)
		if not collisionDirection or collisionDirection.Magnitude == 0 then
			return
		else
			changeGravity(collisionDirection, localGravity)
		end

	end)
end


player.CharacterAdded:Connect(function(char)
	onCharacterAdded(char)
end)
if player.Character then
	onCharacterAdded(player.Character)
end



