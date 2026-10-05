local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local PhysicsConfig = require(ReplicatedStorage:WaitForChild("PhysicsConfig"))

local character = nil
local rootPart = nil
local humanoid = nil

local isGrappling = false
local currentAnchor = nil
local ropeLength = 0
local swingAngle = 0
local angularVelocity = 0

local activeBeam = nil
local ropeAttachment0 = nil
local ropeAttachment1 = nil
local nearestAnchor = nil

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local function getClosestGrapplePoint()
	if not rootPart then return nil end
	local anchors = CollectionService:GetTagged("GrappleAnchor")
	local closestAnchor = nil
	local minDistance = PhysicsConfig.MAX_GRAPPLE_DISTANCE or 95
	
	local playerPos = rootPart.Position
	
	for _, anchor in ipairs(anchors) do
		if anchor:IsA("BasePart") then
			local dist = (anchor.Position - playerPos).Magnitude
			if dist < minDistance then
				minDistance = dist
				closestAnchor = anchor
			end
		end
	end
	return closestAnchor
end

local function startGrapple()
	if isGrappling or not rootPart or not nearestAnchor then return end
	isGrappling = true
	currentAnchor = nearestAnchor
	
	local anchorPos = currentAnchor.Position
	local playerPos = rootPart.Position
	local rel = playerPos - anchorPos
	
	ropeLength = math.clamp(math.sqrt(rel.X * rel.X + rel.Y * rel.Y), 5, PhysicsConfig.MAX_GRAPPLE_DISTANCE or 95)
	
	local incomingVel = rootPart.AssemblyLinearVelocity
	local attachBoost = PhysicsConfig.HOOK_ATTACH_BOOST or 38
	
	swingAngle = math.atan2(rel.X, -rel.Y)
	local tangentSpeed = incomingVel.X * math.cos(swingAngle) + incomingVel.Y * math.sin(swingAngle)
	
	if tangentSpeed >= 0 then
		tangentSpeed = math.max(tangentSpeed + attachBoost * 0.6, attachBoost)
	else
		if math.abs(tangentSpeed) < attachBoost then
			tangentSpeed = attachBoost
		end
	end
	
	angularVelocity = tangentSpeed / ropeLength
	
	if humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	end
	
	ropeAttachment0 = rootPart:FindFirstChild("PlayerRopeAttachment") or Instance.new("Attachment", rootPart)
	ropeAttachment0.Name = "PlayerRopeAttachment"
	
	ropeAttachment1 = currentAnchor:FindFirstChild("AnchorAttachment") or Instance.new("Attachment", currentAnchor)
	ropeAttachment1.Name = "AnchorAttachment"
	
	activeBeam = Instance.new("Beam")
	activeBeam.Name = "GrappleRopeBeam"
	activeBeam.Attachment0 = ropeAttachment0
	activeBeam.Attachment1 = ropeAttachment1
	activeBeam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	activeBeam.Width0 = PhysicsConfig.ROPE_THICKNESS
	activeBeam.Width1 = PhysicsConfig.ROPE_THICKNESS
	activeBeam.FaceCamera = true
	activeBeam.LightEmission = 0.5
	activeBeam.LightInfluence = 0
	activeBeam.Parent = rootPart
end

local function releaseGrapple()
	if not isGrappling then return end
	isGrappling = false
	
	if activeBeam then activeBeam:Destroy() activeBeam = nil end
	
	if rootPart then
		local tangentialSpeed = angularVelocity * ropeLength
		local vx = tangentialSpeed * math.cos(swingAngle)
		local vy = tangentialSpeed * math.sin(swingAngle)
		
		local currentSpeed = math.sqrt(vx * vx + vy * vy)
		local maxRelease = PhysicsConfig.MAX_RELEASE_SPEED or 220
		if currentSpeed > maxRelease then
			local scale = maxRelease / currentSpeed
			vx = vx * scale
			vy = vy * scale
		end
		
		rootPart.AssemblyLinearVelocity = Vector3.new(vx, vy, 0)
	end
	
	currentAnchor = nil
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 
		or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.Space
		or input.KeyCode == Enum.KeyCode.ButtonR2 then
		startGrapple()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 
		or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.Space
		or input.KeyCode == Enum.KeyCode.ButtonR2 then
		releaseGrapple()
	end
end)

local function onCharacterAdded(newChar)
	character = newChar
	rootPart = character:WaitForChild("HumanoidRootPart")
	humanoid = character:WaitForChild("Humanoid")
	
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
	
	local filterList = {character}
	for _, anchor in ipairs(CollectionService:GetTagged("GrappleAnchor")) do
		table.insert(filterList, anchor)
	end
	raycastParams.FilterDescendantsInstances = filterList
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then onCharacterAdded(player.Character) end

RunService.Heartbeat:Connect(function(dt)
	if not rootPart then return end
	
	if math.abs(rootPart.Position.Z - PhysicsConfig.Z_LOCK_PLANE) > 0.01 then
		rootPart.CFrame = CFrame.new(rootPart.Position.X, rootPart.Position.Y, PhysicsConfig.Z_LOCK_PLANE) * (rootPart.CFrame - rootPart.Position)
		rootPart.AssemblyLinearVelocity = Vector3.new(rootPart.AssemblyLinearVelocity.X, rootPart.AssemblyLinearVelocity.Y, 0)
	end
	
	nearestAnchor = getClosestGrapplePoint()
	
	if isGrappling and currentAnchor and currentAnchor:IsA("BasePart") then
		local g = PhysicsConfig.GRAVITY or 130
		local L = ropeLength
		
		local alpha = -(g / L) * math.sin(swingAngle)
		local damping = PhysicsConfig.SWING_DAMPING or 0.05
		alpha = alpha - (damping * angularVelocity)
		
		if math.abs(angularVelocity) > 2.2 then
			local pumpDir = math.sign(angularVelocity)
			local pumpRate = PhysicsConfig.SWING_PUMP_RATE or 1.2
			alpha = alpha + (pumpDir * pumpRate)
		end
		
		angularVelocity = angularVelocity + alpha * dt
		local nextAngle = swingAngle + angularVelocity * dt
		
		local anchorPos = currentAnchor.Position
		local proposedX = anchorPos.X + L * math.sin(nextAngle)
		local proposedY = anchorPos.Y - L * math.cos(nextAngle)
		
		local currentPos = rootPart.Position
		local targetPos = Vector3.new(proposedX, proposedY, PhysicsConfig.Z_LOCK_PLANE)
		local moveVec = targetPos - currentPos
		local moveDist = moveVec.Magnitude
		
		local characterRadius = 1.2
		local hitResult = nil
		if moveDist > 0.001 then
			hitResult = workspace:Spherecast(currentPos, characterRadius, moveVec.Unit * (moveDist + characterRadius), raycastParams)
		end
		
		local finalPos = targetPos
		if hitResult and hitResult.Instance and hitResult.Instance.CanCollide then
			local hitNormal = hitResult.Normal
			finalPos = hitResult.Position + (hitNormal * characterRadius)
			finalPos = Vector3.new(finalPos.X, finalPos.Y, PhysicsConfig.Z_LOCK_PLANE)
			
			angularVelocity = -angularVelocity * 0.75
			
			local contactRel = finalPos - anchorPos
			ropeLength = math.clamp(contactRel.Magnitude, 5, PhysicsConfig.MAX_GRAPPLE_DISTANCE or 95)
			swingAngle = math.atan2(contactRel.X, -contactRel.Y)
		else
			swingAngle = nextAngle
		end
		
		local tangentialSpeed = angularVelocity * ropeLength
		local vx = tangentialSpeed * math.cos(swingAngle)
		local vy = tangentialSpeed * math.sin(swingAngle)
		
		local toAnchor = anchorPos - finalPos
		local ropeTilt = math.atan2(toAnchor.Y, toAnchor.X) - math.rad(90)
		local facingY = (vx < -1) and math.rad(-90) or math.rad(90)
		rootPart.CFrame = CFrame.new(finalPos) * CFrame.Angles(0, 0, ropeTilt) * CFrame.Angles(0, facingY, 0)
		rootPart.AssemblyLinearVelocity = Vector3.new(vx, vy, 0)
	end
end)
