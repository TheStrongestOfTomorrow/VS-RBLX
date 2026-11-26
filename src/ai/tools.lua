-- Native VS-RBLX IDE & Roblox DataModel Agent Tools (`src/ai/tools.lua`).
-- Clean-room tool suite with `readOnly` permission classification, exact smallest-change
-- `workspace_edit_file` (refusing missing/ambiguous matches), non-executing `check_luau_syntax`,
-- cooperative deadline-guarded `run_luau_bounded` (prevents infinite loops from freezing Roblox),
-- and live Roblox DataModel / RemoteEvent introspection.
-- Architectural engineering inspired by Project UAI (MIT © CarlDV / Project-Ptolemy).
return function(env)
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")
	local diagnostics = env.require("runtime/diagnostics")
	local robloxExplorer = env.require("runtime/roblox_explorer")
	local util = env.require("runtime/util")

	local M = {}

	-- Rewrite unconditional Luau loop headers (`do` / `repeat`) with cooperative deadline checks
	-- while leaving string literals and comments completely untouched!
	function M.injectCooperativeCheckpoints(source, guardFnName)
		local guard = guardFnName or "__vsrblx_check()"
		local out = {}
		local i = 1
		local n = #source

		local function isIdentChar(ch)
			return ch ~= "" and ch:match("[A-Za-z0-9_]") ~= nil
		end

		while i <= n do
			local c = source:sub(i, i)
			local c2 = source:sub(i, i + 1)

			-- Line or block comment
			if c2 == "--" then
				local eqs = source:match("^%-%-%[(=*)%[", i)
				if eqs ~= nil then
					local closePat = "%]" .. eqs .. "%]"
					local _, ePos = source:find(closePat, i + 4 + #eqs)
					if ePos then
						out[#out + 1] = source:sub(i, ePos)
						i = ePos + 1
					else
						out[#out + 1] = source:sub(i)
						break
					end
				else
					local nl = source:find("\n", i, true)
					if nl then
						out[#out + 1] = source:sub(i, nl)
						i = nl + 1
					else
						out[#out + 1] = source:sub(i)
						break
					end
				end
			-- Long bracket string `[=[ ... ]=]`
			elseif c == "[" and source:match("^%[(=*)%[", i) ~= nil then
				local eqs = source:match("^%[(=*)%[", i)
				local closePat = "%]" .. eqs .. "%]"
				local _, ePos = source:find(closePat, i + 2 + #eqs)
				if ePos then
					out[#out + 1] = source:sub(i, ePos)
					i = ePos + 1
				else
					out[#out + 1] = source:sub(i)
					break
				end
			-- Quoted string `"` or `'`
			elseif c == '"' or c == "'" then
				local quote = c
				local j = i + 1
				while j <= n do
					local cj = source:sub(j, j)
					if cj == "\\" then
						j = j + 2
					elseif cj == quote then
						j = j + 1
						break
					else
						j = j + 1
					end
				end
				out[#out + 1] = source:sub(i, j - 1)
				i = j
			-- Identifier / Keyword token
			elseif c:match("[A-Za-z_]") then
				local prev = (i > 1) and source:sub(i - 1, i - 1) or ""
				local word = source:match("^[A-Za-z_][A-Za-z0-9_]*", i)
				local afterIdx = i + #word
				if prev ~= "." and prev ~= ":" and not isIdentChar(prev) then
					if word == "do" or word == "repeat" then
						out[#out + 1] = word .. " " .. guard .. ";"
					else
						out[#out + 1] = word
					end
				else
					out[#out + 1] = word
				end
				i = afterIdx
			else
				out[#out + 1] = c
				i = i + 1
			end
		end
		return table.concat(out)
	end

	M.DEFINITIONS = {
		{
			name = "workspace_list_files",
			readOnly = true,
			description = "List all files in the active VS-RBLX workspace.",
			parameters = {
				type = "object",
				properties = {},
			},
			run = function()
				local files = workspaceFs.allFiles("")
				return { ok = true, count = #files, files = files }
			end,
		},
		{
			name = "workspace_read_file",
			readOnly = true,
			description = "Read a file from the active VS-RBLX workspace by relative path.",
			parameters = {
				type = "object",
				properties = {
					path = { type = "string", description = "Workspace relative path (e.g. 'src/main.luau')" },
				},
				required = { "path" },
			},
			run = function(args)
				local path = tostring(args.path or "")
				local content = workspaceFs.readFile(path)
				if content == nil then
					return { ok = false, error = "File not found: " .. path }
				end
				return { ok = true, path = path, size = #content, content = content }
			end,
		},
		{
			name = "workspace_search",
			readOnly = true,
			description = "Search for a substring across all files in the active workspace.",
			parameters = {
				type = "object",
				properties = {
					query = { type = "string", description = "Case-insensitive search text" },
				},
				required = { "query" },
			},
			run = function(args)
				local q = tostring(args.query or ""):lower()
				if q == "" then return { ok = false, error = "Empty query" } end
				local hits = {}
				for _, path in ipairs(workspaceFs.allFiles("")) do
					local body = workspaceFs.readFile(path) or ""
					local lineNo = 0
					for line in (body .. "\n"):gmatch("([^\n]*)\n") do
						lineNo = lineNo + 1
						if line:lower():find(q, 1, true) then
							hits[#hits + 1] = { path = path, line = lineNo, text = util.trim(line):sub(1, 140) }
							if #hits >= 40 then break end
						end
					end
					if #hits >= 40 then break end
				end
				return { ok = true, count = #hits, matches = hits }
			end,
		},
		{
			name = "check_luau_syntax",
			readOnly = true,
			description = "Compile Luau code (inline or by workspace path) WITHOUT executing it to verify 0 syntax errors.",
			parameters = {
				type = "object",
				properties = {
					path = { type = "string", description = "Optional workspace file path" },
					code = { type = "string", description = "Optional inline Luau source" },
				},
			},
			run = function(args)
				local src = args.code
				local label = "@inline"
				if (type(src) ~= "string" or src == "") and type(args.path) == "string" and args.path ~= "" then
					src = workspaceFs.readFile(args.path)
					label = "@" .. args.path
					if src == nil then
						return { ok = false, error = "File not found: " .. tostring(args.path) }
					end
				end
				src = tostring(src or "")
				local loader = (env.caps and env.caps.fn and env.caps.fn.loadstring) or loadstring
				if type(loader) ~= "function" then
					return { ok = false, error = "Host does not expose loadstring compiler" }
				end
				local fn, compileErr = loader(src, label)
				if not fn then
					return { ok = false, valid = false, error = tostring(compileErr) }
				end
				return { ok = true, valid = true, bytes = #src }
			end,
		},
		{
			name = "get_diagnostics",
			readOnly = true,
			description = "Get current syntax diagnostics (errors and warnings) across open editor tabs.",
			parameters = { type = "object", properties = {} },
			run = function()
				local list, errs, warns = diagnostics.all()
				return { ok = true, errors = errs, warnings = warns, items = list }
			end,
		},
		{
			name = "inspect_roblox_tree",
			readOnly = true,
			description = "Inspect live Roblox DataModel services or children of a service (e.g. 'Workspace', 'ReplicatedStorage').",
			parameters = {
				type = "object",
				properties = {
					service = { type = "string", description = "Optional top-level service name (omit for root list)" },
				},
			},
			run = function(args)
				local svcName = util.trim(tostring(args.service or ""))
				if svcName == "" then
					local roots = {}
					for _, r in ipairs(robloxExplorer.rootServices()) do
						roots[#roots + 1] = { name = r.name, className = r.className }
					end
					return { ok = true, services = roots }
				end
				local target = nil
				for _, r in ipairs(robloxExplorer.rootServices()) do
					if r.name:lower() == svcName:lower() then
						target = r.instance
						break
					end
				end
				if not target then
					return { ok = false, error = "Service not found: " .. svcName }
				end
				local kids = {}
				for _, ch in ipairs(robloxExplorer.childrenOf(target, 50)) do
					kids[#kids + 1] = {
						name = ch.name,
						className = ch.className,
						luauPath = robloxExplorer.luauPathOf(ch.instance),
					}
				end
				return { ok = true, service = svcName, children = kids }
			end,
		},
		{
			name = "discover_remotes",
			readOnly = true,
			description = "Scan the live Roblox DataModel for RemoteEvent and RemoteFunction instances and return their Luau paths.",
			parameters = { type = "object", properties = {} },
			run = function()
				local remotes = robloxExplorer.listRemotes(60)
				return { ok = true, count = #remotes, remotes = remotes }
			end,
		},
		{
			name = "workspace_edit_file",
			readOnly = false,
			description = "Perform an exact, surgical `old_text -> new_text` replacement in an existing workspace file. Refuses missing or ambiguous matches.",
			parameters = {
				type = "object",
				properties = {
					path = { type = "string", description = "Workspace file path" },
					old_text = { type = "string", description = "Exact text to replace (must match uniquely once)" },
					new_text = { type = "string", description = "Replacement text" },
				},
				required = { "path", "old_text", "new_text" },
			},
			run = function(args)
				local path = tostring(args.path or "")
				local oldText = tostring(args.old_text or "")
				local newText = tostring(args.new_text or "")
				if oldText == "" then
					return { ok = false, error = "old_text must be non-empty" }
				end
				local current = workspaceFs.readFile(path)
				if current == nil then
					return { ok = false, error = "File not found: " .. path }
				end
				if #current > 2097152 then
					return { ok = false, error = "File exceeds 2 MB safety bound" }
				end
				local s1, e1 = current:find(oldText, 1, true)
				if not s1 then
					return { ok = false, error = "old_text not found in " .. path }
				end
				local s2 = current:find(oldText, e1 + 1, true)
				if s2 then
					return { ok = false, error = "Ambiguous edit: old_text matched multiple locations in " .. path }
				end
				local updated = current:sub(1, s1 - 1) .. newText .. current:sub(e1 + 1)
				local okW, wErr = workspaceFs.writeFile(path, updated)
				if not okW then
					return { ok = false, error = tostring(wErr) }
				end
				codeStore.openFile(path, { reloadFromDisk = true })
				return { ok = true, path = path, bytes = #updated }
			end,
		},
		{
			name = "workspace_write_file",
			readOnly = false,
			description = "Create or overwrite a file in the active VS-RBLX workspace.",
			parameters = {
				type = "object",
				properties = {
					path = { type = "string", description = "Workspace file path" },
					content = { type = "string", description = "Full file content" },
				},
				required = { "path", "content" },
			},
			run = function(args)
				local path = tostring(args.path or "")
				local content = tostring(args.content or "")
				local okW, err = workspaceFs.writeFile(path, content)
				if not okW then
					return { ok = false, error = tostring(err) }
				end
				codeStore.openFile(path, { reloadFromDisk = true })
				return { ok = true, path = path, bytes = #content }
			end,
		},
		{
			name = "run_luau_bounded",
			readOnly = false,
			description = "Execute Luau code in a bounded sandbox with cooperative loop-deadline checkpoints and captured print/warn output.",
			parameters = {
				type = "object",
				properties = {
					code = { type = "string", description = "Luau code to execute" },
					timeout = { type = "number", description = "Max execution time in seconds (1–30, default 5)" },
				},
				required = { "code" },
			},
			run = function(args)
				local rawCode = tostring(args.code or "")
				local maxSec = util.clamp(tonumber(args.timeout) or 5, 0.05, 30)
				local loader = (env.caps and env.caps.fn and env.caps.fn.loadstring) or loadstring
				if type(loader) ~= "function" then
					return { ok = false, error = "loadstring unavailable in this host" }
				end

				local guardedCode = M.injectCooperativeCheckpoints(rawCode, "__vsrblx_check()")
				local chunk, cErr = loader(guardedCode, "@ai_run_luau")
				if not chunk then
					return { ok = false, error = "Syntax error: " .. tostring(cErr) }
				end

				local logs = {}
				local startClock = os.clock()
				local iterCount = 0
				local baseEnv = getfenv(0)
				local execEnv = setmetatable({
					__vsrblx_check = function()
						iterCount = iterCount + 1
						if iterCount % 512 == 0 and (os.clock() - startClock) > maxSec then
							error(string.format("Execution deadline exceeded (%.2fs) — loop safely aborted", maxSec), 0)
						end
					end,
					print = function(...)
						local parts = {}
						for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
						if #logs < 80 then logs[#logs + 1] = table.concat(parts, "\t") end
					end,
					warn = function(...)
						local parts = {}
						for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
						if #logs < 80 then logs[#logs + 1] = "[WARN] " .. table.concat(parts, "\t") end
					end,
				}, { __index = baseEnv })
				pcall(setfenv, chunk, execEnv)

				local okRun, retVal = pcall(chunk)
				return {
					ok = okRun,
					output = table.concat(logs, "\n"),
					result = okRun and tostring(retVal) or nil,
					error = (not okRun) and tostring(retVal) or nil,
				}
			end,
		},
	}

	function M.find(name)
		for _, t in ipairs(M.DEFINITIONS) do
			if t.name == name then return t end
		end
		return nil
	end

	function M.execute(name, args)
		local t = M.find(name)
		if not t then
			return { ok = false, error = "Unknown tool: " .. tostring(name) }
		end
		local okRun, res = pcall(t.run, args or {})
		if not okRun then
			return { ok = false, error = tostring(res) }
		end
		return res
	end

	function M.schemasForMode(permMode)
		local list = {}
		for _, t in ipairs(M.DEFINITIONS) do
			if permMode ~= "read_only" or t.readOnly then
				list[#list + 1] = {
					name = t.name,
					description = t.description,
					parameters = t.parameters,
				}
			end
		end
		return list
	end

	return M
end
