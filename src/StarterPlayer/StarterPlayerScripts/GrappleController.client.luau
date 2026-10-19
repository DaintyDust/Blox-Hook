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

-- Invisible Rope Grip Part & IKControls
local ropeGripPart = nil
local gripAttachment = nil
local leftGripAttach = nil
local rightGripAttach = nil
local ikLeft = nil
local ikRight = nil

local isMenuMode = true
local isFinished = false
local isGrappling = false
local isPauzed = false
local currentAnchor = nil
local ropeLength = 0
local swingAngle = 0
local angularVelocity = 0

local activeBeam = nil
local ropeAttachment1 = nil
local nearestAnchor = nil

-- 3D Dashed Selection Ring
local selectionRingModel = nil
local selectionRingRoot = nil
local ringDashParts = {}
local ringRotationAngle = 0

local menuTime = 0
local menuBeam = nil
local menuAttach1 = nil

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local LevelFinishedEvent = Events:WaitForChild("LevelFinishedEvent")

local function setIKActive(active)
    if ikLeft then ikLeft.Enabled = active end
    if ikRight then ikRight.Enabled = active end
end

local function updateGripPosition(playerPos, anchorPos)
    if not ropeGripPart then return end
    local diff = anchorPos - playerPos
    local dir = diff.Magnitude > 0.01 and diff.Unit or Vector3.new(0, 1, 0)
    local gripPos = playerPos + dir * 2.4
    ropeGripPart.CFrame = CFrame.lookAt(gripPos, anchorPos)
end

local function setupRopeGripAndIK(newChar)
    if ropeGripPart then ropeGripPart:Destroy() ropeGripPart = nil end
    if ikLeft then ikLeft:Destroy() ikLeft = nil end
    if ikRight then ikRight:Destroy() ikRight = nil end

    ropeGripPart = Instance.new("Part")
    ropeGripPart.Name = "RopeGripPart"
    ropeGripPart.Size = Vector3.new(0.4, 0.4, 0.4)
    ropeGripPart.Transparency = 1
    ropeGripPart.Anchored = true
    ropeGripPart.CanCollide = false
    ropeGripPart.CanTouch = false
    ropeGripPart.CanQuery = false
    ropeGripPart.Massless = true
    ropeGripPart.CFrame = rootPart.CFrame * CFrame.new(0, 2.4, 0)
    ropeGripPart.Parent = newChar

    gripAttachment = Instance.new("Attachment")
    gripAttachment.Name = "RopeGripCenter"
    gripAttachment.Position = Vector3.new(0, 0, 0)
    gripAttachment.Parent = ropeGripPart

    leftGripAttach = Instance.new("Attachment")
    leftGripAttach.Name = "LeftHandGrip"
    leftGripAttach.Position = Vector3.new(-0.15, 0, 0)
    leftGripAttach.Parent = ropeGripPart

    rightGripAttach = Instance.new("Attachment")
    rightGripAttach.Name = "RightHandGrip"
    rightGripAttach.Position = Vector3.new(0.15, 0, 0)
    rightGripAttach.Parent = ropeGripPart

    local leftUpperArm = newChar:WaitForChild("LeftUpperArm", 3)
    local leftHand = newChar:WaitForChild("LeftHand", 3)
    local rightUpperArm = newChar:WaitForChild("RightUpperArm", 3)
    local rightHand = newChar:WaitForChild("RightHand", 3)

    if leftUpperArm and leftHand and rightUpperArm and rightHand and humanoid then
        ikLeft = Instance.new("IKControl")
        ikLeft.Name = "LeftArmRopeIK"
        ikLeft.Type = Enum.IKControlType.Position
        ikLeft.ChainRoot = leftUpperArm
        ikLeft.EndEffector = leftHand
        ikLeft.Target = leftGripAttach
        ikLeft.Weight = 1
        ikLeft.SmoothTime = 0.03
        ikLeft.Enabled = false
        ikLeft.Parent = humanoid

        ikRight = Instance.new("IKControl")
        ikRight.Name = "RightArmRopeIK"
        ikRight.Type = Enum.IKControlType.Position
        ikRight.ChainRoot = rightUpperArm
        ikRight.EndEffector = rightHand
        ikRight.Target = rightGripAttach
        ikRight.Weight = 1
        ikRight.SmoothTime = 0.03
        ikRight.Enabled = false
        ikRight.Parent = humanoid
    end
end

local function updateRaycastFilter()
	local filterList = {}
	if character then
		table.insert(filterList, character)
	end
	for _, anchor in ipairs(CollectionService:GetTagged("GrappleAnchor")) do
		if anchor:IsDescendantOf(workspace) then
			table.insert(filterList, anchor)
		end
	end
	local map = workspace:FindFirstChild("Map")
	local lines = map and map:FindFirstChild("Lines", true)
	if lines then
		table.insert(filterList, lines)
	end
	raycastParams.FilterDescendantsInstances = filterList
end

local function getLevelLines()
	local map = workspace:FindFirstChild("Map")
    local lines = map and map:FindFirstChild("Lines", true)
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

local function setupMenuVisuals()
    local anchor = getMainScreenAnchor()
    if not anchor or not rootPart then return end
    
    if menuBeam then menuBeam:Destroy() menuBeam = nil end
    if menuAttach1 then menuAttach1:Destroy() menuAttach1 = nil end
    
    setAnchorActive(anchor, true)
    setSelectionRingVisible(false)
    
    menuAttach1 = anchor:FindFirstChild("AnchorAttachment")
    if not menuAttach1 then
        menuAttach1 = Instance.new("Attachment")
        menuAttach1.Name = "AnchorAttachment"
        menuAttach1.Parent = anchor
    end
    
    local startPos = Vector3.new(anchor.Position.X, anchor.Position.Y - 12, anchor.Position.Z)
    rootPart.CFrame = CFrame.new(startPos) * CFrame.Angles(0, math.rad(180), 0)
    rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    
    updateGripPosition(startPos, anchor.Position)
    setIKActive(true)
    
    menuBeam = Instance.new("Beam")
    menuBeam.Name = "MenuBeam"
    menuBeam.Attachment0 = gripAttachment
    menuBeam.Attachment1 = menuAttach1
    menuBeam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
    menuBeam.Width0 = PhysicsConfig.ROPE_THICKNESS or 0.22
    menuBeam.Width1 = PhysicsConfig.ROPE_THICKNESS or 0.22
    menuBeam.FaceCamera = true
    menuBeam.LightEmission = 0.5
    menuBeam.LightInfluence = 0
    menuBeam.Parent = rootPart
end

local function respawnAtStart()
	if isMenuMode or not rootPart then return end
	if isGrappling then
		if currentAnchor then
			setAnchorActive(currentAnchor, false)
		end
		if activeBeam then activeBeam:Destroy() activeBeam = nil end
		isGrappling = false
		currentAnchor = nil
	end

	setSelectionRingVisible(false)
	setIKActive(false)

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

local GameStartedEvent = Events:WaitForChild("GameStartedEvent")
GameStartedEvent.Event:Connect(function()
    isMenuMode = false
    isFinished = false
    
    local menuAnchor = getMainScreenAnchor()
    if menuAnchor then
        setAnchorActive(menuAnchor, false)
    end
    
    if menuBeam then menuBeam:Destroy() menuBeam = nil end
    setIKActive(false)
    
    if rootPart then
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
end)

local ReturnToMenuEvent = Events:WaitForChild("ReturnToMenuEvent")
ReturnToMenuEvent.Event:Connect(function()
    isMenuMode = true
    isFinished = false
    setupMenuVisuals()
end)

local ForceRespawnEvent = Events:WaitForChild("ForceRespawnEvent", 10)
if ForceRespawnEvent and ForceRespawnEvent:IsA("RemoteEvent") then
    ForceRespawnEvent.OnClientEvent:Connect(function()
        respawnAtStart()
    end)
end

local savedAngularVelocity = 0
local savedLinearVelocity = Vector3.zero

local GamePauzedEvent = Events:WaitForChild("GamePauzedEvent", 10)
GamePauzedEvent.Event:Connect(function(state)
	isPauzed = state
	if state then
		savedAngularVelocity = angularVelocity
		if rootPart then
			savedLinearVelocity = rootPart.AssemblyLinearVelocity
			rootPart.AssemblyLinearVelocity = Vector3.zero
			rootPart.AssemblyAngularVelocity = Vector3.zero
		end
	else
		angularVelocity = savedAngularVelocity
		if rootPart then
			rootPart.AssemblyLinearVelocity = savedLinearVelocity
		end
	end
end)


local function triggerFinishSequence()
	if isFinished or isMenuMode or isPauzed then return end
    isFinished = true
    
    setSelectionRingVisible(false)
    setIKActive(false)
    
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
        while isFinished and not isMenuMode do
            task.wait(0.03)
			if rootPart and isFinished and not isMenuMode and not isPauzed then
                local v = rootPart.AssemblyLinearVelocity
                rootPart.AssemblyLinearVelocity = Vector3.new(v.X * 0.94, math.max(v.Y * 0.90, -10), 0)
            end
        end
    end)
end

local function getClosestGrapplePoint()
	if not rootPart or isMenuMode or isFinished or isPauzed then return nil end
    local anchors = CollectionService:GetTagged("GrappleAnchor")
    local closestAnchor = nil
    local minDistance = PhysicsConfig.MAX_GRAPPLE_DISTANCE or 95
    
    local playerPos = rootPart.Position
    
	for _, anchor in ipairs(anchors) do
		if not anchor:IsDescendantOf(game.Workspace) then continue end
        if anchor:IsA("BasePart") then
            local mainScreen = workspace:FindFirstChild("MainScreen") or workspace:FindFirstChild("Mainscreen")
            if not mainScreen or not anchor:IsDescendantOf(mainScreen) then
                local dist = (anchor.Position - playerPos).Magnitude
                if dist < minDistance then
                    minDistance = dist
                    closestAnchor = anchor
                end
            end
        end
    end
    return closestAnchor
end

local function startGrapple()
	if isMenuMode or isFinished or isGrappling or isPauzed or not rootPart or not nearestAnchor then return end
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
    
    updateGripPosition(playerPos, anchorPos)
    setIKActive(true)
    
    ropeAttachment1 = currentAnchor:FindFirstChild("AnchorAttachment") or Instance.new("Attachment", currentAnchor)
    ropeAttachment1.Name = "AnchorAttachment"
    
    activeBeam = Instance.new("Beam")
    activeBeam.Name = "GrappleRopeBeam"
    activeBeam.Attachment0 = gripAttachment
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
    if isMenuMode or not isGrappling then return end
    isGrappling = false
    
    setIKActive(false)
    
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
    if gameProcessed or isMenuMode or isFinished or isPauzed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 
        or input.UserInputType == Enum.UserInputType.Touch
        or input.KeyCode == Enum.KeyCode.Space
        or input.KeyCode == Enum.KeyCode.ButtonR2 then
        startGrapple()
    end
end)

UserInputService.InputEnded:Connect(function(input)
	if isMenuMode or isFinished or isPauzed then return end
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
    
    setupRopeGripAndIK(newChar)
    
    local filterList = {character}
	for _, anchor in ipairs(CollectionService:GetTagged("GrappleAnchor")) do
		if not anchor:IsDescendantOf(game.Workspace) then continue end
        table.insert(filterList, anchor)
    end
	local map = workspace:FindFirstChild("Map")
    local lines = map and map:FindFirstChild("Lines", true)
    if lines then
        table.insert(filterList, lines)
    end
    raycastParams.FilterDescendantsInstances = filterList
    
    if isMenuMode then
        setupMenuVisuals()
    else
        respawnAtStart()
    end
    
    humanoid.Died:Connect(function()
        if isGrappling then
            releaseGrapple()
        end
        setSelectionRingVisible(false)
        setIKActive(false)
    end)
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then onCharacterAdded(player.Character) end

resetAllAnchorsToDefault()
create3DSelectionRing()

RunService.Heartbeat:Connect(function(dt)
    if not rootPart then return end
    
    if isMenuMode then
        setSelectionRingVisible(false)
        local anchor = getMainScreenAnchor()
        if anchor then
            menuTime = menuTime + dt
            local theta = 0.5 * math.sin(menuTime * 1.8)
            local ropeL = 12.0
            local targetX = anchor.Position.X + ropeL * math.sin(theta)
            local targetY = anchor.Position.Y - ropeL * math.cos(theta)
            local targetZ = anchor.Position.Z
            
            local newPos = Vector3.new(targetX, targetY, targetZ)
            local tiltAngle = theta * 0.85
            rootPart.CFrame = CFrame.new(newPos) * CFrame.Angles(0, math.rad(180), 0) * CFrame.Angles(0, 0, -tiltAngle)
            rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            
            updateGripPosition(newPos, anchor.Position)
            setIKActive(true)
        end
        return
    end

    if isPauzed then
        if isGrappling and currentAnchor and currentAnchor:IsA("BasePart") then
            updateGripPosition(rootPart.Position, currentAnchor.Position)
            setIKActive(true)
        end
        return
    end
    
    local deadBelowY, deadAboveY, finishThresholdX = getLevelLines()
    
    if not isFinished then
        if rootPart.Position.Y < (deadBelowY - 15) or rootPart.Position.Y > (deadAboveY + 15) then
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
        local hitNormal = hitResult and Vector3.new(hitResult.Normal.X, hitResult.Normal.Y, 0)
        local swingDir = Vector3.new(math.cos(nextAngle), math.sin(nextAngle), 0) * math.sign(angularVelocity)
        if hitResult and hitResult.Instance and hitResult.Instance.CanCollide and hitNormal.Magnitude > 0.001 and swingDir:Dot(hitNormal) < 0 then
            hitNormal = hitNormal.Unit
            finalPos = hitResult.Position + (hitNormal * (characterRadius + 0.1))
            finalPos = Vector3.new(finalPos.X, finalPos.Y, PhysicsConfig.Z_LOCK_PLANE)
            
            local contactRel = finalPos - anchorPos
            ropeLength = math.clamp(contactRel.Magnitude, 5, PhysicsConfig.MAX_GRAPPLE_DISTANCE or 95)
            swingAngle = math.atan2(contactRel.X, -contactRel.Y)
            
            local tangent = Vector3.new(math.cos(swingAngle), math.sin(swingAngle), 0)
            local awayDir = (tangent:Dot(hitNormal) >= 0) and 1 or -1
            local isBouncePad = CollectionService:HasTag(hitResult.Instance, "BouncePad")
            local restitution = isBouncePad and (PhysicsConfig.SWING_PAD_RESTITUTION or 1.1) or (PhysicsConfig.SWING_WALL_RESTITUTION or 0.6)
            local minSpeed = isBouncePad and (PhysicsConfig.SWING_PAD_MIN_BOUNCE_SPEED or 55) or (PhysicsConfig.SWING_WALL_MIN_BOUNCE_SPEED or 22)
            local bounceSpeed = math.max(math.abs(angularVelocity) * ropeLength * restitution, minSpeed)
            angularVelocity = awayDir * bounceSpeed / ropeLength
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
        
        updateGripPosition(finalPos, anchorPos)
        setIKActive(true)
    else
        if ropeGripPart then
            ropeGripPart.CFrame = rootPart.CFrame * CFrame.new(0, 2.4, 0)
        end
    end
    
    -- Update 3D Selection Ring
	if not isFinished and not isMenuMode and not isPauzed then
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

task.spawn(function()
	local mapFolder = workspace:WaitForChild("Map", 10)
	if mapFolder then
		mapFolder.ChildAdded:Connect(function()
			task.wait()
			updateRaycastFilter()
			if not isMenuMode then
				resetAllAnchorsToDefault()
			end
		end)
	end
end)
