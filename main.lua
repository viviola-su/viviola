-- Full Aimbot + ESP LocalScript
-- Combines your original aimbot GUI + fixed toggle behavior + ESP + Team ESP + Aim part selector (Head/Torso/Random)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = player:GetMouse()

-- Default Settings
local aimbotEnabled = true
local aimPartOption = "Head"      -- "Head", "Torso", "Random"
local circleRadius = 75
local smoothness = 0.15
local aimbotMode = "Hold"        -- "Hold" or "Toggle"
local activationKey = Enum.UserInputType.MouseButton2 -- default Right Click

-- ESP Settings
local espEnabled = true
local teamEspEnabled = true
local defaultESPColor = Color3.fromRGB(255,255,255)

-- Runtime Vars
local holdingKey = false
local target = nil               -- current target part
local toggleActive = false       -- Toggle-mode aiming on/off
local playerESPs = {}           -- map player -> {BillboardGui, Frame, TextLabel}
local aimCandidates = {"Head", "Torso"} -- used for Random

--// Create Circle
local circle = Drawing.new("Circle")
circle.Thickness = 1.25
circle.NumSides = 64
circle.Radius = circleRadius
circle.Color = Color3.fromRGB(255, 0, 255)
circle.Filled = false
circle.Visible = true
circle.Transparency = 0.75

--// Create UI
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
ScreenGui.Name = "AimbotSettingsUI"

local Frame = Instance.new("Frame", ScreenGui)
Frame.Size = UDim2.new(0, 340, 0, 300)
Frame.Position = UDim2.new(0.5, -170, 0.5, -150)
Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Frame.Active = true
Frame.Draggable = true
Frame.Visible = true
Frame.BorderSizePixel = 0

local Title = Instance.new("TextLabel", Frame)
Title.Text = "SimpleGui"
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 20

-- Aimbot toggle button
local toggleButton = Instance.new("TextButton", Frame)
toggleButton.Size = UDim2.new(0.45, 0, 0, 30)
toggleButton.Position = UDim2.new(0.05, 0, 0.2, 0)
toggleButton.Text = "Aimbot: OFF"
toggleButton.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)

toggleButton.MouseButton1Click:Connect(function()
	aimbotEnabled = not aimbotEnabled
	if aimbotEnabled then
		toggleButton.Text = "Aimbot: ON"
		toggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
	else
		toggleButton.Text = "Aimbot: OFF"
		toggleButton.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
		toggleActive = false
		target = nil
	end
end)

-- Mode selector (Hold/Toggle)
local modeButton = Instance.new("TextButton", Frame)
modeButton.Size = UDim2.new(0.45, 0, 0, 30)
modeButton.Position = UDim2.new(0.52, 0, 0.2, 0)
modeButton.Text = "Mode: Hold"
modeButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
modeButton.TextColor3 = Color3.fromRGB(255, 255, 255)

modeButton.MouseButton1Click:Connect(function()
	aimbotMode = (aimbotMode == "Hold" and "Toggle" or "Hold")
	modeButton.Text = "Mode: " .. aimbotMode
	-- Reset toggle state when switching mode
	toggleActive = false
	target = nil
end)

-- Activation key button
local keyButton = Instance.new("TextButton", Frame)
keyButton.Size = UDim2.new(0.9, 0, 0, 30)
keyButton.Position = UDim2.new(0.05, 0, 0.35, 0)
keyButton.Text = "Activation Key: Right Click"
keyButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
keyButton.TextColor3 = Color3.fromRGB(255, 255, 255)

local waitingForKey = false
keyButton.MouseButton1Click:Connect(function()
	waitingForKey = true
	keyButton.Text = "Press any key..."
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if waitingForKey and not gameProcessed then
		waitingForKey = false
		if input.UserInputType == Enum.UserInputType.Keyboard then
			activationKey = input.KeyCode
			keyButton.Text = "Key: " .. activationKey.Name
		else
			activationKey = input.UserInputType
			-- nicer display
			keyButton.Text = "Key: " .. tostring(activationKey):gsub("Enum.UserInputType.", "")
		end
	end
end)

-- Range controls
local leftArrow = Instance.new("TextButton", Frame)
leftArrow.Size = UDim2.new(0.18, 0, 0, 25)
leftArrow.Position = UDim2.new(0.05, 0, 0.53, 0)
leftArrow.Text = "<"
leftArrow.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
leftArrow.TextColor3 = Color3.fromRGB(255, 255, 255)

local rightArrow = Instance.new("TextButton", Frame)
rightArrow.Size = UDim2.new(0.18, 0, 0, 25)
rightArrow.Position = UDim2.new(0.77, 0, 0.53, 0)
rightArrow.Text = ">"
rightArrow.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
rightArrow.TextColor3 = Color3.fromRGB(255, 255, 255)

local rangeLabel = Instance.new("TextLabel", Frame)
rangeLabel.Size = UDim2.new(0.6, 0, 0, 25)
rangeLabel.Position = UDim2.new(0.23, 0, 0.53, 0)
rangeLabel.Text = "Range: " .. circleRadius
rangeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
rangeLabel.BackgroundTransparency = 1

leftArrow.MouseButton1Click:Connect(function()
	circleRadius = math.clamp(circleRadius - 10, 50, 800)
	rangeLabel.Text = "Range: " .. circleRadius
	circle.Radius = circleRadius
end)

rightArrow.MouseButton1Click:Connect(function()
	circleRadius = math.clamp(circleRadius + 10, 50, 800)
	rangeLabel.Text = "Range: " .. circleRadius
	circle.Radius = circleRadius
end)

-- Sensitivity dropdown
local sensitivityButton = Instance.new("TextButton", Frame)
sensitivityButton.Size = UDim2.new(0.9, 0, 0, 30)
sensitivityButton.Position = UDim2.new(0.05, 0, 0.63, 0)
sensitivityButton.Text = "Sensitivity: Smooth"
sensitivityButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
sensitivityButton.TextColor3 = Color3.fromRGB(255, 255, 255)

local sensitivityOptions = {Slow = 0.05, Smooth = 0.15, Fast = 1}
local currentSense = "Smooth"

sensitivityButton.MouseButton1Click:Connect(function()
	if currentSense == "Slow" then
		currentSense = "Smooth"
	elseif currentSense == "Smooth" then
		currentSense = "Fast"
	else
		currentSense = "Slow"
	end
	sensitivityButton.Text = "Sensitivity: " .. currentSense
	smoothness = sensitivityOptions[currentSense]
end)

-- Aim part selector UI (Head / Torso / Random)
local aimLabel = Instance.new("TextLabel", Frame)
aimLabel.Size = UDim2.new(0.9, 0, 0, 20)
aimLabel.Position = UDim2.new(0.05, 0, 0.75, 0)
aimLabel.Text = "Aim Part: " .. aimPartOption
aimLabel.TextColor3 = Color3.fromRGB(255,255,255)
aimLabel.BackgroundTransparency = 1

local aimCycleButton = Instance.new("TextButton", Frame)
aimCycleButton.Size = UDim2.new(0.9, 0, 0, 24)
aimCycleButton.Position = UDim2.new(0.05, 0, 0.79, 0)
aimCycleButton.Text = "Cycle Aim Part"
aimCycleButton.BackgroundColor3 = Color3.fromRGB(70,70,70)
aimCycleButton.TextColor3 = Color3.fromRGB(255,255,255)

aimCycleButton.MouseButton1Click:Connect(function()
	if aimPartOption == "Head" then
		aimPartOption = "Torso"
	elseif aimPartOption == "Torso" then
		aimPartOption = "Random"
	else
		aimPartOption = "Head"
	end
	aimLabel.Text = "Aim Part: " .. aimPartOption
end)

-- ESP toggle button
local espButton = Instance.new("TextButton", Frame)
espButton.Size = UDim2.new(0.45, 0, 0, 26)
espButton.Position = UDim2.new(0.05, 0, 0.9, 0)
espButton.Text = "ESP: OFF"
espButton.BackgroundColor3 = Color3.fromRGB(255,60,60)
espButton.TextColor3 = Color3.fromRGB(255,255,255)

espButton.MouseButton1Click:Connect(function()
	espEnabled = not espEnabled
	if espEnabled then
		espButton.Text = "ESP: ON"
		espButton.BackgroundColor3 = Color3.fromRGB(0,200,100)
	else
		espButton.Text = "ESP: OFF"
		espButton.BackgroundColor3 = Color3.fromRGB(255,60,60)
		-- remove all ESP GUIs
		for pl, obj in pairs(playerESPs) do
			if obj.gui then obj.gui:Destroy() end
		end
		playerESPs = {}
	end
end)

-- Team ESP toggle
local teamEspButton = Instance.new("TextButton", Frame)
teamEspButton.Size = UDim2.new(0.45, 0, 0, 26)
teamEspButton.Position = UDim2.new(0.52, 0, 0.9, 0)
teamEspButton.Text = "Team ESP: OFF"
teamEspButton.BackgroundColor3 = Color3.fromRGB(70,70,70)
teamEspButton.TextColor3 = Color3.fromRGB(255,255,255)

teamEspButton.MouseButton1Click:Connect(function()
	teamEspEnabled = not teamEspEnabled
	if teamEspEnabled then
		teamEspButton.Text = "Team ESP: ON"
		teamEspButton.BackgroundColor3 = Color3.fromRGB(0,200,100)
	else
		teamEspButton.Text = "Team ESP: OFF"
		teamEspButton.BackgroundColor3 = Color3.fromRGB(70,70,70)
	end
end)

--// Helpers

-- find appropriate aiming part name in a character (tries requested, falls back)
local function findAimPartInCharacter(character, wantPartName)
	if not character then return nil end
	if wantPartName == "Head" then
		return character:FindFirstChild("Head")
	elseif wantPartName == "Torso" then
		-- prefer HumanoidRootPart, then Torso
		return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("LowerTorso")
	else
		-- Random choice between Head and Torso
		local choice = aimCandidates[math.random(1, #aimCandidates)]
		return findAimPartInCharacter(character, choice)
	end
end

local function isPartValid(p)
	if not p then return false end
	if not p:IsDescendantOf(workspace) then return false end
	local model = p:FindFirstAncestorOfClass("Model")
	if not model then return false end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false end
	if humanoid.Health <= 0 then return false end
	return true
end

-- get closest part to mouse within circleRadius using aimPartOption logic
local function getClosestToMouse()
	local closest, dist = nil, circleRadius
	local mousePos = UserInputService:GetMouseLocation()

	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player and otherPlayer.Character then
			local part = findAimPartInCharacter(otherPlayer.Character, aimPartOption)
			if part then
				local screenPoint, onScreen = camera:WorldToViewportPoint(part.Position)
				if onScreen then
					local mag = (Vector2.new(screenPoint.X, screenPoint.Y) - mousePos).Magnitude
					if mag < dist then
						dist = mag
						closest = part
					end
				end
			end
		end
	end

	return closest
end

-- Acquire best target
local function acquireTarget()
	local p = getClosestToMouse()
	if isPartValid(p) then
		target = p
		return true
	end
	target = nil
	return false
end

local function clearTarget()
	target = nil
end

-- Create BillboardGui ESP for a player's character
local function createESP(playerObj)
	if not playerObj or not playerObj.Character then return nil end
	local char = playerObj.Character
	if playerESPs[playerObj] and playerESPs[playerObj].gui then
		return playerESPs[playerObj]
	end

	local head = char:FindFirstChild("Head")
	local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
	local attachPart = head or root
	if not attachPart then return nil end

	-- BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ESP_Billboard"
	billboard.Adornee = attachPart
	billboard.Size = UDim2.new(0, 120, 0, 48)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 1000
	billboard.Parent = ScreenGui

	local frame = Instance.new("Frame", billboard)
	frame.Size = UDim2.new(1,0,1,0)
	frame.BackgroundTransparency = 1

	local nameLabel = Instance.new("TextLabel", frame)
	nameLabel.Size = UDim2.new(1,0,0.6,0)
	nameLabel.Position = UDim2.new(0,0,0,0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextStrokeTransparency = 0
	nameLabel.TextStrokeColor3 = Color3.new(0,0,0)
	nameLabel.Text = playerObj.Name
	nameLabel.Font = Enum.Font.SourceSansBold
	nameLabel.TextSize = 14
	nameLabel.TextColor3 = defaultESPColor

	local distLabel = Instance.new("TextLabel", frame)
	distLabel.Size = UDim2.new(1,0,0.4,0)
	distLabel.Position = UDim2.new(0,0,0.6,0)
	distLabel.BackgroundTransparency = 1
	distLabel.Text = ""
	distLabel.Font = Enum.Font.SourceSans
	distLabel.TextSize = 12
	distLabel.TextColor3 = defaultESPColor

	playerESPs[playerObj] = {
		gui = billboard,
		nameLabel = nameLabel,
		distLabel = distLabel,
		attachedPart = attachPart
	}
	return playerESPs[playerObj]
end

-- Remove ESP for player
local function removeESP(playerObj)
	if playerESPs[playerObj] then
		if playerESPs[playerObj].gui then
			playerESPs[playerObj].gui:Destroy()
		end
		playerESPs[playerObj] = nil
	end
end

-- Update ESP colors and distance
local function updateESPForPlayer(playerObj)
	local data = playerESPs[playerObj]
	if not data or not data.attachedPart then return end
	local char = playerObj.Character
	if not char then removeESP(playerObj) return end

	local root = player.Character and (player.Character:FindFirstChild("HumanoidRootPart") or player.Character:FindFirstChild("Torso"))
	local dist = root and (root.Position - camera.CFrame.Position).Magnitude or 0
	data.distLabel.Text = string.format("%.0f stud", dist)

	local color = defaultESPColor
	if teamEspEnabled and playerObj.Team and playerObj.TeamColor then
		-- TeamColor is BrickColor; convert to Color3
		color = playerObj.TeamColor.Color
	end
	data.nameLabel.TextColor3 = color
	data.distLabel.TextColor3 = color
end

-- Ensure ESP exists/cleared for all players (constantly called)
local function refreshAllESP()
	if not espEnabled then return end
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= player and pl.Character and pl.Character:FindFirstChildOfClass("Humanoid") and pl.Character:FindFirstChild("Humanoid").Health > 0 then
			if not playerESPs[pl] then
				createESP(pl)
			end
		else
			removeESP(pl)
		end
	end
end

-- Connect player join/leave to maintain ESP
Players.PlayerAdded:Connect(function(pl)
	-- create esp when they spawn if ESP enabled
	pl.CharacterAdded:Connect(function()
		if espEnabled then
			-- slight delay for parts to exist
			wait(0.05)
			createESP(pl)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(pl)
	removeESP(pl)
end)

-- Also respond to characters added/removed to create/destroy ESP
for _, pl in ipairs(Players:GetPlayers()) do
	pl.CharacterAdded:Connect(function()
		if espEnabled then
			wait(0.05)
			createESP(pl)
		end
	end)
end

--// Update Circle Position
RunService.RenderStepped:Connect(function()
	local mousePos = UserInputService:GetMouseLocation()
	circle.Position = Vector2.new(mousePos.X, mousePos.Y)
end)

--// Aimbot Loop
RunService.RenderStepped:Connect(function()
	-- Keep ESP updated constantly
	if espEnabled then
		refreshAllESP()
		for pl, _ in pairs(playerESPs) do
			updateESPForPlayer(pl)
		end
	end

	if not aimbotEnabled then return end

	if aimbotMode == "Hold" then
		if holdingKey then
			local targetPart = getClosestToMouse()
			if targetPart then
				local targetPos = targetPart.Position
				local newCFrame = CFrame.new(camera.CFrame.Position, targetPos)
				camera.CFrame = camera.CFrame:Lerp(newCFrame, smoothness)
			end
		end
	else -- Toggle mode
		if toggleActive then
			if isPartValid(target) then
				local targetPos = target.Position
				local newCFrame = CFrame.new(camera.CFrame.Position, targetPos)
				camera.CFrame = camera.CFrame:Lerp(newCFrame, smoothness)
			else
				-- target died or invalid -> try to acquire new one automatically
				if not acquireTarget() then
					-- no valid target currently; keep toggleActive true and keep trying next frames
				end
			end
		end
	end
end)

--// Input handling
local function matchesActivation(input)
	-- Activation key can be KeyCode or UserInputType
	if typeof(activationKey) == "EnumItem" then
		-- If it's a KeyCode
		if activationKey.EnumType == Enum.KeyCode then
			return input.KeyCode == activationKey
		else
			return input.UserInputType == activationKey
		end
	else
		return (input.UserInputType == activationKey or input.KeyCode == activationKey)
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if waitingForKey and not gameProcessed then return end

	if matchesActivation(input) then
		if aimbotMode == "Hold" then
			holdingKey = true
		else
			-- Toggle mode: flip toggleActive and acquire target if turning on
			toggleActive = not toggleActive
			if toggleActive then
				-- If aimPartOption == Random, we might pick a part per acquireTarget call; acquireTarget uses findAimPartInCharacter which handles Random
				acquireTarget()
			else
				clearTarget()
			end
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if matchesActivation(input) then
		if aimbotMode == "Hold" then
			holdingKey = false
		else
			-- For Toggle mode we DO NOT clear the target here (keeps locked until they die or you toggle off)
		end
	end
end)

-- Clear target on player leave or local character removal
Players.PlayerRemoving:Connect(function(p)
	if target and target:FindFirstAncestorOfClass("Model") == p.Character then
		clearTarget()
	end
end)

player.CharacterRemoving:Connect(function()
	clearTarget()
	toggleActive = false
end)

-- Ensure ESP cleans up if we toggle off later
-- (already handled in espButton)


-- End of script
