local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

Players.RespawnTime = 0.2

local ForceRespawnEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("ForceRespawnEvent")

local PlayerVoidedEvent = Instance.new("BindableEvent")
PlayerVoidedEvent.Name = "PlayerVoidedEvent"
PlayerVoidedEvent.Parent = ServerStorage

local function getSpawnPosition()
	local spawnLocation = workspace:FindFirstChildOfClass("SpawnLocation")
	if spawnLocation then
		return Vector3.new(spawnLocation.Position.X, spawnLocation.Position.Y + 14, 0)
	end
	return Vector3.new(-16, 16, 0)
end

local function getBoundaryLines()
	local map = workspace:FindFirstChild("Map")
	local lines = map and map:FindFirstChild("Lines", true)
	local deadBelowY = -88
	local deadAboveY = 252
	local finishX = 351.25
	if lines then
		local deadBelow = lines:FindFirstChild("DeadBelow")
		local deadAbove = lines:FindFirstChild("DeadAbove")
		local finish = lines:FindFirstChild("Finish")
		if deadBelow and deadBelow:IsA("BasePart") then deadBelowY = deadBelow.Position.Y end
		if deadAbove and deadAbove:IsA("BasePart") then deadAboveY = deadAbove.Position.Y end
		if finish and finish:IsA("BasePart") then finishX = finish.Position.X end
	end
	return deadBelowY, deadAboveY, finishX
end

local function onCharacterAdded(player, char)
	local humanoid = char:WaitForChild("Humanoid", 5)
	if not humanoid then return end

	humanoid.Died:Connect(function()
		task.wait(0.15)
		if player and player.Parent then
			player:LoadCharacter()
		end
	end)
end

local function setupPlayer(player)
	player.CharacterAdded:Connect(function(char)
		onCharacterAdded(player, char)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

RunService.Heartbeat:Connect(function()
	local startPos = getSpawnPosition()
	local deadBelowY, deadAboveY, finishX = getBoundaryLines()

	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local humanoid = char and char:FindFirstChild("Humanoid")

		if root and humanoid and humanoid.Health > 0 then
			local pos = root.Position
			if math.abs(pos.Z) < 12 and pos.X < finishX and (pos.Y < deadBelowY or pos.Y > deadAboveY) then
				root.CFrame = CFrame.new(startPos)
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				ForceRespawnEvent:FireClient(player)
				PlayerVoidedEvent:Fire(player)
			end
		end
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end
Players.PlayerAdded:Connect(setupPlayer)
