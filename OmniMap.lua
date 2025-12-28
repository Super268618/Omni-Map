-- Omni Map Teleport Interface
-- Four-Way Swiper + Accurate Selection + Compass + Animated Marker
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
local GROUND_Y = 0        -- ground plane height
local PAN_SPEED = 1.2
local INERTIA = 0.85
local MAP_HEIGHT = 300     -- fixed bird-eye camera height

--------------------------------------------------
-- GUI ROOT
--------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Top buttons
local function topButton(text, x)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromScale(0.25,0.07)
	b.Position = UDim2.fromScale(x,0.02)
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
dpad.Size = UDim2.fromScale(0.28,0.28)
dpad.Position = UDim2.fromScale(0.05,0.62)
dpad.BackgroundTransparency = 1
dpad.Visible = false
dpad.Parent = gui

local function dirBtn(pos, txt)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromScale(0.3,0.3)
	b.Position = pos
	b.Text = txt
	b.TextScaled = true
	b.BackgroundTransparency = 0.2
	b.Parent = dpad
	return b
end

local up = dirBtn(UDim2.fromScale(0.35,0.0), "↑")
local down = dirBtn(UDim2.fromScale(0.35,0.7), "↓")
local left = dirBtn(UDim2.fromScale(0.0,0.35), "←")
local right = dirBtn(UDim2.fromScale(0.7,0.35), "→")

--------------------------------------------------
-- COMPASS
--------------------------------------------------
local compass = Instance.new("ImageLabel")
compass.Size = UDim2.fromScale(0.08,0.08)
compass.Position = UDim2.fromScale(0.9,0.02)
compass.BackgroundTransparency = 1
compass.Image = "rbxassetid://6268610579" -- north arrow asset
compass.Visible = false
compass.Parent = gui

--------------------------------------------------
-- STATE
--------------------------------------------------
local mapMode = false
local moveDir = Vector3.zero
local mapCenter = Vector3.zero
local velocity = Vector3.zero
local selectedPosition
local originalType
local originalCF

--------------------------------------------------
-- MARKER WITH ANIMATION
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

local function animateMarker(pos)
	marker.Position = pos
	marker.Transparency = 0
	local tween = TweenService:Create(marker, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(3,3,3)})
	tween:Play()
	tween.Completed:Connect(function()
		TweenService:Create(marker, TweenInfo.new(0.2), {Size = Vector3.new(1.5,1.5,1.5)}):Play()
	end)
end

--------------------------------------------------
-- CAMERA LOOP
--------------------------------------------------
local function enterMap()
	if mapMode then return end
	mapMode = true
	dpad.Visible = true
	compass.Visible = true

	originalType = camera.CameraType
	originalCF = camera.CFrame
	camera.CameraType = Enum.CameraType.Scriptable

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then mapCenter = root.Position end

	RunService:BindToRenderStep("MapCam",200,function()
		-- pan
		velocity += moveDir * PAN_SPEED
		mapCenter += velocity
		velocity *= INERTIA

		-- camera fixed height
		camera.CFrame = CFrame.new(mapCenter + Vector3.new(0,MAP_HEIGHT,0), mapCenter)

		-- compass (north up)
		compass.Rotation = 0
	end)
end

local function exitMap()
	mapMode = false
	dpad.Visible = false
	compass.Visible = false
	moveDir = Vector3.zero
	RunService:UnbindFromRenderStep("MapCam")
	camera.CameraType = originalType
	camera.CFrame = originalCF
end

--------------------------------------------------
-- D-PAD
--------------------------------------------------
local function bindDir(btn, dir)
	btn.MouseButton1Down:Connect(function() if mapMode then moveDir = dir end end)
	btn.MouseButton1Up:Connect(function() moveDir = Vector3.zero end)
end

bindDir(up, Vector3.new(0,0,-1))
bindDir(down, Vector3.new(0,0,1))
bindDir(left, Vector3.new(-1,0,0))
bindDir(right, Vector3.new(1,0,0))

--------------------------------------------------
-- ACCURATE TAP SELECTION
--------------------------------------------------
UIS.InputEnded:Connect(function(input)
	if not mapMode then return end
	if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

	local ray = camera:ViewportPointToRay(input.Position.X, input.Position.Y)
	if math.abs(ray.Direction.Y) < 0.001 then return end
	local t = (GROUND_Y - ray.Origin.Y)/ray.Direction.Y
	if t < 0 then return end

	local hitPos = ray.Origin + ray.Direction * t
	selectedPosition = hitPos
	animateMarker(hitPos)
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
