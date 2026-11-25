-- Authentic VS Code Title Bar: Brand Logo, Top Menu Bar (`File`, `Edit`, `View`,
-- `Run`, `GitHub`), Centered Command Center Search Pill (`Ctrl+P`), Ghost-Coding
-- Opacity Slider (`30%–100%`), Layout & Zen Toggles, and Window Controls (─, □, ✕).
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local brand = env.require("ui/brand")
	local icons = env.require("ui/icons")
	local overlay = env.require("ui/overlay")
	local util = env.require("runtime/util")
	local config = env.require("runtime/config")
	local dispose = env.require("runtime/dispose")
	local commands = env.require("runtime/command_catalog")
	local languages = env.require("runtime/languages")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")

	local M = {}

	function M.new(parent, callbacks)
		callbacks = callbacks or {}
		local h = theme.sizes.titleBar
		local mobileMode = false

		local bar = P.frame(parent, {
			name = "TitleBar",
			size = UDim2.new(1, 0, 0, h),
			bg = theme.color.titleBar,
			active = true,
			zIndex = 30,
		})
		local bottomBorder = P.frame(bar, {
			size = UDim2.new(1, 0, 0, 1),
			pos = UDim2.new(0, 0, 1, -1),
			bg = theme.color.border,
			zIndex = 31,
		})

		-- Mobile Acode `☰` Drawer Toggle (visible in Mobile Mode)
		local drawerBtn = P.button(bar, {
			name = "MobileDrawerBtn",
			size = UDim2.fromOffset(34, h - 2),
			pos = UDim2.fromOffset(4, 1),
			hoverBg = theme.color.hover,
			text = "☰",
			bold = true,
			textSize = 16,
			color = theme.color.titleBarText,
			radius = 4,
			visible = false,
			zIndex = 34,
			onClick = function()
				if callbacks.onToggleDrawer then callbacks.onToggleDrawer() end
			end,
		})

		local logo = brand.draw(bar, 16, 32)
		logo.Position = UDim2.fromOffset(10, math.floor((h - 16) / 2))

		-- Menu buttons
		local menuRow = P.frame(bar, {
			name = "MenuBar",
			size = UDim2.fromOffset(250, h),
			pos = UDim2.fromOffset(34, 0),
			zIndex = 32,
		})
		P.list(menuRow, Enum.FillDirection.Horizontal, 2, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

		local MENUS = {
			{
				label = "File",
				items = function()
					return {
						{ label = "New Untitled File", shortcut = "Ctrl+N", onClick = function() commands.run("file.newUntitled") end },
						{ label = "New Disk File...", shortcut = "Alt+N", onClick = function() commands.run("file.newDiskFile") end },
						{ label = "New Folder...", onClick = function() commands.run("file.newFolder") end },
						{ separator = true },
						{ label = "Open Workspace...", onClick = function() commands.run("workspace.switch") end },
						{ label = "Mount Executor Folder...", onClick = function() commands.run("workspace.mountRaw") end },
						{ separator = true },
						{ label = "Save", shortcut = "Ctrl+S", onClick = function() commands.run("file.save") end },
						{ label = "Save All to Disk", shortcut = "Ctrl+Shift+S", onClick = function() commands.run("file.saveAll") end },
						{ label = "Reload from Local Disk", onClick = function() commands.run("file.reloadDisk") end },
					}
				end,
			},
			{
				label = "Edit",
				items = function()
					return {
						{ label = "Undo", shortcut = "Ctrl+Z", onClick = function() commands.run("edit.undo") end },
						{ label = "Redo", shortcut = "Ctrl+Y", onClick = function() commands.run("edit.redo") end },
						{ label = "Clipboard History (15 Slots)...", shortcut = "Ctrl+Shift+V", onClick = function() commands.run("edit.clipboardHistory") end },
						{ separator = true },
						{ label = "Toggle Line Comment", shortcut = "Ctrl+/", onClick = function() commands.run("editor.toggleComment") end },
						{ label = "Duplicate Line Down", shortcut = "Shift+Alt+Down", onClick = function() commands.run("editor.duplicateLineDown") end },
						{ label = "Move Line Up", shortcut = "Alt+Up", onClick = function() commands.run("editor.moveLineUp") end },
						{ label = "Move Line Down", shortcut = "Alt+Down", onClick = function() commands.run("editor.moveLineDown") end },
						{ label = "Delete Line", shortcut = "Ctrl+Shift+K", onClick = function() commands.run("editor.deleteLine") end },
						{ separator = true },
						{ label = "Find in File", shortcut = "Ctrl+F", onClick = function() commands.run("edit.find") end },
						{ label = "Replace in File", shortcut = "Ctrl+H", onClick = function() commands.run("edit.replace") end },
						{ label = "Find in Workspace", shortcut = "Ctrl+Shift+F", onClick = function() commands.run("view.search") end },
						{ separator = true },
						{ label = "Format Document", shortcut = "Shift+Alt+F", onClick = function() commands.run("edit.format") end },
					}
				end,
			},
			{
				label = "View",
				items = function()
					local viewItems = {
						{ label = "Command Palette...", shortcut = "Ctrl+Shift+P", onClick = function() commands.run("workbench.commandPalette") end },
						{ label = "Quick Open File...", shortcut = "Ctrl+P", onClick = function() commands.run("workbench.quickOpen") end },
					}
					local curDoc = codeStore.active()
					if curDoc and languages.isPreviewable(curDoc) then
						viewItems[#viewItems + 1] = {
							label = "◫ Open Preview to the Side",
							onClick = function() commands.run("preview.openToSide") end,
						}
					end
					local tail = {
						{ separator = true },
						{ label = "📱 Toggle Acode Mobile Mode", onClick = function() commands.run("workbench.toggleMobileMode") end },
						{ label = "🎮 Toggle Play-While-Coding Dock", onClick = function() commands.run("mobile.togglePlayWhileCoding") end },
						{ label = "Toggle Zen Mode", shortcut = "Ctrl+Shift+Z", onClick = function() commands.run("workbench.toggleZenMode") end },
						{ label = "Ghost Opacity: 100% (Solid)", onClick = function() if callbacks.onSetOpacity then callbacks.onSetOpacity(1.0) end end },
						{ label = "Ghost Opacity: 70% (Peek)", onClick = function() if callbacks.onSetOpacity then callbacks.onSetOpacity(0.70) end end },
						{ label = "Ghost Opacity: 45% (Ghost)", onClick = function() if callbacks.onSetOpacity then callbacks.onSetOpacity(0.45) end end },
						{ separator = true },
						{ label = "Explorer", shortcut = "Ctrl+Shift+E", onClick = function() commands.run("view.explorer") end },
						{ label = "Source Control (GitHub)", shortcut = "Ctrl+Shift+G", onClick = function() commands.run("view.scm") end },
						{ label = "Workspace TODOs & FIXMEs", shortcut = "Ctrl+Shift+M", onClick = function() commands.run("view.todos") end },
						{ label = "Extensions & Languages", shortcut = "Ctrl+Shift+X", onClick = function() commands.run("view.extensions") end },
						{ separator = true },
						{ label = "Toggle Primary Side Bar", shortcut = "Ctrl+B", onClick = function() commands.run("view.toggleSidebar") end },
						{ label = "Toggle Terminal Panel", shortcut = "Ctrl+J", onClick = function() commands.run("view.togglePanel") end },
						{ label = "Split Editor Right", shortcut = "Ctrl+\\", onClick = function() commands.run("view.splitEditor") end },
						{ label = "Toggle Minimap", onClick = function() commands.run("view.toggleMinimap") end },
						{ label = "Capture Toggle Hotkey...", onClick = function() commands.run("workbench.changeToggleKey") end },
						{ label = "Reset Auto Window Size", onClick = function() commands.run("window.resetSize") end },
					}
					for _, tItem in ipairs(tail) do viewItems[#viewItems + 1] = tItem end
					return viewItems
				end,
			},
			{
				label = "Run",
				items = function()
					return {
						{ label = "Run Active Luau Script", shortcut = "F5", onClick = function() commands.run("run.active") end },
						{ label = "Stop Running Tasks", onClick = function() commands.run("run.stop") end },
						{ separator = true },
						{ label = "Bundle Workspace -> Single .lua", shortcut = "Ctrl+Shift+B", onClick = function() commands.run("workspace.bundle") end },
						{ label = "🎯 Pick 3D / GUI Instance Path", onClick = function() commands.run("roblox.pickInstance") end },
						{ label = "Live Roblox LogService Console", onClick = function() commands.run("roblox.showConsole") end },
						{ label = "New Terminal Session", onClick = function() commands.run("terminal.newSession") end },
						{ separator = true },
						{ label = "Open Run & Debug View", shortcut = "Ctrl+Shift+D", onClick = function() commands.run("view.debug") end },
					}
				end,
			},
			{
				label = "GitHub",
				items = function()
					return {
						{ label = "Clone / Load GitHub Repository...", onClick = function() commands.run("github.clone") end },
						{ label = "Set Personal Access Token (PAT)...", onClick = function() commands.run("github.auth") end },
						{ separator = true },
						{ label = "Switch / Create Branch...", onClick = function() commands.run("github.switchBranch") end },
						{ label = "Pull Latest from GitHub", onClick = function() commands.run("github.pull") end },
						{ label = "Commit & Push Changes...", onClick = function() commands.run("github.push") end },
						{ separator = true },
						{ label = "⬇ Import GitHub Gist...", onClick = function() commands.run("github.importGist") end },
						{ label = "⬆ Publish Secret GitHub Gist", onClick = function() commands.run("github.publishGist") end },
						{ label = "Load Raw URL...", onClick = function() commands.run("github.loadUrl") end },
					}
				end,
			},
		}

		local menuButtons = {}
		for idx, menuSpec in ipairs(MENUS) do
			local btn = P.button(menuRow, {
				name = "Menu_" .. menuSpec.label,
				size = UDim2.fromOffset(#menuSpec.label * 7 + 14, 24),
				text = menuSpec.label,
				textSize = 12,
				color = theme.color.titleBarText,
				radius = 4,
				order = idx,
				zIndex = 33,
			})
			btn.Activated:Connect(function()
				local pos = btn.AbsolutePosition
				overlay.dropdown(pos.X, pos.Y + btn.AbsoluteSize.Y + 2, menuSpec.items(), 246)
			end)
			menuButtons[#menuButtons + 1] = btn
		end

		-- Centered VS Code Command Center pill
		local centerPill = P.button(bar, {
			name = "CommandCenterPill",
			size = UDim2.fromOffset(252, 22),
			pos = UDim2.new(0.47, 0, 0.5, 0),
			anchor = Vector2.new(0.5, 0.5),
			bg = theme.color.inputBg,
			hoverBg = theme.color.hover,
			text = "",
			radius = 5,
			border = theme.color.inputBorder,
			zIndex = 33,
			onClick = function()
				commands.run("workbench.quickOpen")
			end,
		})
		centerPill.AnchorPoint = Vector2.new(0.5, 0.5)

		local centerText = P.label(centerPill, {
			name = "CommandCenterLabel",
			size = UDim2.fromScale(1, 1),
			text = "⌕  VS-RBLX — Search files (Ctrl+P)",
			textSize = 11,
			color = theme.color.muted,
			alignX = Enum.TextXAlignment.Center,
			truncate = true,
			zIndex = 34,
		})

		-- Right side Ghost-Coding Opacity Slider, Mobile Mode, Layout Toggles, Zen Mode & Window Controls
		local rightCluster = P.frame(bar, {
			name = "RightControls",
			size = UDim2.fromOffset(328, h),
			pos = UDim2.new(1, -328, 0, 0),
			zIndex = 33,
		})
		P.list(rightCluster, Enum.FillDirection.Horizontal, 2, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

		local mobileToggleBtn = P.button(rightCluster, {
			name = "MobileModeBtn",
			size = UDim2.fromOffset(28, 22),
			hoverBg = theme.color.hover,
			text = "📱",
			textSize = 12,
			radius = 4,
			order = 0,
			zIndex = 34,
			onClick = function()
				commands.run("workbench.toggleMobileMode")
			end,
		})

		-- Interactive Ghost-Coding Opacity Pill (`30%–100%` drag scrub + click presets)
		local curOpacity = util.clamp(tonumber(config.get("window.opacity", 1.0)) or 1.0, 0.30, 1.0)
		local opacityBtn = P.button(rightCluster, {
			name = "OpacitySliderPill",
			size = UDim2.fromOffset(62, 22),
			bg = theme.color.inputBg,
			hoverBg = theme.color.hover,
			text = "",
			radius = 4,
			border = theme.color.inputBorder,
			order = 1,
			zIndex = 34,
		})
		local opacityFill = P.frame(opacityBtn, {
			name = "OpacityFill",
			size = UDim2.new((curOpacity - 0.30) / 0.70, 0, 0, 3),
			pos = UDim2.new(0, 0, 1, -3),
			bg = theme.color.accent,
			radius = 2,
			zIndex = 35,
		})
		local opacityIconSlot = P.frame(opacityBtn, {
			size = UDim2.fromOffset(14, 14),
			pos = UDim2.fromOffset(5, 4),
			zIndex = 35,
		})
		icons.codicon(opacityIconSlot, "opacity", 13, theme.color.titleBarText, 36)
		local opacityLbl = P.label(opacityBtn, {
			name = "OpacityLabel",
			size = UDim2.new(1, -21, 1, -2),
			pos = UDim2.fromOffset(20, 0),
			text = string.format("%d%%", math.floor(curOpacity * 100 + 0.5)),
			mono = true,
			bold = true,
			textSize = 10,
			color = theme.color.titleBarText,
			alignX = Enum.TextXAlignment.Center,
			zIndex = 36,
		})

		local function refreshOpacityUi(alpha)
			curOpacity = util.clamp(tonumber(alpha) or 1.0, 0.30, 1.0)
			opacityLbl.Text = string.format("%d%%", math.floor(curOpacity * 100 + 0.5))
			opacityFill.Size = UDim2.new(util.clamp((curOpacity - 0.30) / 0.70, 0, 1), 0, 0, 3)
			opacityFill.BackgroundColor3 = curOpacity < 0.99 and theme.color.good or theme.color.accent
		end

		local scrubbingOpacity = false
		local didScrubMove = false
		local scrubStartX = 0

		local function applyScrubAt(screenX)
			local absX = opacityBtn.AbsolutePosition.X
			local absW = math.max(1, opacityBtn.AbsoluteSize.X)
			local ratio = util.clamp((screenX - absX) / absW, 0, 1)
			local nextAlpha = 0.30 + ratio * 0.70
			refreshOpacityUi(nextAlpha)
			if callbacks.onSetOpacity then
				callbacks.onSetOpacity(nextAlpha)
			end
		end

		opacityBtn.InputBegan:Connect(function(input)
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
				scrubbingOpacity = true
				didScrubMove = false
				scrubStartX = input.Position.X
			end
		end)

		if env.uis then
			dispose.connection(env.uis.InputChanged:Connect(function(input)
				if not scrubbingOpacity then return end
				local kind = input.UserInputType
				if kind ~= Enum.UserInputType.MouseMovement and kind ~= Enum.UserInputType.Touch then return end
				if math.abs(input.Position.X - scrubStartX) >= 3 then
					didScrubMove = true
					applyScrubAt(input.Position.X)
				end
			end))
			dispose.connection(env.uis.InputEnded:Connect(function(input)
				if not scrubbingOpacity then return end
				local kind = input.UserInputType
				if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
					scrubbingOpacity = false
				end
			end))
		end

		opacityBtn.Activated:Connect(function()
			if didScrubMove then
				didScrubMove = false
				return
			end
			local p = opacityBtn.AbsolutePosition
			local presets = {
				{ label = "100% — Solid Window", shortcut = "Default", onClick = function() if callbacks.onSetOpacity then callbacks.onSetOpacity(1.0) end end },
				{ label = "85% — Subtle Peek", onClick = function() if callbacks.onSetOpacity then callbacks.onSetOpacity(0.85) end end },
				{ label = "70% — Translucent", onClick = function() if callbacks.onSetOpacity then callbacks.onSetOpacity(0.70) end end },
				{ label = "50% — Ghost Coding", onClick = function() if callbacks.onSetOpacity then callbacks.onSetOpacity(0.50) end end },
				{ label = "30% — Ultra Ghost", onClick = function() if callbacks.onSetOpacity then callbacks.onSetOpacity(0.30) end end },
			}
			overlay.dropdown(math.max(8, p.X - 70), p.Y + opacityBtn.AbsoluteSize.Y + 4, presets, 196)
		end)

		local iconBtnSpecs = {}
		local function makeIconBtn(name, iconName, order, hoverCol, onClick)
			local b = P.button(rightCluster, {
				name = name,
				size = UDim2.fromOffset(28, h),
				hoverBg = hoverCol or theme.color.hover,
				text = "",
				order = order,
				zIndex = 34,
				onClick = onClick,
			})
			local holder = P.frame(b, {
				size = UDim2.fromOffset(16, 16),
				pos = UDim2.fromOffset(6, math.floor((h - 16) / 2)),
				zIndex = 35,
			})
			icons.codicon(holder, iconName, 16, theme.color.titleBarText, 35)
			iconBtnSpecs[#iconBtnSpecs + 1] = { holder = holder, iconName = iconName }
			return b
		end

		makeIconBtn("ZenModeBtn", "zen", 2, nil, function() commands.run("workbench.toggleZenMode") end)
		makeIconBtn("ToggleSidebarBtn", "sidebar", 3, nil, function() commands.run("view.toggleSidebar") end)
		makeIconBtn("TogglePanelBtn", "panel", 4, nil, function() commands.run("view.togglePanel") end)
		makeIconBtn("SplitEditorBtn", "split", 5, nil, function() commands.run("view.splitEditor") end)
		makeIconBtn("MinimizeWindowBtn", "minimize", 6, nil, function()
			if callbacks.onMinimize then callbacks.onMinimize() end
		end)
		makeIconBtn("MaximizeWindowBtn", "maximize", 7, nil, function()
			if callbacks.onMaximize then callbacks.onMaximize() end
		end)
		makeIconBtn("CloseWindowBtn", "close", 8, Color3.fromRGB(232, 17, 35), function()
			if callbacks.onClose then callbacks.onClose() end
		end)

		local function refreshTitle()
			local doc = codeStore.active()
			local filePart = doc and doc.title or "Welcome"
			local zenPrefix = config.get("workbench.zenMode", false) and "✦ ZEN  •  " or "⌕  "
			centerText.Text = string.format("%s%s — %s  (Ctrl+P)", zenPrefix, workspaceFs.activeName, filePart)
		end

		config.changed:connect(function(key, val)
			if key == "window.opacity" or key == "*" then
				refreshOpacityUi(config.get("window.opacity", 1.0))
			end
			if key == "workbench.zenMode" or key == "*" then
				refreshTitle()
			end
		end)
		codeStore.changed:connect(refreshTitle)
		workspaceFs.changed:connect(refreshTitle)
		theme.changed:connect(function()
			bar.BackgroundColor3 = theme.color.titleBar
			bottomBorder.BackgroundColor3 = theme.color.border
			centerPill.BackgroundColor3 = theme.color.inputBg
			centerText.TextColor3 = theme.color.muted
			opacityBtn.BackgroundColor3 = theme.color.inputBg
			opacityLbl.TextColor3 = theme.color.titleBarText
			opacityIconSlot:ClearAllChildren()
			icons.codicon(opacityIconSlot, "opacity", 13, theme.color.titleBarText, 36)
			for _, spec in ipairs(iconBtnSpecs) do
				spec.holder:ClearAllChildren()
				icons.codicon(spec.holder, spec.iconName, 16, theme.color.titleBarText, 35)
			end
			for _, b in ipairs(menuButtons) do
				b.TextColor3 = theme.color.titleBarText
			end
			refreshOpacityUi(curOpacity)
		end)

		refreshOpacityUi(curOpacity)
		refreshTitle()
		return {
			root = bar,
			drawerButton = drawerBtn,
			mobileButton = mobileToggleBtn,
			opacityButton = opacityBtn,
			refresh = refreshTitle,
			refreshOpacity = refreshOpacityUi,
			setMobileMode = function(flag)
				mobileMode = flag == true
				h = mobileMode and 38 or theme.sizes.titleBar
				bar.Size = UDim2.new(1, 0, 0, h)
				drawerBtn.Visible = mobileMode
				drawerBtn.Size = UDim2.fromOffset(34, h - 2)
				logo.Visible = not mobileMode
				menuRow.Position = UDim2.fromOffset(mobileMode and 40 or 34, 0)
				menuRow.Size = UDim2.fromOffset(250, h)
				menuRow.Visible = not mobileMode
				mobileToggleBtn.BackgroundColor3 = mobileMode and theme.color.accent or theme.color.titleBar
				mobileToggleBtn.BackgroundTransparency = mobileMode and 0 or 1
			end,
		}
	end

	return M
end
