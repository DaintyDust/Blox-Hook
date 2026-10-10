local DataStoreService = game:GetService("DataStoreService")
local LevelsStore = DataStoreService:GetDataStore("Levels")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Events = ReplicatedStorage:WaitForChild("Events")
local ForceRespawnEvent = Events:WaitForChild("ForceRespawnEvent")
local GetLevelEvent = Events:WaitForChild("GetLevel")

local DEFAULT_DATA = {
	Level = 1,
	Deaths = 0,
	Wins = 0,
}

local MIN_WIN_TIME = 1.2
local MAX_STEP_DISTANCE_X = 60
local DEATH_COOLDOWN = 0.5

local playerStates = {}

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

local function savePlayerDataAsync(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end

	local userId = tostring(player.UserId)
	local data = {}
	for _, stat in ipairs(leaderstats:GetChildren()) do
		data[stat.Name] = stat.Value
	end

	pcall(function()
		LevelsStore:SetAsync(userId, data)
	end)
end

local function addDeath(player)
	local state = playerStates[player]
	local now = os.clock()
	if state then
		if now - state.lastDeathTime < DEATH_COOLDOWN then
			return
		end
		state.lastDeathTime = now
		state.inActiveRun = false
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local deaths = leaderstats and leaderstats:FindFirstChild("Deaths")
	if deaths then
		deaths.Value += 1
	end
end

local function addWin(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end

	local wins = leaderstats:FindFirstChild("Wins")
	if wins then
		wins.Value += 1
	end

	local levelStat = leaderstats:FindFirstChild("Level")
	if levelStat then
		local mapFolder = workspace:FindFirstChild("Map")
		local activeNum = mapFolder and mapFolder:GetAttribute("CurrentLevelNumber")
		if not activeNum then
			local activeName = mapFolder and mapFolder:GetAttribute("CurrentLevel") or ""
			activeNum = tonumber(string.match(activeName, "%d+")) or 1
		end
		if levelStat.Value <= activeNum then
			levelStat.Value = activeNum + 1
		end
	end

	task.spawn(function()
		savePlayerDataAsync(player)
	end)
end

local function createLeaderStats(Player, Data)
	local leaderStatsFolder = Instance.new("Folder")
	leaderStatsFolder.Name = "leaderstats"
	leaderStatsFolder.Parent = Player

	local savedLevel = tonumber(Data.Level) or DEFAULT_DATA.Level
	if savedLevel < 1 then
		savedLevel = 1
	end

	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = savedLevel
	level.Parent = leaderStatsFolder

	local deaths = Instance.new("IntValue")
	deaths.Name = "Deaths"
	deaths.Value = Data.Deaths or DEFAULT_DATA.Deaths
	deaths.Parent = leaderStatsFolder

	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Value = Data.Wins or DEFAULT_DATA.Wins
	wins.Parent = leaderStatsFolder
end

local function setupCharacterListener(player)
	local startPos = getSpawnPosition()
	playerStates[player] = {
		inActiveRun = false,
		hasWon = false,
		runStartTime = os.clock(),
		lastX = startPos.X,
		lastDeathTime = 0,
	}

	local function onCharacterAdded(char)
		local state = playerStates[player]
		if state then
			local spawnpoint = getSpawnPosition()
			state.inActiveRun = false
			state.hasWon = false
			state.runStartTime = os.clock()
			state.lastX = spawnpoint.X
		end

		local humanoid = char:WaitForChild("Humanoid", 5)
		if humanoid then
			humanoid.Died:Connect(function()
				addDeath(player)
			end)
		end
	end

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

local function loadData(player)
	setupCharacterListener(player)

	local userId = tostring(player.UserId)
	local success, data = pcall(function()
		return LevelsStore:GetAsync(userId)
	end)

	if not success then
		warn(`Couldn't load the data for {player.Name}`)
		data = table.clone(DEFAULT_DATA)
	elseif data == nil then
		data = table.clone(DEFAULT_DATA)
		pcall(function()
			LevelsStore:SetAsync(userId, data)
		end)
	end

	createLeaderStats(player, data)
end

local function saveData(player)
	playerStates[player] = nil
	savePlayerDataAsync(player)
end

local function getLevel(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local level = leaderstats:FindFirstChild("Level")
		if level then
			return level.Value
		end
	end
	return nil
end

RunService.Heartbeat:Connect(function(dt)
	local startPos = getSpawnPosition()
	local deadBelowY, deadAboveY, finishX = getBoundaryLines()
	local now = os.clock()

	for _, player in ipairs(Players:GetPlayers()) do
		local state = playerStates[player]
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local humanoid = char and char:FindFirstChild("Humanoid")

		if state and root and humanoid and humanoid.Health > 0 then
			local pos = root.Position

			if math.abs(pos.Z) < 12 then
				if math.abs(pos.X - startPos.X) < 22 and math.abs(pos.Y - startPos.Y) < 30 then
					state.hasWon = false
					if not state.inActiveRun or pos.X <= startPos.X + 8 then
						state.inActiveRun = true
						state.runStartTime = now
						state.lastX = pos.X
					end
				end

				if not state.hasWon then
					local deltaX = pos.X - state.lastX
					local maxAllowedStep = math.max(350 * dt, MAX_STEP_DISTANCE_X)
					if state.inActiveRun and deltaX > maxAllowedStep then
						warn(`Suspicious teleport detected for {player.Name} (deltaX: {math.floor(deltaX)})`)
						state.inActiveRun = false
						root.CFrame = CFrame.new(startPos)
						root.AssemblyLinearVelocity = Vector3.zero
						root.AssemblyAngularVelocity = Vector3.zero
						state.lastX = startPos.X
						if ForceRespawnEvent and ForceRespawnEvent:IsA("RemoteEvent") then
							ForceRespawnEvent:FireClient(player)
						end
						continue
					end
					state.lastX = pos.X

					if pos.X < finishX and (pos.Y < deadBelowY or pos.Y > deadAboveY) then
						addDeath(player)
						root.CFrame = CFrame.new(startPos)
						root.AssemblyLinearVelocity = Vector3.zero
						root.AssemblyAngularVelocity = Vector3.zero
						state.lastX = startPos.X
						if ForceRespawnEvent and ForceRespawnEvent:IsA("RemoteEvent") then
							ForceRespawnEvent:FireClient(player)
						end
						continue
					end

					if state.inActiveRun and pos.X >= finishX then
						local runDuration = now - state.runStartTime
						if runDuration >= MIN_WIN_TIME then
							state.hasWon = true
							state.inActiveRun = false
							addWin(player)
						else
							warn(`Won too fast blocked for {player.Name} ({string.format("%.2f", runDuration)}s)`)
							state.inActiveRun = false
							root.CFrame = CFrame.new(startPos)
							root.AssemblyLinearVelocity = Vector3.zero
							root.AssemblyAngularVelocity = Vector3.zero
							state.lastX = startPos.X
							if ForceRespawnEvent and ForceRespawnEvent:IsA("RemoteEvent") then
								ForceRespawnEvent:FireClient(player)
							end
						end
					end
				end
			else
				state.inActiveRun = false
				state.hasWon = false
			end
		end
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadData, player)
end
Players.PlayerAdded:Connect(loadData)
Players.PlayerRemoving:Connect(saveData)
GetLevelEvent.OnServerInvoke = function(player)
	return getLevel(player)
end

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveData(player)
	end
end)
