-- Draggable, Auto-Resized, and 8-Direction Player-Resizable Window Shell for VS-RBLX.
return function(env)
	local util = env.require("runtime/util")
	local config = env.require("runtime/config")
	local dispose = env.require("runtime/dispose")
	local clock = env.require("runtime/clock")
	local signal = env.require("runtime/signal")
	local theme = env.require("ui/theme")
	local responsive = env.require("ui/responsive")
	local brand = env.require("ui/brand")
	local P = env.require("ui/primitives")

	local MIN_W = 540
	local MIN_H = 320
	local SNAP_EDGE = 12
	local HANDLE_THICK = 6
	local CORNER_SIZE = 14

	local M = {}

	function M.new(parentScreen)
		local initOpacity = util.clamp(tonumber(config.get("window.opacity", 1.0)) or 1.0, 0.30, 1.0)
		local win = {
			visible = true,
			minimised = false,
			maximised = config.get("window.maximised", false) == true,
			opacity = initOpacity,
			opacityChanged = signal.new("window.opacityChanged"),
			snappedSide = nil,
			onResize = nil,
		}

		local root = P.frame(parentScreen, {
			name = "VSCodeWindow",
			size = UDim2.fromOffset(980, 620),
			pos = UDim2.fromOffset(100, 60),
			bg = theme.color.editor,
			transparency = 1,
			radius = 6,
			clip = true,
			active = true,
			zIndex = 10,
		})
		local borderStroke = P.stroke(root, theme.color.border, 1)
		win.root = root

		local contentHost = P.frame(root, {
			name = "WorkbenchHost",
			size = UDim2.fromScale(1, 1),
			clip = true,
			zIndex = 11,
		})
		win.body = contentHost

		-- Minimized floating launcher pill
		local pill = P.button(parentScreen, {
			name = "MinimizedPill",
			size = UDim2.fromOffset(128, 32),
			pos = UDim2.new(0, 16, 1, -48),
			bg = theme.color.titleBar,
			hoverBg = theme.color.hover,
			text = "",
			radius = 16,
			border = theme.color.accent,
			visible = false,
			zIndex = 190,
			onClick = function()
				win.restore()
			end,
		})
		local pillBrand = brand.draw(pill, 16, 192)
		pillBrand.Position = UDim2.fromOffset(10, 8)
		P.label(pill, {
			size = UDim2.new(1, -34, 1, 0),
			pos = UDim2.fromOffset(32, 0),
			text = "VS-RBLX  ↗",
			bold = true,
			textSize = 12,
			color = theme.color.titleBarText,
			zIndex = 192,
		})
		win.pill = pill

		local preSnapRect = nil

		local function persistRect()
			if win.maximised or win.snappedSide then return end
			config.set("window.width", math.floor(root.Size.X.Offset), { quiet = true })
			config.set("window.height", math.floor(root.Size.Y.Offset), { quiet = true })
			config.set("window.x", math.floor(root.Position.X.Offset), { quiet = true })
			config.set("window.y", math.floor(root.Position.Y.Offset), { quiet = true })
			config.set("window.placed", true, { quiet = true })
		end

		function win.applyLayout(reason)
			local bounds = responsive.usableRect(win.maximised and 0 or 8)
			local effMinW = math.min(MIN_W, bounds.width)
			local effMinH = math.min(MIN_H, bounds.height)

			if win.maximised then
				root.Position = UDim2.fromOffset(bounds.x, bounds.y)
				root.Size = UDim2.fromOffset(bounds.width, bounds.height)
			elseif win.snappedSide == "left" then
				root.Position = UDim2.fromOffset(bounds.x, bounds.y)
				root.Size = UDim2.fromOffset(math.floor(bounds.width * 0.5), bounds.height)
			elseif win.snappedSide == "right" then
				local half = math.floor(bounds.width * 0.5)
				root.Position = UDim2.fromOffset(bounds.x + bounds.width - half, bounds.y)
				root.Size = UDim2.fromOffset(half, bounds.height)
			else
				local autoScale = config.get("window.autoResize", true) == true
				local customSize = config.get("window.customSize", false) == true
				local placed = config.get("window.placed", false) == true

				local w, h
				if autoScale and (not customSize or reason == "resetAuto") then
					local scaleW = tonumber(config.get("window.widthScale", 0.84)) or 0.84
					local scaleH = tonumber(config.get("window.heightScale", 0.84)) or 0.84
					w = math.floor(bounds.width * scaleW)
					h = math.floor(bounds.height * scaleH)
				else
					w = tonumber(config.get("window.width", 980)) or 980
					h = tonumber(config.get("window.height", 620)) or 620
				end

				w = util.clamp(w, effMinW, bounds.width)
				h = util.clamp(h, effMinH, bounds.height)

				local x, y
				if placed then
					x = tonumber(config.get("window.x", 0)) or 0
					y = tonumber(config.get("window.y", 0)) or 0
				else
					x = bounds.x + math.floor((bounds.width - w) * 0.5)
					y = bounds.y + math.floor((bounds.height - h) * 0.5)
				end
				x = util.clamp(x, bounds.x, math.max(bounds.x, bounds.x + bounds.width - w))
				y = util.clamp(y, bounds.y, math.max(bounds.y, bounds.y + bounds.height - h))

				root.Size = UDim2.fromOffset(w, h)
				root.Position = UDim2.fromOffset(x, y)
			end

			if win.onResize then
				pcall(win.onResize, root.Size.X.Offset, root.Size.Y.Offset)
			end
		end

		-- 8-way interactive edge & corner resize handles
		local resizeHandles = {}
		local activeGesture = nil

		local function makeResizeZone(name, sizeUDim, posUDim, dirX, dirY)
			local zone = P.frame(root, {
				name = name,
				size = sizeUDim,
				pos = posUDim,
				active = true,
				zIndex = 95,
			})
			zone.BackgroundTransparency = 1
			resizeHandles[#resizeHandles + 1] = zone

			zone.InputBegan:Connect(function(input)
				local kind = input.UserInputType
				if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then return end
				if win.maximised then return end
				win.snappedSide = nil
				activeGesture = {
					mode = "resize",
					input = input,
					startMouse = input.Position,
					startX = root.Position.X.Offset,
					startY = root.Position.Y.Offset,
					startW = root.Size.X.Offset,
					startH = root.Size.Y.Offset,
					dirX = dirX,
					dirY = dirY,
				}
			end)
		end

		makeResizeZone("ResizeLeft", UDim2.new(0, HANDLE_THICK, 1, -CORNER_SIZE * 2), UDim2.fromOffset(0, CORNER_SIZE), -1, 0)
		makeResizeZone("ResizeRight", UDim2.new(0, HANDLE_THICK, 1, -CORNER_SIZE * 2), UDim2.new(1, -HANDLE_THICK, 0, CORNER_SIZE), 1, 0)
		makeResizeZone("ResizeTop", UDim2.new(1, -CORNER_SIZE * 2, 0, HANDLE_THICK), UDim2.fromOffset(CORNER_SIZE, 0), 0, -1)
		makeResizeZone("ResizeBottom", UDim2.new(1, -CORNER_SIZE * 2, 0, HANDLE_THICK), UDim2.new(0, CORNER_SIZE, 1, -HANDLE_THICK), 0, 1)
		makeResizeZone("ResizeTopLeft", UDim2.fromOffset(CORNER_SIZE, CORNER_SIZE), UDim2.fromOffset(0, 0), -1, -1)
		makeResizeZone("ResizeTopRight", UDim2.fromOffset(CORNER_SIZE, CORNER_SIZE), UDim2.new(1, -CORNER_SIZE, 0, 0), 1, -1)
		makeResizeZone("ResizeBottomLeft", UDim2.fromOffset(CORNER_SIZE, CORNER_SIZE), UDim2.new(0, 0, 1, -CORNER_SIZE), -1, 1)
		makeResizeZone("ResizeBottomRight", UDim2.fromOffset(CORNER_SIZE, CORNER_SIZE), UDim2.new(1, -CORNER_SIZE, 1, -CORNER_SIZE), 1, 1)

		-- Subtle diagonal grip dots on bottom-right corner
		local gripVisual = P.frame(root, {
			name = "ResizeGripVisual",
			size = UDim2.fromOffset(12, 12),
			pos = UDim2.new(1, -13, 1, -13),
			zIndex = 94,
		})
		for gx = 0, 2 do
			for gy = 0, 2 do
				if gx + gy >= 2 then
					P.frame(gripVisual, {
						size = UDim2.fromOffset(2, 2),
						pos = UDim2.fromOffset(gx * 4 + 1, gy * 4 + 1),
						bg = Color3.fromRGB(220, 220, 220),
						transparency = 0.35,
						zIndex = 94,
					})
				end
			end
		end

		local function updateResizeVisibility()
			local allow = not win.maximised
			for _, h in ipairs(resizeHandles) do h.Visible = allow end
			gripVisual.Visible = allow
		end

		local lastTitleClickMs = 0

		function win.bindDragBar(dragSurface)
			local function isInteractiveDescendant(input)
				for _, child in ipairs(dragSurface:GetDescendants()) do
					if child:IsA("GuiButton") or child:IsA("TextBox") then
						local p, s = child.AbsolutePosition, child.AbsoluteSize
						if child.Visible
							and input.Position.X >= p.X and input.Position.X <= p.X + s.X
							and input.Position.Y >= p.Y and input.Position.Y <= p.Y + s.Y then
							return true
						end
					end
				end
				return false
			end

			dragSurface.InputBegan:Connect(function(input)
				local kind = input.UserInputType
				if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then return end
				if isInteractiveDescendant(input) then return end

				local nowMs = clock.ms()
				if nowMs - lastTitleClickMs < 320 then
					lastTitleClickMs = 0
					win.toggleMaximise()
					return
				end
				lastTitleClickMs = nowMs

				if win.maximised or win.snappedSide then
					local bounds = responsive.usableRect(8)
					local restoreW = preSnapRect and preSnapRect.w or math.floor(bounds.width * 0.8)
					local restoreH = preSnapRect and preSnapRect.h or math.floor(bounds.height * 0.8)
					win.maximised = false
					win.snappedSide = nil
					config.set("window.maximised", false, { quiet = true })
					local newX = util.clamp(math.floor(input.Position.X - restoreW * 0.5), bounds.x, bounds.x + bounds.width - restoreW)
					local newY = bounds.y
					root.Size = UDim2.fromOffset(restoreW, restoreH)
					root.Position = UDim2.fromOffset(newX, newY)
					updateResizeVisibility()
				end

				activeGesture = {
					mode = "drag",
					input = input,
					startMouse = input.Position,
					startX = root.Position.X.Offset,
					startY = root.Position.Y.Offset,
				}
			end)
		end

		if env.uis then
			dispose.connection(env.uis.InputChanged:Connect(function(input)
				if not activeGesture then return end
				local kind = input.UserInputType
				if kind ~= Enum.UserInputType.MouseMovement and kind ~= Enum.UserInputType.Touch then return end

				local bounds = responsive.usableRect(4)
				local dx = input.Position.X - activeGesture.startMouse.X
				local dy = input.Position.Y - activeGesture.startMouse.Y

				if activeGesture.mode == "drag" then
					local w = root.Size.X.Offset
					local h = root.Size.Y.Offset
					local nx = util.clamp(math.floor(activeGesture.startX + dx), bounds.x, math.max(bounds.x, bounds.x + bounds.width - w))
					local ny = util.clamp(math.floor(activeGesture.startY + dy), bounds.y, math.max(bounds.y, bounds.y + bounds.height - h))
					root.Position = UDim2.fromOffset(nx, ny)
				elseif activeGesture.mode == "resize" then
					local effMinW = math.min(MIN_W, bounds.width)
					local effMinH = math.min(MIN_H, bounds.height)
					local nx = activeGesture.startX
					local ny = activeGesture.startY
					local nw = activeGesture.startW
					local nh = activeGesture.startH

					if activeGesture.dirX == 1 then
						nw = util.clamp(math.floor(activeGesture.startW + dx), effMinW, bounds.x + bounds.width - nx)
					elseif activeGesture.dirX == -1 then
						local rightEdge = activeGesture.startX + activeGesture.startW
						nx = util.clamp(math.floor(activeGesture.startX + dx), bounds.x, rightEdge - effMinW)
						nw = rightEdge - nx
					end

					if activeGesture.dirY == 1 then
						nh = util.clamp(math.floor(activeGesture.startH + dy), effMinH, bounds.y + bounds.height - ny)
					elseif activeGesture.dirY == -1 then
						local bottomEdge = activeGesture.startY + activeGesture.startH
						ny = util.clamp(math.floor(activeGesture.startY + dy), bounds.y, bottomEdge - effMinH)
						nh = bottomEdge - ny
					end

					root.Position = UDim2.fromOffset(nx, ny)
					root.Size = UDim2.fromOffset(nw, nh)
					if win.onResize then
						pcall(win.onResize, nw, nh)
					end
				end
			end))

			dispose.connection(env.uis.InputEnded:Connect(function(input)
				if not activeGesture then return end
				local kind = input.UserInputType
				if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then return end

				local g = activeGesture
				activeGesture = nil
				local bounds = responsive.usableRect(8)

				if g.mode == "drag" then
					-- Edge Aero-Snap: top = maximize, far left/right = 50% split
					if input.Position.Y <= bounds.y + SNAP_EDGE then
						preSnapRect = { w = root.Size.X.Offset, h = root.Size.Y.Offset }
						win.setMaximised(true)
						return
					elseif input.Position.X <= bounds.x + SNAP_EDGE then
						preSnapRect = { w = root.Size.X.Offset, h = root.Size.Y.Offset }
						win.snappedSide = "left"
						win.applyLayout("snap")
						return
					elseif input.Position.X >= bounds.x + bounds.width - SNAP_EDGE then
						preSnapRect = { w = root.Size.X.Offset, h = root.Size.Y.Offset }
						win.snappedSide = "right"
						win.applyLayout("snap")
						return
					end
					persistRect()
					config.saveNow()
				elseif g.mode == "resize" then
					config.set("window.customSize", true, { quiet = true })
					config.set("window.widthScale", root.Size.X.Offset / math.max(1, bounds.width), { quiet = true })
					config.set("window.heightScale", root.Size.Y.Offset / math.max(1, bounds.height), { quiet = true })
					persistRect()
					config.saveNow()
				end
			end))
		end

		function win.setMaximised(flag)
			if flag and not win.maximised then
				preSnapRect = { w = root.Size.X.Offset, h = root.Size.Y.Offset }
			end
			win.maximised = flag == true
			win.snappedSide = nil
			config.set("window.maximised", win.maximised, { immediate = true })
			updateResizeVisibility()
			win.applyLayout("maximise")
		end

		function win.toggleMaximise()
			win.setMaximised(not win.maximised)
		end

		function win.setOpacity(alpha, opts)
			opts = opts or {}
			local clamped = math.floor(util.clamp(tonumber(alpha) or 1.0, 0.30, 1.0) * 100 + 0.5) / 100
			win.opacity = clamped
			config.set("window.opacity", clamped, { quiet = opts.quiet == true, immediate = opts.immediate == true })
			win.opacityChanged:fire(clamped)
			return clamped
		end

		function win.getOpacity()
			return win.opacity
		end

		function win.stepOpacity(delta)
			return win.setOpacity(win.opacity + (tonumber(delta) or 0))
		end

		function win.resetAutoSize()
			win.maximised = false
			win.snappedSide = nil
			config.set("window.maximised", false, { quiet = true })
			config.set("window.customSize", false, { quiet = true })
			config.set("window.placed", false, { immediate = true })
			updateResizeVisibility()
			win.applyLayout("resetAuto")
		end

		function win.minimise()
			win.minimised = true
			root.Visible = false
			pill.Visible = true
		end

		function win.restore()
			win.minimised = false
			win.visible = true
			pill.Visible = false
			root.Visible = true
			win.applyLayout("restore")
		end

		function win.hide()
			win.visible = false
			root.Visible = false
			pill.Visible = false
		end

		function win.show()
			win.visible = true
			win.minimised = false
			pill.Visible = false
			root.Visible = true
			win.applyLayout("show")
		end

		function win.toggle()
			if win.minimised or not win.visible then
				win.restore()
			else
				win.minimise()
			end
		end

		responsive.changed:connect(function()
			if win.visible and not win.minimised then
				win.applyLayout("viewport")
			end
		end)

		theme.changed:connect(function()
			root.BackgroundColor3 = theme.color.editor
			borderStroke.Color = theme.color.border
			pill.BackgroundColor3 = theme.color.titleBar
		end)

		updateResizeVisibility()
		win.applyLayout("init")
		return win
	end

	return M
end
