-- VS Code Source Control (`Ctrl+Shift+G`):
-- Clone/Pull/Commit/Push via Executor HTTP, Stage/Unstage/Discard changes,
-- 1-click Side-by-Side Diff Viewer, GitHub Gist Import/Publish, and Commit History.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local overlay = env.require("ui/overlay")
	local codeStore = env.require("runtime/code_store")
	local gitState = env.require("runtime/git_state")
	local githubSync = env.require("tools/github_sync")
	local githubConnect = env.require("ui/panels/github_connect")
	local commands = env.require("runtime/command_catalog")

	local M = {}

	function M.new(parent)
		local root = P.frame(parent, {
			name = "SourceControlViewlet",
			size = UDim2.fromScale(1, 1),
			visible = false,
			zIndex = 21,
		})
		P.pad(root, 6, 10, 6, 10)

		P.label(root, {
			size = UDim2.new(1, 0, 0, 22),
			text = "SOURCE CONTROL (GITHUB)",
			bold = true,
			textSize = 11,
			color = theme.color.muted,
			zIndex = 22,
		})

		local repoStatusLbl = P.label(root, {
			size = UDim2.new(1, 0, 0, 18),
			pos = UDim2.fromOffset(0, 22),
			textSize = 11,
			color = theme.color.accent,
			text = "No GitHub repository linked",
			truncate = true,
			zIndex = 22,
		})

		-- Row 1: Connect / Pull / Branch
		local btnRow = P.frame(root, {
			size = UDim2.new(1, 0, 0, 26),
			pos = UDim2.fromOffset(0, 42),
			zIndex = 22,
		})
		P.list(btnRow, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

		P.button(btnRow, {
			name = "ScmConnectBtn",
			size = UDim2.fromOffset(74, 24),
			bg = theme.color.inputBg,
			hoverBg = theme.color.hover,
			text = "Clone / PAT",
			textSize = 11,
			radius = 4,
			order = 1,
			zIndex = 23,
			onClick = function() githubConnect.openModal() end,
		})
		P.button(btnRow, {
			name = "ScmPullBtn",
			size = UDim2.fromOffset(52, 24),
			bg = theme.color.inputBg,
			hoverBg = theme.color.hover,
			text = "↻ Pull",
			textSize = 11,
			radius = 4,
			order = 2,
			zIndex = 23,
			onClick = function()
				task.spawn(function()
					local snap, err = githubSync.pull()
					if snap then overlay.toast("Pulled " .. snap.fullName, "good", 3)
					else overlay.toast("Pull failed: " .. tostring(err), "bad", 4) end
				end)
			end,
		})
		P.button(btnRow, {
			name = "ScmBranchBtn",
			size = UDim2.fromOffset(72, 24),
			bg = theme.color.inputBg,
			hoverBg = theme.color.hover,
			text = "⎇ Branch",
			textSize = 11,
			radius = 4,
			order = 3,
			zIndex = 23,
			onClick = function()
				commands.run("github.switchBranch")
			end,
		})

		-- Row 2: GitHub Gists (Import & Publish)
		local gistRow = P.frame(root, {
			size = UDim2.new(1, 0, 0, 24),
			pos = UDim2.fromOffset(0, 72),
			zIndex = 22,
		})
		P.list(gistRow, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

		P.button(gistRow, {
			name = "ImportGistBtn",
			size = UDim2.fromOffset(96, 22),
			bg = theme.color.inputBg,
			hoverBg = theme.color.hover,
			text = "⬇ Import Gist",
			textSize = 11,
			radius = 4,
			order = 1,
			zIndex = 23,
			onClick = function() commands.run("github.importGist") end,
		})
		P.button(gistRow, {
			name = "PublishGistBtn",
			size = UDim2.fromOffset(102, 22),
			bg = theme.color.inputBg,
			hoverBg = theme.color.hover,
			text = "⬆ Publish Gist",
			textSize = 11,
			radius = 4,
			order = 2,
			zIndex = 23,
			onClick = function() commands.run("github.publishGist") end,
		})

		local _, msgInput = P.input(root, {
			name = "CommitMessageInput",
			size = UDim2.new(1, 0, 0, 28),
			pos = UDim2.fromOffset(0, 100),
			placeholder = "Message (Commit & Push via HTTP)",
			zIndex = 22,
		})

		local commitBtn = P.button(root, {
			name = "CommitAndPushBtn",
			size = UDim2.new(1, 0, 0, 28),
			pos = UDim2.fromOffset(0, 132),
			bg = theme.color.accent,
			hoverBg = theme.color.accentHover,
			color = Color3.fromRGB(255, 255, 255),
			bold = true,
			text = "✓ Commit & Push to GitHub",
			textSize = 12,
			radius = 4,
			zIndex = 22,
		})

		-- Stage All / Unstage All bar
		local stageBar = P.frame(root, {
			size = UDim2.new(1, 0, 0, 22),
			pos = UDim2.fromOffset(0, 164),
			zIndex = 22,
		})
		P.list(stageBar, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
		P.button(stageBar, {
			name = "StageAllBtn",
			size = UDim2.fromOffset(72, 20),
			bg = theme.color.inputBg,
			hoverBg = theme.color.hover,
			text = "+ Stage All",
			textSize = 10,
			radius = 3,
			order = 1,
			zIndex = 23,
			onClick = function() gitState.stageAll() end,
		})
		P.button(stageBar, {
			name = "UnstageAllBtn",
			size = UDim2.fromOffset(82, 20),
			bg = theme.color.inputBg,
			hoverBg = theme.color.hover,
			text = "− Unstage All",
			textSize = 10,
			radius = 3,
			order = 2,
			zIndex = 23,
			onClick = function() gitState.unstageAll() end,
		})

		local listScroll = P.scroll(root, {
			name = "ScmChangesList",
			size = UDim2.new(1, 0, 1, -190),
			pos = UDim2.fromOffset(0, 190),
			zIndex = 22,
		})
		P.list(listScroll, Enum.FillDirection.Vertical, 2)

		commitBtn.Activated:Connect(function()
			local msg = msgInput.Text ~= "" and msgInput.Text or "Update from VS-RBLX"
			task.spawn(function()
				commitBtn.Text = "Pushing via HTTP..."
				local res, err = githubSync.commitAndPush(msg)
				commitBtn.Text = "✓ Commit & Push to GitHub"
				if res then
					msgInput.Text = ""
					overlay.toast(string.format("Pushed commit %s (%d files)", res.commitSha:sub(1, 7), res.files), "good", 3.5)
				else
					overlay.toast("Push failed: " .. tostring(err), "bad", 4.5)
				end
			end)
		end)

		local function renderFileGroup(headerTitle, items, isStaged, startOrd)
			local ord = startOrd
			if #items == 0 then return ord end
			ord = ord + 1
			P.label(listScroll, {
				size = UDim2.new(1, 0, 0, 20),
				bold = true,
				textSize = 11,
				color = theme.color.muted,
				text = string.format("%s (%d)", headerTitle, #items),
				order = ord,
				zIndex = 23,
			})

			for _, ch in ipairs(items) do
				ord = ord + 1
				local row = P.frame(listScroll, {
					size = UDim2.new(1, 0, 0, 22),
					order = ord,
					zIndex = 23,
				})
				local badgeCol = ch.status == "A" and theme.color.good or (ch.status == "D" and theme.color.bad or theme.color.warn)
				local fileBtn = P.button(row, {
					name = "DiffRow_" .. ch.path,
					size = UDim2.new(1, -46, 1, 0),
					hoverBg = theme.color.hover,
					alignX = Enum.TextXAlignment.Left,
					textSize = 11,
					color = theme.color.sideBarText,
					text = "  [" .. ch.status .. "] " .. ch.path,
					zIndex = 24,
					onClick = function()
						local orig = gitState.originalContent(ch.path) or ""
						local cur = ch.status == "D" and "" or (codeStore.findByPath(ch.path) and codeStore.findByPath(ch.path).content or env.require("runtime/workspace_fs").readFile(ch.path) or "")
						codeStore.openDiff(ch.path, orig, cur)
					end,
				})
				fileBtn.TextTruncate = Enum.TextTruncate.AtEnd
				P.label(row, {
					size = UDim2.fromOffset(16, 22),
					pos = UDim2.new(1, -64, 0, 0),
					text = ch.status,
					bold = true,
					textSize = 11,
					color = badgeCol,
					alignX = Enum.TextXAlignment.Center,
					zIndex = 25,
				})
				P.button(row, {
					name = (isStaged and "Unstage_" or "Stage_") .. ch.path,
					size = UDim2.fromOffset(20, 20),
					pos = UDim2.new(1, -42, 0, 1),
					text = isStaged and "−" or "+",
					bold = true,
					textSize = 12,
					radius = 3,
					zIndex = 25,
					onClick = function()
						if isStaged then gitState.unstage(ch.path) else gitState.stage(ch.path) end
					end,
				})
				P.button(row, {
					name = "Discard_" .. ch.path,
					size = UDim2.fromOffset(20, 20),
					pos = UDim2.new(1, -20, 0, 1),
					text = "↺",
					textSize = 11,
					color = theme.color.bad,
					radius = 3,
					zIndex = 25,
					onClick = function()
						gitState.discardFile(ch.path)
						local openDoc = codeStore.findByPath(ch.path)
						if openDoc then
							codeStore.openFile(ch.path, { reloadFromDisk = true })
						end
						overlay.toast("Discarded changes in " .. ch.path, "warn", 2)
					end,
				})
			end
			return ord
		end

		local function refresh()
			local st = gitState.status()
			if st.repo then
				repoStatusLbl.Text = string.format("⎇ %s @ %s (%s)", st.repo, st.branch or "main", tostring(st.headSha or "local"):sub(1, 7))
			else
				repoStatusLbl.Text = "Local Workspace (Click Clone / PAT to link GitHub)"
			end

			listScroll:ClearAllChildren()
			P.list(listScroll, Enum.FillDirection.Vertical, 2)
			local ord = 0

			ord = renderFileGroup("STAGED CHANGES", st.staged, true, ord)
			ord = renderFileGroup("CHANGES", st.unstaged, false, ord)

			if st.total == 0 then
				ord = ord + 1
				P.label(listScroll, {
					size = UDim2.new(1, 0, 0, 24),
					text = "Working tree clean — all disk files match HEAD.",
					textSize = 11,
					color = theme.color.muted,
					order = ord,
					zIndex = 23,
				})
			end

			if #gitState.commits > 0 then
				ord = ord + 1
				P.label(listScroll, {
					size = UDim2.new(1, 0, 0, 22),
					bold = true,
					textSize = 11,
					color = theme.color.muted,
					text = "COMMIT HISTORY",
					order = ord,
					zIndex = 23,
				})
				for i = 1, math.min(10, #gitState.commits) do
					local c = gitState.commits[i]
					ord = ord + 1
					P.label(listScroll, {
						size = UDim2.new(1, 0, 0, 19),
						mono = true,
						textSize = 11,
						color = theme.color.sideBarText,
						text = string.format("● %s  %s (%s)", tostring(c.sha or ""):sub(1, 7), tostring(c.message or ""), tostring(c.time or "")),
						truncate = true,
						order = ord,
						zIndex = 23,
					})
				end
			end
		end

		gitState.changed:connect(refresh)
		codeStore.changed:connect(refresh)
		theme.changed:connect(refresh)

		refresh()
		return { root = root, refresh = refresh }
	end

	return M
end
