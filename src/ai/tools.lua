-- Native VS-RBLX IDE & Roblox DataModel Agent Tools (`src/ai/tools.lua`).
-- Clean-room tool suite with `readOnly` permission classification, exact smallest-change
-- `workspace_edit_file` (refusing missing/ambiguous matches), non-executing `check_luau_syntax`,
-- cooperative deadline-guarded `run_luau_bounded` (prevents infinite loops from freezing Roblox),
-- and live Roblox DataModel / RemoteEvent introspection.
-- Architectural engineering inspired by Project UAI (MIT © CarlDV / Project-Ptolemy).
return function(env)
	local workspaceFs = env.require("runtime/workspace_fs")
	local aiWorkspace = env.require("runtime/ai_workspace")
	local codeStore = env.require("runtime/code_store")
	local diagnostics = env.require("runtime/diagnostics")
	local robloxExplorer = env.require("runtime/roblox_explorer")
	local util = env.require("runtime/util")

	local M = {}
	local authorizationThread = ""
	local authorizedProjects = {}

	function M.setThread(threadId)
		local id = tostring(threadId or "")
		if id ~= authorizationThread then
			authorizationThread = id
			authorizedProjects = {}
			if workspaceFs.activeName then authorizedProjects[workspaceFs.activeName] = true end
		end
	end

	local function projectAccess(projectName)
		local name = util.trim(tostring(projectName or workspaceFs.activeName or "default"))
		if name == "" then name = workspaceFs.activeName or "default" end
		if name ~= workspaceFs.activeName and not authorizedProjects[name] then
			return nil, "Project scope is not authorized for this AI conversation. Call workspace_authorize_project and wait for user approval."
		end
		if name == workspaceFs.activeName and workspaceFs.rawMode then
			return name, nil, workspaceFs.diskRootLabel()
		end
		local root, cleanOrErr = workspaceFs.projectRoot(name)
		if not root then return nil, tostring(cleanOrErr) end
		return name, nil, root
	end

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
			name = "workspace_list_available_projects",
			readOnly = true,
			description = "List known project workspace names only. This does not authorize access to another project's contents.",
			parameters = { type = "object", properties = {} },
			run = function()
				return { ok = true, active = workspaceFs.activeName, projects = workspaceFs.listWorkspaces() }
			end,
		},
		{
			name = "workspace_authorize_project",
			readOnly = false,
			requiresApproval = true,
			description = "Request user approval to let this AI conversation read/search a named project workspace. Approval applies to this thread only and grants no write access.",
			parameters = {
				type = "object",
				properties = { project = { type = "string", description = "Exact project name returned by workspace_list_available_projects" } },
				required = { "project" },
			},
			run = function(args)
				local name = util.trim(tostring(args.project or ""))
				if name == "" then return { ok = false, error = "Project name required" } end
				local known = false
				for _, candidate in ipairs(workspaceFs.listWorkspaces()) do
					if candidate == name then known = true break end
				end
				if not known then return { ok = false, error = "Unknown project workspace: " .. name } end
				local root, err = workspaceFs.projectRoot(name)
				if not root then return { ok = false, error = tostring(err) } end
				authorizedProjects[name] = true
				return { ok = true, project = name, root = root, access = "read-only for this conversation" }
			end,
		},
		{
			name = "workspace_list_files",
			readOnly = true,
			description = "Recursively list files in the active project workspace (bounded to 1200 paths). Use offset to page through results.",
			parameters = {
				type = "object",
				properties = {
					offset = { type = "number", description = "Zero-based result offset" },
					limit = { type = "number", description = "Page size (1-300, default 150)" },
					project = { type = "string", description = "Optional project name; non-active projects require prior user authorization in this conversation" },
				},
			},
			run = function(args)
				local project, accessErr, projectRoot = projectAccess(args.project)
				if not project then return { ok = false, error = accessErr } end
				local files, listErr, listInfo
				if project == workspaceFs.activeName then
					files = workspaceFs.allFiles("")
					projectRoot = workspaceFs.diskRootLabel()
				else
					files, listErr, listInfo = workspaceFs.listProjectFiles(project)
				end
				if not files then return { ok = false, error = tostring(listErr or "Unable to list project") } end
				local offset = math.floor(util.clamp(tonumber(args.offset) or 0, 0, #files))
				local limit = math.floor(util.clamp(tonumber(args.limit) or 150, 1, 300))
				local page = {}
				for i = offset + 1, math.min(#files, offset + limit) do page[#page + 1] = files[i] end
				return {
					ok = true,
					workspace = project,
					root = projectRoot or (listInfo and listInfo.root) or workspaceFs.diskRootLabel(),
					count = #page,
					total = #files,
					truncated = (listInfo and listInfo.truncated) or #files >= 1200,
					nextOffset = offset + #page < #files and (offset + #page) or nil,
					files = page,
				}
			end,
		},
		{
			name = "workspace_read_file",
			readOnly = true,
			description = "Read a bounded UTF-8 page from the active project workspace file. Use nextOffset to continue large text files.",
			parameters = {
				type = "object",
				properties = {
					path = { type = "string", description = "Workspace relative path (e.g. 'src/main.luau')" },
					offset = { type = "number", description = "Zero-based byte offset returned by the previous page" },
					max_bytes = { type = "number", description = "Maximum page size (1-65536, default 32768)" },
					project = { type = "string", description = "Optional named project; requires authorization for non-active projects" },
				},
				required = { "path" },
			},
			run = function(args)
				local project, accessErr = projectAccess(args.project)
				if not project then return { ok = false, error = accessErr } end
				local path = tostring(args.path or "")
				local content, readErr
				if project == workspaceFs.activeName then content, readErr = workspaceFs.readFile(path)
				else content, readErr = workspaceFs.readProjectFile(project, path) end
				if content == nil then
					return { ok = false, error = tostring(readErr or ("File not found: " .. path)) }
				end
				if #content > 8388608 then return { ok = false, error = "File exceeds 8 MB text safety bound" } end
				if not util.validUtf8(content) then return { ok = false, error = "File is not valid UTF-8 text" } end
				local start = math.floor(util.clamp(tonumber(args.offset) or 0, 0, #content))
				while start > 0 and not util.validUtf8(content:sub(1, start)) do start = start - 1 end
				local maxBytes = math.floor(util.clamp(tonumber(args.max_bytes) or 32768, 1, 65536))
				local chunk = content:sub(start + 1, start + maxBytes)
				while #chunk > 0 and not util.validUtf8(chunk) do chunk = chunk:sub(1, -2) end
				local nextOffset = start + #chunk
				return {
					ok = true,
					path = path,
					totalBytes = #content,
					offset = start,
					bytes = #chunk,
					truncated = nextOffset < #content,
					nextOffset = nextOffset < #content and nextOffset or nil,
					content = chunk,
				}
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
					project = { type = "string", description = "Optional named project; requires authorization for non-active projects" },
				},
				required = { "query" },
			},
			run = function(args)
				local project, accessErr = projectAccess(args.project)
				if not project then return { ok = false, error = accessErr } end
				local q = tostring(args.query or ""):lower()
				if q == "" then return { ok = false, error = "Empty query" } end
				local hits = {}
				local paths
				if project == workspaceFs.activeName then paths = workspaceFs.allFiles("")
				else paths = workspaceFs.listProjectFiles(project) end
				if type(paths) ~= "table" then return { ok = false, error = "Unable to list authorized project files" } end
				for _, path in ipairs(paths) do
					local body
					if project == workspaceFs.activeName then body = workspaceFs.readFile(path)
					else body = workspaceFs.readProjectFile(project, path) end
					body = body or ""
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
			name = "ai_workspace_list_files",
			readOnly = true,
			description = "List files in the private AI workspace for the active conversation thread, separate from project files and live game.",
			parameters = {
				type = "object",
				properties = {
					offset = { type = "number", description = "Zero-based result offset" },
					limit = { type = "number", description = "Page size (1-300, default 150)" },
				},
			},
			run = function(args)
				local page = aiWorkspace.listFiles(args)
				page.ok = true
				return page
			end,
		},
		{
			name = "ai_workspace_read_file",
			readOnly = true,
			description = "Read a file from the private workspace for the active AI conversation thread, separate from project files.",
			parameters = {
				type = "object",
				properties = { path = { type = "string", description = "Path relative to the private AI workspace" } },
				required = { "path" },
			},
			run = function(args)
				local path = tostring(args.path or "")
				local content, err = aiWorkspace.readFile(path)
				if content == nil then return { ok = false, error = tostring(err or "AI workspace file not found") } end
				return { ok = true, path = path, root = aiWorkspace.rootPath(), bytes = #content, content = content }
			end,
		},
		{
			name = "ai_workspace_write_file",
			readOnly = false,
			description = "Create or overwrite a file in the private workspace for the active AI conversation thread. This never writes to the active project workspace.",
			parameters = {
				type = "object",
				properties = {
					path = { type = "string", description = "Path relative to the private AI workspace" },
					content = { type = "string", description = "Full file content (maximum 8 MB)" },
				},
				required = { "path", "content" },
			},
			run = function(args)
				local path = tostring(args.path or "")
				local content = tostring(args.content or "")
				local ok, err = aiWorkspace.writeFile(path, content)
				if not ok then return { ok = false, error = tostring(err) } end
				return { ok = true, path = path, root = aiWorkspace.rootPath(), bytes = #content }
			end,
		},
		{
			name = "ai_workspace_transfer_to_project",
			readOnly = false,
			requiresApproval = true,
			description = "Explicitly copy one AI artifact into the active project workspace. This is permission-gated; it is never automatic, and destination files are not overwritten unless separately confirmed.",
			parameters = {
				type = "object",
				properties = {
					source = { type = "string", description = "Source path relative to the private AI workspace" },
					destination = { type = "string", description = "Destination path relative to the active project" },
					confirm_transfer = { type = "boolean", description = "Must be true only after the user explicitly requested this transfer" },
					overwrite_existing = { type = "boolean", description = "Must be true only after the user explicitly approved replacing an existing project file" },
				},
				required = { "source", "destination", "confirm_transfer" },
			},
			run = function(args)
				if args.confirm_transfer ~= true then return { ok = false, error = "Explicit user-requested transfer confirmation required" } end
				local source = tostring(args.source or "")
				local destination = tostring(args.destination or "")
				if source == "" or destination == "" then return { ok = false, error = "Source and destination are required" } end
				local content, readErr = aiWorkspace.readFile(source)
				if content == nil then return { ok = false, error = tostring(readErr or "AI artifact not found") } end
				if workspaceFs.readFile(destination) ~= nil and args.overwrite_existing ~= true then
					return { ok = false, error = "Destination already exists; explicit overwrite approval required" }
				end
				local ok, writeErr = workspaceFs.writeFile(destination, content)
				if not ok then return { ok = false, error = tostring(writeErr or "Project write failed") } end
				return {
					ok = true,
					transferred = true,
					from = aiWorkspace.rootPath() .. "/" .. source,
					to = workspaceFs.diskRootLabel() .. "/" .. destination,
					bytes = #content,
				}
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
			description = "Browse the live Roblox DataModel recursively. Start at game or a service, then inspect a returned Luau path. Bounded to protect the client.",
			parameters = {
				type = "object",
				properties = {
					service = { type = "string", description = "Optional service name (for example Workspace or ServerStorage)" },
					path = { type = "string", description = "Optional returned Luau/DataModel path to inspect more deeply" },
					depth = { type = "number", description = "Tree depth (1-4, default 2)" },
					limit = { type = "number", description = "Maximum returned instances (1-120, default 60)" },
				},
			},
			run = function(args)
				local serviceName = util.trim(tostring(args.service or ""))
				local path = util.trim(tostring(args.path or ""))
				if serviceName ~= "" and path ~= "" then
					return { ok = false, error = "Choose either service or path, not both" }
				end
				local target = env.game
				if path ~= "" then
					local resolveErr
					target, resolveErr = robloxExplorer.resolvePath(path)
					if not target then return { ok = false, error = tostring(resolveErr or "DataModel path not found") } end
				elseif serviceName ~= "" then
					local resolveErr
					target, resolveErr = robloxExplorer.resolvePath(serviceName)
					if not target then return { ok = false, error = tostring(resolveErr or ("Service not found: " .. serviceName)) } end
				end

				local maxDepth = math.floor(util.clamp(tonumber(args.depth) or 2, 1, 4))
				local maxNodes = math.floor(util.clamp(tonumber(args.limit) or 60, 1, 120))
				local visited = 0
				local truncated = false
				local function childCount(inst)
					local ok, children = pcall(function() return inst:GetChildren() end)
					return ok and type(children) == "table" and #children or 0
				end
				local function buildNode(inst, level)
					if visited >= maxNodes then truncated = true return nil end
					visited = visited + 1
					local name, className, isScript = "?", "Instance", false
					pcall(function()
						name = tostring(inst.Name or inst.ClassName or "?")
						className = tostring(inst.ClassName or "Instance")
						isScript = inst:IsA("LuaSourceContainer")
					end)
					local node = {
						name = name,
						className = className,
						luauPath = robloxExplorer.luauPathOf(inst),
						isScript = isScript == true,
					}
					local totalChildren = childCount(inst)
					if totalChildren > 0 and level < maxDepth then
						node.children = {}
						local available = math.max(1, maxNodes - visited)
						local listed = robloxExplorer.childrenOf(inst, available)
						if #listed < totalChildren then truncated = true end
						for _, child in ipairs(listed) do
							if visited >= maxNodes then truncated = true break end
						local childNode = buildNode(child.instance, level + 1)
						if childNode then node.children[#node.children + 1] = childNode end
						if truncated and visited >= maxNodes then break end
					end
				elseif totalChildren > 0 and level >= maxDepth then
					node.hasMore = true
						truncated = true
				end
				return node
				end
				local tree = buildNode(target, 0)
				return {
					ok = tree ~= nil,
					rootPath = path ~= "" and path or (serviceName ~= "" and serviceName or "game"),
					depth = maxDepth,
					count = visited,
					truncated = truncated,
					tree = tree,
				}
			end,
		},
		{
			name = "read_roblox_script",
			readOnly = true,
			description = "Read an accessible Script, LocalScript, or ModuleScript from a returned live DataModel path. Source/decompile access depends on executor capabilities.",
			parameters = {
				type = "object",
				properties = { path = { type = "string", description = "Luau path from inspect_roblox_tree" } },
				required = { "path" },
			},
			run = function(args)
				local path = util.trim(tostring(args.path or ""))
				if path == "" then return { ok = false, error = "Script path is required" } end
				local inst, resolveErr = robloxExplorer.resolvePath(path)
				if not inst then return { ok = false, error = tostring(resolveErr or "Instance not found") } end
				local isScript = false
				pcall(function() isScript = inst:IsA("LuaSourceContainer") end)
				if not isScript then return { ok = false, error = "Target is not a readable script container" } end
				local source, sourceKind = robloxExplorer.readScriptSource(inst)
				if type(source) ~= "string" then return { ok = false, error = tostring(sourceKind or "Source unavailable") } end
				local originalBytes = #source
				local maxBytes = 65536
				if originalBytes > maxBytes then
					source = source:sub(1, maxBytes)
					while #source > 0 and not util.validUtf8(source) do source = source:sub(1, -2) end
				end
				return {
					ok = true,
					path = robloxExplorer.luauPathOf(inst),
					name = tostring(inst.Name or "Script"),
					className = tostring(inst.ClassName or "LuaSourceContainer"),
					sourceKind = sourceKind,
					bytes = originalBytes,
					truncated = originalBytes > #source,
					source = source,
				}
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
