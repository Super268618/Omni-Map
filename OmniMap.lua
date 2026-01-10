-- Omni Map Teleport Interface -- Final Polished Drone Mode + Speed Slider
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
local MOVE_SPEED = 3.0 -- This is now the BASE speed, modified by the slider
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
-- SPEED SLIDER UI
--------------------------------------------------
local sliderFrame = Instance.new("Frame")
sliderFrame.Name = "SliderFrame"
sliderFrame.Size = UDim2.fromOffset(200, 40)
sliderFrame.Position = UDim2.new(0.5, -100, 1, -100)
sliderFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
sliderFrame.BackgroundTransparency = 0.5
sliderFrame.Visible = false
sliderFrame.Parent = gui

local sliderCorner = Instance.new("UICorner")
sliderCorner.Parent = sliderFrame

local sliderLabel = Instance.new("TextLabel")
sliderLabel.Size = UDim2.new(1, 0, 0, -20)
sliderLabel.BackgroundTransparency = 1
sliderLabel.Text = "Speed: 3.0"
sliderLabel.TextColor3 = Color3.new(1, 1, 1)
sliderLabel.TextScaled = true
sliderLabel.Parent = sliderFrame

local sliderTrack = Instance.new("Frame")
sliderTrack.Size = UDim2.new(0.8, 0, 0.1, 0)
sliderTrack.Position = UDim2.fromScale(0.1, 0.5)
sliderTrack.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
sliderTrack.Parent = sliderFrame

local sliderKnob = Instance.new("TextButton")
sliderKnob.Size = UDim2.fromOffset(20, 30)
sliderKnob.Position = UDim2.fromScale(0.2, 0.5)
sliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
sliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
sliderKnob.Text = ""
sliderKnob.Parent = sliderFrame

--------------------------------------------------
-- SLIDER LOGIC
--------------------------------------------------
local draggingSlider = false

local function updateSlider(input)
	local relativeX = math.clamp((input.Position.X - sliderTrack.AbsolutePosition.X) / sliderTrack.AbsoluteSize.X, 0, 1)
	sliderKnob.Position = UDim2.fromScale(0.1 + (relativeX * 0.8), 0.5)
	
	-- Map 0-1 range to 1.0 - 10.0 Speed
	MOVE_SPEED = 1 + (relativeX * 9)
	sliderLabel.Text = string.format("Speed: %.1f", MOVE_SPEED)
end

sliderKnob.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		draggingSlider = true
	end
end)

UIS.InputChanged:Connect(function(input)
	if draggingSlider and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
		updateSlider(input)
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		draggingSlider = false
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
	sliderFrame.Visible = true
	
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
	sliderFrame.Visible = false
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
	if not mapMode or input == joystickTouch or draggingSlider then return end
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
	if not mapMode then return end
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
