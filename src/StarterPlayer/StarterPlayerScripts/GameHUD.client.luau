local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InputService = game:GetService("UserInputService")
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
local GetLevelEvent = Events:WaitForChild("GetLevel")
local GamePauzedEvent = Events:WaitForChild("GamePauzedEvent")
local LevelsFolder = ReplicatedStorage:WaitForChild("Levels")

local screenGui = playerGui:WaitForChild("Main")
screenGui.Enabled = true

-- 1. START MENU FRAME
local menuFrame = screenGui:WaitForChild("StartScreen")
menuFrame.Visible = true
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
local continueBtn = finishFrame:WaitForChild("ContinueButton")
local menuReturnBtn = finishFrame:WaitForChild("MenuButton")
local FinishBlur = game.Lighting:WaitForChild("FinishBlur")

-- 5. PAUZE SCREEN FRAME
local pauzeFrame = screenGui:WaitForChild("PauzeScreen")
local pauzeLabel = pauzeFrame:WaitForChild("PauzeLabel")
local pauzeButton = gameplayHUD:WaitForChild("PauzeButton")
local pauzeImage = pauzeButton:WaitForChild("PauzeImage")
local playImage = pauzeButton:WaitForChild("PlayImage")

local COLOR_BTN_BLUE = Color3.fromRGB(70, 165, 255)
local COLOR_BTN_BLUE_HOVER = Color3.fromRGB(95, 185, 255)
local COLOR_BTN_BLUE_LOCKED = Color3.fromRGB(43, 103, 158)
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
		local currentLevel = GetLevelEvent:InvokeServer()
		local locked = btn:FindFirstChild("LevelLock")
		local levelText = btn:FindFirstChild("LevelText")
		local levelNumber = tonumber(string.match(name, "%d+"))
		if levelNumber <= currentLevel then
			locked.Visible = false
			levelText.Visible = true
			btn.Interactable = true
		end
		if btn and btn.Parent and not btn.LevelLock.Visible then
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
		local locked = btn:FindFirstChild("LevelLock")
		local levelText = btn:FindFirstChild("LevelText")
		local currentLevel = GetLevelEvent:InvokeServer()
		btn.Name = info.Name
		btn.LayoutOrder = info.Number
		levelText.Text = "Level " .. tostring(info.Number)
		btn.BackgroundColor3 = (info.Name == selectedLevelName) and COLOR_BTN_GREEN or COLOR_BTN_BLUE
		btn.Visible = true
		btn.Parent = levelsGrid
		levelButtons[info.Name] = btn
		if info.Number > currentLevel then
			locked.Visible = true
			levelText.Visible = false
			btn.BackgroundColor3 = COLOR_BTN_BLUE_LOCKED
			btn.Interactable = false
		end

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

local camera = workspace.CurrentCamera
local currentOrientationIsPortrait = nil

local function updateResponsiveLayout()
	if not screenGui or not screenGui.Parent then return end
	local viewportSize = camera.ViewportSize
	if viewportSize.X <= 0 or viewportSize.Y <= 0 then return end

	local isPortrait = (viewportSize.Y > viewportSize.X)
	local shortAxis = math.min(viewportSize.X, viewportSize.Y)
	local isSmallPhone = shortAxis < 500

	local strokeScale = math.clamp(shortAxis / 720, 0.45, 1.6)
	local cornerScale = math.clamp(shortAxis / 720, 0.5, 1.5)

	for _, desc in ipairs(screenGui:GetDescendants()) do
		if desc:IsA("UIStroke") then
			local base = desc:GetAttribute("BaseThickness")
			if not base then
				base = (desc.Thickness > 0) and desc.Thickness or 4
				desc:SetAttribute("BaseThickness", base)
			end
			desc.Thickness = math.max(1, math.round(base * strokeScale))
		elseif desc:IsA("UICorner") then
			local base = desc:GetAttribute("BaseRadius")
			if not base then
				base = desc.CornerRadius.Offset
				if base == 0 then base = 16 end
				desc:SetAttribute("BaseRadius", base)
			end
			desc.CornerRadius = UDim.new(0, math.max(3, math.round(base * cornerScale)))
		end
	end

	local template = script:FindFirstChild("UIComponents") and script.UIComponents:FindFirstChild("Level_1")
	if template then
		for _, desc in ipairs(template:GetDescendants()) do
			if desc:IsA("UIStroke") then
				local base = desc:GetAttribute("BaseThickness") or 3
				desc.Thickness = math.max(1, math.round(base * strokeScale))
			elseif desc:IsA("UICorner") then
				local base = desc:GetAttribute("BaseRadius") or 12
				desc.CornerRadius = UDim.new(0, math.max(3, math.round(base * cornerScale)))
			end
		end
	end

	local levelsContainer = levelsFrame:FindFirstChild("LevelsContainer")
	local grid = levelsContainer and levelsContainer:FindFirstChild("Grid")
	local gridLayout = grid and grid:FindFirstChildOfClass("UIGridLayout")

	if isPortrait then
		titleContainer.Position = UDim2.new(0.5, 0, 0.20, 0)
		titleContainer.Size = UDim2.new(0.82, 0, 0.15, 0)

		levelsBtn.Position = UDim2.new(0.5, 0, 0.73, 0)
		levelsBtn.Size = UDim2.new(0.68, 0, 0.075, 0)

		playBtn.Position = UDim2.new(0.5, 0, 0.84, 0)
		playBtn.Size = UDim2.new(0.74, 0, 0.085, 0)

		levelsTitleContainer.Position = UDim2.new(0.5, 0, 0.10, 0)
		levelsTitleContainer.Size = UDim2.new(0.85, 0, 0.08, 0)

		if levelsContainer then
			levelsContainer.Position = UDim2.new(0.5, 0, 0.48, 0)
			levelsContainer.Size = UDim2.new(0.92, 0, 0.62, 0)
		end

		if gridLayout then
			gridLayout.CellSize = UDim2.new(0.21, 0, 0.16, 0)
			gridLayout.CellPadding = UDim2.new(0.04, 0, 0.035, 0)
		end

		selectBtn.Position = UDim2.new(0.5, 0, 0.88, 0)
		selectBtn.Size = UDim2.new(0.60, 0, 0.07, 0)

		local finishTitle = finishFrame:FindFirstChild("FinishTitle")
		if finishTitle then
			finishTitle.Position = UDim2.new(0.5, 0, 0.22, 0)
			finishTitle.Size = UDim2.new(0.85, 0, 0.14, 0)
		end

		continueBtn.AnchorPoint = Vector2.new(0.5, 0.5)
		continueBtn.Position = UDim2.new(0.5, 0, 0.64, 0)
		continueBtn.Size = UDim2.new(0.65, 0, 0.075, 0)

		menuReturnBtn.AnchorPoint = Vector2.new(0.5, 0.5)
		menuReturnBtn.Position = UDim2.new(0.5, 0, 0.74, 0)
		menuReturnBtn.Size = UDim2.new(0.65, 0, 0.075, 0)

		pauzeButton.Position = UDim2.new(0, 16, 0, 16)
		pauzeButton.Size = UDim2.new(0, 42, 0, 42)

		progressContainer.Position = UDim2.new(0.5, 0, 0, 16)
		progressContainer.Size = UDim2.new(0.62, 0, 0.045, 0)
	else
		titleContainer.Position = UDim2.new(0.5, 0, 0.22, 0)
		titleContainer.Size = isSmallPhone and UDim2.new(0.55, 0, 0.22, 0) or UDim2.new(0.48, 0, 0.18, 0)

		levelsBtn.Position = UDim2.new(0.5, 0, 0.72, 0)
		levelsBtn.Size = isSmallPhone and UDim2.new(0.32, 0, 0.11, 0) or UDim2.new(0.24, 0, 0.10, 0)

		playBtn.Position = UDim2.new(0.5, 0, 0.85, 0)
		playBtn.Size = isSmallPhone and UDim2.new(0.35, 0, 0.12, 0) or UDim2.new(0.26, 0, 0.11, 0)

		levelsTitleContainer.Position = UDim2.new(0.5, 0, 0.10, 0)
		levelsTitleContainer.Size = UDim2.new(0.50, 0, 0.10, 0)

		if levelsContainer then
			levelsContainer.Position = UDim2.new(0.5, 0, 0.49, 0)
			levelsContainer.Size = isSmallPhone and UDim2.new(0.88, 0, 0.65, 0) or UDim2.new(0.78, 0, 0.60, 0)
		end

		if gridLayout then
			gridLayout.CellSize = UDim2.new(0.098, 0, 0.28, 0)
			gridLayout.CellPadding = UDim2.new(0.025, 0, 0.045, 0)
		end

		selectBtn.Position = UDim2.new(0.5, 0, 0.88, 0)
		selectBtn.Size = isSmallPhone and UDim2.new(0.25, 0, 0.09, 0) or UDim2.new(0.18, 0, 0.08, 0)

		local finishTitle = finishFrame:FindFirstChild("FinishTitle")
		if finishTitle then
			finishTitle.Position = UDim2.new(0.5, 0, 0.25, 0)
			finishTitle.Size = UDim2.new(0.55, 0, 0.16, 0)
		end

		continueBtn.AnchorPoint = Vector2.new(1, 0.5)
		continueBtn.Position = UDim2.new(0.5, -12, 0.68, 0)
		continueBtn.Size = isSmallPhone and UDim2.new(0.28, 0, 0.11, 0) or UDim2.new(0.24, 0, 0.10, 0)

		menuReturnBtn.AnchorPoint = Vector2.new(0, 0.5)
		menuReturnBtn.Position = UDim2.new(0.5, 12, 0.68, 0)
		menuReturnBtn.Size = isSmallPhone and UDim2.new(0.28, 0, 0.11, 0) or UDim2.new(0.24, 0, 0.10, 0)

		pauzeButton.Position = UDim2.new(0, 16, 0, 16)
		pauzeButton.Size = UDim2.new(0, 42, 0, 42)

		progressContainer.Position = UDim2.new(0.5, 0, 0, 16)
		progressContainer.Size = isSmallPhone and UDim2.new(0.45, 0, 0.07, 0) or UDim2.new(0.34, 0, 0.055, 0)
	end

	currentOrientationIsPortrait = isPortrait
end

updateResponsiveLayout()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)

task.spawn(function()
	while menuFrame and menuFrame.Parent do
		local isPortrait = (camera.ViewportSize.Y > camera.ViewportSize.X)
		local baseY = isPortrait and 0.20 or 0.22
		TweenService:Create(titleContainer, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			Position = UDim2.new(0.5, 0, baseY + 0.02, 0)
		}):Play()
		task.wait(1.2)
		TweenService:Create(titleContainer, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			Position = UDim2.new(0.5, 0, baseY - 0.02, 0)
		}):Play()
		task.wait(1.2)
	end
end)

local pauzeScale = pauzeLabel:WaitForChild("UIScale") or Instance.new("UIScale", pauzeLabel)
task.spawn(function()
	while pauzeFrame and pauzeFrame.Parent do
		TweenService:Create(pauzeScale, TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			Scale = 0.80
		}):Play()
		task.wait(0.85)
		TweenService:Create(pauzeScale, TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			Scale = 1.20
		}):Play()
		task.wait(0.85)
	end
end)

playBtn.MouseEnter:Connect(function()
	TweenService:Create(playScale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1.08
	}):Play()
	TweenService:Create(playBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundColor3 = COLOR_BTN_GREEN_HOVER
	}):Play()
end)

playBtn.MouseLeave:Connect(function()
	TweenService:Create(playScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = 1.0
	}):Play()
	TweenService:Create(playBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
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

continueBtn.MouseEnter:Connect(function()
	TweenService:Create(continueBtn, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		BackgroundColor3 = COLOR_BTN_GREEN_HOVER
	}):Play()
end)
continueBtn.MouseLeave:Connect(function()
	TweenService:Create(continueBtn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
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

pauzeButton.MouseEnter:Connect(function()
	TweenService:Create(pauzeButton, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		BackgroundColor3 = COLOR_BTN_BLUE_HOVER
	}):Play()
end)
pauzeButton.MouseLeave:Connect(function()
	TweenService:Create(pauzeButton, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
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
	
	TweenService:Create(levelsFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, -1, 0)
	}):Play()
	task.wait(0.3)

	menuFrame.Visible = false
	levelsFrame.Visible = false
	finishFrame.Visible = false
	gameplayHUD.Visible = true

	GameStartedEvent:Fire()
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
	updateLevelButtonHighlights()
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

function continue()
	if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		player.Character.HumanoidRootPart.Anchored = false
	end
	playClickSound()

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

	task.wait(0.08)
	gameplayHUD.Visible = true

	GameStartedEvent:Fire()
end

continueBtn.Text = "Next Level"
continueBtn.MouseButton1Click:Connect(continue)
InputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then return end
	if not finishFrame.Visible then return end
	if menuFrame.Visible or levelsFrame.Visible or gameplayHUD.Visible then return end
	if input.KeyCode == Enum.KeyCode.Space then
		continue()
	end
end)

menuReturnBtn.MouseButton1Click:Connect(function()
	if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		player.Character.HumanoidRootPart.Anchored = false
	end
	playClickSound()

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

function Pauze(state)
	pauzeImage.Visible = not state
	playImage.Visible = state
	pauzeFrame.Visible = state
	if character then
		for _, part in pairs(character:GetChildren()) do
			if part:IsA("BasePart") then
				part.Anchored = state
			end
		end
	end
	GamePauzedEvent:Fire(state)
end

pauzeButton.MouseButton1Click:Connect(function()
	Pauze(pauzeImage.Visible)
end)

pauzeFrame.InputBegan:Connect(function(input)
	if pauzeFrame.Visible and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		Pauze(false)
	end
end)

InputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then return end
	if pauzeFrame.Visible then
		if input.KeyCode == Enum.KeyCode.Space or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			Pauze(false)
		end
		return
	end
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
