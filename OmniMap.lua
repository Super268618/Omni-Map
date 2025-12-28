-- Omni Map Teleport
-- Four-Way Swiper + Accurate Selection + Zoom UI
-- LocalScript | StarterPlayerScripts

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

--------------------------------------------------
-- CONFIG
--------------------------------------------------
local GROUND_Y = 0          -- map ground height
local MIN_HEIGHT = 80
local MAX_HEIGHT = 800
local ZOOM_SPEED = 6        -- zoom per frame
local PAN_SPEED = 1.2
local INERTIA = 0.85

--------------------------------------------------
-- GUI ROOT
--------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

--------------------------------------------------
-- TOP BUTTONS
--------------------------------------------------
local function topButton(text, x)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromScale(0.25, 0.07)
	b.Position = UDim2.fromScale(x, 0.02)
	b.Text = text
	b.TextScaled = true
	b.Parent = gui
	return b
end

local selectBtn = topButton("Select Position", 0.05)
local teleportBtn = topButton("Teleport", 0.375)
local cancelBtn = topButton("Cancel", 0.70)

--------------------------------------------------
-- FOUR-WAY SWIPER UI
--------------------------------------------------
local dpad = Instance.new("Frame")
dpad.Size = UDim2.fromScale(0.28, 0.28)
dpad.Position = UDim2.fromScale(0.05, 0.62)
dpad.BackgroundTransparency = 1
dpad.Visible = false
dpad.Parent = gui

local function dirBtn(pos, txt)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromScale(0.3, 0.3)
	b.Position = pos
	b.Text = txt
	b.TextScaled = true
	b.BackgroundTransparency = 0.2
	b.Parent = dpad
	return b
end

local up    = dirBtn(UDim2.fromScale(0.35, 0.0), "↑")
local down  = dirBtn(UDim2.fromScale(0.35, 0.7), "↓")
local left  = dirBtn(UDim2.fromScale(0.0,  0.35), "←")
local right = dirBtn(UDim2.fromScale(0.7,  0.35), "→")

--------------------------------------------------
-- ZOOM UI
--------------------------------------------------
local zoomFrame = Instance.new("Frame")
zoomFrame.Size = UDim2.fromScale(0.12, 0.25)
zoomFrame.Position = UDim2.fromScale(0.83, 0.55)
zoomFrame.BackgroundTransparency = 1
zoomFrame.Visible = false
zoomFrame.Parent = gui

local zoomIn = Instance.new("TextButton")
zoomIn.Size = UDim2.fromScale(1, 0.45)
zoomIn.Position = UDim2.fromScale(0, 0)
zoomIn.Text = "+"
zoomIn.TextScaled = true
zoomIn.Parent = zoomFrame

local zoomOut = Instance.new("TextButton")
zoomOut.Size = UDim2.fromScale(1, 0.45)
zoomOut.Position = UDim2.fromScale(0, 0.55)
zoomOut.Text = "−"
zoomOut.TextScaled = true
zoomOut.Parent = zoomFrame

--------------------------------------------------
-- STATE
--------------------------------------------------
local mapMode = false
local moveDir = Vector3.zero
local zoomDir = 0           -- -1 out, +1 in

local mapCenter = Vector3.zero
local velocity = Vector3.zero

local mapHeight = 300
local targetHeight = 300

local selectedPosition
local originalType
local originalCF

--------------------------------------------------
-- MARKER
--------------------------------------------------
local marker = Instance.new("Part")
marker.Anchored = true
marker.CanCollide = false
marker.Shape = Enum.PartType.Ball
marker.Size = Vector3.new(1.5,1.5,1.5)
marker.Material = Enum.Material.Neon
marker.Color = Color3.fromRGB(0,255,0)
marker.Transparency = 1
marker.Parent = workspace

--------------------------------------------------
-- CAMERA LOOP
--------------------------------------------------
local function enterMap()
	if mapMode then return end
	mapMode = true

	dpad.Visible = true
	zoomFrame.Visible = true

	originalType = camera.CameraType
	originalCF = camera.CFrame
	camera.CameraType = Enum.CameraType.Scriptable

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		mapCenter = root.Position
	end

	RunService:BindToRenderStep("MapCam", 200, function()
		-- pan
		velocity += moveDir * PAN_SPEED
		mapCenter += velocity
		velocity *= INERTIA

		-- zoom
		targetHeight = math.clamp(
			targetHeight - zoomDir * ZOOM_SPEED,
			MIN_HEIGHT,
			MAX_HEIGHT
		)

		mapHeight += (targetHeight - mapHeight) * 0.25

		camera.CFrame = CFrame.new(
			mapCenter + Vector3.new(0, mapHeight, 0),
			mapCenter
		)
	end)
end

local function exitMap()
	mapMode = false
	dpad.Visible = false
	zoomFrame.Visible = false
	moveDir = Vector3.zero
	zoomDir = 0

	RunService:UnbindFromRenderStep("MapCam")
	camera.CameraType = originalType
	camera.CFrame = originalCF
end

--------------------------------------------------
-- D-PAD HOLD LOGIC
--------------------------------------------------
local function bindDir(btn, dir)
	btn.MouseButton1Down:Connect(function()
		if mapMode then moveDir = dir end
	end)
	btn.MouseButton1Up:Connect(function()
		moveDir = Vector3.zero
	end)
end

bindDir(up,    Vector3.new(0,0,-1))
bindDir(down,  Vector3.new(0,0, 1))
bindDir(left,  Vector3.new(-1,0,0))
bindDir(right, Vector3.new( 1,0,0))

--------------------------------------------------
-- ZOOM HOLD LOGIC
--------------------------------------------------
zoomIn.MouseButton1Down:Connect(function()
	if mapMode then zoomDir = 1 end
end)
zoomIn.MouseButton1Up:Connect(function()
	zoomDir = 0
end)

zoomOut.MouseButton1Down:Connect(function()
	if mapMode then zoomDir = -1 end
end)
zoomOut.MouseButton1Up:Connect(function()
	zoomDir = 0
end)

--------------------------------------------------
-- ACCURATE TAP SELECTION (GROUND PLANE)
--------------------------------------------------
UIS.InputEnded:Connect(function(input)
	if not mapMode then return end
	if input.UserInputType ~= Enum.UserInputType.Touch
	and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end

	local ray = camera:ViewportPointToRay(input.Position.X, input.Position.Y)
	if math.abs(ray.Direction.Y) < 0.001 then return end

	local t = (GROUND_Y - ray.Origin.Y) / ray.Direction.Y
	if t < 0 then return end

	local hitPos = ray.Origin + ray.Direction * t

	selectedPosition = hitPos
	marker.Position = hitPos
	marker.Transparency = 0
end)

--------------------------------------------------
-- BUTTONS
--------------------------------------------------
selectBtn.MouseButton1Click:Connect(enterMap)
cancelBtn.MouseButton1Click:Connect(exitMap)

teleportBtn.MouseButton1Click:Connect(function()
	if selectedPosition and player.Character then
		local root = player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.new(selectedPosition + Vector3.new(0,5,0))
		end
	end
	exitMap()
end)
