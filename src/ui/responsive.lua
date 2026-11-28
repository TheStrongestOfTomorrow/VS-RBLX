-- Viewport observer, touch/mobile detector & keyboard-aware usable-area calculator
-- powering VS-RBLX's auto-resized window and Acode Mobile Mode.
return function(env)
	local signal = env.require("runtime/signal")
	local config = env.require("runtime/config")
	local dispose = env.require("runtime/dispose")

	local M = {
		viewport = Vector2.new(1280, 720),
		compact = false,
		touch = false,
		keyboardOpen = false,
		keyboardHeight = 0,
		changed = signal.new("responsive.changed"),
	}

	local camConn = nil

	local function readViewport()
		local ws = env.services.Workspace
		local cam = ws and ws.CurrentCamera or nil
		if cam and cam.ViewportSize and cam.ViewportSize.X > 0 and cam.ViewportSize.Y > 0 then
			M.viewport = cam.ViewportSize
		end
		M.touch = (env.uis ~= nil and env.uis.TouchEnabled == true)
		M.compact = M.viewport.X < 860 or M.viewport.Y < 540
	end

	function M.isTouchDevice()
		readViewport()
		return M.touch
	end

	function M.setVirtualKeyboard(openFlag, customHeight)
		M.keyboardOpen = openFlag == true
		if M.keyboardOpen then
			M.keyboardHeight = tonumber(customHeight) or math.floor(M.viewport.Y * 0.34)
		else
			M.keyboardHeight = 0
		end
		M.changed:fire(M.viewport)
	end

	local function bindCamera()
		if camConn then
			pcall(function() camConn:Disconnect() end)
			camConn = nil
		end
		local ws = env.services.Workspace
		local cam = ws and ws.CurrentCamera or nil
		if cam then
			readViewport()
			camConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				readViewport()
				M.changed:fire(M.viewport)
			end)
			dispose.connection(camConn)
		end
	end

	bindCamera()
	local ws = env.services.Workspace
	if ws then
		pcall(function()
			dispose.connection(ws:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
				bindCamera()
				M.changed:fire(M.viewport)
			end))
		end)
	end

	-- Listen to Roblox TextBox focus events on touch devices for keyboard-aware viewport adjustment
	if env.uis then
		pcall(function()
			if env.uis.TextBoxFocused then
				dispose.connection(env.uis.TextBoxFocused:Connect(function()
					if env.uis.TouchEnabled == true and env.uis.KeyboardEnabled ~= true then
						M.setVirtualKeyboard(true)
					end
				end))
			end
			if env.uis.TextBoxFocusReleased then
				dispose.connection(env.uis.TextBoxFocusReleased:Connect(function()
					if M.keyboardOpen then
						M.setVirtualKeyboard(false)
					end
				end))
			end
		end)
	end

	function M.usableRect(margin)
		readViewport()
		local pad = tonumber(margin) or 8
		local topInset = 0
		if env.guisvc and type(env.guisvc.GetGuiInset) == "function" then
			local ok, insetTop = pcall(function() return env.guisvc:GetGuiInset() end)
			if ok and insetTop then
				topInset = math.max(0, insetTop.Y)
			end
		end
		local cfgKb = tonumber(config.get("mobile.keyboardInset", 0)) or 0
		local kbReserve = math.max(M.keyboardHeight, cfgKb)
		local x = pad
		local y = pad
		-- Keep the usable rectangle truthful on compact phones and while the virtual
		-- keyboard is open. Fabricating a 300x220 minimum here made the window extend
		-- beyond short viewports and pushed dialogs behind the keyboard.
		local w = math.max(1, M.viewport.X - pad * 2)
		local h = math.max(1, M.viewport.Y - topInset - kbReserve - pad * 2)
		return {
			x = x,
			y = y,
			width = w,
			height = h,
			keyboardHeight = kbReserve,
			viewportX = M.viewport.X,
			viewportY = M.viewport.Y - topInset,
		}
	end

	return M
end
