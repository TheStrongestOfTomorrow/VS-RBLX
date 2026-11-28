-- Draggable, Auto-Resized, and Explicit Toggle-Resizable (`⤢` ON/OFF) Window Shell for VS-RBLX.
-- Supports both Desktop and Mobile Acode Mode as a movable floating window (with `□` Maximize
-- when full-bleed is desired) + a draggable `MinimizedPill` (`VS-RBLX ↗`).
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

	local DESKTOP_MIN_W = 360
	local DESKTOP_MIN_H = 240
	local MOBILE_MIN_W = 280
	local MOBILE_MIN_H = 200
	local SNAP_EDGE = 12

	local M = {}

	function M.new(parentScreen)
		local initOpacity = util.clamp(tonumber(config.get("window.opacity", 1.0)) or 1.0, 0.30, 1.0)
		local win = {
			visible = true,
			minimised = false,
			maximised = config.get("window.maximised", false) == true,
			mobileMode = false,
			resizeMode = false, -- Explicit Topbar `⤢` Resize Toggle (OFF by default so edges never hijack moving!)
			playWhileCoding = config.get("mobile.playWhileCoding", false) == true,
			opacity = initOpacity,
			opacityChanged = signal.new("window.opacityChanged"),
			resizeModeChanged = signal.new("window.resizeModeChanged"),
			snappedSide = nil,
			onResize = nil,
		}
		local prePlayOpacity = nil

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

		-- Minimized floating launcher pill (now draggable so mobile players can move it away from thumbsticks!)
		local pill = P.button(parentScreen, {
			name = "MinimizedPill",
			size = UDim2.fromOffset(128, 32),
			pos = UDim2.new(0, 16, 1, -52),
			bg = theme.color.titleBar,
			hoverBg = theme.color.hover,
			text = "",
			radius = 16,
			border = theme.color.accent,
			visible = false,
			zIndex = 190,
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
		local activeGesture = nil
		local pillDidDrag = false

		pill.InputBegan:Connect(function(input)
			local kind = input.UserInputType
			if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then return end
			pillDidDrag = false
			local absP = pill.AbsolutePosition
			activeGesture = {
				mode = "pillDrag",
				input = input,
				startMouse = input.Position,
				startX = absP.X,
				startY = absP.Y,
			}
		end)
		pill.Activated:Connect(function()
			if pillDidDrag then
				pillDidDrag = false
				return
			end
			win.restore()
		end)

		local function persistRect()
			if win.maximised or win.snappedSide then return end
			config.set("window.width", math.floor(root.Size.X.Offset), { quiet = true })
			config.set("window.height", math.floor(root.Size.Y.Offset), { quiet = true })
			config.set("window.x", math.floor(root.Position.X.Offset), { quiet = true })
			config.set("window.y", math.floor(root.Position.Y.Offset), { quiet = true })
			config.set("window.placed", true, { quiet = true })
		end

		function win.effectiveMinBounds(bounds)
			local compactTouchPlay = win.playWhileCoding and responsive.isTouchDevice() and responsive.compact
			local minW = (win.mobileMode or compactTouchPlay) and MOBILE_MIN_W or DESKTOP_MIN_W
			local minH = (win.mobileMode or compactTouchPlay) and MOBILE_MIN_H or DESKTOP_MIN_H
			return math.min(minW, bounds.width), math.min(minH, bounds.height)
		end

		function win.applyLayout(reason)
			local bounds = responsive.usableRect(win.maximised and 0 or 6)
			local effMinW, effMinH = win.effectiveMinBounds(bounds)

			if win.playWhileCoding then
				-- On compact touch screens use a taller coding dock while preserving a
				-- meaningful gameplay strip; desktop-sized windows retain the 52% peek.
				local compactTouchPlay = responsive.isTouchDevice() and responsive.compact
				local dockRatio = compactTouchPlay and 0.68 or 0.52
				local dockW = math.max(effMinW, math.floor(bounds.width * dockRatio))
				local dockH = math.max(effMinH, math.floor(bounds.height * 0.94))
				root.Position = UDim2.fromOffset(bounds.x + bounds.width - dockW, bounds.y)
				root.Size = UDim2.fromOffset(dockW, dockH)
			elseif win.maximised then
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
					local defScaleW = win.mobileMode and 0.90 or 0.84
					local defScaleH = win.mobileMode and 0.86 or 0.84
					local scaleW = tonumber(config.get("window.widthScale", defScaleW)) or defScaleW
					local scaleH = tonumber(config.get("window.heightScale", defScaleH)) or defScaleH
					if win.mobileMode and not customSize then
						scaleW = defScaleW
						scaleH = defScaleH
					end
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

		-- 8-way Push/Pull Resize Handles (ONLY active & visible when `win.resizeMode == true`!)
		local resizeHandles = {}

		local function makeResizeZone(name, dirX, dirY, isCorner)
			local zone = P.frame(root, {
				name = name,
				size = UDim2.fromOffset(14, 14),
				pos = UDim2.fromOffset(0, 0),
				bg = theme.color.accent,
				transparency = 0.20,
				radius = isCorner and 6 or 3,
				visible = false,
				active = false,
				zIndex = 95,
			})
			resizeHandles[#resizeHandles + 1] = {
				zone = zone,
				dirX = dirX,
				dirY = dirY,
				isCorner = isCorner == true,
			}

			zone.InputBegan:Connect(function(input)
				if not win.resizeMode then return end
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

		makeResizeZone("ResizeLeft", -1, 0, false)
		makeResizeZone("ResizeRight", 1, 0, false)
		makeResizeZone("ResizeTop", 0, -1, false)
		makeResizeZone("ResizeBottom", 0, 1, false)
		makeResizeZone("ResizeTopLeft", -1, -1, true)
		makeResizeZone("ResizeTopRight", 1, -1, true)
		makeResizeZone("ResizeBottomLeft", -1, 1, true)
		makeResizeZone("ResizeBottomRight", 1, 1, true)

		-- Visual Resize-Mode Banner Pill at top-center while Resize Mode is ON
		local resizeBanner = P.button(root, {
			name = "ResizeModeBanner",
			size = UDim2.fromOffset(224, 24),
			pos = UDim2.new(0.5, 0, 0, 42),
			anchor = Vector2.new(0.5, 0),
			bg = theme.color.accent,
			hoverBg = theme.color.accentHover,
			color = Color3.fromRGB(255, 255, 255),
			bold = true,
			text = "⤢ RESIZE ON — Pull/Push Edges (Tap to Lock)",
			textSize = 10,
			radius = 12,
			visible = false,
			zIndex = 96,
			onClick = function()
				win.setResizeMode(false)
			end,
		})
		resizeBanner.BackgroundTransparency = 0.05

		local function layoutResizeHandles()
			local edgeT = win.mobileMode and 14 or 8
			local cornerS = win.mobileMode and 24 or 16
			for _, h in ipairs(resizeHandles) do
				local z = h.zone
				z.BackgroundColor3 = theme.color.accent
				if h.isCorner then
					z.Size = UDim2.fromOffset(cornerS, cornerS)
					local px = (h.dirX == -1) and UDim.new(0, 0) or UDim.new(1, -cornerS)
					local py = (h.dirY == -1) and UDim.new(0, 0) or UDim.new(1, -cornerS)
					z.Position = UDim2.new(px.Scale, px.Offset, py.Scale, py.Offset)
					z.BackgroundTransparency = 0.12
				elseif h.dirX ~= 0 then
					z.Size = UDim2.new(0, edgeT, 1, -cornerS * 2)
					z.Position = (h.dirX == -1)
						and UDim2.fromOffset(0, cornerS)
						or UDim2.new(1, -edgeT, 0, cornerS)
					z.BackgroundTransparency = 0.35
				else
					z.Size = UDim2.new(1, -cornerS * 2, 0, edgeT)
					z.Position = (h.dirY == -1)
						and UDim2.fromOffset(cornerS, 0)
						or UDim2.new(0, cornerS, 1, -edgeT)
					z.BackgroundTransparency = 0.35
				end
			end
		end

		local function updateResizeVisibility()
			local show = win.resizeMode and (not win.maximised)
			layoutResizeHandles()
			for _, h in ipairs(resizeHandles) do
				h.zone.Visible = show
				h.zone.Active = show
			end
			resizeBanner.Visible = show
			borderStroke.Color = show and theme.color.accent or theme.color.border
			borderStroke.Thickness = show and 2 or 1
		end

		function win.setResizeMode(flag)
			local nextFlag = flag == true
			if nextFlag and win.maximised then
				-- Automatically un-maximize slightly so the player has edges to push/pull!
				local bounds = responsive.usableRect(6)
				win.maximised = false
				config.set("window.maximised", false, { quiet = true })
				local nw = math.floor(bounds.width * 0.90)
				local nh = math.floor(bounds.height * 0.88)
				root.Size = UDim2.fromOffset(nw, nh)
				root.Position = UDim2.fromOffset(
					bounds.x + math.floor((bounds.width - nw) * 0.5),
					bounds.y + math.floor((bounds.height - nh) * 0.5)
				)
				if win.onResize then pcall(win.onResize, nw, nh) end
			end
			win.resizeMode = nextFlag
			activeGesture = nil
			updateResizeVisibility()
			win.resizeModeChanged:fire(win.resizeMode)
			return win.resizeMode
		end

		function win.toggleResizeMode()
			return win.setResizeMode(not win.resizeMode)
		end

		local lastTitleClickMs = -1000
		local lastTitleClickX = -1000
		local lastTitleClickY = -1000

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
				-- While Resize Mode is ON, pause TitleBar move-dragging so pull/push handles never fight moving!
				if win.resizeMode then return end
				local kind = input.UserInputType
				if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then return end
				if isInteractiveDescendant(input) then return end

				local nowMs = clock.ms()
				if (nowMs - lastTitleClickMs < 320)
					and math.abs(input.Position.X - lastTitleClickX) < 6
					and math.abs(input.Position.Y - lastTitleClickY) < 6 then
					lastTitleClickMs = -1000
					win.toggleMaximise()
					return
				end
				lastTitleClickMs = nowMs
				lastTitleClickX = input.Position.X
				lastTitleClickY = input.Position.Y

				if win.maximised or win.snappedSide then
					local bounds = responsive.usableRect(6)
					local restoreW = preSnapRect and preSnapRect.w or math.floor(bounds.width * 0.82)
					local restoreH = preSnapRect and preSnapRect.h or math.floor(bounds.height * 0.82)
					win.maximised = false
					win.snappedSide = nil
					config.set("window.maximised", false, { quiet = true })
					local newX = util.clamp(math.floor(input.Position.X - restoreW * 0.5), bounds.x, math.max(bounds.x, bounds.x + bounds.width - restoreW))
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

				if activeGesture.mode == "pillDrag" then
					if math.abs(dx) >= 6 or math.abs(dy) >= 6 then
						pillDidDrag = true
					end
					if pillDidDrag then
						local pw = pill.AbsoluteSize.X
						local ph = pill.AbsoluteSize.Y
						local px = util.clamp(math.floor(activeGesture.startX + dx), 4, math.max(4, bounds.x + bounds.width - pw - 4))
						local py = util.clamp(math.floor(activeGesture.startY + dy), 4, math.max(4, bounds.y + bounds.height - ph - 4))
						pill.Position = UDim2.fromOffset(px, py)
					end
				elseif activeGesture.mode == "drag" then
					local w = root.Size.X.Offset
					local h = root.Size.Y.Offset
					local nx = util.clamp(math.floor(activeGesture.startX + dx), bounds.x, math.max(bounds.x, bounds.x + bounds.width - w))
					local ny = util.clamp(math.floor(activeGesture.startY + dy), bounds.y, math.max(bounds.y, bounds.y + bounds.height - h))
					root.Position = UDim2.fromOffset(nx, ny)
				elseif activeGesture.mode == "resize" and win.resizeMode then
					local effMinW, effMinH = win.effectiveMinBounds(bounds)
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
				local bounds = responsive.usableRect(6)

				if g.mode == "drag" then
					-- Only Aero-Snap on Desktop Mode (on Mobile Mode let players position near edges freely!)
					if not win.mobileMode then
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
					end
					persistRect()
					config.saveNow()
				elseif g.mode == "pillDrag" then
					if pillDidDrag then
						task.delay(0.05, function()
							pillDidDrag = false
						end)
					end
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
			if win.maximised and win.resizeMode then
				win.resizeMode = false
				win.resizeModeChanged:fire(false)
			end
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

		function win.setMobileMode(flag)
			win.mobileMode = flag == true
			pill.Size = flag and UDim2.fromOffset(148, 40) or UDim2.fromOffset(128, 32)
			pillBrand.Position = UDim2.fromOffset(12, flag and 12 or 8)
			updateResizeVisibility()
			win.applyLayout("mobileMode")
		end

		function win.setPlayWhileCoding(flag)
			local nextPlay = flag == true
			win.playWhileCoding = nextPlay
			config.set("mobile.playWhileCoding", nextPlay, { immediate = true })
			if nextPlay then
				if win.opacity > 0.80 then
					prePlayOpacity = win.opacity
					win.setOpacity(0.72)
				end
			elseif prePlayOpacity then
				win.setOpacity(prePlayOpacity)
				prePlayOpacity = nil
			end
			win.applyLayout("playWhileCoding")
			return nextPlay
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
			pill.BackgroundColor3 = theme.color.titleBar
			resizeBanner.BackgroundColor3 = theme.color.accent
			updateResizeVisibility()
		end)

		updateResizeVisibility()
		win.applyLayout("init")
		return win
	end

	return M
end
