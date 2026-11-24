-- VS-RBLX Complete VS Code Workbench Orchestrator (`src/ui/app.lua`).
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local overlay = env.require("ui/overlay")
	local bootSplash = env.require("ui/boot")
	local windowMod = env.require("ui/window")
	local titlebarMod = env.require("ui/titlebar")
	local activitybarMod = env.require("ui/activitybar")
	local statusbarMod = env.require("ui/statusbar")
	local commandPaletteMod = env.require("ui/command_palette")

	local tabsMod = env.require("ui/code/tabs")
	local breadcrumbsMod = env.require("ui/code/breadcrumbs")
	local editorMod = env.require("ui/code/editor")
	local splitterMod = env.require("ui/code/splitter")
	local terminalMod = env.require("ui/code/terminal")

	local explorerPanel = env.require("ui/panels/explorer")
	local searchPanel = env.require("ui/panels/search")
	local scmPanel = env.require("ui/panels/scm")
	local debugPanel = env.require("ui/panels/debug")
	local extensionsPanel = env.require("ui/panels/extensions")
	local settingsPanel = env.require("ui/panels/settings")
	local githubConnect = env.require("ui/panels/github_connect")

	local util = env.require("runtime/util")
	local dispose = env.require("runtime/dispose")
	local config = env.require("runtime/config")
	local bootProgress = env.require("runtime/boot_progress")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")
	local gitState = env.require("runtime/git_state")
	local commands = env.require("runtime/command_catalog")
	local shortcuts = env.require("runtime/shortcuts")
	local tools = env.require("tools/init")

	local M = {}

	local function resolveGuiHost()
		if type(env.gethui) == "function" then
			local ok, hui = pcall(env.gethui)
			if ok and hui then return hui end
		end
		if env.coreGui then
			local ok, _ = pcall(function() return env.coreGui.Name end)
			if ok then return env.coreGui end
		end
		if env.plr then
			local pg = env.plr:FindFirstChild("PlayerGui")
			if pg then return pg end
		end
		return nil
	end

	function M.mount(opts)
		opts = opts or {}
		local splash = bootSplash.show()
		if splash then splash.step("Loading workspace configuration...", 0.2) end

		config.load()
		theme.apply()

		bootProgress.update("fs", "Mounting local disk workspace (writefile / readfile)...")
		if splash then splash.step("Mounting local disk workspace...", 0.45) end
		workspaceFs.init()
		gitState.loadMeta()

		local guiParent = opts.parent or resolveGuiHost()
		local screenGui = Instance.new("ScreenGui")
		screenGui.Name = "VSRBLX_Workbench"
		screenGui.ResetOnSpawn = false
		screenGui.IgnoreGuiInset = true
		screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		if guiParent then
			pcall(function() screenGui.Parent = guiParent end)
		end
		dispose.add(function()
			pcall(function() screenGui:Destroy() end)
		end)

		overlay.mount(screenGui)

		bootProgress.update("ui", "Constructing draggable & player-resizable VS Code window...")
		if splash then splash.step("Building VS Code workbench...", 0.75) end

		local win = windowMod.new(screenGui)
		local palette = commandPaletteMod.new(screenGui)

		local TITLE_H = theme.sizes.titleBar
		local STATUS_H = theme.sizes.statusBar
		local ACT_W = theme.sizes.activityBar
		local TAB_H = theme.sizes.tabBar
		local CRUMB_H = theme.sizes.breadcrumbs

		local sideBarVisible = config.get("workbench.sideBarVisible", true) ~= false
		local sideBarWidth = util.clamp(tonumber(config.get("workbench.sideBarWidth", 250)) or 250, 170, 460)
		local panelVisible = config.get("workbench.panelVisible", true) ~= false
		local panelHeight = util.clamp(tonumber(config.get("workbench.panelHeight", 190)) or 190, 100, 420)
		local activeViewlet = tostring(config.get("workbench.activeViewlet", "explorer"))

		-- TitleBar (bound to window drag + maximize/minimize/close controls)
		local titleBar = titlebarMod.new(win.body, {
			onMinimize = function() win.minimise() end,
			onMaximize = function() win.toggleMaximise() end,
			onClose = function() win.hide() end,
		})
		win.bindDragBar(titleBar.root)

		-- StatusBar
		statusbarMod.new(win.body)

		-- Central Body Frame between TitleBar and StatusBar
		local workbenchBody = P.frame(win.body, {
			name = "WorkbenchBody",
			size = UDim2.new(1, 0, 1, -(TITLE_H + STATUS_H)),
			pos = UDim2.fromOffset(0, TITLE_H),
			bg = theme.color.editor,
			clip = true,
			zIndex = 11,
		})

		-- Primary Sidebar Container
		local sideBarFrame = P.frame(workbenchBody, {
			name = "PrimarySideBar",
			size = UDim2.new(0, sideBarWidth, 1, 0),
			pos = UDim2.fromOffset(ACT_W, 0),
			bg = theme.color.sideBar,
			clip = true,
			zIndex = 20,
		})
		local sideRightBorder = P.frame(sideBarFrame, {
			size = UDim2.new(0, 1, 1, 0),
			pos = UDim2.new(1, -1, 0, 0),
			bg = theme.color.border,
			zIndex = 25,
		})

		-- Viewlets inside Primary Sidebar
		local viewlets = {
			explorer = explorerPanel.new(sideBarFrame),
			search = searchPanel.new(sideBarFrame),
			scm = scmPanel.new(sideBarFrame),
			debug = debugPanel.new(sideBarFrame),
			extensions = extensionsPanel.new(sideBarFrame),
			settings = settingsPanel.new(sideBarFrame),
		}

		-- Main Center Stack (Editors on top + Bottom Terminal Panel below)
		local mainArea = P.frame(workbenchBody, {
			name = "MainEditorAndPanelStack",
			bg = theme.color.editor,
			clip = true,
			zIndex = 12,
		})

		local editorsRegion = P.frame(mainArea, {
			name = "EditorsRegion",
			bg = theme.color.editor,
			clip = true,
			zIndex = 12,
		})

		-- Primary Editor Group
		local primaryGroup = P.frame(editorsRegion, {
			name = "PrimaryEditorPane",
			size = UDim2.fromScale(1, 1),
			bg = theme.color.editor,
			clip = true,
			zIndex = 12,
		})
		tabsMod.new(primaryGroup, "primary")
		breadcrumbsMod.new(primaryGroup, "primary")
		local primaryBody = P.frame(primaryGroup, {
			size = UDim2.new(1, 0, 1, -(TAB_H + CRUMB_H)),
			pos = UDim2.fromOffset(0, TAB_H + CRUMB_H),
			zIndex = 12,
		})
		local primaryEditor = editorMod.new(primaryBody, "primary")

		-- Secondary Split Editor Group (`Ctrl+\`)
		local secondaryGroup = P.frame(editorsRegion, {
			name = "SecondaryEditorPane",
			size = UDim2.new(0.5, 0, 1, 0),
			pos = UDim2.new(0.5, 0, 0, 0),
			bg = theme.color.editor,
			visible = false,
			clip = true,
			zIndex = 12,
		})
		local splitLeftRule = P.frame(secondaryGroup, {
			size = UDim2.new(0, 1, 1, 0),
			bg = theme.color.border,
			zIndex = 30,
		})
		tabsMod.new(secondaryGroup, "secondary")
		breadcrumbsMod.new(secondaryGroup, "secondary")
		local secondaryBody = P.frame(secondaryGroup, {
			size = UDim2.new(1, 0, 1, -(TAB_H + CRUMB_H)),
			pos = UDim2.fromOffset(0, TAB_H + CRUMB_H),
			zIndex = 12,
		})
		local secondaryEditor = editorMod.new(secondaryBody, "secondary")

		-- Bottom Panel (`PROBLEMS`, `OUTPUT`, `TERMINAL`, `HTTP / GIT`)
		local panelHolder = P.frame(mainArea, {
			name = "BottomPanelContainer",
			bg = theme.color.panelBg,
			clip = true,
			zIndex = 20,
		})

		local reflowWorkbench

		local bottomTerminal = terminalMod.new(panelHolder, function()
			panelVisible = false
			config.set("workbench.panelVisible", false, { quiet = true })
			reflowWorkbench()
		end)

		-- Interactive Splitters
		local sideSash = splitterMod.vertical(workbenchBody, 38, function(dx)
			sideBarWidth = util.clamp(sideBarWidth + dx, 170, 480)
			config.set("workbench.sideBarWidth", sideBarWidth, { quiet = true })
			reflowWorkbench()
		end)

		local panelSash = splitterMod.horizontal(mainArea, 38, function(dy)
			panelHeight = util.clamp(panelHeight - dy, 95, math.max(140, mainArea.AbsoluteSize.Y - 120))
			config.set("workbench.panelHeight", panelHeight, { quiet = true })
			reflowWorkbench()
		end)

		local splitRatio = 0.5
		local editorSplitSash = splitterMod.vertical(editorsRegion, 38, function(dx)
			local totalW = math.max(300, editorsRegion.AbsoluteSize.X)
			splitRatio = util.clamp(splitRatio + (dx / totalW), 0.25, 0.75)
			reflowWorkbench()
		end)

		reflowWorkbench = function()
			local effSideW = sideBarVisible and sideBarWidth or 0
			sideBarFrame.Visible = sideBarVisible
			sideBarFrame.Size = UDim2.new(0, sideBarWidth, 1, 0)
			sideSash.Visible = sideBarVisible
			sideSash.Position = UDim2.fromOffset(ACT_W + sideBarWidth - 2, 0)

			local leftOffset = ACT_W + effSideW
			mainArea.Position = UDim2.fromOffset(leftOffset, 0)
			mainArea.Size = UDim2.new(1, -leftOffset, 1, 0)

			local effPanelH = panelVisible and panelHeight or 0
			panelHolder.Visible = panelVisible
			panelHolder.Size = UDim2.new(1, 0, 0, effPanelH)
			panelHolder.Position = UDim2.new(0, 0, 1, -effPanelH)

			panelSash.Visible = panelVisible
			panelSash.Position = UDim2.new(0, 0, 1, -effPanelH - 2)

			editorsRegion.Position = UDim2.fromOffset(0, 0)
			editorsRegion.Size = UDim2.new(1, 0, 1, -effPanelH)

			if codeStore.splitOpen then
				primaryGroup.Size = UDim2.new(splitRatio, 0, 1, 0)
				secondaryGroup.Visible = true
				secondaryGroup.Position = UDim2.new(splitRatio, 0, 0, 0)
				secondaryGroup.Size = UDim2.new(1 - splitRatio, 0, 1, 0)
				editorSplitSash.Visible = true
				editorSplitSash.Position = UDim2.new(splitRatio, -2, 0, 0)
			else
				primaryGroup.Size = UDim2.fromScale(1, 1)
				secondaryGroup.Visible = false
				editorSplitSash.Visible = false
			end
		end

		local actBar
		local function selectViewlet(id, toggleIfSame)
			if toggleIfSame and sideBarVisible and activeViewlet == id then
				sideBarVisible = false
			else
				activeViewlet = id
				sideBarVisible = true
			end
			for k, v in pairs(viewlets) do
				v.root.Visible = (k == activeViewlet)
			end
			config.set("workbench.activeViewlet", activeViewlet)
			config.set("workbench.sideBarVisible", sideBarVisible)
			if actBar then actBar.refresh() end
			reflowWorkbench()
			if sideBarVisible and id == "search" and viewlets.search.focus then
				viewlets.search.focus()
			end
		end

		actBar = activitybarMod.new(workbenchBody, function(id)
			selectViewlet(id, true)
		end)

		codeStore.changed:connect(reflowWorkbench)
		win.onResize = reflowWorkbench

		local function registerCommands()
			local function reg(id, title, category, shortcut, runFn, aliases)
				commands.register({ id = id, title = title, category = category, shortcut = shortcut, run = runFn })
				for _, al in ipairs(aliases or {}) do
					commands.register({ id = al, title = title, category = category, shortcut = shortcut, run = runFn })
				end
			end

			reg("workbench.commandPalette", "Show Command Palette", "View", "Ctrl+Shift+P", function()
				palette.open(">")
			end)
			reg("workbench.quickOpen", "Quick Open Workspace File...", "File", "Ctrl+P", function()
				palette.open("")
			end)
			reg("workbench.toggleWindow", "Show / Hide VS-RBLX Window", "Window", "RightShift", function()
				win.toggle()
			end)
			reg("window.maximize", "Toggle Maximize / Restore Window", "Window", "F11", function()
				win.toggleMaximise()
			end)
			reg("window.center", "Reset Window Auto-Size & Center on Screen", "Window", nil, function()
				win.resetAutoSize()
			end, { "window.resetSize" })

			reg("workbench.toggleSideBar", "Toggle Primary Side Bar", "View", "Ctrl+B", function()
				sideBarVisible = not sideBarVisible
				config.set("workbench.sideBarVisible", sideBarVisible)
				actBar.refresh()
				reflowWorkbench()
			end, { "view.toggleSidebar" })

			reg("workbench.togglePanel", "Toggle Integrated Terminal & Panel", "View", "Ctrl+J", function()
				panelVisible = not panelVisible
				config.set("workbench.panelVisible", panelVisible)
				reflowWorkbench()
				if panelVisible then bottomTerminal.focusTerminal() end
			end, { "view.togglePanel" })

			reg("workbench.showProblems", "Focus Problems Panel", "View", nil, function()
				panelVisible = true
				bottomTerminal.selectTab("problems")
				reflowWorkbench()
			end, { "view.problems" })

			reg("workbench.viewExplorer", "Show Explorer", "View", "Ctrl+Shift+E", function()
				selectViewlet("explorer", false)
			end, { "view.explorer" })

			reg("workbench.viewSearch", "Search Across Files", "View", "Ctrl+Shift+F", function()
				selectViewlet("search", false)
			end, { "view.search" })

			reg("workbench.viewScm", "Show Source Control (GitHub)", "GitHub", "Ctrl+Shift+G", function()
				selectViewlet("scm", false)
			end, { "view.scm" })

			reg("workbench.viewDebug", "Show Run and Debug", "Run", "Ctrl+Shift+D", function()
				selectViewlet("debug", false)
			end, { "view.debug" })

			reg("workbench.viewExtensions", "Show Extensions & Languages", "View", "Ctrl+Shift+X", function()
				selectViewlet("extensions", false)
			end, { "view.extensions" })

			reg("workbench.viewSettings", "Open Settings", "Preferences", "Ctrl+,", function()
				selectViewlet("settings", false)
			end, { "view.settings" })

			reg("file.newUntitled", "New Untitled Scratch Buffer", "File", "Ctrl+N", function()
				codeStore.newUntitled("", "luau")
			end)
			reg("file.newDiskFile", "New File on Local Disk...", "File", nil, function()
				viewlets.explorer.fileTree.promptNewFile()
			end)
			reg("file.newDiskFolder", "New Folder on Local Disk...", "File", nil, function()
				viewlets.explorer.fileTree.promptNewFolder()
			end, { "file.newFolder" })

			reg("file.save", "Save Active File to Disk (writefile)", "File", "Ctrl+S", function()
				local doc = codeStore.active()
				if not doc then return end
				if doc.path == "" then
					overlay.prompt({
						title = "Save Buffer to Local Disk",
						placeholder = "scripts/new_script.luau",
						mono = true,
						confirmText = "Save",
						onConfirm = function(p)
							local ok, err = codeStore.saveAs(doc.id, p)
							if ok then overlay.toast("Saved " .. p .. " via writefile", "good", 2.5)
							else overlay.toast("Save failed: " .. tostring(err), "bad", 4) end
						end,
					})
				else
					local ok, err = codeStore.save(doc.id)
					if ok then overlay.toast("Saved " .. doc.path, "good", 2)
					else overlay.toast("Save failed: " .. tostring(err), "bad", 4) end
				end
			end)

			reg("file.saveAll", "Save All Modified Files to Disk", "File", "Ctrl+Shift+S", function()
				local n = codeStore.saveAll()
				overlay.toast(string.format("Saved %d file(s) to disk", n), "good", 2.5)
			end)

			reg("file.closeTab", "Close Active Editor Tab", "View", "Ctrl+W", function()
				local doc = codeStore.active()
				if doc then codeStore.close(doc.id) end
			end)

			reg("edit.undo", "Undo", "Edit", "Ctrl+Z", function()
				local doc = codeStore.active()
				if doc and codeStore.undo then codeStore.undo(doc.id) end
			end)
			reg("edit.redo", "Redo", "Edit", "Ctrl+Y", function()
				local doc = codeStore.active()
				if doc and codeStore.redo then codeStore.redo(doc.id) end
			end)

			reg("editor.find", "Find in Active File", "Edit", "Ctrl+F", function()
				local target = codeStore.focusedPane == "secondary" and secondaryEditor or primaryEditor
				target.openFind(false)
			end, { "edit.find" })

			reg("editor.replace", "Find and Replace in Active File", "Edit", "Ctrl+H", function()
				local target = codeStore.focusedPane == "secondary" and secondaryEditor or primaryEditor
				target.openFind(true)
			end, { "edit.replace" })

			reg("editor.gotoLine", "Go to Line...", "Go", "Ctrl+G", function()
				palette.open(":")
			end)

			reg("editor.format", "Format Document", "Edit", "Shift+Alt+F", function()
				local ok, msg = tools.formatter.formatActive()
				overlay.toast(ok and "Formatted document" or tostring(msg), ok and "good" or "warn", 2)
			end, { "edit.format" })

			reg("editor.toggleSplit", "Split Editor Right / Close Split", "View", "Ctrl+\\", function()
				codeStore.toggleSplit()
				reflowWorkbench()
			end, { "view.splitEditor" })

			reg("editor.toggleMinimap", "Toggle Editor Minimap", "View", nil, function()
				config.set("editor.minimap", not config.get("editor.minimap", true))
			end, { "view.toggleMinimap" })

			reg("editor.toggleWordWrap", "Toggle Word Wrap", "View", "Alt+Z", function()
				config.set("editor.wordWrap", not config.get("editor.wordWrap", false))
			end)

			reg("run.activeFile", "Execute Active Luau Script", "Run", "F5", function()
				panelVisible = true
				bottomTerminal.selectTab("output")
				reflowWorkbench()
				local ok, err = tools.execution.runActive()
				overlay.toast(ok and "Executed active Luau script" or ("Run error: " .. tostring(err)), ok and "good" or "bad", 3)
			end, { "run.active" })

			reg("run.stopAll", "Stop All Running Scripts", "Run", nil, function()
				local n = tools.execution.stop()
				overlay.toast(string.format("Stopped %d task(s)", n), "warn", 2)
			end, { "run.stop" })

			reg("github.clone", "Clone Repository or Load URL via HTTP...", "GitHub", nil, function()
				githubConnect.openModal()
			end, { "github.auth", "github.loadUrl" })

			reg("github.pull", "Pull Latest Remote Tree to Disk", "GitHub", nil, function()
				task.spawn(function()
					local snap, err = tools.githubSync.pull()
					if snap then overlay.toast("Pulled " .. snap.fullName, "good", 3)
					else overlay.toast("Pull failed: " .. tostring(err), "bad", 4) end
				end)
			end)

			reg("github.push", "Commit & Push Changes via HTTP...", "GitHub", nil, function()
				selectViewlet("scm", false)
			end)

			reg("github.createBranch", "Create & Switch GitHub Branch...", "GitHub", nil, function()
				overlay.prompt({
					title = "Create & Switch GitHub Branch",
					placeholder = "feature/my-update",
					mono = true,
					confirmText = "Create Branch",
					onConfirm = function(name)
						task.spawn(function()
							local created, err = tools.githubSync.createBranch(name)
							if created then overlay.toast("Switched to branch " .. name, "good", 3)
							else overlay.toast("Branch error: " .. tostring(err), "bad", 4) end
						end)
					end,
				})
			end)

			reg("workspace.switch", "Switch or Create Local Disk Workspace...", "Workspace", nil, function()
				overlay.prompt({
					title = "Switch Local Disk Workspace",
					subtitle = "Creates or mounts VSRBLX/workspaces/<name>",
					default = workspaceFs.activeName,
					mono = true,
					confirmText = "Mount Workspace",
					onConfirm = function(name)
						if name ~= "" then
							tools.fsSync.switchWorkspace(name)
							overlay.toast("Mounted workspace: " .. name, "good", 3)
						end
					end,
				})
			end)

			reg("workspace.mountRaw", "Mount Raw Executor Disk Folder...", "Workspace", nil, function()
				overlay.prompt({
					title = "Mount Executor Disk Folder",
					subtitle = "Reads/writes any folder inside your executor workspace via readfile/writefile",
					placeholder = "my_scripts",
					mono = true,
					confirmText = "Mount Folder",
					onConfirm = function(folder)
						tools.fsSync.mountRawFolder(folder)
						overlay.toast("Mounted executor folder: " .. (folder ~= "" and folder or "<root>"), "good", 3)
					end,
				})
			end)

			reg("workspace.reloadDisk", "Reload All Open Buffers from Disk (readfile)", "Workspace", nil, function()
				tools.fsSync.reloadFromDisk()
				overlay.toast("Reloaded workspace from disk", "good", 2)
			end, { "file.reloadDisk" })

			for _, t in ipairs(theme.list()) do
				local tid, tlabel = t.id, t.label
				commands.register({
					id = "theme." .. tid,
					title = "Color Theme -> " .. tlabel,
					category = "Preferences",
					run = function() theme.apply(tid) end,
				})
			end
		end

		local function bindShortcuts()
			shortcuts.bind({ key = "RightShift" }, "workbench.toggleWindow", true)
			shortcuts.bind({ key = "F11" }, "window.maximize", true)
			shortcuts.bind({ ctrl = true, shift = true, key = "P" }, "workbench.commandPalette", true)
			shortcuts.bind({ key = "F1" }, "workbench.commandPalette", true)
			shortcuts.bind({ ctrl = true, key = "P" }, "workbench.quickOpen", true)
			shortcuts.bind({ ctrl = true, key = "B" }, "workbench.toggleSideBar", true)
			shortcuts.bind({ ctrl = true, key = "J" }, "workbench.togglePanel", true)
			shortcuts.bind({ ctrl = true, key = "Backquote" }, "workbench.togglePanel", true)
			shortcuts.bind({ ctrl = true, shift = true, key = "E" }, "workbench.viewExplorer", true)
			shortcuts.bind({ ctrl = true, shift = true, key = "F" }, "workbench.viewSearch", true)
			shortcuts.bind({ ctrl = true, shift = true, key = "G" }, "workbench.viewScm", true)
			shortcuts.bind({ ctrl = true, shift = true, key = "D" }, "workbench.viewDebug", true)
			shortcuts.bind({ ctrl = true, shift = true, key = "X" }, "workbench.viewExtensions", true)
			shortcuts.bind({ ctrl = true, key = "Comma" }, "workbench.viewSettings", true)
			shortcuts.bind({ ctrl = true, key = "S" }, "file.save", true)
			shortcuts.bind({ ctrl = true, shift = true, key = "S" }, "file.saveAll", true)
			shortcuts.bind({ ctrl = true, key = "N" }, "file.newUntitled", true)
			shortcuts.bind({ ctrl = true, key = "W" }, "file.closeTab", true)
			shortcuts.bind({ ctrl = true, key = "F" }, "editor.find", true)
			shortcuts.bind({ ctrl = true, key = "H" }, "editor.replace", true)
			shortcuts.bind({ ctrl = true, key = "G" }, "editor.gotoLine", true)
			shortcuts.bind({ shift = true, alt = true, key = "F" }, "editor.format", true)
			shortcuts.bind({ ctrl = true, key = "Backslash" }, "editor.toggleSplit", true)
			shortcuts.bind({ alt = true, key = "Z" }, "editor.toggleWordWrap", true)
			shortcuts.bind({ key = "F5" }, "run.activeFile", true)
			shortcuts.install()
		end

		registerCommands()
		bindShortcuts()

		-- Open starter files from disk workspace
		if workspaceFs.exists("README.md") then
			codeStore.openFile("README.md")
		end
		if workspaceFs.exists("src/main.luau") then
			codeStore.openFile("src/main.luau")
		elseif workspaceFs.exists("src/init.luau") then
			codeStore.openFile("src/init.luau")
		end

		selectViewlet(activeViewlet, false)
		reflowWorkbench()

		theme.changed:connect(function()
			workbenchBody.BackgroundColor3 = theme.color.editor
			sideBarFrame.BackgroundColor3 = theme.color.sideBar
			sideRightBorder.BackgroundColor3 = theme.color.border
			mainArea.BackgroundColor3 = theme.color.editor
			editorsRegion.BackgroundColor3 = theme.color.editor
			primaryGroup.BackgroundColor3 = theme.color.editor
			secondaryGroup.BackgroundColor3 = theme.color.editor
			splitLeftRule.BackgroundColor3 = theme.color.border
			panelHolder.BackgroundColor3 = theme.color.panelBg
		end)

		bootProgress.update("ready", "VS-RBLX Workbench ready.")
		if splash then splash.close() end

		return {
			screenGui = screenGui,
			window = win,
			palette = palette,
			primaryEditor = primaryEditor,
			secondaryEditor = secondaryEditor,
			terminal = bottomTerminal,
			selectViewlet = selectViewlet,
		}
	end

	return M
end
