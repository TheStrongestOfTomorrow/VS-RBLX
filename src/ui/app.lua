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
	local clipboard = env.require("runtime/clipboard")
	local sessionJournal = env.require("runtime/session_journal")
	local gitState = env.require("runtime/git_state")
	local commands = env.require("runtime/command_catalog")
	local shortcuts = env.require("runtime/shortcuts")
	local tools = env.require("tools/init")

	local M = {}

	function M.mount(opts)
		opts = opts or {}
		local splash = opts.splash
		if not splash then
			pcall(function() splash = bootSplash.show() end)
		end
		if splash then pcall(splash.step, "Loading workspace configuration...", 0.25) end

		config.load()
		theme.apply()

		bootProgress.update("fs", "Mounting local disk workspace (writefile / readfile)...")
		if splash then pcall(splash.step, "Mounting local disk workspace...", 0.5) end
		workspaceFs.init()
		gitState.loadMeta()

		local screenGui = Instance.new("ScreenGui")
		screenGui.Name = "VSRBLX_Workbench"
		screenGui.ResetOnSpawn = false
		screenGui.IgnoreGuiInset = true
		screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		local mountedOk = bootSplash.mountScreenGui(screenGui, opts.parent)
		if not mountedOk or not screenGui.Parent then
			pcall(function() screenGui:Destroy() end)
			error("Nowhere to parent VSRBLX_Workbench ScreenGui (gethui, CoreGui, and PlayerGui all unavailable)", 0)
		end
		dispose.add(function()
			pcall(function() screenGui:Destroy() end)
		end)

		overlay.mount(screenGui)

		-- Dirty-tab close confirmation handler (VS Code 3-button Save / Don't Save / Cancel)
		codeStore.dirtyCloseHandler = function(doc)
			overlay.confirm({
				title = string.format("Do you want to save the changes you made to %s?", tostring(doc.title)),
				message = "Your changes will be lost if you don't save them to disk.",
				primaryText = "Save",
				secondaryText = "Don't Save",
				cancelText = "Cancel",
				onPrimary = function()
					local ok, err = codeStore.save(doc.id)
					if ok then
						codeStore.close(doc.id, { force = true })
						overlay.toast("Saved and closed " .. tostring(doc.title), "good", 2)
					else
						overlay.toast("Save failed: " .. tostring(err), "bad", 4)
					end
				end,
				onSecondary = function()
					codeStore.close(doc.id, { force = true })
				end,
			})
		end
		dispose.add(function()
			codeStore.dirtyCloseHandler = nil
		end)

		bootProgress.update("ui", "Constructing draggable & player-resizable VS Code window...")
		if splash then pcall(splash.step, "Building VS Code workbench...", 0.85) end

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
		local zenMode = config.get("workbench.zenMode", false) == true
		local preZenState = nil

		-- TitleBar (bound to window drag + opacity scrub + maximize/minimize/close controls)
		local titleBar = titlebarMod.new(win.body, {
			onMinimize = function() win.minimise() end,
			onMaximize = function() win.toggleMaximise() end,
			onClose = function() win.hide() end,
			onSetOpacity = function(alpha) win.setOpacity(alpha) end,
		})
		win.bindDragBar(titleBar.root)

		-- StatusBar
		local statusBar = statusbarMod.new(win.body)

		-- Central Body Frame between TitleBar and StatusBar (transparent layout wrapper)
		local workbenchBody = P.frame(win.body, {
			name = "WorkbenchBody",
			size = UDim2.new(1, 0, 1, -(TITLE_H + STATUS_H)),
			pos = UDim2.fromOffset(0, TITLE_H),
			bg = theme.color.editor,
			transparency = 1,
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

		-- Main Center Stack (transparent wrapper over EditorsRegion + BottomPanelContainer)
		local mainArea = P.frame(workbenchBody, {
			name = "MainEditorAndPanelStack",
			bg = theme.color.editor,
			transparency = 1,
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
			transparency = 1,
			clip = true,
			zIndex = 12,
		})
		local primaryTabs = tabsMod.new(primaryGroup, "primary")
		local primaryBreadcrumbs = breadcrumbsMod.new(primaryGroup, "primary")
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
			transparency = 1,
			visible = false,
			clip = true,
			zIndex = 12,
		})
		local splitLeftRule = P.frame(secondaryGroup, {
			size = UDim2.new(0, 1, 1, 0),
			bg = theme.color.border,
			zIndex = 30,
		})
		local secondaryTabs = tabsMod.new(secondaryGroup, "secondary")
		local secondaryBreadcrumbs = breadcrumbsMod.new(secondaryGroup, "secondary")
		local secondaryBody = P.frame(secondaryGroup, {
			size = UDim2.new(1, 0, 1, -(TAB_H + CRUMB_H)),
			pos = UDim2.fromOffset(0, TAB_H + CRUMB_H),
			zIndex = 12,
		})
		local secondaryEditor = editorMod.new(secondaryBody, "secondary")

		-- Floating Zen Mode Exit Pill inside EditorsRegion
		local zenExitPill = P.button(editorsRegion, {
			name = "ZenExitPill",
			size = UDim2.fromOffset(148, 24),
			pos = UDim2.new(1, -160, 0, TAB_H + 6),
			bg = theme.color.sideBar,
			hoverBg = theme.color.accent,
			color = theme.color.tabActiveText,
			bold = true,
			textSize = 11,
			text = "✦ Zen Mode  •  Exit",
			radius = 12,
			border = theme.color.accent,
			visible = false,
			zIndex = 65,
			onClick = function()
				commands.run("workbench.toggleZenMode")
			end,
		})

		-- Bottom Panel (`PROBLEMS`, `TODOS`, `OUTPUT`, `TERMINAL`, `HTTP / GIT`)
		local panelHolder = P.frame(mainArea, {
			name = "BottomPanelContainer",
			bg = theme.color.panelBg,
			transparency = 1,
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

		local actBar

		reflowWorkbench = function()
			local showStatus = not zenMode
			statusBar.root.Visible = showStatus
			workbenchBody.Position = UDim2.fromOffset(0, TITLE_H)
			workbenchBody.Size = UDim2.new(1, 0, 1, -(TITLE_H + (showStatus and STATUS_H or 0)))

			local showAct = not zenMode
			if actBar then
				actBar.root.Visible = showAct
			end
			local effActW = showAct and ACT_W or 0

			local showSide = (not zenMode) and sideBarVisible
			local effSideW = showSide and sideBarWidth or 0
			sideBarFrame.Visible = showSide
			sideBarFrame.Position = UDim2.fromOffset(effActW, 0)
			sideBarFrame.Size = UDim2.new(0, sideBarWidth, 1, 0)
			sideSash.Visible = showSide
			sideSash.Position = UDim2.fromOffset(effActW + sideBarWidth - 2, 0)

			local leftOffset = effActW + effSideW
			mainArea.Position = UDim2.fromOffset(leftOffset, 0)
			mainArea.Size = UDim2.new(1, -leftOffset, 1, 0)

			local showPanel = (not zenMode) and panelVisible
			local effPanelH = showPanel and panelHeight or 0
			panelHolder.Visible = showPanel
			panelHolder.Size = UDim2.new(1, 0, 0, effPanelH)
			panelHolder.Position = UDim2.new(0, 0, 1, -effPanelH)

			panelSash.Visible = showPanel
			panelSash.Position = UDim2.new(0, 0, 1, -effPanelH - 2)

			editorsRegion.Position = UDim2.fromOffset(0, 0)
			editorsRegion.Size = UDim2.new(1, 0, 1, -effPanelH)
			zenExitPill.Visible = zenMode

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

		local function setZenMode(flag)
			local nextZen = flag == true
			if nextZen == zenMode then return zenMode end
			if nextZen then
				preZenState = {
					sideBarVisible = sideBarVisible,
					panelVisible = panelVisible,
				}
			elseif preZenState then
				sideBarVisible = preZenState.sideBarVisible
				panelVisible = preZenState.panelVisible
				preZenState = nil
			end
			zenMode = nextZen
			config.set("workbench.zenMode", zenMode)
			if actBar then actBar.refresh() end
			reflowWorkbench()
			return zenMode
		end

		local function selectViewlet(id, toggleIfSame)
			if zenMode then
				setZenMode(false)
			end
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

		-- Ghost-Coding Opacity propagation (single-layer background transparency across zones)
		local function applyWindowOpacity(alpha)
			local clamped = util.clamp(tonumber(alpha) or 1.0, 0.30, 1.0)
			local bgTrans = 1.0 - clamped
			titleBar.root.BackgroundTransparency = bgTrans
			actBar.root.BackgroundTransparency = bgTrans
			sideBarFrame.BackgroundTransparency = bgTrans
			editorsRegion.BackgroundTransparency = bgTrans
			primaryBreadcrumbs.root.BackgroundTransparency = bgTrans
			secondaryBreadcrumbs.root.BackgroundTransparency = bgTrans
			statusBar.root.BackgroundTransparency = math.min(0.75, bgTrans)
			if primaryTabs.setTransparency then primaryTabs.setTransparency(bgTrans) end
			if secondaryTabs.setTransparency then secondaryTabs.setTransparency(bgTrans) end
			if primaryEditor.setTransparency then primaryEditor.setTransparency(bgTrans) end
			if secondaryEditor.setTransparency then secondaryEditor.setTransparency(bgTrans) end
			if bottomTerminal.setTransparency then bottomTerminal.setTransparency(bgTrans) end
		end

		win.opacityChanged:connect(applyWindowOpacity)
		applyWindowOpacity(win.opacity)

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

			reg("workbench.toggleZenMode", "Toggle Zen Mode (Distraction-Free)", "View", "Ctrl+Shift+Z", function()
				local enabled = setZenMode(not zenMode)
				overlay.toast(enabled and "Zen Mode enabled (Ctrl+Shift+Z to exit)" or "Exited Zen Mode", "info", 2)
				return enabled
			end, { "view.zenMode" })

			reg("window.opacityDown", "Ghost Mode: Decrease Window Opacity (-15%)", "Window", nil, function()
				local v = win.stepOpacity(-0.15)
				overlay.toast(string.format("Window opacity: %d%%", math.floor(v * 100 + 0.5)), "info", 1.6)
				return v
			end)
			reg("window.opacityUp", "Ghost Mode: Increase Window Opacity (+15%)", "Window", nil, function()
				local v = win.stepOpacity(0.15)
				overlay.toast(string.format("Window opacity: %d%%", math.floor(v * 100 + 0.5)), "info", 1.6)
				return v
			end)
			reg("window.opacityReset", "Ghost Mode: Reset Window Opacity to 100%", "Window", nil, function()
				local v = win.setOpacity(1.0)
				overlay.toast("Window opacity reset to 100%", "info", 1.6)
				return v
			end)

			reg("workbench.toggleSideBar", "Toggle Primary Side Bar", "View", "Ctrl+B", function()
				if zenMode then setZenMode(false) end
				sideBarVisible = not sideBarVisible
				config.set("workbench.sideBarVisible", sideBarVisible)
				actBar.refresh()
				reflowWorkbench()
			end, { "view.toggleSidebar" })

			reg("workbench.togglePanel", "Toggle Integrated Terminal & Panel", "View", "Ctrl+J", function()
				if zenMode then setZenMode(false) end
				panelVisible = not panelVisible
				config.set("workbench.panelVisible", panelVisible)
				reflowWorkbench()
				if panelVisible then bottomTerminal.focusTerminal() end
			end, { "view.togglePanel" })

			reg("workbench.showProblems", "Focus Problems Panel", "View", nil, function()
				if zenMode then setZenMode(false) end
				panelVisible = true
				bottomTerminal.selectTab("problems")
				reflowWorkbench()
			end, { "view.problems" })

			reg("workbench.showTodos", "Show Workspace TODOs & FIXMEs", "View", "Ctrl+Shift+M", function()
				if zenMode then setZenMode(false) end
				panelVisible = true
				bottomTerminal.selectTab("todos")
				reflowWorkbench()
			end, { "view.todos" })

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
			reg("file.newDiskFile", "New File in Explorer (Inline)...", "File", nil, function()
				selectViewlet("explorer", false)
				viewlets.explorer.fileTree.promptNewFile("")
			end)
			reg("file.newDiskFolder", "New Folder in Explorer (Inline)...", "File", nil, function()
				selectViewlet("explorer", false)
				viewlets.explorer.fileTree.promptNewFolder("")
			end, { "file.newFolder" })

			reg("file.rename", "Rename Active File in Explorer", "File", "F2", function()
				local doc = codeStore.active()
				if doc and doc.path ~= "" and not doc.untitled then
					selectViewlet("explorer", false)
					viewlets.explorer.fileTree.startRename(doc.path)
				end
			end)

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
							local ok, err = codeStore.save(doc.id, { saveAsPath = p })
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
				if doc then codeStore.requestClose(doc.id) end
			end)

			reg("edit.undo", "Undo", "Edit", "Ctrl+Z", function()
				local doc = codeStore.active()
				if doc and codeStore.undo then codeStore.undo(doc.id) end
			end)
			reg("edit.redo", "Redo", "Edit", "Ctrl+Y", function()
				local doc = codeStore.active()
				if doc and codeStore.redo then codeStore.redo(doc.id) end
			end)

			local function focusedEditor()
				return codeStore.focusedPane == "secondary" and secondaryEditor or primaryEditor
			end

			reg("edit.clipboardHistory", "Paste from Clipboard History (15 Slots)", "Edit", "Ctrl+Shift+V", function()
				local items = clipboard.list()
				local menu = {}
				if #items == 0 then
					overlay.toast("Clipboard history is empty — copy or select code first.", "info", 2.2)
					return
				end
				for idx, entry in ipairs(items) do
					local rawText = entry.text
					menu[#menu + 1] = {
						label = string.format("%d. %s", idx, entry.preview or ""),
						shortcut = string.format("%d ch", entry.chars or #rawText),
						onClick = function()
							focusedEditor().runAction("insertText", rawText)
						end,
					}
				end
				menu[#menu + 1] = { separator = true }
				menu[#menu + 1] = {
					label = "Clear Clipboard History",
					onClick = function()
						clipboard.clear()
						overlay.toast("Cleared 15-slot clipboard history", "warn", 2)
					end,
				}
				local wBounds = win.root.AbsolutePosition
				local wSize = win.root.AbsoluteSize
				overlay.dropdown(math.max(16, wBounds.X + math.floor(wSize.X * 0.5) - 170), math.max(40, wBounds.Y + 64), menu, 340)
			end)

			reg("editor.toggleComment", "Toggle Line Comment", "Edit", "Ctrl+/", function()
				return focusedEditor().runAction("toggleComment")
			end)
			reg("editor.indentLines", "Indent Line / Selection", "Edit", "Ctrl+]", function()
				return focusedEditor().runAction("indent")
			end)
			reg("editor.outdentLines", "Outdent Line / Selection", "Edit", "Ctrl+[", function()
				return focusedEditor().runAction("outdent")
			end)
			reg("editor.moveLineUp", "Move Line Up", "Edit", "Alt+Up", function()
				return focusedEditor().runAction("moveLineUp")
			end)
			reg("editor.moveLineDown", "Move Line Down", "Edit", "Alt+Down", function()
				return focusedEditor().runAction("moveLineDown")
			end)
			reg("editor.duplicateLineDown", "Duplicate Line Down", "Edit", "Shift+Alt+Down", function()
				return focusedEditor().runAction("duplicateLineDown")
			end)
			reg("editor.duplicateLineUp", "Duplicate Line Up", "Edit", "Shift+Alt+Up", function()
				return focusedEditor().runAction("duplicateLineUp")
			end)
			reg("editor.deleteLine", "Delete Line", "Edit", "Ctrl+Shift+K", function()
				return focusedEditor().runAction("deleteLine")
			end)
			reg("editor.selectWord", "Select Word at Cursor", "Selection", "Ctrl+D", function()
				return focusedEditor().runAction("selectWord")
			end)
			reg("editor.selectLine", "Select Entire Line", "Selection", "Ctrl+L", function()
				return focusedEditor().runAction("selectLine")
			end)
			reg("editor.copyLine", "Copy Selection or Line to Clipboard Ring", "Edit", nil, function()
				return focusedEditor().runAction("copySelectionOrLine")
			end)

			reg("workbench.changeToggleKey", "Capture Custom Toggle Window Hotkey...", "Preferences", nil, function()
				overlay.toast("Press any key now to set your VS-RBLX Toggle Hotkey...", "info", 4)
				shortcuts.captureNextKey(function(newKey)
					config.set("keybindings.toggleKey", newKey, { immediate = true })
					shortcuts.applyPreset()
					overlay.toast("VS-RBLX Toggle Hotkey bound to: " .. tostring(newKey), "good", 3)
				end)
			end)

			reg("workbench.keymapPreset", "Cycle Keymap Preset (VS Code / Sublime / Touch)", "Preferences", nil, function()
				local order = { "vscode", "sublime", "touch" }
				local cur = tostring(config.get("keybindings.preset", "vscode"))
				local nextIdx = 1
				for i, p in ipairs(order) do
					if p == cur then nextIdx = (i % #order) + 1; break end
				end
				local nextPreset = order[nextIdx]
				config.set("keybindings.preset", nextPreset, { immediate = true })
				shortcuts.applyPreset(nextPreset)
				overlay.toast("Keymap preset switched to: " .. nextPreset, "good", 2.5)
				return nextPreset
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
				if zenMode then setZenMode(false) end
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
			shortcuts.applyPreset()
			shortcuts.install()
		end

		config.changed:connect(function(key)
			if key == "*" or key == "keybindings.preset" or key == "keybindings.toggleKey" then
				shortcuts.applyPreset()
			end
		end)

		registerCommands()
		bindShortcuts()
		clipboard.load()

		-- Restore previous session tabs & unsaved crash drafts, or open starter files
		local restoredSession, recoveredDrafts = sessionJournal.restore()
		if not restoredSession then
			if workspaceFs.exists("README.md") then
				codeStore.openFile("README.md")
			end
			if workspaceFs.exists("src/main.luau") then
				codeStore.openFile("src/main.luau")
			elseif workspaceFs.exists("src/init.luau") then
				codeStore.openFile("src/init.luau")
			end
		elseif recoveredDrafts and recoveredDrafts > 0 then
			overlay.toast(string.format("Recovered %d unsaved draft(s) from session", recoveredDrafts), "good", 3)
		end

		for k, v in pairs(viewlets) do
			v.root.Visible = (k == activeViewlet)
		end
		reflowWorkbench()

		theme.changed:connect(function()
			sideBarFrame.BackgroundColor3 = theme.color.sideBar
			sideRightBorder.BackgroundColor3 = theme.color.border
			editorsRegion.BackgroundColor3 = theme.color.editor
			splitLeftRule.BackgroundColor3 = theme.color.border
			zenExitPill.BackgroundColor3 = theme.color.sideBar
			zenExitPill.TextColor3 = theme.color.tabActiveText
			applyWindowOpacity(win.opacity)
		end)

		bootProgress.update("ready", "VS-RBLX Workbench ready.")
		if splash then splash.close() end

		return {
			screenGui = screenGui,
			window = win,
			titleBar = titleBar,
			statusBar = statusBar,
			viewlets = viewlets,
			palette = palette,
			primaryEditor = primaryEditor,
			secondaryEditor = secondaryEditor,
			terminal = bottomTerminal,
			selectViewlet = selectViewlet,
			setZenMode = setZenMode,
			isZenMode = function() return zenMode end,
		}
	end

	return M
end
