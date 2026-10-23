local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local SoundConfig = require(ReplicatedStorage:WaitForChild("SoundConfig"))

local SoundPlayer = {}
local MAX_PER_ID = 4
local pools = {}

local poolFolder = Instance.new("Folder")
poolFolder.Name = "SoundPool"
poolFolder.Parent = SoundService

local function toContentId(id)
	if type(id) == "number" then
		return "rbxassetid://" .. id
	end
	if type(id) ~= "string" or id == "" then
		return nil
	end
	if id:find("://") then
		return id
	end
	return "rbxassetid://" .. id
end

local function pickContentId(entry)
	if not entry.Ids then
		return toContentId(entry.Id)
	end

	local valid = {}
	for _, id in ipairs(entry.Ids) do
		local contentId = toContentId(id)
		if contentId then
			table.insert(valid, contentId)
		end
	end
	if #valid == 0 then
		return nil
	end

	return valid[math.random(1, #valid)]
end

local function newSound(contentId)
	local sound = Instance.new("Sound")
	sound.SoundId = contentId
	sound.Parent = poolFolder
	local pool = pools[contentId]
	if not pool then
		pool = {}
		pools[contentId] = pool
	end
	table.insert(pool, sound)
	return sound
end

-- A new Sound takes about 300ms to start even when the asset is cached, so sounds are reused
local function getSound(contentId)
	local pool = pools[contentId]
	if not pool then
		return newSound(contentId)
	end
	for _, sound in ipairs(pool) do
		if not sound.IsPlaying then
			return sound
		end
	end
	if #pool < MAX_PER_ID then
		return newSound(contentId)
	end
	return pool[1]
end

function SoundPlayer.preload()
	local sounds = {}
	for _, entry in pairs(SoundConfig) do
		for _, id in ipairs(entry.Ids or { entry.Id }) do
			local contentId = toContentId(id)
			if contentId and not pools[contentId] then
				table.insert(sounds, newSound(contentId))
			end
		end
	end
	ContentProvider:PreloadAsync(sounds)
end

function SoundPlayer.play(name, speedMultiplier)
	local entry = SoundConfig[name]
	if not entry then
		warn(`SoundConfig has no sound named "{name}"`)
		return
	end

	local contentId = pickContentId(entry)
	if not contentId then return end

	local sound = getSound(contentId)
	sound.Volume = entry.Volume or 0.8
	sound.PlaybackSpeed = (entry.PlaybackSpeed or 1) * (speedMultiplier or 1)
	sound.TimePosition = 0
	sound:Play()
end

return SoundPlayer
