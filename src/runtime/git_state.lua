-- Local Git / GitHub working-tree tracker for VS-RBLX Source Control.
-- Compares current disk/open workspace files against the baseline fetched from GitHub
-- so players can stage, unstage, discard, diff, commit, pull, and push.
return function(env)
	local util = env.require("runtime/util")
	local fsx = env.require("runtime/fsx")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")
	local signal = env.require("runtime/signal")

	local M = {
		changed = signal.new("git_state.changed"),
		repo = nil,
		branch = "main",
		headSha = nil,
		branches = { "main" },
		baseFiles = {},
		fileShas = {},
		staged = {},
		commits = {},
	}

	local function metaPath()
		return "git_meta/" .. workspaceFs.activeName .. ".json"
	end

	function M.saveMeta()
		local payload = {
			repo = M.repo,
			branch = M.branch,
			headSha = M.headSha,
			branches = M.branches,
			baseFiles = M.baseFiles,
			fileShas = M.fileShas,
			staged = M.staged,
			commits = M.commits,
		}
		local raw = util.jsonEncode(payload)
		if raw then
			fsx.write(metaPath(), raw)
		end
	end

	function M.loadMeta()
		local raw = fsx.read(metaPath())
		if type(raw) == "string" and raw ~= "" then
			local decoded = util.jsonDecode(raw)
			if type(decoded) == "table" then
				M.repo = decoded.repo
				M.branch = decoded.branch or "main"
				M.headSha = decoded.headSha
				M.branches = type(decoded.branches) == "table" and decoded.branches or { M.branch }
				M.baseFiles = type(decoded.baseFiles) == "table" and decoded.baseFiles or {}
				M.fileShas = type(decoded.fileShas) == "table" and decoded.fileShas or {}
				M.staged = type(decoded.staged) == "table" and decoded.staged or {}
				M.commits = type(decoded.commits) == "table" and decoded.commits or {}
				M.changed:fire()
				return true
			end
		end
		M.repo = nil
		M.branch = "main"
		M.headSha = nil
		M.branches = { "main" }
		M.baseFiles = {}
		M.fileShas = {}
		M.staged = {}
		M.commits = {}
		M.changed:fire()
		return false
	end

	function M.adoptRemoteSnapshot(spec)
		M.repo = spec.repo
		M.branch = spec.branch or "main"
		M.headSha = spec.headSha
		M.branches = spec.branches or { M.branch }
		M.baseFiles = util.shallowCopy(spec.files or {})
		M.fileShas = util.shallowCopy(spec.shas or {})
		M.staged = {}
		if spec.commits then M.commits = spec.commits end
		M.saveMeta()
		M.changed:fire()
	end

	function M.initLocalBaseline()
		local snap = {}
		for _, item in ipairs(workspaceFs.listAllFiles("")) do
			snap[item.path] = workspaceFs.readFile(item.path) or ""
		end
		M.baseFiles = snap
		M.staged = {}
		M.saveMeta()
		M.changed:fire()
	end

	local function currentContent(path)
		local doc = codeStore.findByPath(path)
		if doc then return doc.content end
		return workspaceFs.readFile(path)
	end

	function M.status()
		local currentPaths = {}
		for _, item in ipairs(workspaceFs.listAllFiles("")) do
			currentPaths[item.path] = true
		end
		for _, doc in ipairs(codeStore.tabs) do
			if not doc.untitled and not doc.isDiff and doc.path ~= "" and not util.startsWith(doc.id, "virtual:") then
				currentPaths[doc.path] = true
			end
		end

		local stagedList = {}
		local unstagedList = {}

		local allPaths = {}
		local seen = {}
		for p in pairs(currentPaths) do
			seen[p] = true
			allPaths[#allPaths + 1] = p
		end
		for p in pairs(M.baseFiles) do
			if not seen[p] then
				seen[p] = true
				allPaths[#allPaths + 1] = p
			end
		end
		table.sort(allPaths)

		for _, path in ipairs(allPaths) do
			local base = M.baseFiles[path]
			local cur = currentPaths[path] and currentContent(path) or nil
			local kind = nil
			if base == nil and cur ~= nil then
				kind = "A"
			elseif base ~= nil and cur == nil then
				kind = "D"
			elseif base ~= nil and cur ~= nil and base ~= cur then
				kind = "M"
			end
			if kind then
				local entry = {
					path = path,
					name = util.basename(path),
					kind = kind,
					oldContent = base or "",
					newContent = cur or "",
					sha = M.fileShas[path],
				}
				if M.staged[path] then
					stagedList[#stagedList + 1] = entry
				else
					unstagedList[#unstagedList + 1] = entry
				end
			else
				M.staged[path] = nil
			end
		end

		return {
			repo = M.repo,
			branch = M.branch,
			headSha = M.headSha,
			staged = stagedList,
			unstaged = unstagedList,
			total = #stagedList + #unstagedList,
		}
	end

	function M.stage(path)
		M.staged[util.normalisePath(path)] = true
		M.saveMeta()
		M.changed:fire()
	end

	function M.unstage(path)
		M.staged[util.normalisePath(path)] = nil
		M.saveMeta()
		M.changed:fire()
	end

	function M.stageAll()
		local st = M.status()
		for _, item in ipairs(st.unstaged) do
			M.staged[item.path] = true
		end
		M.saveMeta()
		M.changed:fire()
	end

	function M.unstageAll()
		M.staged = {}
		M.saveMeta()
		M.changed:fire()
	end

	function M.discard(path)
		local clean = util.normalisePath(path)
		local base = M.baseFiles[clean]
		M.staged[clean] = nil
		if base == nil then
			workspaceFs.deletePath(clean)
			local doc = codeStore.findByPath(clean)
			if doc then codeStore.close(doc.id) end
		else
			workspaceFs.writeFile(clean, base)
			local doc = codeStore.findByPath(clean)
			if doc then
				doc.content = base
				doc.savedContent = base
				doc.dirty = false
				codeStore.changed:fire({ reason = "discard", id = doc.id })
			end
		end
		M.saveMeta()
		M.changed:fire()
	end

	function M.recordCommit(sha, message, changedEntries)
		for _, item in ipairs(changedEntries or {}) do
			if item.kind == "D" then
				M.baseFiles[item.path] = nil
				M.fileShas[item.path] = nil
			else
				M.baseFiles[item.path] = item.newContent
				if item.newSha then
					M.fileShas[item.path] = item.newSha
				end
			end
			M.staged[item.path] = nil
		end
		M.headSha = sha or M.headSha
		table.insert(M.commits, 1, {
			sha = sha or "local",
			message = message,
			files = #(changedEntries or {}),
		})
		while #M.commits > 40 do table.remove(M.commits) end
		M.saveMeta()
		M.changed:fire()
	end

	function M.isLinked()
		return type(M.repo) == "string" and M.repo ~= ""
	end

	function M.baselineOf(path)
		return M.baseFiles[util.normalisePath(path)] or ""
	end

	function M.commitLocal(message)
		local st = M.status()
		local targets = #st.staged > 0 and st.staged or st.unstaged
		if #targets == 0 then
			return false, "Nothing to commit"
		end
		local sha = string.format("%07x", (#M.commits + 1) * 104729)
		M.recordCommit(sha, message or "Local snapshot", targets)
		return true, M.commits[1]
	end

	return M
end
