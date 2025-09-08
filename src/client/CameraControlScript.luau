local player = game:GetService("Players").LocalPlayer
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Setup
local camera = workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable

local isAlive = false
local sphere = nil
local cameraTarget = nil
local localGravity = nil
local raycastParams = nil

local dragging = false
local lastMousePosition
local desiredDistance = 15
local minDistance = 2.5
local yaw = 0
local pitch = 0
local cameraStartOffset = Vector3.zero

-- player parts blacklist
local function getCharacterIgnoreList(char:Model)
	if not char then return {} end
	local parts = {}
	for _, descendant in ipairs(char:GetDescendants()) do
		if descendant:IsA("BasePart") or descendant:IsA("UnionOperation") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

-- Gravity smoothing
local currentGravityDir = Vector3.new(0, -1, 0)
local gravityLerpSpeed = 10 -- higher is faster

local function getSphere(char:Model)
	sphere = char:WaitForChild("SphereBody", 5)
	cameraTarget = sphere.Parent:FindFirstChild("Center")
	localGravity = sphere:WaitForChild("LocalGravity", 5)

	raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = getCharacterIgnoreList(char)
	return cameraTarget
end

-- get camera movement plane
function GetCameraBasis(gravity:Vector3)
	local up = -gravity.Unit

	local fallback = Vector3.new(0, 0, 1)
	if math.abs(up:Dot(fallback)) > 0.99 then
		fallback = Vector3.new(0, 1, 0)
		warn("fallback used for camera basis")
	end

	local right = fallback:Cross(up).Unit
	local look = up:Cross(right).Unit

	return right, look
end

-- Input handlers
-- Mouse movement
UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		dragging = true
		lastMousePosition = UserInputService:GetMouseLocation()
	end
end)

-- Mouse release
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		dragging = false
	end
end)

-- Mouse wheel zoom
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel and isAlive then
		desiredDistance = math.clamp(desiredDistance - input.Position.Z, 5, 50)
	end
end)

-- reset on window focus loss
UserInputService.WindowFocusReleased:Connect(function()
	dragging = false
end)



local function handleCamera(cameraTarget: Part)
	local currentCameraPosition = cameraTarget.Position + cameraStartOffset
	isAlive = true
	RunService.RenderStepped:Connect(function(dt)
		if not cameraTarget or not cameraTarget.Parent then
			return
		end

		-- Update gravity direction
		local targetGravityDir = localGravity.Value.Unit
		if targetGravityDir == Vector3.zero then
			targetGravityDir = Vector3.new(0, -1, 0)
		end

		-- Blend toward the target gravity
		local lerped = currentGravityDir:Lerp(targetGravityDir, dt * gravityLerpSpeed)
		if lerped.Magnitude > 0.001 then
			currentGravityDir = lerped.Unit
		end

		-- Unified up axis from blended gravity
		local upAxis = -currentGravityDir
		-- Get basis using the blended gravity
		local rightVector, lookVector = GetCameraBasis(currentGravityDir)

		-- Mouse input for yaw/pitch
		if dragging then
			local currentMousePos = UserInputService:GetMouseLocation()
			local mouseDelta = currentMousePos - lastMousePosition
			lastMousePosition = currentMousePos

			yaw = yaw - mouseDelta.X * 0.005
			pitch = math.clamp(pitch + mouseDelta.Y * 0.005, -math.rad(80), math.rad(80))
		end

		-- Apply yaw then pitch to the basis
		local yawRotation = CFrame.fromAxisAngle(upAxis, yaw)
		local rotatedRight = (yawRotation * rightVector)
		local pitchRotation = CFrame.fromAxisAngle(rotatedRight, pitch)
		local finalLook = (pitchRotation * (yawRotation * lookVector))

		-- Ideal camera offset
		local cameraDirection = finalLook * desiredDistance
		local targetPosition = cameraTarget.Position

		-- Obstruction handling: scale finalLook to safeDistance if blocked
		local rayResult = workspace:Raycast(targetPosition, cameraDirection, raycastParams)
		if rayResult then
			local safeDistance = math.max((rayResult.Position - targetPosition).Magnitude - 0.3, minDistance)
			cameraDirection = finalLook * safeDistance
		end

		local desiredCameraPosition = targetPosition + cameraDirection
		currentCameraPosition = currentCameraPosition:Lerp(desiredCameraPosition, math.clamp(12 * dt, 0, 1))

		camera.CFrame = CFrame.lookAt(currentCameraPosition, targetPosition, upAxis)
	end)
	isAlive = false
end

local function onCharacterAdded(char: Model)
	local cameraTarget = getSphere(char)
	handleCamera(cameraTarget)
end

player.CharacterAdded:Connect(function(char)
	onCharacterAdded(char)
end)
if player.Character then
	onCharacterAdded(player.Character)
end