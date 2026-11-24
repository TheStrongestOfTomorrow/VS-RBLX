-- Modal Dialog for GitHub Repository Cloning, Token Authentication, & Repo Browser.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local overlay = env.require("ui/overlay")
	local config = env.require("runtime/config")
	local caps = env.require("runtime/caps")
	local github = env.require("net/github")
	local githubSync = env.require("tools/github_sync")

	local M = {}

	function M.openModal()
		local card = overlay.openModal("GitHubCloneModal", 520, 390)
		P.pad(card, 14, 16, 14, 16)

		P.label(card, {
			size = UDim2.new(1, -34, 0, 22),
			text = "GitHub Repository Sync & Executor HTTP Loader",
			bold = true,
			textSize = 14,
			color = theme.color.tabActiveText,
			zIndex = 232,
		})
		P.button(card, {
			size = UDim2.fromOffset(26, 24),
			pos = UDim2.new(1, -26, 0, 0),
			text = "✕",
			radius = 4,
			zIndex = 232,
			onClick = function() overlay.closeModal() end,
		})

		P.label(card, {
			size = UDim2.new(1, 0, 0, 18),
			pos = UDim2.fromOffset(0, 24),
			text = "HTTP Transport: " .. tostring(caps.requestName or caps.http) .. "   |   Files persist via writefile / readfile",
			textSize = 11,
			color = theme.color.muted,
			zIndex = 232,
		})

		P.label(card, {
			size = UDim2.new(1, 0, 0, 18),
			pos = UDim2.fromOffset(0, 50),
			text = "Clone Repository (owner/repo, owner/repo@branch, or https://github.com/...)",
			textSize = 12,
			color = theme.color.sideBarText,
			zIndex = 232,
		})
		local _, repoBox = P.input(card, {
			name = "CloneRepoInput",
			size = UDim2.new(1, -110, 0, 28),
			pos = UDim2.fromOffset(0, 70),
			mono = true,
			value = config.get("github.activeRepo", ""),
			placeholder = "TheStrongestOfTomorrow/VS-RBLX",
			zIndex = 232,
		})
		local cloneBtn = P.button(card, {
			name = "RunCloneBtn",
			size = UDim2.fromOffset(102, 28),
			pos = UDim2.new(1, -102, 0, 70),
			bg = theme.color.accent,
			hoverBg = theme.color.accentHover,
			color = Color3.fromRGB(255, 255, 255),
			bold = true,
			text = "Clone to Disk",
			radius = 4,
			zIndex = 232,
		})

		P.label(card, {
			size = UDim2.new(1, 0, 0, 18),
			pos = UDim2.fromOffset(0, 108),
			text = "Personal Access Token (optional for public clone; required for private repos & push)",
			textSize = 11,
			color = theme.color.sideBarText,
			zIndex = 232,
		})
		local _, patBox = P.input(card, {
			name = "PatInput",
			size = UDim2.new(1, -188, 0, 28),
			pos = UDim2.fromOffset(0, 128),
			mono = true,
			value = config.get("github.token", ""),
			placeholder = "ghp_xxxxxxxxxxxxxxxxxxxx",
			zIndex = 232,
		})
		local verifyBtn = P.button(card, {
			name = "VerifyPatBtn",
			size = UDim2.fromOffset(88, 28),
			pos = UDim2.new(1, -180, 0, 128),
			bg = theme.color.inputBg,
			text = "Save & Verify",
			textSize = 11,
			radius = 4,
			zIndex = 232,
		})
		local listReposBtn = P.button(card, {
			name = "ListUserReposBtn",
			size = UDim2.fromOffset(86, 28),
			pos = UDim2.new(1, -86, 0, 128),
			bg = theme.color.inputBg,
			text = "My Repos",
			textSize = 11,
			radius = 4,
			zIndex = 232,
		})

		P.label(card, {
			size = UDim2.new(1, 0, 0, 18),
			pos = UDim2.fromOffset(0, 166),
			text = "Import Raw URL into Current Workspace",
			textSize = 11,
			color = theme.color.sideBarText,
			zIndex = 232,
		})
		local _, rawUrlBox = P.input(card, {
			name = "RawUrlInput",
			size = UDim2.new(1, -110, 0, 26),
			pos = UDim2.fromOffset(0, 186),
			mono = true,
			placeholder = "https://raw.githubusercontent.com/...",
			zIndex = 232,
		})
		local importUrlBtn = P.button(card, {
			name = "ImportRawUrlBtn",
			size = UDim2.fromOffset(102, 26),
			pos = UDim2.new(1, -102, 0, 186),
			bg = theme.color.inputBg,
			text = "Fetch File",
			textSize = 11,
			radius = 4,
			zIndex = 232,
		})

		local feedbackLbl = P.label(card, {
			size = UDim2.new(1, 0, 0, 20),
			pos = UDim2.fromOffset(0, 218),
			text = "Ready.",
			mono = true,
			textSize = 11,
			color = theme.color.accent,
			zIndex = 232,
		})

		local repoListScroll = P.scroll(card, {
			name = "UserRepoBrowser",
			size = UDim2.new(1, 0, 0, 118),
			pos = UDim2.fromOffset(0, 242),
			bg = theme.color.editor,
			zIndex = 232,
		})
		P.pad(repoListScroll, 4, 6, 4, 6)
		P.list(repoListScroll, Enum.FillDirection.Vertical, 2)

		local function executeClone(spec)
			if spec == "" then
				feedbackLbl.Text = "Enter owner/repo first."
				return
			end
			if patBox.Text ~= config.get("github.token", "") then
				github.setToken(patBox.Text)
			end
			feedbackLbl.Text = "Cloning " .. spec .. " via Executor HTTP..."
			task.spawn(function()
				local snap, err = githubSync.cloneRepo(spec)
				if snap then
					overlay.toast(string.format("Cloned %s (%d files written to disk)", snap.fullName, snap.fetched), "good", 4)
					overlay.closeModal()
				else
					feedbackLbl.Text = "Clone failed: " .. tostring(err)
					overlay.toast("Clone failed: " .. tostring(err), "bad", 4)
				end
			end)
		end

		cloneBtn.Activated:Connect(function() executeClone(repoBox.Text) end)

		verifyBtn.Activated:Connect(function()
			feedbackLbl.Text = "Verifying GitHub token..."
			task.spawn(function()
				local user, err = githubSync.authenticate(patBox.Text)
				if user then
					feedbackLbl.Text = "Authenticated as @" .. tostring(user.login)
					overlay.toast("GitHub authenticated: @" .. tostring(user.login), "good", 3)
				else
					feedbackLbl.Text = "Auth error: " .. tostring(err)
				end
			end)
		end)

		listReposBtn.Activated:Connect(function()
			if patBox.Text ~= "" then github.setToken(patBox.Text) end
			feedbackLbl.Text = "Loading repositories..."
			task.spawn(function()
				local repos, err = github.listUserRepos()
				repoListScroll:ClearAllChildren()
				P.pad(repoListScroll, 4, 6, 4, 6)
				P.list(repoListScroll, Enum.FillDirection.Vertical, 2)
				if not repos then
					feedbackLbl.Text = "Error: " .. tostring(err)
					return
				end
				feedbackLbl.Text = string.format("Loaded %d repositories — click any to clone:", #repos)
				for idx, r in ipairs(repos) do
					local fullName = tostring(r.fullName or "")
					P.button(repoListScroll, {
						size = UDim2.new(1, 0, 0, 22),
						hoverBg = theme.color.listActive,
						alignX = Enum.TextXAlignment.Left,
						mono = true,
						textSize = 11,
						color = theme.color.tabActiveText,
						text = string.format("  %s %s  [%s]", r.private and "🔒" or "🌐", fullName, tostring(r.defaultBranch or "main")),
						order = idx,
						zIndex = 233,
						onClick = function()
							repoBox.Text = fullName
							executeClone(fullName)
						end,
					})
				end
			end)
		end)

		importUrlBtn.Activated:Connect(function()
			local target = rawUrlBox.Text
			if target == "" then return end
			feedbackLbl.Text = "Fetching " .. target .. " ..."
			task.spawn(function()
				local doc, err = githubSync.importUrl(target)
				if doc then
					overlay.toast("Imported " .. doc.title .. " into workspace!", "good", 3)
					overlay.closeModal()
				else
					feedbackLbl.Text = "Import failed: " .. tostring(err)
				end
			end)
		end)
	end

	return M
end
