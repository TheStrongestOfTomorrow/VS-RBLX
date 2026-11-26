-- VS Code Bottom Integrated Panel:
-- PROBLEMS, TODOS, OUTPUT (with Live Roblox LogService channel filters & clickable stack-jump),
-- Multi-Session TERMINAL (`+` new shell, `✕` close, `Up`/`Down` history, `Tab` autocomplete),
-- and HTTP / GIT traffic inspector.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local config = env.require("runtime/config")
	local dispose = env.require("runtime/dispose")
	local log = env.require("runtime/log")
	local robloxConsole = env.require("runtime/roblox_console")
	local diagnostics = env.require("runtime/diagnostics")
	local todoScanner = env.require("runtime/todo_scanner")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")
	local http = env.require("net/http")
	local terminalCmds = env.require("tools/terminal_cmds")

	local M = {}

	local TABS = {
		{ id = "problems", label = "PROBLEMS" },
		{ id = "todos", label = "TODOS" },
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

		local tabRow = P.scroll(header, {
			name = "PanelHeaderTabs",
			size = UDim2.new(1, -112, 1, 0),
			pos = UDim2.fromOffset(6, 0),
			direction = Enum.ScrollingDirection.X,
			autoCanvas = Enum.AutomaticSize.X,
			barThickness = 2,
			zIndex = 22,
		})
		P.list(tabRow, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

		local tabButtons = {}
		local activeTab = config.get("workbench.activePanelTab", "terminal")

		local bodyArea = P.frame(root, {
			name = "PanelBody",
			size = UDim2.new(1, 0, 1, -29),
			pos = UDim2.fromOffset(0, 29),
			zIndex = 21,
		})
		bodyArea.BackgroundTransparency = 1

		local rightBtns = P.frame(header, {
			size = UDim2.fromOffset(102, 28),
			pos = UDim2.new(1, -106, 0, 0),
			zIndex = 22,
		})
		P.list(rightBtns, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

		local newTermBtn = P.button(rightBtns, {
			name = "NewTerminalSessionBtn",
			size = UDim2.fromOffset(24, 22),
			text = "+",
			bold = true,
			textSize = 13,
			color = theme.color.tabActiveText,
			radius = 3,
			order = 1,
			zIndex = 23,
			onClick = function()
				terminalCmds.newSession()
			end,
		})

		P.button(rightBtns, {
			name = "ClearPanelBtn",
			size = UDim2.fromOffset(38, 22),
			text = "Clear",
			textSize = 11,
			color = theme.color.muted,
			radius = 3,
			order = 2,
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
			order = 3,
			zIndex = 23,
			onClick = function()
				if onClosePanel then onClosePanel() end
			end,
		})

		-- 1. PROBLEMS view
		local problemsScroll = P.scroll(bodyArea, { name = "ProblemsView", visible = false, zIndex = 22 })
		P.pad(problemsScroll, 6, 8, 6, 8)
		P.list(problemsScroll, Enum.FillDirection.Vertical, 2)

		-- 2. TODOS view
		local todosPane = P.frame(bodyArea, { name = "TodosView", size = UDim2.fromScale(1, 1), visible = false, zIndex = 22 })
		local todoFilterRow = P.frame(todosPane, {
			name = "TodoFilterBar",
			size = UDim2.new(1, 0, 0, 24),
			pos = UDim2.fromOffset(8, 3),
			zIndex = 23,
		})
		P.list(todoFilterRow, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

		local todosScroll = P.scroll(todosPane, {
			name = "TodosScroll",
			size = UDim2.new(1, 0, 1, -28),
			pos = UDim2.fromOffset(0, 28),
			zIndex = 23,
		})
		P.pad(todosScroll, 4, 8, 6, 8)
		P.list(todosScroll, Enum.FillDirection.Vertical, 2)

		local activeTodoFilter = "all"
		local renderTodos

		local FILTER_CHIPS = {
			{ id = "all", label = "All" },
			{ id = "fixme", label = "FIXME / BUG" },
			{ id = "todo", label = "TODO / HACK" },
			{ id = "note", label = "NOTE" },
		}
		local filterBtns = {}
		for idx, chip in ipairs(FILTER_CHIPS) do
			local fb = P.button(todoFilterRow, {
				name = "TodoFilter_" .. chip.id,
				size = UDim2.fromOffset(#chip.label * 6 + 20, 20),
				bg = chip.id == activeTodoFilter and theme.color.listActive or theme.color.inputBg,
				hoverBg = theme.color.hover,
				text = chip.label,
				textSize = 10,
				bold = true,
				color = theme.color.sideBarText,
				radius = 10,
				order = idx,
				zIndex = 24,
				activeState = function() return chip.id == activeTodoFilter end,
				onClick = function()
					activeTodoFilter = chip.id
					for fid, b in pairs(filterBtns) do
						b.BackgroundColor3 = (fid == activeTodoFilter) and theme.color.listActive or theme.color.inputBg
						b.BackgroundTransparency = 0
					end
					if renderTodos then renderTodos() end
				end,
			})
			fb.BackgroundTransparency = 0
			filterBtns[chip.id] = fb
		end

		-- 3. OUTPUT view (with Channel Filter Pills + Clickable Stack-Trace Jump!)
		local outputPane = P.frame(bodyArea, { name = "OutputView", size = UDim2.fromScale(1, 1), visible = false, zIndex = 22 })
		local outFilterRow = P.frame(outputPane, {
			name = "OutputFilterBar",
			size = UDim2.new(1, 0, 0, 24),
			pos = UDim2.fromOffset(8, 3),
			zIndex = 23,
		})
		P.list(outFilterRow, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

		local outputScroll = P.scroll(outputPane, {
			name = "OutputScroll",
			size = UDim2.new(1, 0, 1, -28),
			pos = UDim2.fromOffset(0, 28),
			zIndex = 23,
		})
		P.pad(outputScroll, 4, 8, 6, 8)
		P.list(outputScroll, Enum.FillDirection.Vertical, 1)

		local activeOutChannel = "all"
		local renderOutput
		local OUT_CHANNELS = {
			{ id = "all", label = "All" },
			{ id = "roblox", label = "Roblox LogService" },
			{ id = "execution", label = "Execution" },
			{ id = "github", label = "GitHub / FS" },
		}
		local outChannelBtns = {}
		for idx, chSpec in ipairs(OUT_CHANNELS) do
			local cb = P.button(outFilterRow, {
				name = "OutFilter_" .. chSpec.id,
				size = UDim2.fromOffset(#chSpec.label * 6 + 18, 20),
				bg = chSpec.id == activeOutChannel and theme.color.listActive or theme.color.inputBg,
				hoverBg = theme.color.hover,
				text = chSpec.label,
				textSize = 10,
				bold = true,
				color = theme.color.sideBarText,
				radius = 10,
				order = idx,
				zIndex = 24,
				activeState = function() return chSpec.id == activeOutChannel end,
				onClick = function()
					activeOutChannel = chSpec.id
					for cid, b in pairs(outChannelBtns) do
						b.BackgroundColor3 = (cid == activeOutChannel) and theme.color.listActive or theme.color.inputBg
						b.BackgroundTransparency = 0
					end
					if renderOutput then renderOutput() end
				end,
			})
			cb.BackgroundTransparency = 0
			outChannelBtns[chSpec.id] = cb
		end

		-- 4. Multi-Tab TERMINAL view
		local termPane = P.frame(bodyArea, { name = "TerminalView", size = UDim2.fromScale(1, 1), visible = false, zIndex = 22 })
		local sessionBar = P.frame(termPane, {
			name = "TerminalSessionBar",
			size = UDim2.new(1, 0, 0, 22),
			bg = theme.color.sideBarHeader,
			zIndex = 23,
		})
		P.pad(sessionBar, 0, 6, 0, 6)
		P.list(sessionBar, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

		local termScroll = P.scroll(termPane, {
			name = "TerminalScroll",
			size = UDim2.new(1, 0, 1, -52),
			pos = UDim2.fromOffset(0, 22),
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
			size = UDim2.fromOffset(108, 28),
			pos = UDim2.fromOffset(8, 0),
			text = "default:~ ❯",
			mono = true,
			bold = true,
			textSize = 11,
			color = theme.color.accent,
			truncate = true,
			zIndex = 24,
		})
		local _, termInput = P.input(promptRow, {
			name = "TerminalCommandInput",
			size = UDim2.new(1, -168, 0, 24),
			pos = UDim2.fromOffset(118, 2),
			mono = true,
			placeholder = "Type command (help, ls -l, tree, git diff, rblx services, bundle...)",
			zIndex = 24,
		})
		local tabCompBtn = P.button(promptRow, {
			name = "TerminalAutocompleteBtn",
			size = UDim2.fromOffset(42, 22),
			pos = UDim2.new(1, -46, 0, 3),
			bg = theme.color.inputBg,
			hoverBg = theme.color.hover,
			text = "Tab ⇥",
			mono = true,
			textSize = 10,
			radius = 3,
			zIndex = 24,
			onClick = function()
				local completed, matches = terminalCmds.autocomplete(termInput.Text)
				termInput.Text = completed
				pcall(function() termInput.CursorPosition = #completed + 1 end)
				if #matches > 1 then
					terminalCmds.print("Completions: " .. table.concat(matches, "   "))
				end
			end,
		})

		local termFocused = false
		termInput.Focused:Connect(function() termFocused = true end)
		termInput.FocusLost:Connect(function(enterPressed)
			termFocused = false
			if enterPressed and termInput.Text ~= "" then
				local cmd = termInput.Text
				termInput.Text = ""
				terminalCmds.execute(cmd)
				task.defer(function() pcall(function() termInput:CaptureFocus() end) end)
			end
		end)

		if env.uis then
			dispose.connection(env.uis.InputBegan:Connect(function(input)
				if not termFocused then return end
				local kc = input.KeyCode
				if kc == Enum.KeyCode.Up then
					local prev = terminalCmds.historyPrev()
					if prev ~= nil then
						termInput.Text = prev
						pcall(function() termInput.CursorPosition = #prev + 1 end)
					end
				elseif kc == Enum.KeyCode.Down then
					local nxt = terminalCmds.historyNext()
					if nxt ~= nil then
						termInput.Text = nxt
						pcall(function() termInput.CursorPosition = #nxt + 1 end)
					end
				elseif kc == Enum.KeyCode.Tab then
					task.defer(function()
						local clean = termInput.Text:gsub("\t", "")
						local completed, matches = terminalCmds.autocomplete(clean)
						termInput.Text = completed
						pcall(function() termInput.CursorPosition = #completed + 1 end)
						if #matches > 1 then
							terminalCmds.print("Completions: " .. table.concat(matches, "   "))
						end
					end)
				end
			end))
		end

		-- 5. HTTP / GIT view
		local httpScroll = P.scroll(bodyArea, { name = "HttpView", visible = false, zIndex = 22 })
		P.pad(httpScroll, 6, 8, 6, 8)
		P.list(httpScroll, Enum.FillDirection.Vertical, 2)

		local function updateTabButtonWidth(btn, txt)
			if not btn then return end
			btn.Text = txt
			btn.Size = UDim2.fromOffset(#txt * 7 + 16, 26)
		end

		local function renderProblems()
			problemsScroll:ClearAllChildren()
			P.pad(problemsScroll, 6, 8, 6, 8)
			P.list(problemsScroll, Enum.FillDirection.Vertical, 2)
			local list, errs, warns = diagnostics.all()
			updateTabButtonWidth(tabButtons.problems, string.format("PROBLEMS (%d)", errs + warns))
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

		renderTodos = function()
			local items, counts = todoScanner.scanAll()
			updateTabButtonWidth(tabButtons.todos, string.format("TODOS (%d)", counts.total or 0))
			if activeTab ~= "todos" then return end

			todosScroll:ClearAllChildren()
			P.pad(todosScroll, 4, 8, 6, 8)
			P.list(todosScroll, Enum.FillDirection.Vertical, 2)

			local shown = 0
			for idx, item in ipairs(items) do
				if activeTodoFilter == "all" or item.group == activeTodoFilter then
					shown = shown + 1
					local badgeCol = theme.color.warn
					if item.group == "fixme" then
						badgeCol = theme.color.bad
					elseif item.group == "note" then
						badgeCol = Color3.fromRGB(79, 193, 255)
					end

					local row = P.button(todosScroll, {
						name = "TodoItem_" .. tostring(shown),
						size = UDim2.new(1, 0, 0, 22),
						hoverBg = theme.color.hover,
						text = "",
						order = idx,
						zIndex = 24,
						onClick = function()
							if item.docId and codeStore.get(item.docId) then
								codeStore.activate(item.docId)
								codeStore.jumpToLine(item.docId, item.line or 1, item.col or 1)
							elseif item.path and item.path ~= "" then
								codeStore.openFile(item.path, { line = item.line or 1, col = item.col or 1 })
							end
						end,
					})
					local pill = P.frame(row, {
						size = UDim2.fromOffset(48, 16),
						pos = UDim2.fromOffset(4, 3),
						bg = badgeCol,
						transparency = 0.78,
						border = badgeCol,
						radius = 3,
						zIndex = 25,
					})
					P.label(pill, {
						size = UDim2.fromScale(1, 1),
						text = item.tag,
						mono = true,
						bold = true,
						textSize = 10,
						color = badgeCol,
						alignX = Enum.TextXAlignment.Center,
						zIndex = 26,
					})
					P.label(row, {
						size = UDim2.new(1, -62, 1, 0),
						pos = UDim2.fromOffset(60, 0),
						mono = true,
						textSize = 12,
						color = theme.color.editorText,
						text = string.format("%s:%d — %s", tostring(item.path or "buffer"), item.line or 1, item.message),
						truncate = true,
						zIndex = 25,
					})
				end
			end

			if shown == 0 then
				P.label(todosScroll, {
					size = UDim2.new(1, 0, 0, 22),
					text = "No TODO / FIXME / NOTE comments found for this filter.",
					color = theme.color.muted,
					textSize = 12,
					zIndex = 24,
				})
			end
		end

		renderOutput = function()
			outputScroll:ClearAllChildren()
			P.pad(outputScroll, 4, 8, 6, 8)
			P.list(outputScroll, Enum.FillDirection.Vertical, 1)

			local allItems = log.list("all")
			local filtered = {}
			for _, entry in ipairs(allItems) do
				if activeOutChannel == "all"
					or entry.channel == activeOutChannel
					or (activeOutChannel == "github" and (entry.channel == "fs" or entry.channel == "git")) then
					filtered[#filtered + 1] = entry
				end
			end

			local startIdx = math.max(1, #filtered - 85)
			local order = 0
			for i = startIdx, #filtered do
				order = order + 1
				local entry = filtered[i]
				local col = theme.color.editorText
				if entry.level == "error" then col = theme.color.bad
				elseif entry.level == "warn" then col = theme.color.warn
				elseif entry.channel == "github" or entry.channel == "roblox" then col = theme.color.good end

				local loc = robloxConsole.parseStackLocation(entry.message)
				local jumpHint = loc and "  ↗" or ""
				local row = P.button(outputScroll, {
					name = "OutputRow_" .. tostring(order),
					size = UDim2.new(1, 0, 0, 19),
					hoverBg = loc and theme.color.hover or nil,
					alignX = Enum.TextXAlignment.Left,
					mono = true,
					textSize = 12,
					color = col,
					text = string.format("[%s][%s] %s%s", entry.time, entry.channel, entry.message, jumpHint),
					order = order,
					zIndex = 24,
					onClick = function()
						if loc then
							robloxConsole.jumpToLogEntry(entry)
						end
					end,
				})
				row.TextTruncate = Enum.TextTruncate.AtEnd
			end
			outputScroll.CanvasPosition = Vector2.new(0, 99999)
		end

		local function renderTerminal()
			-- Update session tabs
			sessionBar:ClearAllChildren()
			P.pad(sessionBar, 0, 6, 0, 6)
			P.list(sessionBar, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

			for idx, sess in ipairs(terminalCmds.sessions) do
				local isCur = (sess.id == terminalCmds.activeSessionId)
				local chip = P.frame(sessionBar, {
					name = "TermSession_" .. sess.id,
					size = UDim2.fromOffset(#sess.title * 7 + 34, 18),
					bg = isCur and theme.color.accent or theme.color.inputBg,
					radius = 3,
					order = idx,
					zIndex = 24,
				})
				P.button(chip, {
					size = UDim2.new(1, -18, 1, 0),
					pos = UDim2.fromOffset(4, 0),
					alignX = Enum.TextXAlignment.Left,
					mono = true,
					bold = isCur,
					textSize = 10,
					color = isCur and Color3.fromRGB(255, 255, 255) or theme.color.sideBarText,
					text = "❯ " .. sess.title,
					zIndex = 25,
					onClick = function()
						terminalCmds.switchSession(sess.id)
					end,
				})
				P.button(chip, {
					name = "CloseTermSession_" .. sess.id,
					size = UDim2.fromOffset(16, 16),
					pos = UDim2.new(1, -17, 0, 1),
					text = "✕",
					textSize = 9,
					color = isCur and Color3.fromRGB(255, 255, 255) or theme.color.muted,
					radius = 2,
					zIndex = 25,
					onClick = function()
						terminalCmds.closeSession(sess.id)
					end,
				})
			end

			local curSess = terminalCmds.activeSession()
			local cwdShort = (curSess and curSess.cwd ~= "") and ("~/" .. curSess.cwd) or "~"
			promptGlyph.Text = string.format("%s:%s ❯", workspaceFs.activeName, cwdShort)

			termScroll:ClearAllChildren()
			P.pad(termScroll, 6, 10, 4, 10)
			P.list(termScroll, Enum.FillDirection.Vertical, 2)
			local startIdx = math.max(1, #terminalCmds.lines - 95)
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
			todosPane.Visible = (id == "todos")
			outputPane.Visible = (id == "output")
			termPane.Visible = (id == "terminal")
			httpScroll.Visible = (id == "http")
			newTermBtn.Visible = (id == "terminal")
			for tid, btn in pairs(tabButtons) do
				btn.TextColor3 = (tid == id) and theme.color.tabActiveText or theme.color.muted
			end
			if id == "problems" then renderProblems()
			elseif id == "todos" then renderTodos()
			elseif id == "output" then renderOutput()
			elseif id == "terminal" then renderTerminal()
			elseif id == "http" then renderHttp() end
		end

		for idx, spec in ipairs(TABS) do
			local btn = P.button(tabRow, {
				name = "PanelTab_" .. spec.id,
				size = UDim2.fromOffset(#spec.label * 7 + 18, 26),
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
		todoScanner.changed:connect(renderTodos)
		log.added:connect(function() if activeTab == "output" then renderOutput() end end)
		log.cleared:connect(renderOutput)
		terminalCmds.changed:connect(renderTerminal)
		workspaceFs.changed:connect(function() if activeTab == "terminal" then renderTerminal() end end)
		http.changed:connect(function() if activeTab == "http" then renderHttp() end end)
		theme.changed:connect(function()
			root.BackgroundColor3 = theme.color.panelBg
			topRule.BackgroundColor3 = theme.color.border
			header.BackgroundColor3 = theme.color.panelHeader
			sessionBar.BackgroundColor3 = theme.color.sideBarHeader
			promptRow.BackgroundColor3 = theme.color.sideBar
			promptGlyph.TextColor3 = theme.color.accent
			tabCompBtn.BackgroundColor3 = theme.color.inputBg
			for fid, b in pairs(filterBtns) do
				b.BackgroundColor3 = (fid == activeTodoFilter) and theme.color.listActive or theme.color.inputBg
				b.TextColor3 = theme.color.sideBarText
			end
			for cid, b in pairs(outChannelBtns) do
				b.BackgroundColor3 = (cid == activeOutChannel) and theme.color.listActive or theme.color.inputBg
				b.TextColor3 = theme.color.sideBarText
			end
			selectTab(activeTab)
		end)

		renderProblems()
		renderTodos()
		selectTab(activeTab)

		return {
			root = root,
			header = header,
			promptRow = promptRow,
			selectTab = selectTab,
			setOutputChannel = function(ch)
				activeOutChannel = ch or "all"
				if activeTab == "output" then renderOutput() end
			end,
			setTransparency = function(bgTrans)
				root.BackgroundTransparency = bgTrans
				header.BackgroundTransparency = bgTrans
				sessionBar.BackgroundTransparency = bgTrans
				promptRow.BackgroundTransparency = bgTrans
			end,
			focusTerminal = function()
				selectTab("terminal")
				task.defer(function() pcall(function() termInput:CaptureFocus() end) end)
			end,
		}
	end

	return M
end
