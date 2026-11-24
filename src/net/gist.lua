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
