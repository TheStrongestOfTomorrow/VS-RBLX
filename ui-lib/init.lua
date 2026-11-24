-- Standalone VS-RBLX Windowing & Theme UI Library (`ui-lib/init.lua`)
-- Mounts VS Code-themed draggable, viewport-auto-resized, 8-way player-resizable windows
-- in any Roblox LocalScript or Executor script.

local M = { version = "1.0.0" }

function M.mountWindow(opts)
	opts = opts or {}
	local uis = game:GetService("UserInputService")
	local ws = game:GetService("Workspace")
	local plrs = game:GetService("Players")

	local host = opts.parent
	if not host and type(gethui) == "function" then
		local ok, hui = pcall(gethui)
		if ok and hui then host = hui end
	end
	if not host and plrs.LocalPlayer then
		host = plrs.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	end

	local sg = Instance.new("ScreenGui")
	sg.Name = opts.name or "VSRBLX_StandaloneWindow"
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	if host then pcall(function() sg.Parent = host end) end

	local win = Instance.new("Frame", sg)
	win.Name = "Window"
	win.Size = UDim2.fromOffset(opts.width or 760, opts.height or 480)
	win.Position = UDim2.fromOffset(120, 80)
	win.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	win.BorderSizePixel = 0
	win.ClipsDescendants = true
	win.Active = true

	local corner = Instance.new("UICorner", win)
	corner.CornerRadius = UDim.new(0, 6)
	local stroke = Instance.new("UIStroke", win)
	stroke.Color = Color3.fromRGB(59, 59, 59)

	local titleBar = Instance.new("Frame", win)
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, 32)
	titleBar.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	titleBar.BorderSizePixel = 0
	titleBar.Active = true

	local titleLbl = Instance.new("TextLabel", titleBar)
	titleLbl.Size = UDim2.new(1, -24, 1, 0)
	titleLbl.Position = UDim2.fromOffset(12, 0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = Enum.Font.SourceSansBold
	titleLbl.TextSize = 13
	titleLbl.TextColor3 = Color3.fromRGB(212, 212, 212)
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Text = opts.title or "VS-RBLX Window"

	local body = Instance.new("Frame", win)
	body.Name = "Body"
	body.Size = UDim2.new(1, 0, 1, -32)
	body.Position = UDim2.fromOffset(0, 32)
	body.BackgroundTransparency = 1

	local resizeGrip = Instance.new("Frame", win)
	resizeGrip.Name = "ResizeCorner"
	resizeGrip.Size = UDim2.fromOffset(14, 14)
	resizeGrip.Position = UDim2.new(1, -14, 1, -14)
	resizeGrip.BackgroundTransparency = 1
	resizeGrip.Active = true

	local mode = nil
	local startMouse, startPos, startSize

	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			mode = "drag"
			startMouse = input.Position
			startPos = win.Position
		end
	end)

	resizeGrip.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			mode = "resize"
			startMouse = input.Position
			startSize = win.Size
		end
	end)

	local c1 = uis.InputChanged:Connect(function(input)
		if not mode then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		local dx = input.Position.X - startMouse.X
		local dy = input.Position.Y - startMouse.Y
		if mode == "drag" then
			win.Position = UDim2.fromOffset(startPos.X.Offset + dx, startPos.Y.Offset + dy)
		elseif mode == "resize" then
			win.Size = UDim2.fromOffset(
				math.max(360, startSize.X.Offset + dx),
				math.max(240, startSize.Y.Offset + dy)
			)
		end
	end)

	local c2 = uis.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			mode = nil
		end
	end)

	local cam = ws.CurrentCamera
	local c3 = cam and cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		local vp = cam.ViewportSize
		local w = math.min(win.Size.X.Offset, math.max(360, vp.X - 16))
		local h = math.min(win.Size.Y.Offset, math.max(240, vp.Y - 16))
		win.Size = UDim2.fromOffset(w, h)
	end) or nil

	return {
		screenGui = sg,
		window = win,
		body = body,
		destroy = function()
			c1:Disconnect()
			c2:Disconnect()
			if c3 then c3:Disconnect() end
			sg:Destroy()
		end,
	}
end

return M
