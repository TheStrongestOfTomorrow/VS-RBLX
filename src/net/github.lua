-- Full GitHub REST & Git Data API client over Executor HTTP.
-- Allows players to clone repositories onto local executor disk, browse branches,
-- pull upstream commits, and commit + push edits directly from Roblox!
return function(env)
	local util = env.require("runtime/util")
	local config = env.require("runtime/config")
	local log = env.require("runtime/log")
	local http = env.require("net/http")
	local urlUtil = env.require("net/url")
	local headersUtil = env.require("net/headers")
	local base64 = env.require("net/base64")

	local API_BASE = "https://api.github.com"
	local RAW_BASE = "https://raw.githubusercontent.com"

	local SKIP_BINARY_EXT = {
		png = true, jpg = true, jpeg = true, gif = true, webp = true, ico = true,
		mp3 = true, mp4 = true, wav = true, ogg = true, pdf = true, zip = true,
		tar = true, gz = true, exe = true, dll = true, so = true, dylib = true,
		woff = true, woff2 = true, ttf = true, otf = true, rbxl = true, rbxm = true,
	}

	local M = {}

	function M.token()
		return tostring(config.get("github.token", "") or "")
	end

	function M.setToken(pat)
		local clean = util.trim(pat or "")
		config.set("github.token", clean, { immediate = true })
		return clean
	end

	local function apiCall(method, path, payload, tokenOverride)
		local tok = tokenOverride ~= nil and tokenOverride or M.token()
		local res = http.send({
			url = API_BASE .. path,
			method = method,
			headers = headersUtil.github(tok, payload ~= nil),
			body = payload,
		})
		if not res.ok then
			local apiMsg = (type(res.json) == "table" and res.json.message) or res.error or ("HTTP " .. tostring(res.status))
			return nil, apiMsg, res.status
		end
		return res.json or res.body, nil, res.status
	end

	function M.verifyToken(tokenOverride)
		local tok = util.trim(tokenOverride or M.token())
		if tok == "" then return nil, "Personal Access Token is empty" end
		local user, err = apiCall("GET", "/user", nil, tok)
		if not user or type(user) ~= "table" then
			return nil, err or "Authentication failed"
		end
		if tokenOverride then
			M.setToken(tok)
		end
		if type(user.login) == "string" then
			config.set("github.username", user.login, { immediate = true })
		end
		log.info("github", "Authenticated with GitHub as @" .. tostring(user.login))
		return user
	end

	function M.listUserRepos()
		if M.token() == "" then
			return nil, "Sign in with a GitHub Personal Access Token first"
		end
		local data, err = apiCall("GET", "/user/repos?sort=updated&per_page=30")
		if not data or type(data) ~= "table" then return nil, err end
		local out = {}
		for _, r in ipairs(data) do
			out[#out + 1] = {
				fullName = r.full_name,
				name = r.name,
				private = r.private == true,
				defaultBranch = r.default_branch or "main",
				description = r.description or "",
			}
		end
		return out
	end

	function M.getRepo(owner, repo)
		return apiCall("GET", "/repos/" .. urlUtil.encodeComponent(owner) .. "/" .. urlUtil.encodeComponent(repo))
	end

	function M.listBranches(owner, repo)
		local data, err = apiCall(
			"GET",
			"/repos/" .. urlUtil.encodeComponent(owner) .. "/" .. urlUtil.encodeComponent(repo) .. "/branches?per_page=50"
		)
		if not data or type(data) ~= "table" then return nil, err end
		local names = {}
		for _, item in ipairs(data) do
			if type(item.name) == "string" then
				names[#names + 1] = item.name
			end
		end
		return names
	end

	function M.fetchFileContent(owner, repo, branch, filePath, blobSha, isPrivate)
		if not isPrivate then
			local rawUrl = string.format(
				"%s/%s/%s/%s/%s",
				RAW_BASE,
				urlUtil.encodeComponent(owner),
				urlUtil.encodeComponent(repo),
				urlUtil.encodeComponent(branch),
				urlUtil.encodePath(filePath)
			)
			local rawRes = http.send({
				url = rawUrl,
				method = "GET",
				json = false,
				quiet = true,
			})
			if rawRes.ok then
				return rawRes.body
			end
		end

		if blobSha and blobSha ~= "" then
			local blob, err = apiCall(
				"GET",
				string.format("/repos/%s/%s/git/blobs/%s", urlUtil.encodeComponent(owner), urlUtil.encodeComponent(repo), blobSha)
			)
			if type(blob) == "table" and type(blob.content) == "string" then
				if blob.encoding == "base64" then
					return base64.decode(blob.content)
				end
				return blob.content
			end
			if err then return nil, err end
		end

		local item, err = apiCall(
			"GET",
			string.format(
				"/repos/%s/%s/contents/%s?ref=%s",
				urlUtil.encodeComponent(owner),
				urlUtil.encodeComponent(repo),
				urlUtil.encodePath(filePath),
				urlUtil.encodeComponent(branch)
			)
		)
		if type(item) == "table" and type(item.content) == "string" then
			return base64.decode(item.content)
		end
		return nil, err or "could not fetch file"
	end

	-- Fetches a complete repository tree & text blobs from GitHub.
	function M.cloneSnapshot(repoInput, opts)
		opts = opts or {}
		local parsed, parseErr = urlUtil.parseGitHubRepo(repoInput)
		if not parsed then return nil, parseErr end

		local owner, repo = parsed.owner, parsed.repo
		local info, infoErr = M.getRepo(owner, repo)
		local branch = opts.branch or parsed.branch or (type(info) == "table" and info.default_branch) or "main"
		local isPrivate = type(info) == "table" and info.private == true

		if not info and M.token() ~= "" then
			return nil, infoErr or ("Repository not found: " .. parsed.fullName)
		end

		local treeData, treeErr = apiCall(
			"GET",
			string.format(
				"/repos/%s/%s/git/trees/%s?recursive=1",
				urlUtil.encodeComponent(owner),
				urlUtil.encodeComponent(repo),
				urlUtil.encodeComponent(branch)
			)
		)
		if type(treeData) ~= "table" or type(treeData.tree) ~= "table" then
			return nil, treeErr or ("Could not read branch tree '" .. branch .. "'")
		end

		local branchList = M.listBranches(owner, repo) or { branch }
		local maxFiles = opts.maxFiles or 85
		local maxFileBytes = opts.maxFileBytes or (256 * 1024)
		local files = {}
		local shas = {}
		local skipped = 0
		local fetched = 0

		local candidates = {}
		for _, node in ipairs(treeData.tree) do
			if node.type == "blob" and type(node.path) == "string" then
				local include = true
				if parsed.subpath ~= "" then
					local pfx = parsed.subpath .. "/"
					if node.path:sub(1, #pfx) ~= pfx and node.path ~= parsed.subpath then
						include = false
					end
				end
				local ext = util.extname(node.path)
				if SKIP_BINARY_EXT[ext] then include = false end
				if (tonumber(node.size) or 0) > maxFileBytes then include = false end
				if include then
					candidates[#candidates + 1] = node
				else
					skipped = skipped + 1
				end
			end
		end

		for idx, node in ipairs(candidates) do
			if fetched >= maxFiles then
				skipped = skipped + 1
			else
				if opts.onProgress then
					pcall(opts.onProgress, idx, math.min(#candidates, maxFiles), node.path)
				end
				local content = M.fetchFileContent(owner, repo, branch, node.path, node.sha, isPrivate)
				if type(content) == "string" then
					local relPath = node.path
					if parsed.subpath ~= "" and util.startsWith(relPath, parsed.subpath .. "/") then
						relPath = relPath:sub(#parsed.subpath + 2)
					end
					files[relPath] = content
					shas[relPath] = node.sha
					fetched = fetched + 1
				else
					skipped = skipped + 1
				end
			end
		end

		log.info("github", string.format(
			"Loaded %s@%s (%d files synced, %d skipped)",
			parsed.fullName,
			branch,
			fetched,
			skipped
		))

		return {
			owner = owner,
			repo = repo,
			fullName = parsed.fullName,
			branch = branch,
			branches = branchList,
			headSha = treeData.sha,
			files = files,
			shas = shas,
			fetched = fetched,
			skipped = skipped,
		}
	end

	-- Commits and pushes staged entries (`A`, `M`, `D`) directly to GitHub!
	function M.pushChanges(repoFullName, branch, commitMessage, entries)
		if M.token() == "" then
			return nil, "GitHub Personal Access Token required to push commits."
		end
		local parsed, parseErr = urlUtil.parseGitHubRepo(repoFullName)
		if not parsed then return nil, parseErr end
		if type(entries) ~= "table" or #entries == 0 then
			return nil, "No changed files to commit."
		end

		local owner, repo = parsed.owner, parsed.repo
		local msg = util.trim(commitMessage or "")
		if msg == "" then msg = "Update via VS-RBLX" end

		-- Try atomic Git Data API commit first when pushing multiple files.
		local refPath = string.format(
			"/repos/%s/%s/git/ref/heads/%s",
			urlUtil.encodeComponent(owner),
			urlUtil.encodeComponent(repo),
			urlUtil.encodeComponent(branch)
		)
		local refObj = apiCall("GET", refPath)
		if type(refObj) == "table" and type(refObj.object) == "table" and refObj.object.sha then
			local parentCommitSha = refObj.object.sha
			local commitObj = apiCall(
				"GET",
				string.format("/repos/%s/%s/git/commits/%s", urlUtil.encodeComponent(owner), urlUtil.encodeComponent(repo), parentCommitSha)
			)
			if type(commitObj) == "table" and type(commitObj.tree) == "table" and commitObj.tree.sha then
				local treeEntries = {}
				local allBlobsOk = true
				for _, item in ipairs(entries) do
					if item.kind == "D" then
						treeEntries[#treeEntries + 1] = {
							path = item.path,
							mode = "100644",
							type = "blob",
							sha = false,
						}
					else
						local blobRes = apiCall(
							"POST",
							string.format("/repos/%s/%s/git/blobs", urlUtil.encodeComponent(owner), urlUtil.encodeComponent(repo)),
							{
								content = base64.encode(item.newContent or ""),
								encoding = "base64",
							}
						)
						if type(blobRes) == "table" and blobRes.sha then
							item.newSha = blobRes.sha
							treeEntries[#treeEntries + 1] = {
								path = item.path,
								mode = "100644",
								type = "blob",
								sha = blobRes.sha,
							}
						else
							allBlobsOk = false
							break
						end
					end
				end

				if allBlobsOk and #treeEntries > 0 then
					-- Replace `sha = false` with explicit JSON null for deleted entries in Git Tree API
					local cleanTreePayload = { base_tree = commitObj.tree.sha, tree = {} }
					for _, te in ipairs(treeEntries) do
						if te.sha == false then
							cleanTreePayload.tree[#cleanTreePayload.tree + 1] = {
								path = te.path,
								mode = te.mode,
								type = te.type,
							}
						else
							cleanTreePayload.tree[#cleanTreePayload.tree + 1] = te
						end
					end
					local newTree = apiCall(
						"POST",
						string.format("/repos/%s/%s/git/trees", urlUtil.encodeComponent(owner), urlUtil.encodeComponent(repo)),
						cleanTreePayload
					)
					if type(newTree) == "table" and newTree.sha then
						local createdCommit = apiCall(
							"POST",
							string.format("/repos/%s/%s/git/commits", urlUtil.encodeComponent(owner), urlUtil.encodeComponent(repo)),
							{
								message = msg,
								tree = newTree.sha,
								parents = { parentCommitSha },
							}
						)
						if type(createdCommit) == "table" and createdCommit.sha then
							local updatedRef, patchErr = apiCall(
								"PATCH",
								string.format(
									"/repos/%s/%s/git/refs/heads/%s",
									urlUtil.encodeComponent(owner),
									urlUtil.encodeComponent(repo),
									urlUtil.encodeComponent(branch)
								),
								{ sha = createdCommit.sha, force = false }
							)
							if updatedRef then
								log.info("github", string.format(
									"Pushed commit %s to %s@%s (%d files)",
									createdCommit.sha:sub(1, 7),
									parsed.fullName,
									branch,
									#entries
								))
								return { sha = createdCommit.sha, files = #entries }
							else
								log.warn("github", "Ref update fallback: " .. tostring(patchErr))
							end
						end
					end
				end
			end
		end

		-- Fallback: Contents API (`PUT` / `DELETE` per file)
		local lastCommitSha = nil
		for _, item in ipairs(entries) do
			local endpoint = string.format(
				"/repos/%s/%s/contents/%s",
				urlUtil.encodeComponent(owner),
				urlUtil.encodeComponent(repo),
				urlUtil.encodePath(item.path)
			)
			if item.kind == "D" then
				if item.sha then
					local delRes, delErr = apiCall("DELETE", endpoint, {
						message = msg,
						sha = item.sha,
						branch = branch,
					})
					if not delRes then return nil, delErr end
					lastCommitSha = type(delRes.commit) == "table" and delRes.commit.sha or lastCommitSha
				end
			else
				local bodyPayload = {
					message = msg,
					content = base64.encode(item.newContent or ""),
					branch = branch,
				}
				if item.sha and item.sha ~= "" then
					bodyPayload.sha = item.sha
				end
				local putRes, putErr = apiCall("PUT", endpoint, bodyPayload)
				if not putRes then return nil, putErr end
				if type(putRes) == "table" then
					if type(putRes.content) == "table" then
						item.newSha = putRes.content.sha
					end
					if type(putRes.commit) == "table" then
						lastCommitSha = putRes.commit.sha
					end
				end
			end
		end

		log.info("github", string.format(
			"Pushed %d file(s) to %s@%s via Contents API",
			#entries,
			parsed.fullName,
			branch
		))
		return { sha = lastCommitSha or "pushed", files = #entries }
	end

	function M.createBranch(repoFullName, newBranch, baseBranch)
		if M.token() == "" then return nil, "Personal Access Token required" end
		local parsed, err = urlUtil.parseGitHubRepo(repoFullName)
		if not parsed then return nil, err end
		local from = baseBranch or "main"
		local refObj, refErr = apiCall(
			"GET",
			string.format(
				"/repos/%s/%s/git/ref/heads/%s",
				urlUtil.encodeComponent(parsed.owner),
				urlUtil.encodeComponent(parsed.repo),
				urlUtil.encodeComponent(from)
			)
		)
		if not refObj or type(refObj.object) ~= "table" then
			return nil, refErr or ("Base branch not found: " .. from)
		end
		local created, createErr = apiCall(
			"POST",
			string.format("/repos/%s/%s/git/refs", urlUtil.encodeComponent(parsed.owner), urlUtil.encodeComponent(parsed.repo)),
			{
				ref = "refs/heads/" .. util.trim(newBranch),
				sha = refObj.object.sha,
			}
		)
		if not created then return nil, createErr end
		log.info("github", "Created branch '" .. newBranch .. "' on " .. parsed.fullName)
		return created
	end

	return M
end
