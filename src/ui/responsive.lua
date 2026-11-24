-- Viewport observer & safe usable-area calculator powering VS-RBLX's auto-resized window.
return function(env)
	local signal = env.require("runtime/signal")
	local dispose = env.require("runtime/dispose")

	local M = {
		viewport = Vector2.new(1280, 720),
		compact = false,
		changed = signal.new("responsive.changed"),
	}

	local camConn = nil

	local function readViewport()
		local ws = env.services.Workspace
		local cam = ws and ws.CurrentCamera or nil
		if cam and cam.ViewportSize and cam.ViewportSize.X > 0 and cam.ViewportSize.Y > 0 then
			M.viewport = cam.ViewportSize
		end
		M.compact = M.viewport.X < 860 or M.viewport.Y < 540
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
		local x = pad
		local y = pad
		local w = math.max(360, M.viewport.X - pad * 2)
		local h = math.max(260, M.viewport.Y - topInset - pad * 2)
		return {
			x = x,
			y = y,
			width = w,
			height = h,
			viewportX = M.viewport.X,
			viewportY = M.viewport.Y - topInset,
		}
	end

	return M
end
