local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local character = nil
local rootPart = nil

local Events = ReplicatedStorage:WaitForChild("Events")
local GameStartedEvent = Events:WaitForChild("GameStartedEvent")
local ReturnToMenuEvent = Events:WaitForChild("ReturnToMenuEvent")
local LevelFinishedEvent = Events:WaitForChild("LevelFinishedEvent")
local SelectLevelEvent = Events:WaitForChild("SelectLevelEvent")
local LevelsFolder = ReplicatedStorage:WaitForChild("Levels")

local screenGui = playerGui:WaitForChild("Main")
screenGui.Enabled = true

-- 1. START MENU FRAME
local menuFrame = screenGui:WaitForChild("StartScreen")
local titleContainer = menuFrame:WaitForChild("TitleContainer")
local playBtn = menuFrame:WaitForChild("PlayButton")
local levelsBtn = menuFrame:WaitForChild("Levels")

-- 2. LEVELS MENU FRAME
local levelsFrame = screenGui:WaitForChild("Levels")
local levelsTitleContainer = levelsFrame:WaitForChild("TitleContainer")
local selectBtn = levelsFrame:WaitForChild("SelectButton")
local levelsGrid = levelsFrame:WaitForChild("LevelsContainer"):WaitForChild("Grid")
local levelBtnTemplate = script:WaitForChild("UIComponents"):WaitForChild("Level_1")

-- 3. GAMEPLAY HUD
local gameplayHUD = screenGui:WaitForChild("Hud")
local progressContainer = gameplayHUD:WaitForChild("ProgressContainer")
local levelStartLabel = progressContainer:WaitForChild("LevelStart")
local levelEndLabel = progressContainer:WaitForChild("LevelEnd")
local barFill = progressContainer:WaitForChild("BarBackground"):WaitForChild("BarFill")

-- 4. FINISH SCREEN FRAME
local finishFrame = screenGui:WaitForChild("FinishScreen")
local retryBtn = finishFrame:WaitForChild("RetryButton")
local menuReturnBtn = finishFrame:WaitForChild("MenuButton")
local FinishBlur = game.Lighting:WaitForChild("FinishBlur")

local COLOR_BTN_BLUE = Color3.fromRGB(70, 165, 255)
local COLOR_BTN_BLUE_HOVER = Color3.fromRGB(95, 185, 255)
local COLOR_BTN_GREEN = Color3.fromRGB(0, 230, 125)
local COLOR_BTN_GREEN_HOVER = Color3.fromRGB(25, 255, 145)

local selectedLevelName = "Level1"
local levelButtons = {}

local function playClickSound()
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/action_jump.mp3"
	sound.Volume = 0.8
	sound.Parent = screenGui
	sound:Play()
	Debris:AddItem(sound, 1.5)
end

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

local function getNextLevelInfo(currentName)
	local sorted = getSortedLevels()
	for i, info in ipairs(sorted) do
		if info.Name == currentName then
			if sorted[i + 1] then
				return sorted[i + 1]
			end
			return nil
		end
	end
	return nil
end

local function updateHudLevelLabels()
	local currNum = getLevelNumber(selectedLevelName)
	local nextInfo = getNextLevelInfo(selectedLevelName)
	local nextNum = nextInfo and nextInfo.Number or (currNum + 1)
	levelStartLabel.Text = tostring(currNum)
	levelEndLabel.Text = tostring(nextNum)
end

local function updateLevelButtonHighlights()
	for name, btn in pairs(levelButtons) do
		if btn and btn.Parent then
			local isSelected = (name == selectedLevelName)
			TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = isSelected and COLOR_BTN_GREEN or COLOR_BTN_BLUE
			}):Play()
		end
	end
end

local function selectLevel(levelName, notifyServer)
	if not levelName then return end
	selectedLevelName = levelName
	updateLevelButtonHighlights()
	updateHudLevelLabels()
	if notifyServer then
		SelectLevelEvent:FireServer(selectedLevelName)
	end
end

local function populateLevelsGrid()
	for _, child in ipairs(levelsGrid:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	table.clear(levelButtons)

	local sorted = getSortedLevels()
	if #sorted > 0 and not LevelsFolder:FindFirstChild(selectedLevelName) then
		selectedLevelName = sorted[1].Name
	end

	for _, info in ipairs(sorted) do
		local btn = levelBtnTemplate:Clone()
		btn.Name = info.Name
		btn.LayoutOrder = info.Number
		btn.Text = "Level " .. tostring(info.Number)
		btn.BackgroundColor3 = (info.Name == selectedLevelName) and COLOR_BTN_GREEN or COLOR_BTN_BLUE
		btn.Visible = true
		btn.Parent = levelsGrid
		levelButtons[info.Name] = btn

		btn.MouseEnter:Connect(function()
			local isSelected = (selectedLevelName == info.Name)
			TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				BackgroundColor3 = isSelected and COLOR_BTN_GREEN_HOVER or COLOR_BTN_BLUE_HOVER
			}):Play()
		end)

		btn.MouseLeave:Connect(function()
			local isSelected = (selectedLevelName == info.Name)
			TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = isSelected and COLOR_BTN_GREEN or COLOR_BTN_BLUE
			}):Play()
		end)

		btn.MouseButton1Click:Connect(function()
			playClickSound()
			selectLevel(info.Name, true)
		end)
	end

	updateHudLevelLabels()
end

populateLevelsGrid()
LevelsFolder.ChildAdded:Connect(function()
	task.wait()
	populateLevelsGrid()
end)
LevelsFolder.ChildRemoved:Connect(function()
	task.wait()
	populateLevelsGrid()
end)

-- Sync initial selected level with workspace.Map or leaderstats.Level
task.spawn(function()
	local mapFolder = workspace:WaitForChild("Map", 5)
	if mapFolder then
		local attrLevel = mapFolder:GetAttribute("CurrentLevel")
		if attrLevel and LevelsFolder:FindFirstChild(attrLevel) then
			selectLevel(attrLevel, false)
		end
		mapFolder:GetAttributeChangedSignal("CurrentLevel"):Connect(function()
			local newAttr = mapFolder:GetAttribute("CurrentLevel")
			if newAttr and LevelsFolder:FindFirstChild(newAttr) then
				selectLevel(newAttr, false)
			end
		end)
	end

	local leaderstats = player:WaitForChild("leaderstats", 10)
	local levelStat = leaderstats and leaderstats:WaitForChild("Level", 5)
	if levelStat then
		local sorted = getSortedLevels()
		local chosen = sorted[1] and sorted[1].Name or "Level1"
		for _, info in ipairs(sorted) do
			if info.Number <= levelStat.Value then
				chosen = info.Name
			end
		end
		selectLevel(chosen, true)
	end
end)

task.spawn(function()
	while menuFrame and menuFrame.Parent do
		TweenService:Create(titleContainer, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			Position = UDim2.new(0.5, -210, 0.135, 0)
		}):Play()
		task.wait(1.2)
		TweenService:Create(titleContainer, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			Position = UDim2.new(0.5, -210, 0.11, 0)
		}):Play()
		task.wait(1.2)
	end
end)

playBtn.MouseEnter:Connect(function()
	TweenService:Create(playBtn, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 260, 0, 78),
		Position = UDim2.new(0.5, -130, 0.809, 0),
		BackgroundColor3 = COLOR_BTN_GREEN_HOVER
	}):Play()
end)

playBtn.MouseLeave:Connect(function()
	TweenService:Create(playBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 240, 0, 72),
		Position = UDim2.new(0.5, -120, 0.819, 0),
		BackgroundColor3 = COLOR_BTN_GREEN
	}):Play()
end)

levelsBtn.MouseEnter:Connect(function()
	TweenService:Create(levelsBtn, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		BackgroundColor3 = COLOR_BTN_BLUE_HOVER
	}):Play()
end)

levelsBtn.MouseLeave:Connect(function()
	TweenService:Create(levelsBtn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundColor3 = COLOR_BTN_BLUE
	}):Play()
end)

selectBtn.MouseEnter:Connect(function()
	TweenService:Create(selectBtn, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		BackgroundColor3 = COLOR_BTN_GREEN_HOVER
	}):Play()
end)

selectBtn.MouseLeave:Connect(function()
	TweenService:Create(selectBtn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundColor3 = COLOR_BTN_GREEN
	}):Play()
end)

retryBtn.MouseEnter:Connect(function()
	TweenService:Create(retryBtn, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		BackgroundColor3 = COLOR_BTN_GREEN_HOVER
	}):Play()
end)
retryBtn.MouseLeave:Connect(function()
	TweenService:Create(retryBtn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundColor3 = COLOR_BTN_GREEN
	}):Play()
end)

menuReturnBtn.MouseEnter:Connect(function()
	TweenService:Create(menuReturnBtn, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		BackgroundColor3 = COLOR_BTN_BLUE_HOVER
	}):Play()
end)
menuReturnBtn.MouseLeave:Connect(function()
	TweenService:Create(menuReturnBtn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundColor3 = COLOR_BTN_BLUE
	}):Play()
end)

-- BUTTON EVENTS
levelsBtn.MouseButton1Click:Connect(function()
	playClickSound()
	updateLevelButtonHighlights()
	menuFrame.Visible = false
	levelsFrame.Position = UDim2.new(0, 0, -0.25, 0)
	levelsFrame.Visible = true
	TweenService:Create(levelsFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0)
	}):Play()
end)

selectBtn.MouseButton1Click:Connect(function()
	playClickSound()
	SelectLevelEvent:FireServer(selectedLevelName)
	updateHudLevelLabels()
	levelsFrame.Visible = false
	menuFrame.Position = UDim2.new(0, 0, -0.25, 0)
	menuFrame.Visible = true
	TweenService:Create(menuFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0)
	}):Play()
end)

playBtn.MouseButton1Click:Connect(function()
	playClickSound()
	SelectLevelEvent:FireServer(selectedLevelName)
	updateHudLevelLabels()

	TweenService:Create(menuFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, -1, 0)
	}):Play()

	task.wait(0.3)
	menuFrame.Visible = false
	levelsFrame.Visible = false
	finishFrame.Visible = false
	gameplayHUD.Visible = true

	GameStartedEvent:Fire()
end)

LevelFinishedEvent.Event:Connect(function()
	gameplayHUD.Visible = false
	finishFrame.Position = UDim2.new(0, 0, -0.3, 0)
	finishFrame.Visible = true
	TweenService:Create(finishFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0)
	}):Play()
	task.wait(3)
	if finishFrame.Visible == false then return end
	TweenService:Create(FinishBlur, TweenInfo.new(1.65, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = 32
	}):Play()
	task.wait(1.5)
	if finishFrame.Visible == false then return end
	if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		player.Character.HumanoidRootPart.Anchored = true
	end
end)

retryBtn.Text = "Next Level"

retryBtn.MouseButton1Click:Connect(function()
	if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		player.Character.HumanoidRootPart.Anchored = false
	end
	playClickSound()

	-- Advance to the next level (or stay on current if it's the final level)
	local nextInfo = getNextLevelInfo(selectedLevelName)
	if nextInfo then
		selectLevel(nextInfo.Name, true)
	else
		selectLevel(selectedLevelName, true)
	end

	finishFrame.Visible = false
	menuFrame.Visible = false
	levelsFrame.Visible = false

	TweenService:Create(FinishBlur, TweenInfo.new(1.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = 0
	}):Play()

	-- Give the server a brief moment to clone the new level into workspace.Map before respawning
	task.wait(0.08)
	gameplayHUD.Visible = true

	GameStartedEvent:Fire()
end)

menuReturnBtn.MouseButton1Click:Connect(function()
	if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		player.Character.HumanoidRootPart.Anchored = false
	end
	playClickSound()

	-- Automatically select the next level if available
	local nextInfo = getNextLevelInfo(selectedLevelName)
	if nextInfo then
		selectLevel(nextInfo.Name, true)
	end

	finishFrame.Visible = false
	gameplayHUD.Visible = false
	levelsFrame.Visible = false

	TweenService:Create(FinishBlur, TweenInfo.new(1.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = 0
	}):Play()

	menuFrame.Position = UDim2.new(0, 0, -1, 0)
	menuFrame.Visible = true
	TweenService:Create(menuFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0)
	}):Play()

	ReturnToMenuEvent:Fire()
end)

local function onCharacterAdded(newChar)
	character = newChar
	rootPart = character:WaitForChild("HumanoidRootPart")
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then onCharacterAdded(player.Character) end

local function getFinishX()
	local map = workspace:FindFirstChild("Map")
	local lines = map and map:FindFirstChild("Lines", true)
	local fin = lines and lines:FindFirstChild("Finish")
	if fin and fin:IsA("BasePart") then
		return fin.Position.X
	end
	return 351.25
end

local function getStartX()
	local spawnLoc = workspace:FindFirstChildOfClass("SpawnLocation")
	if spawnLoc then
		return spawnLoc.Position.X
	end
	return -16
end

RunService.RenderStepped:Connect(function()
	if not rootPart or not gameplayHUD.Visible then return end
	local startX = getStartX()
	local finishX = getFinishX()
	local progress = math.clamp((rootPart.Position.X - startX) / math.max(1, (finishX - startX)), 0, 1)
	barFill.Size = UDim2.new(progress, 0, 1, 0)
end)
