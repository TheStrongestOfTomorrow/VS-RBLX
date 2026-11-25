-- Authentic VS Code 22px Bottom Status Bar:
-- Left: Executor Host / Disk indicator, Interactive Branch Switcher (`⎇`), Sync button,
-- Eyedropper Picker (`🎯`), Error/Warn counts, TODO counter.
-- Right: Cursor Ln/Col, Spaces/Tab size, UTF-8, Language Mode Picker.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local overlay = env.require("ui/overlay")
	local caps = env.require("runtime/caps")
	local fsx = env.require("runtime/fsx")
	local config = env.require("runtime/config")
	local languages = env.require("runtime/languages")
	local codeStore = env.require("runtime/code_store")
	local diagnostics = env.require("runtime/diagnostics")
	local todoScanner = env.require("runtime/todo_scanner")
	local gitState = env.require("runtime/git_state")
	local githubSync = env.require("tools/github_sync")
	local commands = env.require("runtime/command_catalog")

	local M = {}

	function M.new(parent)
		local h = theme.sizes.statusBar
		local bar = P.frame(parent, {
			name = "StatusBar",
			size = UDim2.new(1, 0, 0, h),
			pos = UDim2.new(0, 0, 1, -h),
			bg = theme.color.statusBar,
			zIndex = 30,
		})

		local leftRow = P.frame(bar, {
			name = "StatusLeft",
			size = UDim2.new(0.60, 0, 1, 0),
			zIndex = 31,
		})
		P.list(leftRow, Enum.FillDirection.Horizontal, 2, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

		local hostPill = P.button(leftRow, {
			name = "HostBadge",
			size = UDim2.fromOffset(136, h),
			bg = theme.color.statusBarRemote,
			hoverBg = theme.color.accentHover,
			color = theme.color.statusBarText,
			bold = true,
			textSize = 11,
			text = string.format(">< %s | %s", caps.executor:sub(1, 10), fsx.isBackedByDisk() and "Disk" or "Mem"),
			order = 1,
			zIndex = 32,
			onClick = function() commands.run("view.extensions") end,
		})

		local branchBtn = P.button(leftRow, {
			name = "BranchBadge",
			size = UDim2.fromOffset(108, h),
			color = theme.color.statusBarText,
			textSize = 11,
			text = "⎇ main",
			order = 2,
			zIndex = 32,
			onClick = function()
				commands.run("github.switchBranch")
			end,
		})

		local syncBtn = P.button(leftRow, {
			name = "SyncBadge",
			size = UDim2.fromOffset(82, h),
			color = theme.color.statusBarText,
			textSize = 11,
			text = "↻ Sync GitHub",
			order = 3,
			zIndex = 32,
			onClick = function()
				if gitState.repo then
					commands.run("github.pull")
				else
					commands.run("github.clone")
				end
			end,
		})

		local pickerBtn = P.button(leftRow, {
			name = "EyedropperBadge",
			size = UDim2.fromOffset(58, h),
			color = theme.color.statusBarText,
			textSize = 11,
			text = "🎯 Pick",
			order = 4,
			zIndex = 32,
			onClick = function()
				commands.run("roblox.pickInstance")
			end,
		})

		local problemsBtn = P.button(leftRow, {
			name = "ProblemsBadge",
			size = UDim2.fromOffset(68, h),
			color = theme.color.statusBarText,
			textSize = 11,
			text = "⊗ 0  ⚠ 0",
			order = 5,
			zIndex = 32,
			onClick = function() commands.run("view.problems") end,
		})

		local todosBtn = P.button(leftRow, {
			name = "TodosBadge",
			size = UDim2.fromOffset(64, h),
			color = theme.color.statusBarText,
			textSize = 11,
			text = "✓ 0 TODO",
			order = 6,
			zIndex = 32,
			onClick = function() commands.run("view.todos") end,
		})

		local rightRow = P.frame(bar, {
			name = "StatusRight",
			size = UDim2.new(0.40, -8, 1, 0),
			pos = UDim2.new(0.60, 0, 0, 0),
			zIndex = 31,
		})
		P.list(rightRow, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

		local cursorLbl = P.button(rightRow, {
			name = "CursorBadge",
			size = UDim2.fromOffset(92, h),
			color = theme.color.statusBarText,
			textSize = 11,
			text = "Ln 1, Col 1",
			order = 1,
			zIndex = 32,
			onClick = function() commands.run("editor.gotoLine") end,
		})

		local indentBtn = P.button(rightRow, {
			name = "IndentBadge",
			size = UDim2.fromOffset(66, h),
			color = theme.color.statusBarText,
			textSize = 11,
			text = "Spaces: 4",
			order = 2,
			zIndex = 32,
			onClick = function()
				local cur = config.get("editor.insertSpaces", true)
				config.set("editor.insertSpaces", not cur)
			end,
		})

		local utfLbl = P.label(rightRow, {
			size = UDim2.fromOffset(42, h),
			text = "UTF-8",
			textSize = 11,
			color = theme.color.statusBarText,
			alignX = Enum.TextXAlignment.Center,
			order = 3,
			zIndex = 32,
		})

		local langBtn = P.button(rightRow, {
			name = "LanguageBadge",
			size = UDim2.fromOffset(86, h),
			color = theme.color.statusBarText,
			bold = true,
			textSize = 11,
			text = "Luau",
			order = 4,
			zIndex = 32,
		})
		langBtn.Activated:Connect(function()
			local doc = codeStore.active()
			if not doc then return end
			local menuItems = {}
			for _, lang in ipairs(languages.list) do
				menuItems[#menuItems + 1] = {
					label = lang.name,
					shortcut = "." .. (lang.extensions[1] or ""),
					onClick = function()
						codeStore.setLanguage(doc.id, lang.id)
					end,
				}
			end
			local p = langBtn.AbsolutePosition
			overlay.dropdown(math.max(12, p.X - 90), math.max(20, p.Y - (#menuItems * 24 + 14)), menuItems, 185)
		end)

		local function refresh()
			local doc = codeStore.active()
			if doc then
				cursorLbl.Text = string.format("Ln %d, Col %d", doc.view.line or 1, doc.view.col or 1)
				langBtn.Text = languages.get(doc.langId).name
			else
				cursorLbl.Text = "Ln 1, Col 1"
				langBtn.Text = "Luau"
			end

			local spaces = config.get("editor.insertSpaces", true)
			local tabSz = tonumber(config.get("editor.tabSize", 4)) or 4
			indentBtn.Text = spaces and ("Spaces: " .. tostring(tabSz)) or ("Tab Size: " .. tostring(tabSz))

			local st = gitState.status()
			local branchLabel = st.branch or "main"
			if st.repo then
				branchLabel = branchLabel .. (st.total > 0 and "*" or "")
			end
			branchBtn.Text = "⎇ " .. branchLabel

			if githubSync.busy then
				syncBtn.Text = "↻ Syncing..."
			elseif st.repo then
				syncBtn.Text = "↻ " .. st.repo:match("([^/]+)$")
			else
				syncBtn.Text = "↻ Clone Repo"
			end

			local _, errs, warns = diagnostics.all()
			problemsBtn.Text = string.format("⊗ %d  ⚠ %d", errs, warns)

			local _, todoCounts = todoScanner.scanAll()
			todosBtn.Text = string.format("✓ %d TODO", todoCounts.total or 0)
		end

		codeStore.changed:connect(refresh)
		codeStore.cursorChanged:connect(refresh)
		diagnostics.changed:connect(refresh)
		todoScanner.changed:connect(refresh)
		gitState.changed:connect(refresh)
		githubSync.progress:connect(refresh)
		config.changed:connect(refresh)
		theme.changed:connect(function()
			bar.BackgroundColor3 = theme.color.statusBar
			hostPill.BackgroundColor3 = theme.color.statusBarRemote
			for _, w in ipairs({ hostPill, branchBtn, syncBtn, pickerBtn, problemsBtn, todosBtn, cursorLbl, indentBtn, utfLbl, langBtn }) do
				w.TextColor3 = theme.color.statusBarText
			end
		end)

		refresh()
		return {
			root = bar,
			branchButton = branchBtn,
			refresh = refresh,
		}
	end

	return M
end
