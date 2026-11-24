--!nocheck
-- VS-RBLX Standalone LocalScript (StarterPlayerScripts / StarterGui)
-- VS-RBLX v1.0.0 | Visual Studio Code Clone in Roblox (100% Luau)
-- Build: 1.0.0-6a1673983f7469d3
-- Modules: 69 | Source size: 374032 bytes
--
-- Executor:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/TheStrongestOfTomorrow/VS-RBLX/main/dist/vsrblx.lua"))()
-- Roblox Studio:
--   Paste dist/vsrblx.localscript.lua inside StarterPlayer > StarterPlayerScripts

local __VSRBLX_BUILD = "1.0.0-6a1673983f7469d3"
local __VSRBLX_MODULES = {}

-- [embedding/scope] (521 bytes)
__VSRBLX_MODULES["embedding/scope"] = (function()
-- Scoped host context validation for embedded VS-RBLX instances.
return function(_env)
	local M = {}

	function M.normalise(hostContext)
		local ctx = type(hostContext) == "table" and hostContext or {}
		return {
			ui = ctx.ui ~= false,
			workspace = type(ctx.workspace) == "string" and ctx.workspace or nil,
			repo = type(ctx.repo) == "string" and ctx.repo or nil,
			theme = type(ctx.theme) == "string" and ctx.theme or nil,
			initialFiles = type(ctx.files) == "table" and ctx.files or nil,
		}
	end

	return M
end
end)()

-- [embedding/sdk] (2091 bytes)
__VSRBLX_MODULES["embedding/sdk"] = (function()
-- Public programmatic SDK returned by `loadstring(...)()` and stored in `getgenv().VSRBLX`.
return function(env)
	local fsx = env.require("runtime/fsx")
	local config = env.require("runtime/config")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")
	local gitState = env.require("runtime/git_state")
	local commands = env.require("runtime/command_catalog")
	local theme = env.require("ui/theme")
	local githubSync = env.require("tools/github_sync")
	local execution = env.require("tools/execution")

	local M = {}

	function M.buildHandle(app, destroyFn)
		local handle = {
			version = env.info.version,
			buildId = env.info.build,
			build = env.info.build,
			alive = true,
			env = env,
			_env = env,
			app = app,
			fs = fsx,
			config = config,
			workspace = workspaceFs,
			codeStore = codeStore,
			editor = codeStore,
			git = gitState,
			github = githubSync,
			theme = theme,
			openFile = function(path, opts) return codeStore.openFile(path, opts) end,
			writeFile = function(path, content) return workspaceFs.writeFile(path, content) end,
			readFile = function(path) return workspaceFs.readFile(path) end,
			cloneRepo = function(repo, opts) return githubSync.cloneRepo(repo, opts) end,
			pullRepo = function() return githubSync.pull() end,
			commitAndPush = function(msg) return githubSync.commitAndPush(msg) end,
			pushRepo = function(msg) return githubSync.commitAndPush(msg) end,
			runActive = function() return execution.runActive() end,
			runCommand = function(id, ...) return commands.run(id, ...) end,
			setTheme = function(themeId) return theme.apply(themeId) end,
			show = function() if app and app.window then app.window.show() end end,
			hide = function() if app and app.window then app.window.hide() end end,
			toggle = function() if app and app.window then app.window.toggle() end end,
		}
		handle.destroy = function()
			if not handle.alive then return end
			handle.alive = false
			if destroyFn then destroyFn() end
		end
		return handle
	end

	M.create = M.buildHandle
	return M
end
end)()

-- [net/base64] (1779 bytes)
__VSRBLX_MODULES["net/base64"] = (function()
-- Pure Luau Base64 encoder/decoder used for GitHub REST & Git Data API payloads.
return function(_env)
	local M = {}
	local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local DECODE_MAP = {}
	for i = 1, #ALPHABET do
		DECODE_MAP[ALPHABET:byte(i)] = i - 1
	end

	function M.encode(raw)
		local data = tostring(raw or "")
		local out = {}
		local n = #data
		for i = 1, n, 3 do
			local b1 = data:byte(i) or 0
			local b2 = data:byte(i + 1)
			local b3 = data:byte(i + 2)
			local triple = b1 * 65536 + (b2 or 0) * 256 + (b3 or 0)

			local c1 = math.floor(triple / 262144) % 64 + 1
			local c2 = math.floor(triple / 4096) % 64 + 1
			local c3 = math.floor(triple / 64) % 64 + 1
			local c4 = (triple % 64) + 1

			out[#out + 1] = ALPHABET:sub(c1, c1)
			out[#out + 1] = ALPHABET:sub(c2, c2)
			out[#out + 1] = b2 and ALPHABET:sub(c3, c3) or "="
			out[#out + 1] = b3 and ALPHABET:sub(c4, c4) or "="
		end
		return table.concat(out)
	end

	function M.decode(encoded)
		local clean = tostring(encoded or ""):gsub("[^A-Za-z0-9%+/=]", "")
		local out = {}
		local n = #clean
		for i = 1, n, 4 do
			local a = DECODE_MAP[clean:byte(i)] or 0
			local b = DECODE_MAP[clean:byte(i + 1)] or 0
			local raw3 = clean:byte(i + 2)
			local raw4 = clean:byte(i + 3)
			local c = (raw3 and raw3 ~= 61) and (DECODE_MAP[raw3] or 0) or 0
			local d = (raw4 and raw4 ~= 61) and (DECODE_MAP[raw4] or 0) or 0

			local triple = a * 262144 + b * 4096 + c * 64 + d
			out[#out + 1] = string.char(math.floor(triple / 65536) % 256)
			if raw3 and raw3 ~= 61 then
				out[#out + 1] = string.char(math.floor(triple / 256) % 256)
			end
			if raw4 and raw4 ~= 61 then
				out[#out + 1] = string.char(triple % 256)
			end
		end
		return table.concat(out)
	end

	return M
end
end)()

-- [net/gist] (1474 bytes)
__VSRBLX_MODULES["net/gist"] = (function()
-- GitHub Gist and raw HTTP URL loader for VS-RBLX.
return function(env)
	local util = env.require("runtime/util")
	local http = env.require("net/http")
	local headersUtil = env.require("net/headers")
	local github = env.require("net/github")
	local log = env.require("runtime/log")

	local M = {}

	function M.loadRawUrl(targetUrl)
		local clean = util.trim(targetUrl or "")
		if clean == "" then return nil, "empty URL" end
		local res = http.send({
			url = clean,
			method = "GET",
			json = false,
		})
		if not res.ok then
			return nil, res.error or ("HTTP " .. tostring(res.status))
		end
		local fileName = clean:match("/([^/%?#]+)[%?#]?.*$") or "remote.luau"
		log.info("http", "Fetched URL into buffer: " .. clean)
		return {
			name = fileName,
			content = res.body,
		}
	end

	function M.loadGist(gistIdOrUrl)
		local raw = util.trim(gistIdOrUrl or "")
		local id = raw:match("([%x]+)$")
		if not id or #id < 6 then return nil, "Invalid Gist ID or URL" end
		local res = http.send({
			url = "https://api.github.com/gists/" .. id,
			method = "GET",
			headers = headersUtil.github(github.token(), false),
		})
		if not res.ok or type(res.json) ~= "table" or type(res.json.files) ~= "table" then
			return nil, "Could not fetch Gist " .. id
		end
		local files = {}
		for fname, item in pairs(res.json.files) do
			if type(item) == "table" and type(item.content) == "string" then
				files[fname] = item.content
			end
		end
		return files
	end

	return M
end
end)()

-- [net/github] (14081 bytes)
__VSRBLX_MODULES["net/github"] = (function()
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
end)()

-- [net/headers] (835 bytes)
__VSRBLX_MODULES["net/headers"] = (function()
-- HTTP header helper with automatic credential redaction for logs.
return function(_env)
	local M = {}

	function M.github(token, hasJsonBody)
		local h = {
			["Accept"] = "application/vnd.github+json",
			["X-GitHub-Api-Version"] = "2022-11-28",
			["User-Agent"] = "VS-RBLX/1.0 (Roblox-Luau-Workbench)",
		}
		if type(token) == "string" and token ~= "" then
			h["Authorization"] = "Bearer " .. token
		end
		if hasJsonBody then
			h["Content-Type"] = "application/json"
		end
		return h
	end

	function M.redact(headers)
		local out = {}
		if type(headers) ~= "table" then return out end
		for k, v in pairs(headers) do
			local lk = tostring(k):lower()
			if lk == "authorization" or lk == "x-api-key" or lk == "cookie" then
				out[k] = "<redacted>"
			else
				out[k] = tostring(v)
			end
		end
		return out
	end

	return M
end
end)()

-- [net/http] (3956 bytes)
__VSRBLX_MODULES["net/http"] = (function()
-- Executor HTTP transport layer (`request` / `http_request` / `syn.request` /
-- `http.request` / `fluxus.request` / `game:HttpGet` / `HttpService:RequestAsync`).
return function(env)
	local caps = env.require("runtime/caps")
	local util = env.require("runtime/util")
	local clock = env.require("runtime/clock")
	local headersUtil = env.require("net/headers")
	local log = env.require("runtime/log")
	local signal = env.require("runtime/signal")

	local HISTORY_MAX = 100
	local M = {
		history = {},
		changed = signal.new("http.changed"),
	}

	local function record(entry)
		M.history[#M.history + 1] = entry
		if #M.history > HISTORY_MAX then
			table.remove(M.history, 1)
		end
		M.changed:fire(entry)
	end

	function M.send(spec)
		local url = tostring(spec.url or spec.Url or "")
		local method = tostring(spec.method or spec.Method or "GET"):upper()
		local reqHeaders = spec.headers or spec.Headers or {}
		local body = spec.body or spec.Body
		if type(body) == "table" then
			body = util.jsonEncode(body)
		end

		local startMs = clock.ms()
		local response = nil
		local transportUsed = caps.http

		if caps.fn.request then
			local ok, raw = pcall(caps.fn.request, {
				Url = url,
				Method = method,
				Headers = reqHeaders,
				Body = body,
			})
			if ok and type(raw) == "table" then
				local code = tonumber(raw.StatusCode or raw.Status) or 0
				response = {
					ok = code >= 200 and code < 300,
					status = code,
					body = tostring(raw.Body or ""),
					headers = raw.Headers or {},
				}
			else
				response = { ok = false, status = 0, body = "", error = tostring(raw or "request failed") }
			end
		elseif method == "GET" and caps.fn.httpGet then
			transportUsed = "game:HttpGet"
			local ok, rawBody = pcall(caps.fn.httpGet, url)
			if ok and type(rawBody) == "string" then
				response = { ok = true, status = 200, body = rawBody, headers = {} }
			else
				response = { ok = false, status = 0, body = "", error = tostring(rawBody or "HttpGet failed") }
			end
		elseif env.hs and type(env.hs.RequestAsync) == "function" then
			transportUsed = "HttpService"
			local cleanHeaders = {}
			for k, v in pairs(reqHeaders) do
				local lk = k:lower()
				if lk ~= "user-agent" and lk ~= "host" and lk ~= "content-length" then
					cleanHeaders[k] = v
				end
			end
			local ok, raw = pcall(function()
				return env.hs:RequestAsync({
					Url = url,
					Method = method,
					Headers = cleanHeaders,
					Body = body,
				})
			end)
			if ok and type(raw) == "table" then
				local code = tonumber(raw.StatusCode) or 0
				response = {
					ok = code >= 200 and code < 300,
					status = code,
					body = tostring(raw.Body or ""),
					headers = raw.Headers or {},
				}
			else
				response = { ok = false, status = 0, body = "", error = tostring(raw or "RequestAsync failed") }
			end
		else
			response = {
				ok = false,
				status = 0,
				body = "",
				error = "No executor HTTP function (`request`, `http_request`, or `HttpService`) available.",
			}
		end

		local durationMs = clock.ms() - startMs
		if response.body ~= "" and spec.json ~= false then
			local decoded = util.jsonDecode(response.body)
			if decoded ~= nil then
				response.json = decoded
			end
		end

		record({
			time = clock.timestamp(),
			method = method,
			url = url,
			status = response.status,
			ok = response.ok,
			ms = durationMs,
			bytes = #response.body,
			transport = transportUsed,
			headers = headersUtil.redact(reqHeaders),
			error = response.error,
		})

		if not response.ok and not spec.quiet then
			log.warn("http", string.format("%s %s -> %d (%s)", method, url, response.status, response.error or "HTTP error"))
		end

		return response
	end

	function M.get(url, headers, opts)
		opts = opts or {}
		opts.url = url
		opts.method = "GET"
		opts.headers = headers
		return M.send(opts)
	end

	function M.clearHistory()
		for i = #M.history, 1, -1 do M.history[i] = nil end
		M.changed:fire(nil)
	end

	return M
end
end)()

-- [net/url] (1802 bytes)
__VSRBLX_MODULES["net/url"] = (function()
-- URL encoder and GitHub repository specifier parser for VS-RBLX.
return function(env)
	local util = env.require("runtime/util")
	local M = {}

	function M.encodeComponent(value)
		local s = tostring(value or "")
		return (s:gsub("([^%w%-_%.~])", function(c)
			return string.format("%%%02X", c:byte())
		end))
	end

	function M.encodePath(path)
		local clean = util.normalisePath(path)
		local parts = util.split(clean, "/")
		for i = 1, #parts do
			parts[i] = M.encodeComponent(parts[i])
		end
		return table.concat(parts, "/")
	end

	-- Parses "owner/repo", "owner/repo@branch", "https://github.com/owner/repo",
	-- or "https://github.com/owner/repo/tree/branch/subpath".
	function M.parseGitHubRepo(input)
		local raw = util.trim(input or "")
		if raw == "" then return nil, "empty repository input" end
		raw = raw:gsub("%.git$", ""):gsub("/+$", "")

		local ghOwner, ghRepo, ghRest = raw:match("^https?://github%.com/([^/%s]+)/([^/%s]+)(.*)$")
		if ghOwner and ghRepo then
			local branch = nil
			local subpath = ""
			if ghRest and ghRest ~= "" then
				local b, sub = ghRest:match("^/tree/([^/]+)/?(.*)$")
				if b then
					branch = b
					subpath = sub or ""
				end
			end
			return {
				owner = ghOwner,
				repo = ghRepo,
				fullName = ghOwner .. "/" .. ghRepo,
				branch = branch,
				subpath = util.normalisePath(subpath),
			}
		end

		local owner, repoAndBranch = raw:match("^([%w%-_%.]+)/([%w%-_%.@]+)$")
		if owner and repoAndBranch then
			local repo, branch = repoAndBranch:match("^([^@]+)@(.+)$")
			repo = repo or repoAndBranch
			return {
				owner = owner,
				repo = repo,
				fullName = owner .. "/" .. repo,
				branch = branch,
				subpath = "",
			}
		end

		return nil, "Use 'owner/repo', 'owner/repo@branch', or 'https://github.com/owner/repo'"
	end

	return M
end
end)()

-- [runtime/boot_progress] (467 bytes)
__VSRBLX_MODULES["runtime/boot_progress"] = (function()
-- Startup stage tracker for VS-RBLX boot splash.
return function(env)
	local clock = env.require("runtime/clock")
	local signal = env.require("runtime/signal")

	local M = {
		stage = "init",
		detail = "Starting VS-RBLX...",
		startedAt = clock.ms(),
		changed = signal.new("boot.changed"),
	}

	function M.update(stage, detail)
		M.stage = tostring(stage or M.stage)
		M.detail = tostring(detail or M.detail)
		M.changed:fire(M.stage, M.detail)
	end

	return M
end
end)()

-- [runtime/caps] (5487 bytes)
__VSRBLX_MODULES["runtime/caps"] = (function()
-- Host capability probe for Roblox Executors and Studio LocalScripts.
--
-- Probes executor filesystem (`readfile`, `writefile`, `listfiles`, `makefolder`,
-- `delfile`, `delfolder`), executor HTTP (`request`, `http_request`, `syn.request`,
-- `http.request`, `fluxus.request`, `game:HttpGet`, `HttpService`), script execution
-- (`loadstring`), clipboard, `gethui`, and `decompile`.
return function(env)
	local M = {}

	local function callable(value)
		return type(value) == "function" and value or nil
	end

	local function findRequests()
		local candidates = {
			{ name = "request", fn = callable(request) },
			{ name = "http_request", fn = callable(http_request) },
			{ name = "syn.request", fn = type(syn) == "table" and callable(syn.request) or nil },
			{ name = "http.request", fn = type(http) == "table" and callable(http.request) or nil },
			{ name = "fluxus.request", fn = type(fluxus) == "table" and callable(fluxus.request) or nil },
		}
		local found, seen = {}, {}
		for _, candidate in ipairs(candidates) do
			if candidate.fn and not seen[candidate.fn] then
				seen[candidate.fn] = true
				found[#found + 1] = candidate
			end
		end
		return found
	end

	local function findClipboard()
		return callable(setclipboard)
			or callable(toclipboard)
			or (type(syn) == "table" and callable(syn.write_clipboard))
			or nil
	end

	local requestAliases = findRequests()
	local primaryRequest = requestAliases[1]
	local requestFn = primaryRequest and primaryRequest.fn or nil
	local requestName = primaryRequest and primaryRequest.name or nil

	local compiler = callable(loadstring)
	if not compiler and callable(getgenv) then
		local ok, globals = pcall(getgenv)
		if ok and type(globals) == "table" then
			local readOk, candidate = pcall(function() return globals.loadstring end)
			if readOk then compiler = callable(candidate) end
		end
	end

	local httpGetFn = nil
	pcall(function()
		if game and type(game.HttpGet) == "function" then
			httpGetFn = function(url)
				return game:HttpGet(url)
			end
		end
	end)

	M.fn = {
		request = requestFn,
		httpGet = httpGetFn,
		readfile = callable(readfile),
		writefile = callable(writefile),
		appendfile = callable(appendfile),
		isfile = callable(isfile),
		isfolder = callable(isfolder),
		makefolder = callable(makefolder),
		listfiles = callable(listfiles),
		delfile = callable(delfile),
		delfolder = callable(delfolder),
		loadstring = compiler,
		getgenv = callable(getgenv),
		gethui = callable(gethui),
		clipboard = findClipboard(),
		identify = callable(identifyexecutor) or callable(getexecutorname),
		decompile = callable(decompile),
		getscriptbytecode = callable(getscriptbytecode),
		customasset = callable(getcustomasset),
		cloneref = callable(cloneref),
	}

	M.requestName = requestName
	M.fs = (M.fn.readfile ~= nil and M.fn.writefile ~= nil)
	M.fsList = (M.fn.listfiles ~= nil)
	M.fsFolders = (M.fn.makefolder ~= nil and M.fn.isfolder ~= nil)
	M.exec = (M.fn.loadstring ~= nil)
	M.clipboard = (M.fn.clipboard ~= nil)
	M.decompile = (M.fn.decompile ~= nil)

	if M.fn.request then
		M.http = "executor"
		M.httpWrite = true
	elseif M.fn.httpGet then
		M.http = "httpget"
		M.httpWrite = false
	else
		local ok, available = pcall(function()
			return env.services.HttpService ~= nil
		end)
		M.http = (ok and available) and "httpservice" or "none"
		M.httpWrite = (M.http == "httpservice")
	end

	M.executor = "LocalScript"
	if M.fn.identify then
		local ok, name, ver = pcall(M.fn.identify)
		if ok and type(name) == "string" and name ~= "" then
			M.executor = ver and (name .. " " .. tostring(ver)) or name
		end
	elseif M.fs or M.fn.request then
		M.executor = "Executor"
	end

	function M.matrix()
		return {
			{ key = "executor", label = "Host Runtime", value = M.executor, ok = true },
			{ key = "fs", label = "Local Disk (readfile/writefile)", value = M.fs and "Supported" or "Virtual Memory Fallback", ok = M.fs },
			{ key = "fsList", label = "Directory Scan (listfiles/makefolder)", value = M.fsList and "Supported" or "Virtual Tree", ok = M.fsList },
			{ key = "http", label = "HTTP Transport", value = M.http .. (M.requestName and (" (" .. M.requestName .. ")") or ""), ok = M.http ~= "none" },
			{ key = "githubPush", label = "GitHub Push/Sync (PUT/POST)", value = M.httpWrite and "Supported" or "Read-Only (HttpGet)", ok = M.httpWrite },
			{ key = "exec", label = "Luau Execution (loadstring)", value = M.exec and "Supported" or "Unavailable", ok = M.exec },
			{ key = "clipboard", label = "System Clipboard", value = M.clipboard and "Supported" or "Internal Buffer", ok = M.clipboard },
			{ key = "decompile", label = "Script Decompiler", value = M.decompile and "Supported" or "Unavailable", ok = M.decompile },
		}
	end

	function M.summary()
		return string.format(
			"%s | disk:%s | http:%s | exec:%s",
			M.executor,
			M.fs and "executor-fs" or "memory",
			M.requestName or M.http,
			M.exec and "yes" or "no"
		)
	end

	function M.has(feature)
		if feature == "fs" then return M.fs == true end
		if feature == "fsTree" then return M.fsList == true and M.fsFolders == true end
		if feature == "httpRequest" then return M.fn.request ~= nil or M.http == "httpservice" end
		if feature == "httpGet" then return M.fn.httpGet ~= nil end
		if feature == "loadstring" then return M.exec == true end
		if feature == "clipboard" then return M.clipboard == true end
		if feature == "decompile" then return M.decompile == true end
		return M[feature] == true
	end

	return M
end
end)()

-- [runtime/clipboard] (469 bytes)
__VSRBLX_MODULES["runtime/clipboard"] = (function()
-- System clipboard bridge (`setclipboard`/`toclipboard`) with internal buffer fallback.
return function(env)
	local caps = env.require("runtime/caps")
	local M = { buffer = "" }

	function M.set(text)
		local value = tostring(text or "")
		M.buffer = value
		if caps.fn.clipboard then
			local ok = pcall(caps.fn.clipboard, value)
			return ok, ok and "system" or "internal"
		end
		return true, "internal"
	end

	function M.get()
		return M.buffer
	end

	return M
end
end)()

-- [runtime/clock] (2021 bytes)
__VSRBLX_MODULES["runtime/clock"] = (function()
-- Clock, debounce and throttle utilities built on Roblox's task library.
return function(_env)
	local unpackValues = table.unpack or unpack
	local M = {}

	function M.now()
		if type(DateTime) == "table" and type(DateTime.now) == "function" then
			local ok, dt = pcall(DateTime.now)
			if ok and dt and dt.UnixTimestampMillis then
				return dt.UnixTimestampMillis / 1000
			end
		end
		if type(tick) == "function" then return tick() end
		return os.clock()
	end

	function M.ms()
		return math.floor(M.now() * 1000)
	end

	function M.timestamp()
		if type(DateTime) == "table" and type(DateTime.now) == "function" then
			local ok, dt = pcall(function()
				return DateTime.fromUnixTimestamp(DateTime.now().UnixTimestamp):FormatLocalTime("HH:mm:ss", "en-us")
			end)
			if ok and type(dt) == "string" then return dt end
		end
		local secs = math.floor(M.now()) % 86400
		local h = math.floor(secs / 3600)
		local m = math.floor((secs % 3600) / 60)
		local s = secs % 60
		return string.format("%02d:%02d:%02d", h, m, s)
	end

	function M.debounce(seconds, fn)
		local pendingThread = nil
		local latestArgs = nil
		local cancelled = false
		local handle = {}

		local function flush()
			pendingThread = nil
			if cancelled or not latestArgs then return end
			local args = latestArgs
			latestArgs = nil
			fn(unpackValues(args, 1, args.n))
		end

		function handle.call(...)
			cancelled = false
			latestArgs = { n = select("#", ...), ... }
			if pendingThread then
				pcall(task.cancel, pendingThread)
				pendingThread = nil
			end
			pendingThread = task.delay(seconds or 0.2, flush)
		end

		function handle.flush()
			if pendingThread then
				pcall(task.cancel, pendingThread)
				pendingThread = nil
			end
			flush()
		end

		function handle.cancel()
			cancelled = true
			latestArgs = nil
			if pendingThread then
				pcall(task.cancel, pendingThread)
				pendingThread = nil
			end
		end

		return setmetatable(handle, {
			__call = function(_, ...)
				handle.call(...)
			end,
		})
	end

	return M
end
end)()

-- [runtime/code_diff] (2838 bytes)
__VSRBLX_MODULES["runtime/code_diff"] = (function()
-- Line-by-line LCS diff engine for VS-RBLX Source Control and unified Diff Viewer.
return function(env)
	local util = env.require("runtime/util")
	local M = {}

	function M.compute(oldSource, newSource)
		local a = util.lines(oldSource or "")
		local b = util.lines(newSource or "")
		local m, n = #a, #b

		local prefix = 0
		while prefix < m and prefix < n and a[prefix + 1] == b[prefix + 1] do
			prefix = prefix + 1
		end
		local suffix = 0
		while suffix < (m - prefix) and suffix < (n - prefix)
			and a[m - suffix] == b[n - suffix] do
			suffix = suffix + 1
		end

		local rows = {}
		local addedCount, removedCount = 0, 0

		for i = 1, prefix do
			rows[#rows + 1] = { kind = "context", oldLine = i, newLine = i, text = a[i] }
		end

		local midM = m - prefix - suffix
		local midN = n - prefix - suffix

		if midM == 0 and midN == 0 then
			return { rows = rows, added = 0, removed = 0 }
		end

		if midM * midN <= 90000 then
			local dp = {}
			for i = 0, midM do
				dp[i] = {}
				dp[i][0] = 0
			end
			for j = 0, midN do dp[0][j] = 0 end
			for i = 1, midM do
				local ai = a[prefix + i]
				local row = dp[i]
				local prevRow = dp[i - 1]
				for j = 1, midN do
					if ai == b[prefix + j] then
						row[j] = prevRow[j - 1] + 1
					else
						local up = prevRow[j]
						local left = row[j - 1]
						row[j] = up >= left and up or left
					end
				end
			end

			local midRows = {}
			local i, j = midM, midN
			while i > 0 or j > 0 do
				if i > 0 and j > 0 and a[prefix + i] == b[prefix + j] then
					midRows[#midRows + 1] = {
						kind = "context",
						oldLine = prefix + i,
						newLine = prefix + j,
						text = a[prefix + i],
					}
					i = i - 1
					j = j - 1
				elseif j > 0 and (i == 0 or dp[i][j - 1] >= dp[i - 1][j]) then
					addedCount = addedCount + 1
					midRows[#midRows + 1] = {
						kind = "add",
						oldLine = nil,
						newLine = prefix + j,
						text = b[prefix + j],
					}
					j = j - 1
				else
					removedCount = removedCount + 1
					midRows[#midRows + 1] = {
						kind = "remove",
						oldLine = prefix + i,
						newLine = nil,
						text = a[prefix + i],
					}
					i = i - 1
				end
			end
			for k = #midRows, 1, -1 do
				rows[#rows + 1] = midRows[k]
			end
		else
			for i = 1, midM do
				removedCount = removedCount + 1
				rows[#rows + 1] = { kind = "remove", oldLine = prefix + i, newLine = nil, text = a[prefix + i] }
			end
			for j = 1, midN do
				addedCount = addedCount + 1
				rows[#rows + 1] = { kind = "add", oldLine = nil, newLine = prefix + j, text = b[prefix + j] }
			end
		end

		for k = 1, suffix do
			rows[#rows + 1] = {
				kind = "context",
				oldLine = m - suffix + k,
				newLine = n - suffix + k,
				text = a[m - suffix + k],
			}
		end

		return {
			rows = rows,
			added = addedCount,
			removed = removedCount,
		}
	end

	return M
end
end)()

-- [runtime/code_folding] (2093 bytes)
__VSRBLX_MODULES["runtime/code_folding"] = (function()
-- Indentation-based code folding regions and symbol extraction for breadcrumbs / outline.
return function(env)
	local util = env.require("runtime/util")
	local M = {}

	local function indentWidth(line)
		local width = 0
		for i = 1, #line do
			local c = line:sub(i, i)
			if c == "\t" then
				width = width + 4
			elseif c == " " then
				width = width + 1
			else
				break
			end
		end
		return width
	end

	function M.regions(source)
		local lines = util.lines(source or "")
		local map = {}
		local n = #lines

		for i = 1, n - 1 do
			local line = lines[i]
			if line:find("%S") then
				local baseIndent = indentWidth(line)
				local j = i + 1
				local lastFold = nil
				while j <= n do
					local nxt = lines[j]
					if nxt:find("%S") then
						if indentWidth(nxt) > baseIndent then
							lastFold = j
						else
							break
						end
					end
					j = j + 1
				end
				if lastFold and lastFold > i then
					map[i] = lastFold
				end
			end
		end
		return map
	end

	function M.symbols(source, langId)
		local lines = util.lines(source or "")
		local out = {}
		for i, line in ipairs(lines) do
			local fnName = line:match("function%s+([%w_%.:]+)%s*%(")
				or line:match("local%s+function%s+([%w_]+)%s*%(")
				or line:match("^%s*def%s+([%w_]+)%s*%(")
				or line:match("^%s*async%s+def%s+([%w_]+)%s*%(")
				or line:match("^%s*fn%s+([%w_]+)%s*[%(<]")
				or line:match("^%s*pub%s+fn%s+([%w_]+)%s*[%(<]")
				or line:match("^%s*func%s+([%w_]+)%s*%(")
			local className = line:match("^%s*class%s+([%w_]+)")
				or line:match("^%s*export%s+class%s+([%w_]+)")
				or line:match("^%s*export%s+interface%s+([%w_]+)")
				or line:match("^%s*interface%s+([%w_]+)")
				or line:match("^%s*struct%s+([%w_]+)")
			if fnName then
				out[#out + 1] = { kind = "function", name = fnName, line = i }
			elseif className then
				out[#out + 1] = { kind = "class", name = className, line = i }
			elseif langId == "markdown" and line:match("^#+%s+(.+)$") then
				out[#out + 1] = { kind = "heading", name = line:match("^#+%s+(.+)$"), line = i }
			end
		end
		return out
	end

	return M
end
end)()

-- [runtime/code_lexer] (10002 bytes)
__VSRBLX_MODULES["runtime/code_lexer"] = (function()
-- Incremental line-state multi-language syntax highlighter for VS-RBLX.
-- Raw document source is never mutated by RichText presentation.
return function(env)
	local languages = env.require("runtime/languages")
	local util = env.require("runtime/util")

	local BACKTICK = string.char(96)
	local M = {}

	function M.lines(source)
		local lines, starts, first = {}, {}, 1
		local clean = tostring(source or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
		local pos = 1
		while true do
			local nl = clean:find("\n", pos, true)
			if not nl then
				local seg = clean:sub(pos)
				lines[#lines + 1] = seg
				starts[#starts + 1] = first
				break
			end
			local seg = clean:sub(pos, nl - 1)
			lines[#lines + 1] = seg
			starts[#starts + 1] = first
			first = first + #seg + 1
			pos = nl + 1
		end
		if #lines == 0 then
			lines[1], starts[1] = "", 1
		end
		return lines, starts
	end

	local function longBracketAt(text, at)
		local eq = text:match("^%[(=*)%[", at)
		if not eq then return nil, nil end
		return "]" .. eq .. "]", #eq + 2
	end

	local function lexMarkdownLine(text, state)
		local spans = {}
		if state == "fence" then
			if text:match("^%s*" .. BACKTICK .. BACKTICK .. BACKTICK) then
				spans[1] = { kind = "keyword", first = 1, last = #text }
				return spans, ""
			end
			if #text > 0 then
				spans[1] = { kind = "string", first = 1, last = #text }
			end
			return spans, "fence"
		end
		if text:match("^%s*" .. BACKTICK .. BACKTICK .. BACKTICK) then
			spans[1] = { kind = "keyword", first = 1, last = #text }
			return spans, "fence"
		end
		if text:match("^%s*#+%s") then
			spans[1] = { kind = "keyword", first = 1, last = #text }
			return spans, ""
		end
		if text:match("^%s*>") then
			spans[1] = { kind = "comment", first = 1, last = #text }
			return spans, ""
		end
		local i = 1
		while i <= #text do
			local ch = text:sub(i, i)
			if ch == BACKTICK then
				local stop = text:find(BACKTICK, i + 1, true)
				local last = stop or #text
				spans[#spans + 1] = { kind = "string", first = i, last = last }
				i = last + 1
			elseif ch == "*" and text:sub(i + 1, i + 1) == "*" then
				local stop = text:find("**", i + 2, true)
				local last = stop and (stop + 1) or #text
				spans[#spans + 1] = { kind = "type", first = i, last = last }
				i = last + 1
			elseif ch == "[" then
				local close = text:find(")", i + 1, true)
				if close and text:sub(i, close):find("%]%(") then
					spans[#spans + 1] = { kind = "call", first = i, last = close }
					i = close + 1
				else
					spans[#spans + 1] = { kind = "text", first = i, last = i }
					i = i + 1
				end
			else
				local prev = spans[#spans]
				if prev and prev.kind == "text" and prev.last + 1 == i then
					prev.last = i
				else
					spans[#spans + 1] = { kind = "text", first = i, last = i }
				end
				i = i + 1
			end
		end
		return spans, ""
	end

	function M.line(text, state, langId)
		local lang = languages.get(langId)
		state = state or ""
		if lang.id == "plaintext" then
			if #text == 0 then return {}, "" end
			return { { kind = "text", first = 1, last = #text } }, ""
		end
		if lang.markdownMode then
			return lexMarkdownLine(text, state)
		end

		local spans = {}
		local i = 1
		local len = #text

		local function add(kind, a, b)
			if b < a then
				i = a + 1
				return
			end
			local previous = spans[#spans]
			if previous and previous.kind == kind and previous.last + 1 == a then
				previous.last = b
			else
				spans[#spans + 1] = { kind = kind, first = a, last = b }
			end
			i = b + 1
		end

		local lineCom = lang.lineComment
		local blockOpen = lang.blockComment and lang.blockComment[1] or nil
		local blockClose = lang.blockComment and lang.blockComment[2] or nil

		if state == "" and lang.preprocessor and text:match("^%s*#[%a_]+") then
			add("decorator", 1, len)
			return spans, ""
		end

		while i <= len do
			if state ~= "" then
				local kind = state:sub(1, 1) == "c" and "comment" or "string"
				local closeSeq = state:sub(2)
				local stop = text:find(closeSeq, i, true)
				if stop then
					add(kind, i, stop + #closeSeq - 1)
					state = ""
				else
					add(kind, i, len)
				end
			else
				local ch = text:sub(i, i)
				if lang.id == "luau" and blockOpen and text:sub(i, i + 1) == "--" then
					local closeBr, width = longBracketAt(text, i + 2)
					if closeBr then
						local stop = text:find(closeBr, i + 2 + width, true)
						if stop then
							add("comment", i, stop + #closeBr - 1)
						else
							add("comment", i, len)
							state = "c" .. closeBr
						end
					else
						add("comment", i, len)
					end
				elseif blockOpen and text:sub(i, i + #blockOpen - 1) == blockOpen then
					local stop = text:find(blockClose, i + #blockOpen, true)
					if stop then
						add("comment", i, stop + #blockClose - 1)
					else
						add("comment", i, len)
						state = "c" .. blockClose
					end
				elseif lineCom and text:sub(i, i + #lineCom - 1) == lineCom then
					add("comment", i, len)
				elseif lang.tripleStrings and (text:sub(i, i + 2) == '"""' or text:sub(i, i + 2) == "'''") then
					local quote3 = text:sub(i, i + 2)
					local stop = text:find(quote3, i + 3, true)
					if stop then
						add("string", i, stop + 2)
					else
						add("string", i, len)
						state = "s" .. quote3
					end
				elseif lang.longStrings and ch == "[" and longBracketAt(text, i) then
					local closeBr, width = longBracketAt(text, i)
					local stop = text:find(closeBr, i + width, true)
					if stop then
						add("string", i, stop + #closeBr - 1)
					else
						add("string", i, len)
						state = "s" .. closeBr
					end
				elseif ch == '"' or ch == "'" or (lang.templateStrings and ch == BACKTICK) then
					local j = i + 1
					while j <= len do
						local cj = text:sub(j, j)
						if cj == "\\" then
							j = j + 2
						elseif cj == ch then
							j = j + 1
							break
						else
							j = j + 1
						end
					end
					local endIdx = math.min(len, j - 1)
					local isProp = false
					if lang.jsonMode and ch == '"' then
						if text:match("^%s*:", endIdx + 1) then isProp = true end
					end
					if ch == BACKTICK and endIdx == len and text:sub(len, len) ~= BACKTICK then
						state = "s" .. BACKTICK
					end
					add(isProp and "property" or "string", i, endIdx)
				elseif lang.decorators and (ch == "@" or (lang.id == "rust" and text:sub(i, i + 1) == "#[")) then
					local matchEnd = text:match("^@[%w_%.]+()", i) or text:match("^#%[[^%]]*%]?()", i)
					if matchEnd then
						add("decorator", i, matchEnd - 1)
					else
						add("text", i, i)
					end
				elseif lang.markupMode and (ch == "<" or ch == ">") then
					local tagMatch = text:match("^</?[%w_%-:]+()", i)
					if tagMatch then
						add("tag", i, tagMatch - 1)
					else
						add("tag", i, i)
					end
				elseif lang.jsonMode and i == 1 and text:match("^%s*[%w_%-%.]+%s*[:=]") then
					local keyEnd = text:match("^%s*[%w_%-%.]+()", 1)
					add("property", 1, keyEnd - 1)
				elseif ch:match("[%a_]") then
					local word = text:match("^[%a_][%w_%-]*", i)
					if not lang.markupMode and lang.id ~= "css" then
						word = text:match("^[%a_][%w_]*", i)
					end
					local lookup = lang.caseInsensitive and word:lower() or word
					local afterIdx = i + #word
					local isCall = text:match("^%s*[%(%!]", afterIdx) ~= nil
					local kind = "text"
					if lang.keywords[lookup] then
						kind = "keyword"
					elseif lang.types and lang.types[lookup] then
						kind = "type"
					elseif lang.builtins and lang.builtins[lookup] then
						kind = "builtin"
					elseif lang.markupMode and text:match("^%s*=", afterIdx) then
						kind = "property"
					elseif isCall then
						kind = "call"
					end
					add(kind, i, i + #word - 1)
				elseif ch:match("%d") or (ch == "." and text:sub(i + 1, i + 1):match("%d")) then
					local num = text:match("^0[xX][%x]+", i)
						or text:match("^%d+%.?%d*[eE][%+%-]?%d+", i)
						or text:match("^%.%d+", i)
						or text:match("^%d+%.?%d*", i)
					if num and num:sub(-1) == "." and text:sub(i + #num, i + #num) == "." then
						num = num:sub(1, -2)
					end
					add("number", i, i + #(num or ch) - 1)
				else
					add("text", i, i)
				end
			end
		end
		return spans, state
	end

	function M.scan(source, langId, previous)
		local cleanLang = languages.get(langId).id
		if previous and previous.source == source and previous.langId == cleanLang then
			return previous
		end
		local lines, starts = M.lines(source)
		local prefix, suffix = 0, 0
		if previous and previous.langId == cleanLang then
			while prefix < math.min(#lines, #previous.lines) and lines[prefix + 1] == previous.lines[prefix + 1] do
				prefix = prefix + 1
			end
			while suffix < math.min(#lines, #previous.lines) - prefix
				and lines[#lines - suffix] == previous.lines[#previous.lines - suffix] do
				suffix = suffix + 1
			end
		end
		local result = {
			source = source,
			langId = cleanLang,
			lines = lines,
			starts = starts,
			spans = {},
			states = {},
		}
		local state = ""
		for i = 1, #lines do
			local oldIndex = nil
			if previous and previous.langId == cleanLang then
				if i <= prefix then
					oldIndex = i
				elseif i > #lines - suffix then
					oldIndex = i + #previous.lines - #lines
				end
			end
			local prevEndState = (oldIndex and oldIndex > 1) and previous.states[oldIndex - 1] or ""
			if oldIndex and prevEndState == state then
				result.spans[i] = previous.spans[oldIndex]
				state = previous.states[oldIndex]
			else
				result.spans[i], state = M.line(lines[i], state, cleanLang)
			end
			result.states[i] = state
		end
		return result
	end

	function M.rich(line, spans, colors)
		if #line == 0 then return "" end
		local out = {}
		for _, span in ipairs(spans or {}) do
			local seg = util.escapeRichText(line:sub(span.first, span.last))
			local hex = colors and colors[span.kind]
			if hex and span.kind ~= "text" then
				out[#out + 1] = '<font color="' .. hex .. '">' .. seg .. "</font>"
			else
				out[#out + 1] = seg
			end
		end
		return table.concat(out)
	end

	return M
end
end)()

-- [runtime/code_search] (4232 bytes)
__VSRBLX_MODULES["runtime/code_search"] = (function()
-- Single-file and workspace-wide multi-file search & replace engine for VS-RBLX.
return function(env)
	local util = env.require("runtime/util")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")

	local M = {}

	local function isWordBoundary(text, first, last)
		local before = first > 1 and text:sub(first - 1, first - 1) or ""
		local after = last < #text and text:sub(last + 1, last + 1) or ""
		local prevWord = before ~= "" and before:match("[%w_]") ~= nil
		local nextWord = after ~= "" and after:match("[%w_]") ~= nil
		return (not prevWord) and (not nextWord)
	end

	function M.findInText(source, query, opts)
		opts = opts or {}
		local q = tostring(query or "")
		if q == "" then return {} end
		local text = tostring(source or "")
		local hay = opts.caseSensitive and text or text:lower()
		local needle = opts.caseSensitive and q or q:lower()
		local plain = opts.usePattern ~= true
		local matches = {}
		local limit = opts.limit or 500

		local lines = util.lines(text)
		local lineOffsets = { 1 }
		for i = 1, #lines - 1 do
			lineOffsets[i + 1] = lineOffsets[i] + #lines[i] + 1
		end

		local function lineColAt(offset)
			local lo, hi = 1, #lineOffsets
			while lo < hi do
				local mid = math.floor((lo + hi + 1) / 2)
				if lineOffsets[mid] <= offset then lo = mid else hi = mid - 1 end
			end
			return lo, offset - lineOffsets[lo] + 1
		end

		local pos = 1
		while pos <= #hay and #matches < limit do
			local ok, a, b = pcall(string.find, hay, needle, pos, plain)
			if not ok or not a then break end
			if b < a then
				pos = a + 1
			else
				if not opts.wholeWord or isWordBoundary(text, a, b) then
					local ln, col = lineColAt(a)
					matches[#matches + 1] = {
						first = a,
						last = b,
						line = ln,
						col = col,
						lineText = lines[ln] or "",
						matched = text:sub(a, b),
					}
				end
				pos = b + 1
			end
		end

		return matches
	end

	function M.replaceInText(source, query, replacement, opts)
		local matches = M.findInText(source, query, opts)
		if #matches == 0 then return source, 0 end
		local rep = tostring(replacement or "")
		local parts = {}
		local cursor = 1
		local maxReplace = (opts and opts.singleIndex) or nil
		local replaced = 0

		for idx, m in ipairs(matches) do
			if not maxReplace or idx == maxReplace then
				parts[#parts + 1] = source:sub(cursor, m.first - 1)
				parts[#parts + 1] = rep
				cursor = m.last + 1
				replaced = replaced + 1
			end
		end
		parts[#parts + 1] = source:sub(cursor)
		return table.concat(parts), replaced
	end

	function M.searchWorkspace(query, opts)
		opts = opts or {}
		local q = tostring(query or "")
		if q == "" then return { files = {}, totalMatches = 0 } end
		local allFiles = workspaceFs.listAllFiles("")
		local results = {}
		local total = 0

		for _, entry in ipairs(allFiles) do
			local openDoc = codeStore.findByPath(entry.path)
			local content = openDoc and openDoc.content or workspaceFs.readFile(entry.path)
			if type(content) == "string" then
				local hits = M.findInText(content, q, opts)
				if #hits > 0 then
					total = total + #hits
					results[#results + 1] = {
						path = entry.path,
						name = entry.name,
						matches = hits,
					}
				end
			end
		end

		return {
			files = results,
			totalMatches = total,
		}
	end

	function M.replaceAcrossWorkspace(query, replacement, opts)
		local scan = M.searchWorkspace(query, opts)
		local filesChanged, totalReplaced = 0, 0
		for _, item in ipairs(scan.files) do
			local openDoc = codeStore.findByPath(item.path)
			local current = openDoc and openDoc.content or workspaceFs.readFile(item.path)
			if type(current) == "string" then
				local updated, count = M.replaceInText(current, query, replacement, opts)
				if count > 0 then
					filesChanged = filesChanged + 1
					totalReplaced = totalReplaced + count
					workspaceFs.writeFile(item.path, updated)
					if openDoc then
						openDoc.content = updated
						openDoc.savedContent = updated
						openDoc.dirty = false
					end
				end
			end
		end
		if filesChanged > 0 then
			codeStore.changed:fire({ reason = "replaceAll", files = filesChanged })
		end
		return filesChanged, totalReplaced
	end

	return M
end
end)()

-- [runtime/code_store] (12884 bytes)
__VSRBLX_MODULES["runtime/code_store"] = (function()
-- VS-RBLX Editor Buffer & Tab Store: manages open tabs, split editor groups,
-- undo/redo stacks, dirty indicators, cursor/scroll view state, and executor
-- disk persistence (`writefile` / `readfile` via workspace_fs).
return function(env)
	local util = env.require("runtime/util")
	local config = env.require("runtime/config")
	local clock = env.require("runtime/clock")
	local signal = env.require("runtime/signal")
	local languages = env.require("runtime/languages")
	local workspaceFs = env.require("runtime/workspace_fs")
	local log = env.require("runtime/log")

	local UNDO_LIMIT = 80
	local untitledCounter = 0

	local M = {
		tabs = {},
		byId = {},
		activeId = nil,
		secondaryId = nil,
		splitOpen = false,
		focusedPane = "primary",
		changed = signal.new("code_store.changed"),
		cursorChanged = signal.new("code_store.cursor"),
		saved = signal.new("code_store.saved"),
	}

	local autoSaveDebounced = clock.debounce(0.75, function()
		if config.get("files.autoSave", "afterDelay") ~= "afterDelay" then return end
		for _, doc in ipairs(M.tabs) do
			if doc.dirty and not doc.untitled and not doc.readOnly and not doc.isDiff then
				M.save(doc.id, { silent = true })
			end
		end
	end)

	local function computeCursorLineCol(source, offset)
		local text = tostring(source or "")
		local pos = util.clamp(tonumber(offset) or 1, 1, #text + 1)
		local line = 1
		local lastNewline = 0
		local idx = 1
		while true do
			local nl = text:find("\n", idx, true)
			if not nl or nl >= pos then break end
			line = line + 1
			lastNewline = nl
			idx = nl + 1
		end
		return line, pos - lastNewline
	end

	local function createDoc(spec)
		local path = util.normalisePath(spec.path or "")
		local id = spec.id or (path ~= "" and ("file:" .. path) or ("untitled:" .. tostring(untitledCounter)))
		local content = tostring(spec.content or ""):gsub("\r\n", "\n")
		local lang = spec.langId and languages.get(spec.langId) or languages.detect(path, content)
		return {
			id = id,
			path = path,
			title = spec.title or (path ~= "" and util.basename(path) or id),
			content = content,
			savedContent = spec.untitled and nil or content,
			langId = lang.id,
			dirty = spec.dirty == true,
			pinned = spec.pinned == true,
			untitled = spec.untitled == true,
			readOnly = spec.readOnly == true,
			isDiff = spec.isDiff == true,
			diffOld = spec.diffOld,
			diffNew = spec.diffNew,
			undoStack = {},
			redoStack = {},
			view = {
				cursor = 1,
				selection = -1,
				line = 1,
				col = 1,
				scrollX = 0,
				scrollY = 0,
			},
		}
	end

	function M.get(id)
		return id and M.byId[id] or nil
	end

	function M.active(pane)
		local targetPane = pane or M.focusedPane
		if targetPane == "secondary" and M.splitOpen and M.secondaryId then
			return M.byId[M.secondaryId]
		end
		return M.activeId and M.byId[M.activeId] or nil
	end

	function M.findByPath(relPath)
		local clean = util.normalisePath(relPath)
		return M.byId["file:" .. clean]
	end

	function M.openFile(relPath, opts)
		opts = opts or {}
		local clean = util.normalisePath(relPath)
		if clean == "" then return nil, "empty path" end
		local id = "file:" .. clean
		local doc = M.byId[id]
		if not doc then
			local content, err = workspaceFs.readFile(clean)
			if content == nil then
				if opts.createIfMissing then
					content = opts.initialContent or ""
					workspaceFs.writeFile(clean, content)
				else
					return nil, err or ("cannot read " .. clean)
				end
			end
			doc = createDoc({
				id = id,
				path = clean,
				content = content,
			})
			M.tabs[#M.tabs + 1] = doc
			M.byId[id] = doc
		elseif opts.reloadFromDisk then
			local diskText = workspaceFs.readFile(clean)
			if diskText ~= nil then
				doc.content = diskText:gsub("\r\n", "\n")
				doc.savedContent = doc.content
				doc.dirty = false
			end
		end

		if opts.pane == "secondary" then
			M.splitOpen = true
			M.secondaryId = doc.id
			M.focusedPane = "secondary"
		else
			M.activeId = doc.id
			if M.splitOpen and M.secondaryId == nil then
				M.secondaryId = doc.id
			end
		end

		if opts.line then
			M.jumpToLine(doc.id, opts.line, opts.col or 1)
		end

		M.changed:fire({ reason = "open", id = doc.id, path = doc.path })
		return doc
	end

	function M.newUntitled(initialContent, langId)
		untitledCounter = untitledCounter + 1
		local name = "Untitled-" .. tostring(untitledCounter)
		local doc = createDoc({
			id = "untitled:" .. tostring(untitledCounter),
			path = name .. ".luau",
			title = name,
			content = initialContent or "-- New Luau buffer\n",
			langId = langId or "luau",
			untitled = true,
			dirty = initialContent ~= nil and initialContent ~= "",
		})
		M.tabs[#M.tabs + 1] = doc
		M.byId[doc.id] = doc
		M.activeId = doc.id
		M.changed:fire({ reason = "new", id = doc.id })
		return doc
	end

	function M.openDiffTab(relPath, oldText, newText, label)
		local clean = util.normalisePath(relPath)
		local id = "diff:" .. clean
		local doc = M.byId[id]
		if not doc then
			doc = createDoc({
				id = id,
				path = clean,
				title = (label or (util.basename(clean) .. " (Working Tree)")),
				content = newText or "",
				readOnly = true,
				isDiff = true,
				diffOld = oldText or "",
				diffNew = newText or "",
			})
			M.tabs[#M.tabs + 1] = doc
			M.byId[id] = doc
		else
			doc.diffOld = oldText or ""
			doc.diffNew = newText or ""
			doc.content = newText or ""
		end
		M.activeId = doc.id
		M.changed:fire({ reason = "diff", id = doc.id })
		return doc
	end

	function M.openVirtualTab(id, title, content, langId, readOnly)
		local fullId = "virtual:" .. tostring(id)
		local doc = M.byId[fullId]
		if not doc then
			doc = createDoc({
				id = fullId,
				path = title,
				title = title,
				content = content or "",
				langId = langId or "luau",
				readOnly = readOnly == true,
				untitled = readOnly ~= true,
			})
			M.tabs[#M.tabs + 1] = doc
			M.byId[fullId] = doc
		else
			doc.content = tostring(content or "")
		end
		M.activeId = doc.id
		M.changed:fire({ reason = "virtual", id = doc.id })
		return doc
	end

	function M.activate(id, pane)
		local doc = M.byId[id]
		if not doc then return false end
		if pane == "secondary" then
			M.splitOpen = true
			M.secondaryId = id
			M.focusedPane = "secondary"
		else
			M.activeId = id
			M.focusedPane = "primary"
		end
		M.changed:fire({ reason = "activate", id = id })
		return true
	end

	function M.updateContent(id, newContent, opts)
		opts = opts or {}
		local doc = M.byId[id]
		if not doc or doc.readOnly then return false end
		local normalized = tostring(newContent or ""):gsub("\r\n", "\n")
		if normalized == doc.content then return false end

		if opts.recordUndo ~= false then
			doc.undoStack[#doc.undoStack + 1] = {
				content = doc.content,
				cursor = doc.view.cursor,
			}
			if #doc.undoStack > UNDO_LIMIT then
				table.remove(doc.undoStack, 1)
			end
			doc.redoStack = {}
		end

		doc.content = normalized
		doc.dirty = doc.untitled or (doc.savedContent ~= normalized)
		M.changed:fire({ reason = "edit", id = doc.id, path = doc.path })

		if doc.dirty and not doc.untitled then
			autoSaveDebounced.call()
		end
		return true
	end

	function M.undo(id)
		local doc = M.byId[id or M.activeId]
		if not doc or doc.readOnly or #doc.undoStack == 0 then return false end
		local prev = table.remove(doc.undoStack)
		doc.redoStack[#doc.redoStack + 1] = {
			content = doc.content,
			cursor = doc.view.cursor,
		}
		doc.content = prev.content
		doc.view.cursor = prev.cursor or 1
		doc.dirty = doc.untitled or (doc.savedContent ~= doc.content)
		M.changed:fire({ reason = "undo", id = doc.id })
		return true
	end

	function M.redo(id)
		local doc = M.byId[id or M.activeId]
		if not doc or doc.readOnly or #doc.redoStack == 0 then return false end
		local nxt = table.remove(doc.redoStack)
		doc.undoStack[#doc.undoStack + 1] = {
			content = doc.content,
			cursor = doc.view.cursor,
		}
		doc.content = nxt.content
		doc.view.cursor = nxt.cursor or 1
		doc.dirty = doc.untitled or (doc.savedContent ~= doc.content)
		M.changed:fire({ reason = "redo", id = doc.id })
		return true
	end

	function M.setLanguage(id, langId)
		local doc = M.byId[id or M.activeId]
		if not doc then return false end
		doc.langId = languages.get(langId).id
		M.changed:fire({ reason = "language", id = doc.id, langId = doc.langId })
		return true
	end

	function M.setCursor(id, cursorOffset, selectionStart)
		local doc = M.byId[id]
		if not doc then return end
		doc.view.cursor = math.max(1, tonumber(cursorOffset) or 1)
		doc.view.selection = tonumber(selectionStart) or -1
		doc.view.line, doc.view.col = computeCursorLineCol(doc.content, doc.view.cursor)
		M.cursorChanged:fire(doc)
	end

	function M.jumpToLine(id, targetLine, targetCol)
		local doc = M.byId[id]
		if not doc then return end
		local lines = util.lines(doc.content)
		local ln = util.clamp(tonumber(targetLine) or 1, 1, #lines)
		local offset = 1
		for i = 1, ln - 1 do
			offset = offset + #lines[i] + 1
		end
		local col = util.clamp(tonumber(targetCol) or 1, 1, #lines[ln] + 1)
		offset = offset + col - 1
		M.setCursor(id, offset, -1)
		doc.view.scrollY = math.max(0, (ln - 4) * 20)
		M.changed:fire({ reason = "jump", id = doc.id, line = ln })
	end

	function M.save(id, opts)
		opts = opts or {}
		local doc = M.byId[id or M.activeId]
		if not doc or doc.readOnly or doc.isDiff then return false, "nothing to save" end
		local targetPath = opts.saveAsPath and util.normalisePath(opts.saveAsPath) or doc.path
		if doc.untitled and not opts.saveAsPath then
			targetPath = doc.title .. "." .. (languages.get(doc.langId).extensions[1] or "luau")
		end
		local ok, res = workspaceFs.writeFile(targetPath, doc.content)
		if not ok then return false, res end

		if doc.untitled or opts.saveAsPath then
			M.byId[doc.id] = nil
			doc.path = targetPath
			doc.title = util.basename(targetPath)
			doc.id = "file:" .. targetPath
			doc.untitled = false
			doc.langId = languages.detect(targetPath, doc.content).id
			M.byId[doc.id] = doc
			M.activeId = doc.id
		end

		doc.savedContent = doc.content
		doc.dirty = false
		if not opts.silent then
			log.info("fs", "Saved to local disk: " .. targetPath .. " (" .. util.formatBytes(#doc.content) .. ")")
		end
		M.saved:fire(doc)
		M.changed:fire({ reason = "save", id = doc.id, path = doc.path })
		return true, targetPath
	end

	function M.saveAll()
		local count = 0
		for _, doc in ipairs(M.tabs) do
			if doc.dirty and not doc.readOnly and not doc.isDiff then
				local ok = M.save(doc.id, { silent = true })
				if ok then count = count + 1 end
			end
		end
		log.info("fs", string.format("Saved %d dirty file(s) to local disk.", count))
		return count
	end

	function M.close(id)
		local doc = M.byId[id]
		if not doc or doc.pinned then return false end
		local closedIdx = 1
		for i = 1, #M.tabs do
			if M.tabs[i].id == id then
				closedIdx = i
				table.remove(M.tabs, i)
				break
			end
		end
		M.byId[id] = nil
		if M.activeId == id then
			local replacement = M.tabs[math.min(closedIdx, #M.tabs)]
			M.activeId = replacement and replacement.id or nil
		end
		if M.secondaryId == id then
			local replacement = M.tabs[math.min(closedIdx, #M.tabs)]
			M.secondaryId = replacement and replacement.id or nil
			if not M.secondaryId then M.splitOpen = false end
		end
		M.changed:fire({ reason = "close", id = id })
		return true
	end

	function M.closeOthers(keepId)
		for i = #M.tabs, 1, -1 do
			local tab = M.tabs[i]
			if tab.id ~= keepId and not tab.pinned then
				M.byId[tab.id] = nil
				table.remove(M.tabs, i)
			end
		end
		M.activeId = keepId
		M.changed:fire({ reason = "closeOthers", id = keepId })
	end

	function M.closeSaved()
		for i = #M.tabs, 1, -1 do
			local tab = M.tabs[i]
			if not tab.dirty and not tab.pinned then
				M.byId[tab.id] = nil
				table.remove(M.tabs, i)
			end
		end
		if M.activeId and not M.byId[M.activeId] then
			M.activeId = M.tabs[1] and M.tabs[1].id or nil
		end
		M.changed:fire({ reason = "closeSaved" })
	end

	function M.togglePin(id)
		local doc = M.byId[id]
		if not doc then return end
		doc.pinned = not doc.pinned
		M.changed:fire({ reason = "pin", id = id })
	end

	function M.toggleSplit()
		M.splitOpen = not M.splitOpen
		if M.splitOpen and not M.secondaryId then
			M.secondaryId = M.activeId
		end
		if not M.splitOpen then
			M.focusedPane = "primary"
		end
		M.changed:fire({ reason = "split", splitOpen = M.splitOpen })
	end

	function M.syncWithWorkspace()
		for i = #M.tabs, 1, -1 do
			local tab = M.tabs[i]
			if not tab.untitled and not tab.isDiff and not util.startsWith(tab.id, "virtual:") then
				if workspaceFs.exists(tab.path) then
					if not tab.dirty then
						local fresh = workspaceFs.readFile(tab.path)
						if fresh then
							tab.content = fresh:gsub("\r\n", "\n")
							tab.savedContent = tab.content
						end
					end
				end
			end
		end
		M.changed:fire({ reason = "workspaceSync" })
	end

	return M
end
end)()

-- [runtime/command_catalog] (1229 bytes)
__VSRBLX_MODULES["runtime/command_catalog"] = (function()
-- Command Palette (`Ctrl+Shift+P` / `F1`) action registry for VS-RBLX.
return function(_env)
	local M = { list = {}, byId = {} }

	function M.register(spec)
		if not spec or not spec.id then return end
		if M.byId[spec.id] then
			local existing = M.byId[spec.id]
			for k, v in pairs(spec) do existing[k] = v end
			return existing
		end
		M.byId[spec.id] = spec
		M.list[#M.list + 1] = spec
		return spec
	end

	function M.run(id, ...)
		local cmd = M.byId[id]
		if not cmd or type(cmd.run) ~= "function" then return false, "unknown command: " .. tostring(id) end
		return pcall(cmd.run, ...)
	end

	function M.search(query)
		local q = tostring(query or ""):lower():gsub("^>%s*", ""):gsub("^%s+", ""):gsub("%s+$", "")
		local out = {}
		for _, cmd in ipairs(M.list) do
			local label = (cmd.category and (cmd.category .. ": " .. cmd.title) or cmd.title or cmd.id)
			if q == "" or label:lower():find(q, 1, true) or cmd.id:lower():find(q, 1, true) then
				out[#out + 1] = {
					id = cmd.id,
					label = label,
					shortcut = cmd.shortcut or "",
					category = cmd.category or "General",
					run = cmd.run,
				}
			end
		end
		table.sort(out, function(a, b) return a.label < b.label end)
		return out
	end

	return M
end
end)()

-- [runtime/config] (3748 bytes)
__VSRBLX_MODULES["runtime/config"] = (function()
-- Persistent VS Code settings (`VSRBLX/settings.json`) backed by executor `writefile`
-- and `readfile`, with dot-path accessors and debounced disk persistence.
return function(env)
	local util = env.require("runtime/util")
	local fsx = env.require("runtime/fsx")
	local clock = env.require("runtime/clock")
	local signal = env.require("runtime/signal")
	local log = env.require("runtime/log")

	local DEFAULTS = {
		workbench = {
			colorTheme = "dark_plus",
			sideBarVisible = true,
			sideBarWidth = 240,
			panelVisible = true,
			panelHeight = 175,
			activeViewlet = "explorer",
			activePanelTab = "terminal",
			statusBarVisible = true,
			breadcrumbs = true,
		},
		editor = {
			fontSize = 14,
			tabSize = 4,
			insertSpaces = true,
			wordWrap = false,
			minimap = true,
			lineNumbers = true,
			autoClosingBrackets = true,
			autoIndent = true,
			intellisense = true,
			renderActiveLine = true,
			codeFolding = true,
		},
		files = {
			autoSave = "afterDelay",
			autoSaveDelayMs = 800,
			activeWorkspace = "default",
			recentWorkspaces = { "default" },
		},
		github = {
			token = "",
			username = "",
			activeRepo = "",
			activeBranch = "main",
			autoSyncOnPush = true,
		},
		window = {
			autoResize = true,
			widthScale = 0.84,
			heightScale = 0.84,
			placed = false,
			customSize = false,
			maximised = false,
			width = 980,
			height = 620,
			x = 0,
			y = 0,
		},
	}

	local M = {
		data = util.deepCopy(DEFAULTS),
		changed = signal.new("config.changed"),
		path = "settings.json",
	}

	local function getAt(root, dotted)
		local cur = root
		for _, part in ipairs(util.split(dotted, ".")) do
			if type(cur) ~= "table" then return nil end
			cur = cur[part]
		end
		return cur
	end

	local function setAt(root, dotted, value)
		local parts = util.split(dotted, ".")
		local cur = root
		for i = 1, #parts - 1 do
			local k = parts[i]
			if type(cur[k]) ~= "table" then cur[k] = {} end
			cur = cur[k]
		end
		cur[parts[#parts]] = value
	end

	local function mergeDefaults(target, defaults)
		for k, v in pairs(defaults) do
			if type(v) == "table" then
				if type(target[k]) ~= "table" then
					target[k] = util.deepCopy(v)
				else
					mergeDefaults(target[k], v)
				end
			elseif target[k] == nil then
				target[k] = v
			end
		end
	end

	function M.saveNow()
		local body, err = util.jsonEncode(M.data)
		if not body then
			log.warn("config", "Failed to encode settings.json: " .. tostring(err))
			return false, err
		end
		return fsx.write(M.path, body)
	end

	local debouncedSave = clock.debounce(0.35, function()
		M.saveNow()
	end)

	function M.load(overrideData)
		if type(overrideData) == "table" then
			M.data = util.deepCopy(overrideData)
			mergeDefaults(M.data, DEFAULTS)
			return true
		end
		local raw = fsx.read(M.path)
		if type(raw) == "string" and raw ~= "" then
			local decoded = util.jsonDecode(raw)
			if type(decoded) == "table" then
				M.data = decoded
				mergeDefaults(M.data, DEFAULTS)
				return true
			end
		end
		M.data = util.deepCopy(DEFAULTS)
		M.saveNow()
		return true
	end

	function M.get(key, fallback)
		local val = getAt(M.data, key)
		if val == nil then
			local def = getAt(DEFAULTS, key)
			if def ~= nil then return def end
			return fallback
		end
		return val
	end

	function M.set(key, value, opts)
		opts = opts or {}
		local prev = getAt(M.data, key)
		setAt(M.data, key, value)
		if opts.immediate then
			M.saveNow()
		else
			debouncedSave.call()
		end
		if not opts.quiet and prev ~= value then
			M.changed:fire(key, value, prev)
		end
	end

	function M.reset()
		M.data = util.deepCopy(DEFAULTS)
		M.saveNow()
		M.changed:fire("*", M.data, nil)
	end

	function M.exportJson()
		return util.jsonEncode(M.data) or "{}"
	end

	return M
end
end)()

-- [runtime/diagnostics] (4142 bytes)
__VSRBLX_MODULES["runtime/diagnostics"] = (function()
-- Real-time syntax & bracket diagnostics feeding VS-RBLX editor gutter markers,
-- status bar error/warning counters, and the bottom Problems panel.
return function(env)
	local caps = env.require("runtime/caps")
	local util = env.require("runtime/util")
	local languages = env.require("runtime/languages")
	local signal = env.require("runtime/signal")

	local M = {
		byDoc = {},
		changed = signal.new("diagnostics.changed"),
	}

	local function checkBracketBalance(source)
		local issues = {}
		local stack = {}
		local pairsMap = { ["("] = ")", ["["] = "]", ["{"] = "}" }
		local closers = { [")"] = "(", ["]"] = "[", ["}"] = "{" }
		local lines = util.lines(source)

		for ln, line in ipairs(lines) do
			local inQuote = nil
			local i = 1
			while i <= #line do
				local c = line:sub(i, i)
				if inQuote then
					if c == "\\" then
						i = i + 1
					elseif c == inQuote then
						inQuote = nil
					end
				else
					if c == "/" and line:sub(i + 1, i + 1) == "/" then
						break
					elseif c == "#" then
						break
					elseif c == '"' or c == "'" then
						inQuote = c
					elseif pairsMap[c] then
						stack[#stack + 1] = { char = c, expect = pairsMap[c], line = ln, col = i }
					elseif closers[c] then
						local top = stack[#stack]
						if not top or top.char ~= closers[c] then
							issues[#issues + 1] = {
								severity = "error",
								line = ln,
								col = i,
								message = string.format("Unexpected closing '%s'", c),
							}
							return issues
						else
							stack[#stack] = nil
						end
					end
				end
				i = i + 1
			end
		end

		if #stack > 0 then
			local top = stack[#stack]
			issues[#issues + 1] = {
				severity = "error",
				line = top.line,
				col = top.col,
				message = string.format("Unclosed '%s' (expected '%s')", top.char, top.expect),
			}
		end
		return issues
	end

	function M.check(doc)
		if not doc or doc.isDiff then return {} end
		local source = tostring(doc.content or "")
		local lang = languages.get(doc.langId)
		local list = {}

		if lang.id == "luau" and caps.fn.loadstring then
			local fn, err = caps.fn.loadstring(source, doc.path or "chunk")
			if not fn and err then
				local ln = tonumber(tostring(err):match(":(%d+):")) or 1
				local msg = tostring(err):match(":%d+:%s*(.*)$") or tostring(err)
				list[#list + 1] = {
					severity = "error",
					line = ln,
					col = 1,
					message = msg,
					path = doc.path,
					docId = doc.id,
				}
			end
		elseif lang.id == "json" then
			if source:find("%S") then
				local decoded, err = util.jsonDecode(source)
				if decoded == nil and err then
					list[#list + 1] = {
						severity = "error",
						line = 1,
						col = 1,
						message = tostring(err),
						path = doc.path,
						docId = doc.id,
					}
				end
			end
		elseif lang.id == "javascript" or lang.id == "typescript" or lang.id == "python"
			or lang.id == "rust" or lang.id == "go" or lang.id == "cpp" or lang.id == "csharp" or lang.id == "java" then
			for _, issue in ipairs(checkBracketBalance(source)) do
				issue.path = doc.path
				issue.docId = doc.id
				list[#list + 1] = issue
			end
		end

		local lines = util.lines(source)
		for i, line in ipairs(lines) do
			if line:find("TODO", 1, true) or line:find("FIXME", 1, true) then
				list[#list + 1] = {
					severity = "warn",
					line = i,
					col = 1,
					message = "Note marker: " .. util.trim(line):sub(1, 70),
					path = doc.path,
					docId = doc.id,
				}
			end
		end

		M.byDoc[doc.id] = list
		M.changed:fire(doc.id, list)
		return list
	end

	function M.remove(docId)
		M.byDoc[docId] = nil
		M.changed:fire(docId, {})
	end

	function M.all()
		local errorsCount, warnsCount = 0, 0
		local items = {}
		for _, list in pairs(M.byDoc) do
			for _, item in ipairs(list) do
				items[#items + 1] = item
				if item.severity == "error" then
					errorsCount = errorsCount + 1
				else
					warnsCount = warnsCount + 1
				end
			end
		end
		table.sort(items, function(a, b)
			if a.path ~= b.path then return tostring(a.path) < tostring(b.path) end
			return (a.line or 1) < (b.line or 1)
		end)
		return items, errorsCount, warnsCount
	end

	return M
end
end)()

-- [runtime/dispose] (1685 bytes)
__VSRBLX_MODULES["runtime/dispose"] = (function()
-- Deterministic cleanup registry so unloading VS-RBLX leaves zero dangling
-- connections, threads, or GUI instances behind.
return function(_env)
	local M = { draining = false }
	local items = {}

	function M.give(resource)
		if resource == nil then return function() end end
		items[#items + 1] = resource
		return function()
			for i = #items, 1, -1 do
				if items[i] == resource then
					table.remove(items, i)
					break
				end
			end
			M.releaseOne(resource)
		end
	end

	function M.connection(conn)
		return M.give(conn)
	end

	function M.instance(inst)
		return M.give(inst)
	end

	function M.thread(co)
		return M.give(co)
	end

	function M.releaseOne(resource)
		local kind = typeof and typeof(resource) or type(resource)
		if kind == "RBXScriptConnection" then
			pcall(function() resource:Disconnect() end)
		elseif kind == "Instance" then
			pcall(function() resource:Destroy() end)
		elseif type(resource) == "thread" then
			pcall(task.cancel, resource)
		elseif type(resource) == "function" then
			pcall(resource)
		elseif type(resource) == "table" then
			if type(resource.Disconnect) == "function" then
				pcall(function() resource:Disconnect() end)
			elseif type(resource.Destroy) == "function" then
				pcall(function() resource:Destroy() end)
			elseif type(resource.destroy) == "function" then
				pcall(resource.destroy)
			elseif type(resource.cancel) == "function" then
				pcall(resource.cancel)
			end
		end
	end

	function M.drain()
		M.draining = true
		for i = #items, 1, -1 do
			local item = items[i]
			items[i] = nil
			M.releaseOne(item)
		end
		M.draining = false
	end

	M.add = M.give
	M.all = M.drain
	M.cleanupAll = M.drain

	return M
end
end)()

-- [runtime/fsx] (9261 bytes)
__VSRBLX_MODULES["runtime/fsx"] = (function()
-- Executor local disk filesystem facade (`readfile`, `writefile`, `listfiles`,
-- `makefolder`, `isfile`, `isfolder`, `delfile`, `delfolder`) with automatic
-- directory creation, strict path sanitisation, and transparent virtual-memory
-- fallback when running inside a vanilla Studio LocalScript.
return function(env)
	local util = env.require("runtime/util")
	local caps = env.require("runtime/caps")
	local log = env.require("runtime/log")
	local signal = env.require("runtime/signal")

	local M = {
		enabled = caps.fs,
		root = (env.info and env.info.folder) or "VSRBLX",
		changed = signal.new("fsx.changed"),
	}

	local knownFolders = {}
	local memFiles = {}
	local memFolders = { [""] = true }

	function M.isBackedByDisk()
		return M.enabled == true
	end

	function M.sanitise(path, allowEmpty)
		local original = tostring(path or "")
		if not util.validUtf8(original) then return nil, "path must contain valid UTF-8" end
		if original:match("^[\\/]") or original:match("^%a:") then
			return nil, "absolute system paths are not allowed outside executor workspace"
		end
		local clean = original:gsub("\\", "/"):gsub("^/+", ""):gsub("/+", "/"):gsub("/+$", "")
		if clean == "" then
			if allowEmpty then return "" end
			return nil, "empty path"
		end
		for _, part in ipairs(util.split(clean, "/")) do
			local device = part:upper():match("^[^%.]+") or ""
			if device == "CON" or device == "PRN" or device == "AUX" or device == "NUL"
				or device:match("^COM[1-9]$") or device:match("^LPT[1-9]$") then
				return nil, "path contains a reserved device name"
			end
			if part == ".." or part == "." then
				return nil, "path may not contain '.' or '..'"
			end
			if part:find("[%z\1-\31\127]") then
				return nil, "path contains a control character"
			end
			if part:match("[%. ]$") then
				return nil, "path segments may not end in a dot or space"
			end
			if part:find('[<>:"|%?%*]') then
				return nil, "path contains a reserved character"
			end
		end
		if #clean > 240 then return nil, "path is too long" end
		return clean
	end

	function M.resolve(path, opts)
		opts = opts or {}
		local clean, err = M.sanitise(path, true)
		if clean == nil then return nil, err end
		if opts.raw then
			return clean
		end
		local base = M.root
		if opts.scope and opts.scope ~= "" then
			base = base .. "/" .. opts.scope
		end
		if clean == "" then return base end
		return base .. "/" .. clean
	end

	function M.ensure(dir, opts)
		local full, err = M.resolve(dir, opts)
		if not full then return false, err end
		if full == "" then return true end
		local walk = ""
		for _, part in ipairs(util.split(full, "/")) do
			walk = (walk == "") and part or (walk .. "/" .. part)
			memFolders[walk] = true
			if M.enabled and caps.fn.makefolder and not knownFolders[walk] then
				local exists = false
				if caps.fn.isfolder then
					local ok, res = pcall(caps.fn.isfolder, walk)
					exists = ok and res == true
				end
				if not exists then
					pcall(caps.fn.makefolder, walk)
				end
				knownFolders[walk] = true
			end
		end
		return true
	end

	function M.exists(path, opts)
		local full = M.resolve(path, opts)
		if not full or full == "" then return false end
		if M.enabled and caps.fn.isfile then
			local ok, res = pcall(caps.fn.isfile, full)
			if ok and res == true then return true end
		end
		return memFiles[full] ~= nil
	end

	function M.isDir(path, opts)
		local full = M.resolve(path, opts)
		if not full then return false end
		if full == "" then return true end
		if M.enabled and caps.fn.isfolder then
			local ok, res = pcall(caps.fn.isfolder, full)
			if ok and res == true then return true end
		end
		return memFolders[full] == true
	end

	function M.read(path, opts)
		local full, err = M.resolve(path, opts)
		if not full or full == "" then return nil, err or "invalid path" end
		if M.enabled and caps.fn.readfile then
			local ok, content = pcall(caps.fn.readfile, full)
			if ok and type(content) == "string" then
				memFiles[full] = content
				return content
			end
			if memFiles[full] ~= nil then return memFiles[full] end
			return nil, tostring(content or "file not found")
		end
		if memFiles[full] ~= nil then
			return memFiles[full]
		end
		return nil, "file not found: " .. full
	end

	function M.write(path, content, opts)
		local full, err = M.resolve(path, opts)
		if not full or full == "" then return false, err or "invalid path" end
		local body = tostring(content or "")
		local parent = util.dirname(full)
		if parent ~= "" then
			M.ensure(parent, { raw = true })
		end
		memFiles[full] = body
		if M.enabled and caps.fn.writefile then
			local ok, writeErr = pcall(caps.fn.writefile, full, body)
			if not ok then
				log.error("fs", "writefile failed for " .. full .. ": " .. tostring(writeErr))
				return false, tostring(writeErr)
			end
		end
		M.changed:fire({ op = "write", path = full, bytes = #body })
		return true, full
	end

	function M.append(path, content, opts)
		local full, err = M.resolve(path, opts)
		if not full or full == "" then return false, err or "invalid path" end
		local parent = util.dirname(full)
		if parent ~= "" then
			M.ensure(parent, { raw = true })
		end
		local extra = tostring(content or "")
		memFiles[full] = (memFiles[full] or "") .. extra
		if M.enabled then
			if caps.fn.appendfile and M.exists(full, { raw = true }) then
				local ok, appendErr = pcall(caps.fn.appendfile, full, extra)
				if not ok then return false, tostring(appendErr) end
			elseif caps.fn.writefile then
				local ok, writeErr = pcall(caps.fn.writefile, full, memFiles[full])
				if not ok then return false, tostring(writeErr) end
			end
		end
		M.changed:fire({ op = "append", path = full, bytes = #extra })
		return true
	end

	function M.mkdir(path, opts)
		local ok, err = M.ensure(path, opts)
		if ok then
			local full = M.resolve(path, opts)
			M.changed:fire({ op = "mkdir", path = full })
		end
		return ok, err
	end

	function M.delete(path, opts)
		local full, err = M.resolve(path, opts)
		if not full or full == "" then return false, err or "invalid path" end
		memFiles[full] = nil
		if memFolders[full] then
			memFolders[full] = nil
			knownFolders[full] = nil
			local prefix = full .. "/"
			for k in pairs(memFiles) do
				if k:sub(1, #prefix) == prefix then memFiles[k] = nil end
			end
			for k in pairs(memFolders) do
				if k:sub(1, #prefix) == prefix then
					memFolders[k] = nil
					knownFolders[k] = nil
				end
			end
			if M.enabled and caps.fn.delfolder then
				pcall(caps.fn.delfolder, full)
			end
		elseif M.enabled and caps.fn.delfile then
			pcall(caps.fn.delfile, full)
		end
		M.changed:fire({ op = "delete", path = full })
		return true
	end

	-- Lists immediate children of `dir`, merging real executor `listfiles` entries
	-- with any virtual entries. Each item is `{ name, path, fullPath, isDir }`.
	function M.list(dir, opts)
		opts = opts or {}
		local full, err = M.resolve(dir or "", opts)
		if not full then return {}, err end

		local seen = {}
		local out = {}
		local prefix = (full == "") and "" or (full .. "/")

		local function record(rawEntry, forceDir)
			local clean = util.normalisePath(rawEntry)
			if clean == "" or clean == full then return end
			local rel = clean
			if prefix ~= "" then
				if clean:sub(1, #prefix) ~= prefix then return end
				rel = clean:sub(#prefix + 1)
			end
			local head = rel:match("^([^/]+)")
			if not head or head == "" then return end
			local childFull = (prefix == "") and head or (prefix .. head)
			local isNested = rel:find("/", 1, true) ~= nil
			local dirFlag = forceDir == true or isNested or M.isDir(childFull, { raw = true })
			if seen[head] then
				if dirFlag then seen[head].isDir = true end
				return
			end
			local relFromScope = head
			local baseClean = util.normalisePath(dir or "")
			if baseClean ~= "" then
				relFromScope = baseClean .. "/" .. head
			end
			local item = {
				name = head,
				path = relFromScope,
				fullPath = childFull,
				isDir = dirFlag,
			}
			seen[head] = item
			out[#out + 1] = item
		end

		if M.enabled and caps.fn.listfiles then
			local target = (full == "") and "." or full
			if full == "" or M.isDir(full, { raw = true }) then
				local ok, list = pcall(caps.fn.listfiles, target)
				if ok and type(list) == "table" then
					for _, entry in ipairs(list) do
						local cleanEntry = tostring(entry):gsub("^%./", ""):gsub("^%.\\", "")
						record(cleanEntry, false)
					end
				end
			end
		end

		for k in pairs(memFiles) do record(k, false) end
		for k in pairs(memFolders) do
			if k ~= "" then record(k, true) end
		end

		table.sort(out, function(a, b)
			if a.isDir ~= b.isDir then return a.isDir end
			return a.name:lower() < b.name:lower()
		end)
		return out
	end

	-- Recursively scans a directory and returns flat list of files & folders.
	function M.walk(dir, opts, maxEntries)
		local limit = maxEntries or 1500
		local results = {}
		local function visit(sub, depth)
			if depth > 16 or #results >= limit then return end
			local items = M.list(sub, opts)
			for _, item in ipairs(items) do
				if #results >= limit then break end
				results[#results + 1] = item
				if item.isDir then
					visit(item.path, depth + 1)
				end
			end
		end
		visit(dir or "", 0)
		return results
	end

	return M
end
end)()

-- [runtime/git_state] (6530 bytes)
__VSRBLX_MODULES["runtime/git_state"] = (function()
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
end)()

-- [runtime/intellisense] (5031 bytes)
__VSRBLX_MODULES["runtime/intellisense"] = (function()
-- Context-aware IntelliSense autocomplete & snippet provider across all 17 languages.
return function(env)
	local languages = env.require("runtime/languages")
	local util = env.require("runtime/util")

	local M = {}

	local ROBLOX_APIS = {
		{ label = 'game:GetService("Players")', insert = 'game:GetService("Players")', kind = "method", detail = "Roblox Service" },
		{ label = 'game:GetService("RunService")', insert = 'game:GetService("RunService")', kind = "method", detail = "Roblox Service" },
		{ label = 'game:GetService("UserInputService")', insert = 'game:GetService("UserInputService")', kind = "method", detail = "Roblox Service" },
		{ label = 'game:GetService("TweenService")', insert = 'game:GetService("TweenService")', kind = "method", detail = "Roblox Service" },
		{ label = 'game:GetService("HttpService")', insert = 'game:GetService("HttpService")', kind = "method", detail = "Roblox Service" },
		{ label = 'game:GetService("ReplicatedStorage")', insert = 'game:GetService("ReplicatedStorage")', kind = "method", detail = "Roblox Service" },
		{ label = 'Instance.new("Frame")', insert = 'Instance.new("Frame")', kind = "constructor", detail = "Create Instance" },
		{ label = "UDim2.fromOffset", insert = "UDim2.fromOffset(", kind = "function", detail = "UDim2 constructor" },
		{ label = "UDim2.fromScale", insert = "UDim2.fromScale(", kind = "function", detail = "UDim2 constructor" },
		{ label = "Color3.fromRGB", insert = "Color3.fromRGB(", kind = "function", detail = "Color3 constructor" },
		{ label = "Vector2.new", insert = "Vector2.new(", kind = "function", detail = "Vector2 constructor" },
		{ label = "Vector3.new", insert = "Vector3.new(", kind = "function", detail = "Vector3 constructor" },
		{ label = "task.spawn", insert = "task.spawn(function()\n\t\nend)", kind = "function", detail = "Spawn thread" },
		{ label = "task.delay", insert = "task.delay(1, function()\n\t\nend)", kind = "function", detail = "Delayed callback" },
		{ label = "readfile", insert = 'readfile("")', kind = "executor", detail = "Executor Disk Read" },
		{ label = "writefile", insert = 'writefile("", "")', kind = "executor", detail = "Executor Disk Write" },
		{ label = "listfiles", insert = 'listfiles("")', kind = "executor", detail = "Executor List Dir" },
		{ label = "makefolder", insert = 'makefolder("")', kind = "executor", detail = "Executor Make Folder" },
		{ label = "isfile", insert = 'isfile("")', kind = "executor", detail = "Executor Check File" },
		{ label = "isfolder", insert = 'isfolder("")', kind = "executor", detail = "Executor Check Folder" },
		{ label = "request", insert = 'request({ Url = "", Method = "GET" })', kind = "executor", detail = "Executor HTTP Request" },
		{ label = "loadstring", insert = 'loadstring("")()', kind = "executor", detail = "Executor Compile Luau" },
	}

	function M.currentWord(source, cursorOffset)
		local text = tostring(source or "")
		local pos = util.clamp((tonumber(cursorOffset) or 1) - 1, 0, #text)
		if pos <= 0 then return "", 1, 0 end
		local startIdx = pos
		while startIdx >= 1 and text:sub(startIdx, startIdx):match("[%w_]") do
			startIdx = startIdx - 1
		end
		startIdx = startIdx + 1
		if startIdx > pos then return "", pos + 1, pos end
		return text:sub(startIdx, pos), startIdx, pos
	end

	function M.suggest(source, cursorOffset, langId, maxItems)
		local prefix, startIdx, endIdx = M.currentWord(source, cursorOffset)
		if #prefix < 2 then return {}, prefix, startIdx, endIdx end

		local lang = languages.get(langId)
		local lowPrefix = prefix:lower()
		local limit = maxItems or 8
		local seen = { [prefix] = true }
		local items = {}

		local function consider(label, insertText, kind, detail)
			if #items >= limit then return end
			if seen[label] then return end
			if label:lower():sub(1, #lowPrefix) == lowPrefix then
				seen[label] = true
				items[#items + 1] = {
					label = label,
					insert = insertText or label,
					kind = kind or "word",
					detail = detail or lang.name,
				}
			end
		end

		for _, snip in ipairs(lang.snippets or {}) do
			consider(snip.trigger, snip.insert, "snippet", snip.label)
		end

		if lang.id == "luau" then
			for _, api in ipairs(ROBLOX_APIS) do
				consider(api.label, api.insert, api.kind, api.detail)
			end
		end

		for word in pairs(lang.keywords or {}) do
			consider(word, word, "keyword", "keyword")
		end
		for word in pairs(lang.builtins or {}) do
			consider(word, word, "builtin", "builtin")
		end
		for word in pairs(lang.types or {}) do
			consider(word, word, "type", "type")
		end

		for token in tostring(source or ""):gmatch("[%a_][%w_]+") do
			if #token >= 3 then
				consider(token, token, "symbol", "document")
			end
		end

		table.sort(items, function(a, b)
			local rank = { snippet = 1, executor = 2, method = 3, keyword = 4, builtin = 5, type = 6, symbol = 7 }
			local ra, rb = rank[a.kind] or 9, rank[b.kind] or 9
			if ra ~= rb then return ra < rb end
			return a.label < b.label
		end)

		return items, prefix, startIdx, endIdx
	end

	return M
end
end)()

-- [runtime/languages] (16012 bytes)
__VSRBLX_MODULES["runtime/languages"] = (function()
-- Multi-language registry for VS-RBLX (17 language modes: Luau, TypeScript,
-- JavaScript, Python, JSON, HTML, CSS, Rust, Go, C/C++, C#, Java, SQL,
-- Markdown, YAML/TOML, Shell, and Plain Text).
return function(env)
	local util = env.require("runtime/util")
	local M = {}

	local function wordSet(words)
		local set = {}
		for w in tostring(words or ""):gmatch("%S+") do
			set[w] = true
		end
		return set
	end

	local LIST = {
		{
			id = "luau",
			name = "Luau",
			badge = "LUAU",
			badgeColor = { 0, 162, 255 },
			extensions = { "luau", "lua" },
			lineComment = "--",
			blockComment = { "--[[", "]]" },
			longStrings = true,
			keywords = wordSet("and break do else elseif end false for function if in local nil not or repeat return then true until while continue export type typeof"),
			builtins = wordSet("game workspace script shared plugin task math string table coroutine bit32 utf8 buffer os debug Instance Vector2 Vector3 CFrame Color3 UDim UDim2 Enum TweenInfo RaycastParams OverlapParams NumberSequence ColorSequence Rect Font DateTime Random pcall xpcall ipairs pairs next select unpack tonumber tostring type assert error print warn require loadstring getgenv getrenv gethui readfile writefile appendfile isfile isfolder makefolder listfiles delfile delfolder request http_request setclipboard toclipboard decompile identifyexecutor cloneref hookmetamethod hookfunction getconnections firesignal"),
			types = wordSet("any boolean number string thread table userdata vector buffer never unknown Frame TextLabel TextButton TextBox ScrollingFrame ImageLabel ImageButton ScreenGui UIListLayout UIPadding UICorner UIStroke Part MeshPart Model Folder RemoteEvent RemoteFunction LocalScript ModuleScript Script"),
			snippets = {
				{ trigger = "fn", label = "local function name(...)", insert = "local function main()\n\t\nend" },
				{ trigger = "serv", label = "game:GetService(...)", insert = 'local Players = game:GetService("Players")' },
				{ trigger = "readf", label = "Executor readfile / writefile", insert = 'if isfile("notes.txt") then\n\tlocal data = readfile("notes.txt")\n\tprint(data)\nend' },
				{ trigger = "req", label = "Executor HTTP request", insert = 'local res = request({\n\tUrl = "https://api.github.com/zen",\n\tMethod = "GET",\n})\nprint(res.StatusCode, res.Body)' },
				{ trigger = "mod", label = "ProjectUAI factory module", insert = "return function(env)\n\tlocal M = {}\n\treturn M\nend" },
			},
		},
		{
			id = "typescript",
			name = "TypeScript",
			badge = "TS",
			badgeColor = { 49, 120, 198 },
			extensions = { "ts", "tsx", "mts", "cts" },
			lineComment = "//",
			blockComment = { "/*", "*/" },
			templateStrings = true,
			decorators = true,
			keywords = wordSet("abstract as async await break case catch class const continue debugger declare default delete do else enum export extends false finally for from function get if implements import in infer instanceof interface is keyof let module namespace never new null of override package private protected public readonly return satisfies set static super switch this throw true try type typeof undefined unique var void while with yield"),
			builtins = wordSet("console window document fetch Promise Array Object Map Set WeakMap WeakSet JSON Math Date RegExp Error Symbol BigInt Reflect Proxy setTimeout clearTimeout setInterval clearInterval process Buffer"),
			types = wordSet("string number boolean unknown any void never object symbol bigint Record Partial Required Readonly Pick Omit Exclude Extract Awaited"),
			snippets = {
				{ trigger = "iface", label = "export interface ...", insert = "export interface Props {\n\tid: string;\n}" },
				{ trigger = "afn", label = "async arrow function", insert = "const run = async (): Promise<void> => {\n\t\n};" },
			},
		},
		{
			id = "javascript",
			name = "JavaScript",
			badge = "JS",
			badgeColor = { 241, 224, 90 },
			extensions = { "js", "jsx", "mjs", "cjs" },
			lineComment = "//",
			blockComment = { "/*", "*/" },
			templateStrings = true,
			decorators = true,
			keywords = wordSet("async await break case catch class const continue debugger default delete do else export extends false finally for from function get if import in instanceof let new null of return set static super switch this throw true try typeof undefined var void while with yield"),
			builtins = wordSet("console window document fetch Promise Array Object Map Set JSON Math Date RegExp Error Symbol parseInt parseFloat isNaN setTimeout setInterval require module exports process"),
			types = wordSet(""),
			snippets = {
				{ trigger = "clg", label = "console.log(...)", insert = "console.log();" },
				{ trigger = "fetch", label = "await fetch JSON", insert = 'const res = await fetch("https://api.github.com");\nconst data = await res.json();' },
			},
		},
		{
			id = "python",
			name = "Python",
			badge = "PY",
			badgeColor = { 53, 114, 165 },
			extensions = { "py", "pyw", "pyi" },
			lineComment = "#",
			tripleStrings = true,
			decorators = true,
			keywords = wordSet("False None True and as assert async await break class continue def del elif else except finally for from global if import in is lambda nonlocal not or pass raise return try while with yield match case"),
			builtins = wordSet("print len range enumerate zip map filter sorted reversed list dict set tuple str int float bool bytes open isinstance issubclass getattr setattr hasattr super type id hex oct bin min max sum abs round any all dir vars"),
			types = wordSet("Optional Union List Dict Set Tuple Callable Any Sequence Iterable Mapping Path"),
			snippets = {
				{ trigger = "def", label = "def function():", insert = "def main() -> None:\n    pass" },
				{ trigger = "main", label = "if __name__ == '__main__':", insert = 'if __name__ == "__main__":\n    main()' },
			},
		},
		{
			id = "json",
			name = "JSON",
			badge = "{}",
			badgeColor = { 203, 203, 65 },
			extensions = { "json", "jsonc", "manifest" },
			lineComment = "//",
			blockComment = { "/*", "*/" },
			jsonMode = true,
			keywords = wordSet("true false null"),
			builtins = wordSet(""),
			types = wordSet(""),
			snippets = {},
		},
		{
			id = "html",
			name = "HTML",
			badge = "<>",
			badgeColor = { 227, 76, 38 },
			extensions = { "html", "htm", "xml", "svg", "xhtml" },
			blockComment = { "<!--", "-->" },
			markupMode = true,
			keywords = wordSet("DOCTYPE html head body title meta link script style div span section header footer main nav article aside h1 h2 h3 h4 p a button input form label ul ol li table tr td th img canvas svg path"),
			builtins = wordSet("class id style src href type value placeholder name role aria hidden defer async"),
			types = wordSet(""),
			snippets = {
				{ trigger = "html5", label = "HTML5 Document Boilerplate", insert = '<!DOCTYPE html>\n<html lang="en">\n<head>\n\t<meta charset="UTF-8">\n\t<title>Document</title>\n</head>\n<body>\n\t\n</body>\n</html>' },
			},
		},
		{
			id = "css",
			name = "CSS",
			badge = "#",
			badgeColor = { 86, 61, 124 },
			extensions = { "css", "scss", "less" },
			lineComment = "//",
			blockComment = { "/*", "*/" },
			decorators = true,
			keywords = wordSet("important media keyframes import supports layer container root from to solid none auto flex grid block inline absolute relative fixed sticky hidden visible pointer center space-between column row wrap"),
			builtins = wordSet("display position width height min-width max-width min-height max-height margin padding border border-radius background background-color color font-family font-size font-weight line-height gap align-items justify-content flex-direction box-shadow opacity transition transform z-index overflow cursor var calc rgb rgba hsl"),
			types = wordSet("px rem em vh vw deg ms s fr"),
			snippets = {},
		},
		{
			id = "rust",
			name = "Rust",
			badge = "RS",
			badgeColor = { 222, 165, 132 },
			extensions = { "rs" },
			lineComment = "//",
			blockComment = { "/*", "*/" },
			decorators = true,
			keywords = wordSet("as async await break const continue crate dyn else enum extern false fn for if impl in let loop match mod move mut pub ref return self Self static struct super trait true type unsafe use where while"),
			builtins = wordSet("println eprintln format vec panic assert assert_eq Option Some None Result Ok Err Box Rc Arc Vec String Clone Copy Debug Default Drop Iterator Into From"),
			types = wordSet("i8 i16 i32 i64 i128 isize u8 u16 u32 u64 u128 usize f32 f64 bool char str"),
			snippets = {
				{ trigger = "fn", label = "fn main()", insert = 'fn main() {\n    println!("Hello, VS-RBLX!");\n}' },
			},
		},
		{
			id = "go",
			name = "Go",
			badge = "GO",
			badgeColor = { 0, 173, 216 },
			extensions = { "go" },
			lineComment = "//",
			blockComment = { "/*", "*/" },
			templateStrings = true,
			keywords = wordSet("break case chan const continue default defer else fallthrough for func go goto if import interface map package range return select struct switch type var true false nil iota"),
			builtins = wordSet("append cap close complex copy delete imag len make new panic print println real recover fmt os io net http context sync time errors"),
			types = wordSet("bool byte complex64 complex128 error float32 float64 int int8 int16 int32 int64 rune string uint uint8 uint16 uint32 uint64 uintptr any comparable"),
			snippets = {},
		},
		{
			id = "cpp",
			name = "C / C++",
			badge = "C++",
			badgeColor = { 243, 75, 125 },
			extensions = { "cpp", "hpp", "cc", "cxx", "c", "h" },
			lineComment = "//",
			blockComment = { "/*", "*/" },
			preprocessor = true,
			keywords = wordSet("alignas alignof auto break case catch class const consteval constexpr constinit continue co_await co_return co_yield decltype default delete do else enum explicit export extern false final for friend goto if inline mutable namespace new noexcept nullptr operator override private protected public register reinterpret_cast requires return sizeof static static_assert static_cast struct switch template this thread_local throw true try typedef typeid typename union using virtual volatile while"),
			builtins = wordSet("std cout cin cerr endl vector string map unordered_map set shared_ptr unique_ptr make_shared make_unique move forward printf malloc free"),
			types = wordSet("void bool char short int long float double signed unsigned size_t int8_t int16_t int32_t int64_t uint8_t uint16_t uint32_t uint64_t"),
			snippets = {},
		},
		{
			id = "csharp",
			name = "C#",
			badge = "C#",
			badgeColor = { 23, 134, 0 },
			extensions = { "cs", "xaml" },
			lineComment = "//",
			blockComment = { "/*", "*/" },
			preprocessor = true,
			keywords = wordSet("abstract as async await base break case catch checked class const continue default delegate do else enum event explicit extern false finally fixed for foreach goto if implicit in interface internal is lock namespace new null operator out override params private protected public readonly record ref return sealed sizeof stackalloc static struct switch this throw true try typeof unchecked unsafe using var virtual void volatile while yield"),
			builtins = wordSet("Console Math Task List Dictionary HashSet Enumerable Linq System String Guid DateTime Exception"),
			types = wordSet("bool byte sbyte char decimal double float int uint nint nuint long ulong object short ushort string dynamic"),
			snippets = {},
		},
		{
			id = "java",
			name = "Java",
			badge = "JV",
			badgeColor = { 176, 114, 25 },
			extensions = { "java" },
			lineComment = "//",
			blockComment = { "/*", "*/" },
			decorators = true,
			keywords = wordSet("abstract assert break case catch class const continue default do else enum exports extends false final finally for goto if implements import instanceof interface module native new non-sealed null open opens package permits private protected provides public record requires return sealed static strictfp super switch synchronized this throw throws to transient transitive true try uses var volatile while with yield"),
			builtins = wordSet("System out println String Math List ArrayList Map HashMap Set HashSet Optional Stream Collections Objects Thread Runnable Override"),
			types = wordSet("boolean byte char short int long float double void"),
			snippets = {},
		},
		{
			id = "sql",
			name = "SQL",
			badge = "SQL",
			badgeColor = { 227, 140, 0 },
			extensions = { "sql" },
			lineComment = "--",
			blockComment = { "/*", "*/" },
			caseInsensitive = true,
			keywords = wordSet("select from where insert into values update set delete create alter drop table index view trigger procedure function database schema primary foreign key references unique check default null not and or in between like ilike is exists join inner left right full outer cross on group by having order asc desc limit offset union all distinct as case when then else end begin commit rollback transaction with recursive returning"),
			builtins = wordSet("count sum avg min max coalesce nullif cast convert lower upper trim length substring concat now current_timestamp date_trunc row_number rank dense_rank"),
			types = wordSet("int integer bigint smallint serial text varchar char boolean bool float double numeric decimal date time timestamp timestamptz uuid json jsonb blob bytea"),
			snippets = {},
		},
		{
			id = "markdown",
			name = "Markdown",
			badge = "MD",
			badgeColor = { 81, 154, 186 },
			extensions = { "md", "markdown", "mdx" },
			markdownMode = true,
			keywords = wordSet(""),
			builtins = wordSet(""),
			types = wordSet(""),
			snippets = {},
		},
		{
			id = "yaml",
			name = "YAML / TOML",
			badge = "YML",
			badgeColor = { 203, 23, 30 },
			extensions = { "yaml", "yml", "toml", "ini", "cfg", "env" },
			lineComment = "#",
			jsonMode = true,
			keywords = wordSet("true false null yes no on off"),
			builtins = wordSet(""),
			types = wordSet(""),
			snippets = {},
		},
		{
			id = "shell",
			name = "Shell / Bash",
			badge = "SH",
			badgeColor = { 137, 224, 81 },
			extensions = { "sh", "bash", "zsh", "ps1", "bat", "cmd" },
			lineComment = "#",
			keywords = wordSet("if then else elif fi case esac for select while until do done in function time coproc export local readonly declare typeset unset shift return exit break continue trap source alias"),
			builtins = wordSet("echo printf cd pwd ls cp mv rm mkdir rmdir touch cat head tail grep sed awk find xargs sort uniq wc curl wget git gh node npm python3 luajit chmod chown tar zip unzip"),
			types = wordSet(""),
			snippets = {},
		},
		{
			id = "plaintext",
			name = "Plain Text",
			badge = "TXT",
			badgeColor = { 150, 150, 150 },
			extensions = { "txt", "log", "gitignore", "gitattributes", "license" },
			keywords = wordSet(""),
			builtins = wordSet(""),
			types = wordSet(""),
			snippets = {},
		},
	}

	local byId = {}
	local byExt = {}
	for _, lang in ipairs(LIST) do
		byId[lang.id] = lang
		for _, ext in ipairs(lang.extensions) do
			byExt[ext:lower()] = lang
		end
	end

	M.list = LIST
	M.byId = byId

	function M.get(id)
		return byId[tostring(id or ""):lower()] or byId.plaintext
	end

	function M.detect(path, content)
		local base = util.basename(path):lower()
		if base == "dockerfile" then return byId.shell end
		if base == "makefile" then return byId.shell end
		if base == "license" or base == "readme" then return byId.plaintext end
		if base == ".gitignore" or base == ".gitattributes" then return byId.plaintext end
		if base == ".env" then return byId.yaml end
		local ext = util.extname(path)
		if ext ~= "" and byExt[ext] then
			return byExt[ext]
		end
		local firstLine = tostring(content or ""):match("^([^\r\n]*)") or ""
		if firstLine:match("^#!/.*python") then return byId.python end
		if firstLine:match("^#!/.*node") then return byId.javascript end
		if firstLine:match("^#!/.*sh") or firstLine:match("^#!/.*bash") then return byId.shell end
		if firstLine:match("^%-%-!") then return byId.luau end
		return byId.luau
	end

	return M
end
end)()

-- [runtime/log] (1664 bytes)
__VSRBLX_MODULES["runtime/log"] = (function()
-- Ring-buffer structured logger feeding VS-RBLX's Output and HTTP/Git panels.
return function(env)
	local clock = env.require("runtime/clock")
	local signal = env.require("runtime/signal")

	local LIMIT = 400
	local entries = {}
	local M = {
		mirror = false,
		added = signal.new("log.added"),
		cleared = signal.new("log.cleared"),
	}

	local function push(level, channel, message)
		local item = {
			time = clock.timestamp(),
			ms = clock.ms(),
			level = level,
			channel = tostring(channel or "app"),
			message = tostring(message or ""),
		}
		entries[#entries + 1] = item
		if #entries > LIMIT then
			table.remove(entries, 1)
		end
		if M.mirror then
			if level == "error" or level == "warn" then
				warn(string.format("[VS-RBLX/%s] %s", item.channel, item.message))
			else
				print(string.format("[VS-RBLX/%s] %s", item.channel, item.message))
			end
		end
		M.added:fire(item)
		return item
	end

	function M.info(channel, message) return push("info", channel, message) end
	function M.warn(channel, message) return push("warn", channel, message) end
	function M.error(channel, message) return push("error", channel, message) end
	function M.output(channel, message) return push("output", channel, message) end

	function M.list(channelFilter)
		if not channelFilter or channelFilter == "all" then
			local out = {}
			for i = 1, #entries do out[i] = entries[i] end
			return out
		end
		local out = {}
		for i = 1, #entries do
			if entries[i].channel == channelFilter then
				out[#out + 1] = entries[i]
			end
		end
		return out
	end

	function M.clear()
		for i = #entries, 1, -1 do entries[i] = nil end
		M.cleared:fire()
	end

	return M
end
end)()

-- [runtime/roblox_explorer] (2147 bytes)
__VSRBLX_MODULES["runtime/roblox_explorer"] = (function()
-- Live Roblox DataModel inspector allowing developers to browse Workspace,
-- ReplicatedStorage, Players, StarterGui, and open/decompile scripts in VS-RBLX.
return function(env)
	local caps = env.require("runtime/caps")
	local M = {}

	local ROOTS = {
		"Workspace",
		"ReplicatedStorage",
		"Players",
		"StarterPlayer",
		"StarterGui",
		"Lighting",
	}

	function M.rootServices()
		local out = {}
		for _, name in ipairs(ROOTS) do
			local svc = env.services[name]
			if svc then
				out[#out + 1] = {
					name = name,
					className = svc.ClassName or name,
					instance = svc,
				}
			end
		end
		return out
	end

	function M.childrenOf(inst, limit)
		if not inst then return {} end
		local ok, children = pcall(function() return inst:GetChildren() end)
		if not ok or type(children) ~= "table" then return {} end
		local maxItems = limit or 120
		local out = {}
		for i = 1, math.min(#children, maxItems) do
			local ch = children[i]
			local isScript = false
			pcall(function()
				isScript = ch:IsA("LuaSourceContainer")
			end)
			local hasKids = false
			pcall(function()
				hasKids = #ch:GetChildren() > 0
			end)
			out[#out + 1] = {
				name = tostring(ch.Name or ch.ClassName),
				className = tostring(ch.ClassName or "Instance"),
				instance = ch,
				isScript = isScript,
				hasChildren = hasKids,
			}
		end
		table.sort(out, function(a, b)
			if a.isScript ~= b.isScript then return a.isScript end
			return a.name:lower() < b.name:lower()
		end)
		return out
	end

	function M.readScriptSource(inst)
		if not inst then return nil, "no instance" end
		local okSrc, rawSrc = pcall(function() return inst.Source end)
		if okSrc and type(rawSrc) == "string" and rawSrc ~= "" then
			return rawSrc, "Source"
		end
		if caps.fn.decompile then
			local okDec, decompiled = pcall(caps.fn.decompile, inst)
			if okDec and type(decompiled) == "string" and decompiled ~= "" then
				return decompiled, "decompile"
			end
		end
		return string.format(
			"-- Instance: %s (%s)\n-- Source is not readable without executor `decompile()` support.\n",
			tostring(inst.Name),
			tostring(inst.ClassName)
		), "stub"
	end

	return M
end
end)()

-- [runtime/runner] (3658 bytes)
__VSRBLX_MODULES["runtime/runner"] = (function()
-- Sandboxed Luau execution engine via executor `loadstring`, with captured
-- `print`/`warn` streams, runtime error tracebacks, and task cancellation.
return function(env)
	local caps = env.require("runtime/caps")
	local clock = env.require("runtime/clock")
	local log = env.require("runtime/log")
	local signal = env.require("runtime/signal")

	local M = {
		running = {},
		changed = signal.new("runner.changed"),
	}
	local nextRunId = 0

	local function stringifyArgs(...)
		local out = {}
		for i = 1, select("#", ...) do
			out[i] = tostring(select(i, ...))
		end
		return table.concat(out, "    ")
	end

	function M.execute(source, label)
		if not caps.fn.loadstring then
			local msg = "Host does not expose `loadstring` for dynamic Luau execution."
			log.error("runner", msg)
			return false, msg
		end

		local chunkName = tostring(label or "script.luau")
		local fn, compileErr = caps.fn.loadstring(tostring(source or ""), chunkName)
		if not fn then
			local errMsg = "Syntax error in " .. chunkName .. ": " .. tostring(compileErr)
			log.error("runner", errMsg)
			return false, errMsg
		end

		nextRunId = nextRunId + 1
		local runId = nextRunId
		local startedMs = clock.ms()
		local linesOut = {}

		if type(setfenv) == "function" then
			local baseEnv = caps.fn.getgenv and caps.fn.getgenv() or _G
			local proxy = setmetatable({
				print = function(...)
					local line = stringifyArgs(...)
					linesOut[#linesOut + 1] = line
					log.output("runner", line)
				end,
				warn = function(...)
					local line = "[warn] " .. stringifyArgs(...)
					linesOut[#linesOut + 1] = line
					log.warn("runner", line)
				end,
			}, {
				__index = baseEnv,
				__newindex = baseEnv,
			})
			pcall(setfenv, fn, proxy)
		end

		local record = {
			id = runId,
			label = chunkName,
			startedMs = startedMs,
			thread = nil,
			active = true,
		}
		M.running[runId] = record
		M.changed:fire()
		log.info("runner", string.format("Running %s (task #%d)...", chunkName, runId))

		local execOk, execResult = false, nil
		record.thread = task.spawn(function()
			local ok, res = pcall(fn)
			execOk, execResult = ok, res
			record.active = false
			M.running[runId] = nil
			local elapsed = clock.ms() - startedMs
			if ok then
				if res ~= nil then
					linesOut[#linesOut + 1] = "=> " .. tostring(res)
					log.output("runner", "=> " .. tostring(res))
				end
				log.info("runner", string.format("Finished %s in %d ms.", chunkName, elapsed))
			else
				log.error("runner", string.format("Runtime error in %s (%d ms): %s", chunkName, elapsed, tostring(res)))
			end
			M.changed:fire()
		end)

		return execOk, execResult, linesOut
	end

	function M.stopAll()
		local stopped = 0
		for id, rec in pairs(M.running) do
			if rec.thread then
				pcall(task.cancel, rec.thread)
			end
			rec.active = false
			M.running[id] = nil
			stopped = stopped + 1
		end
		if stopped > 0 then
			log.warn("runner", string.format("Stopped %d running script task(s).", stopped))
			M.changed:fire()
		end
		return stopped
	end

	function M.activeCount()
		local n = 0
		for _ in pairs(M.running) do n = n + 1 end
		return n
	end

	function M.evalExpression(expr)
		if not caps.fn.loadstring then
			return false, "loadstring unavailable"
		end
		local fn, err = caps.fn.loadstring("return " .. tostring(expr or ""), "watch")
		if not fn then
			fn, err = caps.fn.loadstring(tostring(expr or ""), "watch")
		end
		if not fn then return false, tostring(err) end
		if type(setfenv) == "function" then
			local baseEnv = caps.fn.getgenv and caps.fn.getgenv() or _G
			pcall(setfenv, fn, baseEnv)
		end
		local ok, val = pcall(fn)
		return ok, val
	end

	return M
end
end)()

-- [runtime/settings_catalog] (3902 bytes)
__VSRBLX_MODULES["runtime/settings_catalog"] = (function()
-- VS Code Settings catalog for the interactive Settings editor & search bar.
return function(_env)
	local M = {}

	M.items = {
		{
			key = "workbench.colorTheme",
			category = "Workbench",
			title = "Color Theme",
			description = "Specifies the color theme used in the VS-RBLX workbench.",
			kind = "select",
			options = {
				{ value = "dark_plus", label = "Dark+ (Default Dark)" },
				{ value = "one_dark", label = "One Dark Pro" },
				{ value = "github_dark", label = "GitHub Dark Default" },
				{ value = "monokai", label = "Monokai Classic" },
				{ value = "dracula", label = "Dracula Official" },
				{ value = "catppuccin", label = "Catppuccin Mocha" },
				{ value = "solarized_dark", label = "Solarized Dark" },
				{ value = "light_plus", label = "Light+ (Default Light)" },
			},
		},
		{
			key = "editor.fontSize",
			category = "Text Editor",
			title = "Font Size",
			description = "Controls the code editor font size in pixels (11 - 22).",
			kind = "number",
			min = 11,
			max = 22,
			step = 1,
		},
		{
			key = "editor.tabSize",
			category = "Text Editor",
			title = "Tab Size",
			description = "The number of spaces a tab is equal to.",
			kind = "number",
			min = 2,
			max = 8,
			step = 2,
		},
		{
			key = "editor.insertSpaces",
			category = "Text Editor",
			title = "Insert Spaces",
			description = "Insert spaces when pressing Tab instead of literal tab characters.",
			kind = "boolean",
		},
		{
			key = "editor.minimap",
			category = "Text Editor",
			title = "Minimap: Enabled",
			description = "Controls whether the right-hand code minimap is shown.",
			kind = "boolean",
		},
		{
			key = "editor.lineNumbers",
			category = "Text Editor",
			title = "Line Numbers",
			description = "Controls the display of line numbers in the editor gutter.",
			kind = "boolean",
		},
		{
			key = "editor.wordWrap",
			category = "Text Editor",
			title = "Word Wrap",
			description = "Controls how lines should wrap in the editor.",
			kind = "boolean",
		},
		{
			key = "editor.intellisense",
			category = "Text Editor",
			title = "Quick Suggestions (IntelliSense)",
			description = "Controls whether completions appear automatically while typing.",
			kind = "boolean",
		},
		{
			key = "editor.autoClosingBrackets",
			category = "Text Editor",
			title = "Auto Closing Brackets",
			description = "Controls whether the editor automatically closes brackets and quotes.",
			kind = "boolean",
		},
		{
			key = "files.autoSave",
			category = "Files",
			title = "Auto Save to Local Disk",
			description = "Controls automatic `writefile` persistence of dirty editors.",
			kind = "select",
			options = {
				{ value = "afterDelay", label = "afterDelay (Auto-write to disk)" },
				{ value = "off", label = "off (Manual Ctrl+S)" },
			},
		},
		{
			key = "window.autoResize",
			category = "Window",
			title = "Auto Resize with Viewport",
			description = "Automatically scales & clamps the VS-RBLX window when the Roblox viewport resizes.",
			kind = "boolean",
		},
		{
			key = "workbench.breadcrumbs",
			category = "Workbench",
			title = "Breadcrumbs: Enabled",
			description = "Enable/disable navigation breadcrumbs above the editor.",
			kind = "boolean",
		},
		{
			key = "github.autoSyncOnPush",
			category = "GitHub",
			title = "Sync Local Disk on Pull/Clone",
			description = "Automatically writes cloned/pulled GitHub files to local executor disk.",
			kind = "boolean",
		},
	}

	function M.search(query)
		local q = tostring(query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
		if q == "" then return M.items end
		local out = {}
		for _, item in ipairs(M.items) do
			if item.key:lower():find(q, 1, true)
				or item.title:lower():find(q, 1, true)
				or item.description:lower():find(q, 1, true)
				or item.category:lower():find(q, 1, true) then
				out[#out + 1] = item
			end
		end
		return out
	end

	return M
end
end)()

-- [runtime/shortcuts] (2121 bytes)
__VSRBLX_MODULES["runtime/shortcuts"] = (function()
-- Keyboard shortcut listener & dispatcher supporting Ctrl/Cmd + Shift + Alt chords.
return function(env)
	local dispose = env.require("runtime/dispose")
	local commands = env.require("runtime/command_catalog")

	local M = { bindings = {}, enabled = true }

	local function ctrlDown()
		local uis = env.uis
		if not uis then return false end
		local ok, down = pcall(function()
			return uis:IsKeyDown(Enum.KeyCode.LeftControl)
				or uis:IsKeyDown(Enum.KeyCode.RightControl)
				or uis:IsKeyDown(Enum.KeyCode.LeftMeta)
				or uis:IsKeyDown(Enum.KeyCode.RightMeta)
		end)
		return ok and down == true
	end

	local function shiftDown()
		local uis = env.uis
		if not uis then return false end
		local ok, down = pcall(function()
			return uis:IsKeyDown(Enum.KeyCode.LeftShift) or uis:IsKeyDown(Enum.KeyCode.RightShift)
		end)
		return ok and down == true
	end

	local function altDown()
		local uis = env.uis
		if not uis then return false end
		local ok, down = pcall(function()
			return uis:IsKeyDown(Enum.KeyCode.LeftAlt) or uis:IsKeyDown(Enum.KeyCode.RightAlt)
		end)
		return ok and down == true
	end

	function M.bind(chord, commandId, allowWhenTyping)
		M.bindings[#M.bindings + 1] = {
			ctrl = chord.ctrl == true,
			shift = chord.shift == true,
			alt = chord.alt == true,
			key = chord.key,
			commandId = commandId,
			allowWhenTyping = allowWhenTyping ~= false,
		}
	end

	function M.install()
		if not env.uis then return end
		dispose.connection(env.uis.InputBegan:Connect(function(input, gameProcessed)
			if not M.enabled then return end
			if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
			local keyName = input.KeyCode and input.KeyCode.Name or ""
			local c, s, a = ctrlDown(), shiftDown(), altDown()
			local focusedBox = nil
			pcall(function() focusedBox = env.uis:GetFocusedTextBox() end)

			for _, b in ipairs(M.bindings) do
				if b.key == keyName and b.ctrl == c and b.shift == s and b.alt == a then
					if (not focusedBox and not gameProcessed) or b.allowWhenTyping then
						commands.run(b.commandId)
						return
					end
				end
			end
		end))
	end

	return M
end
end)()

-- [runtime/signal] (1162 bytes)
__VSRBLX_MODULES["runtime/signal"] = (function()
-- Lightweight synchronous pub/sub signal used across runtime and UI modules.
return function(_env)
	local M = {}

	function M.new(name)
		local listeners = {}
		local nextId = 0
		local sig = { name = name or "signal" }

		function sig:connect(fn)
			if type(fn) ~= "function" then return function() end end
			nextId = nextId + 1
			local id = nextId
			listeners[#listeners + 1] = { id = id, fn = fn, active = true }
			return function()
				for i = #listeners, 1, -1 do
					if listeners[i].id == id then
						listeners[i].active = false
						table.remove(listeners, i)
						break
					end
				end
			end
		end

		function sig:once(fn)
			local off
			off = sig:connect(function(...)
				if off then off(); off = nil end
				fn(...)
			end)
			return off
		end

		function sig:fire(...)
			local snapshot = {}
			for i = 1, #listeners do snapshot[i] = listeners[i] end
			for i = 1, #snapshot do
				local entry = snapshot[i]
				if entry.active then
					pcall(entry.fn, ...)
				end
			end
		end

		function sig:clear()
			for i = #listeners, 1, -1 do
				listeners[i].active = false
				listeners[i] = nil
			end
		end

		return sig
	end

	return M
end
end)()

-- [runtime/util] (4605 bytes)
__VSRBLX_MODULES["runtime/util"] = (function()
-- Shared pure Luau helpers: strings, paths, tables, math, UTF-8 and JSON wrappers.
return function(env)
	local M = {}

	function M.clamp(value, lo, hi)
		if value < lo then return lo end
		if value > hi then return hi end
		return value
	end

	function M.round(value)
		return math.floor(value + 0.5)
	end

	function M.trim(text)
		return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
	end

	function M.split(text, sep)
		local out = {}
		local str = tostring(text or "")
		local delim = sep or "/"
		if delim == "" then
			for i = 1, #str do out[i] = str:sub(i, i) end
			return out
		end
		local pos = 1
		while true do
			local hit = str:find(delim, pos, true)
			if not hit then
				out[#out + 1] = str:sub(pos)
				break
			end
			out[#out + 1] = str:sub(pos, hit - 1)
			pos = hit + #delim
		end
		return out
	end

	function M.startsWith(text, prefix)
		local s = tostring(text or "")
		local p = tostring(prefix or "")
		return s:sub(1, #p) == p
	end

	function M.endsWith(text, suffix)
		local s = tostring(text or "")
		local p = tostring(suffix or "")
		return p == "" or s:sub(-#p) == p
	end

	function M.escapePattern(text)
		return (tostring(text or ""):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
	end

	function M.escapeRichText(text)
		return (tostring(text or "")
			:gsub("&", "&amp;")
			:gsub("<", "&lt;")
			:gsub(">", "&gt;")
			:gsub('"', "&quot;")
			:gsub("'", "&apos;"))
	end

	function M.validUtf8(text)
		if type(text) ~= "string" then return false end
		if utf8 and type(utf8.len) == "function" then
			local ok, count = pcall(utf8.len, text)
			return ok and count ~= nil
		end
		return true
	end

	function M.normalisePath(path)
		local clean = tostring(path or ""):gsub("\\", "/"):gsub("/+", "/"):gsub("^/+", ""):gsub("/+$", "")
		return clean
	end

	function M.basename(path)
		local clean = M.normalisePath(path)
		if clean == "" then return "" end
		return clean:match("([^/]+)$") or clean
	end

	function M.dirname(path)
		local clean = M.normalisePath(path)
		local parent = clean:match("^(.*)/[^/]+$")
		return parent or ""
	end

	function M.extname(path)
		local base = M.basename(path)
		local ext = base:match("%.([^%.]+)$")
		return ext and ext:lower() or ""
	end

	function M.joinPath(a, b)
		local left = M.normalisePath(a)
		local right = M.normalisePath(b)
		if left == "" then return right end
		if right == "" then return left end
		return left .. "/" .. right
	end

	function M.deepCopy(value, seen)
		if type(value) ~= "table" then return value end
		seen = seen or {}
		if seen[value] then return seen[value] end
		local copy = {}
		seen[value] = copy
		for k, v in pairs(value) do
			copy[M.deepCopy(k, seen)] = M.deepCopy(v, seen)
		end
		return copy
	end

	function M.shallowCopy(tbl)
		local out = {}
		if type(tbl) == "table" then
			for k, v in pairs(tbl) do out[k] = v end
		end
		return out
	end

	function M.keys(tbl)
		local out = {}
		if type(tbl) == "table" then
			for k in pairs(tbl) do out[#out + 1] = k end
		end
		table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
		return out
	end

	function M.countLines(text)
		local s = tostring(text or "")
		if s == "" then return 1 end
		local _, n = s:gsub("\n", "\n")
		return n + 1
	end

	function M.lines(text)
		local out = {}
		local s = tostring(text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
		local pos = 1
		while true do
			local nl = s:find("\n", pos, true)
			if not nl then
				out[#out + 1] = s:sub(pos)
				break
			end
			out[#out + 1] = s:sub(pos, nl - 1)
			pos = nl + 1
		end
		if #out == 0 then out[1] = "" end
		return out
	end

	function M.formatBytes(bytes)
		local n = tonumber(bytes) or 0
		if n < 1024 then return string.format("%d B", n) end
		if n < 1024 * 1024 then return string.format("%.1f KB", n / 1024) end
		return string.format("%.2f MB", n / (1024 * 1024))
	end

	function M.jsonEncode(value)
		local ok, encoded = pcall(function()
			return env.hs:JSONEncode(value)
		end)
		if ok and type(encoded) == "string" then return encoded end
		return nil, tostring(encoded)
	end

	function M.jsonDecode(text)
		if type(text) ~= "string" or text == "" then return nil, "empty json" end
		local ok, decoded = pcall(function()
			return env.hs:JSONDecode(text)
		end)
		if ok then return decoded end
		return nil, tostring(decoded)
	end

	function M.colorToHex(color)
		if not color then return "#cccccc" end
		return string.format(
			"#%02x%02x%02x",
			M.clamp(math.floor(color.R * 255 + 0.5), 0, 255),
			M.clamp(math.floor(color.G * 255 + 0.5), 0, 255),
			M.clamp(math.floor(color.B * 255 + 0.5), 0, 255)
		)
	end

	return M
end
end)()

-- [runtime/workspace_fs] (9643 bytes)
__VSRBLX_MODULES["runtime/workspace_fs"] = (function()
-- Workspace filesystem manager bridging VS-RBLX's file tree with the executor's
-- local disk (`readfile`, `writefile`, `listfiles`, `makefolder`, `delfile`, `delfolder`).
return function(env)
	local util = env.require("runtime/util")
	local fsx = env.require("runtime/fsx")
	local config = env.require("runtime/config")
	local languages = env.require("runtime/languages")
	local signal = env.require("runtime/signal")
	local log = env.require("runtime/log")

	local M = {
		changed = signal.new("workspace.changed"),
		activeName = "default",
		rawMode = false,
		rawRoot = "",
	}

	local STARTER_FILES = {
		{
			path = "README.md",
			content = table.concat({
				"# VS-RBLX Workspace",
				"",
				"Welcome to **VS-RBLX** — a full Visual Studio Code clone running inside Roblox in **100% Luau**.",
				"",
				"## Highlights",
				"- **Local Disk Sync**: Uses executor `writefile`, `readfile`, `listfiles`, and `makefolder`.",
				"- **GitHub Sync**: Clone, pull, branch, stage, commit, and push repositories over executor HTTP.",
				"- **17 Languages**: Luau, TypeScript, JavaScript, Python, JSON, HTML, CSS, Rust, Go, C++, C#, Java, SQL, Markdown, YAML, Shell.",
				"- **Run & Debug**: Press **F5** or click **Run** to execute Luau buffers live.",
				"",
			}, "\n"),
		},
		{
			path = "src/main.luau",
			content = table.concat({
				"-- VS-RBLX Starter Script (Luau)",
				"local Players = game:GetService(\"Players\")",
				"local player = Players.LocalPlayer",
				"",
				"local function greet(target)",
				"\tlocal name = target and target.Name or \"Developer\"",
				"\tprint(string.format(\"[VS-RBLX] Hello, %s! Ready to build in Luau.\", name))",
				"\treturn name",
				"end",
				"",
				"greet(player)",
				"",
			}, "\n"),
		},
		{
			path = "src/disk_demo.luau",
			content = table.concat({
				"-- Demonstrates executor writefile / readfile local disk persistence",
				"local fileName = \"VSRBLX/workspaces/default/hello_disk.txt\"",
				"if type(writefile) == \"function\" and type(readfile) == \"function\" then",
				"\twritefile(fileName, \"Saved directly to your local executor disk!\")",
				"\tprint(\"Read back from disk:\", readfile(fileName))",
				"else",
				"\twarn(\"Executor filesystem not detected; using VS-RBLX virtual disk.\")",
				"end",
				"",
			}, "\n"),
		},
		{
			path = "web/app.ts",
			content = table.concat({
				"// TypeScript multi-language syntax showcase",
				"export interface RepoStatus {",
				"\towner: string;",
				"\trepo: string;",
				"\tbranch: string;",
				"\tclean: boolean;",
				"}",
				"",
				"export async function checkRepo(status: RepoStatus): Promise<string> {",
				"\treturn `${status.owner}/${status.repo}@${status.branch}`;",
				"}",
				"",
			}, "\n"),
		},
		{
			path = "scripts/analyzer.py",
			content = table.concat({
				"# Python multi-language syntax showcase",
				"from typing import List, Dict",
				"",
				"def summarize_files(paths: List[str]) -> Dict[str, int]:",
				"    counts: Dict[str, int] = {}",
				"    for path in paths:",
				"        ext = path.rsplit('.', 1)[-1] if '.' in path else 'txt'",
				"        counts[ext] = counts.get(ext, 0) + 1",
				"    return counts",
				"",
				"if __name__ == \"__main__\":",
				"    print(summarize_files([\"main.luau\", \"app.ts\", \"README.md\"]))",
				"",
			}, "\n"),
		},
		{
			path = "vsrblx.project.json",
			content = table.concat({
				"{",
				"  \"name\": \"vs-rblx-starter\",",
				"  \"version\": \"1.0.0\",",
				"  \"language\": \"luau\",",
				"  \"entry\": \"src/main.luau\"",
				"}",
				"",
			}, "\n"),
		},
	}

	function M.scopeOpts()
		if M.rawMode then
			return { raw = true }
		end
		return { scope = "workspaces/" .. M.activeName }
	end

	function M.diskRootLabel()
		if M.rawMode then
			return M.rawRoot == "" and "ExecutorRoot:/" or ("ExecutorRoot:/" .. M.rawRoot)
		end
		return fsx.root .. "/workspaces/" .. M.activeName
	end

	local function resolveRel(relPath)
		local clean = util.normalisePath(relPath)
		if M.rawMode and M.rawRoot ~= "" then
			return util.joinPath(M.rawRoot, clean)
		end
		return clean
	end

	function M.init()
		local saved = config.get("files.activeWorkspace", "default")
		if type(saved) == "string" and saved ~= "" then
			M.activeName = saved
		end
		fsx.mkdir("", M.scopeOpts())
		local existing = fsx.list("", M.scopeOpts())
		if #existing == 0 and M.activeName == "default" and not M.rawMode then
			for _, seed in ipairs(STARTER_FILES) do
				fsx.write(seed.path, seed.content, M.scopeOpts())
			end
			log.info("fs", "Seeded starter workspace on disk at " .. M.diskRootLabel())
		end
	end

	function M.listWorkspaces()
		local items = fsx.list("", { scope = "workspaces" })
		local out = {}
		local seenDefault = false
		for _, item in ipairs(items) do
			if item.isDir then
				out[#out + 1] = item.name
				if item.name == "default" then seenDefault = true end
			end
		end
		if not seenDefault then
			table.insert(out, 1, "default")
		end
		return out
	end

	function M.openWorkspace(name)
		local clean, err = fsx.sanitise(name)
		if not clean then return false, err end
		M.rawMode = false
		M.rawRoot = ""
		M.activeName = clean
		fsx.mkdir("", M.scopeOpts())
		config.set("files.activeWorkspace", clean)
		local recent = config.get("files.recentWorkspaces", {})
		local nextRecent = { clean }
		if type(recent) == "table" then
			for _, item in ipairs(recent) do
				if item ~= clean and #nextRecent < 10 then
					nextRecent[#nextRecent + 1] = item
				end
			end
		end
		config.set("files.recentWorkspaces", nextRecent, { quiet = true })
		log.info("fs", "Opened disk workspace: " .. M.diskRootLabel())
		M.changed:fire({ reason = "switch", workspace = clean })
		return true
	end

	-- Mounts any folder directly inside the executor's workspace root!
	function M.mountExecutorFolder(folderPath)
		local clean, err = fsx.sanitise(folderPath or "", true)
		if clean == nil then return false, err end
		M.rawMode = true
		M.rawRoot = clean
		M.activeName = clean == "" and "executor-root" or util.basename(clean)
		if clean ~= "" then
			fsx.mkdir(clean, { raw = true })
		end
		log.info("fs", "Mounted raw executor disk folder: " .. M.diskRootLabel())
		M.changed:fire({ reason = "mount", workspace = M.activeName })
		return true
	end

	function M.readFile(relPath)
		return fsx.read(resolveRel(relPath), M.scopeOpts())
	end

	function M.writeFile(relPath, content)
		local ok, res = fsx.write(resolveRel(relPath), content, M.scopeOpts())
		if ok then
			M.changed:fire({ reason = "write", path = util.normalisePath(relPath) })
		end
		return ok, res
	end

	function M.createFolder(relPath)
		local ok, err = fsx.mkdir(resolveRel(relPath), M.scopeOpts())
		if ok then
			M.changed:fire({ reason = "mkdir", path = util.normalisePath(relPath) })
		end
		return ok, err
	end

	function M.deletePath(relPath)
		local ok, err = fsx.delete(resolveRel(relPath), M.scopeOpts())
		if ok then
			M.changed:fire({ reason = "delete", path = util.normalisePath(relPath) })
		end
		return ok, err
	end

	function M.renamePath(oldPath, newPath)
		local cleanOld = util.normalisePath(oldPath)
		local cleanNew, err = fsx.sanitise(newPath)
		if not cleanNew then return false, err end
		if cleanOld == cleanNew then return true end
		if fsx.isDir(resolveRel(cleanOld), M.scopeOpts()) then
			local children = M.listAllFiles(cleanOld)
			fsx.mkdir(resolveRel(cleanNew), M.scopeOpts())
			for _, file in ipairs(children) do
				local suffix = file.path:sub(#cleanOld + 2)
				local dest = util.joinPath(cleanNew, suffix)
				local body = M.readFile(file.path) or ""
				fsx.write(resolveRel(dest), body, M.scopeOpts())
			end
			fsx.delete(resolveRel(cleanOld), M.scopeOpts())
		else
			local body, readErr = M.readFile(cleanOld)
			if body == nil then return false, readErr end
			local wrote, writeErr = fsx.write(resolveRel(cleanNew), body, M.scopeOpts())
			if not wrote then return false, writeErr end
			fsx.delete(resolveRel(cleanOld), M.scopeOpts())
		end
		M.changed:fire({ reason = "rename", oldPath = cleanOld, path = cleanNew })
		return true, cleanNew
	end

	function M.exists(relPath)
		return fsx.exists(resolveRel(relPath), M.scopeOpts())
	end

	function M.isDir(relPath)
		return fsx.isDir(resolveRel(relPath), M.scopeOpts())
	end

	function M.listDir(relDir)
		local base = resolveRel(relDir or "")
		local items = fsx.list(base, M.scopeOpts())
		local out = {}
		for _, item in ipairs(items) do
			local rel = item.path
			if M.rawMode and M.rawRoot ~= "" and util.startsWith(rel, M.rawRoot .. "/") then
				rel = rel:sub(#M.rawRoot + 2)
			end
			out[#out + 1] = {
				name = item.name,
				path = rel,
				fullPath = item.fullPath,
				isDir = item.isDir,
				lang = (not item.isDir) and languages.detect(rel).id or nil,
			}
		end
		return out
	end

	function M.listAllFiles(subDir)
		local out = {}
		local function walk(dir, depth)
			if depth > 14 or #out >= 1200 then return end
			for _, item in ipairs(M.listDir(dir)) do
				if not item.isDir then
					out[#out + 1] = item
				elseif item.name ~= ".git" and item.name ~= "node_modules" then
					walk(item.path, depth + 1)
				end
			end
		end
		walk(subDir or "", 0)
		return out
	end

	function M.replaceWorkspaceFiles(filesMap, opts)
		opts = opts or {}
		if opts.clean then
			for _, entry in ipairs(M.listDir("")) do
				fsx.delete(resolveRel(entry.path), M.scopeOpts())
			end
		end
		local count = 0
		for path, body in pairs(filesMap) do
			local ok = fsx.write(resolveRel(path), body, M.scopeOpts())
			if ok then count = count + 1 end
		end
		M.changed:fire({ reason = "bulkSync", count = count })
		return count
	end

	return M
end
end)()

-- [tools/decompiler] (1075 bytes)
__VSRBLX_MODULES["tools/decompiler"] = (function()
-- Imports live Roblox game scripts (`LocalScript` / `ModuleScript`) into VS-RBLX
-- tabs or saves them directly onto local executor disk (`writefile`).
return function(env)
	local robloxExplorer = env.require("runtime/roblox_explorer")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")
	local log = env.require("runtime/log")

	local M = {}

	function M.openInstanceScript(inst, saveToWorkspace)
		local src, origin = robloxExplorer.readScriptSource(inst)
		if not src then return nil, origin end
		local safeName = tostring(inst.Name or "Script"):gsub("[^%w%-_]", "_") .. ".luau"
		if saveToWorkspace then
			local relPath = "game_imports/" .. safeName
			workspaceFs.writeFile(relPath, src)
			log.info("fs", "Imported game script to disk: " .. relPath .. " (" .. origin .. ")")
			return codeStore.openFile(relPath, { reloadFromDisk = true })
		end
		return codeStore.openVirtualTab(
			"rbx_" .. safeName .. "_" .. tostring(origin),
			safeName .. " [Game]",
			src,
			"luau",
			false
		)
	end

	return M
end
end)()

-- [tools/execution] (1008 bytes)
__VSRBLX_MODULES["tools/execution"] = (function()
-- Editor buffer execution helper for Run & Debug (`F5`).
return function(env)
	local codeStore = env.require("runtime/code_store")
	local runner = env.require("runtime/runner")
	local languages = env.require("runtime/languages")
	local log = env.require("runtime/log")

	local M = {}

	function M.runActive()
		local doc = codeStore.active()
		if not doc then
			log.warn("runner", "No active editor tab to run.")
			return false, "No active editor tab"
		end
		if doc.langId ~= "luau" then
			local lang = languages.get(doc.langId)
			local msg = string.format(
				"Direct in-game execution runs Luau scripts. '%s' is %s (use GitHub Sync / Disk Save for external runtimes).",
				doc.title,
				lang.name
			)
			log.warn("runner", msg)
			return false, msg
		end
		if doc.dirty and not doc.untitled then
			codeStore.save(doc.id, { silent = true })
		end
		return runner.execute(doc.content, doc.path ~= "" and doc.path or doc.title)
	end

	function M.stop()
		return runner.stopAll()
	end

	return M
end
end)()

-- [tools/formatter] (5314 bytes)
__VSRBLX_MODULES["tools/formatter"] = (function()
-- Multi-language source formatter (`Shift+Alt+F`) for Luau, JSON, C-style braces, and whitespace cleanup.
return function(env)
	local util = env.require("runtime/util")
	local config = env.require("runtime/config")
	local languages = env.require("runtime/languages")

	local M = {}

	local function indentStr(depth)
		local useSpaces = config.get("editor.insertSpaces", true)
		local tabSize = tonumber(config.get("editor.tabSize", 4)) or 4
		if useSpaces then
			return string.rep(" ", math.max(0, depth) * tabSize)
		end
		return string.rep("\t", math.max(0, depth))
	end

	local function prettyJson(val, depth)
		local kind = type(val)
		if val == nil then return "null" end
		if kind == "boolean" then return val and "true" or "false" end
		if kind == "number" then return tostring(val) end
		if kind == "string" then
			return util.jsonEncode(val) or ('"' .. val .. '"')
		end
		if kind == "table" then
			local isArr = true
			local n = 0
			for k in pairs(val) do
				if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
					isArr = false
					break
				end
				n = n + 1
			end
			if isArr and n == #val then
				if n == 0 then return "[]" end
				local items = {}
				for i = 1, n do
					items[i] = indentStr(depth + 1) .. prettyJson(val[i], depth + 1)
				end
				return "[\n" .. table.concat(items, ",\n") .. "\n" .. indentStr(depth) .. "]"
			end
			local keys = util.keys(val)
			if #keys == 0 then return "{}" end
			local rows = {}
			for _, k in ipairs(keys) do
				rows[#rows + 1] = indentStr(depth + 1)
					.. (util.jsonEncode(tostring(k)) or ('"' .. tostring(k) .. '"'))
					.. ": " .. prettyJson(val[k], depth + 1)
			end
			return "{\n" .. table.concat(rows, ",\n") .. "\n" .. indentStr(depth) .. "}"
		end
		return tostring(val)
	end

	local function formatLuau(source)
		local lines = util.lines(source)
		local out = {}
		local depth = 0
		for _, rawLine in ipairs(lines) do
			local trimmed = util.trim(rawLine)
			if trimmed == "" then
				out[#out + 1] = ""
			else
				local codeOnly = trimmed:gsub("%-%-.*$", "")
				local dedentNow = false
				if codeOnly:match("^end[%s%),;]*$")
					or codeOnly:match("^else%f[%W]")
					or codeOnly:match("^elseif%f[%W]")
					or codeOnly:match("^until%f[%W]")
					or codeOnly:match("^[}%]%)][%s,;]*$") then
					dedentNow = true
				end
				if dedentNow then
					depth = math.max(0, depth - 1)
				end
				out[#out + 1] = indentStr(depth) .. trimmed

				local opens = 0
				for _ in codeOnly:gmatch("%f[%w]function%f[%W]") do opens = opens + 1 end
				for _ in codeOnly:gmatch("%f[%w]then%f[%W]") do opens = opens + 1 end
				for _ in codeOnly:gmatch("%f[%w]do%f[%W]") do opens = opens + 1 end
				for _ in codeOnly:gmatch("%f[%w]repeat%f[%W]") do opens = opens + 1 end
				if codeOnly:match("^else%f[%W]") then opens = opens + 1 end
				for _ in codeOnly:gmatch("{") do opens = opens + 1 end

				local closes = 0
				for _ in codeOnly:gmatch("%f[%w]end%f[%W]") do closes = closes + 1 end
				for _ in codeOnly:gmatch("%f[%w]until%f[%W]") do closes = closes + 1 end
				for _ in codeOnly:gmatch("}") do closes = closes + 1 end
				if dedentNow and (codeOnly:match("^end") or codeOnly:match("^until") or codeOnly:match("^[}]")) then
					closes = math.max(0, closes - 1)
				end
				depth = math.max(0, depth + opens - closes)
			end
		end
		return table.concat(out, "\n") .. "\n"
	end

	local function formatBraces(source)
		local lines = util.lines(source)
		local out = {}
		local depth = 0
		for _, rawLine in ipairs(lines) do
			local trimmed = util.trim(rawLine)
			if trimmed == "" then
				out[#out + 1] = ""
			else
				if trimmed:match("^[}%]%)];?,?$") or trimmed:match("^}%s*else") or trimmed:match("^}%s*catch") then
					depth = math.max(0, depth - 1)
				end
				out[#out + 1] = indentStr(depth) .. trimmed
				local opens = 0
				for _ in trimmed:gmatch("{") do opens = opens + 1 end
				local closes = 0
				for _ in trimmed:gmatch("}") do closes = closes + 1 end
				if trimmed:match("^}") then closes = math.max(0, closes - 1) end
				depth = math.max(0, depth + opens - closes)
			end
		end
		return table.concat(out, "\n") .. "\n"
	end

	function M.format(source, langId)
		local lang = languages.get(langId)
		local text = tostring(source or "")
		if lang.id == "json" then
			local decoded, err = util.jsonDecode(text)
			if decoded ~= nil then
				return prettyJson(decoded, 0) .. "\n"
			end
			return text, err
		elseif lang.id == "luau" then
			return formatLuau(text)
		elseif lang.id == "javascript" or lang.id == "typescript" or lang.id == "css"
			or lang.id == "rust" or lang.id == "go" or lang.id == "cpp"
			or lang.id == "csharp" or lang.id == "java" then
			return formatBraces(text)
		else
			local lines = util.lines(text)
			for i = 1, #lines do
				lines[i] = (lines[i]:gsub("[ \t]+$", ""))
			end
			return table.concat(lines, "\n")
		end
	end

	M.formatText = M.format

	function M.formatActive()
		local codeStore = env.require("runtime/code_store")
		local doc = codeStore.active()
		if not doc or doc.readOnly or doc.isDiff then
			return false, "No editable document active"
		end
		local formatted, err = M.format(doc.content, doc.langId)
		if not formatted then
			return false, err or "Format failed"
		end
		codeStore.updateContent(doc.id, formatted)
		return true
	end

	return M
end
end)()

-- [tools/fs_sync] (1456 bytes)
__VSRBLX_MODULES["tools/fs_sync"] = (function()
-- Local executor disk workspace management (`readfile`, `writefile`, `listfiles`).
return function(env)
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")
	local gitState = env.require("runtime/git_state")
	local log = env.require("runtime/log")

	local M = {}

	function M.reloadFromDisk()
		codeStore.syncWithWorkspace()
		workspaceFs.changed:fire({ reason = "reload" })
		log.info("fs", "Reloaded workspace tree from local disk: " .. workspaceFs.diskRootLabel())
		return true
	end

	function M.switchWorkspace(name)
		codeStore.saveAll()
		local ok, err = workspaceFs.openWorkspace(name)
		if not ok then return false, err end
		gitState.loadMeta()
		for i = #codeStore.tabs, 1, -1 do
			local t = codeStore.tabs[i]
			codeStore.byId[t.id] = nil
			codeStore.tabs[i] = nil
		end
		codeStore.activeId = nil
		local files = workspaceFs.listAllFiles("")
		if files[1] then
			codeStore.openFile(files[1].path)
		end
		return true
	end

	function M.mountRawFolder(folderPath)
		codeStore.saveAll()
		local ok, err = workspaceFs.mountExecutorFolder(folderPath)
		if not ok then return false, err end
		for i = #codeStore.tabs, 1, -1 do
			local t = codeStore.tabs[i]
			codeStore.byId[t.id] = nil
			codeStore.tabs[i] = nil
		end
		codeStore.activeId = nil
		local files = workspaceFs.listAllFiles("")
		if files[1] then
			codeStore.openFile(files[1].path)
		end
		return true
	end

	return M
end
end)()

-- [tools/github_sync] (5951 bytes)
__VSRBLX_MODULES["tools/github_sync"] = (function()
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
end)()

-- [tools/init] (385 bytes)
__VSRBLX_MODULES["tools/init"] = (function()
-- Unified tool registry for VS-RBLX developer actions.
return function(env)
	local M = {
		formatter = env.require("tools/formatter"),
		githubSync = env.require("tools/github_sync"),
		fsSync = env.require("tools/fs_sync"),
		execution = env.require("tools/execution"),
		decompiler = env.require("tools/decompiler"),
		terminal = env.require("tools/terminal_cmds"),
	}
	return M
end
end)()

-- [tools/terminal_cmds] (9899 bytes)
__VSRBLX_MODULES["tools/terminal_cmds"] = (function()
-- VS-RBLX Integrated Terminal command shell supporting disk I/O (`ls`, `cat`,
-- `touch`, `mkdir`, `rm`), Luau execution (`run`, `luau`), Git/GitHub (`git clone`,
-- `git status`, `git pull`, `git commit`, `git push`, `gh auth`), and HTTP (`http get`).
return function(env)
	local util = env.require("runtime/util")
	local caps = env.require("runtime/caps")
	local config = env.require("runtime/config")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")
	local gitState = env.require("runtime/git_state")
	local runner = env.require("runtime/runner")
	local github = env.require("net/github")
	local githubSync = env.require("tools/github_sync")
	local http = env.require("net/http")
	local signal = env.require("runtime/signal")

	local M = {
		cwd = "",
		lines = {
			"VS-RBLX Integrated Terminal v1.0 (Luau Shell)",
			"Type 'help' for disk, Luau, HTTP, and GitHub commands.",
		},
		changed = signal.new("terminal.changed"),
	}

	local function pushLine(text)
		for _, line in ipairs(util.lines(tostring(text or ""))) do
			M.lines[#M.lines + 1] = line
		end
		while #M.lines > 300 do
			table.remove(M.lines, 1)
		end
		M.changed:fire()
	end

	local function resolveCwdPath(argPath)
		local p = util.trim(argPath or "")
		if p == "" or p == "." then return M.cwd end
		if p == "/" or p == "~" then return "" end
		if p == ".." then return util.dirname(M.cwd) end
		if util.startsWith(p, "../") then
			return util.joinPath(util.dirname(M.cwd), p:sub(4))
		end
		if util.startsWith(p, "/") then
			return util.normalisePath(p)
		end
		return util.joinPath(M.cwd, p)
	end

	function M.print(text)
		pushLine(text)
	end

	function M.clear()
		M.lines = {}
		M.changed:fire()
	end

	function M.execute(rawInput)
		local cmdLine = util.trim(rawInput or "")
		local promptPrefix = string.format("vsrblx:%s/%s$ ", workspaceFs.activeName, M.cwd)
		pushLine(promptPrefix .. cmdLine)
		if cmdLine == "" then return end

		local cmd, rest = cmdLine:match("^(%S+)%s*(.*)$")
		cmd = (cmd or ""):lower()
		rest = util.trim(rest or "")

		if cmd == "help" then
			pushLine(table.concat({
				"Available Commands:",
				"  ls [dir]                 List workspace files on local disk",
				"  cd <dir> | pwd           Change or print current directory",
				"  cat <file>               Print file contents via readfile",
				"  touch <file>             Create empty file via writefile",
				"  mkdir <dir>              Create folder via makefolder",
				"  rm <path>                Delete file or folder",
				"  open <file>              Open file in VS-RBLX editor tab",
				"  save                     Save all dirty tabs to local disk",
				"  run [file]               Execute Luau file (or active tab)",
				"  luau <expr>              Evaluate inline Luau code",
				"  git clone <owner/repo>   Clone GitHub repo onto local disk",
				"  git status               Show modified / staged files",
				"  git add <file|.>         Stage file(s) for commit",
				"  git pull                 Pull latest changes from GitHub",
				"  git push [message]       Commit & push changes to GitHub",
				"  gh auth <token>          Verify & store GitHub PAT token",
				"  http get <url>           Perform executor HTTP GET request",
				"  theme <id>               Switch VS Code color theme",
				"  caps                     Inspect executor capabilities",
				"  clear                    Clear terminal output",
			}, "\n"))
		elseif cmd == "clear" or cmd == "cls" then
			M.clear()
		elseif cmd == "pwd" then
			pushLine(workspaceFs.diskRootLabel() .. (M.cwd ~= "" and ("/" .. M.cwd) or ""))
		elseif cmd == "cd" then
			local target = resolveCwdPath(rest)
			if target == "" or workspaceFs.isDir(target) then
				M.cwd = target
			else
				pushLine("cd: no such directory: " .. tostring(rest))
			end
		elseif cmd == "ls" or cmd == "dir" then
			local target = resolveCwdPath(rest)
			local entries = workspaceFs.listDir(target)
			if #entries == 0 then
				pushLine("(empty directory)")
			else
				local row = {}
				for _, item in ipairs(entries) do
					row[#row + 1] = item.isDir and (item.name .. "/") or item.name
				end
				pushLine(table.concat(row, "  "))
			end
		elseif cmd == "cat" then
			if rest == "" then
				pushLine("usage: cat <file>")
			else
				local content, err = workspaceFs.readFile(resolveCwdPath(rest))
				pushLine(content ~= nil and content or ("cat: " .. tostring(err)))
			end
		elseif cmd == "touch" then
			if rest == "" then
				pushLine("usage: touch <file>")
			else
				local target = resolveCwdPath(rest)
				if not workspaceFs.exists(target) then
					workspaceFs.writeFile(target, "")
				end
				pushLine("wrote " .. target)
			end
		elseif cmd == "mkdir" then
			if rest == "" then
				pushLine("usage: mkdir <folder>")
			else
				local target = resolveCwdPath(rest)
				workspaceFs.createFolder(target)
				pushLine("created folder " .. target)
			end
		elseif cmd == "rm" then
			if rest == "" then
				pushLine("usage: rm <path>")
			else
				local target = resolveCwdPath(rest)
				workspaceFs.deletePath(target)
				pushLine("deleted " .. target)
			end
		elseif cmd == "open" or cmd == "code" then
			if rest == "" then
				pushLine("usage: open <file>")
			else
				local doc, err = codeStore.openFile(resolveCwdPath(rest), { createIfMissing = true })
				pushLine(doc and ("Opened " .. doc.path) or ("open failed: " .. tostring(err)))
			end
		elseif cmd == "save" then
			local n = codeStore.saveAll()
			pushLine(string.format("Saved %d file(s) to %s", n, workspaceFs.diskRootLabel()))
		elseif cmd == "run" then
			if rest ~= "" then
				local p = resolveCwdPath(rest)
				local src, err = workspaceFs.readFile(p)
				if not src then
					pushLine("run: " .. tostring(err))
				else
					local _, _, out = runner.execute(src, p)
					for _, l in ipairs(out or {}) do pushLine(l) end
				end
			else
				local doc = codeStore.active()
				if not doc then
					pushLine("run: no active file")
				else
					local _, _, out = runner.execute(doc.content, doc.path)
					for _, l in ipairs(out or {}) do pushLine(l) end
				end
			end
		elseif cmd == "luau" or cmd == "eval" then
			local _, _, out = runner.execute(rest, "terminal.luau")
			for _, l in ipairs(out or {}) do pushLine(l) end
		elseif cmd == "caps" then
			pushLine(caps.summary())
			for _, item in ipairs(caps.matrix()) do
				pushLine(string.format("  %-34s : %s", item.label, item.value))
			end
		elseif cmd == "theme" then
			if rest == "" then
				pushLine("Current theme: " .. tostring(config.get("workbench.colorTheme", "dark_plus")))
				pushLine("Themes: dark_plus, one_dark, github_dark, monokai, dracula, catppuccin, solarized_dark, light_plus")
			else
				config.set("workbench.colorTheme", rest)
				pushLine("Theme set to " .. rest)
			end
		elseif cmd == "http" then
			local sub, urlArg = rest:match("^(%S+)%s+(.+)$")
			if sub and sub:lower() == "get" then
				local res = http.get(util.trim(urlArg), nil, { json = false })
				pushLine(string.format("HTTP %d (%d bytes)", res.status, #res.body))
				pushLine(res.body:sub(1, 500))
			else
				pushLine("usage: http get <url>")
			end
		elseif cmd == "gh" then
			local sub, argVal = rest:match("^(%S+)%s*(.*)$")
			sub = (sub or ""):lower()
			if sub == "auth" then
				local user, err = github.verifyToken(argVal)
				if user then
					pushLine("Authenticated with GitHub as @" .. tostring(user.login))
				else
					pushLine("gh auth failed: " .. tostring(err))
				end
			elseif sub == "repos" then
				local repos, err = github.listUserRepos()
				if not repos then
					pushLine("gh repos: " .. tostring(err))
				else
					for _, r in ipairs(repos) do
						pushLine(string.format("  %-34s [%s]", r.fullName, r.defaultBranch))
					end
				end
			else
				pushLine("usage: gh auth <token> | gh repos")
			end
		elseif cmd == "git" then
			local sub, argVal = rest:match("^(%S+)%s*(.*)$")
			sub = (sub or ""):lower()
			argVal = util.trim(argVal or "")
			if sub == "status" then
				local st = gitState.status()
				pushLine("Repo: " .. tostring(st.repo or "(local workspace)") .. " | Branch: " .. tostring(st.branch))
				if st.total == 0 then
					pushLine("nothing to commit, working tree clean")
				else
					for _, e in ipairs(st.staged) do pushLine("  staged   " .. e.kind .. " " .. e.path) end
					for _, e in ipairs(st.unstaged) do pushLine("  modified " .. e.kind .. " " .. e.path) end
				end
			elseif sub == "clone" then
				if argVal == "" then
					pushLine("usage: git clone <owner/repo>")
				else
					local snap, err = githubSync.cloneRepo(argVal)
					if snap then
						M.cwd = ""
						pushLine(string.format("Cloned %s@%s (%d files written to local disk)", snap.fullName, snap.branch, snap.fetched))
					else
						pushLine("git clone error: " .. tostring(err))
					end
				end
			elseif sub == "pull" then
				local snap, err = githubSync.pull()
				pushLine(snap and string.format("Pulled %d files from %s@%s", snap.fetched, snap.fullName, snap.branch) or ("git pull error: " .. tostring(err)))
			elseif sub == "add" then
				if argVal == "." or argVal == "-A" or argVal == "" then
					gitState.stageAll()
					pushLine("Staged all modified files.")
				else
					gitState.stage(resolveCwdPath(argVal))
					pushLine("Staged " .. argVal)
				end
			elseif sub == "commit" or sub == "push" then
				local msg = argVal:match('%-m%s+"([^"]+)"') or argVal:match("%-m%s+'([^']+)'") or (argVal ~= "" and argVal or "Update from VS-RBLX")
				local res, err = githubSync.commitAndPush(msg)
				pushLine(res and ("Committed & pushed (" .. tostring(res.sha):sub(1, 7) .. ")") or ("git push error: " .. tostring(err)))
			else
				pushLine("git commands: status, clone <owner/repo>, pull, add <path|.>, push [msg]")
			end
		else
			pushLine("Unknown command: '" .. cmd .. "'. Type 'help' for available commands.")
		end
	end

	return M
end
end)()

-- [ui/activitybar] (4995 bytes)
__VSRBLX_MODULES["ui/activitybar"] = (function()
-- Left 48px VS Code Activity Bar with active left indicator bar and SCM change count badge.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local icons = env.require("ui/icons")
	local config = env.require("runtime/config")
	local gitState = env.require("runtime/git_state")
	local commands = env.require("runtime/command_catalog")

	local M = {}

	local ITEMS = {
		{ id = "explorer", icon = "explorer", title = "Explorer" },
		{ id = "search", icon = "search", title = "Search" },
		{ id = "scm", icon = "scm", title = "Source Control (GitHub)" },
		{ id = "debug", icon = "debug", title = "Run and Debug" },
		{ id = "extensions", icon = "extensions", title = "Extensions & Languages" },
	}

	function M.new(parent, onSelectViewlet)
		local w = theme.sizes.activityBar
		local root = P.frame(parent, {
			name = "ActivityBar",
			size = UDim2.new(0, w, 1, 0),
			bg = theme.color.activityBar,
			zIndex = 25,
		})
		local rightRule = P.frame(root, {
			size = UDim2.new(0, 1, 1, 0),
			pos = UDim2.new(1, -1, 0, 0),
			bg = theme.color.border,
			zIndex = 26,
		})

		local topGroup = P.frame(root, {
			name = "TopIcons",
			size = UDim2.new(1, 0, 0, #ITEMS * 48),
			zIndex = 26,
		})
		P.list(topGroup, Enum.FillDirection.Vertical, 0)

		local entries = {}
		local scmBadge, scmBadgeLbl

		for idx, spec in ipairs(ITEMS) do
			local btn = P.button(topGroup, {
				name = "Activity_" .. spec.id,
				size = UDim2.fromOffset(w, 48),
				hoverBg = theme.color.hover,
				text = "",
				order = idx,
				zIndex = 27,
				onClick = function()
					if onSelectViewlet then onSelectViewlet(spec.id) end
				end,
			})
			local bar = P.frame(btn, {
				name = "ActiveBar",
				size = UDim2.new(0, 2, 0, 32),
				pos = UDim2.fromOffset(0, 8),
				bg = theme.color.activityIndicator,
				visible = false,
				zIndex = 29,
			})
			local icHolder = P.frame(btn, {
				size = UDim2.fromOffset(22, 22),
				pos = UDim2.fromOffset(13, 13),
				zIndex = 28,
			})
			entries[spec.id] = { btn = btn, bar = bar, icHolder = icHolder, iconName = spec.icon }

			if spec.id == "scm" then
				scmBadge = P.frame(btn, {
					name = "ScmBadge",
					size = UDim2.fromOffset(16, 16),
					pos = UDim2.fromOffset(26, 26),
					bg = theme.color.accent,
					radius = 8,
					visible = false,
					zIndex = 30,
				})
				scmBadgeLbl = P.label(scmBadge, {
					size = UDim2.fromScale(1, 1),
					text = "0",
					bold = true,
					textSize = 10,
					color = Color3.fromRGB(255, 255, 255),
					alignX = Enum.TextXAlignment.Center,
					zIndex = 31,
				})
			end
		end

		local bottomGroup = P.frame(root, {
			name = "BottomIcons",
			size = UDim2.new(1, 0, 0, 96),
			pos = UDim2.new(0, 0, 1, -96),
			zIndex = 26,
		})
		P.list(bottomGroup, Enum.FillDirection.Vertical, 0)

		local accountBtn = P.button(bottomGroup, {
			name = "Activity_account",
			size = UDim2.fromOffset(w, 48),
			hoverBg = theme.color.hover,
			text = "",
			order = 1,
			zIndex = 27,
			onClick = function() commands.run("github.auth") end,
		})
		local accIcon = icons.codicon(accountBtn, "account", 20, theme.color.activityIcon, 28)
		accIcon.Position = UDim2.fromOffset(14, 14)

		local settingsBtn = P.button(bottomGroup, {
			name = "Activity_settings",
			size = UDim2.fromOffset(w, 48),
			hoverBg = theme.color.hover,
			text = "",
			order = 2,
			zIndex = 27,
			onClick = function()
				if onSelectViewlet then onSelectViewlet("settings") end
			end,
		})
		local gearIcon = icons.codicon(settingsBtn, "settings", 20, theme.color.activityIcon, 28)
		gearIcon.Position = UDim2.fromOffset(14, 14)

		local function redrawIcons()
			local current = config.get("workbench.activeViewlet", "explorer")
			local sidebarShown = config.get("workbench.sideBarVisible", true)
			for id, e in pairs(entries) do
				local isActive = sidebarShown and (current == id)
				e.bar.Visible = isActive
				e.bar.BackgroundColor3 = theme.color.activityIndicator
				e.icHolder:ClearAllChildren()
				icons.codicon(
					e.icHolder,
					e.iconName,
					22,
					isActive and theme.color.activityIconActive or theme.color.activityIcon,
					28
				)
			end
		end

		local function refreshScmCount()
			local st = gitState.status()
			if st.total > 0 then
				scmBadge.Visible = true
				scmBadge.BackgroundColor3 = theme.color.accent
				scmBadgeLbl.Text = st.total > 99 and "99+" or tostring(st.total)
			else
				scmBadge.Visible = false
			end
		end

		config.changed:connect(function(key)
			if key == "*" or key == "workbench.activeViewlet" or key == "workbench.sideBarVisible" then
				redrawIcons()
			end
		end)
		gitState.changed:connect(refreshScmCount)
		theme.changed:connect(function()
			root.BackgroundColor3 = theme.color.activityBar
			rightRule.BackgroundColor3 = theme.color.border
			redrawIcons()
			refreshScmCount()
		end)

		redrawIcons()
		refreshScmCount()
		return {
			root = root,
			refresh = redrawIcons,
			refreshScm = refreshScmCount,
		}
	end

	return M
end
end)()

-- [ui/app] (22682 bytes)
__VSRBLX_MODULES["ui/app"] = (function()
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
	local commandPaletteMod = env.require("ui/command_palette")

	local tabsMod = env.require("ui/code/tabs")
	local breadcrumbsMod = env.require("ui/code/breadcrumbs")
	local editorMod = env.require("ui/code/editor")
	local splitterMod = env.require("ui/code/splitter")
	local terminalMod = env.require("ui/code/terminal")

	local explorerPanel = env.require("ui/panels/explorer")
	local searchPanel = env.require("ui/panels/search")
	local scmPanel = env.require("ui/panels/scm")
	local debugPanel = env.require("ui/panels/debug")
	local extensionsPanel = env.require("ui/panels/extensions")
	local settingsPanel = env.require("ui/panels/settings")
	local githubConnect = env.require("ui/panels/github_connect")

	local util = env.require("runtime/util")
	local dispose = env.require("runtime/dispose")
	local config = env.require("runtime/config")
	local bootProgress = env.require("runtime/boot_progress")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")
	local gitState = env.require("runtime/git_state")
	local commands = env.require("runtime/command_catalog")
	local shortcuts = env.require("runtime/shortcuts")
	local tools = env.require("tools/init")

	local M = {}

	local function resolveGuiHost()
		if type(env.gethui) == "function" then
			local ok, hui = pcall(env.gethui)
			if ok and hui then return hui end
		end
		if env.coreGui then
			local ok, _ = pcall(function() return env.coreGui.Name end)
			if ok then return env.coreGui end
		end
		if env.plr then
			local pg = env.plr:FindFirstChild("PlayerGui")
			if pg then return pg end
		end
		return nil
	end

	function M.mount(opts)
		opts = opts or {}
		local splash = bootSplash.show()
		if splash then splash.step("Loading workspace configuration...", 0.2) end

		config.load()
		theme.apply()

		bootProgress.update("fs", "Mounting local disk workspace (writefile / readfile)...")
		if splash then splash.step("Mounting local disk workspace...", 0.45) end
		workspaceFs.init()
		gitState.loadMeta()

		local guiParent = opts.parent or resolveGuiHost()
		local screenGui = Instance.new("ScreenGui")
		screenGui.Name = "VSRBLX_Workbench"
		screenGui.ResetOnSpawn = false
		screenGui.IgnoreGuiInset = true
		screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		if guiParent then
			pcall(function() screenGui.Parent = guiParent end)
		end
		dispose.add(function()
			pcall(function() screenGui:Destroy() end)
		end)

		overlay.mount(screenGui)

		bootProgress.update("ui", "Constructing draggable & player-resizable VS Code window...")
		if splash then splash.step("Building VS Code workbench...", 0.75) end

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

		-- TitleBar (bound to window drag + maximize/minimize/close controls)
		local titleBar = titlebarMod.new(win.body, {
			onMinimize = function() win.minimise() end,
			onMaximize = function() win.toggleMaximise() end,
			onClose = function() win.hide() end,
		})
		win.bindDragBar(titleBar.root)

		-- StatusBar
		statusbarMod.new(win.body)

		-- Central Body Frame between TitleBar and StatusBar
		local workbenchBody = P.frame(win.body, {
			name = "WorkbenchBody",
			size = UDim2.new(1, 0, 1, -(TITLE_H + STATUS_H)),
			pos = UDim2.fromOffset(0, TITLE_H),
			bg = theme.color.editor,
			clip = true,
			zIndex = 11,
		})

		-- Primary Sidebar Container
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

		-- Viewlets inside Primary Sidebar
		local viewlets = {
			explorer = explorerPanel.new(sideBarFrame),
			search = searchPanel.new(sideBarFrame),
			scm = scmPanel.new(sideBarFrame),
			debug = debugPanel.new(sideBarFrame),
			extensions = extensionsPanel.new(sideBarFrame),
			settings = settingsPanel.new(sideBarFrame),
		}

		-- Main Center Stack (Editors on top + Bottom Terminal Panel below)
		local mainArea = P.frame(workbenchBody, {
			name = "MainEditorAndPanelStack",
			bg = theme.color.editor,
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
			clip = true,
			zIndex = 12,
		})
		tabsMod.new(primaryGroup, "primary")
		breadcrumbsMod.new(primaryGroup, "primary")
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
			visible = false,
			clip = true,
			zIndex = 12,
		})
		local splitLeftRule = P.frame(secondaryGroup, {
			size = UDim2.new(0, 1, 1, 0),
			bg = theme.color.border,
			zIndex = 30,
		})
		tabsMod.new(secondaryGroup, "secondary")
		breadcrumbsMod.new(secondaryGroup, "secondary")
		local secondaryBody = P.frame(secondaryGroup, {
			size = UDim2.new(1, 0, 1, -(TAB_H + CRUMB_H)),
			pos = UDim2.fromOffset(0, TAB_H + CRUMB_H),
			zIndex = 12,
		})
		local secondaryEditor = editorMod.new(secondaryBody, "secondary")

		-- Bottom Panel (`PROBLEMS`, `OUTPUT`, `TERMINAL`, `HTTP / GIT`)
		local panelHolder = P.frame(mainArea, {
			name = "BottomPanelContainer",
			bg = theme.color.panelBg,
			clip = true,
			zIndex = 20,
		})

		local reflowWorkbench

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

		reflowWorkbench = function()
			local effSideW = sideBarVisible and sideBarWidth or 0
			sideBarFrame.Visible = sideBarVisible
			sideBarFrame.Size = UDim2.new(0, sideBarWidth, 1, 0)
			sideSash.Visible = sideBarVisible
			sideSash.Position = UDim2.fromOffset(ACT_W + sideBarWidth - 2, 0)

			local leftOffset = ACT_W + effSideW
			mainArea.Position = UDim2.fromOffset(leftOffset, 0)
			mainArea.Size = UDim2.new(1, -leftOffset, 1, 0)

			local effPanelH = panelVisible and panelHeight or 0
			panelHolder.Visible = panelVisible
			panelHolder.Size = UDim2.new(1, 0, 0, effPanelH)
			panelHolder.Position = UDim2.new(0, 0, 1, -effPanelH)

			panelSash.Visible = panelVisible
			panelSash.Position = UDim2.new(0, 0, 1, -effPanelH - 2)

			editorsRegion.Position = UDim2.fromOffset(0, 0)
			editorsRegion.Size = UDim2.new(1, 0, 1, -effPanelH)

			if codeStore.splitOpen then
				primaryGroup.Size = UDim2.new(splitRatio, 0, 1, 0)
				secondaryGroup.Visible = true
				secondaryGroup.Position = UDim2.new(splitRatio, 0, 0, 0)
				secondaryGroup.Size = UDim2.new(1 - splitRatio, 0, 1, 0)
				editorSplitSash.Visible = true
				editorSplitSash.Position = UDim2.new(splitRatio, -2, 0, 0)
			else
				primaryGroup.Size = UDim2.fromScale(1, 1)
				secondaryGroup.Visible = false
				editorSplitSash.Visible = false
			end
		end

		local actBar
		local function selectViewlet(id, toggleIfSame)
			if toggleIfSame and sideBarVisible and activeViewlet == id then
				sideBarVisible = false
			else
				activeViewlet = id
				sideBarVisible = true
			end
			for k, v in pairs(viewlets) do
				v.root.Visible = (k == activeViewlet)
			end
			config.set("workbench.activeViewlet", activeViewlet)
			config.set("workbench.sideBarVisible", sideBarVisible)
			if actBar then actBar.refresh() end
			reflowWorkbench()
			if sideBarVisible and id == "search" and viewlets.search.focus then
				viewlets.search.focus()
			end
		end

		actBar = activitybarMod.new(workbenchBody, function(id)
			selectViewlet(id, true)
		end)

		codeStore.changed:connect(reflowWorkbench)
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

			reg("workbench.toggleSideBar", "Toggle Primary Side Bar", "View", "Ctrl+B", function()
				sideBarVisible = not sideBarVisible
				config.set("workbench.sideBarVisible", sideBarVisible)
				actBar.refresh()
				reflowWorkbench()
			end, { "view.toggleSidebar" })

			reg("workbench.togglePanel", "Toggle Integrated Terminal & Panel", "View", "Ctrl+J", function()
				panelVisible = not panelVisible
				config.set("workbench.panelVisible", panelVisible)
				reflowWorkbench()
				if panelVisible then bottomTerminal.focusTerminal() end
			end, { "view.togglePanel" })

			reg("workbench.showProblems", "Focus Problems Panel", "View", nil, function()
				panelVisible = true
				bottomTerminal.selectTab("problems")
				reflowWorkbench()
			end, { "view.problems" })

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
			reg("file.newDiskFile", "New File on Local Disk...", "File", nil, function()
				viewlets.explorer.fileTree.promptNewFile()
			end)
			reg("file.newDiskFolder", "New Folder on Local Disk...", "File", nil, function()
				viewlets.explorer.fileTree.promptNewFolder()
			end, { "file.newFolder" })

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
							local ok, err = codeStore.saveAs(doc.id, p)
							if ok then overlay.toast("Saved " .. p .. " via writefile", "good", 2.5)
							else overlay.toast("Save failed: " .. tostring(err), "bad", 4) end
						end,
					})
				else
					local ok, err = codeStore.save(doc.id)
					if ok then overlay.toast("Saved " .. doc.path, "good", 2)
					else overlay.toast("Save failed: " .. tostring(err), "bad", 4) end
				end
			end)

			reg("file.saveAll", "Save All Modified Files to Disk", "File", "Ctrl+Shift+S", function()
				local n = codeStore.saveAll()
				overlay.toast(string.format("Saved %d file(s) to disk", n), "good", 2.5)
			end)

			reg("file.closeTab", "Close Active Editor Tab", "View", "Ctrl+W", function()
				local doc = codeStore.active()
				if doc then codeStore.close(doc.id) end
			end)

			reg("edit.undo", "Undo", "Edit", "Ctrl+Z", function()
				local doc = codeStore.active()
				if doc and codeStore.undo then codeStore.undo(doc.id) end
			end)
			reg("edit.redo", "Redo", "Edit", "Ctrl+Y", function()
				local doc = codeStore.active()
				if doc and codeStore.redo then codeStore.redo(doc.id) end
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

			reg("editor.format", "Format Document", "Edit", "Shift+Alt+F", function()
				local ok, msg = tools.formatter.formatActive()
				overlay.toast(ok and "Formatted document" or tostring(msg), ok and "good" or "warn", 2)
			end, { "edit.format" })

			reg("editor.toggleSplit", "Split Editor Right / Close Split", "View", "Ctrl+\\", function()
				codeStore.toggleSplit()
				reflowWorkbench()
			end, { "view.splitEditor" })

			reg("editor.toggleMinimap", "Toggle Editor Minimap", "View", nil, function()
				config.set("editor.minimap", not config.get("editor.minimap", true))
			end, { "view.toggleMinimap" })

			reg("editor.toggleWordWrap", "Toggle Word Wrap", "View", "Alt+Z", function()
				config.set("editor.wordWrap", not config.get("editor.wordWrap", false))
			end)

			reg("run.activeFile", "Execute Active Luau Script", "Run", "F5", function()
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
							local created, err = tools.githubSync.createBranch(name)
							if created then overlay.toast("Switched to branch " .. name, "good", 3)
							else overlay.toast("Branch error: " .. tostring(err), "bad", 4) end
						end)
					end,
				})
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
			shortcuts.bind({ key = "RightShift" }, "workbench.toggleWindow", true)
			shortcuts.bind({ key = "F11" }, "window.maximize", true)
			shortcuts.bind({ ctrl = true, shift = true, key = "P" }, "workbench.commandPalette", true)
			shortcuts.bind({ key = "F1" }, "workbench.commandPalette", true)
			shortcuts.bind({ ctrl = true, key = "P" }, "workbench.quickOpen", true)
			shortcuts.bind({ ctrl = true, key = "B" }, "workbench.toggleSideBar", true)
			shortcuts.bind({ ctrl = true, key = "J" }, "workbench.togglePanel", true)
			shortcuts.bind({ ctrl = true, key = "Backquote" }, "workbench.togglePanel", true)
			shortcuts.bind({ ctrl = true, shift = true, key = "E" }, "workbench.viewExplorer", true)
			shortcuts.bind({ ctrl = true, shift = true, key = "F" }, "workbench.viewSearch", true)
			shortcuts.bind({ ctrl = true, shift = true, key = "G" }, "workbench.viewScm", true)
			shortcuts.bind({ ctrl = true, shift = true, key = "D" }, "workbench.viewDebug", true)
			shortcuts.bind({ ctrl = true, shift = true, key = "X" }, "workbench.viewExtensions", true)
			shortcuts.bind({ ctrl = true, key = "Comma" }, "workbench.viewSettings", true)
			shortcuts.bind({ ctrl = true, key = "S" }, "file.save", true)
			shortcuts.bind({ ctrl = true, shift = true, key = "S" }, "file.saveAll", true)
			shortcuts.bind({ ctrl = true, key = "N" }, "file.newUntitled", true)
			shortcuts.bind({ ctrl = true, key = "W" }, "file.closeTab", true)
			shortcuts.bind({ ctrl = true, key = "F" }, "editor.find", true)
			shortcuts.bind({ ctrl = true, key = "H" }, "editor.replace", true)
			shortcuts.bind({ ctrl = true, key = "G" }, "editor.gotoLine", true)
			shortcuts.bind({ shift = true, alt = true, key = "F" }, "editor.format", true)
			shortcuts.bind({ ctrl = true, key = "Backslash" }, "editor.toggleSplit", true)
			shortcuts.bind({ alt = true, key = "Z" }, "editor.toggleWordWrap", true)
			shortcuts.bind({ key = "F5" }, "run.activeFile", true)
			shortcuts.install()
		end

		registerCommands()
		bindShortcuts()

		-- Open starter files from disk workspace
		if workspaceFs.exists("README.md") then
			codeStore.openFile("README.md")
		end
		if workspaceFs.exists("src/main.luau") then
			codeStore.openFile("src/main.luau")
		elseif workspaceFs.exists("src/init.luau") then
			codeStore.openFile("src/init.luau")
		end

		selectViewlet(activeViewlet, false)
		reflowWorkbench()

		theme.changed:connect(function()
			workbenchBody.BackgroundColor3 = theme.color.editor
			sideBarFrame.BackgroundColor3 = theme.color.sideBar
			sideRightBorder.BackgroundColor3 = theme.color.border
			mainArea.BackgroundColor3 = theme.color.editor
			editorsRegion.BackgroundColor3 = theme.color.editor
			primaryGroup.BackgroundColor3 = theme.color.editor
			secondaryGroup.BackgroundColor3 = theme.color.editor
			splitLeftRule.BackgroundColor3 = theme.color.border
			panelHolder.BackgroundColor3 = theme.color.panelBg
		end)

		bootProgress.update("ready", "VS-RBLX Workbench ready.")
		if splash then splash.close() end

		return {
			screenGui = screenGui,
			window = win,
			palette = palette,
			primaryEditor = primaryEditor,
			secondaryEditor = secondaryEditor,
			terminal = bottomTerminal,
			selectViewlet = selectViewlet,
		}
	end

	return M
end
end)()

-- [ui/boot] (2688 bytes)
__VSRBLX_MODULES["ui/boot"] = (function()
-- Brief VS Code startup splash card shown while modules & disk workspace initialise.
return function(env)
	local caps = env.require("runtime/caps")
	local M = {}

	function M.show()
		local parentGui = nil
		if caps.fn.gethui then
			local ok, hui = pcall(caps.fn.gethui)
			if ok and hui then parentGui = hui end
		end
		if not parentGui then parentGui = env.services.CoreGui end
		if not parentGui and env.plr then parentGui = env.plr:FindFirstChild("PlayerGui") end
		if not parentGui then return nil end

		local sg = Instance.new("ScreenGui")
		sg.Name = "VSRBLX_Boot"
		sg.IgnoreGuiInset = true
		sg.DisplayOrder = 999
		local ok = pcall(function() sg.Parent = parentGui end)
		if not ok and env.plr and env.plr:FindFirstChild("PlayerGui") then
			pcall(function() sg.Parent = env.plr.PlayerGui end)
		end

		local card = Instance.new("Frame", sg)
		card.Size = UDim2.fromOffset(290, 74)
		card.Position = UDim2.fromScale(0.5, 0.5)
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		card.BorderSizePixel = 0
		local corner = Instance.new("UICorner", card)
		corner.CornerRadius = UDim.new(0, 6)
		local stroke = Instance.new("UIStroke", card)
		stroke.Color = Color3.fromRGB(0, 122, 204)
		stroke.Thickness = 1

		local title = Instance.new("TextLabel", card)
		title.Size = UDim2.new(1, -24, 0, 22)
		title.Position = UDim2.fromOffset(12, 12)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.SourceSansBold
		title.TextSize = 15
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = "VS-RBLX · Visual Studio Code"

		local detail = Instance.new("TextLabel", card)
		detail.Size = UDim2.new(1, -24, 0, 18)
		detail.Position = UDim2.fromOffset(12, 36)
		detail.BackgroundTransparency = 1
		detail.Font = Enum.Font.SourceSans
		detail.TextSize = 12
		detail.TextColor3 = Color3.fromRGB(160, 160, 160)
		detail.TextXAlignment = Enum.TextXAlignment.Left
		detail.Text = "Mounting workbench..."

		local barBg = Instance.new("Frame", card)
		barBg.Size = UDim2.new(1, -24, 0, 3)
		barBg.Position = UDim2.fromOffset(12, 58)
		barBg.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
		barBg.BorderSizePixel = 0

		local barFill = Instance.new("Frame", barBg)
		barFill.Size = UDim2.new(0.25, 0, 1, 0)
		barFill.BackgroundColor3 = Color3.fromRGB(0, 122, 204)
		barFill.BorderSizePixel = 0

		return {
			step = function(stageText, ratio)
				detail.Text = tostring(stageText or "")
				barFill.Size = UDim2.new(math.max(0.1, math.min(1, tonumber(ratio) or 0.5)), 0, 1, 0)
			end,
			close = function()
				pcall(function() sg:Destroy() end)
			end,
		}
	end

	return M
end
end)()

-- [ui/brand] (1454 bytes)
__VSRBLX_MODULES["ui/brand"] = (function()
-- Geometric Visual Studio Code blue ribbon icon drawn purely with Roblox Frames.
return function(env)
	local P = env.require("ui/primitives")
	local M = {}

	function M.draw(parent, size, zIndex)
		local sz = size or 18
		local z = zIndex or 5
		local holder = P.frame(parent, {
			name = "VSCodeBrand",
			size = UDim2.fromOffset(sz, sz),
			zIndex = z,
		})

		local blueMain = Color3.fromRGB(0, 122, 204)
		local blueBright = Color3.fromRGB(36, 175, 255)
		local blueDark = Color3.fromRGB(0, 95, 168)

		local rightPillar = P.frame(holder, {
			name = "RightPillar",
			size = UDim2.fromOffset(math.max(3, math.floor(sz * 0.24)), math.floor(sz * 0.84)),
			pos = UDim2.fromOffset(math.floor(sz * 0.68), math.floor(sz * 0.08)),
			bg = blueBright,
			radius = 1,
			zIndex = z + 2,
		})
		rightPillar.Active = false

		local diagDown = P.frame(holder, {
			name = "RibbonDown",
			size = UDim2.fromOffset(math.floor(sz * 0.78), math.max(2, math.floor(sz * 0.18))),
			pos = UDim2.fromOffset(math.floor(sz * 0.08), math.floor(sz * 0.42)),
			bg = blueMain,
			radius = 1,
			zIndex = z + 1,
		})
		diagDown.Rotation = 34

		local diagUp = P.frame(holder, {
			name = "RibbonUp",
			size = UDim2.fromOffset(math.floor(sz * 0.78), math.max(2, math.floor(sz * 0.18))),
			pos = UDim2.fromOffset(math.floor(sz * 0.08), math.floor(sz * 0.40)),
			bg = blueDark,
			radius = 1,
			zIndex = z,
		})
		diagUp.Rotation = -34

		return holder
	end

	return M
end
end)()

-- [ui/code/breadcrumbs] (2842 bytes)
__VSRBLX_MODULES["ui/code/breadcrumbs"] = (function()
-- VS Code Path & Symbol Breadcrumbs bar above the editor viewport.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local overlay = env.require("ui/overlay")
	local util = env.require("runtime/util")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")
	local codeFolding = env.require("runtime/code_folding")

	local M = {}

	function M.new(parent, paneName)
		local pane = paneName or "primary"
		local h = theme.sizes.breadcrumbs

		local bar = P.frame(parent, {
			name = "Breadcrumbs_" .. pane,
			size = UDim2.new(1, 0, 0, h),
			pos = UDim2.fromOffset(0, theme.sizes.tabBar),
			bg = theme.color.breadcrumbBg,
			zIndex = 19,
		})
		local rule = P.frame(bar, {
			size = UDim2.new(1, 0, 0, 1),
			pos = UDim2.new(0, 0, 1, -1),
			bg = theme.color.border,
			zIndex = 20,
		})

		local pathBtn = P.button(bar, {
			name = "BreadcrumbTrail",
			size = UDim2.new(1, -16, 1, 0),
			pos = UDim2.fromOffset(8, 0),
			alignX = Enum.TextXAlignment.Left,
			text = "",
			textSize = 11,
			color = theme.color.muted,
			zIndex = 20,
		})

		local function refresh()
			local doc = codeStore.active(pane)
			if not doc then
				pathBtn.Text = workspaceFs.activeName .. "  ›  (no file open)"
				return
			end
			local segments = { workspaceFs.activeName }
			for _, seg in ipairs(util.split(doc.path ~= "" and doc.path or doc.title, "/")) do
				if seg ~= "" then segments[#segments + 1] = seg end
			end
			local syms = codeFolding.symbols(doc.content, doc.langId)
			local curLine = doc.view.line or 1
			local currentSym = nil
			for _, sym in ipairs(syms) do
				if sym.line <= curLine then currentSym = sym end
			end
			if currentSym then
				segments[#segments + 1] = "ƒ " .. currentSym.name
			end
			pathBtn.Text = table.concat(segments, "  ›  ")
		end

		pathBtn.Activated:Connect(function()
			local doc = codeStore.active(pane)
			if not doc then return end
			local syms = codeFolding.symbols(doc.content, doc.langId)
			if #syms == 0 then return end
			local menu = {}
			for _, s in ipairs(syms) do
				local targetLn = s.line
				menu[#menu + 1] = {
					label = string.format("%s (%s)", s.name, s.kind),
					shortcut = "Ln " .. tostring(s.line),
					onClick = function() codeStore.jumpToLine(doc.id, targetLn, 1) end,
				}
			end
			local p = pathBtn.AbsolutePosition
			overlay.dropdown(p.X + 80, p.Y + h, menu, 240)
		end)

		codeStore.changed:connect(refresh)
		codeStore.cursorChanged:connect(refresh)
		workspaceFs.changed:connect(refresh)
		theme.changed:connect(function()
			bar.BackgroundColor3 = theme.color.breadcrumbBg
			rule.BackgroundColor3 = theme.color.border
			pathBtn.TextColor3 = theme.color.muted
		end)

		refresh()
		return {
			root = bar,
			refresh = refresh,
		}
	end

	return M
end
end)()

-- [ui/code/diff_view] (2758 bytes)
__VSRBLX_MODULES["ui/code/diff_view"] = (function()
-- Colorized Git Unified Diff Viewer for VS-RBLX Source Control changes.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local codeDiff = env.require("runtime/code_diff")

	local M = {}

	function M.new(parent)
		local root = P.frame(parent, {
			name = "DiffViewer",
			size = UDim2.fromScale(1, 1),
			bg = theme.color.editor,
			visible = false,
			zIndex = 15,
		})

		local summaryBar = P.frame(root, {
			name = "DiffSummary",
			size = UDim2.new(1, 0, 0, 26),
			bg = theme.color.sideBarHeader,
			zIndex = 16,
		})
		local summaryLbl = P.label(summaryBar, {
			size = UDim2.new(1, -16, 1, 0),
			pos = UDim2.fromOffset(10, 0),
			text = "Working Tree Diff",
			mono = true,
			textSize = 12,
			color = theme.color.tabActiveText,
			zIndex = 17,
		})

		local scroll = P.scroll(root, {
			name = "DiffScroll",
			size = UDim2.new(1, 0, 1, -26),
			pos = UDim2.fromOffset(0, 26),
			bg = theme.color.editor,
			zIndex = 16,
		})
		P.list(scroll, Enum.FillDirection.Vertical, 0)

		local function render(doc)
			scroll:ClearAllChildren()
			P.list(scroll, Enum.FillDirection.Vertical, 0)
			if not doc then return end
			local result = codeDiff.compute(doc.diffOld or "", doc.diffNew or "")
			summaryLbl.Text = string.format("%s   (+%d added, -%d removed)", doc.path, result.added, result.removed)

			local maxRows = math.min(#result.rows, 450)
			for i = 1, maxRows do
				local r = result.rows[i]
				local rowBg = nil
				local prefix = "  "
				local txtCol = theme.color.editorText
				if r.kind == "add" then
					rowBg = theme.color.diffAddBg
					prefix = "+ "
					txtCol = theme.color.good
				elseif r.kind == "remove" then
					rowBg = theme.color.diffRemoveBg
					prefix = "- "
					txtCol = theme.color.bad
				end

				local row = P.frame(scroll, {
					size = UDim2.new(1, 0, 0, 19),
					bg = rowBg,
					order = i,
					zIndex = 17,
				})
				local lnNum = string.format("%4s %4s", r.oldLine and tostring(r.oldLine) or "", r.newLine and tostring(r.newLine) or "")
				P.label(row, {
					size = UDim2.fromOffset(72, 19),
					pos = UDim2.fromOffset(4, 0),
					text = lnNum,
					mono = true,
					textSize = 12,
					color = theme.color.lineNumber,
					zIndex = 18,
				})
				P.label(row, {
					size = UDim2.new(1, -84, 1, 0),
					pos = UDim2.fromOffset(80, 0),
					text = prefix .. tostring(r.text or ""),
					mono = true,
					textSize = 13,
					color = txtCol,
					zIndex = 18,
				})
			end
		end

		theme.changed:connect(function()
			root.BackgroundColor3 = theme.color.editor
			summaryBar.BackgroundColor3 = theme.color.sideBarHeader
			scroll.BackgroundColor3 = theme.color.editor
		end)

		return {
			root = root,
			render = render,
		}
	end

	return M
end
end)()

-- [ui/code/editor] (19342 bytes)
__VSRBLX_MODULES["ui/code/editor"] = (function()
-- Full VS Code RichText Multi-Language Editor with Gutter, Active Line, Diagnostics,
-- Inline Find & Replace (`Ctrl+F`/`Ctrl+H`), IntelliSense Popup, Minimap, Diff View, & Welcome.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local minimapMod = env.require("ui/code/minimap")
	local diffViewMod = env.require("ui/code/diff_view")
	local welcomeMod = env.require("ui/code/welcome")
	local util = env.require("runtime/util")
	local config = env.require("runtime/config")
	local clock = env.require("runtime/clock")
	local codeStore = env.require("runtime/code_store")
	local codeLexer = env.require("runtime/code_lexer")
	local codeSearch = env.require("runtime/code_search")
	local intellisense = env.require("runtime/intellisense")
	local diagnostics = env.require("runtime/diagnostics")

	local M = {}

	function M.new(parent, paneName)
		local pane = paneName or "primary"
		local gutterW = 50

		local container = P.frame(parent, {
			name = "EditorGroup_" .. pane,
			size = UDim2.fromScale(1, 1),
			bg = theme.color.editor,
			clip = true,
			zIndex = 12,
		})

		local welcome = welcomeMod.new(container)
		local diffViewer = diffViewMod.new(container)

		local codeSurface = P.frame(container, {
			name = "CodeSurface",
			size = UDim2.fromScale(1, 1),
			bg = theme.color.editor,
			clip = true,
			zIndex = 13,
		})

		local scroll = P.scroll(codeSurface, {
			name = "EditorScroll",
			size = UDim2.new(1, -72, 1, 0),
			bg = theme.color.editor,
			direction = Enum.ScrollingDirection.XY,
			autoCanvas = Enum.AutomaticSize.None,
			barThickness = 8,
			zIndex = 14,
		})

		local activeLineHighlight = P.frame(scroll, {
			name = "ActiveLineHighlight",
			size = UDim2.new(1, 0, 0, 20),
			pos = UDim2.fromOffset(0, 6),
			bg = theme.color.activeLine,
			zIndex = 14,
		})

		local gutter = P.frame(scroll, {
			name = "EditorGutter",
			size = UDim2.new(0, gutterW, 1, 0),
			bg = theme.color.editorGutter,
			zIndex = 16,
		})
		local gutterBorder = P.frame(gutter, {
			size = UDim2.new(0, 1, 1, 0),
			pos = UDim2.new(1, -1, 0, 0),
			bg = theme.color.border,
			transparency = 0.55,
			zIndex = 17,
		})

		local presentationLayer = P.frame(scroll, {
			name = "SyntaxLayer",
			size = UDim2.new(1, -gutterW, 1, 0),
			pos = UDim2.fromOffset(gutterW + 8, 6),
			zIndex = 16,
		})

		local box = Instance.new("TextBox", scroll)
		box.Name = "SourceTextBox"
		box.BorderSizePixel = 0
		box.BackgroundTransparency = 1
		box.Position = UDim2.fromOffset(gutterW + 8, 6)
		box.Size = UDim2.fromOffset(800, 600)
		box.MultiLine = true
		box.ClearTextOnFocus = false
		box.RichText = false
		box.TextWrapped = false
		box.Font = theme.font.mono
		box.TextSize = theme.sizes.editorFont
		box.LineHeight = theme.sizes.editorLineHeight / math.max(1, theme.sizes.editorFont)
		box.TextColor3 = theme.color.editorText
		box.TextTransparency = 1
		box.TextXAlignment = Enum.TextXAlignment.Left
		box.TextYAlignment = Enum.TextYAlignment.Top
		box.Text = ""
		box.ZIndex = 17

		local caretBar = P.frame(scroll, {
			name = "EditorCaret",
			size = UDim2.fromOffset(2, theme.sizes.editorLineHeight),
			pos = UDim2.fromOffset(gutterW + 8, 6),
			bg = theme.color.tabActiveText,
			visible = false,
			zIndex = 18,
		})

		-- Minimap
		local minimap = minimapMod.new(codeSurface, function(ratio)
			local maxScroll = math.max(0, scroll.CanvasSize.Y.Offset - scroll.AbsoluteSize.Y)
			scroll.CanvasPosition = Vector2.new(scroll.CanvasPosition.X, math.floor(maxScroll * ratio))
		end)

		-- Inline Find & Replace Bar (`Ctrl+F` / `Ctrl+H`)
		local findCard = P.frame(codeSurface, {
			name = "FindReplaceWidget",
			size = UDim2.fromOffset(336, 68),
			pos = UDim2.new(1, -418, 0, 6),
			bg = theme.color.sideBar,
			radius = 5,
			border = theme.color.border,
			visible = false,
			active = true,
			zIndex = 40,
		})
		P.pad(findCard, 6, 8, 6, 8)

		local _, findInput = P.input(findCard, {
			name = "FindInput",
			size = UDim2.fromOffset(170, 24),
			placeholder = "Find",
			zIndex = 41,
		})
		local matchCounter = P.label(findCard, {
			size = UDim2.fromOffset(62, 24),
			pos = UDim2.fromOffset(176, 0),
			text = "0/0",
			textSize = 11,
			color = theme.color.muted,
			zIndex = 41,
		})
		P.button(findCard, {
			name = "FindNextBtn",
			size = UDim2.fromOffset(24, 24),
			pos = UDim2.fromOffset(240, 0),
			text = "↓",
			radius = 3,
			zIndex = 41,
			onClick = function() end,
		})
		local findNextBtn = findCard:FindFirstChild("FindNextBtn")
		local closeFindBtn = P.button(findCard, {
			name = "CloseFindBtn",
			size = UDim2.fromOffset(24, 24),
			pos = UDim2.fromOffset(296, 0),
			text = "✕",
			radius = 3,
			zIndex = 41,
			onClick = function() findCard.Visible = false end,
		})
		closeFindBtn.Active = true

		local _, replaceInput = P.input(findCard, {
			name = "ReplaceInput",
			size = UDim2.fromOffset(170, 24),
			pos = UDim2.fromOffset(0, 30),
			placeholder = "Replace",
			zIndex = 41,
		})
		local replaceOneBtn = P.button(findCard, {
			name = "ReplaceOneBtn",
			size = UDim2.fromOffset(64, 24),
			pos = UDim2.fromOffset(176, 30),
			bg = theme.color.inputBg,
			text = "Replace",
			textSize = 11,
			radius = 3,
			zIndex = 41,
		})
		local replaceAllBtn = P.button(findCard, {
			name = "ReplaceAllBtn",
			size = UDim2.fromOffset(74, 24),
			pos = UDim2.fromOffset(244, 30),
			bg = theme.color.accent,
			color = Color3.fromRGB(255, 255, 255),
			text = "Replace All",
			textSize = 11,
			radius = 3,
			zIndex = 41,
		})

		-- IntelliSense popup
		local suggestCard = P.frame(codeSurface, {
			name = "IntelliSensePopup",
			size = UDim2.fromOffset(290, 140),
			pos = UDim2.fromOffset(70, 44),
			bg = theme.color.dropdownBg,
			radius = 4,
			border = theme.color.accent,
			visible = false,
			active = true,
			zIndex = 45,
		})
		P.pad(suggestCard, 4, 4, 4, 4)
		P.list(suggestCard, Enum.FillDirection.Vertical, 1)

		-- State & pools
		local currentDoc = nil
		local lexCache = nil
		local syncingText = false
		local isFocused = false
		local linePool = {}
		local numPool = {}
		local diagDotPool = {}
		local findMatches = {}
		local findIndex = 0
		local currentSuggestions = {}
		local suggestSpanStart, suggestSpanEnd = 1, 0

		local debouncedDiag = clock.debounce(0.3, function()
			if currentDoc then
				diagnostics.check(currentDoc)
			end
		end)

		local function updateLayoutWidths()
			local showMini = config.get("editor.minimap", true) == true
			minimap.root.Visible = showMini
			scroll.Size = UDim2.new(1, showMini and -minimap.width or 0, 1, 0)
			gutter.Visible = config.get("editor.lineNumbers", true) ~= false
			local effGutter = gutter.Visible and gutterW or 8
			presentationLayer.Position = UDim2.fromOffset(effGutter + 8, 6)
			box.Position = UDim2.fromOffset(effGutter + 8, 6)
		end

		local function ensureRowWidgets(slot)
			if not linePool[slot] then
				linePool[slot] = P.label(presentationLayer, {
					name = "CodeLine_" .. tostring(slot),
					size = UDim2.new(1, 0, 0, theme.sizes.editorLineHeight),
					mono = true,
					rich = true,
					textSize = theme.sizes.editorFont,
					color = theme.color.editorText,
					zIndex = 16,
				})
				numPool[slot] = P.label(gutter, {
					name = "LineNum_" .. tostring(slot),
					size = UDim2.fromOffset(gutterW - 10, theme.sizes.editorLineHeight),
					mono = true,
					textSize = math.max(11, theme.sizes.editorFont - 1),
					color = theme.color.lineNumber,
					alignX = Enum.TextXAlignment.Right,
					zIndex = 17,
				})
				diagDotPool[slot] = P.frame(gutter, {
					name = "DiagDot_" .. tostring(slot),
					size = UDim2.fromOffset(5, 5),
					bg = theme.color.bad,
					radius = 3,
					visible = false,
					zIndex = 18,
				})
			end
			return linePool[slot], numPool[slot], diagDotPool[slot]
		end

		local function drawVisibleLines()
			if not currentDoc or not lexCache then return end
			local lh = theme.sizes.editorLineHeight
			local fontSz = theme.sizes.editorFont
			box.Font = theme.font.mono
			box.TextSize = fontSz
			box.LineHeight = lh / math.max(1, fontSz)
			box.TextWrapped = config.get("editor.wordWrap", false) == true

			local totalLines = #lexCache.lines
			local maxChars = 40
			for i = 1, totalLines do
				if #lexCache.lines[i] > maxChars then maxChars = #lexCache.lines[i] end
			end
			local charPx = math.ceil(fontSz * 0.62)
			local contentW = math.max(scroll.AbsoluteSize.X, gutterW + maxChars * charPx + 80)
			local contentH = math.max(scroll.AbsoluteSize.Y, totalLines * lh + 64)

			scroll.CanvasSize = UDim2.fromOffset(contentW, contentH)
			box.Size = UDim2.fromOffset(contentW - gutterW - 12, contentH - 12)
			gutter.Size = UDim2.fromOffset(gutterW, contentH)
			presentationLayer.Size = UDim2.fromOffset(contentW - gutterW - 12, contentH - 12)

			local scrollY = scroll.CanvasPosition.Y
			local viewH = math.max(240, scroll.AbsoluteSize.Y)
			local firstVisible = math.max(1, math.floor(scrollY / lh) - 2)
			local lastVisible = math.min(totalLines, firstVisible + math.ceil(viewH / lh) + 6)

			local diagMap = {}
			for _, d in ipairs(diagnostics.byDoc[currentDoc.id] or {}) do
				diagMap[d.line] = d.severity
			end

			local curLine = currentDoc.view.line or 1
			activeLineHighlight.Visible = config.get("editor.renderActiveLine", true) ~= false
			activeLineHighlight.Position = UDim2.fromOffset(0, 6 + (curLine - 1) * lh)
			activeLineHighlight.Size = UDim2.fromOffset(contentW, lh)
			activeLineHighlight.BackgroundColor3 = theme.color.activeLine

			local hasSelection = isFocused and box.SelectionStart > 0 and box.CursorPosition > 0 and box.SelectionStart ~= box.CursorPosition
			box.TextTransparency = hasSelection and 0 or 1
			box.TextColor3 = theme.color.editorText

			local slot = 0
			for ln = firstVisible, lastVisible do
				slot = slot + 1
				local codeLbl, numLbl, dot = ensureRowWidgets(slot)
				codeLbl.Visible = not hasSelection
				codeLbl.Position = UDim2.fromOffset(0, (ln - 1) * lh)
				codeLbl.Size = UDim2.fromOffset(contentW - gutterW - 16, lh)
				codeLbl.TextSize = fontSz
				codeLbl.TextColor3 = theme.color.editorText
				codeLbl.Text = codeLexer.rich(lexCache.lines[ln], lexCache.spans[ln], theme.syntax)

				numLbl.Visible = true
				numLbl.Position = UDim2.fromOffset(4, 6 + (ln - 1) * lh)
				numLbl.Size = UDim2.fromOffset(gutterW - 12, lh)
				numLbl.TextSize = math.max(11, fontSz - 1)
				numLbl.Text = tostring(ln)
				numLbl.TextColor3 = (ln == curLine) and theme.color.lineNumberActive or theme.color.lineNumber

				local sev = diagMap[ln]
				if sev then
					dot.Visible = true
					dot.Position = UDim2.fromOffset(3, 6 + (ln - 1) * lh + math.floor((lh - 5) / 2))
					dot.BackgroundColor3 = (sev == "error") and theme.color.bad or theme.color.warn
				else
					dot.Visible = false
				end
			end

			for k = slot + 1, #linePool do
				linePool[k].Visible = false
				numPool[k].Visible = false
				diagDotPool[k].Visible = false
			end

			-- Update Caret position
			if isFocused and not hasSelection and currentDoc and not currentDoc.readOnly then
				local col = math.max(1, currentDoc.view.col or 1)
				local lineStr = lexCache.lines[curLine] or ""
				local subBefore = lineStr:sub(1, col - 1):gsub("\t", "    ")
				local effGutter = gutter.Visible and gutterW or 8
				local xPx = effGutter + 8 + math.floor(#subBefore * (fontSz * 0.6))
				local yPx = 6 + (curLine - 1) * lh
				caretBar.Position = UDim2.fromOffset(xPx, yPx)
				caretBar.Size = UDim2.fromOffset(2, lh)
				caretBar.Visible = true
			else
				caretBar.Visible = false
			end

			minimap.updateViewport(scrollY, viewH, contentH)
		end

		local function acceptSuggestion(item)
			if not currentDoc or not item then return end
			suggestCard.Visible = false
			local src = box.Text
			local before = src:sub(1, suggestSpanStart - 1)
			local after = src:sub(suggestSpanEnd + 1)
			local nextText = before .. item.insert .. after
			syncingText = true
			box.Text = nextText
			local newCursor = #before + #item.insert + 1
			box.CursorPosition = newCursor
			syncingText = false
			codeStore.updateContent(currentDoc.id, nextText)
			codeStore.setCursor(currentDoc.id, newCursor, -1)
		end

		local function refreshIntelliSense()
			if not isFocused or not currentDoc or currentDoc.readOnly
				or config.get("editor.intellisense", true) == false then
				suggestCard.Visible = false
				return
			end
			local items, _, sIdx, eIdx = intellisense.suggest(box.Text, box.CursorPosition, currentDoc.langId, 6)
			currentSuggestions = items
			suggestSpanStart, suggestSpanEnd = sIdx, eIdx
			if #items == 0 then
				suggestCard.Visible = false
				return
			end

			suggestCard:ClearAllChildren()
			P.pad(suggestCard, 4, 4, 4, 4)
			P.list(suggestCard, Enum.FillDirection.Vertical, 1)
			suggestCard.Size = UDim2.fromOffset(300, #items * 23 + 10)

			local lh = theme.sizes.editorLineHeight
			local curLine = currentDoc.view.line or 1
			local relY = util.clamp(10 + curLine * lh - scroll.CanvasPosition.Y, 28, math.max(30, codeSurface.AbsoluteSize.Y - 160))
			suggestCard.Position = UDim2.fromOffset(gutterW + 24, relY)
			suggestCard.Visible = true

			for idx, sug in ipairs(items) do
				local row = P.button(suggestCard, {
					name = "Suggest_" .. tostring(idx),
					size = UDim2.new(1, 0, 0, 22),
					bg = idx == 1 and theme.color.listActive or nil,
					hoverBg = theme.color.listActive,
					text = "",
					radius = 3,
					order = idx,
					zIndex = 46,
					onClick = function() acceptSuggestion(sug) end,
				})
				P.label(row, {
					size = UDim2.new(1, -90, 1, 0),
					pos = UDim2.fromOffset(6, 0),
					text = sug.label,
					mono = true,
					textSize = 12,
					color = theme.color.tabActiveText,
					truncate = true,
					zIndex = 47,
				})
				P.label(row, {
					size = UDim2.fromOffset(82, 22),
					pos = UDim2.new(1, -86, 0, 0),
					text = sug.detail,
					textSize = 10,
					color = theme.color.muted,
					alignX = Enum.TextXAlignment.Right,
					zIndex = 47,
				})
			end
		end

		local function mountDoc(doc)
			currentDoc = doc
			suggestCard.Visible = false
			if not doc then
				codeSurface.Visible = false
				diffViewer.root.Visible = false
				welcome.root.Visible = true
				welcome.refresh()
				return
			end
			if doc.isDiff then
				welcome.root.Visible = false
				codeSurface.Visible = false
				diffViewer.root.Visible = true
				diffViewer.render(doc)
				return
			end

			welcome.root.Visible = false
			diffViewer.root.Visible = false
			codeSurface.Visible = true

			box.TextEditable = not doc.readOnly
			if box.Text ~= doc.content then
				syncingText = true
				box.Text = doc.content
				syncingText = false
			end
			lexCache = codeLexer.scan(doc.content, doc.langId, lexCache)
			minimap.updateSource(lexCache)
			debouncedDiag.call()
			updateLayoutWidths()
			drawVisibleLines()
			if doc.view.scrollY then
				scroll.CanvasPosition = Vector2.new(doc.view.scrollX or 0, doc.view.scrollY or 0)
			end
		end

		box.Focused:Connect(function()
			isFocused = true
			codeStore.focusedPane = pane
			drawVisibleLines()
		end)

		box.FocusLost:Connect(function()
			isFocused = false
			task.delay(0.15, function()
				if not isFocused then suggestCard.Visible = false end
			end)
			drawVisibleLines()
		end)

		box:GetPropertyChangedSignal("Text"):Connect(function()
			if syncingText or not currentDoc or currentDoc.readOnly then return end
			local raw = box.Text
			if raw:find("\t", 1, true) and config.get("editor.insertSpaces", true) then
				-- Keep literal tabs in existing files unless typed at cursor, handled cleanly
			end
			codeStore.updateContent(currentDoc.id, raw)
			lexCache = codeLexer.scan(currentDoc.content, currentDoc.langId, lexCache)
			minimap.updateSource(lexCache)
			codeStore.setCursor(currentDoc.id, box.CursorPosition, box.SelectionStart)
			debouncedDiag.call()
			drawVisibleLines()
			refreshIntelliSense()
		end)

		box:GetPropertyChangedSignal("CursorPosition"):Connect(function()
			if syncingText or not currentDoc then return end
			codeStore.setCursor(currentDoc.id, box.CursorPosition, box.SelectionStart)
			drawVisibleLines()
		end)

		box:GetPropertyChangedSignal("SelectionStart"):Connect(function()
			if syncingText or not currentDoc then return end
			drawVisibleLines()
		end)

		scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			if currentDoc then
				currentDoc.view.scrollX = scroll.CanvasPosition.X
				currentDoc.view.scrollY = scroll.CanvasPosition.Y
			end
			drawVisibleLines()
		end)

		-- Find & Replace handlers
		local function runFind()
			if not currentDoc then return end
			findMatches = codeSearch.findInText(currentDoc.content, findInput.Text, {})
			if #findMatches == 0 then
				findIndex = 0
				matchCounter.Text = "0/0"
			else
				findIndex = ((findIndex) % #findMatches) + 1
				matchCounter.Text = string.format("%d/%d", findIndex, #findMatches)
				local hit = findMatches[findIndex]
				codeStore.jumpToLine(currentDoc.id, hit.line, hit.col)
			end
		end

		findInput:GetPropertyChangedSignal("Text"):Connect(function()
			findIndex = 0
			runFind()
		end)
		findNextBtn.Activated:Connect(runFind)

		replaceOneBtn.Activated:Connect(function()
			if not currentDoc or findInput.Text == "" then return end
			local updated, count = codeSearch.replaceInText(currentDoc.content, findInput.Text, replaceInput.Text, {
				singleIndex = math.max(1, findIndex),
			})
			if count > 0 then
				codeStore.updateContent(currentDoc.id, updated)
				mountDoc(currentDoc)
				runFind()
			end
		end)

		replaceAllBtn.Activated:Connect(function()
			if not currentDoc or findInput.Text == "" then return end
			local updated, count = codeSearch.replaceInText(currentDoc.content, findInput.Text, replaceInput.Text, {})
			if count > 0 then
				codeStore.updateContent(currentDoc.id, updated)
				mountDoc(currentDoc)
				runFind()
			end
		end)

		codeStore.changed:connect(function()
			mountDoc(codeStore.active(pane))
		end)
		diagnostics.changed:connect(function(docId)
			if currentDoc and currentDoc.id == docId then
				drawVisibleLines()
			end
		end)
		config.changed:connect(function()
			updateLayoutWidths()
			drawVisibleLines()
		end)
		theme.changed:connect(function()
			container.BackgroundColor3 = theme.color.editor
			codeSurface.BackgroundColor3 = theme.color.editor
			scroll.BackgroundColor3 = theme.color.editor
			gutter.BackgroundColor3 = theme.color.editorGutter
			gutterBorder.BackgroundColor3 = theme.color.border
			findCard.BackgroundColor3 = theme.color.sideBar
			suggestCard.BackgroundColor3 = theme.color.dropdownBg
			drawVisibleLines()
		end)

		mountDoc(codeStore.active(pane))

		return {
			root = container,
			box = box,
			openFind = function(showReplace)
				findCard.Visible = true
				findCard.Size = UDim2.fromOffset(336, showReplace and 68 or 36)
				replaceInput.Parent.Visible = showReplace == true
				replaceOneBtn.Visible = showReplace == true
				replaceAllBtn.Visible = showReplace == true
				task.defer(function() pcall(function() findInput:CaptureFocus() end) end)
			end,
			acceptTopSuggestion = function()
				if suggestCard.Visible and currentSuggestions[1] then
					acceptSuggestion(currentSuggestions[1])
					return true
				end
				return false
			end,
			refresh = function()
				mountDoc(codeStore.active(pane))
			end,
		}
	end

	return M
end
end)()

-- [ui/code/explorer] (5897 bytes)
__VSRBLX_MODULES["ui/code/explorer"] = (function()
-- Collapsible hierarchical File Tree widget with language icons and right-click disk actions.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local icons = env.require("ui/icons")
	local overlay = env.require("ui/overlay")
	local util = env.require("runtime/util")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")

	local M = {}

	function M.new(parent)
		local expanded = { [""] = true, ["src"] = true, ["web"] = true, ["scripts"] = true }
		local holder = P.frame(parent, {
			name = "FileTreeContainer",
			size = UDim2.new(1, 0, 0, 200),
			zIndex = 22,
		})
		holder.AutomaticSize = Enum.AutomaticSize.Y
		P.list(holder, Enum.FillDirection.Vertical, 1)

		local rebuild

		local function promptCreate(baseDir, isFolder)
			local pfx = baseDir ~= "" and (baseDir .. "/") or ""
			overlay.prompt({
				title = isFolder and "New Folder on Local Disk" or "New File on Local Disk",
				subtitle = "Workspace: " .. workspaceFs.diskRootLabel(),
				default = pfx,
				placeholder = pfx .. (isFolder and "folder_name" or "script.luau"),
				mono = true,
				confirmText = "Create",
				onConfirm = function(val)
					local clean = util.normalisePath(val)
					if clean == "" then return end
					if isFolder then
						local ok, err = workspaceFs.createFolder(clean)
						if ok then
							expanded[clean] = true
							overlay.toast("Created folder: " .. clean, "good", 2.5)
						else
							overlay.toast("Error: " .. tostring(err), "bad", 4)
						end
					else
						local ok, err = workspaceFs.writeFile(clean, "")
						if ok then
							codeStore.openFile(clean, { reloadFromDisk = true })
							overlay.toast("Created file on disk: " .. clean, "good", 2.5)
						else
							overlay.toast("Error: " .. tostring(err), "bad", 4)
						end
					end
				end,
			})
		end

		local function promptRename(oldPath)
			overlay.prompt({
				title = "Rename Path on Disk",
				default = oldPath,
				mono = true,
				confirmText = "Rename",
				onConfirm = function(newVal)
					local ok, res = workspaceFs.renamePath(oldPath, newVal)
					if ok then
						local doc = codeStore.findByPath(oldPath)
						if doc then
							codeStore.close(doc.id)
							codeStore.openFile(res)
						end
						overlay.toast("Renamed to " .. tostring(res), "good", 2.5)
					else
						overlay.toast("Rename failed: " .. tostring(res), "bad", 4)
					end
				end,
			})
		end

		rebuild = function()
			holder:ClearAllChildren()
			P.list(holder, Enum.FillDirection.Vertical, 1)
			local activeDoc = codeStore.active()
			local activePath = activeDoc and activeDoc.path or nil
			local orderCounter = 0

			local function renderDir(dirPath, depth)
				if depth > 10 then return end
				local entries = workspaceFs.listDir(dirPath)
				for _, entry in ipairs(entries) do
					orderCounter = orderCounter + 1
					local isSelected = (not entry.isDir) and (entry.path == activePath)
					local row = P.button(holder, {
						name = "Tree_" .. entry.name,
						size = UDim2.new(1, 0, 0, 22),
						bg = isSelected and theme.color.listActive or nil,
						hoverBg = theme.color.hover,
						text = "",
						order = orderCounter,
						zIndex = 23,
						activeState = function() return isSelected end,
						onClick = function()
							if entry.isDir then
								expanded[entry.path] = not expanded[entry.path]
								rebuild()
							else
								codeStore.openFile(entry.path)
							end
						end,
					})

					local indentPx = 8 + depth * 12
					if entry.isDir then
						P.label(row, {
							size = UDim2.fromOffset(12, 22),
							pos = UDim2.fromOffset(indentPx, 0),
							text = expanded[entry.path] and "▾" or "▸",
							textSize = 11,
							color = theme.color.muted,
							zIndex = 24,
						})
					end

					local badge = icons.fileBadge(row, entry.lang, entry.isDir, 24)
					badge.Position = UDim2.fromOffset(indentPx + (entry.isDir and 14 or 4), entry.isDir and 5 or 4)

					local nameX = indentPx + (entry.isDir and 32 or 34)
					P.label(row, {
						size = UDim2.new(1, -(nameX + 8), 1, 0),
						pos = UDim2.fromOffset(nameX, 0),
						text = entry.name,
						textSize = 12,
						color = isSelected and theme.color.tabActiveText or theme.color.sideBarText,
						truncate = true,
						zIndex = 24,
					})

					row.MouseButton2Click:Connect(function()
						local p = row.AbsolutePosition
						local targetDir = entry.isDir and entry.path or util.dirname(entry.path)
						local menu = {
							{ label = "New File Here...", onClick = function() promptCreate(targetDir, false) end },
							{ label = "New Folder Here...", onClick = function() promptCreate(targetDir, true) end },
							{ separator = true },
						}
						if not entry.isDir then
							menu[#menu + 1] = {
								label = "Open to the Side",
								onClick = function() codeStore.openFile(entry.path, { pane = "secondary" }) end,
							}
						end
						menu[#menu + 1] = { label = "Rename...", onClick = function() promptRename(entry.path) end }
						menu[#menu + 1] = {
							label = "Delete from Disk",
							onClick = function()
								workspaceFs.deletePath(entry.path)
								local openDoc = codeStore.findByPath(entry.path)
								if openDoc then codeStore.close(openDoc.id) end
								overlay.toast("Deleted " .. entry.path, "warn", 2.5)
							end,
						}
						overlay.dropdown(p.X + 24, p.Y + 18, menu, 185)
					end)

					if entry.isDir and expanded[entry.path] then
						renderDir(entry.path, depth + 1)
					end
				end
			end

			renderDir("", 0)
		end

		workspaceFs.changed:connect(rebuild)
		codeStore.changed:connect(rebuild)
		theme.changed:connect(rebuild)

		rebuild()
		return {
			root = holder,
			refresh = rebuild,
			promptNewFile = function() promptCreate("", false) end,
			promptNewFolder = function() promptCreate("", true) end,
		}
	end

	return M
end
end)()

-- [ui/code/minimap] (3570 bytes)
__VSRBLX_MODULES["ui/code/minimap"] = (function()
-- VS Code Right-Side Code Minimap with miniature colorized bars and clickable viewport slider.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local util = env.require("runtime/util")

	local M = {}

	function M.new(parent, onJumpRatio)
		local width = 72
		local root = P.frame(parent, {
			name = "Minimap",
			size = UDim2.new(0, width, 1, 0),
			pos = UDim2.new(1, -width, 0, 0),
			bg = theme.color.editor,
			clip = true,
			active = true,
			zIndex = 16,
		})
		local leftRule = P.frame(root, {
			size = UDim2.new(0, 1, 1, 0),
			bg = theme.color.border,
			transparency = 0.5,
			zIndex = 17,
		})

		local canvas = P.frame(root, {
			name = "MiniLines",
			size = UDim2.new(1, -8, 1, -8),
			pos = UDim2.fromOffset(5, 4),
			zIndex = 17,
		})

		local slider = P.frame(root, {
			name = "ViewportSlider",
			size = UDim2.new(1, 0, 0, 44),
			pos = UDim2.fromOffset(0, 0),
			bg = theme.color.selection,
			transparency = 0.65,
			zIndex = 18,
		})

		local bars = {}
		local MAX_BARS = 85

		local function ensureBar(i)
			if not bars[i] then
				bars[i] = P.frame(canvas, {
					size = UDim2.fromOffset(20, 2),
					pos = UDim2.fromOffset(0, (i - 1) * 3),
					bg = theme.color.muted,
					transparency = 0.35,
					zIndex = 17,
				})
			end
			return bars[i]
		end

		local function updateSource(lexScan)
			if not lexScan or not lexScan.lines then return end
			local total = #lexScan.lines
			local step = math.max(1, math.ceil(total / MAX_BARS))
			local idx = 0
			for lineNo = 1, total, step do
				idx = idx + 1
				if idx > MAX_BARS then break end
				local line = lexScan.lines[lineNo] or ""
				local bar = ensureBar(idx)
				local trimmed = util.trim(line)
				if trimmed == "" then
					bar.Visible = false
				else
					bar.Visible = true
					local indent = #(line:match("^(%s*)") or "")
					local w = util.clamp(math.floor(#trimmed * 0.75), 4, width - 14)
					bar.Position = UDim2.fromOffset(util.clamp(indent * 2, 0, 24), (idx - 1) * 3)
					bar.Size = UDim2.fromOffset(w, 2)
					local spans = lexScan.spans[lineNo]
					local firstKind = spans and spans[1] and spans[1].kind or "text"
					local colHex = theme.syntax[firstKind]
					bar.BackgroundColor3 = colHex and Color3.fromHex(colHex) or theme.color.muted
				end
			end
			for k = idx + 1, #bars do
				bars[k].Visible = false
			end
		end

		local function updateViewport(scrollY, viewHeight, contentHeight)
			local h = math.max(1, root.AbsoluteSize.Y)
			local totalH = math.max(contentHeight, viewHeight, 1)
			local fracH = util.clamp(viewHeight / totalH, 0.08, 1)
			local fracY = util.clamp(scrollY / math.max(1, totalH - viewHeight), 0, 1)
			local sliderH = math.floor(h * fracH)
			local sliderY = math.floor((h - sliderH) * fracY)
			slider.Size = UDim2.new(1, 0, 0, sliderH)
			slider.Position = UDim2.fromOffset(0, sliderY)
		end

		root.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				local relY = input.Position.Y - root.AbsolutePosition.Y
				local ratio = util.clamp(relY / math.max(1, root.AbsoluteSize.Y), 0, 1)
				if onJumpRatio then onJumpRatio(ratio) end
			end
		end)

		theme.changed:connect(function()
			root.BackgroundColor3 = theme.color.editor
			leftRule.BackgroundColor3 = theme.color.border
			slider.BackgroundColor3 = theme.color.selection
		end)

		return {
			root = root,
			width = width,
			updateSource = updateSource,
			updateViewport = updateViewport,
		}
	end

	return M
end
end)()

-- [ui/code/splitter] (3082 bytes)
__VSRBLX_MODULES["ui/code/splitter"] = (function()
-- Interactive draggable vertical/horizontal splitters between VS Code Sidebar,
-- Editor Groups, and the Bottom Terminal Panel.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local dispose = env.require("runtime/dispose")

	local M = {}

	function M.vertical(parent, zIndex, onDelta)
		local sash = P.frame(parent, {
			name = "VerticalSash",
			size = UDim2.new(0, 4, 1, 0),
			bg = theme.color.accent,
			transparency = 1,
			active = true,
			zIndex = zIndex or 35,
		})
		local dragging = false
		local startX = 0

		sash.MouseEnter:Connect(function() sash.BackgroundTransparency = 0.25 end)
		sash.MouseLeave:Connect(function() if not dragging then sash.BackgroundTransparency = 1 end end)

		sash.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				startX = input.Position.X
				sash.BackgroundTransparency = 0
			end
		end)

		if env.uis then
			dispose.connection(env.uis.InputChanged:Connect(function(input)
				if not dragging then return end
				if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
					local dx = input.Position.X - startX
					startX = input.Position.X
					if onDelta then onDelta(dx) end
				end
			end))
			dispose.connection(env.uis.InputEnded:Connect(function(input)
				if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
					dragging = false
					sash.BackgroundTransparency = 1
				end
			end))
		end

		return sash
	end

	function M.horizontal(parent, zIndex, onDelta)
		local sash = P.frame(parent, {
			name = "HorizontalSash",
			size = UDim2.new(1, 0, 0, 4),
			bg = theme.color.accent,
			transparency = 1,
			active = true,
			zIndex = zIndex or 35,
		})
		local dragging = false
		local startY = 0

		sash.MouseEnter:Connect(function() sash.BackgroundTransparency = 0.25 end)
		sash.MouseLeave:Connect(function() if not dragging then sash.BackgroundTransparency = 1 end end)

		sash.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				startY = input.Position.Y
				sash.BackgroundTransparency = 0
			end
		end)

		if env.uis then
			dispose.connection(env.uis.InputChanged:Connect(function(input)
				if not dragging then return end
				if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
					local dy = input.Position.Y - startY
					startY = input.Position.Y
					if onDelta then onDelta(dy) end
				end
			end))
			dispose.connection(env.uis.InputEnded:Connect(function(input)
				if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
					dragging = false
					sash.BackgroundTransparency = 1
				end
			end))
		end

		return sash
	end

	return M
end
end)()

-- [ui/code/tabs] (5544 bytes)
__VSRBLX_MODULES["ui/code/tabs"] = (function()
-- VS Code Multi-Tab Editor Bar with language badges, dirty dots (`●`), pin state,
-- context menu, Run (`▶`) button, Save button, and Split Editor button.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local icons = env.require("ui/icons")
	local overlay = env.require("ui/overlay")
	local codeStore = env.require("runtime/code_store")
	local commands = env.require("runtime/command_catalog")

	local M = {}

	function M.new(parent, paneName)
		local pane = paneName or "primary"
		local h = theme.sizes.tabBar

		local root = P.frame(parent, {
			name = "TabBar_" .. pane,
			size = UDim2.new(1, 0, 0, h),
			bg = theme.color.tabBar,
			zIndex = 20,
		})
		local bottomBorder = P.frame(root, {
			size = UDim2.new(1, 0, 0, 1),
			pos = UDim2.new(0, 0, 1, -1),
			bg = theme.color.border,
			zIndex = 21,
		})

		local tabsScroll = P.scroll(root, {
			name = "TabsScroll",
			size = UDim2.new(1, -106, 1, -1),
			direction = Enum.ScrollingDirection.X,
			autoCanvas = Enum.AutomaticSize.X,
			barThickness = 3,
			zIndex = 21,
		})
		P.list(tabsScroll, Enum.FillDirection.Horizontal, 1)

		local actionsBar = P.frame(root, {
			name = "EditorActions",
			size = UDim2.fromOffset(102, h - 1),
			pos = UDim2.new(1, -104, 0, 0),
			zIndex = 22,
		})
		P.list(actionsBar, Enum.FillDirection.Horizontal, 2, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

		P.button(actionsBar, {
			name = "RunTabBtn",
			size = UDim2.fromOffset(30, 26),
			text = "▶",
			bold = true,
			color = theme.color.good,
			radius = 4,
			order = 1,
			zIndex = 23,
			onClick = function() commands.run("run.active") end,
		})

		P.button(actionsBar, {
			name = "SaveTabBtn",
			size = UDim2.fromOffset(34, 26),
			text = "Save",
			textSize = 11,
			color = theme.color.sideBarText,
			radius = 4,
			order = 2,
			zIndex = 23,
			onClick = function() commands.run("file.save") end,
		})

		local splitBtn = P.button(actionsBar, {
			name = "SplitPaneBtn",
			size = UDim2.fromOffset(28, 26),
			text = "⫿",
			textSize = 14,
			color = theme.color.sideBarText,
			radius = 4,
			order = 3,
			zIndex = 23,
			onClick = function() codeStore.toggleSplit() end,
		})

		local function rebuild()
			tabsScroll:ClearAllChildren()
			P.list(tabsScroll, Enum.FillDirection.Horizontal, 1)
			local activeDoc = codeStore.active(pane)
			local activeId = activeDoc and activeDoc.id or nil

			for idx, doc in ipairs(codeStore.tabs) do
				local isCurrent = (doc.id == activeId)
				local tabW = math.max(118, math.min(200, #doc.title * 7 + 62))
				local tabBtn = P.button(tabsScroll, {
					name = "Tab_" .. doc.title,
					size = UDim2.fromOffset(tabW, h - 1),
					bg = isCurrent and theme.color.tabActive or theme.color.tabInactive,
					hoverBg = isCurrent and theme.color.tabActive or theme.color.hover,
					text = "",
					order = idx,
					zIndex = 22,
					activeState = function() return isCurrent end,
					onClick = function()
						codeStore.activate(doc.id, pane)
					end,
				})

				if isCurrent then
					P.frame(tabBtn, {
						name = "ActiveTopAccent",
						size = UDim2.new(1, 0, 0, 2),
						bg = theme.color.tabActiveTop,
						zIndex = 24,
					})
				end

				P.frame(tabBtn, {
					size = UDim2.new(0, 1, 1, 0),
					pos = UDim2.new(1, -1, 0, 0),
					bg = theme.color.border,
					zIndex = 23,
				})

				local badge = icons.fileBadge(tabBtn, doc.langId, false, 23)
				badge.Position = UDim2.fromOffset(8, math.floor((h - 14) / 2))

				local prefix = doc.pinned and "📌 " or ""
				P.label(tabBtn, {
					size = UDim2.new(1, -64, 1, 0),
					pos = UDim2.fromOffset(36, 0),
					text = prefix .. doc.title,
					textSize = 12,
					color = isCurrent and theme.color.tabActiveText or theme.color.tabInactiveText,
					truncate = true,
					zIndex = 23,
				})

				local closeOrDot = P.button(tabBtn, {
					name = "CloseTabBtn",
					size = UDim2.fromOffset(20, 20),
					pos = UDim2.new(1, -24, 0.5, -10),
					text = doc.dirty and "●" or (doc.pinned and "•" or "✕"),
					textSize = doc.dirty and 12 or 11,
					color = doc.dirty and theme.color.tabActiveText or theme.color.muted,
					radius = 3,
					zIndex = 24,
					onClick = function()
						if doc.pinned then
							codeStore.togglePin(doc.id)
						else
							codeStore.close(doc.id)
						end
					end,
				})
				closeOrDot.Active = true

				tabBtn.MouseButton2Click:Connect(function()
					local p = tabBtn.AbsolutePosition
					overlay.dropdown(p.X, p.Y + h, {
						{ label = doc.pinned and "Unpin Tab" or "Pin Tab", onClick = function() codeStore.togglePin(doc.id) end },
						{ label = "Save to Local Disk", shortcut = "Ctrl+S", onClick = function() codeStore.save(doc.id) end },
						{ separator = true },
						{ label = "Split Editor Right", onClick = function() codeStore.openFile(doc.path, { pane = "secondary" }) end },
						{ separator = true },
						{ label = "Close", shortcut = "Ctrl+W", onClick = function() codeStore.close(doc.id) end },
						{ label = "Close Others", onClick = function() codeStore.closeOthers(doc.id) end },
						{ label = "Close Saved", onClick = function() codeStore.closeSaved() end },
					}, 190)
				end)
			end
		end

		codeStore.changed:connect(rebuild)
		theme.changed:connect(function()
			root.BackgroundColor3 = theme.color.tabBar
			bottomBorder.BackgroundColor3 = theme.color.border
			splitBtn.TextColor3 = theme.color.sideBarText
			rebuild()
		end)

		rebuild()
		return {
			root = root,
			refresh = rebuild,
		}
	end

	return M
end
end)()

-- [ui/code/terminal] (10442 bytes)
__VSRBLX_MODULES["ui/code/terminal"] = (function()
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
end)()

-- [ui/code/welcome] (4356 bytes)
__VSRBLX_MODULES["ui/code/welcome"] = (function()
-- VS Code Welcome Tab shown when no editor tabs are open.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local brand = env.require("ui/brand")
	local caps = env.require("runtime/caps")
	local fsx = env.require("runtime/fsx")
	local config = env.require("runtime/config")
	local commands = env.require("runtime/command_catalog")
	local fsSync = env.require("tools/fs_sync")

	local M = {}

	function M.new(parent)
		local root = P.scroll(parent, {
			name = "WelcomeScreen",
			size = UDim2.fromScale(1, 1),
			bg = theme.color.editor,
			visible = false,
			zIndex = 14,
		})
		P.pad(root, 32, 36, 32, 36)

		local headerRow = P.frame(root, {
			size = UDim2.new(1, 0, 0, 56),
			zIndex = 15,
		})
		local logo = brand.draw(headerRow, 42, 16)
		logo.Position = UDim2.fromOffset(0, 6)

		local titleLbl = P.label(headerRow, {
			size = UDim2.new(1, -58, 0, 28),
			pos = UDim2.fromOffset(56, 2),
			text = "Visual Studio Code · Roblox Edition",
			bold = true,
			textSize = 22,
			color = theme.color.tabActiveText,
			zIndex = 16,
		})
		local subLbl = P.label(headerRow, {
			size = UDim2.new(1, -58, 0, 20),
			pos = UDim2.fromOffset(56, 32),
			text = string.format(
				"100%% Luau  |  Host: %s  |  Disk: %s  |  HTTP: %s",
				caps.executor,
				fsx.isBackedByDisk() and "writefile / readfile" or "Virtual Disk",
				caps.requestName or caps.http
			),
			textSize = 12,
			color = theme.color.muted,
			zIndex = 16,
		})

		local grid = P.frame(root, {
			size = UDim2.new(1, 0, 0, 260),
			pos = UDim2.fromOffset(0, 82),
			zIndex = 15,
		})

		local leftCol = P.frame(grid, {
			size = UDim2.new(0.48, 0, 1, 0),
			zIndex = 15,
		})
		P.list(leftCol, Enum.FillDirection.Vertical, 8)

		P.label(leftCol, {
			size = UDim2.new(1, 0, 0, 20),
			text = "Start",
			bold = true,
			textSize = 14,
			color = theme.color.tabActiveText,
			order = 1,
			zIndex = 16,
		})

		local START_ACTIONS = {
			{ label = "+  New Disk File...", cmd = "file.newDiskFile" },
			{ label = "📂  Switch Local Disk Workspace...", cmd = "workspace.switch" },
			{ label = "💾  Mount Raw Executor Folder...", cmd = "workspace.mountRaw" },
			{ label = "⎇  Clone GitHub Repository...", cmd = "github.clone" },
			{ label = "🔑  Set GitHub Personal Access Token...", cmd = "github.auth" },
			{ label = "🎨  Switch Color Theme...", cmd = "workbench.commandPalette" },
		}

		for idx, act in ipairs(START_ACTIONS) do
			P.button(leftCol, {
				size = UDim2.new(1, 0, 0, 26),
				alignX = Enum.TextXAlignment.Left,
				text = "  " .. act.label,
				color = theme.color.accent,
				radius = 4,
				order = idx + 1,
				zIndex = 16,
				onClick = function() commands.run(act.cmd) end,
			})
		end

		local rightCol = P.frame(grid, {
			size = UDim2.new(0.48, 0, 1, 0),
			pos = UDim2.new(0.52, 0, 0, 0),
			zIndex = 15,
		})
		P.list(rightCol, Enum.FillDirection.Vertical, 6)

		P.label(rightCol, {
			size = UDim2.new(1, 0, 0, 20),
			text = "Recent Disk Workspaces",
			bold = true,
			textSize = 14,
			color = theme.color.tabActiveText,
			order = 1,
			zIndex = 16,
		})

		local recentBox = P.frame(rightCol, {
			size = UDim2.new(1, 0, 0, 180),
			order = 2,
			zIndex = 16,
		})
		P.list(recentBox, Enum.FillDirection.Vertical, 4)

		local function refreshRecent()
			recentBox:ClearAllChildren()
			P.list(recentBox, Enum.FillDirection.Vertical, 4)
			local recent = config.get("files.recentWorkspaces", { "default" })
			if type(recent) == "table" then
				for i, name in ipairs(recent) do
					local wsName = tostring(name)
					P.button(recentBox, {
						size = UDim2.new(1, 0, 0, 24),
						alignX = Enum.TextXAlignment.Left,
						text = "  VSRBLX/workspaces/" .. wsName,
						mono = true,
						textSize = 12,
						color = theme.color.sideBarText,
						radius = 4,
						order = i,
						zIndex = 17,
						onClick = function() fsSync.switchWorkspace(wsName) end,
					})
				end
			end
		end

		config.changed:connect(function(key)
			if key == "*" or key == "files.recentWorkspaces" then refreshRecent() end
		end)
		theme.changed:connect(function()
			root.BackgroundColor3 = theme.color.editor
			titleLbl.TextColor3 = theme.color.tabActiveText
			subLbl.TextColor3 = theme.color.muted
		end)

		refreshRecent()
		return {
			root = root,
			refresh = refreshRecent,
		}
	end

	return M
end
end)()

-- [ui/command_palette] (6640 bytes)
__VSRBLX_MODULES["ui/command_palette"] = (function()
-- VS Code Command Palette (`>`), Quick Open File Finder (`Ctrl+P`), Go to Line (`:`),
-- and Go to Symbol (`@`) modal overlay.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local icons = env.require("ui/icons")
	local util = env.require("runtime/util")
	local commands = env.require("runtime/command_catalog")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")
	local codeFolding = env.require("runtime/code_folding")

	local M = { openState = false }

	function M.new(parentWindow)
		local backdrop = P.button(parentWindow, {
			name = "CommandPaletteBackdrop",
			size = UDim2.fromScale(1, 1),
			text = "",
			visible = false,
			zIndex = 160,
			onClick = function()
				backdrop.Visible = false
				M.openState = false
			end,
		})
		backdrop.BackgroundTransparency = 1

		local card = P.frame(backdrop, {
			name = "CommandPaletteCard",
			size = UDim2.fromOffset(500, 320),
			pos = UDim2.new(0.5, 0, 0, 36),
			anchor = Vector2.new(0.5, 0),
			bg = theme.color.dropdownBg,
			radius = 6,
			border = theme.color.border,
			active = true,
			zIndex = 162,
		})
		P.pad(card, 8, 8, 8, 8)

		local inputWrap, box = P.input(card, {
			name = "PaletteInput",
			size = UDim2.new(1, 0, 0, 30),
			placeholder = "Search files by name, or type '>' for commands, ':' for line, '@' for symbols",
			zIndex = 163,
		})
		inputWrap.Active = true

		local listScroll = P.scroll(card, {
			name = "PaletteResults",
			size = UDim2.new(1, 0, 1, -38),
			pos = UDim2.fromOffset(0, 38),
			zIndex = 163,
		})
		P.list(listScroll, Enum.FillDirection.Vertical, 2)

		local currentResults = {}

		local function closePalette()
			backdrop.Visible = false
			M.openState = false
		end

		local function populate(rawText)
			listScroll:ClearAllChildren()
			P.list(listScroll, Enum.FillDirection.Vertical, 2)
			currentResults = {}
			local text = tostring(rawText or "")

			if util.startsWith(text, ">") then
				local found = commands.search(text:sub(2))
				for idx, cmd in ipairs(found) do
					if idx <= 40 then
						currentResults[#currentResults + 1] = function()
							closePalette()
							commands.run(cmd.id)
						end
						local row = P.button(listScroll, {
							name = "Cmd_" .. cmd.id,
							size = UDim2.new(1, 0, 0, 26),
							hoverBg = theme.color.listActive,
							text = "",
							radius = 3,
							order = idx,
							zIndex = 164,
							onClick = currentResults[#currentResults],
						})
						P.label(row, {
							size = UDim2.new(1, -100, 1, 0),
							pos = UDim2.fromOffset(8, 0),
							text = cmd.label,
							textSize = 12,
							color = theme.color.sideBarText,
							truncate = true,
							zIndex = 165,
						})
						if cmd.shortcut ~= "" then
							P.label(row, {
								size = UDim2.fromOffset(90, 26),
								pos = UDim2.new(1, -96, 0, 0),
								text = cmd.shortcut,
								textSize = 11,
								color = theme.color.muted,
								alignX = Enum.TextXAlignment.Right,
								zIndex = 165,
							})
						end
					end
				end
			elseif util.startsWith(text, ":") then
				local ln = tonumber(util.trim(text:sub(2))) or 1
				currentResults[1] = function()
					closePalette()
					local doc = codeStore.active()
					if doc then codeStore.jumpToLine(doc.id, ln, 1) end
				end
				P.button(listScroll, {
					size = UDim2.new(1, 0, 0, 28),
					hoverBg = theme.color.listActive,
					text = "  Go to Line " .. tostring(ln),
					alignX = Enum.TextXAlignment.Left,
					radius = 3,
					zIndex = 164,
					onClick = currentResults[1],
				})
			elseif util.startsWith(text, "@") then
				local doc = codeStore.active()
				local q = util.trim(text:sub(2)):lower()
				local syms = doc and codeFolding.symbols(doc.content, doc.langId) or {}
				local rank = 0
				for _, sym in ipairs(syms) do
					if q == "" or sym.name:lower():find(q, 1, true) then
						rank = rank + 1
						local targetLn = sym.line
						currentResults[rank] = function()
							closePalette()
							if doc then codeStore.jumpToLine(doc.id, targetLn, 1) end
						end
						local row = P.button(listScroll, {
							size = UDim2.new(1, 0, 0, 26),
							hoverBg = theme.color.listActive,
							text = "",
							radius = 3,
							order = rank,
							zIndex = 164,
							onClick = currentResults[rank],
						})
						P.label(row, {
							size = UDim2.new(1, -60, 1, 0),
							pos = UDim2.fromOffset(8, 0),
							text = string.format("[%s] %s", sym.kind, sym.name),
							mono = true,
							textSize = 12,
							color = theme.color.sideBarText,
							zIndex = 165,
						})
						P.label(row, {
							size = UDim2.fromOffset(50, 26),
							pos = UDim2.new(1, -56, 0, 0),
							text = "Ln " .. tostring(sym.line),
							textSize = 11,
							color = theme.color.muted,
							alignX = Enum.TextXAlignment.Right,
							zIndex = 165,
						})
					end
				end
			else
				local q = util.trim(text):lower()
				local files = workspaceFs.listAllFiles("")
				local rank = 0
				for _, f in ipairs(files) do
					if rank < 35 and (q == "" or f.path:lower():find(q, 1, true)) then
						rank = rank + 1
						local targetPath = f.path
						currentResults[rank] = function()
							closePalette()
							codeStore.openFile(targetPath)
						end
						local row = P.button(listScroll, {
							name = "FileHit_" .. tostring(rank),
							size = UDim2.new(1, 0, 0, 26),
							hoverBg = theme.color.listActive,
							text = "",
							radius = 3,
							order = rank,
							zIndex = 164,
							onClick = currentResults[rank],
						})
						local badge = icons.fileBadge(row, f.lang, false, 165)
						badge.Position = UDim2.fromOffset(6, 6)
						P.label(row, {
							size = UDim2.new(1, -42, 1, 0),
							pos = UDim2.fromOffset(36, 0),
							text = f.name .. "   —   " .. f.path,
							textSize = 12,
							color = theme.color.sideBarText,
							truncate = true,
							zIndex = 165,
						})
					end
				end
			end
		end

		box:GetPropertyChangedSignal("Text"):Connect(function()
			if backdrop.Visible then
				populate(box.Text)
			end
		end)

		box.FocusLost:Connect(function(enterPressed)
			if enterPressed and currentResults[1] then
				currentResults[1]()
			end
		end)

		local api = {}
		function api.open(prefix)
			M.openState = true
			backdrop.Visible = true
			card.BackgroundColor3 = theme.color.dropdownBg
			box.Text = prefix or ""
			populate(box.Text)
			task.defer(function()
				pcall(function()
					box:CaptureFocus()
					box.CursorPosition = #box.Text + 1
				end)
			end)
		end

		function api.close()
			closePalette()
		end

		return api
	end

	return M
end
end)()

-- [ui/icons] (4604 bytes)
__VSRBLX_MODULES["ui/icons"] = (function()
-- Pure Roblox Frame-drawn vector VS Code Codicons & language file badges.
-- Requires zero external rbxassetid uploads so icons never break or get moderated.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local languages = env.require("runtime/languages")

	local M = {}

	local function lineBar(parent, x, y, w, h, col, rot, z)
		local b = P.frame(parent, {
			size = UDim2.fromOffset(w, h),
			pos = UDim2.fromOffset(x, y),
			bg = col,
			zIndex = z,
		})
		if rot then b.Rotation = rot end
		return b
	end

	local function outlineBox(parent, x, y, w, h, col, radius, z)
		local f = P.frame(parent, {
			size = UDim2.fromOffset(w, h),
			pos = UDim2.fromOffset(x, y),
			radius = radius or 2,
			border = col,
			borderWidth = 1.5,
			zIndex = z,
		})
		return f
	end

	function M.codicon(parent, name, size, color, zIndex)
		local s = size or 20
		local col = color or theme.color.activityIcon
		local z = zIndex or 5
		local root = P.frame(parent, {
			name = "Icon_" .. tostring(name),
			size = UDim2.fromOffset(s, s),
			zIndex = z,
		})

		if name == "explorer" then
			outlineBox(root, 3, 5, s - 9, s - 7, col, 2, z + 1)
			outlineBox(root, 6, 2, s - 9, s - 7, col, 2, z + 2)
		elseif name == "search" then
			local r = math.floor(s * 0.56)
			local circle = outlineBox(root, 2, 2, r, r, col, math.floor(r / 2), z + 1)
			circle.Name = "Lens"
			lineBar(root, math.floor(s * 0.56), math.floor(s * 0.68), math.floor(s * 0.36), 2, col, 45, z + 1)
		elseif name == "scm" then
			outlineBox(root, 4, 2, 5, 5, col, 3, z + 2)
			outlineBox(root, 4, s - 7, 5, 5, col, 3, z + 2)
			outlineBox(root, s - 9, 5, 5, 5, col, 3, z + 2)
			lineBar(root, 6, 7, 2, s - 14, col, 0, z + 1)
			lineBar(root, 6, math.floor(s * 0.48), s - 13, 2, col, -18, z + 1)
		elseif name == "debug" then
			outlineBox(root, 3, 3, s - 6, s - 6, col, 3, z + 1)
			local playLbl = P.label(root, {
				size = UDim2.fromScale(1, 1),
				text = "▶",
				textSize = math.max(10, s - 7),
				color = col,
				alignX = Enum.TextXAlignment.Center,
				zIndex = z + 2,
			})
			playLbl.Position = UDim2.fromOffset(1, 0)
		elseif name == "extensions" then
			local b = math.floor((s - 7) / 2)
			outlineBox(root, 2, 2, b, b, col, 1, z + 1)
			outlineBox(root, 2, 4 + b, b, b, col, 1, z + 1)
			outlineBox(root, 4 + b, 4 + b, b, b, col, 1, z + 1)
			outlineBox(root, 5 + b, 1, b, b, col, 1, z + 2)
		elseif name == "settings" then
			local r = s - 6
			outlineBox(root, 3, 3, r, r, col, math.floor(r / 2), z + 1)
			outlineBox(root, math.floor(s / 2) - 2, math.floor(s / 2) - 2, 4, 4, col, 2, z + 2)
			lineBar(root, math.floor(s / 2) - 1, 1, 2, 3, col, 0, z + 1)
			lineBar(root, math.floor(s / 2) - 1, s - 4, 2, 3, col, 0, z + 1)
			lineBar(root, 1, math.floor(s / 2) - 1, 3, 2, col, 0, z + 1)
			lineBar(root, s - 4, math.floor(s / 2) - 1, 3, 2, col, 0, z + 1)
		elseif name == "account" then
			outlineBox(root, math.floor(s / 2) - 4, 2, 8, 8, col, 4, z + 1)
			outlineBox(root, 3, s - 8, s - 6, 6, col, 3, z + 1)
		elseif name == "sidebar" then
			outlineBox(root, 2, 3, s - 4, s - 6, col, 2, z + 1)
			lineBar(root, 7, 4, 2, s - 8, col, 0, z + 2)
		elseif name == "panel" then
			outlineBox(root, 2, 3, s - 4, s - 6, col, 2, z + 1)
			lineBar(root, 3, s - 8, s - 6, 2, col, 0, z + 2)
		elseif name == "split" then
			outlineBox(root, 2, 3, s - 4, s - 6, col, 2, z + 1)
			lineBar(root, math.floor(s / 2), 4, 1, s - 8, col, 0, z + 2)
		elseif name == "minimize" then
			lineBar(root, 4, math.floor(s / 2), s - 8, 1, col, 0, z + 1)
		elseif name == "maximize" then
			outlineBox(root, 4, 4, s - 8, s - 8, col, 1, z + 1)
		elseif name == "close" then
			lineBar(root, 3, math.floor(s / 2), s - 6, 2, col, 45, z + 1)
			lineBar(root, 3, math.floor(s / 2), s - 6, 2, col, -45, z + 1)
		end

		return root
	end

	function M.fileBadge(parent, langId, isDir, zIndex)
		local z = zIndex or 5
		if isDir then
			local folderBox = P.frame(parent, {
				name = "FolderBadge",
				size = UDim2.fromOffset(14, 11),
				bg = Color3.fromRGB(220, 173, 96),
				radius = 2,
				zIndex = z,
			})
			return folderBox
		end
		local lang = type(langId) == "table" and langId or languages.get(langId)
		local rgb = lang.badgeColor or { 150, 150, 150 }
		local badgeColor = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		local lbl = P.label(parent, {
			name = "LangBadge",
			size = UDim2.fromOffset(26, 14),
			text = lang.badge or "FILE",
			mono = true,
			bold = true,
			textSize = 9,
			color = badgeColor,
			alignX = Enum.TextXAlignment.Center,
			zIndex = z,
		})
		return lbl
	end

	return M
end
end)()

-- [ui/overlay] (7221 bytes)
__VSRBLX_MODULES["ui/overlay"] = (function()
-- VS Code popups, dropdown menus, input prompts, modals, and bottom-right toast notifications.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")

	local M = {
		layer = nil,
		toastStack = nil,
		activeMenu = nil,
		activeModal = nil,
	}

	function M.mount(parentScreen)
		if M.layer then
			pcall(function() M.layer:Destroy() end)
		end
		M.layer = P.frame(parentScreen, {
			name = "OverlayLayer",
			size = UDim2.fromScale(1, 1),
			zIndex = 200,
		})
		M.toastStack = P.frame(M.layer, {
			name = "ToastStack",
			size = UDim2.fromOffset(320, 260),
			pos = UDim2.new(1, -332, 1, -296),
			zIndex = 260,
		})
		P.list(M.toastStack, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom)
	end

	function M.closeMenu()
		if M.activeMenu then
			pcall(function() M.activeMenu:Destroy() end)
			M.activeMenu = nil
		end
	end

	function M.closeModal()
		if M.activeModal then
			pcall(function() M.activeModal:Destroy() end)
			M.activeModal = nil
		end
	end

	function M.openModal(name, width, height)
		M.closeModal()
		local parentTarget = M.layer
		local backdrop = P.button(parentTarget, {
			name = "ModalBackdrop_" .. tostring(name or "Dialog"),
			size = UDim2.fromScale(1, 1),
			bg = Color3.fromRGB(0, 0, 0),
			transparency = 0.45,
			text = "",
			zIndex = 230,
			onClick = function() M.closeModal() end,
		})
		local card = P.frame(backdrop, {
			name = tostring(name or "ModalCard"),
			size = UDim2.fromOffset(width or 480, height or 320),
			pos = UDim2.new(0.5, 0, 0.46, 0),
			anchor = Vector2.new(0.5, 0.5),
			bg = theme.color.sideBar,
			radius = 6,
			border = theme.color.border,
			active = true,
			zIndex = 231,
		})
		M.activeModal = backdrop
		return card, backdrop
	end

	function M.dropdown(x, y, items, width)
		M.closeMenu()
		if not M.layer then return end

		local backdrop = P.button(M.layer, {
			name = "MenuBackdrop",
			size = UDim2.fromScale(1, 1),
			text = "",
			zIndex = 210,
			onClick = function() M.closeMenu() end,
		})
		backdrop.BackgroundTransparency = 1

		local menuW = width or 220
		local menuH = 8
		for _, it in ipairs(items) do
			menuH = menuH + (it.separator and 7 or 24)
		end

		local card = P.frame(backdrop, {
			name = "DropdownCard",
			size = UDim2.fromOffset(menuW, menuH),
			pos = UDim2.fromOffset(x, y),
			bg = theme.color.dropdownBg,
			radius = 4,
			border = theme.color.border,
			zIndex = 215,
		})
		P.pad(card, 4, 4, 4, 4)
		P.list(card, Enum.FillDirection.Vertical, 0)

		for idx, item in ipairs(items) do
			if item.separator then
				local sepWrap = P.frame(card, {
					size = UDim2.new(1, 0, 0, 7),
					order = idx,
					zIndex = 216,
				})
				P.frame(sepWrap, {
					size = UDim2.new(1, -8, 0, 1),
					pos = UDim2.fromOffset(4, 3),
					bg = theme.color.border,
					zIndex = 217,
				})
			else
				local row = P.button(card, {
					name = "MenuItem_" .. tostring(idx),
					size = UDim2.new(1, 0, 0, 24),
					hoverBg = theme.color.listActive,
					text = "",
					radius = 3,
					order = idx,
					zIndex = 216,
					onClick = function()
						M.closeMenu()
						if item.onClick then item.onClick() end
					end,
				})
				P.label(row, {
					size = UDim2.new(1, -70, 1, 0),
					pos = UDim2.fromOffset(10, 0),
					text = item.label or "",
					color = theme.color.sideBarText,
					textSize = 12,
					zIndex = 217,
				})
				if item.shortcut and item.shortcut ~= "" then
					P.label(row, {
						size = UDim2.fromOffset(64, 24),
						pos = UDim2.new(1, -70, 0, 0),
						text = item.shortcut,
						color = theme.color.muted,
						textSize = 11,
						alignX = Enum.TextXAlignment.Right,
						zIndex = 217,
					})
				end
			end
		end

		M.activeMenu = backdrop
		return backdrop
	end

	function M.prompt(spec)
		M.closeModal()
		if not M.layer then return end

		local backdrop = P.button(M.layer, {
			name = "ModalBackdrop",
			size = UDim2.fromScale(1, 1),
			bg = Color3.fromRGB(0, 0, 0),
			transparency = 0.45,
			text = "",
			zIndex = 230,
			onClick = function() M.closeModal() end,
		})

		local boxCard = P.frame(backdrop, {
			name = "PromptModal",
			size = UDim2.fromOffset(spec.width or 420, spec.height or 146),
			pos = UDim2.new(0.5, 0, 0.34, 0),
			anchor = Vector2.new(0.5, 0.5),
			bg = theme.color.sideBar,
			radius = 6,
			border = theme.color.border,
			active = true,
			zIndex = 235,
		})
		P.pad(boxCard, 12, 14, 12, 14)

		P.label(boxCard, {
			size = UDim2.new(1, 0, 0, 20),
			text = spec.title or "Input",
			bold = true,
			textSize = 14,
			color = theme.color.tabActiveText,
			zIndex = 236,
		})

		if spec.subtitle then
			P.label(boxCard, {
				size = UDim2.new(1, 0, 0, 18),
				pos = UDim2.fromOffset(0, 22),
				text = spec.subtitle,
				textSize = 12,
				color = theme.color.muted,
				zIndex = 236,
			})
		end

		local inputWrap, field = P.input(boxCard, {
			name = "PromptField",
			size = UDim2.new(1, 0, 0, 28),
			pos = UDim2.fromOffset(0, 48),
			value = spec.default or "",
			placeholder = spec.placeholder or "",
			mono = spec.mono == true,
			zIndex = 236,
			onSubmit = function(val)
				M.closeModal()
				if spec.onConfirm then spec.onConfirm(val) end
			end,
		})
		inputWrap.Active = true

		local actions = P.frame(boxCard, {
			size = UDim2.new(1, 0, 0, 28),
			pos = UDim2.new(0, 0, 1, -28),
			zIndex = 236,
		})
		P.list(actions, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right)

		P.button(actions, {
			name = "CancelBtn",
			size = UDim2.fromOffset(74, 26),
			bg = theme.color.inputBg,
			hoverBg = theme.color.hover,
			text = "Cancel",
			radius = 4,
			order = 1,
			zIndex = 237,
			onClick = function() M.closeModal() end,
		})
		P.button(actions, {
			name = "ConfirmBtn",
			size = UDim2.fromOffset(92, 26),
			bg = theme.color.accent,
			hoverBg = theme.color.accentHover,
			color = Color3.fromRGB(255, 255, 255),
			bold = true,
			text = spec.confirmText or "Confirm",
			radius = 4,
			order = 2,
			zIndex = 237,
			onClick = function()
				local v = field.Text
				M.closeModal()
				if spec.onConfirm then spec.onConfirm(v) end
			end,
		})

		M.activeModal = backdrop
		task.defer(function()
			pcall(function() field:CaptureFocus() end)
		end)
		return backdrop, field
	end

	function M.toast(message, kind, durationSec)
		if not M.toastStack then return end
		local stripeColor = theme.color.accent
		if kind == "good" then stripeColor = theme.color.good
		elseif kind == "warn" then stripeColor = theme.color.warn
		elseif kind == "bad" then stripeColor = theme.color.bad end

		local card = P.frame(M.toastStack, {
			name = "Toast",
			size = UDim2.fromOffset(310, 44),
			bg = theme.color.sideBar,
			radius = 4,
			border = theme.color.border,
			zIndex = 262,
		})
		P.frame(card, {
			size = UDim2.new(0, 4, 1, 0),
			bg = stripeColor,
			radius = 2,
			zIndex = 263,
		})
		P.label(card, {
			size = UDim2.new(1, -22, 1, -8),
			pos = UDim2.fromOffset(12, 4),
			text = tostring(message or ""),
			wrap = true,
			textSize = 12,
			color = theme.color.sideBarText,
			zIndex = 263,
		})

		task.delay(durationSec or 3.5, function()
			pcall(function() card:Destroy() end)
		end)
		return card
	end

	return M
end
end)()

-- [ui/panels/debug] (4193 bytes)
__VSRBLX_MODULES["ui/panels/debug"] = (function()
-- VS Code Run & Debug Sidebar Viewlet (`Ctrl+Shift+D`) with Luau execution & Watch expressions.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local overlay = env.require("ui/overlay")
	local runner = env.require("runtime/runner")
	local execution = env.require("tools/execution")

	local M = {}

	function M.new(parent)
		local root = P.frame(parent, {
			name = "DebugViewlet",
			size = UDim2.fromScale(1, 1),
			visible = false,
			zIndex = 21,
		})
		P.pad(root, 6, 10, 6, 10)

		P.label(root, {
			size = UDim2.new(1, 0, 0, 22),
			text = "RUN AND DEBUG",
			bold = true,
			textSize = 11,
			color = theme.color.muted,
			zIndex = 22,
		})

		local btnRow = P.frame(root, {
			size = UDim2.new(1, 0, 0, 30),
			pos = UDim2.fromOffset(0, 26),
			zIndex = 22,
		})
		P.button(btnRow, {
			name = "RunActiveScriptBtn",
			size = UDim2.new(0.68, -3, 1, 0),
			bg = theme.color.good,
			color = Color3.fromRGB(18, 22, 18),
			bold = true,
			text = "▶ Run Active Script (F5)",
			textSize = 12,
			radius = 4,
			zIndex = 23,
			onClick = function()
				local ok, err = execution.runActive()
				if ok then
					overlay.toast("Executed active Luau script", "good", 2)
				else
					overlay.toast("Run error: " .. tostring(err), "bad", 4)
				end
			end,
		})
		P.button(btnRow, {
			name = "StopTasksBtn",
			size = UDim2.new(0.32, -3, 1, 0),
			pos = UDim2.new(0.68, 6, 0, 0),
			bg = theme.color.bad,
			color = Color3.fromRGB(255, 255, 255),
			bold = true,
			text = "■ Stop",
			textSize = 12,
			radius = 4,
			zIndex = 23,
			onClick = function()
				local n = execution.stop()
				overlay.toast(string.format("Stopped %d task(s)", n), "warn", 2)
			end,
		})

		-- Watch expressions
		P.label(root, {
			size = UDim2.new(1, 0, 0, 20),
			pos = UDim2.fromOffset(0, 64),
			bold = true,
			textSize = 11,
			color = theme.color.sideBarText,
			text = "▾ WATCH EXPRESSIONS",
			zIndex = 22,
		})

		local _, watchBox = P.input(root, {
			name = "WatchExprInput",
			size = UDim2.new(1, -48, 0, 26),
			pos = UDim2.fromOffset(0, 86),
			mono = true,
			placeholder = "e.g. workspace.Name or 2 ^ 10",
			zIndex = 22,
		})
		local addWatchBtn = P.button(root, {
			size = UDim2.fromOffset(42, 26),
			pos = UDim2.new(1, -42, 0, 86),
			bg = theme.color.accent,
			color = Color3.fromRGB(255, 255, 255),
			text = "Add",
			textSize = 11,
			radius = 4,
			zIndex = 22,
		})

		local watches = { "game and game.PlaceId or 0", "workspace and #workspace:GetChildren() or 0" }
		local watchScroll = P.scroll(root, {
			name = "WatchScroll",
			size = UDim2.new(1, 0, 1, -120),
			pos = UDim2.fromOffset(0, 120),
			zIndex = 22,
		})
		P.list(watchScroll, Enum.FillDirection.Vertical, 3)

		local function refreshWatches()
			watchScroll:ClearAllChildren()
			P.list(watchScroll, Enum.FillDirection.Vertical, 3)
			for idx, expr in ipairs(watches) do
				local ok, val = runner.evalExpression(expr)
				local row = P.frame(watchScroll, {
					size = UDim2.new(1, 0, 0, 36),
					bg = theme.color.inputBg,
					radius = 4,
					order = idx,
					zIndex = 23,
				})
				P.label(row, {
					size = UDim2.new(1, -28, 0, 18),
					pos = UDim2.fromOffset(6, 2),
					mono = true,
					textSize = 11,
					color = theme.color.accent,
					text = expr,
					truncate = true,
					zIndex = 24,
				})
				P.label(row, {
					size = UDim2.new(1, -12, 0, 16),
					pos = UDim2.fromOffset(6, 18),
					mono = true,
					textSize = 11,
					color = ok and theme.color.good or theme.color.bad,
					text = "=> " .. tostring(val),
					truncate = true,
					zIndex = 24,
				})
				P.button(row, {
					size = UDim2.fromOffset(20, 18),
					pos = UDim2.new(1, -22, 0, 2),
					text = "✕",
					textSize = 10,
					zIndex = 24,
					onClick = function()
						table.remove(watches, idx)
						refreshWatches()
					end,
				})
			end
		end

		addWatchBtn.Activated:Connect(function()
			if watchBox.Text ~= "" then
				watches[#watches + 1] = watchBox.Text
				watchBox.Text = ""
				refreshWatches()
			end
		end)
		runner.changed:connect(refreshWatches)

		refreshWatches()
		return { root = root, refresh = refreshWatches }
	end

	return M
end
end)()

-- [ui/panels/explorer] (8331 bytes)
__VSRBLX_MODULES["ui/panels/explorer"] = (function()
-- VS Code Explorer Sidebar Viewlet: Open Editors, Local Disk File Tree (`writefile`/
-- `readfile`), and Live Roblox DataModel Script Importer.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local explorerTreeMod = env.require("ui/code/explorer")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")
	local robloxExplorer = env.require("runtime/roblox_explorer")
	local decompiler = env.require("tools/decompiler")
	local fsSync = env.require("tools/fs_sync")
	local overlay = env.require("ui/overlay")

	local M = {}

	function M.new(parent)
		local root = P.frame(parent, {
			name = "ExplorerViewlet",
			size = UDim2.fromScale(1, 1),
			zIndex = 21,
		})

		local titleRow = P.frame(root, {
			size = UDim2.new(1, 0, 0, 30),
			zIndex = 22,
		})
		P.label(titleRow, {
			size = UDim2.new(1, -110, 1, 0),
			pos = UDim2.fromOffset(12, 0),
			text = "EXPLORER",
			bold = true,
			textSize = 11,
			color = theme.color.muted,
			zIndex = 23,
		})

		local toolRow = P.frame(titleRow, {
			size = UDim2.fromOffset(102, 26),
			pos = UDim2.new(1, -106, 0, 2),
			zIndex = 23,
		})
		P.list(toolRow, Enum.FillDirection.Horizontal, 2, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

		local fileTree = nil

		P.button(toolRow, {
			name = "NewFileBtn",
			size = UDim2.fromOffset(24, 22),
			text = "+F",
			bold = true,
			textSize = 10,
			radius = 3,
			order = 1,
			zIndex = 24,
			onClick = function() if fileTree then fileTree.promptNewFile() end end,
		})
		P.button(toolRow, {
			name = "NewFolderBtn",
			size = UDim2.fromOffset(24, 22),
			text = "+D",
			bold = true,
			textSize = 10,
			radius = 3,
			order = 2,
			zIndex = 24,
			onClick = function() if fileTree then fileTree.promptNewFolder() end end,
		})
		P.button(toolRow, {
			name = "ReloadDiskBtn",
			size = UDim2.fromOffset(24, 22),
			text = "↻",
			textSize = 12,
			radius = 3,
			order = 3,
			zIndex = 24,
			onClick = function()
				fsSync.reloadFromDisk()
				overlay.toast("Synced with local disk", "good", 2)
			end,
		})
		P.button(toolRow, {
			name = "SaveAllBtn",
			size = UDim2.fromOffset(24, 22),
			text = "💾",
			textSize = 11,
			radius = 3,
			order = 4,
			zIndex = 24,
			onClick = function()
				local n = codeStore.saveAll()
				overlay.toast(string.format("Saved %d file(s) to disk", n), "good", 2)
			end,
		})

		local scroll = P.scroll(root, {
			name = "ExplorerScroll",
			size = UDim2.new(1, 0, 1, -30),
			pos = UDim2.fromOffset(0, 30),
			zIndex = 22,
		})
		P.list(scroll, Enum.FillDirection.Vertical, 2)

		-- Section 1: Open Editors
		local openHeader = P.frame(scroll, {
			size = UDim2.new(1, 0, 0, 22),
			bg = theme.color.sideBarHeader,
			order = 1,
			zIndex = 23,
		})
		local openHeaderLbl = P.label(openHeader, {
			size = UDim2.new(1, -12, 1, 0),
			pos = UDim2.fromOffset(8, 0),
			text = "▾ OPEN EDITORS",
			bold = true,
			textSize = 11,
			color = theme.color.sideBarText,
			zIndex = 24,
		})

		local openList = P.frame(scroll, {
			name = "OpenEditorsList",
			size = UDim2.new(1, 0, 0, 0),
			order = 2,
			zIndex = 23,
		})
		openList.AutomaticSize = Enum.AutomaticSize.Y
		P.list(openList, Enum.FillDirection.Vertical, 1)

		-- Section 2: Local Disk Folder
		local wsHeader = P.frame(scroll, {
			size = UDim2.new(1, 0, 0, 22),
			bg = theme.color.sideBarHeader,
			order = 3,
			zIndex = 23,
		})
		local wsHeaderLbl = P.label(wsHeader, {
			size = UDim2.new(1, -12, 1, 0),
			pos = UDim2.fromOffset(8, 0),
			text = "▾ WORKSPACE: " .. workspaceFs.activeName:upper(),
			bold = true,
			textSize = 11,
			color = theme.color.sideBarText,
			truncate = true,
			zIndex = 24,
		})

		local treeWrap = P.frame(scroll, {
			size = UDim2.new(1, 0, 0, 0),
			order = 4,
			zIndex = 23,
		})
		treeWrap.AutomaticSize = Enum.AutomaticSize.Y
		fileTree = explorerTreeMod.new(treeWrap)

		-- Section 3: Roblox Game Explorer
		local gameExpanded = false
		local gameBtn = P.button(scroll, {
			name = "GameTreeToggle",
			size = UDim2.new(1, 0, 0, 22),
			bg = theme.color.sideBarHeader,
			hoverBg = theme.color.hover,
			alignX = Enum.TextXAlignment.Left,
			bold = true,
			textSize = 11,
			color = theme.color.sideBarText,
			text = "  ▸ ROBLOX DATAMODEL",
			order = 5,
			zIndex = 23,
		})
		local gameContainer = P.frame(scroll, {
			size = UDim2.new(1, 0, 0, 0),
			visible = false,
			order = 6,
			zIndex = 23,
		})
		gameContainer.AutomaticSize = Enum.AutomaticSize.Y
		P.list(gameContainer, Enum.FillDirection.Vertical, 1)

		local expandedInstances = {}
		local function renderGameTree()
			gameContainer:ClearAllChildren()
			if not gameExpanded then return end
			P.list(gameContainer, Enum.FillDirection.Vertical, 1)
			local ord = 0

			local function walkInst(inst, labelName, depth)
				if depth > 5 or ord > 80 then return end
				for _, ch in ipairs(robloxExplorer.childrenOf(inst, 40)) do
					ord = ord + 1
					local row = P.button(gameContainer, {
						size = UDim2.new(1, 0, 0, 21),
						hoverBg = theme.color.hover,
						alignX = Enum.TextXAlignment.Left,
						textSize = 11,
						color = ch.isScript and theme.color.accent or theme.color.sideBarText,
						text = string.rep("   ", depth) .. (ch.isScript and "📜 " or (ch.hasChildren and "▸ " or "  ")) .. ch.name .. " (" .. ch.className .. ")",
						order = ord,
						zIndex = 24,
						onClick = function()
							if ch.isScript then
								decompiler.openInstanceScript(ch.instance, true)
								overlay.toast("Imported " .. ch.name .. " to workspace", "good", 2.5)
							elseif ch.hasChildren then
								expandedInstances[ch.instance] = not expandedInstances[ch.instance]
								renderGameTree()
							end
						end,
					})
					row.TextTruncate = Enum.TextTruncate.AtEnd
					if expandedInstances[ch.instance] then
						walkInst(ch.instance, ch.name, depth + 1)
					end
				end
			end

			for _, rootSvc in ipairs(robloxExplorer.rootServices()) do
				ord = ord + 1
				local svcInst = rootSvc.instance
				P.button(gameContainer, {
					size = UDim2.new(1, 0, 0, 22),
					hoverBg = theme.color.hover,
					alignX = Enum.TextXAlignment.Left,
					bold = true,
					textSize = 11,
					color = theme.color.sideBarText,
					text = "  " .. (expandedInstances[svcInst] and "▾ " or "▸ ") .. rootSvc.name,
					order = ord,
					zIndex = 24,
					onClick = function()
						expandedInstances[svcInst] = not expandedInstances[svcInst]
						renderGameTree()
					end,
				})
				if expandedInstances[svcInst] then
					walkInst(svcInst, rootSvc.name, 2)
				end
			end
		end

		gameBtn.Activated:Connect(function()
			gameExpanded = not gameExpanded
			gameBtn.Text = gameExpanded and "  ▾ ROBLOX DATAMODEL" or "  ▸ ROBLOX DATAMODEL"
			gameContainer.Visible = gameExpanded
			renderGameTree()
		end)

		local function renderOpenEditors()
			openList:ClearAllChildren()
			P.list(openList, Enum.FillDirection.Vertical, 1)
			openHeaderLbl.Text = string.format("▾ OPEN EDITORS (%d)", #codeStore.tabs)
			local activeDoc = codeStore.active()
			for idx, tab in ipairs(codeStore.tabs) do
				local isCur = activeDoc and activeDoc.id == tab.id
				local row = P.button(openList, {
					size = UDim2.new(1, 0, 0, 21),
					bg = isCur and theme.color.listActive or nil,
					hoverBg = theme.color.hover,
					alignX = Enum.TextXAlignment.Left,
					textSize = 12,
					color = isCur and theme.color.tabActiveText or theme.color.sideBarText,
					text = "    " .. (tab.dirty and "● " or "  ") .. tab.title,
					order = idx,
					zIndex = 24,
					activeState = function() return isCur end,
					onClick = function() codeStore.activate(tab.id) end,
				})
				row.TextTruncate = Enum.TextTruncate.AtEnd
			end
		end

		codeStore.changed:connect(renderOpenEditors)
		workspaceFs.changed:connect(function()
			wsHeaderLbl.Text = "▾ WORKSPACE: " .. workspaceFs.activeName:upper()
		end)
		theme.changed:connect(function()
			openHeader.BackgroundColor3 = theme.color.sideBarHeader
			wsHeader.BackgroundColor3 = theme.color.sideBarHeader
			gameBtn.BackgroundColor3 = theme.color.sideBarHeader
			renderOpenEditors()
			if gameExpanded then renderGameTree() end
		end)

		renderOpenEditors()
		return {
			root = root,
			fileTree = fileTree,
		}
	end

	return M
end
end)()

-- [ui/panels/extensions] (4293 bytes)
__VSRBLX_MODULES["ui/panels/extensions"] = (function()
-- VS Code Extensions, Language Packs & Executor Capability Matrix Viewlet (`Ctrl+Shift+X`).
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local icons = env.require("ui/icons")
	local caps = env.require("runtime/caps")
	local languages = env.require("runtime/languages")
	local overlay = env.require("ui/overlay")

	local M = {}

	function M.new(parent)
		local root = P.frame(parent, {
			name = "ExtensionsViewlet",
			size = UDim2.fromScale(1, 1),
			visible = false,
			zIndex = 21,
		})
		P.pad(root, 6, 10, 6, 10)

		P.label(root, {
			size = UDim2.new(1, 0, 0, 22),
			text = "EXTENSIONS & LANGUAGES",
			bold = true,
			textSize = 11,
			color = theme.color.muted,
			zIndex = 22,
		})

		local scroll = P.scroll(root, {
			name = "ExtensionsScroll",
			size = UDim2.new(1, 0, 1, -26),
			pos = UDim2.fromOffset(0, 26),
			zIndex = 22,
		})
		P.list(scroll, Enum.FillDirection.Vertical, 4)

		local ord = 0
		local function addSection(title)
			ord = ord + 1
			P.label(scroll, {
				size = UDim2.new(1, 0, 0, 22),
				bold = true,
				textSize = 11,
				color = theme.color.tabActiveText,
				text = "▾ " .. title,
				order = ord,
				zIndex = 23,
			})
		end

		-- 1. Executor Capabilities
		addSection("EXECUTOR HOST CAPABILITIES (" .. caps.executor .. ")")
		local capRows = {
			{ name = "Local Disk File Read/Write", detail = "writefile / readfile", ok = caps.has("fs") },
			{ name = "Local Disk Folder Tree", detail = "listfiles / makefolder", ok = caps.has("fsTree") },
			{ name = "GitHub HTTP Request API", detail = tostring(caps.requestName or caps.http), ok = caps.has("httpRequest") or caps.has("httpGet") },
			{ name = "Luau Compiler & Runner", detail = "loadstring", ok = caps.has("loadstring") },
			{ name = "System Clipboard", detail = "setclipboard", ok = caps.has("clipboard") },
			{ name = "Instance Script Decompiler", detail = "decompile", ok = caps.has("decompile") },
		}
		for _, c in ipairs(capRows) do
			ord = ord + 1
			local card = P.frame(scroll, {
				size = UDim2.new(1, 0, 0, 34),
				bg = theme.color.inputBg,
				radius = 4,
				order = ord,
				zIndex = 23,
			})
			P.label(card, {
				size = UDim2.new(1, -66, 0, 18),
				pos = UDim2.fromOffset(8, 2),
				bold = true,
				textSize = 11,
				color = theme.color.tabActiveText,
				text = c.name,
				truncate = true,
				zIndex = 24,
			})
			P.label(card, {
				size = UDim2.new(1, -66, 0, 14),
				pos = UDim2.fromOffset(8, 18),
				mono = true,
				textSize = 10,
				color = theme.color.muted,
				text = c.detail,
				zIndex = 24,
			})
			P.label(card, {
				size = UDim2.fromOffset(56, 34),
				pos = UDim2.new(1, -60, 0, 0),
				bold = true,
				textSize = 10,
				alignX = Enum.TextXAlignment.Right,
				color = c.ok and theme.color.good or theme.color.warn,
				text = c.ok and "ACTIVE" or "FALLBACK",
				zIndex = 24,
			})
		end

		-- 2. Color Themes
		addSection("INSTALLED COLOR THEMES (8)")
		for _, t in ipairs(theme.list()) do
			ord = ord + 1
			local themeId = t.id
			P.button(scroll, {
				size = UDim2.new(1, 0, 0, 26),
				bg = theme.color.inputBg,
				hoverBg = theme.color.listActive,
				alignX = Enum.TextXAlignment.Left,
				textSize = 12,
				color = theme.color.sideBarText,
				text = "  🎨  " .. t.label,
				radius = 4,
				order = ord,
				zIndex = 23,
				onClick = function()
					theme.apply(themeId)
					overlay.toast("Applied theme: " .. t.label, "good", 2)
				end,
			})
		end

		-- 3. Built-in Multi-Language Support
		addSection(string.format("BUILT-IN LANGUAGE MODES (%d)", #languages.list))
		for _, lang in ipairs(languages.list) do
			ord = ord + 1
			local row = P.frame(scroll, {
				size = UDim2.new(1, 0, 0, 26),
				bg = theme.color.inputBg,
				radius = 4,
				order = ord,
				zIndex = 23,
			})
			local b = icons.fileBadge(row, lang, false, 24)
			b.Position = UDim2.fromOffset(6, 6)
			local extLabel = (#(lang.extensions or {}) > 0) and ("  (." .. table.concat(lang.extensions, ", .") .. ")") or ""
			P.label(row, {
				size = UDim2.new(1, -44, 1, 0),
				pos = UDim2.fromOffset(36, 0),
				textSize = 11,
				color = theme.color.sideBarText,
				text = lang.name .. extLabel,
				truncate = true,
				zIndex = 24,
			})
		end

		return { root = root }
	end

	return M
end
end)()

-- [ui/panels/github_connect] (7092 bytes)
__VSRBLX_MODULES["ui/panels/github_connect"] = (function()
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
end)()

-- [ui/panels/scm] (8566 bytes)
__VSRBLX_MODULES["ui/panels/scm"] = (function()
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
end)()

-- [ui/panels/search] (5164 bytes)
__VSRBLX_MODULES["ui/panels/search"] = (function()
-- VS Code Workspace Search & Replace Sidebar Viewlet (`Ctrl+Shift+F`).
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local overlay = env.require("ui/overlay")
	local util = env.require("runtime/util")
	local codeSearch = env.require("runtime/code_search")
	local codeStore = env.require("runtime/code_store")

	local M = {}

	function M.new(parent)
		local root = P.frame(parent, {
			name = "SearchViewlet",
			size = UDim2.fromScale(1, 1),
			visible = false,
			zIndex = 21,
		})
		P.pad(root, 6, 10, 6, 10)

		P.label(root, {
			size = UDim2.new(1, 0, 0, 22),
			text = "SEARCH",
			bold = true,
			textSize = 11,
			color = theme.color.muted,
			zIndex = 22,
		})

		local _, queryBox = P.input(root, {
			name = "WorkspaceSearchInput",
			size = UDim2.new(1, 0, 0, 26),
			pos = UDim2.fromOffset(0, 26),
			placeholder = "Search across files...",
			zIndex = 22,
		})

		local _, replaceBox = P.input(root, {
			name = "WorkspaceReplaceInput",
			size = UDim2.new(1, 0, 0, 26),
			pos = UDim2.fromOffset(0, 56),
			placeholder = "Replace with...",
			zIndex = 22,
		})

		local optsRow = P.frame(root, {
			size = UDim2.new(1, 0, 0, 26),
			pos = UDim2.fromOffset(0, 86),
			zIndex = 22,
		})
		P.list(optsRow, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

		local caseSensitive = false
		local wholeWord = false

		local caseBtn = P.button(optsRow, {
			size = UDim2.fromOffset(30, 22),
			bg = theme.color.inputBg,
			text = "Aa",
			mono = true,
			textSize = 11,
			radius = 3,
			order = 1,
			zIndex = 23,
		})
		local wordBtn = P.button(optsRow, {
			size = UDim2.fromOffset(32, 22),
			bg = theme.color.inputBg,
			text = "[ab]",
			mono = true,
			textSize = 10,
			radius = 3,
			order = 2,
			zIndex = 23,
		})
		local replaceAllBtn = P.button(optsRow, {
			name = "WorkspaceReplaceAllBtn",
			size = UDim2.fromOffset(92, 22),
			bg = theme.color.accent,
			hoverBg = theme.color.accentHover,
			color = Color3.fromRGB(255, 255, 255),
			text = "Replace All",
			textSize = 11,
			radius = 3,
			order = 3,
			zIndex = 23,
		})

		local statusLbl = P.label(root, {
			size = UDim2.new(1, 0, 0, 18),
			pos = UDim2.fromOffset(0, 114),
			text = "Type a query to search workspace files.",
			textSize = 11,
			color = theme.color.muted,
			zIndex = 22,
		})

		local resultsScroll = P.scroll(root, {
			name = "SearchResultsScroll",
			size = UDim2.new(1, 0, 1, -136),
			pos = UDim2.fromOffset(0, 136),
			zIndex = 22,
		})
		P.list(resultsScroll, Enum.FillDirection.Vertical, 2)

		local function runSearch()
			resultsScroll:ClearAllChildren()
			P.list(resultsScroll, Enum.FillDirection.Vertical, 2)
			local q = queryBox.Text
			if q == "" then
				statusLbl.Text = "Type a query to search workspace files."
				return
			end
			local scan = codeSearch.searchWorkspace(q, {
				caseSensitive = caseSensitive,
				wholeWord = wholeWord,
			})
			statusLbl.Text = string.format("%d result(s) in %d file(s)", scan.totalMatches, #scan.files)

			local ord = 0
			for _, fileGroup in ipairs(scan.files) do
				ord = ord + 1
				P.label(resultsScroll, {
					size = UDim2.new(1, 0, 0, 20),
					bold = true,
					textSize = 11,
					color = theme.color.tabActiveText,
					text = string.format("▾ %s (%d)", fileGroup.path, #fileGroup.matches),
					truncate = true,
					order = ord,
					zIndex = 23,
				})
				for _, hit in ipairs(fileGroup.matches) do
					if ord < 160 then
						ord = ord + 1
						local targetPath = fileGroup.path
						local targetLn, targetCol = hit.line, hit.col
						local hitBtn = P.button(resultsScroll, {
							size = UDim2.new(1, 0, 0, 20),
							hoverBg = theme.color.hover,
							alignX = Enum.TextXAlignment.Left,
							mono = true,
							textSize = 11,
							color = theme.color.sideBarText,
							text = string.format("  %3d: %s", hit.line, util.trim(hit.lineText)),
							order = ord,
							zIndex = 23,
							onClick = function()
								codeStore.openFile(targetPath, { line = targetLn, col = targetCol })
							end,
						})
						hitBtn.TextTruncate = Enum.TextTruncate.AtEnd
					end
				end
			end
		end

		caseBtn.Activated:Connect(function()
			caseSensitive = not caseSensitive
			caseBtn.BackgroundColor3 = caseSensitive and theme.color.accent or theme.color.inputBg
			runSearch()
		end)
		wordBtn.Activated:Connect(function()
			wholeWord = not wholeWord
			wordBtn.BackgroundColor3 = wholeWord and theme.color.accent or theme.color.inputBg
			runSearch()
		end)
		queryBox:GetPropertyChangedSignal("Text"):Connect(runSearch)

		replaceAllBtn.Activated:Connect(function()
			if queryBox.Text == "" then return end
			local filesChanged, totalRep = codeSearch.replaceAcrossWorkspace(queryBox.Text, replaceBox.Text, {
				caseSensitive = caseSensitive,
				wholeWord = wholeWord,
			})
			overlay.toast(string.format("Replaced %d occurrence(s) across %d file(s)", totalRep, filesChanged), "good", 3)
			runSearch()
		end)

		return {
			root = root,
			focus = function()
				task.defer(function() pcall(function() queryBox:CaptureFocus() end) end)
			end,
		}
	end

	return M
end
end)()

-- [ui/panels/settings] (4168 bytes)
__VSRBLX_MODULES["ui/panels/settings"] = (function()
-- VS Code Settings Sidebar Viewlet (`Ctrl+,`) backed by `runtime/settings_catalog` & `config`.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local config = env.require("runtime/config")
	local catalog = env.require("runtime/settings_catalog")

	local M = {}

	function M.new(parent)
		local root = P.frame(parent, {
			name = "SettingsViewlet",
			size = UDim2.fromScale(1, 1),
			visible = false,
			zIndex = 21,
		})
		P.pad(root, 6, 10, 6, 10)

		P.label(root, {
			size = UDim2.new(1, 0, 0, 22),
			text = "SETTINGS",
			bold = true,
			textSize = 11,
			color = theme.color.muted,
			zIndex = 22,
		})

		local _, filterBox = P.input(root, {
			name = "SettingsFilterInput",
			size = UDim2.new(1, 0, 0, 26),
			pos = UDim2.fromOffset(0, 26),
			placeholder = "Search settings...",
			zIndex = 22,
		})

		local scroll = P.scroll(root, {
			name = "SettingsScroll",
			size = UDim2.new(1, 0, 1, -60),
			pos = UDim2.fromOffset(0, 58),
			zIndex = 22,
		})
		P.list(scroll, Enum.FillDirection.Vertical, 6)

		local function rebuild()
			scroll:ClearAllChildren()
			P.list(scroll, Enum.FillDirection.Vertical, 6)
			local list = catalog.search(filterBox.Text)
			for idx, item in ipairs(list) do
				local card = P.frame(scroll, {
					size = UDim2.new(1, 0, 0, 58),
					bg = theme.color.inputBg,
					radius = 4,
					order = idx,
					zIndex = 23,
				})
				P.pad(card, 6, 8, 6, 8)
				P.label(card, {
					size = UDim2.new(1, -90, 0, 18),
					bold = true,
					textSize = 12,
					color = theme.color.tabActiveText,
					text = item.title or item.key,
					truncate = true,
					zIndex = 24,
				})
				P.label(card, {
					size = UDim2.new(1, -90, 0, 24),
					pos = UDim2.fromOffset(0, 20),
					textSize = 10,
					color = theme.color.muted,
					text = item.description or "",
					wrap = true,
					zIndex = 24,
				})

				local curVal = config.get(item.key)
				if item.kind == "boolean" then
					P.button(card, {
						size = UDim2.fromOffset(72, 24),
						pos = UDim2.new(1, -72, 0, 10),
						bg = curVal and theme.color.accent or theme.color.sideBar,
						color = Color3.fromRGB(255, 255, 255),
						bold = true,
						text = curVal and "ON" or "OFF",
						textSize = 11,
						radius = 4,
						zIndex = 24,
						onClick = function()
							config.set(item.key, not curVal)
						end,
					})
				elseif item.kind == "number" then
					P.button(card, {
						size = UDim2.fromOffset(24, 24),
						pos = UDim2.new(1, -76, 0, 10),
						bg = theme.color.sideBar,
						text = "−",
						radius = 3,
						zIndex = 24,
						onClick = function()
							local nextN = math.max(item.min or 1, (tonumber(curVal) or 14) - (item.step or 1))
							config.set(item.key, nextN)
						end,
					})
					P.label(card, {
						size = UDim2.fromOffset(26, 24),
						pos = UDim2.new(1, -50, 0, 10),
						mono = true,
						textSize = 11,
						alignX = Enum.TextXAlignment.Center,
						text = tostring(curVal),
						zIndex = 24,
					})
					P.button(card, {
						size = UDim2.fromOffset(24, 24),
						pos = UDim2.new(1, -24, 0, 10),
						bg = theme.color.sideBar,
						text = "+",
						radius = 3,
						zIndex = 24,
						onClick = function()
							local nextN = math.min(item.max or 99, (tonumber(curVal) or 14) + (item.step or 1))
							config.set(item.key, nextN)
						end,
					})
				elseif item.kind == "select" and item.options then
					P.button(card, {
						size = UDim2.fromOffset(82, 24),
						pos = UDim2.new(1, -82, 0, 10),
						bg = theme.color.sideBar,
						textSize = 10,
						text = tostring(curVal),
						radius = 4,
						zIndex = 24,
						onClick = function()
							local curIdx = 1
							for oi, opt in ipairs(item.options) do
								if opt.value == curVal then curIdx = oi; break end
							end
							local nextOpt = item.options[(curIdx % #item.options) + 1]
							config.set(item.key, nextOpt.value)
						end,
					})
				end
			end
		end

		filterBox:GetPropertyChangedSignal("Text"):Connect(rebuild)
		config.changed:connect(rebuild)
		theme.changed:connect(rebuild)

		rebuild()
		return { root = root, refresh = rebuild }
	end

	return M
end
end)()

-- [ui/primitives] (7249 bytes)
__VSRBLX_MODULES["ui/primitives"] = (function()
-- Clean Roblox UI constructor primitives for VS-RBLX panels, buttons, inputs, and scrollbars.
return function(env)
	local theme = env.require("ui/theme")
	local P = {}

	function P.corner(inst, radius)
		local c = Instance.new("UICorner", inst)
		c.CornerRadius = UDim.new(0, radius or 4)
		return c
	end

	function P.stroke(inst, color, thickness)
		local s = Instance.new("UIStroke", inst)
		s.Color = color or theme.color.border
		s.Thickness = thickness or 1
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		return s
	end

	function P.pad(inst, top, right, bottom, left)
		local p = Instance.new("UIPadding", inst)
		p.PaddingTop = UDim.new(0, top or 0)
		p.PaddingRight = UDim.new(0, right or top or 0)
		p.PaddingBottom = UDim.new(0, bottom or top or 0)
		p.PaddingLeft = UDim.new(0, left or right or top or 0)
		return p
	end

	function P.list(inst, dir, gap, hAlign, vAlign)
		local l = Instance.new("UIListLayout", inst)
		l.FillDirection = dir or Enum.FillDirection.Vertical
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.Padding = UDim.new(0, gap or 0)
		if hAlign then l.HorizontalAlignment = hAlign end
		if vAlign then l.VerticalAlignment = vAlign end
		return l
	end

	function P.frame(parent, props)
		props = props or {}
		local f = Instance.new("Frame", parent)
		f.Name = props.name or "Frame"
		f.BorderSizePixel = 0
		f.Size = props.size or UDim2.fromScale(1, 1)
		f.Position = props.pos or UDim2.fromOffset(0, 0)
		if props.anchor then f.AnchorPoint = props.anchor end
		if props.bg then
			f.BackgroundColor3 = props.bg
			f.BackgroundTransparency = props.transparency or 0
		else
			f.BackgroundTransparency = 1
		end
		if props.clip then f.ClipsDescendants = true end
		if props.zIndex then f.ZIndex = props.zIndex end
		if props.order then f.LayoutOrder = props.order end
		if props.visible ~= nil then f.Visible = props.visible end
		if props.active ~= nil then f.Active = props.active end
		if props.radius then P.corner(f, props.radius) end
		if props.border then P.stroke(f, props.border, props.borderWidth) end
		return f
	end

	function P.label(parent, props)
		props = props or {}
		local lbl = Instance.new("TextLabel", parent)
		lbl.Name = props.name or "Label"
		lbl.BorderSizePixel = 0
		lbl.BackgroundTransparency = props.bg and (props.transparency or 0) or 1
		if props.bg then lbl.BackgroundColor3 = props.bg end
		lbl.Size = props.size or UDim2.new(1, 0, 0, 20)
		lbl.Position = props.pos or UDim2.fromOffset(0, 0)
		lbl.Font = props.mono and theme.font.mono or (props.bold and theme.font.uiBold or theme.font.ui)
		lbl.TextSize = props.textSize or theme.sizes.uiFont
		lbl.TextColor3 = props.color or theme.color.sideBarText
		lbl.Text = tostring(props.text or "")
		lbl.RichText = props.rich == true
		lbl.TextWrapped = props.wrap == true
		lbl.TextTruncate = props.truncate and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None
		lbl.TextXAlignment = props.alignX or Enum.TextXAlignment.Left
		lbl.TextYAlignment = props.alignY or Enum.TextYAlignment.Center
		if props.zIndex then lbl.ZIndex = props.zIndex end
		if props.order then lbl.LayoutOrder = props.order end
		if props.visible ~= nil then lbl.Visible = props.visible end
		return lbl
	end

	function P.button(parent, props)
		props = props or {}
		local btn = Instance.new("TextButton", parent)
		btn.Name = props.name or "Button"
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = false
		local baseBg = props.bg
		local hoverBg = props.hoverBg or theme.color.hover
		btn.BackgroundColor3 = baseBg or hoverBg
		btn.BackgroundTransparency = baseBg and (props.transparency or 0) or 1
		btn.Size = props.size or UDim2.fromOffset(80, 26)
		btn.Position = props.pos or UDim2.fromOffset(0, 0)
		btn.Font = props.mono and theme.font.mono or (props.bold and theme.font.uiMedium or theme.font.ui)
		btn.TextSize = props.textSize or theme.sizes.uiFont
		btn.TextColor3 = props.color or theme.color.sideBarText
		btn.Text = tostring(props.text or "")
		btn.TextXAlignment = props.alignX or Enum.TextXAlignment.Center
		if props.zIndex then btn.ZIndex = props.zIndex end
		if props.order then btn.LayoutOrder = props.order end
		if props.visible ~= nil then btn.Visible = props.visible end
		if props.radius then P.corner(btn, props.radius) end
		if props.border then P.stroke(btn, props.border, 1) end

		btn.MouseEnter:Connect(function()
			if props.activeState and props.activeState() then return end
			btn.BackgroundColor3 = hoverBg
			btn.BackgroundTransparency = 0
		end)
		btn.MouseLeave:Connect(function()
			if props.activeState and props.activeState() then return end
			if baseBg then
				btn.BackgroundColor3 = baseBg
				btn.BackgroundTransparency = props.transparency or 0
			else
				btn.BackgroundTransparency = 1
			end
		end)
		if props.onClick then
			btn.Activated:Connect(props.onClick)
		end
		return btn
	end

	function P.input(parent, props)
		props = props or {}
		local wrap = P.frame(parent, {
			name = props.name or "InputWrap",
			size = props.size or UDim2.new(1, 0, 0, 26),
			pos = props.pos,
			bg = props.bg or theme.color.inputBg,
			radius = 3,
			order = props.order,
			zIndex = props.zIndex,
		})
		local borderStroke = P.stroke(wrap, theme.color.inputBorder, 1)
		P.pad(wrap, 0, 6, 0, 6)

		local box = Instance.new("TextBox", wrap)
		box.Name = "Field"
		box.BorderSizePixel = 0
		box.BackgroundTransparency = 1
		box.Size = UDim2.fromScale(1, 1)
		box.ClearTextOnFocus = false
		box.MultiLine = props.multiLine == true
		box.Font = props.mono and theme.font.mono or theme.font.ui
		box.TextSize = props.textSize or theme.sizes.uiFont
		box.TextColor3 = theme.color.editorText
		box.PlaceholderText = props.placeholder or ""
		box.PlaceholderColor3 = theme.color.muted
		box.Text = props.value or ""
		box.TextXAlignment = Enum.TextXAlignment.Left
		box.TextYAlignment = props.multiLine and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
		if props.zIndex then box.ZIndex = props.zIndex + 1 end

		box.Focused:Connect(function()
			borderStroke.Color = theme.color.inputFocus
		end)
		box.FocusLost:Connect(function(enterPressed)
			borderStroke.Color = theme.color.inputBorder
			if props.onSubmit and enterPressed then
				props.onSubmit(box.Text)
			end
			if props.onFocusLost then
				props.onFocusLost(box.Text, enterPressed)
			end
		end)
		if props.onChange then
			box:GetPropertyChangedSignal("Text"):Connect(function()
				props.onChange(box.Text)
			end)
		end
		return wrap, box
	end

	function P.scroll(parent, props)
		props = props or {}
		local sf = Instance.new("ScrollingFrame", parent)
		sf.Name = props.name or "Scroll"
		sf.BorderSizePixel = 0
		sf.Size = props.size or UDim2.fromScale(1, 1)
		sf.Position = props.pos or UDim2.fromOffset(0, 0)
		sf.BackgroundTransparency = props.bg and 0 or 1
		if props.bg then sf.BackgroundColor3 = props.bg end
		sf.ScrollBarThickness = props.barThickness or 6
		sf.ScrollBarImageColor3 = theme.color.muted
		sf.CanvasSize = props.canvasSize or UDim2.fromOffset(0, 0)
		sf.AutomaticCanvasSize = props.autoCanvas or Enum.AutomaticSize.Y
		sf.ScrollingDirection = props.direction or Enum.ScrollingDirection.Y
		if props.zIndex then sf.ZIndex = props.zIndex end
		if props.order then sf.LayoutOrder = props.order end
		return sf
	end

	return P
end
end)()

-- [ui/responsive] (1917 bytes)
__VSRBLX_MODULES["ui/responsive"] = (function()
-- Viewport observer & safe usable-area calculator powering VS-RBLX's auto-resized window.
return function(env)
	local signal = env.require("runtime/signal")
	local dispose = env.require("runtime/dispose")

	local M = {
		viewport = Vector2.new(1280, 720),
		compact = false,
		changed = signal.new("responsive.changed"),
	}

	local camConn = nil

	local function readViewport()
		local ws = env.services.Workspace
		local cam = ws and ws.CurrentCamera or nil
		if cam and cam.ViewportSize and cam.ViewportSize.X > 0 and cam.ViewportSize.Y > 0 then
			M.viewport = cam.ViewportSize
		end
		M.compact = M.viewport.X < 860 or M.viewport.Y < 540
	end

	local function bindCamera()
		if camConn then
			pcall(function() camConn:Disconnect() end)
			camConn = nil
		end
		local ws = env.services.Workspace
		local cam = ws and ws.CurrentCamera or nil
		if cam then
			readViewport()
			camConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				readViewport()
				M.changed:fire(M.viewport)
			end)
			dispose.connection(camConn)
		end
	end

	bindCamera()
	local ws = env.services.Workspace
	if ws then
		pcall(function()
			dispose.connection(ws:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
				bindCamera()
				M.changed:fire(M.viewport)
			end))
		end)
	end

	function M.usableRect(margin)
		readViewport()
		local pad = tonumber(margin) or 8
		local topInset = 0
		if env.guisvc and type(env.guisvc.GetGuiInset) == "function" then
			local ok, insetTop = pcall(function() return env.guisvc:GetGuiInset() end)
			if ok and insetTop then
				topInset = math.max(0, insetTop.Y)
			end
		end
		local x = pad
		local y = pad
		local w = math.max(360, M.viewport.X - pad * 2)
		local h = math.max(260, M.viewport.Y - topInset - pad * 2)
		return {
			x = x,
			y = y,
			width = w,
			height = h,
			viewportX = M.viewport.X,
			viewportY = M.viewport.Y - topInset,
		}
	end

	return M
end
end)()

-- [ui/statusbar] (6178 bytes)
__VSRBLX_MODULES["ui/statusbar"] = (function()
-- Authentic VS Code 22px Bottom Status Bar:
-- Left: Executor Host / Disk indicator, Git branch, Sync button, Error/Warn counts.
-- Right: Cursor Ln/Col, Spaces/Tab size, UTF-8, LF, Language Mode Picker, Notifications.
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
			size = UDim2.new(0.55, 0, 1, 0),
			zIndex = 31,
		})
		P.list(leftRow, Enum.FillDirection.Horizontal, 2, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

		local hostPill = P.button(leftRow, {
			name = "HostBadge",
			size = UDim2.fromOffset(142, h),
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
			size = UDim2.fromOffset(115, h),
			color = theme.color.statusBarText,
			textSize = 11,
			text = "⎇ main",
			order = 2,
			zIndex = 32,
			onClick = function() commands.run("view.scm") end,
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

		local problemsBtn = P.button(leftRow, {
			name = "ProblemsBadge",
			size = UDim2.fromOffset(74, h),
			color = theme.color.statusBarText,
			textSize = 11,
			text = "⊗ 0  ⚠ 0",
			order = 4,
			zIndex = 32,
			onClick = function() commands.run("view.problems") end,
		})

		local rightRow = P.frame(bar, {
			name = "StatusRight",
			size = UDim2.new(0.45, -8, 1, 0),
			pos = UDim2.new(0.55, 0, 0, 0),
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
			size = UDim2.fromOffset(88, h),
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
		end

		codeStore.changed:connect(refresh)
		codeStore.cursorChanged:connect(refresh)
		diagnostics.changed:connect(refresh)
		gitState.changed:connect(refresh)
		githubSync.progress:connect(refresh)
		config.changed:connect(refresh)
		theme.changed:connect(function()
			bar.BackgroundColor3 = theme.color.statusBar
			hostPill.BackgroundColor3 = theme.color.statusBarRemote
			for _, w in ipairs({ hostPill, branchBtn, syncBtn, problemsBtn, cursorLbl, indentBtn, utfLbl, langBtn }) do
				w.TextColor3 = theme.color.statusBarText
			end
		end)

		refresh()
		return {
			root = bar,
			refresh = refresh,
		}
	end

	return M
end
end)()

-- [ui/theme] (16496 bytes)
__VSRBLX_MODULES["ui/theme"] = (function()
-- Authentic Visual Studio Code Color Themes & Typography Tokens for VS-RBLX.
return function(env)
	local config = env.require("runtime/config")
	local signal = env.require("runtime/signal")
	local util = env.require("runtime/util")

	local M = {
		changed = signal.new("theme.changed"),
		activeId = "dark_plus",
	}

	local function hex(h)
		return Color3.fromHex(h)
	end

	local PALETTES = {
		dark_plus = {
			name = "Dark+ (Default Dark)",
			isLight = false,
			titleBar = hex("#3c3c3c"),
			titleBarText = hex("#cccccc"),
			activityBar = hex("#333333"),
			activityIcon = hex("#858585"),
			activityIconActive = hex("#ffffff"),
			activityIndicator = hex("#007acc"),
			sideBar = hex("#252526"),
			sideBarHeader = hex("#2d2d2d"),
			sideBarText = hex("#cccccc"),
			editor = hex("#1e1e1e"),
			editorText = hex("#d4d4d4"),
			editorGutter = hex("#1e1e1e"),
			lineNumber = hex("#858585"),
			lineNumberActive = hex("#c6c6c6"),
			activeLine = hex("#282828"),
			selection = hex("#264f78"),
			findMatch = hex("#515c6a"),
			tabBar = hex("#252526"),
			tabInactive = hex("#2d2d2d"),
			tabInactiveText = hex("#969696"),
			tabActive = hex("#1e1e1e"),
			tabActiveText = hex("#ffffff"),
			tabActiveTop = hex("#007acc"),
			breadcrumbBg = hex("#1e1e1e"),
			panelBg = hex("#1e1e1e"),
			panelHeader = hex("#252526"),
			statusBar = hex("#007acc"),
			statusBarRemote = hex("#16825d"),
			statusBarText = hex("#ffffff"),
			inputBg = hex("#3c3c3c"),
			inputBorder = hex("#474747"),
			inputFocus = hex("#007fd4"),
			dropdownBg = hex("#252526"),
			hover = hex("#2a2d2e"),
			listActive = hex("#04395e"),
			border = hex("#3b3b3b"),
			accent = hex("#007acc"),
			accentHover = hex("#1177bb"),
			muted = hex("#858585"),
			good = hex("#73c991"),
			warn = hex("#cca700"),
			bad = hex("#f14c4c"),
			diffAddBg = hex("#233a27"),
			diffRemoveBg = hex("#442326"),
			syntax = {
				keyword = "#569cd6",
				builtin = "#4ec9b0",
				type = "#4ec9b0",
				string = "#ce9178",
				number = "#b5cea8",
				comment = "#6a9955",
				call = "#dcdcaa",
				property = "#9cdcfe",
				tag = "#569cd6",
				decorator = "#c586c0",
			},
		},
		one_dark = {
			name = "One Dark Pro",
			isLight = false,
			titleBar = hex("#21252b"),
			titleBarText = hex("#abb2bf"),
			activityBar = hex("#282c34"),
			activityIcon = hex("#6b717d"),
			activityIconActive = hex("#d7dae0"),
			activityIndicator = hex("#528bff"),
			sideBar = hex("#21252b"),
			sideBarHeader = hex("#282c34"),
			sideBarText = hex("#abb2bf"),
			editor = hex("#282c34"),
			editorText = hex("#abb2bf"),
			editorGutter = hex("#282c34"),
			lineNumber = hex("#495162"),
			lineNumberActive = hex("#abb2bf"),
			activeLine = hex("#2c313c"),
			selection = hex("#3e4451"),
			findMatch = hex("#42557b"),
			tabBar = hex("#21252b"),
			tabInactive = hex("#21252b"),
			tabInactiveText = hex("#6b717d"),
			tabActive = hex("#282c34"),
			tabActiveText = hex("#d7dae0"),
			tabActiveTop = hex("#528bff"),
			breadcrumbBg = hex("#282c34"),
			panelBg = hex("#21252b"),
			panelHeader = hex("#282c34"),
			statusBar = hex("#21252b"),
			statusBarRemote = hex("#528bff"),
			statusBarText = hex("#9da5b4"),
			inputBg = hex("#1d1f23"),
			inputBorder = hex("#3a3f4b"),
			inputFocus = hex("#528bff"),
			dropdownBg = hex("#21252b"),
			hover = hex("#2c313a"),
			listActive = hex("#2c313a"),
			border = hex("#181a1f"),
			accent = hex("#528bff"),
			accentHover = hex("#6796ff"),
			muted = hex("#6b717d"),
			good = hex("#98c379"),
			warn = hex("#e5c07b"),
			bad = hex("#e06c75"),
			diffAddBg = hex("#24382b"),
			diffRemoveBg = hex("#3f262a"),
			syntax = {
				keyword = "#c678dd",
				builtin = "#56b6c2",
				type = "#e5c07b",
				string = "#98c379",
				number = "#d19a66",
				comment = "#5c6370",
				call = "#61afef",
				property = "#e06c75",
				tag = "#e06c75",
				decorator = "#e5c07b",
			},
		},
		github_dark = {
			name = "GitHub Dark Default",
			isLight = false,
			titleBar = hex("#010409"),
			titleBarText = hex("#e6edf3"),
			activityBar = hex("#0d1117"),
			activityIcon = hex("#7d8590"),
			activityIconActive = hex("#e6edf3"),
			activityIndicator = hex("#f78166"),
			sideBar = hex("#010409"),
			sideBarHeader = hex("#0d1117"),
			sideBarText = hex("#c9d1d9"),
			editor = hex("#0d1117"),
			editorText = hex("#e6edf3"),
			editorGutter = hex("#0d1117"),
			lineNumber = hex("#6e7681"),
			lineNumberActive = hex("#e6edf3"),
			activeLine = hex("#161b22"),
			selection = hex("#1f6feb"),
			findMatch = hex("#3b2e00"),
			tabBar = hex("#010409"),
			tabInactive = hex("#010409"),
			tabInactiveText = hex("#7d8590"),
			tabActive = hex("#0d1117"),
			tabActiveText = hex("#e6edf3"),
			tabActiveTop = hex("#f78166"),
			breadcrumbBg = hex("#0d1117"),
			panelBg = hex("#010409"),
			panelHeader = hex("#0d1117"),
			statusBar = hex("#010409"),
			statusBarRemote = hex("#238636"),
			statusBarText = hex("#c9d1d9"),
			inputBg = hex("#0d1117"),
			inputBorder = hex("#30363d"),
			inputFocus = hex("#1f6feb"),
			dropdownBg = hex("#161b22"),
			hover = hex("#161b22"),
			listActive = hex("#1f2937"),
			border = hex("#30363d"),
			accent = hex("#2f81f7"),
			accentHover = hex("#388bfd"),
			muted = hex("#7d8590"),
			good = hex("#3fb950"),
			warn = hex("#d29922"),
			bad = hex("#f85149"),
			diffAddBg = hex("#122d1f"),
			diffRemoveBg = hex("#35191d"),
			syntax = {
				keyword = "#ff7b72",
				builtin = "#79c0ff",
				type = "#ffa657",
				string = "#a5d6ff",
				number = "#79c0ff",
				comment = "#8b949e",
				call = "#d2a8ff",
				property = "#79c0ff",
				tag = "#7ee787",
				decorator = "#ffa657",
			},
		},
		monokai = {
			name = "Monokai Classic",
			isLight = false,
			titleBar = hex("#1e1f1c"),
			titleBarText = hex("#cccccc"),
			activityBar = hex("#272822"),
			activityIcon = hex("#75715e"),
			activityIconActive = hex("#f8f8f2"),
			activityIndicator = hex("#a6e22e"),
			sideBar = hex("#1e1f1c"),
			sideBarHeader = hex("#272822"),
			sideBarText = hex("#f8f8f2"),
			editor = hex("#272822"),
			editorText = hex("#f8f8f2"),
			editorGutter = hex("#272822"),
			lineNumber = hex("#90908a"),
			lineNumberActive = hex("#f8f8f2"),
			activeLine = hex("#3e3d32"),
			selection = hex("#49483e"),
			findMatch = hex("#665c33"),
			tabBar = hex("#1e1f1c"),
			tabInactive = hex("#1e1f1c"),
			tabInactiveText = hex("#88846f"),
			tabActive = hex("#272822"),
			tabActiveText = hex("#f8f8f2"),
			tabActiveTop = hex("#a6e22e"),
			breadcrumbBg = hex("#272822"),
			panelBg = hex("#1e1f1c"),
			panelHeader = hex("#272822"),
			statusBar = hex("#414339"),
			statusBarRemote = hex("#75715e"),
			statusBarText = hex("#f8f8f2"),
			inputBg = hex("#3e3d32"),
			inputBorder = hex("#555549"),
			inputFocus = hex("#a6e22e"),
			dropdownBg = hex("#1e1f1c"),
			hover = hex("#3e3d32"),
			listActive = hex("#49483e"),
			border = hex("#34352f"),
			accent = hex("#a6e22e"),
			accentHover = hex("#b6f23e"),
			muted = hex("#75715e"),
			good = hex("#a6e22e"),
			warn = hex("#e6db74"),
			bad = hex("#f92672"),
			diffAddBg = hex("#2b3b24"),
			diffRemoveBg = hex("#42232c"),
			syntax = {
				keyword = "#f92672",
				builtin = "#66d9ef",
				type = "#66d9ef",
				string = "#e6db74",
				number = "#ae81ff",
				comment = "#75715e",
				call = "#a6e22e",
				property = "#fd971f",
				tag = "#f92672",
				decorator = "#ae81ff",
			},
		},
		dracula = {
			name = "Dracula Official",
			isLight = false,
			titleBar = hex("#21222c"),
			titleBarText = hex("#f8f8f2"),
			activityBar = hex("#282a36"),
			activityIcon = hex("#6272a4"),
			activityIconActive = hex("#f8f8f2"),
			activityIndicator = hex("#ff79c6"),
			sideBar = hex("#21222c"),
			sideBarHeader = hex("#282a36"),
			sideBarText = hex("#f8f8f2"),
			editor = hex("#282a36"),
			editorText = hex("#f8f8f2"),
			editorGutter = hex("#282a36"),
			lineNumber = hex("#6272a4"),
			lineNumberActive = hex("#f8f8f2"),
			activeLine = hex("#343746"),
			selection = hex("#44475a"),
			findMatch = hex("#5a5278"),
			tabBar = hex("#191a21"),
			tabInactive = hex("#21222c"),
			tabInactiveText = hex("#6272a4"),
			tabActive = hex("#282a36"),
			tabActiveText = hex("#f8f8f2"),
			tabActiveTop = hex("#ff79c6"),
			breadcrumbBg = hex("#282a36"),
			panelBg = hex("#21222c"),
			panelHeader = hex("#282a36"),
			statusBar = hex("#191a21"),
			statusBarRemote = hex("#bd93f9"),
			statusBarText = hex("#f8f8f2"),
			inputBg = hex("#282a36"),
			inputBorder = hex("#44475a"),
			inputFocus = hex("#bd93f9"),
			dropdownBg = hex("#21222c"),
			hover = hex("#343746"),
			listActive = hex("#44475a"),
			border = hex("#44475a"),
			accent = hex("#bd93f9"),
			accentHover = hex("#cfa9ff"),
			muted = hex("#6272a4"),
			good = hex("#50fa7b"),
			warn = hex("#f1fa8c"),
			bad = hex("#ff5555"),
			diffAddBg = hex("#213d2e"),
			diffRemoveBg = hex("#46242b"),
			syntax = {
				keyword = "#ff79c6",
				builtin = "#8be9fd",
				type = "#8be9fd",
				string = "#f1fa8c",
				number = "#bd93f9",
				comment = "#6272a4",
				call = "#50fa7b",
				property = "#ffb86c",
				tag = "#ff79c6",
				decorator = "#50fa7b",
			},
		},
		catppuccin = {
			name = "Catppuccin Mocha",
			isLight = false,
			titleBar = hex("#11111b"),
			titleBarText = hex("#cdd6f4"),
			activityBar = hex("#181825"),
			activityIcon = hex("#6c7086"),
			activityIconActive = hex("#cba6f7"),
			activityIndicator = hex("#cba6f7"),
			sideBar = hex("#181825"),
			sideBarHeader = hex("#1e1e2e"),
			sideBarText = hex("#cdd6f4"),
			editor = hex("#1e1e2e"),
			editorText = hex("#cdd6f4"),
			editorGutter = hex("#1e1e2e"),
			lineNumber = hex("#6c7086"),
			lineNumberActive = hex("#cba6f7"),
			activeLine = hex("#2a2b3d"),
			selection = hex("#45475a"),
			findMatch = hex("#585b70"),
			tabBar = hex("#11111b"),
			tabInactive = hex("#181825"),
			tabInactiveText = hex("#6c7086"),
			tabActive = hex("#1e1e2e"),
			tabActiveText = hex("#cdd6f4"),
			tabActiveTop = hex("#cba6f7"),
			breadcrumbBg = hex("#1e1e2e"),
			panelBg = hex("#181825"),
			panelHeader = hex("#1e1e2e"),
			statusBar = hex("#11111b"),
			statusBarRemote = hex("#89b4fa"),
			statusBarText = hex("#cdd6f4"),
			inputBg = hex("#313244"),
			inputBorder = hex("#45475a"),
			inputFocus = hex("#89b4fa"),
			dropdownBg = hex("#181825"),
			hover = hex("#313244"),
			listActive = hex("#313244"),
			border = hex("#313244"),
			accent = hex("#89b4fa"),
			accentHover = hex("#b4befe"),
			muted = hex("#6c7086"),
			good = hex("#a6e3a1"),
			warn = hex("#f9e2af"),
			bad = hex("#f38ba8"),
			diffAddBg = hex("#24392e"),
			diffRemoveBg = hex("#3e2430"),
			syntax = {
				keyword = "#cba6f7",
				builtin = "#89dceb",
				type = "#f9e2af",
				string = "#a6e3a1",
				number = "#fab387",
				comment = "#6c7086",
				call = "#89b4fa",
				property = "#f5c2e7",
				tag = "#f38ba8",
				decorator = "#f9e2af",
			},
		},
		solarized_dark = {
			name = "Solarized Dark",
			isLight = false,
			titleBar = hex("#00212b"),
			titleBarText = hex("#93a1a1"),
			activityBar = hex("#002b36"),
			activityIcon = hex("#586e75"),
			activityIconActive = hex("#fdf6e3"),
			activityIndicator = hex("#268bd2"),
			sideBar = hex("#00212b"),
			sideBarHeader = hex("#073642"),
			sideBarText = hex("#93a1a1"),
			editor = hex("#002b36"),
			editorText = hex("#839496"),
			editorGutter = hex("#002b36"),
			lineNumber = hex("#586e75"),
			lineNumberActive = hex("#93a1a1"),
			activeLine = hex("#073642"),
			selection = hex("#073642"),
			findMatch = hex("#1c4c59"),
			tabBar = hex("#00212b"),
			tabInactive = hex("#00212b"),
			tabInactiveText = hex("#586e75"),
			tabActive = hex("#002b36"),
			tabActiveText = hex("#fdf6e3"),
			tabActiveTop = hex("#268bd2"),
			breadcrumbBg = hex("#002b36"),
			panelBg = hex("#00212b"),
			panelHeader = hex("#073642"),
			statusBar = hex("#00212b"),
			statusBarRemote = hex("#2aa198"),
			statusBarText = hex("#93a1a1"),
			inputBg = hex("#073642"),
			inputBorder = hex("#586e75"),
			inputFocus = hex("#268bd2"),
			dropdownBg = hex("#00212b"),
			hover = hex("#073642"),
			listActive = hex("#073642"),
			border = hex("#073642"),
			accent = hex("#268bd2"),
			accentHover = hex("#2aa198"),
			muted = hex("#586e75"),
			good = hex("#859900"),
			warn = hex("#b58900"),
			bad = hex("#dc322f"),
			diffAddBg = hex("#0d3d33"),
			diffRemoveBg = hex("#3d1f26"),
			syntax = {
				keyword = "#859900",
				builtin = "#268bd2",
				type = "#b58900",
				string = "#2aa198",
				number = "#d33682",
				comment = "#586e75",
				call = "#268bd2",
				property = "#93a1a1",
				tag = "#268bd2",
				decorator = "#cb4b16",
			},
		},
		light_plus = {
			name = "Light+ (Default Light)",
			isLight = true,
			titleBar = hex("#dddddd"),
			titleBarText = hex("#333333"),
			activityBar = hex("#2c2c2c"),
			activityIcon = hex("#858585"),
			activityIconActive = hex("#ffffff"),
			activityIndicator = hex("#007acc"),
			sideBar = hex("#f3f3f3"),
			sideBarHeader = hex("#eaeaea"),
			sideBarText = hex("#383838"),
			editor = hex("#ffffff"),
			editorText = hex("#1f1f1f"),
			editorGutter = hex("#ffffff"),
			lineNumber = hex("#237893"),
			lineNumberActive = hex("#0b216f"),
			activeLine = hex("#f5f5f5"),
			selection = hex("#add6ff"),
			findMatch = hex("#f8dfa5"),
			tabBar = hex("#f3f3f3"),
			tabInactive = hex("#ececec"),
			tabInactiveText = hex("#616161"),
			tabActive = hex("#ffffff"),
			tabActiveText = hex("#1f1f1f"),
			tabActiveTop = hex("#007acc"),
			breadcrumbBg = hex("#ffffff"),
			panelBg = hex("#f8f8f8"),
			panelHeader = hex("#ececec"),
			statusBar = hex("#007acc"),
			statusBarRemote = hex("#16825d"),
			statusBarText = hex("#ffffff"),
			inputBg = hex("#ffffff"),
			inputBorder = hex("#cecece"),
			inputFocus = hex("#007acc"),
			dropdownBg = hex("#f3f3f3"),
			hover = hex("#e8e8e8"),
			listActive = hex("#d6ebff"),
			border = hex("#e0e0e0"),
			accent = hex("#007acc"),
			accentHover = hex("#005a9e"),
			muted = hex("#6e6e6e"),
			good = hex("#1a7f37"),
			warn = hex("#9a6700"),
			bad = hex("#cf222e"),
			diffAddBg = hex("#dafbe1"),
			diffRemoveBg = hex("#ffebe9"),
			syntax = {
				keyword = "#0000ff",
				builtin = "#267f99",
				type = "#267f99",
				string = "#a31515",
				number = "#098658",
				comment = "#008000",
				call = "#795e26",
				property = "#001080",
				tag = "#800000",
				decorator = "#af00db",
			},
		},
	}

	M.palettes = PALETTES
	M.color = {}
	M.syntax = {}

	local function resolveFont(candidates, fallback)
		for _, name in ipairs(candidates) do
			local ok, f = pcall(function() return Enum.Font[name] end)
			if ok and f then return f end
		end
		return fallback
	end

	M.font = {
		ui = resolveFont({ "BuilderSans", "Gotham", "SourceSans" }, Enum.Font.SourceSans),
		uiMedium = resolveFont({ "BuilderSansMedium", "GothamMedium", "SourceSansSemibold" }, Enum.Font.SourceSans),
		uiBold = resolveFont({ "BuilderSansBold", "GothamBold", "SourceSansBold" }, Enum.Font.SourceSans),
		mono = resolveFont({ "RobotoMono", "Code", "Ubuntu" }, Enum.Font.Code),
	}

	M.sizes = {
		titleBar = 32,
		activityBar = 48,
		tabBar = 35,
		breadcrumbs = 22,
		statusBar = 22,
		editorFont = 14,
		editorLineHeight = 20,
		uiFont = 13,
		smallFont = 11,
	}

	local THEME_ORDER = {
		"dark_plus",
		"one_dark",
		"github_dark",
		"monokai",
		"dracula",
		"catppuccin",
		"solarized_dark",
		"light_plus",
	}

	function M.list()
		local out = {}
		for _, id in ipairs(THEME_ORDER) do
			local p = PALETTES[id]
			if p then
				out[#out + 1] = { id = id, label = p.name, isLight = p.isLight }
			end
		end
		return out
	end

	function M.apply(explicitId)
		if type(explicitId) == "string" and PALETTES[explicitId] then
			if config.get("workbench.colorTheme", "dark_plus") ~= explicitId then
				config.set("workbench.colorTheme", explicitId)
				return true
			end
		end
		local id = tostring(config.get("workbench.colorTheme", "dark_plus") or "dark_plus")
		local pal = PALETTES[id] or PALETTES.dark_plus
		M.activeId = PALETTES[id] and id or "dark_plus"
		for k, v in pairs(pal) do
			if k ~= "syntax" then
				M.color[k] = v
			end
		end
		for k, v in pairs(pal.syntax) do
			M.syntax[k] = v
		end
		local fontSz = util.clamp(tonumber(config.get("editor.fontSize", 14)) or 14, 11, 24)
		M.sizes.editorFont = fontSz
		M.sizes.editorLineHeight = math.floor(fontSz * 1.42 + 0.5)
		return PALETTES[id] ~= nil
	end

	M.apply()
	config.changed:connect(function(key)
		if key == "*" or key == "workbench.colorTheme" or key == "editor.fontSize" then
			M.apply()
			M.changed:fire(M.activeId)
		end
	end)

	return M
end
end)()

-- [ui/titlebar] (9300 bytes)
__VSRBLX_MODULES["ui/titlebar"] = (function()
-- Authentic VS Code Title Bar: Brand Logo, Top Menu Bar (`File`, `Edit`, `View`,
-- `Run`, `GitHub`, `Help`), Centered Command Center Search Pill (`Ctrl+P`),
-- Layout Toggle Icons (Sidebar, Panel, Split), and Window Controls (─, □, ✕).
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local brand = env.require("ui/brand")
	local icons = env.require("ui/icons")
	local overlay = env.require("ui/overlay")
	local commands = env.require("runtime/command_catalog")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")

	local M = {}

	function M.new(parent, callbacks)
		callbacks = callbacks or {}
		local h = theme.sizes.titleBar

		local bar = P.frame(parent, {
			name = "TitleBar",
			size = UDim2.new(1, 0, 0, h),
			bg = theme.color.titleBar,
			active = true,
			zIndex = 30,
		})
		local bottomBorder = P.frame(bar, {
			size = UDim2.new(1, 0, 0, 1),
			pos = UDim2.new(0, 0, 1, -1),
			bg = theme.color.border,
			zIndex = 31,
		})

		local logo = brand.draw(bar, 16, 32)
		logo.Position = UDim2.fromOffset(10, math.floor((h - 16) / 2))

		-- Menu buttons
		local menuRow = P.frame(bar, {
			name = "MenuBar",
			size = UDim2.fromOffset(290, h),
			pos = UDim2.fromOffset(34, 0),
			zIndex = 32,
		})
		P.list(menuRow, Enum.FillDirection.Horizontal, 2, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

		local MENUS = {
			{
				label = "File",
				items = function()
					return {
						{ label = "New Untitled File", shortcut = "Ctrl+N", onClick = function() commands.run("file.newUntitled") end },
						{ label = "New Disk File...", shortcut = "Alt+N", onClick = function() commands.run("file.newDiskFile") end },
						{ label = "New Folder...", onClick = function() commands.run("file.newFolder") end },
						{ separator = true },
						{ label = "Open Workspace...", onClick = function() commands.run("workspace.switch") end },
						{ label = "Mount Executor Folder...", onClick = function() commands.run("workspace.mountRaw") end },
						{ separator = true },
						{ label = "Save", shortcut = "Ctrl+S", onClick = function() commands.run("file.save") end },
						{ label = "Save All to Disk", shortcut = "Ctrl+Shift+S", onClick = function() commands.run("file.saveAll") end },
						{ label = "Reload from Local Disk", onClick = function() commands.run("file.reloadDisk") end },
					}
				end,
			},
			{
				label = "Edit",
				items = function()
					return {
						{ label = "Undo", shortcut = "Ctrl+Z", onClick = function() commands.run("edit.undo") end },
						{ label = "Redo", shortcut = "Ctrl+Y", onClick = function() commands.run("edit.redo") end },
						{ separator = true },
						{ label = "Find in File", shortcut = "Ctrl+F", onClick = function() commands.run("edit.find") end },
						{ label = "Replace in File", shortcut = "Ctrl+H", onClick = function() commands.run("edit.replace") end },
						{ label = "Find in Workspace", shortcut = "Ctrl+Shift+F", onClick = function() commands.run("view.search") end },
						{ separator = true },
						{ label = "Format Document", shortcut = "Shift+Alt+F", onClick = function() commands.run("edit.format") end },
					}
				end,
			},
			{
				label = "View",
				items = function()
					return {
						{ label = "Command Palette...", shortcut = "Ctrl+Shift+P", onClick = function() commands.run("workbench.commandPalette") end },
						{ label = "Quick Open File...", shortcut = "Ctrl+P", onClick = function() commands.run("workbench.quickOpen") end },
						{ separator = true },
						{ label = "Explorer", shortcut = "Ctrl+Shift+E", onClick = function() commands.run("view.explorer") end },
						{ label = "Source Control (GitHub)", shortcut = "Ctrl+Shift+G", onClick = function() commands.run("view.scm") end },
						{ label = "Extensions & Languages", shortcut = "Ctrl+Shift+X", onClick = function() commands.run("view.extensions") end },
						{ separator = true },
						{ label = "Toggle Primary Side Bar", shortcut = "Ctrl+B", onClick = function() commands.run("view.toggleSidebar") end },
						{ label = "Toggle Terminal Panel", shortcut = "Ctrl+J", onClick = function() commands.run("view.togglePanel") end },
						{ label = "Split Editor Right", shortcut = "Ctrl+\\", onClick = function() commands.run("view.splitEditor") end },
						{ label = "Toggle Minimap", onClick = function() commands.run("view.toggleMinimap") end },
						{ label = "Reset Auto Window Size", onClick = function() commands.run("window.resetSize") end },
					}
				end,
			},
			{
				label = "Run",
				items = function()
					return {
						{ label = "Run Active Luau Script", shortcut = "F5", onClick = function() commands.run("run.active") end },
						{ label = "Stop Running Tasks", onClick = function() commands.run("run.stop") end },
						{ separator = true },
						{ label = "Open Run & Debug View", shortcut = "Ctrl+Shift+D", onClick = function() commands.run("view.debug") end },
					}
				end,
			},
			{
				label = "GitHub",
				items = function()
					return {
						{ label = "Clone / Load GitHub Repository...", onClick = function() commands.run("github.clone") end },
						{ label = "Set Personal Access Token (PAT)...", onClick = function() commands.run("github.auth") end },
						{ separator = true },
						{ label = "Pull Latest from GitHub", onClick = function() commands.run("github.pull") end },
						{ label = "Commit & Push Changes...", onClick = function() commands.run("github.push") end },
						{ label = "Create Branch...", onClick = function() commands.run("github.createBranch") end },
						{ label = "Load Raw URL / Gist...", onClick = function() commands.run("github.loadUrl") end },
					}
				end,
			},
		}

		local menuButtons = {}
		for idx, menuSpec in ipairs(MENUS) do
			local btn = P.button(menuRow, {
				name = "Menu_" .. menuSpec.label,
				size = UDim2.fromOffset(#menuSpec.label * 7 + 16, 24),
				text = menuSpec.label,
				textSize = 12,
				color = theme.color.titleBarText,
				radius = 4,
				order = idx,
				zIndex = 33,
			})
			btn.Activated:Connect(function()
				local pos = btn.AbsolutePosition
				overlay.dropdown(pos.X, pos.Y + btn.AbsoluteSize.Y + 2, menuSpec.items(), 240)
			end)
			menuButtons[#menuButtons + 1] = btn
		end

		-- Centered VS Code Command Center pill
		local centerPill = P.button(bar, {
			name = "CommandCenterPill",
			size = UDim2.fromOffset(290, 22),
			pos = UDim2.new(0.5, 0, 0.5, 0),
			anchor = Vector2.new(0.5, 0.5),
			bg = theme.color.inputBg,
			hoverBg = theme.color.hover,
			text = "",
			radius = 5,
			border = theme.color.inputBorder,
			zIndex = 33,
			onClick = function()
				commands.run("workbench.quickOpen")
			end,
		})
		centerPill.AnchorPoint = Vector2.new(0.5, 0.5)

		local centerText = P.label(centerPill, {
			name = "CommandCenterLabel",
			size = UDim2.fromScale(1, 1),
			text = "⌕  VS-RBLX — Search files (Ctrl+P) or > commands",
			textSize = 11,
			color = theme.color.muted,
			alignX = Enum.TextXAlignment.Center,
			truncate = true,
			zIndex = 34,
		})

		-- Right side layout & window controls
		local rightCluster = P.frame(bar, {
			name = "RightControls",
			size = UDim2.fromOffset(204, h),
			pos = UDim2.new(1, -204, 0, 0),
			zIndex = 33,
		})
		P.list(rightCluster, Enum.FillDirection.Horizontal, 2, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

		local function makeIconBtn(name, iconName, order, hoverCol, onClick)
			local b = P.button(rightCluster, {
				name = name,
				size = UDim2.fromOffset(30, h),
				hoverBg = hoverCol or theme.color.hover,
				text = "",
				order = order,
				zIndex = 34,
				onClick = onClick,
			})
			local ic = icons.codicon(b, iconName, 16, theme.color.titleBarText, 35)
			ic.Position = UDim2.fromOffset(7, math.floor((h - 16) / 2))
			return b
		end

		makeIconBtn("ToggleSidebarBtn", "sidebar", 1, nil, function() commands.run("view.toggleSidebar") end)
		makeIconBtn("TogglePanelBtn", "panel", 2, nil, function() commands.run("view.togglePanel") end)
		makeIconBtn("SplitEditorBtn", "split", 3, nil, function() commands.run("view.splitEditor") end)
		makeIconBtn("MinimizeWindowBtn", "minimize", 4, nil, function()
			if callbacks.onMinimize then callbacks.onMinimize() end
		end)
		makeIconBtn("MaximizeWindowBtn", "maximize", 5, nil, function()
			if callbacks.onMaximize then callbacks.onMaximize() end
		end)
		makeIconBtn("CloseWindowBtn", "close", 6, Color3.fromRGB(232, 17, 35), function()
			if callbacks.onClose then callbacks.onClose() end
		end)

		local function refreshTitle()
			local doc = codeStore.active()
			local filePart = doc and doc.title or "Welcome"
			centerText.Text = string.format("⌕  %s — %s  (Ctrl+P)", workspaceFs.activeName, filePart)
		end

		codeStore.changed:connect(refreshTitle)
		workspaceFs.changed:connect(refreshTitle)
		theme.changed:connect(function()
			bar.BackgroundColor3 = theme.color.titleBar
			bottomBorder.BackgroundColor3 = theme.color.border
			centerPill.BackgroundColor3 = theme.color.inputBg
			centerText.TextColor3 = theme.color.muted
			for _, b in ipairs(menuButtons) do
				b.TextColor3 = theme.color.titleBarText
			end
		end)

		refreshTitle()
		return {
			root = bar,
			refresh = refreshTitle,
		}
	end

	return M
end
end)()

-- [ui/window] (14308 bytes)
__VSRBLX_MODULES["ui/window"] = (function()
-- Draggable, Auto-Resized, and 8-Direction Player-Resizable Window Shell for VS-RBLX.
return function(env)
	local util = env.require("runtime/util")
	local config = env.require("runtime/config")
	local dispose = env.require("runtime/dispose")
	local clock = env.require("runtime/clock")
	local theme = env.require("ui/theme")
	local responsive = env.require("ui/responsive")
	local brand = env.require("ui/brand")
	local P = env.require("ui/primitives")

	local MIN_W = 540
	local MIN_H = 320
	local SNAP_EDGE = 12
	local HANDLE_THICK = 6
	local CORNER_SIZE = 14

	local M = {}

	function M.new(parentScreen)
		local win = {
			visible = true,
			minimised = false,
			maximised = config.get("window.maximised", false) == true,
			snappedSide = nil,
			onResize = nil,
		}

		local root = P.frame(parentScreen, {
			name = "VSCodeWindow",
			size = UDim2.fromOffset(980, 620),
			pos = UDim2.fromOffset(100, 60),
			bg = theme.color.editor,
			radius = 6,
			clip = true,
			active = true,
			zIndex = 10,
		})
		local borderStroke = P.stroke(root, theme.color.border, 1)
		win.root = root

		local contentHost = P.frame(root, {
			name = "WorkbenchHost",
			size = UDim2.fromScale(1, 1),
			clip = true,
			zIndex = 11,
		})
		win.body = contentHost

		-- Minimized floating launcher pill
		local pill = P.button(parentScreen, {
			name = "MinimizedPill",
			size = UDim2.fromOffset(128, 32),
			pos = UDim2.new(0, 16, 1, -48),
			bg = theme.color.titleBar,
			hoverBg = theme.color.hover,
			text = "",
			radius = 16,
			border = theme.color.accent,
			visible = false,
			zIndex = 190,
			onClick = function()
				win.restore()
			end,
		})
		local pillBrand = brand.draw(pill, 16, 192)
		pillBrand.Position = UDim2.fromOffset(10, 8)
		P.label(pill, {
			size = UDim2.new(1, -34, 1, 0),
			pos = UDim2.fromOffset(32, 0),
			text = "VS-RBLX  ↗",
			bold = true,
			textSize = 12,
			color = theme.color.titleBarText,
			zIndex = 192,
		})
		win.pill = pill

		local preSnapRect = nil

		local function persistRect()
			if win.maximised or win.snappedSide then return end
			config.set("window.width", math.floor(root.Size.X.Offset), { quiet = true })
			config.set("window.height", math.floor(root.Size.Y.Offset), { quiet = true })
			config.set("window.x", math.floor(root.Position.X.Offset), { quiet = true })
			config.set("window.y", math.floor(root.Position.Y.Offset), { quiet = true })
			config.set("window.placed", true, { quiet = true })
		end

		function win.applyLayout(reason)
			local bounds = responsive.usableRect(win.maximised and 0 or 8)
			local effMinW = math.min(MIN_W, bounds.width)
			local effMinH = math.min(MIN_H, bounds.height)

			if win.maximised then
				root.Position = UDim2.fromOffset(bounds.x, bounds.y)
				root.Size = UDim2.fromOffset(bounds.width, bounds.height)
			elseif win.snappedSide == "left" then
				root.Position = UDim2.fromOffset(bounds.x, bounds.y)
				root.Size = UDim2.fromOffset(math.floor(bounds.width * 0.5), bounds.height)
			elseif win.snappedSide == "right" then
				local half = math.floor(bounds.width * 0.5)
				root.Position = UDim2.fromOffset(bounds.x + bounds.width - half, bounds.y)
				root.Size = UDim2.fromOffset(half, bounds.height)
			else
				local autoScale = config.get("window.autoResize", true) == true
				local customSize = config.get("window.customSize", false) == true
				local placed = config.get("window.placed", false) == true

				local w, h
				if autoScale and (not customSize or reason == "resetAuto") then
					local scaleW = tonumber(config.get("window.widthScale", 0.84)) or 0.84
					local scaleH = tonumber(config.get("window.heightScale", 0.84)) or 0.84
					w = math.floor(bounds.width * scaleW)
					h = math.floor(bounds.height * scaleH)
				else
					w = tonumber(config.get("window.width", 980)) or 980
					h = tonumber(config.get("window.height", 620)) or 620
				end

				w = util.clamp(w, effMinW, bounds.width)
				h = util.clamp(h, effMinH, bounds.height)

				local x, y
				if placed then
					x = tonumber(config.get("window.x", 0)) or 0
					y = tonumber(config.get("window.y", 0)) or 0
				else
					x = bounds.x + math.floor((bounds.width - w) * 0.5)
					y = bounds.y + math.floor((bounds.height - h) * 0.5)
				end
				x = util.clamp(x, bounds.x, math.max(bounds.x, bounds.x + bounds.width - w))
				y = util.clamp(y, bounds.y, math.max(bounds.y, bounds.y + bounds.height - h))

				root.Size = UDim2.fromOffset(w, h)
				root.Position = UDim2.fromOffset(x, y)
			end

			if win.onResize then
				pcall(win.onResize, root.Size.X.Offset, root.Size.Y.Offset)
			end
		end

		-- 8-way interactive edge & corner resize handles
		local resizeHandles = {}
		local activeGesture = nil

		local function makeResizeZone(name, sizeUDim, posUDim, dirX, dirY)
			local zone = P.frame(root, {
				name = name,
				size = sizeUDim,
				pos = posUDim,
				active = true,
				zIndex = 95,
			})
			zone.BackgroundTransparency = 1
			resizeHandles[#resizeHandles + 1] = zone

			zone.InputBegan:Connect(function(input)
				local kind = input.UserInputType
				if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then return end
				if win.maximised then return end
				win.snappedSide = nil
				activeGesture = {
					mode = "resize",
					input = input,
					startMouse = input.Position,
					startX = root.Position.X.Offset,
					startY = root.Position.Y.Offset,
					startW = root.Size.X.Offset,
					startH = root.Size.Y.Offset,
					dirX = dirX,
					dirY = dirY,
				}
			end)
		end

		makeResizeZone("ResizeLeft", UDim2.new(0, HANDLE_THICK, 1, -CORNER_SIZE * 2), UDim2.fromOffset(0, CORNER_SIZE), -1, 0)
		makeResizeZone("ResizeRight", UDim2.new(0, HANDLE_THICK, 1, -CORNER_SIZE * 2), UDim2.new(1, -HANDLE_THICK, 0, CORNER_SIZE), 1, 0)
		makeResizeZone("ResizeTop", UDim2.new(1, -CORNER_SIZE * 2, 0, HANDLE_THICK), UDim2.fromOffset(CORNER_SIZE, 0), 0, -1)
		makeResizeZone("ResizeBottom", UDim2.new(1, -CORNER_SIZE * 2, 0, HANDLE_THICK), UDim2.new(0, CORNER_SIZE, 1, -HANDLE_THICK), 0, 1)
		makeResizeZone("ResizeTopLeft", UDim2.fromOffset(CORNER_SIZE, CORNER_SIZE), UDim2.fromOffset(0, 0), -1, -1)
		makeResizeZone("ResizeTopRight", UDim2.fromOffset(CORNER_SIZE, CORNER_SIZE), UDim2.new(1, -CORNER_SIZE, 0, 0), 1, -1)
		makeResizeZone("ResizeBottomLeft", UDim2.fromOffset(CORNER_SIZE, CORNER_SIZE), UDim2.new(0, 0, 1, -CORNER_SIZE), -1, 1)
		makeResizeZone("ResizeBottomRight", UDim2.fromOffset(CORNER_SIZE, CORNER_SIZE), UDim2.new(1, -CORNER_SIZE, 1, -CORNER_SIZE), 1, 1)

		-- Subtle diagonal grip dots on bottom-right corner
		local gripVisual = P.frame(root, {
			name = "ResizeGripVisual",
			size = UDim2.fromOffset(12, 12),
			pos = UDim2.new(1, -13, 1, -13),
			zIndex = 94,
		})
		for gx = 0, 2 do
			for gy = 0, 2 do
				if gx + gy >= 2 then
					P.frame(gripVisual, {
						size = UDim2.fromOffset(2, 2),
						pos = UDim2.fromOffset(gx * 4 + 1, gy * 4 + 1),
						bg = Color3.fromRGB(220, 220, 220),
						transparency = 0.35,
						zIndex = 94,
					})
				end
			end
		end

		local function updateResizeVisibility()
			local allow = not win.maximised
			for _, h in ipairs(resizeHandles) do h.Visible = allow end
			gripVisual.Visible = allow
		end

		local lastTitleClickMs = 0

		function win.bindDragBar(dragSurface)
			local function isInteractiveDescendant(input)
				for _, child in ipairs(dragSurface:GetDescendants()) do
					if child:IsA("GuiButton") or child:IsA("TextBox") then
						local p, s = child.AbsolutePosition, child.AbsoluteSize
						if child.Visible
							and input.Position.X >= p.X and input.Position.X <= p.X + s.X
							and input.Position.Y >= p.Y and input.Position.Y <= p.Y + s.Y then
							return true
						end
					end
				end
				return false
			end

			dragSurface.InputBegan:Connect(function(input)
				local kind = input.UserInputType
				if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then return end
				if isInteractiveDescendant(input) then return end

				local nowMs = clock.ms()
				if nowMs - lastTitleClickMs < 320 then
					lastTitleClickMs = 0
					win.toggleMaximise()
					return
				end
				lastTitleClickMs = nowMs

				if win.maximised or win.snappedSide then
					local bounds = responsive.usableRect(8)
					local restoreW = preSnapRect and preSnapRect.w or math.floor(bounds.width * 0.8)
					local restoreH = preSnapRect and preSnapRect.h or math.floor(bounds.height * 0.8)
					win.maximised = false
					win.snappedSide = nil
					config.set("window.maximised", false, { quiet = true })
					local newX = util.clamp(math.floor(input.Position.X - restoreW * 0.5), bounds.x, bounds.x + bounds.width - restoreW)
					local newY = bounds.y
					root.Size = UDim2.fromOffset(restoreW, restoreH)
					root.Position = UDim2.fromOffset(newX, newY)
					updateResizeVisibility()
				end

				activeGesture = {
					mode = "drag",
					input = input,
					startMouse = input.Position,
					startX = root.Position.X.Offset,
					startY = root.Position.Y.Offset,
				}
			end)
		end

		if env.uis then
			dispose.connection(env.uis.InputChanged:Connect(function(input)
				if not activeGesture then return end
				local kind = input.UserInputType
				if kind ~= Enum.UserInputType.MouseMovement and kind ~= Enum.UserInputType.Touch then return end

				local bounds = responsive.usableRect(4)
				local dx = input.Position.X - activeGesture.startMouse.X
				local dy = input.Position.Y - activeGesture.startMouse.Y

				if activeGesture.mode == "drag" then
					local w = root.Size.X.Offset
					local h = root.Size.Y.Offset
					local nx = util.clamp(math.floor(activeGesture.startX + dx), bounds.x, math.max(bounds.x, bounds.x + bounds.width - w))
					local ny = util.clamp(math.floor(activeGesture.startY + dy), bounds.y, math.max(bounds.y, bounds.y + bounds.height - h))
					root.Position = UDim2.fromOffset(nx, ny)
				elseif activeGesture.mode == "resize" then
					local effMinW = math.min(MIN_W, bounds.width)
					local effMinH = math.min(MIN_H, bounds.height)
					local nx = activeGesture.startX
					local ny = activeGesture.startY
					local nw = activeGesture.startW
					local nh = activeGesture.startH

					if activeGesture.dirX == 1 then
						nw = util.clamp(math.floor(activeGesture.startW + dx), effMinW, bounds.x + bounds.width - nx)
					elseif activeGesture.dirX == -1 then
						local rightEdge = activeGesture.startX + activeGesture.startW
						nx = util.clamp(math.floor(activeGesture.startX + dx), bounds.x, rightEdge - effMinW)
						nw = rightEdge - nx
					end

					if activeGesture.dirY == 1 then
						nh = util.clamp(math.floor(activeGesture.startH + dy), effMinH, bounds.y + bounds.height - ny)
					elseif activeGesture.dirY == -1 then
						local bottomEdge = activeGesture.startY + activeGesture.startH
						ny = util.clamp(math.floor(activeGesture.startY + dy), bounds.y, bottomEdge - effMinH)
						nh = bottomEdge - ny
					end

					root.Position = UDim2.fromOffset(nx, ny)
					root.Size = UDim2.fromOffset(nw, nh)
					if win.onResize then
						pcall(win.onResize, nw, nh)
					end
				end
			end))

			dispose.connection(env.uis.InputEnded:Connect(function(input)
				if not activeGesture then return end
				local kind = input.UserInputType
				if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then return end

				local g = activeGesture
				activeGesture = nil
				local bounds = responsive.usableRect(8)

				if g.mode == "drag" then
					-- Edge Aero-Snap: top = maximize, far left/right = 50% split
					if input.Position.Y <= bounds.y + SNAP_EDGE then
						preSnapRect = { w = root.Size.X.Offset, h = root.Size.Y.Offset }
						win.setMaximised(true)
						return
					elseif input.Position.X <= bounds.x + SNAP_EDGE then
						preSnapRect = { w = root.Size.X.Offset, h = root.Size.Y.Offset }
						win.snappedSide = "left"
						win.applyLayout("snap")
						return
					elseif input.Position.X >= bounds.x + bounds.width - SNAP_EDGE then
						preSnapRect = { w = root.Size.X.Offset, h = root.Size.Y.Offset }
						win.snappedSide = "right"
						win.applyLayout("snap")
						return
					end
					persistRect()
					config.saveNow()
				elseif g.mode == "resize" then
					config.set("window.customSize", true, { quiet = true })
					config.set("window.widthScale", root.Size.X.Offset / math.max(1, bounds.width), { quiet = true })
					config.set("window.heightScale", root.Size.Y.Offset / math.max(1, bounds.height), { quiet = true })
					persistRect()
					config.saveNow()
				end
			end))
		end

		function win.setMaximised(flag)
			if flag and not win.maximised then
				preSnapRect = { w = root.Size.X.Offset, h = root.Size.Y.Offset }
			end
			win.maximised = flag == true
			win.snappedSide = nil
			config.set("window.maximised", win.maximised, { immediate = true })
			updateResizeVisibility()
			win.applyLayout("maximise")
		end

		function win.toggleMaximise()
			win.setMaximised(not win.maximised)
		end

		function win.resetAutoSize()
			win.maximised = false
			win.snappedSide = nil
			config.set("window.maximised", false, { quiet = true })
			config.set("window.customSize", false, { quiet = true })
			config.set("window.placed", false, { immediate = true })
			updateResizeVisibility()
			win.applyLayout("resetAuto")
		end

		function win.minimise()
			win.minimised = true
			root.Visible = false
			pill.Visible = true
		end

		function win.restore()
			win.minimised = false
			win.visible = true
			pill.Visible = false
			root.Visible = true
			win.applyLayout("restore")
		end

		function win.hide()
			win.visible = false
			root.Visible = false
			pill.Visible = false
		end

		function win.show()
			win.visible = true
			win.minimised = false
			pill.Visible = false
			root.Visible = true
			win.applyLayout("show")
		end

		function win.toggle()
			if win.minimised or not win.visible then
				win.restore()
			else
				win.minimise()
			end
		end

		responsive.changed:connect(function()
			if win.visible and not win.minimised then
				win.applyLayout("viewport")
			end
		end)

		theme.changed:connect(function()
			root.BackgroundColor3 = theme.color.editor
			borderStroke.Color = theme.color.border
			pill.BackgroundColor3 = theme.color.titleBar
		end)

		updateResizeVisibility()
		win.applyLayout("init")
		return win
	end

	return M
end
end)()

-- [bootstrap]
-- VS-RBLX: Visual Studio Code for Roblox (100% Luau · LocalScript & Executor IDE)
-- Supports executor disk persistence (`writefile`/`readfile`), GitHub HTTP sync,
-- 17-language RichText syntax highlighting, and a draggable/auto-resized/resizable workbench.

local VERSION = "1.0.0"

local function safeGlobal(name)
	local ok, val = pcall(function()
		local g = (type(getgenv) == "function" and getgenv()) or _G
		if g and g[name] ~= nil then return g[name] end
		return _G[name]
	end)
	if ok and val ~= nil then return val end
	return rawget(_G, name)
end

local function safeService(name)
	if game and type(game.GetService) == "function" then
		local ok, svc = pcall(function() return game:GetService(name) end)
		if ok and svc then return svc end
	end
	return nil
end

local function createEnv(customOpts)
	customOpts = customOpts or {}
	local buildMeta = rawget(_G, "__VSRBLX_BUILD") or {
		version = VERSION,
		id = VERSION .. "-dev",
		channel = "dev",
	}
	local moduleTable = rawget(_G, "__VSRBLX_MODULES") or {}
	local loaded = {}
	local loading = {}

	local services = {
		Workspace = workspace or safeService("Workspace"),
		Players = safeService("Players"),
		UserInputService = safeService("UserInputService"),
		TweenService = safeService("TweenService"),
		HttpService = safeService("HttpService"),
		RunService = safeService("RunService"),
		TextService = safeService("TextService"),
		GuiService = safeService("GuiService"),
		CoreGui = safeService("CoreGui"),
		ReplicatedStorage = safeService("ReplicatedStorage"),
		StarterPlayer = safeService("StarterPlayer"),
		StarterGui = safeService("StarterGui"),
	}

	local localPlr = services.Players and services.Players.LocalPlayer or nil

	local env = {
		version = buildMeta.version or VERSION,
		buildId = buildMeta.id or (VERSION .. "-dev"),
		channel = buildMeta.channel or "dev",
		info = {
			version = buildMeta.version or VERSION,
			build = buildMeta.id or (VERSION .. "-dev"),
			folder = customOpts.folder or "VSRBLX",
		},
		opts = customOpts,
		services = services,

		-- Service shortcuts
		game = game,
		workspace = services.Workspace,
		players = services.Players,
		plr = localPlr,
		uis = services.UserInputService,
		tween = services.TweenService,
		hs = services.HttpService,
		httpService = services.HttpService,
		runService = services.RunService,
		textService = services.TextService,
		guisvc = services.GuiService,
		guiService = services.GuiService,
		coreGui = services.CoreGui,

		-- Executor host capabilities
		getgenv = safeGlobal("getgenv"),
		gethui = safeGlobal("gethui"),
		identifyexecutor = safeGlobal("identifyexecutor") or safeGlobal("getexecutorname"),
		loadstring = safeGlobal("loadstring") or loadstring,

		-- Executor local disk filesystem (`writefile` / `readfile`)
		writefile = safeGlobal("writefile"),
		readfile = safeGlobal("readfile"),
		appendfile = safeGlobal("appendfile"),
		isfile = safeGlobal("isfile"),
		isfolder = safeGlobal("isfolder"),
		makefolder = safeGlobal("makefolder"),
		listfiles = safeGlobal("listfiles"),
		delfile = safeGlobal("delfile"),
		delfolder = safeGlobal("delfolder"),

		-- Executor HTTP transport (`request` / `http_request` / `syn.request`)
		request = safeGlobal("request"),
		http_request = safeGlobal("http_request"),
		http = safeGlobal("http"),
		syn = safeGlobal("syn"),
		fluxus = safeGlobal("fluxus"),

		-- Clipboard & script inspection
		setclipboard = safeGlobal("setclipboard") or safeGlobal("toclipboard"),
		getclipboard = safeGlobal("getclipboard"),
		decompile = safeGlobal("decompile"),
		getscriptbytecode = safeGlobal("getscriptbytecode"),
	}

	local function resolveFactory(modId)
		if moduleTable[modId] then
			return moduleTable[modId]
		end
		local relPath = "src/" .. modId .. ".lua"
		if type(loadfile) == "function" then
			local chunk, err = loadfile(relPath)
			if not chunk then error("Failed to load " .. relPath .. ": " .. tostring(err)) end
			return chunk()
		end
		if type(env.readfile) == "function" and type(env.loadstring) == "function" then
			local ok, src = pcall(env.readfile, relPath)
			if ok and type(src) == "string" then
				local chunk, err = env.loadstring(src, "@" .. relPath)
				if not chunk then error("Compile error in " .. relPath .. ": " .. tostring(err)) end
				return chunk()
			end
		end
		error("Module not found: " .. tostring(modId))
	end

	function env.require(modId)
		if loaded[modId] ~= nil then
			return loaded[modId]
		end
		if loading[modId] then
			error("Circular module dependency detected: " .. tostring(modId))
		end
		loading[modId] = true
		local factory = resolveFactory(modId)
		if type(factory) ~= "function" then
			loading[modId] = nil
			error("Module " .. tostring(modId) .. " must return function(env)")
		end
		local result = factory(env)
		loading[modId] = nil
		loaded[modId] = result == nil and true or result
		return loaded[modId]
	end

	return env
end

local function boot(userOpts)
	local globalHost = (type(getgenv) == "function" and getgenv()) or _G
	local bootCfg = userOpts or (globalHost and globalHost.VSRBLX_CONFIG) or {}

	if globalHost and type(globalHost.VSRBLX) == "table" and type(globalHost.VSRBLX.destroy) == "function" then
		pcall(globalHost.VSRBLX.destroy)
	end

	local env = createEnv(bootCfg)
	local dispose = env.require("runtime/dispose")
	local sdkMod = env.require("embedding/sdk")

	local appInstance = nil
	if not bootCfg.headless then
		local appMod = env.require("ui/app")
		appInstance = appMod.mount(bootCfg)
	else
		local config = env.require("runtime/config")
		local workspaceFs = env.require("runtime/workspace_fs")
		local gitState = env.require("runtime/git_state")
		config.load()
		workspaceFs.init()
		gitState.loadMeta()
	end

	local api = sdkMod.buildHandle(appInstance, function()
		if dispose.all then
			dispose.all()
		elseif dispose.cleanupAll then
			dispose.cleanupAll()
		end
	end)
	if globalHost then
		globalHost.VSRBLX = api
	end
	return api
end

local autoBoot = true
local host = (type(getgenv) == "function" and getgenv()) or _G
if host and host.VSRBLX_NO_AUTOBOOT == true then
	autoBoot = false
end

if autoBoot then
	return boot()
end

return {
	version = VERSION,
	createEnv = createEnv,
	boot = boot,
}
