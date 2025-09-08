local player = game:GetService("Players").LocalPlayer
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local camera = workspace.CurrentCamera

-- helper function used to round floating point numbers
local function round(num:number, decimalPlaces:number)
	local mult = 10 ^ (decimalPlaces or 0)
	return math.floor(num * mult + 0.5) / mult
end

-- helper function used to round floating point vector3
local function roundVector3(vector3:Vector3)
	return Vector3.new(round(vector3.X,3), round(vector3.Y,3), round(vector3.Z,3))
end

-- Set the custom physical properties of the sphere
local function setPhysicsProperties(sphere:Part)
	local parent = sphere.Parent
	if not parent then return end

	for _, part in ipairs(parent:GetChildren()) do
		if part:IsA("BasePart") then
			part.CustomPhysicalProperties = PhysicalProperties.new(1, 0, 0, 1, 1)
		end
	end
end

local isAlive = false
local sphere = nil

local MovementForce = nil
local localGravity = nil

local MAX_SPEED = nil
local SPEED = nil
local SPEED_DAMPING = nil
local JUMP_FORCE = nil

local jumpCooldown = 0.3

local moveDirection = Vector3.zero
local heldKeys = {}
local keyDirectionMap = {
	[Enum.KeyCode.W] = Vector3.new(0, 0, 1),
	[Enum.KeyCode.S] = Vector3.new(0, 0, -1),
	[Enum.KeyCode.A] = Vector3.new(-1, 0, 0),
	[Enum.KeyCode.D] = Vector3.new(1, 0, 0),
	[Enum.KeyCode.Space] = Vector3.new(0, 1, 0),
}

local function updateMoveDirection()
	moveDirection = Vector3.zero
	for key, _ in pairs(heldKeys) do
		local dir = keyDirectionMap[key]
		if dir then
			moveDirection += dir
		end
	end
	if moveDirection.Magnitude > 1 then
		moveDirection = moveDirection.Unit
	end
end

-- check if part is grounded by gravity direction
local function isGrounded()
	local direction = roundVector3(localGravity.Value)
	local rayOrigin = sphere.Position
	local rayDistance = 2.1
	local rayDirection = direction * rayDistance

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {sphere.Parent}
	raycastParams.IgnoreWater = true

	local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	if result then
		if (rayOrigin - result.Position).Magnitude < 3 then
			return true
		end
	end
	return false
end

-- initiate jump
local canJump = true
local function initiateJump()
	canJump = false
	local jumpDirection = -localGravity.Value.unit
	local jumpImpulse = jumpDirection * sphere.AssemblyMass * JUMP_FORCE.Value
	sphere:ApplyImpulse(jumpImpulse)
	task.delay(jumpCooldown, function()
		canJump = true
	end)
end

-- projects a vector onto the gravity plane
local function projectOntoPlane(vector3, gravityDirection)
	local projection = vector3 - gravityDirection * vector3:Dot(gravityDirection)
	return projection.Unit
end

-- finds the projection plane for the sphere movement
local function findProjectionPlane()
	local cameraCF = camera.CFrame
	local gravityDirection = localGravity.Value.unit

	local rightVector = projectOntoPlane(cameraCF.RightVector, gravityDirection)
	local lookVector = projectOntoPlane(cameraCF.LookVector, gravityDirection)

	if rightVector == Vector3.zero or lookVector == Vector3.zero then
		warn("Invalid camera vectors; skipping frame")
		return nil
	end

	local projectionPlane = {rightVector, lookVector}
	return projectionPlane
end

-- controls player movement through forces
local function playerMovement(projectionPlane:{Vector3})
	local rightVector = projectionPlane[1]
	local	lookVector = projectionPlane[2]

	local xForce = rightVector * moveDirection.X * SPEED.Value
	local zForce = lookVector * moveDirection.Z * SPEED.Value

	local gravityForce = localGravity.Value * 1.5 * sphere.AssemblyMass
	local moveForce = (xForce + zForce) * sphere.AssemblyMass
	local totalForce = moveForce + gravityForce

	MovementForce.Force = totalForce
end

-- Velocity capping with damping
local function clampVelocity()
	local velocity = sphere.AssemblyLinearVelocity
	local speed = velocity.Magnitude
	if speed > MAX_SPEED.Value then
		local cappedVelocity = velocity.Unit * MAX_SPEED.Value
		sphere.AssemblyLinearVelocity = velocity:Lerp(cappedVelocity, SPEED_DAMPING.Value)
	else
		sphere.AssemblyLinearVelocity = velocity:Lerp(Vector3.zero, SPEED_DAMPING.Value / 10)
	end
end

-- user input for movement added
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.Keyboard and not gameProcessed then
		if input.KeyCode == Enum.KeyCode.Space and canJump and isGrounded() and isAlive then
			initiateJump()
		end
		heldKeys[input.KeyCode] = true
		updateMoveDirection()
	end
end)

-- user input for movement removed
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		heldKeys[input.KeyCode] = nil
		updateMoveDirection()
	end
end)

-- validate sphere and camera target
local function updateTarget(char:Model)
	sphere = char:WaitForChild("SphereBody", 5)
	setPhysicsProperties(sphere)
	
	localGravity = sphere:WaitForChild("LocalGravity", 5)
	MovementForce = sphere:WaitForChild("SphereMovement", 5)
	MAX_SPEED = sphere.MaxSpeed
	SPEED = sphere.Speed
	SPEED_DAMPING = sphere.SpeedDamping
	JUMP_FORCE = sphere.JumpForce
	
	return sphere
end


local function handleSphereControls(char:Model)
	isAlive = true
	RunService.RenderStepped:Connect(function()
		if (not sphere or not sphere:IsDescendantOf(workspace)) then
			return
		end

		local projectionPlane = findProjectionPlane()
		if projectionPlane == nil then
			return
		end
		
		playerMovement(projectionPlane)
		clampVelocity()
	end)
	isAlive = false
end


local function onCharacterAdded(char: Model)
	updateTarget(char)
	handleSphereControls(char)
end

player.CharacterAdded:Connect(function(char)
	onCharacterAdded(char)
end)
if player.Character then
	onCharacterAdded(player.Character)
end
