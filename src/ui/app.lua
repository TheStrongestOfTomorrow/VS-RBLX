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
	local responsive = env.require("ui/responsive")
	local mobileBarMod = env.require("ui/mobile_bar")
	local commandPaletteMod = env.require("ui/command_palette")

	local tabsMod = env.require("ui/code/tabs")
	local breadcrumbsMod = env.require("ui/code/breadcrumbs")
	local editorMod = env.require("ui/code/editor")
	local previewPaneMod = env.require("ui/code/preview_pane")
	local splitterMod = env.require("ui/code/splitter")
	local terminalMod = env.require("ui/code/terminal")

	local explorerPanel = env.require("ui/panels/explorer")
	local searchPanel = env.require("ui/panels/search")
	local scmPanel = env.require("ui/panels/scm")
	local debugPanel = env.require("ui/panels/debug")
	local extensionsPanel = env.require("ui/panels/extensions")
	local settingsPanel = env.require("ui/panels/settings")
	local githubConnect = env.require("ui/panels/github_connect")
	local vaultModal = env.require("ui/panels/vault_modal")

	local util = env.require("runtime/util")
	local dispose = env.require("runtime/dispose")
	local config = env.require("runtime/config")
	local cryptoVault = env.require("runtime/crypto_vault")
	local bootProgress = env.require("runtime/boot_progress")
	local workspaceFs = env.require("runtime/workspace_fs")
	local languages = env.require("runtime/languages")
	local previewEngine = env.require("runtime/preview_engine")
	local extensionHub = env.require("runtime/extension_hub")
	local codeStore = env.require("runtime/code_store")
	local clipboard = env.require("runtime/clipboard")
	local sessionJournal = env.require("runtime/session_journal")
	local robloxConsole = env.require("runtime/roblox_console")
	local gitState = env.require("runtime/git_state")
	local commands = env.require("runtime/command_catalog")
	local shortcuts = env.require("runtime/shortcuts")
	local githubNet = env.require("net/github")
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
		cryptoVault.init()
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
		local previewOpen = false
		local mobileMode = tostring(config.get("mobile.mode", "auto")) == "on"
		local drawerOpen = false

		local reflowWorkbench

		-- TitleBar (bound to window drag + explicit resize toggle + opacity scrub + mobile drawer + controls)
		local titleBar = titlebarMod.new(win.body, {
			onMinimize = function() win.minimise() end,
			onMaximize = function() win.toggleMaximise() end,
			onClose = function() win.hide() end,
			onSetOpacity = function(alpha) win.setOpacity(alpha) end,
			onToggleResizeMode = function()
				local on = win.toggleResizeMode()
				overlay.toast(
					on and "⤢ Resize Mode ON — Push/Pull any edge or corner (Tap ⤢ again to lock & move)"
						or "⤢ Resize Mode OFF — Window locked, drag Topbar to move freely",
					on and "info" or "good",
					2.4
				)
			end,
			onToggleDrawer = function()
				drawerOpen = not drawerOpen
				if reflowWorkbench then reflowWorkbench() end
			end,
		})
		win.bindDragBar(titleBar.root)
		win.resizeModeChanged:connect(function(flag)
			if titleBar.setResizeMode then
				titleBar.setResizeMode(flag)
			end
		end)

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

		-- Tap-to-dismiss backdrop when Acode Mobile Slide-Over Drawer is open
		local drawerBackdrop = P.button(workbenchBody, {
			name = "MobileDrawerBackdrop",
			size = UDim2.fromScale(1, 1),
			bg = Color3.fromRGB(0, 0, 0),
			hoverBg = Color3.fromRGB(0, 0, 0),
			transparency = 0.45,
			text = "",
			visible = false,
			zIndex = 50,
			onClick = function()
				drawerOpen = false
				if reflowWorkbench then reflowWorkbench() end
			end,
		})

		-- Primary Sidebar Container (acts as Slide-Over Drawer in Acode Mobile Mode)
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

		-- Mobile Drawer Top Switcher Strip (shown inside Sidebar when Mobile Mode is active)
		local drawerNav = P.frame(sideBarFrame, {
			name = "MobileDrawerNav",
			size = UDim2.new(1, -1, 0, 34),
			bg = theme.color.activityBar,
			visible = false,
			zIndex = 58,
		})
		P.pad(drawerNav, 3, 6, 3, 6)
		P.list(drawerNav, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

		local viewletHost = P.frame(sideBarFrame, {
			name = "SideBarViewletHost",
			size = UDim2.fromScale(1, 1),
			transparency = 1,
			zIndex = 21,
		})

		-- Viewlets inside Primary Sidebar
		local viewlets = {
			explorer = explorerPanel.new(viewletHost),
			search = searchPanel.new(viewletHost),
			scm = scmPanel.new(viewletHost),
			debug = debugPanel.new(viewletHost),
			extensions = extensionsPanel.new(viewletHost),
			settings = settingsPanel.new(viewletHost),
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

		-- Live Split Preview Pane (for previewable languages ONLY: HTML+CSS, Markdown, CSS, JSON/YAML, SQL, Python/JS/TS)
		local previewPane = previewPaneMod.new(editorsRegion, {
			onClose = function()
				previewOpen = false
				if reflowWorkbench then reflowWorkbench() end
			end,
		})

		-- Acode Mobile Quick-Keys Bar (1-tap symbols + Undo/Redo + Play+Code + Run)
		local mobileQuickBar = mobileBarMod.new(mainArea, function(sym)
			local targetEd = codeStore.focusedPane == "secondary" and secondaryEditor or primaryEditor
			targetEd.runAction("insertText", sym)
		end)

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
		local drawerPillBtns = {}

		reflowWorkbench = function()
			local winW = math.max(280, win.root.Size.X.Offset)
			local winH = math.max(200, win.root.Size.Y.Offset)
			local effTitleH = mobileMode and 38 or TITLE_H
			local effTabH = mobileMode and 42 or TAB_H
			local showStatus = (not zenMode) and (not mobileMode)
			statusBar.root.Visible = showStatus
			if titleBar.reflow then titleBar.reflow(winW) end
			if statusBar.reflow then statusBar.reflow(winW) end
			workbenchBody.Position = UDim2.fromOffset(0, effTitleH)
			workbenchBody.Size = UDim2.new(1, 0, 1, -(effTitleH + (showStatus and STATUS_H or 0)))

			primaryBreadcrumbs.root.Position = UDim2.fromOffset(0, effTabH)
			primaryBody.Position = UDim2.fromOffset(0, effTabH + CRUMB_H)
			primaryBody.Size = UDim2.new(1, 0, 1, -(effTabH + CRUMB_H))
			secondaryBreadcrumbs.root.Position = UDim2.fromOffset(0, effTabH)
			secondaryBody.Position = UDim2.fromOffset(0, effTabH + CRUMB_H)
			secondaryBody.Size = UDim2.new(1, 0, 1, -(effTabH + CRUMB_H))

			local showAct = (not zenMode) and (not mobileMode)
			if actBar then
				actBar.root.Visible = showAct
			end
			local effActW = showAct and ACT_W or 0
			local mainAvailW = winW

			if mobileMode then
				-- Acode Slide-Over Drawer mode: overlays on top of the editor when `drawerOpen == true`
				local drawerW = math.min(290, math.max(200, winW - 36))
				local showDrawer = (not zenMode) and drawerOpen
				drawerBackdrop.Visible = showDrawer
				sideBarFrame.Visible = showDrawer
				sideBarFrame.ZIndex = 55
				sideBarFrame.Position = UDim2.fromOffset(0, 0)
				sideBarFrame.Size = UDim2.new(0, drawerW, 1, 0)
				drawerNav.Visible = true
				viewletHost.Position = UDim2.fromOffset(0, 34)
				viewletHost.Size = UDim2.new(1, 0, 1, -34)
				sideSash.Visible = false

				mainArea.Position = UDim2.fromOffset(0, 0)
				mainArea.Size = UDim2.fromScale(1, 1)
				mainAvailW = winW
			else
				drawerBackdrop.Visible = false
				drawerNav.Visible = false
				sideBarFrame.ZIndex = 20
				viewletHost.Position = UDim2.fromOffset(0, 0)
				viewletHost.Size = UDim2.fromScale(1, 1)

				-- Clamp Desktop Sidebar width on narrow screens (< 580px) so Editor always keeps breathing room!
				local clampedSideW = (winW < 580)
					and math.min(sideBarWidth, math.max(150, math.floor((winW - effActW) * 0.42)))
					or sideBarWidth
				local showSide = (not zenMode) and sideBarVisible
				local effSideW = showSide and clampedSideW or 0
				sideBarFrame.Visible = showSide
				sideBarFrame.Position = UDim2.fromOffset(effActW, 0)
				sideBarFrame.Size = UDim2.new(0, clampedSideW, 1, 0)
				sideSash.Visible = showSide
				sideSash.Position = UDim2.fromOffset(effActW + clampedSideW - 2, 0)

				local leftOffset = effActW + effSideW
				mainArea.Position = UDim2.fromOffset(leftOffset, 0)
				mainArea.Size = UDim2.new(1, -leftOffset, 1, 0)
				mainAvailW = math.max(180, winW - leftOffset)
			end

			local showQuickBar = mobileMode and (config.get("mobile.quickKeys", true) ~= false)
			local effQuickH = showQuickBar and mobileQuickBar.height or 0
			mobileQuickBar.root.Visible = showQuickBar

			local showPanel = (not zenMode) and panelVisible
			local clampedPanelH = math.min(panelHeight, math.max(90, math.floor((winH - effTitleH) * 0.44)))
			local effPanelH = showPanel and clampedPanelH or 0
			panelHolder.Visible = showPanel
			panelHolder.Size = UDim2.new(1, 0, 0, effPanelH)
			panelHolder.Position = UDim2.new(0, 0, 1, -effPanelH)

			if showQuickBar then
				mobileQuickBar.root.Position = UDim2.new(0, 0, 1, -(effPanelH + effQuickH))
			end

			panelSash.Visible = showPanel
			panelSash.Position = UDim2.new(0, 0, 1, -effPanelH - 2)

			editorsRegion.Position = UDim2.fromOffset(0, 0)
			editorsRegion.Size = UDim2.new(1, 0, 1, -(effPanelH + effQuickH))
			zenExitPill.Visible = zenMode

			local curPrimaryDoc = codeStore.active("primary")
			local canShowPreview = previewOpen and (curPrimaryDoc ~= nil) and languages.isPreviewable(curPrimaryDoc)

			if canShowPreview then
				primaryGroup.Size = UDim2.new(splitRatio, 0, 1, 0)
				secondaryGroup.Visible = false
				previewPane.root.Visible = true
				previewPane.root.Position = UDim2.new(splitRatio, 0, 0, 0)
				previewPane.root.Size = UDim2.new(1 - splitRatio, 0, 1, 0)
				editorSplitSash.Visible = true
				editorSplitSash.Position = UDim2.new(splitRatio, -2, 0, 0)
				if primaryTabs.reflow then primaryTabs.reflow(math.floor(mainAvailW * splitRatio)) end
			elseif codeStore.splitOpen then
				previewPane.root.Visible = false
				primaryGroup.Size = UDim2.new(splitRatio, 0, 1, 0)
				secondaryGroup.Visible = true
				secondaryGroup.Position = UDim2.new(splitRatio, 0, 0, 0)
				secondaryGroup.Size = UDim2.new(1 - splitRatio, 0, 1, 0)
				editorSplitSash.Visible = true
				editorSplitSash.Position = UDim2.new(splitRatio, -2, 0, 0)
				if primaryTabs.reflow then primaryTabs.reflow(math.floor(mainAvailW * splitRatio)) end
				if secondaryTabs.reflow then secondaryTabs.reflow(math.floor(mainAvailW * (1 - splitRatio))) end
			else
				previewPane.root.Visible = false
				primaryGroup.Size = UDim2.fromScale(1, 1)
				secondaryGroup.Visible = false
				editorSplitSash.Visible = false
				if primaryTabs.reflow then primaryTabs.reflow(mainAvailW) end
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
			if mobileMode then
				activeViewlet = id
				drawerOpen = true
			else
				if toggleIfSame and sideBarVisible and activeViewlet == id then
					sideBarVisible = false
				else
					activeViewlet = id
					sideBarVisible = true
				end
			end
			for k, v in pairs(viewlets) do
				v.root.Visible = (k == activeViewlet)
			end
			for vid, b in pairs(drawerPillBtns) do
				b.BackgroundColor3 = (vid == activeViewlet) and theme.color.accent or theme.color.inputBg
				b.TextColor3 = (vid == activeViewlet) and Color3.fromRGB(255, 255, 255) or theme.color.sideBarText
			end
			config.set("workbench.activeViewlet", activeViewlet)
			config.set("workbench.sideBarVisible", sideBarVisible)
			if actBar then actBar.refresh() end
			reflowWorkbench()
			if (sideBarVisible or drawerOpen) and id == "search" and viewlets.search.focus then
				viewlets.search.focus()
			end
		end

		-- Populate Mobile Drawer Viewlet Switcher Pills (`Files`, `Search`, `Git`, `Run`, `Ext`, `⚙`, `>`)
		local DRAWER_TABS = {
			{ id = "explorer", label = "Files" },
			{ id = "search", label = "Search" },
			{ id = "scm", label = "Git" },
			{ id = "debug", label = "Run" },
			{ id = "extensions", label = "Ext" },
			{ id = "settings", label = "⚙" },
		}
		for idx, dSpec in ipairs(DRAWER_TABS) do
			local db = P.button(drawerNav, {
				name = "DrawerTab_" .. dSpec.id,
				size = UDim2.fromOffset(#dSpec.label * 6 + 18, 26),
				bg = (dSpec.id == activeViewlet) and theme.color.accent or theme.color.inputBg,
				hoverBg = theme.color.hover,
				color = (dSpec.id == activeViewlet) and Color3.fromRGB(255, 255, 255) or theme.color.sideBarText,
				bold = true,
				text = dSpec.label,
				textSize = 11,
				radius = 5,
				order = idx,
				zIndex = 59,
				onClick = function()
					selectViewlet(dSpec.id, false)
				end,
			})
			db.BackgroundTransparency = 0
			drawerPillBtns[dSpec.id] = db
		end
		local cmdPill = P.button(drawerNav, {
			name = "DrawerCmdPaletteBtn",
			size = UDim2.fromOffset(30, 26),
			bg = theme.color.inputBg,
			hoverBg = theme.color.accent,
			text = ">_",
			mono = true,
			bold = true,
			textSize = 11,
			radius = 5,
			order = 99,
			zIndex = 59,
			onClick = function()
				drawerOpen = false
				reflowWorkbench()
				palette.open(">")
			end,
		})
		cmdPill.BackgroundTransparency = 0

		local function setMobileMode(flag, opts)
			opts = opts or {}
			mobileMode = flag == true
			drawerOpen = false
			if not opts.keepConfig then
				config.set("mobile.mode", mobileMode and "on" or "off", { immediate = true })
			end
			if mobileMode then
				panelVisible = false
				config.set("workbench.panelVisible", false, { quiet = true })
			end
			titleBar.setMobileMode(mobileMode)
			primaryTabs.setMobileMode(mobileMode)
			secondaryTabs.setMobileMode(mobileMode)
			win.setMobileMode(mobileMode)
			reflowWorkbench()
			if not opts.silent then
				overlay.toast(
					mobileMode and "📱 Acode Mobile Mode enabled (☰ drawer, 42px tabs & Quick-Keys)" or "Switched to Desktop VS Code Mode",
					"good",
					2.6
				)
			end
			return mobileMode
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
			sideBarFrame.BackgroundTransparency = mobileMode and math.min(0.15, bgTrans) or bgTrans
			editorsRegion.BackgroundTransparency = bgTrans
			primaryBreadcrumbs.root.BackgroundTransparency = bgTrans
			secondaryBreadcrumbs.root.BackgroundTransparency = bgTrans
			statusBar.root.BackgroundTransparency = math.min(0.75, bgTrans)
			if primaryTabs.setTransparency then primaryTabs.setTransparency(bgTrans) end
			if secondaryTabs.setTransparency then secondaryTabs.setTransparency(bgTrans) end
			if primaryEditor.setTransparency then primaryEditor.setTransparency(bgTrans) end
			if secondaryEditor.setTransparency then secondaryEditor.setTransparency(bgTrans) end
			if previewPane.setTransparency then previewPane.setTransparency(bgTrans) end
			if mobileQuickBar.setTransparency then mobileQuickBar.setTransparency(bgTrans) end
			if bottomTerminal.setTransparency then bottomTerminal.setTransparency(bgTrans) end
		end

		win.opacityChanged:connect(applyWindowOpacity)
		applyWindowOpacity(win.opacity)

		codeStore.changed:connect(function()
			-- Auto-close mobile drawer when opening/activating a file so the player sees code immediately!
			if mobileMode and drawerOpen then
				drawerOpen = false
			end
			local activeDoc = codeStore.active("primary")
			if previewOpen and activeDoc and languages.isPreviewable(activeDoc) then
				if config.get("preview.autoRefresh", true) ~= false or previewPane.currentDoc() ~= activeDoc then
					previewPane.render(activeDoc)
				end
			end
			reflowWorkbench()
		end)
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

			reg("window.toggleResizeMode", "Toggle Resize Mode (⤢ Push/Pull Edges ON/OFF)", "Window", nil, function()
				local on = win.toggleResizeMode()
				overlay.toast(
					on and "⤢ Resize Mode ON — Pull/push any edge or corner" or "⤢ Resize Mode OFF — Drag Topbar to move freely",
					on and "info" or "good",
					2.2
				)
				return on
			end, { "window.resizeMode" })

			reg("window.setResizeMode", "Set Window Resize Mode Explicitly", "Window", nil, function(flag)
				return win.setResizeMode(flag == true)
			end)

			reg("vault.open", "Zero-Knowledge Master Vault: Setup / Unlock / Manage...", "Security", nil, function()
				return vaultModal.openVaultModal()
			end, { "vault.setup", "vault.unlock" })

			reg("vault.lock", "Zero-Knowledge Master Vault: Lock Session Now", "Security", nil, function()
				cryptoVault.lock()
				overlay.toast("🔒 Master Vault locked (decrypted PAT wiped from RAM)", "good", 2.2)
				return true
			end)

			reg("vault.reset", "Zero-Knowledge Master Vault: Wipe & Disable Encryption", "Security", nil, function()
				cryptoVault.resetVault()
				overlay.toast("Wiped VSRBLX/vault.enc & disabled Vault encryption", "warn", 2.5)
				return true
			end)

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
					if ok then
						if doc.path == ".vsrblx/settings.json" or doc.path == "settings.json" then
							local importedOk, impErr = config.importJson(doc.content)
							if importedOk then
								overlay.toast("Synced settings.json -> live Workbench config", "good", 2.4)
							else
								overlay.toast("settings.json JSON error: " .. tostring(impErr), "bad", 4)
							end
						else
							overlay.toast("Saved " .. doc.path, "good", 2)
						end
					else
						overlay.toast("Save failed: " .. tostring(err), "bad", 4)
					end
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

			reg("editor.gotoDefinition", "Go to Definition (Local or Cross-File Module)", "Go", "F12", function()
				local def = focusedEditor().gotoDefinition()
				if not def then
					overlay.toast("No workspace symbol definition found at cursor", "info", 2)
				end
				return def
			end)

			reg("editor.triggerSuggest", "Trigger LSP Suggest / Autocomplete", "Edit", "Ctrl+Space", function()
				return focusedEditor().triggerSuggest()
			end)

			reg("editor.showHover", "Show Symbol Hover Documentation", "View", "Ctrl+Shift+I", function()
				local info = focusedEditor().showHover()
				if not info then
					overlay.toast("No hover documentation for symbol at cursor", "info", 1.8)
				end
				return info
			end)

			reg("extensions.syncGitHub", "Sync Community Extensions from GitHub Issues Hub", "Extensions", nil, function()
				selectViewlet("extensions", false)
				local list, err = extensionHub.syncFromGitHub()
				if not list then
					overlay.toast("Extension Hub sync failed: " .. tostring(err), "bad", 3)
					return nil, err
				end
				overlay.toast(string.format("🛡 Scanned %d GitHub Issue extension(s)", #list), "good", 2.4)
				return list
			end)

			reg("editor.format", "Format Document", "Edit", "Shift+Alt+F", function()
				local ok, msg = tools.formatter.formatActive()
				overlay.toast(ok and "Formatted document" or tostring(msg), ok and "good" or "warn", 2)
			end, { "edit.format" })

			reg("editor.toggleSplit", "Split Editor Right / Close Split", "View", "Ctrl+\\", function()
				previewOpen = false
				codeStore.toggleSplit()
				reflowWorkbench()
			end, { "view.splitEditor" })

			reg("preview.openToSide", "Open Live Preview to the Side", "Preview", nil, function()
				local doc = codeStore.active("primary")
				if not doc or not languages.isPreviewable(doc) then
					local lname = doc and languages.get(doc.langId).name or "empty buffer"
					overlay.toast("Live Preview is not available for " .. lname, "warn", 2.2)
					return false
				end
				if previewOpen and previewPane.currentDoc() == doc and previewPane.root.Visible then
					previewOpen = false
					reflowWorkbench()
					return false
				end
				codeStore.splitOpen = false
				previewOpen = true
				previewPane.render(doc)
				reflowWorkbench()
				return true
			end, { "markdown.showPreviewToSide", "view.openPreview" })

			reg("preview.close", "Close Live Split Preview", "Preview", nil, function()
				previewOpen = false
				reflowWorkbench()
				return true
			end)

			reg("workbench.toggleMobileMode", "Toggle Acode Mobile Mode (Touch & Play-While-Coding)", "Mobile", nil, function()
				return setMobileMode(not mobileMode)
			end, { "mobile.toggle" })

			reg("mobile.toggleDrawer", "Toggle Mobile Slide-Over Drawer", "Mobile", nil, function()
				if not mobileMode then setMobileMode(true, { silent = true }) end
				drawerOpen = not drawerOpen
				reflowWorkbench()
				return drawerOpen
			end)

			reg("mobile.togglePlayWhileCoding", "Toggle Play-While-Coding Split Peek Mode", "Mobile", nil, function()
				local active = win.setPlayWhileCoding(not win.playWhileCoding)
				reflowWorkbench()
				overlay.toast(
					active and "🎮 Play-While-Coding active (left screen free for gameplay!)" or "Exited Play-While-Coding dock",
					"good",
					2.5
				)
				return active
			end)

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
							if gitState.repo then
								local created, err = tools.githubSync.createBranch(name)
								if created then overlay.toast("Switched to branch " .. name, "good", 3)
								else overlay.toast("Branch error: " .. tostring(err), "bad", 4) end
							else
								gitState.branch = name
								gitState.saveMeta()
								gitState.changed:fire()
								overlay.toast("Switched local branch to " .. name, "good", 2.5)
							end
						end)
					end,
				})
			end)

			reg("github.switchBranch", "Switch or Create Git Branch...", "GitHub", nil, function()
				local menu = {
					{
						label = "+ Create New Branch...",
						onClick = function() commands.run("github.createBranch") end,
					},
					{
						label = "↻ Pull Latest Remote Tree",
						onClick = function() commands.run("github.pull") end,
					},
					{
						label = "⎇ Open Source Control View",
						shortcut = "Ctrl+Shift+G",
						onClick = function() selectViewlet("scm", false) end,
					},
					{ separator = true },
				}

				local curBranch = gitState.branch or "main"
				local knownBranches = { curBranch }
				if curBranch ~= "main" then knownBranches[#knownBranches + 1] = "main" end

				local function showMenu(branchNames)
					local seen = {}
					for _, bName in ipairs(branchNames) do
						if not seen[bName] then
							seen[bName] = true
							menu[#menu + 1] = {
								label = (bName == curBranch and "✓ ⎇ " or "   ⎇ ") .. bName,
								onClick = function()
									gitState.branch = bName
									gitState.saveMeta()
									gitState.changed:fire()
									if gitState.repo then
										task.spawn(function()
											local snap, err = tools.githubSync.cloneRepo(gitState.repo, { branch = bName })
											if snap then overlay.toast("Checked out " .. bName, "good", 2.5)
											else overlay.toast("Checkout failed: " .. tostring(err), "bad", 4) end
										end)
									else
										overlay.toast("Switched branch to " .. bName, "good", 2)
									end
								end,
							}
						end
					end
					local p = statusBar.branchButton and statusBar.branchButton.AbsolutePosition or Vector2.new(80, 420)
					overlay.dropdown(math.max(12, p.X), math.max(24, p.Y - (#menu * 24 + 16)), menu, 230)
				end

				if gitState.repo then
					task.spawn(function()
						local o, r = gitState.repo:match("^([^/]+)/([^/]+)$")
						local names = (o and r) and githubNet.listBranches(o, r) or nil
						if type(names) == "table" and #names > 0 then
							showMenu(names)
						else
							showMenu(knownBranches)
						end
					end)
				else
					showMenu(knownBranches)
				end
			end)

			reg("github.importGist", "Import GitHub Gist into Workspace...", "GitHub", nil, function()
				overlay.prompt({
					title = "Import GitHub Gist",
					subtitle = "Enter a Gist ID or https://gist.github.com/... URL",
					placeholder = "a1b2c3d4e5f6...",
					mono = true,
					confirmText = "Import Gist",
					onConfirm = function(spec)
						if spec == "" then return end
						task.spawn(function()
							local res, err = tools.githubSync.importGist(spec)
							if res then
								overlay.toast(string.format("Imported %d Gist file(s) to disk", res.count), "good", 3)
							else
								overlay.toast("Gist import failed: " .. tostring(err), "bad", 4)
							end
						end)
					end,
				})
			end)

			reg("github.publishGist", "Publish Active Buffer to GitHub Gist", "GitHub", nil, function()
				task.spawn(function()
					local res, err = tools.githubSync.publishActiveGist({ public = false })
					if res then
						overlay.toast("Published Secret Gist (URL copied!)", "good", 3.5)
					else
						overlay.toast("Gist publish failed: " .. tostring(err), "bad", 4)
					end
				end)
			end)

			reg("roblox.pickInstance", "Eyedropper: Pick In-Game 3D / GUI Instance Path", "Roblox", nil, function()
				tools.instancePicker.start(screenGui, win, function(luauPath, inst)
					focusedEditor().runAction("insertText", luauPath)
					overlay.toast("Inserted & copied: " .. luauPath .. " (" .. tostring(inst and inst.ClassName or "Instance") .. ")", "good", 3)
				end)
			end)

			reg("roblox.showConsole", "Open Live Roblox LogService Console", "Roblox", nil, function()
				if zenMode then setZenMode(false) end
				panelVisible = true
				bottomTerminal.selectTab("output")
				if bottomTerminal.setOutputChannel then
					bottomTerminal.setOutputChannel("roblox")
				end
				reflowWorkbench()
			end)

			reg("workspace.bundle", "Bundle Workspace into Standalone Luau Script", "Build", "Ctrl+Shift+B", function()
				local res, err = tools.projectBundler.bundleWorkspace()
				if not res then
					overlay.toast("Bundle failed: " .. tostring(err), "bad", 4)
					return nil
				end
				codeStore.openFile(res.outputPath, { reloadFromDisk = true })
				overlay.toast(string.format("Bundled %d modules -> %s (copied!)", res.modules, res.outputPath), "good", 3.5)
				return res
			end)

			reg("terminal.newSession", "Create New Integrated Terminal Session", "Terminal", nil, function()
				if zenMode then setZenMode(false) end
				panelVisible = true
				bottomTerminal.selectTab("terminal")
				reflowWorkbench()
				local sess = tools.terminal.newSession()
				bottomTerminal.focusTerminal()
				return sess
			end)

			reg("preferences.openSettingsJson", "Preferences: Open settings.json (JSON)", "Preferences", nil, function()
				local jsonBody = config.exportJson()
				workspaceFs.writeFile(".vsrblx/settings.json", jsonBody)
				return codeStore.openFile(".vsrblx/settings.json", { reloadFromDisk = true })
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
			if key == "*" or key == "mobile.mode" then
				local pref = tostring(config.get("mobile.mode", "auto"))
				if pref == "on" and not mobileMode then
					setMobileMode(true, { silent = true, keepConfig = true })
				elseif pref == "off" and mobileMode then
					setMobileMode(false, { silent = true, keepConfig = true })
				end
			elseif key == "mobile.quickKeys" or key == "mobile.playWhileCoding" then
				if key == "mobile.playWhileCoding" then
					local wantPlay = config.get("mobile.playWhileCoding", false) == true
					if win.playWhileCoding ~= wantPlay then
						win.setPlayWhileCoding(wantPlay)
					end
				end
				reflowWorkbench()
			end
		end)

		registerCommands()
		bindShortcuts()
		clipboard.load()
		robloxConsole.install()

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
		if mobileMode then
			setMobileMode(true, { silent = true, keepConfig = true })
		else
			reflowWorkbench()
		end

		-- Auto-detect Android / touch devices and offer to switch to Acode Mobile Mode,
		-- followed by First-Boot Zero-Knowledge Master Vault Onboarding (`[Create Vault Key]` vs `[Leave Unencrypted]`)!
		local function maybeOfferVaultOnboarding()
			if opts.skipFirstBootPrompts == true then return end
			if cryptoVault.shouldPromptFirstBoot() then
				config.set("vault.promptedOnce", true, { immediate = true })
				vaultModal.openSetupModal()
			end
		end

		local modeSetting = tostring(config.get("mobile.mode", "auto"))
		if modeSetting == "auto" and responsive.isTouchDevice() and config.get("mobile.promptedOnce", false) ~= true then
			overlay.confirm({
				title = "📱 Touch / Mobile Device Detected",
				message = "Switch to Acode Mobile Mode (☰ slide-over drawer, 42px touch tabs, Quick-Keys symbol bar & Play-While-Coding)? You can switch back anytime via 📱 in the Title Bar.",
				primaryText = "Switch to Mobile Mode",
				secondaryText = "Keep Desktop Mode",
				cancelText = "Ask Later",
				onPrimary = function()
					config.set("mobile.promptedOnce", true, { quiet = true })
					setMobileMode(true)
					maybeOfferVaultOnboarding()
				end,
				onSecondary = function()
					config.set("mobile.promptedOnce", true, { quiet = true })
					config.set("mobile.mode", "off", { immediate = true })
					maybeOfferVaultOnboarding()
				end,
			})
		else
			maybeOfferVaultOnboarding()
		end

		theme.changed:connect(function()
			sideBarFrame.BackgroundColor3 = theme.color.sideBar
			drawerNav.BackgroundColor3 = theme.color.activityBar
			sideRightBorder.BackgroundColor3 = theme.color.border
			editorsRegion.BackgroundColor3 = theme.color.editor
			splitLeftRule.BackgroundColor3 = theme.color.border
			zenExitPill.BackgroundColor3 = theme.color.sideBar
			zenExitPill.TextColor3 = theme.color.tabActiveText
			for vid, b in pairs(drawerPillBtns) do
				b.BackgroundColor3 = (vid == activeViewlet) and theme.color.accent or theme.color.inputBg
				b.TextColor3 = (vid == activeViewlet) and Color3.fromRGB(255, 255, 255) or theme.color.sideBarText
			end
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
			primaryTabs = primaryTabs,
			primaryEditor = primaryEditor,
			secondaryEditor = secondaryEditor,
			previewPane = previewPane,
			previewEngine = previewEngine,
			mobileQuickBar = mobileQuickBar,
			terminal = bottomTerminal,
			selectViewlet = selectViewlet,
			setZenMode = setZenMode,
			isZenMode = function() return zenMode end,
			setMobileMode = setMobileMode,
			isMobileMode = function() return mobileMode end,
			isPreviewOpen = function() return previewOpen and previewPane.root.Visible end,
		}
	end

	return M
end
