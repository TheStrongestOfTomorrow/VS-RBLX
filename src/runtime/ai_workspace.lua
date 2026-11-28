-- Isolated executor-backed workspace for AI-generated artifacts, scoped per conversation thread.
-- Project files remain in runtime/workspace_fs; conversation threads remain in ai/threads.
return function(env)
	local fsx = env.require("runtime/fsx")
	local util = env.require("runtime/util")

	local DEFAULT_ROOT = "ai/workspaces/default"
	local OWNER_FILE = ".vsrblx-thread-owner"
	local ROOT = DEFAULT_ROOT
	local MAX_FILES = 2000
	local MAX_TEXT_BYTES = 8 * 1024 * 1024
	local M = { name = "default" }

	local function scopeOpts()
		return { scope = ROOT }
	end

	local function safePath(path)
		local clean, err = fsx.sanitise(path, false)
		if not clean then return nil, err end
		return clean
	end

	function M.rootPath()
		return fsx.root .. "/" .. ROOT
	end

	function M.setThread(threadId)
		local id = tostring(threadId or "")
		if id == "" then
			ROOT = DEFAULT_ROOT
			M.threadId = nil
			return true
		end
		local safeId = id:gsub("[^%w_-]", "_"):sub(1, 64)
		if safeId == "" then return false, "Invalid AI thread identifier" end
		local defaultOwner = fsx.read(OWNER_FILE, { scope = DEFAULT_ROOT })
		if type(defaultOwner) ~= "string" or defaultOwner == "" then
			defaultOwner = id
			fsx.write(OWNER_FILE, id, { scope = DEFAULT_ROOT })
		end
		if id == defaultOwner then
			ROOT = DEFAULT_ROOT
		else
			ROOT = "ai/workspaces/threads/" .. safeId
		end
		M.threadId = id
		M.init()
		return true
	end

	function M.readFile(path)
		local clean, err = safePath(path)
		if not clean then return nil, err end
		local content, readErr = fsx.read(clean, scopeOpts())
		if content ~= nil and #content > MAX_TEXT_BYTES then
			return nil, "AI workspace file exceeds 8 MB safety bound"
		end
		return content, readErr
	end

	function M.writeFile(path, content)
		local clean, err = safePath(path)
		if not clean then return false, err end
		local body = tostring(content or "")
		if #body > MAX_TEXT_BYTES then return false, "AI workspace file exceeds 8 MB safety bound" end
		return fsx.write(clean, body, scopeOpts())
	end

	function M.deleteFile(path)
		local clean, err = safePath(path)
		if not clean then return false, err end
		return fsx.delete(clean, scopeOpts())
	end

	function M.listFiles(opts)
		opts = opts or {}
		local found = {}
		local truncated = false
		local function walk(dir, depth)
			if depth > 14 or #found >= MAX_FILES then
				truncated = true
				return
			end
			for _, item in ipairs(fsx.list(dir, scopeOpts())) do
				if item.isDir then
					if item.name ~= ".git" and item.name ~= "node_modules" then
					walk(item.path, depth + 1)
				end
				elseif not (dir == "" and item.name == OWNER_FILE) then
					found[#found + 1] = item.path
					if #found >= MAX_FILES then truncated = true return end
				end
			end
		end
		walk("", 0)
		local offset = math.floor(util.clamp(tonumber(opts.offset) or 0, 0, #found))
		local limit = math.floor(util.clamp(tonumber(opts.limit) or 150, 1, 300))
		local page = {}
		for i = offset + 1, math.min(#found, offset + limit) do page[#page + 1] = found[i] end
		return {
			root = M.rootPath(),
			files = page,
			total = #found,
			count = #page,
			truncated = truncated,
			nextOffset = offset + #page < #found and (offset + #page) or nil,
		}
	end

	function M.init()
		return fsx.mkdir("", scopeOpts())
	end

	M.init()
	return M
end
