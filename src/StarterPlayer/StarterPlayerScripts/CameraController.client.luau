local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local PhysicsConfig = require(ReplicatedStorage:WaitForChild("PhysicsConfig"))
local Events = ReplicatedStorage:WaitForChild("Events")

local character = nil
local rootPart = nil
local isMenuMode = true

camera.CameraType = Enum.CameraType.Scriptable

local currentCamPos = Vector3.new(0, 10, 50)
local targetTiltAngle = 0
local currentTiltAngle = 0

local function getMainScreenAnchor()
	local mainScreen = workspace:FindFirstChild("MainScreen") or workspace:FindFirstChild("Mainscreen")
	if mainScreen then
		local anchor = mainScreen:FindFirstChild("Anchor_Norm") or mainScreen:FindFirstChild("Anchor") or mainScreen:FindFirstChildOfClass("BasePart")
		if anchor and anchor:IsA("BasePart") then
			return anchor
		end
	end
	return nil
end

local GameStartedEvent = Events:WaitForChild("GameStartedEvent")
GameStartedEvent.Event:Connect(function()
	isMenuMode = false
	if rootPart then
		local zOffset = PhysicsConfig.CAMERA_OFFSET_Z or 62
		currentCamPos = Vector3.new(rootPart.Position.X, rootPart.Position.Y + 2, zOffset)
	end
end)

local ReturnToMenuEvent = Events:WaitForChild("ReturnToMenuEvent")
ReturnToMenuEvent.Event:Connect(function()
	isMenuMode = true
	local anchor = getMainScreenAnchor()
	if anchor then
		currentCamPos = Vector3.new(anchor.Position.X, anchor.Position.Y - 5, anchor.Position.Z + 45)
	end
end)

local function onCharacterAdded(newChar)
	character = newChar
	rootPart = character:WaitForChild("HumanoidRootPart")
	
	if isMenuMode then
		local anchor = getMainScreenAnchor()
		if anchor then
			currentCamPos = Vector3.new(anchor.Position.X, anchor.Position.Y - 5, anchor.Position.Z + 45)
		end
	else
		local zOffset = PhysicsConfig.CAMERA_OFFSET_Z or 62
		currentCamPos = Vector3.new(rootPart.Position.X, rootPart.Position.Y + 2, zOffset)
	end
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then onCharacterAdded(player.Character) end

RunService.RenderStepped:Connect(function(dt)
	if isMenuMode then
		local anchor = getMainScreenAnchor()
		if anchor then
			local targetMenuCam = Vector3.new(anchor.Position.X, anchor.Position.Y - 5, anchor.Position.Z + 45)
			currentCamPos = currentCamPos:Lerp(targetMenuCam, math.clamp(dt * 8, 0, 1))
			local focusPoint = Vector3.new(anchor.Position.X, anchor.Position.Y - 5, anchor.Position.Z)
			camera.CFrame = CFrame.new(currentCamPos, focusPoint)
			camera.FieldOfView = PhysicsConfig.DEFAULT_FOV or 70
		end
		return
	end
	
	if not rootPart then return end
	
	local playerPos = rootPart.Position
	local playerVel = rootPart.AssemblyLinearVelocity
	local speed = playerVel.Magnitude
	
	local lookaheadFactor = PhysicsConfig.CAMERA_LOOKAHEAD or 0.18
	local smoothSpeed = PhysicsConfig.CAMERA_SMOOTH_SPEED or 16
	local zOffset = PhysicsConfig.CAMERA_OFFSET_Z or 62
	local defaultFov = PhysicsConfig.DEFAULT_FOV or 70
	local maxSpeed = PhysicsConfig.MAX_SWING_SPEED or 180
	
	local lookaheadX = math.clamp(playerVel.X * lookaheadFactor, -20, 25)
	local lookaheadY = math.clamp(playerVel.Y * 0.08, -10, 10)
	
	local targetPos = Vector3.new(
		playerPos.X + lookaheadX + 6,
		playerPos.Y + lookaheadY + 2,
		zOffset
	)
	
	local smoothFactor = math.clamp(dt * smoothSpeed, 0, 1)
	currentCamPos = currentCamPos:Lerp(targetPos, smoothFactor)
	
	local speedRatio = math.clamp(speed / maxSpeed, 0, 1)
	local baseFov = defaultFov
	local targetFov = baseFov + 14 * speedRatio
	camera.FieldOfView = camera.FieldOfView + (targetFov - camera.FieldOfView) * math.clamp(dt * 8, 0, 1)
	
	local focusPoint = Vector3.new(currentCamPos.X, currentCamPos.Y, 0)
	
	targetTiltAngle = math.clamp(-playerVel.Y * 0.003, -0.08, 0.08)
	currentTiltAngle = currentTiltAngle + (targetTiltAngle - currentTiltAngle) * math.clamp(dt * 10, 0, 1)
	
	camera.CFrame = CFrame.new(currentCamPos, focusPoint) * CFrame.Angles(0, 0, currentTiltAngle)
end)
