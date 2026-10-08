local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer

local PhysicsConfig = require(ReplicatedStorage:WaitForChild("PhysicsConfig"))
local Events = ReplicatedStorage:WaitForChild("Events")

local character = nil
local rootPart = nil
local humanoid = nil

local isFinished = false
local isGrappling = false
local currentAnchor = nil
local ropeLength = 0
local swingAngle = 0
local angularVelocity = 0

local activeBeam = nil
local ropeAttachment0 = nil
local ropeAttachment1 = nil
local nearestAnchor = nil

-- 3D Dashed Selection Ring
local selectionRingModel = nil
local selectionRingRoot = nil
local ringDashParts = {}
local ringRotationAngle = 0

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local LevelFinishedEvent = Events:WaitForChild("LevelFinishedEvent")

local function getLevelLines()
	local map = workspace:FindFirstChild("Map")
	local lines = map and map:FindFirstChild("Lines")
	local deadBelowY = -88
	local deadAboveY = 252
	local finishX = 351.25
	
	if lines then
		local db = lines:FindFirstChild("DeadBelow")
		local da = lines:FindFirstChild("DeadAbove")
		local fin = lines:FindFirstChild("Finish")
		if db and db:IsA("BasePart") then deadBelowY = db.Position.Y end
		if da and da:IsA("BasePart") then deadAboveY = da.Position.Y end
		if fin and fin:IsA("BasePart") then finishX = fin.Position.X end
	end
	return deadBelowY, deadAboveY, finishX
end

local function create3DSelectionRing()
	if selectionRingModel then selectionRingModel:Destroy() end
	
	local model = Instance.new("Model")
	model.Name = "SelectionRing"
	
	local root = Instance.new("Part")
	root.Name = "RingRoot"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Anchored = true
	root.Parent = model
	model.PrimaryPart = root
	
	local numSegments = 16
	local radius = 3.2
	local segLength = 0.95
	local thickness = 0.22
	ringDashParts = {}
	
	for i = 1, numSegments do
		local angle = (i - 1) * (2 * math.pi / numSegments)
		local seg = Instance.new("Part")
		seg.Name = "Dash_" .. i
		seg.Material = Enum.Material.SmoothPlastic
		seg.Color = Color3.fromRGB(255, 255, 255)
		seg.Size = Vector3.new(segLength, thickness, thickness)
		seg.Anchored = false
		seg.CanCollide = false
		seg.CanTouch = false
		seg.CanQuery = false
		seg.CastShadow = false
		seg.Transparency = 1
		
		local x = radius * math.cos(angle)
		local y = radius * math.sin(angle)
		seg.CFrame = CFrame.new(x, y, 0) * CFrame.Angles(0, 0, angle + math.pi/2)
		
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = seg
		weld.Parent = seg
		
		seg.Parent = model
		table.insert(ringDashParts, seg)
	end
	
	model.Parent = workspace
	selectionRingModel = model
	selectionRingRoot = root
end

local function setSelectionRingVisible(visible)
	local targetTrans = visible and 0.05 or 1
	for _, part in ipairs(ringDashParts) do
		part.Transparency = targetTrans
	end
end

local function setAnchorActive(anchor, isActive)
	if not anchor then return end
	local dot = anchor:FindFirstChild("CenterDot") or (anchor.Name == "CenterDot" and anchor)
	local targetColor = isActive and (PhysicsConfig.COLOR_ANCHOR_ACTIVE or Color3.fromRGB(235, 45, 65)) 
								 or (PhysicsConfig.COLOR_ANCHOR_DEFAULT or Color3.fromRGB(90, 180, 255))
	
	local anchorOrigSize = anchor:GetAttribute("OriginalSize") or Vector3.new(0.8, 3.4, 3.4)
	local targetAnchorSize = isActive and (anchorOrigSize * 1.2) or anchorOrigSize
	
	TweenService:Create(anchor, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = targetAnchorSize
	}):Play()
	
	if dot and dot:IsA("BasePart") then
		local dotOrigSize = dot:GetAttribute("OriginalSize") or Vector3.new(2.0, 1.4, 1.4)
		local targetDotSize = isActive and (dotOrigSize * 1.3) or dotOrigSize
		
		TweenService:Create(dot, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = targetColor,
			Size = targetDotSize
		}):Play()
	end
end

local function resetAllAnchorsToDefault()
	for _, anchor in ipairs(CollectionService:GetTagged("GrappleAnchor")) do
		if not anchor:IsDescendantOf(game.Workspace) then continue end
		setAnchorActive(anchor, false)
	end
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name == "CenterDot" and obj:IsA("BasePart") then
			obj.Color = PhysicsConfig.COLOR_ANCHOR_DEFAULT or Color3.fromRGB(90, 180, 255)
			obj.Size = obj:GetAttribute("OriginalSize") or Vector3.new(2.0, 1.4, 1.4)
		end
	end
end

local function respawnAtStart()
	if not rootPart then return end
	if isGrappling then
		if currentAnchor then
			setAnchorActive(currentAnchor, false)
		end
		if activeBeam then activeBeam:Destroy() activeBeam = nil end
		isGrappling = false
		currentAnchor = nil
	end

	setSelectionRingVisible(false)

	local spawnLoc = workspace:FindFirstChildOfClass("SpawnLocation")
	local spawnX = spawnLoc and spawnLoc.Position.X or -16
	local spawnY = spawnLoc and spawnLoc.Position.Y or 2
	local targetPos = Vector3.new(spawnX, spawnY + 14, PhysicsConfig.Z_LOCK_PLANE or 0)

	angularVelocity = 0
	swingAngle = 0
	rootPart.CFrame = CFrame.new(targetPos)
	rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
end

local ForceRespawnEvent = Events:WaitForChild("ForceRespawnEvent", 10)
if ForceRespawnEvent and ForceRespawnEvent:IsA("RemoteEvent") then
	ForceRespawnEvent.OnClientEvent:Connect(function()
		respawnAtStart()
	end)
end

local function triggerFinishSequence()
	if isFinished then return end
	isFinished = true
	
	setSelectionRingVisible(false)
	
	if isGrappling then
		if currentAnchor then
			setAnchorActive(currentAnchor, false)
		end
		if activeBeam then activeBeam:Destroy() activeBeam = nil end
		isGrappling = false
		currentAnchor = nil
	end
	
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/action_jump.mp3"
	sound.Volume = 0.9
	sound.PlaybackSpeed = 0.8
	sound.Parent = rootPart
	sound:Play()
	Debris:AddItem(sound, 3)
	
	if LevelFinishedEvent then
		LevelFinishedEvent:Fire()
	end
	
	task.spawn(function()
		while isFinished do
			task.wait(0.03)
			if rootPart and isFinished then
				local v = rootPart.AssemblyLinearVelocity
				rootPart.AssemblyLinearVelocity = Vector3.new(v.X * 0.94, math.max(v.Y * 0.90, -10), 0)
			end
		end
	end)
end

local function getClosestGrapplePoint()
	if not rootPart or isFinished then return nil end
	local anchors = CollectionService:GetTagged("GrappleAnchor")
	local closestAnchor = nil
	local minDistance = PhysicsConfig.MAX_GRAPPLE_DISTANCE or 95
	
	local playerPos = rootPart.Position
	
	for _, anchor in ipairs(anchors) do
		if not anchor:IsDescendantOf(game.Workspace) then continue end
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
	if isFinished or isGrappling or not rootPart or not nearestAnchor then return end
	isGrappling = true
	currentAnchor = nearestAnchor
	
	setSelectionRingVisible(false)
	setAnchorActive(currentAnchor, true)
	
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
	
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/action_jump.mp3"
	sound.Volume = 0.65
	sound.PlaybackSpeed = 1.45
	sound.Parent = rootPart
	sound:Play()
	Debris:AddItem(sound, 1)
end

local function releaseGrapple()
	if not isGrappling then return end
	isGrappling = false
	
	if currentAnchor and currentAnchor:IsA("BasePart") then
		setAnchorActive(currentAnchor, false)
	end
	
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
	if gameProcessed or isFinished then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 
		or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.Space
		or input.KeyCode == Enum.KeyCode.ButtonR2 then
		startGrapple()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if isFinished then return end
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
		if not anchor:IsDescendantOf(game.Workspace) then continue end
		table.insert(filterList, anchor)
	end
	local map = workspace:FindFirstChild("Map")
	local lines = map and map:FindFirstChild("Lines")
	if lines then
		table.insert(filterList, lines)
	end
	raycastParams.FilterDescendantsInstances = filterList
	
	respawnAtStart()
	
	humanoid.Died:Connect(function()
		if isGrappling then
			releaseGrapple()
		end
		setSelectionRingVisible(false)
	end)
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then onCharacterAdded(player.Character) end

resetAllAnchorsToDefault()
create3DSelectionRing()

RunService.Heartbeat:Connect(function(dt)
	if not rootPart then return end
	
	local deadBelowY, deadAboveY, finishThresholdX = getLevelLines()
	
	if not isFinished then
		if rootPart.Position.Y < deadBelowY or rootPart.Position.Y > deadAboveY then
			respawnAtStart()
			return
		end
	end
	
	if not isFinished and rootPart.Position.X >= finishThresholdX then
		triggerFinishSequence()
	end
	
	if math.abs(rootPart.Position.Z - PhysicsConfig.Z_LOCK_PLANE) > 0.01 then
		rootPart.CFrame = CFrame.new(rootPart.Position.X, rootPart.Position.Y, PhysicsConfig.Z_LOCK_PLANE) * (rootPart.CFrame - rootPart.Position)
		rootPart.AssemblyLinearVelocity = Vector3.new(rootPart.AssemblyLinearVelocity.X, rootPart.AssemblyLinearVelocity.Y, 0)
	end
	
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
	
	-- Update 3D Selection Ring
	if not isFinished then
		nearestAnchor = getClosestGrapplePoint()
		if nearestAnchor and nearestAnchor:IsA("BasePart") and selectionRingRoot then
			if isGrappling and nearestAnchor == currentAnchor then
				setSelectionRingVisible(false)
			else
				ringRotationAngle = (ringRotationAngle + dt * 1.8) % (2 * math.pi)
				selectionRingRoot.CFrame = CFrame.new(nearestAnchor.Position.X, nearestAnchor.Position.Y, 0.45) * CFrame.Angles(0, 0, ringRotationAngle)
				setSelectionRingVisible(true)
			end
		else
			setSelectionRingVisible(false)
		end
	else
		setSelectionRingVisible(false)
	end
end)
