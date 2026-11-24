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
