-- Authentic VS Code Title Bar: Brand Logo, Top Menu Bar (`File`, `Edit`, `View`,
-- `Run`, `GitHub`, `Help`), Centered Command Center Search Pill (`Ctrl+P`),
-- Layout Toggle Icons (Sidebar, Panel, Split), and Window Controls (─, □, ✕).
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local brand = env.require("ui/brand")
	local icons = env.require("ui/icons")
	local overlay = env.require("ui/overlay")
	local commands = env.require("runtime/command_catalog")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")

	local M = {}

	function M.new(parent, callbacks)
		callbacks = callbacks or {}
		local h = theme.sizes.titleBar

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

		local logo = brand.draw(bar, 16, 32)
		logo.Position = UDim2.fromOffset(10, math.floor((h - 16) / 2))

		-- Menu buttons
		local menuRow = P.frame(bar, {
			name = "MenuBar",
			size = UDim2.fromOffset(290, h),
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
					return {
						{ label = "Command Palette...", shortcut = "Ctrl+Shift+P", onClick = function() commands.run("workbench.commandPalette") end },
						{ label = "Quick Open File...", shortcut = "Ctrl+P", onClick = function() commands.run("workbench.quickOpen") end },
						{ separator = true },
						{ label = "Explorer", shortcut = "Ctrl+Shift+E", onClick = function() commands.run("view.explorer") end },
						{ label = "Source Control (GitHub)", shortcut = "Ctrl+Shift+G", onClick = function() commands.run("view.scm") end },
						{ label = "Extensions & Languages", shortcut = "Ctrl+Shift+X", onClick = function() commands.run("view.extensions") end },
						{ separator = true },
						{ label = "Toggle Primary Side Bar", shortcut = "Ctrl+B", onClick = function() commands.run("view.toggleSidebar") end },
						{ label = "Toggle Terminal Panel", shortcut = "Ctrl+J", onClick = function() commands.run("view.togglePanel") end },
						{ label = "Split Editor Right", shortcut = "Ctrl+\\", onClick = function() commands.run("view.splitEditor") end },
						{ label = "Toggle Minimap", onClick = function() commands.run("view.toggleMinimap") end },
						{ label = "Reset Auto Window Size", onClick = function() commands.run("window.resetSize") end },
					}
				end,
			},
			{
				label = "Run",
				items = function()
					return {
						{ label = "Run Active Luau Script", shortcut = "F5", onClick = function() commands.run("run.active") end },
						{ label = "Stop Running Tasks", onClick = function() commands.run("run.stop") end },
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
						{ label = "Pull Latest from GitHub", onClick = function() commands.run("github.pull") end },
						{ label = "Commit & Push Changes...", onClick = function() commands.run("github.push") end },
						{ label = "Create Branch...", onClick = function() commands.run("github.createBranch") end },
						{ label = "Load Raw URL / Gist...", onClick = function() commands.run("github.loadUrl") end },
					}
				end,
			},
		}

		local menuButtons = {}
		for idx, menuSpec in ipairs(MENUS) do
			local btn = P.button(menuRow, {
				name = "Menu_" .. menuSpec.label,
				size = UDim2.fromOffset(#menuSpec.label * 7 + 16, 24),
				text = menuSpec.label,
				textSize = 12,
				color = theme.color.titleBarText,
				radius = 4,
				order = idx,
				zIndex = 33,
			})
			btn.Activated:Connect(function()
				local pos = btn.AbsolutePosition
				overlay.dropdown(pos.X, pos.Y + btn.AbsoluteSize.Y + 2, menuSpec.items(), 240)
			end)
			menuButtons[#menuButtons + 1] = btn
		end

		-- Centered VS Code Command Center pill
		local centerPill = P.button(bar, {
			name = "CommandCenterPill",
			size = UDim2.fromOffset(290, 22),
			pos = UDim2.new(0.5, 0, 0.5, 0),
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
			text = "⌕  VS-RBLX — Search files (Ctrl+P) or > commands",
			textSize = 11,
			color = theme.color.muted,
			alignX = Enum.TextXAlignment.Center,
			truncate = true,
			zIndex = 34,
		})

		-- Right side layout & window controls
		local rightCluster = P.frame(bar, {
			name = "RightControls",
			size = UDim2.fromOffset(204, h),
			pos = UDim2.new(1, -204, 0, 0),
			zIndex = 33,
		})
		P.list(rightCluster, Enum.FillDirection.Horizontal, 2, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

		local function makeIconBtn(name, iconName, order, hoverCol, onClick)
			local b = P.button(rightCluster, {
				name = name,
				size = UDim2.fromOffset(30, h),
				hoverBg = hoverCol or theme.color.hover,
				text = "",
				order = order,
				zIndex = 34,
				onClick = onClick,
			})
			local ic = icons.codicon(b, iconName, 16, theme.color.titleBarText, 35)
			ic.Position = UDim2.fromOffset(7, math.floor((h - 16) / 2))
			return b
		end

		makeIconBtn("ToggleSidebarBtn", "sidebar", 1, nil, function() commands.run("view.toggleSidebar") end)
		makeIconBtn("TogglePanelBtn", "panel", 2, nil, function() commands.run("view.togglePanel") end)
		makeIconBtn("SplitEditorBtn", "split", 3, nil, function() commands.run("view.splitEditor") end)
		makeIconBtn("MinimizeWindowBtn", "minimize", 4, nil, function()
			if callbacks.onMinimize then callbacks.onMinimize() end
		end)
		makeIconBtn("MaximizeWindowBtn", "maximize", 5, nil, function()
			if callbacks.onMaximize then callbacks.onMaximize() end
		end)
		makeIconBtn("CloseWindowBtn", "close", 6, Color3.fromRGB(232, 17, 35), function()
			if callbacks.onClose then callbacks.onClose() end
		end)

		local function refreshTitle()
			local doc = codeStore.active()
			local filePart = doc and doc.title or "Welcome"
			centerText.Text = string.format("⌕  %s — %s  (Ctrl+P)", workspaceFs.activeName, filePart)
		end

		codeStore.changed:connect(refreshTitle)
		workspaceFs.changed:connect(refreshTitle)
		theme.changed:connect(function()
			bar.BackgroundColor3 = theme.color.titleBar
			bottomBorder.BackgroundColor3 = theme.color.border
			centerPill.BackgroundColor3 = theme.color.inputBg
			centerText.TextColor3 = theme.color.muted
			for _, b in ipairs(menuButtons) do
				b.TextColor3 = theme.color.titleBarText
			end
		end)

		refreshTitle()
		return {
			root = bar,
			refresh = refreshTitle,
		}
	end

	return M
end
