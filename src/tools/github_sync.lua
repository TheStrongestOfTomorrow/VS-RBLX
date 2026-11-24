-- High-level GitHub <-> Local Executor Disk synchronization workflow.
-- Clones GitHub repos onto executor disk (`writefile`), switches branches, pulls
-- upstream updates, and commits + pushes staged or dirty files back to GitHub.
return function(env)
	local util = env.require("runtime/util")
	local config = env.require("runtime/config")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")
	local gitState = env.require("runtime/git_state")
	local github = env.require("net/github")
	local gist = env.require("net/gist")
	local signal = env.require("runtime/signal")

	local M = {
		busy = false,
		statusText = "",
		progress = signal.new("github_sync.progress"),
	}

	local function setProgress(busy, text)
		M.busy = busy == true
		M.statusText = tostring(text or "")
		M.progress:fire(M.busy, M.statusText)
	end

	function M.cloneRepo(repoInput, opts)
		opts = opts or {}
		if M.busy then return nil, "Another GitHub operation is already running" end
		setProgress(true, "Connecting to GitHub...")

		local snap, err = github.cloneSnapshot(repoInput, {
			branch = opts.branch,
			maxFiles = opts.maxFiles or 85,
			onProgress = function(idx, total, path)
				setProgress(true, string.format("Syncing (%d/%d): %s", idx, total, path))
			end,
		})
		if not snap then
			setProgress(false, "")
			return nil, err
		end

		local wsName = opts.workspaceName or (snap.owner .. "__" .. snap.repo):gsub("[^%w%-_]", "_")
		workspaceFs.openWorkspace(wsName)
		workspaceFs.replaceWorkspaceFiles(snap.files, { clean = true })

		config.set("github.activeRepo", snap.fullName, { quiet = true })
		config.set("github.activeBranch", snap.branch, { immediate = true })

		gitState.adoptRemoteSnapshot({
			repo = snap.fullName,
			branch = snap.branch,
			headSha = snap.headSha,
			branches = snap.branches,
			files = snap.files,
			shas = snap.shas,
		})

		-- Close old tabs and open README or first code file automatically
		for i = #codeStore.tabs, 1, -1 do
			local t = codeStore.tabs[i]
			codeStore.byId[t.id] = nil
			codeStore.tabs[i] = nil
		end
		codeStore.activeId = nil

		local entryFile = nil
		for _, candidate in ipairs({ "init.lua", "src/main.luau", "src/init.lua", "README.md" }) do
			if snap.files[candidate] ~= nil then
				entryFile = candidate
				break
			end
		end
		if not entryFile then
			local keys = util.keys(snap.files)
			entryFile = keys[1]
		end
		if entryFile then
			codeStore.openFile(entryFile)
		end

		setProgress(false, string.format("Synced %s@%s (%d files)", snap.fullName, snap.branch, snap.fetched))
		snap.filesWritten = snap.fetched
		return snap
	end

	M.clone = M.cloneRepo

	function M.authenticate(token)
		return github.verifyToken(token)
	end

	function M.createBranch(newBranch)
		local repo = gitState.repo or config.get("github.activeRepo", "")
		if not repo or repo == "" then return nil, "No linked GitHub repository" end
		local created, err = github.createBranch(repo, newBranch, gitState.branch)
		if not created then return nil, err end
		gitState.branch = newBranch
		gitState.branches[#gitState.branches + 1] = newBranch
		config.set("github.activeBranch", newBranch, { immediate = true })
		gitState.saveMeta()
		gitState.changed:fire()
		return created
	end

	function M.pull()
		local repo = gitState.repo or config.get("github.activeRepo", "")
		if not repo or repo == "" then
			return nil, "No GitHub repository linked to this workspace yet."
		end
		local branch = gitState.branch or config.get("github.activeBranch", "main")
		if M.busy then return nil, "GitHub sync is already running" end
		setProgress(true, "Pulling " .. repo .. "@" .. branch .. "...")

		local snap, err = github.cloneSnapshot(repo, {
			branch = branch,
			onProgress = function(idx, total, path)
				setProgress(true, string.format("Pulling (%d/%d): %s", idx, total, path))
			end,
		})
		if not snap then
			setProgress(false, "")
			return nil, err
		end

		workspaceFs.replaceWorkspaceFiles(snap.files, { clean = false })
		gitState.adoptRemoteSnapshot({
			repo = snap.fullName,
			branch = snap.branch,
			headSha = snap.headSha,
			branches = snap.branches,
			files = snap.files,
			shas = snap.shas,
			commits = gitState.commits,
		})
		codeStore.syncWithWorkspace()
		snap.filesWritten = snap.fetched
		setProgress(false, string.format("Pulled %d files from %s@%s", snap.fetched, snap.fullName, snap.branch))
		return snap
	end

	function M.switchBranch(branchName)
		local repo = gitState.repo or config.get("github.activeRepo", "")
		if not repo or repo == "" then return nil, "No linked GitHub repository" end
		gitState.branch = branchName
		config.set("github.activeBranch", branchName, { immediate = true })
		return M.pull()
	end

	function M.commitAndPush(message)
		local repo = gitState.repo or config.get("github.activeRepo", "")
		if not repo or repo == "" then
			return nil, "Clone or link a GitHub repository before pushing."
		end
		if M.busy then return nil, "GitHub sync is already running" end

		codeStore.saveAll()
		local st = gitState.status()
		local targets = st.staged
		if #targets == 0 then
			targets = st.unstaged
		end
		if #targets == 0 then
			return nil, "Working tree is clean — nothing to commit."
		end

		setProgress(true, string.format("Pushing %d file(s) to %s@%s...", #targets, repo, gitState.branch))
		local res, err = github.pushChanges(repo, gitState.branch, message, targets)
		if not res then
			setProgress(false, "")
			return nil, err
		end

		gitState.recordCommit(res.sha, message, targets)
		setProgress(false, string.format("Committed & pushed %d file(s) (%s)", #targets, tostring(res.sha):sub(1, 7)))
		return res
	end

	function M.importUrl(targetUrl)
		local loaded, err = gist.loadRawUrl(targetUrl)
		if not loaded then return nil, err end
		workspaceFs.writeFile(loaded.name, loaded.content)
		return codeStore.openFile(loaded.name, { reloadFromDisk = true })
	end

	return M
end
