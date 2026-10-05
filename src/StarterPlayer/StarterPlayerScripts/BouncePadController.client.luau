local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local PhysicsConfig = require(ReplicatedStorage:WaitForChild("PhysicsConfig"))

local character = nil
local rootPart = nil
local lastBounceTime = 0

local function playBounceAnimation(pad)
	local centerBone = pad:FindFirstChild("CenterBone", true)

	if centerBone then
		if not pad:GetAttribute("OriginalTransformStored") then
			pad:SetAttribute("OriginalTransformStored", true)
		end

		local compressTween = TweenService:Create(centerBone, TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			Transform = CFrame.new(0, -0.5, 0)
		})

		local bulgeTween = TweenService:Create(centerBone, TweenInfo.new(0.1, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
			Transform = CFrame.new(0, 1.8, 0)
		})

		local settleTween = TweenService:Create(centerBone, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transform = CFrame.new() 
		})

		compressTween:Play()
		compressTween.Completed:Connect(function()
			bulgeTween:Play()
		end)
		bulgeTween.Completed:Connect(function()
			settleTween:Play()
		end)

	else
		local originalSize = pad:GetAttribute("OriginalSize") or pad.Size
		pad:SetAttribute("OriginalSize", originalSize)

		local squashTween = TweenService:Create(pad, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(originalSize.X * 1.25, originalSize.Y * 0.4, originalSize.Z * 1.25)
		})
		local stretchTween = TweenService:Create(pad, TweenInfo.new(0.35, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
			Size = originalSize
		})

		squashTween:Play()
		squashTween.Completed:Connect(function()
			stretchTween:Play()
		end)
	end

	TweenService:Create(pad, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, true), {
		Color = Color3.fromRGB(255, 255, 255)
	}):Play()
end

local function handleBouncePad(pad)
	if not rootPart then return end
	local now = tick()
	if now - lastBounceTime < 0.22 then return end

	local dist = (pad.Position - rootPart.Position).Magnitude
	local triggerRadius = math.max(pad.Size.X, pad.Size.Y, pad.Size.Z) * 1.25

	if dist > triggerRadius then return end
	lastBounceTime = now

	playBounceAnimation(pad)

	local isCeilingPad = pad:GetAttribute("IsCeiling") or pad.Name:lower():find("ceiling") ~= nil
	local customStrength = pad:GetAttribute("BounceStrength") or PhysicsConfig.BOUNCE_STRENGTH or 140

	local launchDir = pad.CFrame.UpVector.Unit
	local base = pad.Parent and pad.Parent:FindFirstChild("PadBase")
	if base and (pad.Position - base.Position):Dot(launchDir) < 0 then
		launchDir = -launchDir
	end

	local relAlongNormal = (rootPart.Position - pad.Position):Dot(launchDir)
	if relAlongNormal < 2.2 then
		rootPart.CFrame = rootPart.CFrame + launchDir * (2.2 - relAlongNormal)
	end

	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end

	local finalVelocity = launchDir * customStrength
	rootPart.AssemblyLinearVelocity = finalVelocity
	
	local oldBV = rootPart:FindFirstChild("BounceVelocity")
	if oldBV then
		oldBV:Destroy()
	end

	local bv = Instance.new("BodyVelocity")
	bv.Name = "BounceVelocity"
	bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bv.Velocity = finalVelocity
	bv.Parent = rootPart

	task.delay(0.06, function()
		if bv.Parent then
			bv.MaxForce = Vector3.new(1e5, 0, 1e5)
			bv.Velocity = Vector3.new(finalVelocity.X, 0, finalVelocity.Z)
		end
	end)
	Debris:AddItem(bv, 0.38)

	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/action_jump.mp3"
	sound.Volume = 0.95
	sound.PlaybackSpeed = isCeilingPad and 1.3 or 1.1
	sound.Parent = pad
	sound:Play()
	Debris:AddItem(sound, 1.5)
end

local function setupPad(pad)
	if pad:IsA("BasePart") then
		pad:SetAttribute("OriginalSize", pad.Size)
		pad.Touched:Connect(function(hit)
			if hit:IsDescendantOf(player.Character) then
				handleBouncePad(pad)
			end
		end)
	end
end

for _, pad in ipairs(CollectionService:GetTagged("BouncePad")) do
	setupPad(pad)
end
CollectionService:GetInstanceAddedSignal("BouncePad"):Connect(setupPad)

local function onCharacterAdded(newChar)
	character = newChar
	rootPart = character:WaitForChild("HumanoidRootPart")
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then onCharacterAdded(player.Character) end
