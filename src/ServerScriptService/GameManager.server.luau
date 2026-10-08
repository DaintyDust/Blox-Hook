local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Players.RespawnTime = 0.2

local ForceRespawnEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("ForceRespawnEvent")

local SERVER_VOID_MARGIN = 8

local function getSpawnPosition()
	local spawnLoc = workspace:FindFirstChildOfClass("SpawnLocation")
	if spawnLoc then
		return Vector3.new(spawnLoc.Position.X, spawnLoc.Position.Y + 14, 0)
	end
	return Vector3.new(-16, 16, 0)
end

local function getBoundaryLines()
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

local function onCharacterAdded(player, char)
	local root = char:WaitForChild("HumanoidRootPart", 5)
	local humanoid = char:WaitForChild("Humanoid", 5)
	if not root or not humanoid then return end

	humanoid.Died:Connect(function()
		task.wait(0.15)
		if player and player.Parent then
			player:LoadCharacter()
		end
	end)

	task.spawn(function()
		while char and char.Parent and humanoid.Health > 0 do
			task.wait(0.08)
			if math.abs(root.Position.Z) < 10 then
				local deadBelowY, deadAboveY, finishX = getBoundaryLines()
				if root.Position.X < finishX then
					if root.Position.Y < (deadBelowY - SERVER_VOID_MARGIN) or root.Position.Y > (deadAboveY + SERVER_VOID_MARGIN) then
						local startPos = getSpawnPosition()
						root.CFrame = CFrame.new(startPos)
						root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
						root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
						ForceRespawnEvent:FireClient(player)
					end
				end
			end
		end
	end)
end

local function setupPlayerVoidCheck(player)
	player.CharacterAdded:Connect(function(char)
		onCharacterAdded(player, char)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayerVoidCheck(player)
end
Players.PlayerAdded:Connect(setupPlayerVoidCheck)
