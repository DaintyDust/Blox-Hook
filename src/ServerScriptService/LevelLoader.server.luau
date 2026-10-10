local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Events = ReplicatedStorage:WaitForChild("Events")
local SelectLevelEvent = Events:WaitForChild("SelectLevelEvent")
local LevelsFolder = ReplicatedStorage:WaitForChild("Levels")

local function getLevelNumber(name)
	return tonumber(string.match(name or "", "%d+")) or 1
end

local function getSortedLevels()
	local list = {}
	for _, folder in ipairs(LevelsFolder:GetChildren()) do
		if folder:IsA("Folder") or folder:IsA("Model") then
			table.insert(list, {
				Instance = folder,
				Name = folder.Name,
				Number = getLevelNumber(folder.Name),
			})
		end
	end
	table.sort(list, function(a, b)
		if a.Number ~= b.Number then
			return a.Number < b.Number
		end
		return a.Name < b.Name
	end)
	return list
end

local function getLevelNameForNumber(levelNum)
	local sorted = getSortedLevels()
	if #sorted == 0 then return nil end
	local chosen = sorted[1].Name
	for _, info in ipairs(sorted) do
		if info.Number == levelNum then
			return info.Name
		elseif info.Number <= levelNum then
			chosen = info.Name
		end
	end
	return chosen
end

local function loadLevelIntoMap(levelName)
	if not levelName then return false end
	local targetLevel = LevelsFolder:FindFirstChild(levelName)
	if not targetLevel then
		local sorted = getSortedLevels()
		if #sorted > 0 then
			targetLevel = sorted[1].Instance
		else
			return false
		end
	end

	local mapFolder = workspace:FindFirstChild("Map")
	if not mapFolder then
		mapFolder = Instance.new("Folder")
		mapFolder.Name = "Map"
		mapFolder.Parent = workspace
	end

	mapFolder:ClearAllChildren()
	for _, child in ipairs(targetLevel:GetChildren()) do
		local clone = child:Clone()
		clone.Parent = mapFolder
	end

	local num = getLevelNumber(targetLevel.Name)
	mapFolder:SetAttribute("CurrentLevel", targetLevel.Name)
	mapFolder:SetAttribute("CurrentLevelNumber", num)
	return true
end

SelectLevelEvent.OnServerEvent:Connect(function(player, requestedLevelName)
	if type(requestedLevelName) ~= "string" then return end
	loadLevelIntoMap(requestedLevelName)
end)

do
	local mapFolder = workspace:FindFirstChild("Map")
	local currentAttr = mapFolder and mapFolder:GetAttribute("CurrentLevel")
	if not currentAttr or not LevelsFolder:FindFirstChild(currentAttr) then
		local sorted = getSortedLevels()
		if #sorted > 0 then
			loadLevelIntoMap(sorted[1].Name)
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	local leaderstats = player:WaitForChild("leaderstats", 10)
	local levelStat = leaderstats and leaderstats:WaitForChild("Level", 5)
	if levelStat then
		local targetLevelName = getLevelNameForNumber(levelStat.Value)
		local mapFolder = workspace:FindFirstChild("Map")
		if not mapFolder or not mapFolder:GetAttribute("CurrentLevel") then
			if targetLevelName then
				loadLevelIntoMap(targetLevelName)
			end
		end
	end
end)
