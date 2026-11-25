-- GitHub Gist Import, Publish, and Raw HTTP URL Loader for VS-RBLX (`src/net/gist.lua`).
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
		log.info("github", "Imported GitHub Gist " .. id)
		return files, nil, res.json.description
	end

	-- Publishes one or more files as a new GitHub Gist via Executor HTTP (`POST /gists`)
	function M.publishGist(spec)
		spec = spec or {}
		local tok = github.token()
		if tok == "" then
			return nil, "Set a GitHub Personal Access Token (with `gist` scope) before publishing a Gist."
		end
		local filesPayload = {}
		local count = 0
		for name, content in pairs(spec.files or {}) do
			local safeName = util.basename(tostring(name or "snippet.luau"))
			if safeName == "" then safeName = "snippet.luau" end
			filesPayload[safeName] = { content = tostring(content or "-- empty\n") }
			count = count + 1
		end
		if count == 0 then
			return nil, "No files provided to publish as a Gist."
		end

		local bodyStr = util.jsonEncode({
			description = tostring(spec.description or "Published from VS-RBLX IDE"),
			public = spec.public == true,
			files = filesPayload,
		})
		local res = http.send({
			url = "https://api.github.com/gists",
			method = "POST",
			headers = headersUtil.github(tok, true),
			body = bodyStr,
		})
		if not res.ok or type(res.json) ~= "table" then
			return nil, res.error or ("GitHub Gist API HTTP " .. tostring(res.status))
		end

		local url = res.json.html_url or ("https://gist.github.com/" .. tostring(res.json.id or ""))
		log.info("github", "Published Gist: " .. url)
		return {
			id = res.json.id,
			url = url,
			public = spec.public == true,
			fileCount = count,
		}
	end

	return M
end
