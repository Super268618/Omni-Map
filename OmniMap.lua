-- Omni Map Teleport Interface -- Drone Mode + Custom Speed TextBox
-- LocalScript | StarterPlayerScripts

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

--------------------------------------------------
-- CONFIG
--------------------------------------------------
local MOVE_SPEED = 3.0 -- Initial speed
local ROTATION_SPEED = 0.006 
local JOYSTICK_RADIUS = 60
local MAX_RAY_DISTANCE = 5000 

--------------------------------------------------
-- GUI ELEMENTS
--------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "DroneCamUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local touchArea = Instance.new("Frame")
touchArea.Name = "TouchArea"
touchArea.Size = UDim2.fromScale(1, 1)
touchArea.BackgroundTransparency = 1
touchArea.Visible = false
touchArea.Parent = gui

local joystickBase = Instance.new("Frame")
joystickBase.Name = "JoystickBase"
joystickBase.Size = UDim2.fromOffset(150, 150)
joystickBase.Position = UDim2.new(0, 50, 1, -200)
joystickBase.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
joystickBase.BackgroundTransparency = 0.6
joystickBase.Visible = false
joystickBase.Parent = gui

local baseCorner = Instance.new("UICorner")
baseCorner.CornerRadius = UDim.new(1, 0)
baseCorner.Parent = joystickBase

local thumbstick = Instance.new("Frame")
thumbstick.Name = "Thumbstick"
thumbstick.Size = UDim2.fromOffset(70, 70)
thumbstick.Position = UDim2.fromScale(0.5, 0.5)
thumbstick.AnchorPoint = Vector2.new(0.5, 0.5)
thumbstick.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
thumbstick.BackgroundTransparency = 0.3
thumbstick.Parent = joystickBase

local thumbCorner = Instance.new("UICorner")
thumbCorner.CornerRadius = UDim.new(1, 0)
thumbCorner.Parent = thumbstick

--------------------------------------------------
-- SPEED TEXTBOX UI
--------------------------------------------------
local speedFrame = Instance.new("Frame")
speedFrame.Name = "SpeedFrame"
speedFrame.Size = UDim2.fromOffset(160, 45)
speedFrame.Position = UDim2.new(0.5, -80, 1, -100) -- Bottom Center
speedFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
speedFrame.BackgroundTransparency = 0.5
speedFrame.Visible = false
speedFrame.Parent = gui

local speedCorner = Instance.new("UICorner")
speedCorner.Parent = speedFrame

local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.fromScale(0.5, 1)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "SPEED:"
speedLabel.TextColor3 = Color3.new(1, 1, 1)
speedLabel.Font = Enum.Font.GothamBold
speedLabel.TextScaled = true
speedLabel.Parent = speedFrame

local speedInput = Instance.new("TextBox")
speedInput.Size = UDim2.fromScale(0.4, 0.7)
speedInput.Position = UDim2.fromScale(0.55, 0.15)
speedInput.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
speedInput.Text = tostring(MOVE_SPEED)
speedInput.TextColor3 = Color3.new(0, 1, 0) -- Green text for visibility
speedInput.Font = Enum.Font.GothamBold
speedInput.TextScaled = true
speedInput.ClearTextOnFocus = true
speedInput.Parent = speedFrame

local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0.2, 0)
inputCorner.Parent = speedInput

-- Logic to update speed when user types
speedInput.FocusLost:Connect(function(enterPressed)
    local val = tonumber(speedInput.Text)
    if val and val > 0 then
        MOVE_SPEED = val
        speedInput.Text = tostring(val)
    else
        speedInput.Text = tostring(MOVE_SPEED) -- Reset to last valid speed
    end
end)

--------------------------------------------------
-- CONTROL BUTTONS
--------------------------------------------------
local function createButton(text, xPos, color)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromScale(0.2, 0.08)
	b.Position = UDim2.fromScale(xPos, 0.05)
	b.Text = text
	b.TextScaled = true
	b.BackgroundColor3 = color
	b.TextColor3 = Color3.new(1,1,1)
	b.Font = Enum.Font.GothamBold
	b.Parent = gui
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.3, 0); c.Parent = b
	return b
end

local selectBtn = createButton("Enter Drone", 0.1, Color3.fromRGB(0, 120, 255))
local teleportBtn = createButton("Teleport", 0.4, Color3.fromRGB(0, 180, 0))
local cancelBtn = createButton("Exit", 0.7, Color3.fromRGB(180, 0, 0))

--------------------------------------------------
-- STATE & ASSETS
--------------------------------------------------
local mapMode = false
local moveInput = Vector2.zero
local camPosition = Vector3.zero
local camAngles = Vector2.new(0, 0)
local selectedPosition = nil
local originalType, originalCF
local joystickTouch = nil 

local marker = Instance.new("Part")
marker.Name = "TeleportMarker"
marker.Anchored = true
marker.CanCollide = false
marker.Shape = Enum.PartType.Ball
marker.Size = Vector3.new(3, 3, 3)
marker.Material = Enum.Material.Neon
marker.Color = Color3.fromRGB(0, 255, 0)
marker.Transparency = 1
marker.Parent = workspace

--------------------------------------------------
-- JOYSTICK LOGIC
--------------------------------------------------
local function updateJoystick(pos)
	local center = joystickBase.AbsolutePosition + (joystickBase.AbsoluteSize / 2)
	local diff = Vector2.new(pos.X, pos.Y) - center
	if diff.Magnitude > JOYSTICK_RADIUS then diff = diff.Unit * JOYSTICK_RADIUS end
	thumbstick.Position = UDim2.new(0.5, diff.X, 0.5, diff.Y)
	moveInput = diff / JOYSTICK_RADIUS
end

joystickBase.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		joystickTouch = input
		updateJoystick(input.Position)
	end
end)

UIS.InputChanged:Connect(function(input)
	if input == joystickTouch then updateJoystick(input.Position) end
end)

UIS.InputEnded:Connect(function(input)
	if input == joystickTouch then
		joystickTouch = nil
		moveInput = Vector2.zero
		TweenService:Create(thumbstick, TweenInfo.new(0.15), {Position = UDim2.fromScale(0.5, 0.5)}):Play()
	end
end)

--------------------------------------------------
-- CORE MOVEMENT LOOP
--------------------------------------------------
local function startCamera()
	if mapMode then return end
	mapMode = true
	touchArea.Visible = true
	joystickBase.Visible = true
	speedFrame.Visible = true
	
	originalType = camera.CameraType
	originalCF = camera.CFrame
	camera.CameraType = Enum.CameraType.Scriptable
	
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	camPosition = root and (root.Position + Vector3.new(0, 50, 0)) or Vector3.new(0, 50, 0)
	
	local rx, ry, rz = camera.CFrame:ToOrientation()
	camAngles = Vector2.new(ry, rx)
	
	RunService:BindToRenderStep("DroneLogic", Enum.RenderPriority.Camera.Value + 1, function()
		local rotation = CFrame.fromOrientation(0, camAngles.X, 0) * CFrame.fromOrientation(camAngles.Y, 0, 0)
		local moveDir = Vector3.new(moveInput.X, 0, moveInput.Y) * MOVE_SPEED
		camPosition = camPosition + (rotation * moveDir)
		camera.CFrame = CFrame.new(camPosition) * rotation
	end)
end

local function stopCamera()
	mapMode = false
	touchArea.Visible = false
	joystickBase.Visible = false
	speedFrame.Visible = false
	RunService:UnbindFromRenderStep("DroneLogic")
	camera.CameraType = originalType
	camera.CFrame = originalCF
	marker.Transparency = 1
	selectedPosition = nil
end

--------------------------------------------------
-- INPUT (LOOK & TAP)
--------------------------------------------------
UIS.InputChanged:Connect(function(input)
	if not mapMode or input == joystickTouch then return end
    -- Prevent camera from spinning while typing in the box
    if UIS:GetFocusedTextBox() then return end

	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Delta
		camAngles -= Vector2.new(delta.X, delta.Y) * ROTATION_SPEED
		camAngles = Vector2.new(camAngles.X, math.clamp(camAngles.Y, -1.5, 1.5))
	end
end)

local tapStartTime = 0
touchArea.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		tapStartTime = tick()
	end
end)

touchArea.InputEnded:Connect(function(input)
	if not mapMode or UIS:GetFocusedTextBox() then return end
	if tick() - tapStartTime < 0.25 then
		local ray = camera:ViewportPointToRay(input.Position.X, input.Position.Y)
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = {player.Character, marker}
		params.FilterType = Enum.RaycastFilterType.Exclude
		
		local result = workspace:Raycast(ray.Origin, ray.Direction * MAX_RAY_DISTANCE, params)
		if result then
			selectedPosition = result.Position
			marker.Position = result.Position
			marker.Transparency = 0.2
			marker.Size = Vector3.new(1,1,1)
			TweenService:Create(marker, TweenInfo.new(0.3, Enum.EasingStyle.Elastic), {Size = Vector3.new(4,4,4)}):Play()
		end
	end
end)

--------------------------------------------------
-- BUTTON HOOKS
--------------------------------------------------
selectBtn.MouseButton1Click:Connect(startCamera)
cancelBtn.MouseButton1Click:Connect(stopCamera)

teleportBtn.MouseButton1Click:Connect(function()
	if selectedPosition and player.Character then
		player.Character:MoveTo(selectedPosition + Vector3.new(0, 4, 0))
		stopCamera()
	end
end)
