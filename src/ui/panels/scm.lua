-- VS Code Source Control (Git / GitHub) Sidebar Viewlet (`Ctrl+Shift+G`).
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local overlay = env.require("ui/overlay")
	local githubConnect = env.require("ui/panels/github_connect")
	local workspaceFs = env.require("runtime/workspace_fs")
	local gitState = env.require("runtime/git_state")
	local codeStore = env.require("runtime/code_store")
	local githubSync = env.require("tools/github_sync")

	local M = {}

	function M.new(parent)
		local root = P.frame(parent, {
			name = "ScmViewlet",
			size = UDim2.fromScale(1, 1),
			visible = false,
			zIndex = 21,
		})
		P.pad(root, 6, 10, 6, 10)

		P.label(root, {
			size = UDim2.new(1, 0, 0, 22),
			text = "SOURCE CONTROL · GITHUB",
			bold = true,
			textSize = 11,
			color = theme.color.muted,
			zIndex = 22,
		})

		local repoInfoLbl = P.label(root, {
			size = UDim2.new(1, 0, 0, 20),
			pos = UDim2.fromOffset(0, 22),
			mono = true,
			textSize = 11,
			color = theme.color.accent,
			text = "Not linked to GitHub",
			truncate = true,
			zIndex = 22,
		})

		local topActions = P.frame(root, {
			size = UDim2.new(1, 0, 0, 26),
			pos = UDim2.fromOffset(0, 44),
			zIndex = 22,
		})
		P.list(topActions, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

		P.button(topActions, {
			name = "OpenCloneModalBtn",
			size = UDim2.fromOffset(78, 22),
			bg = theme.color.inputBg,
			text = "Clone / Auth",
			textSize = 11,
			radius = 3,
			order = 1,
			zIndex = 23,
			onClick = function() githubConnect.openModal() end,
		})
		P.button(topActions, {
			name = "GitPullBtn",
			size = UDim2.fromOffset(50, 22),
			bg = theme.color.inputBg,
			text = "↓ Pull",
			textSize = 11,
			radius = 3,
			order = 2,
			zIndex = 23,
			onClick = function()
				task.spawn(function()
					local res, err = githubSync.pull()
					if res then
						overlay.toast(string.format("Pulled %d files from %s", res.filesWritten, res.fullName), "good", 3)
					else
						overlay.toast("Pull failed: " .. tostring(err), "bad", 4)
					end
				end)
			end,
		})
		P.button(topActions, {
			name = "NewBranchBtn",
			size = UDim2.fromOffset(64, 22),
			bg = theme.color.inputBg,
			text = "⎇ Branch",
			textSize = 11,
			radius = 3,
			order = 3,
			zIndex = 23,
			onClick = function()
				overlay.prompt({
					title = "Create & Switch GitHub Branch",
					placeholder = "feature/my-update",
					mono = true,
					confirmText = "Create Branch",
					onConfirm = function(name)
						task.spawn(function()
							local created, err = githubSync.createBranch(name)
							if created then
								overlay.toast("Switched to branch " .. name, "good", 3)
							else
								overlay.toast("Branch error: " .. tostring(err), "bad", 4)
							end
						end)
					end,
				})
			end,
		})

		local _, commitBox = P.input(root, {
			name = "CommitMsgInput",
			size = UDim2.new(1, 0, 0, 28),
			pos = UDim2.fromOffset(0, 76),
			placeholder = "Message (Commit & Push to GitHub)",
			zIndex = 22,
		})

		local commitBtns = P.frame(root, {
			size = UDim2.new(1, 0, 0, 28),
			pos = UDim2.fromOffset(0, 108),
			zIndex = 22,
		})
		P.button(commitBtns, {
			name = "CommitPushBtn",
			size = UDim2.new(0.66, -3, 1, 0),
			bg = theme.color.accent,
			hoverBg = theme.color.accentHover,
			color = Color3.fromRGB(255, 255, 255),
			bold = true,
			text = "✓ Commit & Push",
			textSize = 12,
			radius = 4,
			zIndex = 23,
			onClick = function()
				local msg = commitBox.Text ~= "" and commitBox.Text or "Update from VS-RBLX"
				task.spawn(function()
					local res, err = githubSync.commitAndPush(msg)
					if res then
						commitBox.Text = ""
						overlay.toast("Pushed commit " .. tostring(res.sha):sub(1, 7) .. " to GitHub!", "good", 4)
					else
						if not gitState.isLinked() then
							local localOk, c = gitState.commitLocal(msg)
							if localOk then
								commitBox.Text = ""
								overlay.toast("Committed locally (" .. c.sha .. ")", "good", 3)
								return
							end
						end
						overlay.toast("Push failed: " .. tostring(err), "bad", 4)
					end
				end)
			end,
		})
		P.button(commitBtns, {
			name = "StageAllBtn",
			size = UDim2.new(0.34, -3, 1, 0),
			pos = UDim2.new(0.66, 6, 0, 0),
			bg = theme.color.inputBg,
			text = "+ Stage All",
			textSize = 11,
			radius = 4,
			zIndex = 23,
			onClick = function() gitState.stageAll() end,
		})

		local listScroll = P.scroll(root, {
			name = "ScmChangesScroll",
			size = UDim2.new(1, 0, 1, -142),
			pos = UDim2.fromOffset(0, 142),
			zIndex = 22,
		})
		P.list(listScroll, Enum.FillDirection.Vertical, 2)

		local function openFileDiff(path)
			local oldText = gitState.baselineOf(path)
			local newText = workspaceFs.readFile(path) or ""
			codeStore.openDiff(path, oldText, newText, path .. " (Working Tree)")
		end

		local function rebuild()
			listScroll:ClearAllChildren()
			P.list(listScroll, Enum.FillDirection.Vertical, 2)

			if gitState.isLinked() then
				repoInfoLbl.Text = string.format("%s @ %s", tostring(gitState.repo), tostring(gitState.branch))
			else
				repoInfoLbl.Text = "Local Git Baseline (" .. workspaceFs.activeName .. ")"
			end

			local st = gitState.status()
			local ord = 0

			ord = ord + 1
			P.label(listScroll, {
				size = UDim2.new(1, 0, 0, 20),
				bold = true,
				textSize = 11,
				color = theme.color.sideBarText,
				text = string.format("▾ STAGED CHANGES (%d)", #st.staged),
				order = ord,
				zIndex = 23,
			})
			for _, item in ipairs(st.staged) do
				ord = ord + 1
				local row = P.frame(listScroll, { size = UDim2.new(1, 0, 0, 22), order = ord, zIndex = 23 })
				local pathBtn = P.button(row, {
					size = UDim2.new(1, -46, 1, 0),
					hoverBg = theme.color.hover,
					alignX = Enum.TextXAlignment.Left,
					mono = true,
					textSize = 11,
					color = theme.color.good,
					text = string.format("  [%s] %s", item.kind, item.path),
					zIndex = 24,
					onClick = function() openFileDiff(item.path) end,
				})
				pathBtn.TextTruncate = Enum.TextTruncate.AtEnd
				P.button(row, {
					size = UDim2.fromOffset(22, 20),
					pos = UDim2.new(1, -24, 0, 1),
					text = "−",
					radius = 3,
					zIndex = 24,
					onClick = function() gitState.unstage(item.path) end,
				})
			end

			ord = ord + 1
			P.label(listScroll, {
				size = UDim2.new(1, 0, 0, 20),
				bold = true,
				textSize = 11,
				color = theme.color.sideBarText,
				text = string.format("▾ CHANGES (%d)", #st.unstaged),
				order = ord,
				zIndex = 23,
			})
			for _, item in ipairs(st.unstaged) do
				ord = ord + 1
				local col = item.kind == "A" and theme.color.good or (item.kind == "D" and theme.color.bad or theme.color.warn)
				local row = P.frame(listScroll, { size = UDim2.new(1, 0, 0, 22), order = ord, zIndex = 23 })
				local pathBtn = P.button(row, {
					size = UDim2.new(1, -50, 1, 0),
					hoverBg = theme.color.hover,
					alignX = Enum.TextXAlignment.Left,
					mono = true,
					textSize = 11,
					color = col,
					text = string.format("  [%s] %s", item.kind, item.path),
					zIndex = 24,
					onClick = function() openFileDiff(item.path) end,
				})
				pathBtn.TextTruncate = Enum.TextTruncate.AtEnd
				P.button(row, {
					size = UDim2.fromOffset(22, 20),
					pos = UDim2.new(1, -48, 0, 1),
					text = "↺",
					radius = 3,
					zIndex = 24,
					onClick = function() gitState.discard(item.path) end,
				})
				P.button(row, {
					size = UDim2.fromOffset(22, 20),
					pos = UDim2.new(1, -24, 0, 1),
					text = "+",
					radius = 3,
					zIndex = 24,
					onClick = function() gitState.stage(item.path) end,
				})
			end

			if #gitState.commits > 0 then
				ord = ord + 1
				P.label(listScroll, {
					size = UDim2.new(1, 0, 0, 22),
					bold = true,
					textSize = 11,
					color = theme.color.muted,
					text = "▾ RECENT COMMITS",
					order = ord,
					zIndex = 23,
				})
				for i = 1, math.min(10, #gitState.commits) do
					ord = ord + 1
					local c = gitState.commits[i]
					P.label(listScroll, {
						size = UDim2.new(1, 0, 0, 19),
						mono = true,
						textSize = 11,
						color = theme.color.sideBarText,
						text = string.format("  %s  %s", tostring(c.sha):sub(1, 7), c.message),
						truncate = true,
						order = ord,
						zIndex = 23,
					})
				end
			end
		end

		gitState.changed:connect(rebuild)
		workspaceFs.changed:connect(rebuild)
		codeStore.changed:connect(rebuild)
		theme.changed:connect(rebuild)

		rebuild()
		return { root = root, refresh = rebuild }
	end

	return M
end
