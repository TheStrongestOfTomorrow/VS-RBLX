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
	local cryptoVault = env.require("runtime/crypto_vault")

	local M = {}

	function M.new(parent, callbacks)
		callbacks = callbacks or {}
		local h = theme.sizes.titleBar
		local mobileMode = false
		local compactTouchMode = false

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
						{ label = "✦ Toggle Integrated AI Sidebar", shortcut = "Ctrl+Alt+I", onClick = function() commands.run("ai.toggleChat") end },
						{ label = "✦ Inline AI Code Edit...", shortcut = "Ctrl+I", onClick = function() commands.run("ai.inlineEdit") end },
						{ label = "⤢ Toggle Resize Mode (ON/OFF)", onClick = function() commands.run("window.toggleResizeMode") end },
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
						{ label = "🔐 Master Vault (Encrypt / Unlock / Lock)...", onClick = function() commands.run("vault.open") end },
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

		-- Compact `≡ Menu` button for narrow Desktop windows / Phones in Desktop Mode (prevents overlap!)
		local compactMenuBtn = P.button(bar, {
			name = "CompactMenuBtn",
			size = UDim2.fromOffset(48, 22),
			pos = UDim2.fromOffset(32, 5),
			hoverBg = theme.color.hover,
			text = "≡ Menu",
			bold = true,
			textSize = 11,
			color = theme.color.titleBarText,
			radius = 4,
			visible = false,
			zIndex = 34,
			onClick = function()
				local topItems = {}
				for _, mSpec in ipairs(MENUS) do
					topItems[#topItems + 1] = {
						label = "▸  " .. mSpec.label .. " ...",
						onClick = function()
							local p = bar.AbsolutePosition
							overlay.dropdown(p.X + 32, p.Y + h + 2, mSpec.items(), 246)
						end,
					}
				end
				local p = bar.AbsolutePosition
				overlay.dropdown(p.X + 28, p.Y + h + 2, topItems, 180)
			end,
		})

		-- Centered VS Code Command Center pill (collapses cleanly to icon on narrow phones!)
		local centerPill = P.button(bar, {
			name = "CommandCenterPill",
			size = UDim2.fromOffset(230, 22),
			pos = UDim2.new(0.46, 0, 0.5, 0),
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

		-- Right side: Vault (`🔐`), Mobile Mode (`📱`), Explicit Resize Toggle (`⤢`), Opacity, Layout & Window Controls
		local rightCluster = P.frame(bar, {
			name = "RightControls",
			size = UDim2.fromOffset(392, h),
			pos = UDim2.new(1, -392, 0, 0),
			zIndex = 33,
		})
		P.list(rightCluster, Enum.FillDirection.Horizontal, 2, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

		local aiChatBtn = P.button(rightCluster, {
			name = "AiChatBtn",
			size = UDim2.fromOffset(32, 22),
			hoverBg = theme.color.hover,
			text = "✦ AI",
			bold = true,
			textSize = 10,
			color = theme.color.titleBarText,
			radius = 4,
			order = -3,
			zIndex = 34,
			onClick = function()
				commands.run("ai.toggleChat")
			end,
		})

		local vaultBtn = P.button(rightCluster, {
			name = "VaultBtn",
			size = UDim2.fromOffset(26, 22),
			hoverBg = theme.color.hover,
			text = "🔐",
			textSize = 12,
			radius = 4,
			order = -2,
			zIndex = 34,
			onClick = function()
				commands.run("vault.open")
			end,
		})

		local resizeActive = false
		local resizeModeBtn = P.button(rightCluster, {
			name = "ResizeModeBtn",
			size = UDim2.fromOffset(30, 22),
			hoverBg = theme.color.hover,
			text = "⤢",
			bold = true,
			textSize = 13,
			color = theme.color.titleBarText,
			radius = 4,
			order = -1,
			zIndex = 34,
			onClick = function()
				if callbacks.onToggleResizeMode then
					callbacks.onToggleResizeMode()
				else
					commands.run("window.toggleResizeMode")
				end
			end,
		})

		local function refreshVaultBtn()
			if not cryptoVault.isEncrypted() then
				vaultBtn.Text = "🔐"
				vaultBtn.BackgroundTransparency = 1
			elseif cryptoVault.isUnlocked() then
				vaultBtn.Text = "🔓"
				vaultBtn.BackgroundColor3 = theme.color.good
				vaultBtn.BackgroundTransparency = 0.78
			else
				vaultBtn.Text = "🔒"
				vaultBtn.BackgroundColor3 = theme.color.warn
				vaultBtn.BackgroundTransparency = 0.72
			end
		end
		cryptoVault.changed:connect(refreshVaultBtn)

		local function refreshResizeBtn(flag)
			resizeActive = flag == true
			resizeModeBtn.Text = resizeActive and "⤢•" or "⤢"
			resizeModeBtn.BackgroundColor3 = resizeActive and theme.color.accent or theme.color.titleBar
			resizeModeBtn.BackgroundTransparency = resizeActive and 0 or 1
			resizeModeBtn.TextColor3 = resizeActive and Color3.fromRGB(255, 255, 255) or theme.color.titleBarText
		end

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

		local zenBtn = makeIconBtn("ZenModeBtn", "zen", 2, nil, function() commands.run("workbench.toggleZenMode") end)
		local toggleSidebarBtn = makeIconBtn("ToggleSidebarBtn", "sidebar", 3, nil, function() commands.run("view.toggleSidebar") end)
		local togglePanelBtn = makeIconBtn("TogglePanelBtn", "panel", 4, nil, function() commands.run("view.togglePanel") end)
		local splitEditorBtn = makeIconBtn("SplitEditorBtn", "split", 5, nil, function() commands.run("view.splitEditor") end)

		-- Compact `⋯` Overflow Button for narrow windows / phones so RightControls NEVER collide with Menu or Search!
		local compactMoreBtn = P.button(rightCluster, {
			name = "CompactMoreBtn",
			size = UDim2.fromOffset(26, 22),
			hoverBg = theme.color.hover,
			text = "⋯",
			bold = true,
			textSize = 13,
			color = theme.color.titleBarText,
			radius = 4,
			visible = false,
			order = 5,
			zIndex = 34,
			onClick = function()
				local p = rightCluster.AbsolutePosition
				local items = {
					{ label = "⌕ Command Palette...", shortcut = "Ctrl+Shift+P", onClick = function() commands.run("workbench.commandPalette") end },
					{ label = string.format("◑ Window Opacity (%d%%)...", math.floor(curOpacity * 100 + 0.5)), onClick = function()
						local presets = {
							{ label = "100% — Solid", onClick = function() if callbacks.onSetOpacity then callbacks.onSetOpacity(1.0) end end },
							{ label = "85% — Subtle Peek", onClick = function() if callbacks.onSetOpacity then callbacks.onSetOpacity(0.85) end end },
							{ label = "70% — Translucent", onClick = function() if callbacks.onSetOpacity then callbacks.onSetOpacity(0.70) end end },
							{ label = "50% — Ghost Coding", onClick = function() if callbacks.onSetOpacity then callbacks.onSetOpacity(0.50) end end },
						}
						overlay.dropdown(p.X, p.Y + h + 2, presets, 190)
					end },
					{ separator = true },
					{ label = "Toggle Primary Sidebar", shortcut = "Ctrl+B", onClick = function() commands.run("view.toggleSidebar") end },
					{ label = "Toggle Bottom Panel", shortcut = "Ctrl+J", onClick = function() commands.run("view.togglePanel") end },
					{ label = "Split Editor Right", shortcut = "Ctrl+\\", onClick = function() commands.run("view.splitEditor") end },
					{ label = "🎮 Toggle Play While Coding", onClick = function() commands.run("mobile.togglePlayWhileCoding") end },
					{ label = "✦ Toggle Zen Mode", onClick = function() commands.run("workbench.toggleZenMode") end },
					{ separator = true },
					{ label = "✦ Toggle Integrated AI Sidebar", shortcut = "Ctrl+Alt+I", onClick = function() commands.run("ai.toggleChat") end },
					{ label = "✦ Inline AI Code Edit...", shortcut = "Ctrl+I", onClick = function() commands.run("ai.inlineEdit") end },
					{ label = "🔐 Zero-Knowledge Master Vault...", onClick = function() commands.run("vault.open") end },
				}
				overlay.dropdown(p.X, p.Y + h + 2, items, 230)
			end,
		})

		makeIconBtn("MinimizeWindowBtn", "minimize", 6, nil, function()
			if callbacks.onMinimize then callbacks.onMinimize() end
		end)
		makeIconBtn("MaximizeWindowBtn", "maximize", 7, nil, function()
			if callbacks.onMaximize then callbacks.onMaximize() end
		end)
		makeIconBtn("CloseWindowBtn", "close", 8, Color3.fromRGB(232, 17, 35), function()
			if callbacks.onClose then callbacks.onClose() end
		end)

		local currentBarWidth = 980
		local isCompactWidth = false
		local isUltraCompact = false

		local function refreshTitle()
			local doc = codeStore.active()
			local filePart = doc and doc.title or "Welcome"
			if isUltraCompact then
				centerText.Text = "⌕"
			elseif isCompactWidth then
				centerText.Text = "⌕  " .. filePart
			else
				local zenPrefix = config.get("workbench.zenMode", false) and "✦ ZEN  •  " or "⌕  "
				centerText.Text = string.format("%s%s — %s  (Ctrl+P)", zenPrefix, workspaceFs.activeName, filePart)
			end
		end

		-- Width-Aware Zero-Overlap Reflow (`>= 880px` full, `560–879px` compact menu + overflow, `< 560px` phone-safe!)
		local function reflowForWidth(barW)
			currentBarWidth = tonumber(barW) or bar.AbsoluteSize.X
			if currentBarWidth <= 0 then currentBarWidth = 980 end

			isCompactWidth = (currentBarWidth < 880) or mobileMode
			isUltraCompact = currentBarWidth < 540

			drawerBtn.Visible = mobileMode or compactTouchMode
			drawerBtn.Size = UDim2.fromOffset(compactTouchMode and 36 or 34, h - 2)
			logo.Visible = (not mobileMode) and (not isUltraCompact) and (not compactTouchMode)

			-- Left Menu Bar vs Compact `≡ Menu`
			if mobileMode then
				menuRow.Visible = false
				compactMenuBtn.Visible = false
			elseif isCompactWidth then
				menuRow.Visible = false
				compactMenuBtn.Visible = true
				local menuX = compactTouchMode and 42 or (isUltraCompact and 6 or 30)
				compactMenuBtn.Position = UDim2.fromOffset(menuX, math.floor((h - 22) * 0.5))
			else
				menuRow.Visible = true
				menuRow.Position = UDim2.fromOffset(34, 0)
				menuRow.Size = UDim2.fromOffset(250, h)
				compactMenuBtn.Visible = false
			end

			-- Secondary Right Toggles vs `⋯` Overflow
			local showFullRight = (currentBarWidth >= 780) and (not mobileMode)
			opacityBtn.Visible = (currentBarWidth >= 660) and (not isUltraCompact)
			zenBtn.Visible = showFullRight
			toggleSidebarBtn.Visible = showFullRight
			togglePanelBtn.Visible = showFullRight
			splitEditorBtn.Visible = showFullRight
			compactMoreBtn.Visible = not showFullRight
			vaultBtn.Visible = not isUltraCompact

			local rightW
			if showFullRight then
				rightW = 418
			elseif opacityBtn.Visible then
				rightW = 310
			elseif isUltraCompact then
				rightW = 214
			else
				rightW = 244
			end
			rightCluster.Size = UDim2.fromOffset(rightW, h)
			rightCluster.Position = UDim2.new(1, -rightW, 0, 0)

			-- Left occupied width & Center Search Pill exact non-overlapping slot
			local leftOccupied = mobileMode and 42 or (compactTouchMode and 98 or (isCompactWidth and (isUltraCompact and 58 or 84) or 288))
			local availCenter = currentBarWidth - leftOccupied - rightW - 12
			if availCenter < 30 then
				centerPill.Visible = false
			else
				centerPill.Visible = true
				local pillW = isUltraCompact and math.min(44, availCenter) or math.min(236, availCenter)
				local centerX = leftOccupied + math.floor((availCenter + 12) * 0.5)
				centerPill.Size = UDim2.fromOffset(pillW, 22)
				centerPill.Position = UDim2.new(0, centerX, 0.5, 0)
			end
			refreshTitle()
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
			compactMenuBtn.TextColor3 = theme.color.titleBarText
			compactMoreBtn.TextColor3 = theme.color.titleBarText
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
			refreshResizeBtn(resizeActive)
			refreshVaultBtn()
		end)

		refreshOpacityUi(curOpacity)
		refreshResizeBtn(false)
		refreshVaultBtn()
		reflowForWidth(980)
		return {
			root = bar,
			drawerButton = drawerBtn,
			mobileButton = mobileToggleBtn,
			resizeButton = resizeModeBtn,
			vaultButton = vaultBtn,
			aiButton = aiChatBtn,
			opacityButton = opacityBtn,
			refresh = refreshTitle,
			refreshOpacity = refreshOpacityUi,
			setResizeMode = refreshResizeBtn,
			setAiOpen = function(flag)
				aiChatBtn.BackgroundColor3 = flag and theme.color.accent or theme.color.titleBar
				aiChatBtn.BackgroundTransparency = flag and 0 or 1
				aiChatBtn.TextColor3 = flag and Color3.fromRGB(255, 255, 255) or theme.color.titleBarText
			end,
			reflow = reflowForWidth,
			setMobileMode = function(flag)
				mobileMode = flag == true
				h = mobileMode and 38 or theme.sizes.titleBar
				bar.Size = UDim2.new(1, 0, 0, h)
				mobileToggleBtn.BackgroundColor3 = mobileMode and theme.color.accent or theme.color.titleBar
				mobileToggleBtn.BackgroundTransparency = mobileMode and 0 or 1
				reflowForWidth(currentBarWidth)
			end,
			setCompactTouchMode = function(flag)
				compactTouchMode = flag == true and not mobileMode
				reflowForWidth(currentBarWidth)
			end,
		}
	end

	return M
end
