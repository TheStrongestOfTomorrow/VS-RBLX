-- VS Code Bottom Integrated Panel with PROBLEMS, OUTPUT, TERMINAL, and HTTP/GIT tabs.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local config = env.require("runtime/config")
	local log = env.require("runtime/log")
	local diagnostics = env.require("runtime/diagnostics")
	local codeStore = env.require("runtime/code_store")
	local http = env.require("net/http")
	local terminalCmds = env.require("tools/terminal_cmds")

	local M = {}

	local TABS = {
		{ id = "problems", label = "PROBLEMS" },
		{ id = "output", label = "OUTPUT" },
		{ id = "terminal", label = "TERMINAL" },
		{ id = "http", label = "HTTP / GIT" },
	}

	function M.new(parent, onClosePanel)
		local root = P.frame(parent, {
			name = "BottomPanel",
			size = UDim2.fromScale(1, 1),
			bg = theme.color.panelBg,
			clip = true,
			zIndex = 20,
		})
		local topRule = P.frame(root, {
			size = UDim2.new(1, 0, 0, 1),
			bg = theme.color.border,
			zIndex = 21,
		})

		local header = P.frame(root, {
			name = "PanelHeader",
			size = UDim2.new(1, 0, 0, 28),
			pos = UDim2.fromOffset(0, 1),
			bg = theme.color.panelHeader,
			zIndex = 21,
		})

		local tabRow = P.frame(header, {
			size = UDim2.new(1, -90, 1, 0),
			pos = UDim2.fromOffset(10, 0),
			zIndex = 22,
		})
		P.list(tabRow, Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

		local tabButtons = {}
		local activeTab = config.get("workbench.activePanelTab", "terminal")

		local bodyArea = P.frame(root, {
			name = "PanelBody",
			size = UDim2.new(1, 0, 1, -29),
			pos = UDim2.fromOffset(0, 29),
			bg = theme.color.panelBg,
			zIndex = 21,
		})

		-- Clear & Close panel buttons
		local rightBtns = P.frame(header, {
			size = UDim2.fromOffset(72, 28),
			pos = UDim2.new(1, -76, 0, 0),
			zIndex = 22,
		})
		P.list(rightBtns, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

		P.button(rightBtns, {
			name = "ClearPanelBtn",
			size = UDim2.fromOffset(38, 22),
			text = "Clear",
			textSize = 11,
			color = theme.color.muted,
			radius = 3,
			order = 1,
			zIndex = 23,
			onClick = function()
				if activeTab == "terminal" then terminalCmds.clear()
				elseif activeTab == "output" then log.clear()
				elseif activeTab == "http" then http.clearHistory() end
			end,
		})
		P.button(rightBtns, {
			name = "HidePanelBtn",
			size = UDim2.fromOffset(24, 22),
			text = "✕",
			textSize = 11,
			color = theme.color.muted,
			radius = 3,
			order = 2,
			zIndex = 23,
			onClick = function()
				if onClosePanel then onClosePanel() end
			end,
		})

		-- 1. PROBLEMS view
		local problemsScroll = P.scroll(bodyArea, { name = "ProblemsView", visible = false, zIndex = 22 })
		P.pad(problemsScroll, 6, 8, 6, 8)
		P.list(problemsScroll, Enum.FillDirection.Vertical, 2)

		-- 2. OUTPUT view
		local outputScroll = P.scroll(bodyArea, { name = "OutputView", visible = false, zIndex = 22 })
		P.pad(outputScroll, 6, 8, 6, 8)
		P.list(outputScroll, Enum.FillDirection.Vertical, 1)

		-- 3. TERMINAL view
		local termPane = P.frame(bodyArea, { name = "TerminalView", size = UDim2.fromScale(1, 1), visible = false, zIndex = 22 })
		local termScroll = P.scroll(termPane, {
			name = "TerminalScroll",
			size = UDim2.new(1, 0, 1, -30),
			zIndex = 23,
		})
		P.pad(termScroll, 6, 10, 4, 10)
		P.list(termScroll, Enum.FillDirection.Vertical, 2)

		local promptRow = P.frame(termPane, {
			name = "TerminalInputBar",
			size = UDim2.new(1, 0, 0, 28),
			pos = UDim2.new(0, 0, 1, -28),
			bg = theme.color.sideBar,
			zIndex = 23,
		})
		local promptGlyph = P.label(promptRow, {
			size = UDim2.fromOffset(22, 28),
			pos = UDim2.fromOffset(8, 0),
			text = "❯",
			mono = true,
			bold = true,
			color = theme.color.accent,
			zIndex = 24,
		})
		local _, termInput = P.input(promptRow, {
			name = "TerminalCommandInput",
			size = UDim2.new(1, -36, 0, 24),
			pos = UDim2.fromOffset(28, 2),
			mono = true,
			placeholder = "Type command (help, ls, git clone owner/repo, git push, run, luau ...)",
			zIndex = 24,
		})
		termInput.FocusLost:Connect(function(enterPressed)
			if enterPressed and termInput.Text ~= "" then
				local cmd = termInput.Text
				termInput.Text = ""
				terminalCmds.execute(cmd)
				task.defer(function() pcall(function() termInput:CaptureFocus() end) end)
			end
		end)

		-- 4. HTTP / GIT view
		local httpScroll = P.scroll(bodyArea, { name = "HttpView", visible = false, zIndex = 22 })
		P.pad(httpScroll, 6, 8, 6, 8)
		P.list(httpScroll, Enum.FillDirection.Vertical, 2)

		local function renderProblems()
			problemsScroll:ClearAllChildren()
			P.pad(problemsScroll, 6, 8, 6, 8)
			P.list(problemsScroll, Enum.FillDirection.Vertical, 2)
			local list, errs, warns = diagnostics.all()
			if tabButtons.problems then
				tabButtons.problems.Text = string.format("PROBLEMS (%d)", errs + warns)
			end
			if #list == 0 then
				P.label(problemsScroll, {
					size = UDim2.new(1, 0, 0, 22),
					text = "No problems have been detected in the workspace.",
					color = theme.color.muted,
					textSize = 12,
					zIndex = 23,
				})
				return
			end
			for idx, item in ipairs(list) do
				local row = P.button(problemsScroll, {
					size = UDim2.new(1, 0, 0, 22),
					hoverBg = theme.color.hover,
					alignX = Enum.TextXAlignment.Left,
					mono = true,
					textSize = 12,
					color = item.severity == "error" and theme.color.bad or theme.color.warn,
					text = string.format(
						"  %s  %s:%d — %s",
						item.severity == "error" and "⊗" or "⚠",
						tostring(item.path or "buffer"),
						item.line or 1,
						item.message
					),
					order = idx,
					zIndex = 23,
					onClick = function()
						if item.path and item.path ~= "" then
							codeStore.openFile(item.path, { line = item.line or 1 })
						elseif item.docId then
							codeStore.activate(item.docId)
							codeStore.jumpToLine(item.docId, item.line or 1, 1)
						end
					end,
				})
				row.TextTruncate = Enum.TextTruncate.AtEnd
			end
		end

		local function renderOutput()
			outputScroll:ClearAllChildren()
			P.pad(outputScroll, 6, 8, 6, 8)
			P.list(outputScroll, Enum.FillDirection.Vertical, 1)
			local items = log.list("all")
			local startIdx = math.max(1, #items - 80)
			local order = 0
			for i = startIdx, #items do
				order = order + 1
				local entry = items[i]
				local col = theme.color.editorText
				if entry.level == "error" then col = theme.color.bad
				elseif entry.level == "warn" then col = theme.color.warn
				elseif entry.channel == "github" then col = theme.color.good end
				P.label(outputScroll, {
					size = UDim2.new(1, 0, 0, 18),
					mono = true,
					textSize = 12,
					color = col,
					text = string.format("[%s][%s] %s", entry.time, entry.channel, entry.message),
					truncate = true,
					order = order,
					zIndex = 23,
				})
			end
		end

		local function renderTerminal()
			termScroll:ClearAllChildren()
			P.pad(termScroll, 6, 10, 4, 10)
			P.list(termScroll, Enum.FillDirection.Vertical, 2)
			local startIdx = math.max(1, #terminalCmds.lines - 90)
			local order = 0
			for i = startIdx, #terminalCmds.lines do
				order = order + 1
				local line = terminalCmds.lines[i]
				local isPrompt = line:find("^vsrblx:") ~= nil
				P.label(termScroll, {
					size = UDim2.new(1, 0, 0, 18),
					mono = true,
					textSize = 12,
					color = isPrompt and theme.color.accent or theme.color.editorText,
					text = line,
					wrap = true,
					order = order,
					zIndex = 24,
				})
			end
			termScroll.CanvasPosition = Vector2.new(0, 99999)
		end

		local function renderHttp()
			httpScroll:ClearAllChildren()
			P.pad(httpScroll, 6, 8, 6, 8)
			P.list(httpScroll, Enum.FillDirection.Vertical, 2)
			if #http.history == 0 then
				P.label(httpScroll, {
					size = UDim2.new(1, 0, 0, 22),
					text = "No Executor HTTP requests sent yet. Clone or sync a GitHub repo to inspect traffic.",
					color = theme.color.muted,
					textSize = 12,
					zIndex = 23,
				})
				return
			end
			local order = 0
			for i = #http.history, math.max(1, #http.history - 50), -1 do
				order = order + 1
				local h = http.history[i]
				P.label(httpScroll, {
					size = UDim2.new(1, 0, 0, 19),
					mono = true,
					textSize = 12,
					color = h.ok and theme.color.good or theme.color.bad,
					text = string.format("[%s] %-6s %3d (%4d ms, %6s B)  %s", h.time, h.method, h.status, h.ms, tostring(h.bytes), h.url),
					truncate = true,
					order = order,
					zIndex = 23,
				})
			end
		end

		local function selectTab(id)
			activeTab = id
			config.set("workbench.activePanelTab", id, { quiet = true })
			problemsScroll.Visible = (id == "problems")
			outputScroll.Visible = (id == "output")
			termPane.Visible = (id == "terminal")
			httpScroll.Visible = (id == "http")
			for tid, btn in pairs(tabButtons) do
				btn.TextColor3 = (tid == id) and theme.color.tabActiveText or theme.color.muted
			end
			if id == "problems" then renderProblems()
			elseif id == "output" then renderOutput()
			elseif id == "terminal" then renderTerminal()
			elseif id == "http" then renderHttp() end
		end

		for idx, spec in ipairs(TABS) do
			local btn = P.button(tabRow, {
				name = "PanelTab_" .. spec.id,
				size = UDim2.fromOffset(#spec.label * 7 + 26, 26),
				text = spec.label,
				bold = true,
				textSize = 11,
				color = theme.color.muted,
				order = idx,
				zIndex = 23,
				onClick = function() selectTab(spec.id) end,
			})
			tabButtons[spec.id] = btn
		end

		diagnostics.changed:connect(renderProblems)
		log.added:connect(function() if activeTab == "output" then renderOutput() end end)
		log.cleared:connect(renderOutput)
		terminalCmds.changed:connect(renderTerminal)
		http.changed:connect(function() if activeTab == "http" then renderHttp() end end)
		theme.changed:connect(function()
			root.BackgroundColor3 = theme.color.panelBg
			topRule.BackgroundColor3 = theme.color.border
			header.BackgroundColor3 = theme.color.panelHeader
			bodyArea.BackgroundColor3 = theme.color.panelBg
			promptRow.BackgroundColor3 = theme.color.sideBar
			promptGlyph.TextColor3 = theme.color.accent
			selectTab(activeTab)
		end)

		renderProblems()
		selectTab(activeTab)

		return {
			root = root,
			selectTab = selectTab,
			focusTerminal = function()
				selectTab("terminal")
				task.defer(function() pcall(function() termInput:CaptureFocus() end) end)
			end,
		}
	end

	return M
end
