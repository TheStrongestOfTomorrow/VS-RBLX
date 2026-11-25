-- Live Roblox `LogService.MessageOut` Console Bridge + Stack-Trace File:Line Parser (`src/runtime/roblox_console.lua`).
-- Streams real-time Roblox `print`, `warn`, and runtime error stack traces into VS-RBLX's
-- OUTPUT panel so clicking any error jumps straight to that file and line.
return function(env)
	local util = env.require("runtime/util")
	local config = env.require("runtime/config")
	local dispose = env.require("runtime/dispose")
	local log = env.require("runtime/log")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")

	local M = {
		installed = false,
		capturedCount = 0,
	}

	-- Extracts `{ path = "...", line = N }` from Luau / Roblox stack trace lines such as:
	--   `src/main.luau:18: attempt to index nil`
	--   `[string "src/combat.luau"]:42: bad argument`
	--   `Players.Player1.PlayerScripts.Client:12: ...`
	function M.parseStackLocation(message)
		local txt = tostring(message or "")
		if txt == "" then return nil end

		-- Pattern 1: `[string "path/to/file.luau"]:12:`
		local chunkPath, chunkLine = txt:match('%[string%s+"([^"]+)"%]%s*:%s*(%d+)')
		if chunkPath and chunkLine then
			local clean = util.normalisePath(chunkPath:gsub("^@", ""))
			return { path = clean, line = tonumber(chunkLine) or 1 }
		end

		-- Pattern 2: `path/to/file.ext:12:`
		local filePath, fileLine = txt:match("([%w_%-%./]+%.[%a]+):(%d+)")
		if filePath and fileLine then
			local clean = util.normalisePath(filePath)
			return { path = clean, line = tonumber(fileLine) or 1 }
		end

		return nil
	end

	function M.jumpToLogEntry(entry)
		if not entry then return false end
		local loc = entry.location or M.parseStackLocation(entry.message)
		if not loc or not loc.path then return false end

		-- Match against open tabs first (exact path or basename match)
		for _, doc in ipairs(codeStore.tabs) do
			if doc.path == loc.path or doc.title == loc.path then
				codeStore.activate(doc.id)
				codeStore.jumpToLine(doc.id, loc.line or 1, 1)
				return true, doc.path, loc.line
			end
		end

		if workspaceFs.exists(loc.path) then
			codeStore.openFile(loc.path, { line = loc.line or 1 })
			return true, loc.path, loc.line
		end
		return false
	end

	function M.ingest(message, msgTypeStr)
		if config.get("roblox.captureLogService", true) == false then return nil end
		local text = tostring(message or "")
		-- Ignore VS-RBLX's own mirrored logs to prevent feedback loops
		if util.startsWith(text, "[VS-RBLX/") or util.startsWith(text, "[vsrblx]") then
			return nil
		end

		local kind = tostring(msgTypeStr or "MessageOutput")
		local entry
		if kind:find("Error", 1, true) then
			entry = log.error("roblox", text)
		elseif kind:find("Warning", 1, true) then
			entry = log.warn("roblox", text)
		else
			entry = log.info("roblox", text)
		end

		if entry then
			entry.location = M.parseStackLocation(text)
			M.capturedCount = M.capturedCount + 1
		end
		return entry
	end

	function M.install()
		if M.installed then return end
		M.installed = true
		local logSvc = env.services and env.services.LogService or nil
		if logSvc and logSvc.MessageOut then
			pcall(function()
				dispose.connection(logSvc.MessageOut:Connect(function(msg, msgType)
					M.ingest(msg, tostring(msgType))
				end))
			end)
		end
	end

	return M
end
