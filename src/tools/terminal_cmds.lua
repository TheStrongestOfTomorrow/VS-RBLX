-- Supercharged Integrated VS Code Terminal Shell (`src/tools/terminal_cmds.lua`):
-- Multi-session state (`sessions`, `newSession`, `switchSession`, `closeSession`),
-- Command history (`historyPrev`, `historyNext`), Tab path/command autocomplete,
-- Full UNIX CLI (`ls -l`, `tree`, `cd`, `pwd`, `cat`, `head`, `tail`, `wc`, `cp`, `mv`,
-- `touch`, `mkdir`, `rm`, `echo > / >>`, `grep`, `find`, `open`),
-- Deep Git/Gist CLI (`status`, `diff`, `stage`, `unstage`, `discard`, `log`, `branch`,
-- `checkout`, `clone`, `pull`, `commit`, `push`, `gist import/publish`),
-- Roblox CLI (`rblx services/tree/props/path/decompile`), `bundle`, `run`, and `luau`.
return function(env)
	local util = env.require("runtime/util")
	local fsx = env.require("runtime/fsx")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")
	local codeDiff = env.require("runtime/code_diff")
	local codeSearch = env.require("runtime/code_search")
	local gitState = env.require("runtime/git_state")
	local robloxExplorer = env.require("runtime/roblox_explorer")
	local clipboard = env.require("runtime/clipboard")
	local githubSync = env.require("tools/github_sync")
	local decompiler = env.require("tools/decompiler")
	local projectBundler = env.require("tools/project_bundler")
	local execution = env.require("tools/execution")
	local theme = env.require("ui/theme")
	local signal = env.require("runtime/signal")

	local TOP_COMMANDS = {
		"help", "clear", "pwd", "ls", "tree", "cd", "cat", "head", "tail", "wc",
		"touch", "mkdir", "cp", "mv", "rm", "echo", "grep", "find", "open",
		"git", "gist", "rblx", "bundle", "run", "luau", "theme",
	}

	local GIT_SUBS = {
		"status", "diff", "stage", "add", "unstage", "discard", "checkout",
		"branch", "log", "clone", "pull", "commit", "push",
	}

	local RBLX_SUBS = { "services", "tree", "props", "path", "decompile" }

	local sessionSeq = 0
	local function makeBannerLines(title)
		return {
			string.format("VS-RBLX Integrated Shell (%s) — Executor FS: %s", title, fsx.isBackedByDisk() and "Active" or "Virtual"),
			"Type `help` for UNIX, Git/Gist, Roblox DataModel (`rblx`), Bundler (`bundle`), and Luau REPL commands.",
		}
	end

	local M = {
		sessions = {},
		activeSessionId = nil,
		lines = {},
		cwd = "",
		changed = signal.new("terminal.changed"),
	}

	local function syncActiveRefs()
		local cur = M.activeSession()
		if cur then
			M.lines = cur.lines
			M.cwd = cur.cwd
		end
	end

	function M.activeSession()
		for _, s in ipairs(M.sessions) do
			if s.id == M.activeSessionId then
				return s
			end
		end
		return M.sessions[1]
	end

	function M.newSession(customTitle)
		sessionSeq = sessionSeq + 1
		local title = customTitle or ("luau-" .. tostring(sessionSeq))
		local sess = {
			id = "term_" .. tostring(sessionSeq),
			title = title,
			cwd = "",
			lines = makeBannerLines(title),
			history = {},
			historyIdx = 0,
		}
		M.sessions[#M.sessions + 1] = sess
		M.activeSessionId = sess.id
		syncActiveRefs()
		M.changed:fire()
		return sess
	end

	function M.switchSession(id)
		for _, s in ipairs(M.sessions) do
			if s.id == id then
				M.activeSessionId = s.id
				syncActiveRefs()
				M.changed:fire()
				return s
			end
		end
		return nil
	end

	function M.closeSession(id)
		if #M.sessions <= 1 then
			M.clear()
			return false
		end
		for i, s in ipairs(M.sessions) do
			if s.id == id then
				table.remove(M.sessions, i)
				if M.activeSessionId == id then
					local fallback = M.sessions[math.min(i, #M.sessions)]
					M.activeSessionId = fallback.id
				end
				syncActiveRefs()
				M.changed:fire()
				return true
			end
		end
		return false
	end

	-- Create initial terminal session
	M.newSession("luau-1")

	local function writeLine(text)
		local sess = M.activeSession()
		if not sess then return end
		for _, ln in ipairs(util.splitLines(tostring(text or ""))) do
			sess.lines[#sess.lines + 1] = ln
			if #sess.lines > 400 then table.remove(sess.lines, 1) end
		end
		syncActiveRefs()
		M.changed:fire()
	end

	function M.print(text)
		writeLine(text)
	end

	function M.clear()
		local sess = M.activeSession()
		if sess then
			sess.lines = {}
			syncActiveRefs()
		end
		M.changed:fire()
	end

	local function resolveRel(sess, p)
		p = util.normalizePath(p or "")
		if p == "" or p == "." then return sess.cwd end
		if p == "/" or p == "~" then return "" end
		if p == ".." then return util.dirname(sess.cwd) end
		if p:sub(1, 3) == "../" then
			return util.joinPath(util.dirname(sess.cwd), p:sub(4))
		end
		if sess.cwd ~= "" and not workspaceFs.exists(p) then
			return util.joinPath(sess.cwd, p)
		end
		return p
	end

	function M.historyPrev()
		local sess = M.activeSession()
		if not sess or #sess.history == 0 then return nil end
		if sess.historyIdx <= 1 then
			sess.historyIdx = 1
		else
			sess.historyIdx = sess.historyIdx - 1
		end
		return sess.history[sess.historyIdx]
	end

	function M.historyNext()
		local sess = M.activeSession()
		if not sess or #sess.history == 0 then return "" end
		if sess.historyIdx >= #sess.history then
			sess.historyIdx = #sess.history + 1
			return ""
		end
		sess.historyIdx = sess.historyIdx + 1
		return sess.history[sess.historyIdx] or ""
	end

	function M.autocomplete(rawLine)
		local sess = M.activeSession()
		local text = tostring(rawLine or "")
		local lead, token = text:match("^(.-)([^%s]*)$")
		lead = lead or ""
		token = token or ""
		local lowerTok = token:lower()

		local words = {}
		for w in text:gmatch("%S+") do words[#words + 1] = w end

		local candidates = {}
		if lead == "" then
			for _, cmd in ipairs(TOP_COMMANDS) do
				if cmd:sub(1, #lowerTok) == lowerTok then
					candidates[#candidates + 1] = cmd
				end
			end
		elseif words[1] == "git" and (#words == 1 or (#words == 2 and text:sub(-1) ~= " ")) then
			for _, sub in ipairs(GIT_SUBS) do
				if sub:sub(1, #lowerTok) == lowerTok then
					candidates[#candidates + 1] = sub
				end
			end
		elseif words[1] == "rblx" and (#words == 1 or (#words == 2 and text:sub(-1) ~= " ")) then
			for _, sub in ipairs(RBLX_SUBS) do
				if sub:sub(1, #lowerTok) == lowerTok then
					candidates[#candidates + 1] = sub
				end
			end
		else
			for _, f in ipairs(workspaceFs.allFiles()) do
				local rel = f
				if sess and sess.cwd ~= "" and f:sub(1, #sess.cwd + 1) == (sess.cwd .. "/") then
					rel = f:sub(#sess.cwd + 2)
				end
				if rel:lower():sub(1, #lowerTok) == lowerTok then
					candidates[#candidates + 1] = rel
				elseif f:lower():sub(1, #lowerTok) == lowerTok then
					candidates[#candidates + 1] = f
				end
			end
		end

		table.sort(candidates)
		if #candidates == 0 then
			return text, candidates
		elseif #candidates == 1 then
			return lead .. candidates[1], candidates
		end

		-- Common prefix among candidates
		local prefix = candidates[1]
		for i = 2, #candidates do
			local c = candidates[i]
			local j = 1
			while j <= #prefix and j <= #c and prefix:sub(j, j):lower() == c:sub(j, j):lower() do
				j = j + 1
			end
			prefix = prefix:sub(1, j - 1)
		end
		if #prefix > #token then
			return lead .. prefix, candidates
		end
		return lead .. candidates[1], candidates
	end

	local function buildAsciiTree(dirRel, indent, outLines, depth)
		if depth > 5 or #outLines > 120 then return end
		local entries = workspaceFs.listTree(dirRel)
		for idx, e in ipairs(entries) do
			local isLast = (idx == #entries)
			local branch = isLast and "└── " or "├── "
			outLines[#outLines + 1] = indent .. branch .. e.name .. (e.isDir and "/" or "")
			if e.isDir then
				buildAsciiTree(e.path, indent .. (isLast and "    " or "│   "), outLines, depth + 1)
			end
		end
	end

	function M.execute(cmdLine)
		local sess = M.activeSession()
		if not sess then sess = M.newSession("luau-1") end

		local raw = util.trim(cmdLine)
		if raw == "" then return end

		if sess.history[#sess.history] ~= raw then
			sess.history[#sess.history + 1] = raw
			if #sess.history > 80 then table.remove(sess.history, 1) end
		end
		sess.historyIdx = #sess.history + 1

		writeLine(string.format("vsrblx:%s/%s$ %s", workspaceFs.activeName, sess.cwd, raw))

		-- Support `echo ... > file` and `echo ... >> file` redirection
		if raw:sub(1, 5) == "echo " or raw == "echo" then
			local body = raw:sub(6)
			local textPart, op, targetFile = body:match("^(.-)%s*(>>?)%s*(%S+)%s*$")
			if op and targetFile then
				local cleanText = util.trim(textPart):gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
				local dst = resolveRel(sess, targetFile)
				if op == ">>" then
					local prev = workspaceFs.readFile(dst) or ""
					local sep = (prev ~= "" and prev:sub(-1) ~= "\n") and "\n" or ""
					workspaceFs.writeFile(dst, prev .. sep .. cleanText .. "\n")
				else
					workspaceFs.writeFile(dst, cleanText .. "\n")
				end
				local openDoc = codeStore.findByPath(dst)
				if openDoc then codeStore.openFile(dst, { reloadFromDisk = true }) end
				writeLine(string.format("Wrote %s (%s)", dst, op))
				return
			else
				local cleanText = body:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
				writeLine(cleanText)
				return
			end
		end

		local args = {}
		for token in raw:gmatch("%S+") do args[#args + 1] = token end
		local cmd = (args[1] or ""):lower()

		if cmd == "help" then
			writeLine(table.concat({
				"UNIX Commands:   ls [-l] [dir], tree [dir], pwd, cd <dir>, cat <file>, head/tail [-n] <file>, wc <file>",
				"File Ops:        touch <file>, mkdir <dir>, cp <src> <dst>, mv <src> <dst>, rm <path>, echo <txt> > <file>",
				"Search & Open:   grep <query>, find <name>, open <file>, clear",
				"Git & Gist:      git status|diff|stage|unstage|discard|log|branch|checkout|clone|pull|commit|push",
				"                 gist import <id|url> | gist publish [public|secret]",
				"Roblox & Build:  rblx services | rblx tree [path] | rblx props <path> | rblx path <path> | rblx decompile <path>",
				"                 bundle [out.lua] | run [file.luau] | luau <code...> | theme [id]",
			}, "\n"))
		elseif cmd == "clear" or cmd == "cls" then
			M.clear()
		elseif cmd == "pwd" then
			writeLine(workspaceFs.diskPath(sess.cwd))
		elseif cmd == "ls" or cmd == "dir" then
			local longFmt = (args[2] == "-l" or args[2] == "-la")
			local dirArg = longFmt and args[3] or args[2]
			local target = dirArg and resolveRel(sess, dirArg) or sess.cwd
			local entries = workspaceFs.listTree(target)
			if #entries == 0 then
				writeLine("(empty directory)")
			elseif longFmt then
				for _, e in ipairs(entries) do
					if e.isDir then
						writeLine(string.format("drwxr-xr-x      -  %s/", e.name))
					else
						local content = workspaceFs.readFile(e.path) or ""
						writeLine(string.format("-rw-r--r-- %6dB  %s", #content, e.name))
					end
				end
			else
				local out = {}
				for _, e in ipairs(entries) do
					out[#out + 1] = e.isDir and (e.name .. "/") or e.name
				end
				writeLine(table.concat(out, "   "))
			end
		elseif cmd == "tree" then
			local target = args[2] and resolveRel(sess, args[2]) or sess.cwd
			local lines = { (target ~= "" and target or workspaceFs.activeName) .. "/" }
			buildAsciiTree(target, "", lines, 1)
			writeLine(table.concat(lines, "\n"))
		elseif cmd == "cd" then
			local nxt = resolveRel(sess, args[2] or "")
			if nxt == "" or workspaceFs.isDir(nxt) then
				sess.cwd = nxt
				syncActiveRefs()
				M.changed:fire()
			else
				writeLine("cd: directory not found: " .. tostring(args[2]))
			end
		elseif cmd == "cat" then
			if not args[2] then writeLine("Usage: cat <file>") return end
			local p = resolveRel(sess, args[2])
			local content = workspaceFs.readFile(p)
			writeLine(content or ("cat: cannot read " .. p))
		elseif cmd == "head" or cmd == "tail" then
			local n = 10
			local fileArg = args[2]
			if fileArg and fileArg:match("^%-%d+$") then
				n = tonumber(fileArg:sub(2)) or 10
				fileArg = args[3]
			end
			if not fileArg then writeLine("Usage: " .. cmd .. " [-n] <file>") return end
			local p = resolveRel(sess, fileArg)
			local content = workspaceFs.readFile(p)
			if not content then writeLine(cmd .. ": cannot read " .. p) return end
			local lns = util.splitLines(content)
			local slice = {}
			if cmd == "head" then
				for i = 1, math.min(n, #lns) do slice[#slice + 1] = lns[i] end
			else
				for i = math.max(1, #lns - n + 1), #lns do slice[#slice + 1] = lns[i] end
			end
			writeLine(table.concat(slice, "\n"))
		elseif cmd == "wc" then
			if not args[2] then writeLine("Usage: wc <file>") return end
			local p = resolveRel(sess, args[2])
			local content = workspaceFs.readFile(p)
			if not content then writeLine("wc: cannot read " .. p) return end
			local lns = util.splitLines(content)
			local wordCount = 0
			for _ in content:gmatch("%S+") do wordCount = wordCount + 1 end
			writeLine(string.format("%5d lines  %6d words  %7d bytes  %s", #lns, wordCount, #content, p))
		elseif cmd == "open" or cmd == "code" then
			if not args[2] then writeLine("Usage: open <file>") return end
			local p = resolveRel(sess, args[2])
			if not workspaceFs.exists(p) then workspaceFs.writeFile(p, "") end
			codeStore.openFile(p)
			writeLine("Opened " .. p)
		elseif cmd == "touch" then
			if not args[2] then writeLine("Usage: touch <file>") return end
			local p = resolveRel(sess, args[2])
			if not workspaceFs.exists(p) then
				workspaceFs.writeFile(p, "")
			end
			writeLine("Touched " .. p .. " on disk")
		elseif cmd == "mkdir" then
			if not args[2] then writeLine("Usage: mkdir <folder>") return end
			local p = resolveRel(sess, args[2])
			workspaceFs.createFolder(p)
			writeLine("Created directory " .. p)
		elseif cmd == "cp" then
			if not args[2] or not args[3] then writeLine("Usage: cp <src> <dst>") return end
			local src = resolveRel(sess, args[2])
			local dst = resolveRel(sess, args[3])
			local body = workspaceFs.readFile(src)
			if not body then writeLine("cp: source not found: " .. src) return end
			workspaceFs.writeFile(dst, body)
			writeLine(string.format("Copied %s -> %s (%d bytes)", src, dst, #body))
		elseif cmd == "mv" then
			if not args[2] or not args[3] then writeLine("Usage: mv <src> <dst>") return end
			local src = resolveRel(sess, args[2])
			local dst = resolveRel(sess, args[3])
			local ok = workspaceFs.renamePath(src, dst)
			if ok then
				codeStore.renameOpenPath(src, dst)
				writeLine(string.format("Moved %s -> %s", src, dst))
			else
				writeLine("mv: failed to move " .. src)
			end
		elseif cmd == "rm" then
			if not args[2] then writeLine("Usage: rm <file>") return end
			local targetArg = (args[2] == "-rf" or args[2] == "-r") and args[3] or args[2]
			if not targetArg then writeLine("Usage: rm <path>") return end
			local p = resolveRel(sess, targetArg)
			workspaceFs.deletePath(p)
			writeLine("Deleted " .. p)
		elseif cmd == "grep" then
			local query = args[2]
			if not query then writeLine("Usage: grep <pattern>") return end
			local res = codeSearch.searchWorkspace(query, { caseSensitive = false, limit = 30 })
			if res.totalMatches == 0 then
				writeLine("No matches for: " .. query)
			else
				for _, fg in ipairs(res.files) do
					for _, h in ipairs(fg.matches) do
						writeLine(string.format("%s:%d: %s", fg.path, h.line, util.trim(h.lineText or "")))
					end
				end
			end
		elseif cmd == "find" then
			local needle = (args[2] or ""):lower()
			local hits = {}
			for _, rel in ipairs(workspaceFs.allFiles()) do
				if needle == "" or rel:lower():find(needle, 1, true) then
					hits[#hits + 1] = rel
				end
			end
			writeLine(#hits > 0 and table.concat(hits, "\n") or "(no matching files)")
		elseif cmd == "run" then
			if args[2] then
				local p = resolveRel(sess, args[2])
				local src = workspaceFs.readFile(p)
				if not src then writeLine("File not found: " .. p) return end
				local ok, res = execution.runSource(src, p)
				writeLine(ok and ("Result: " .. tostring(res)) or tostring(res))
			else
				local ok, res = execution.runActive()
				writeLine(ok and ("Executed active buffer -> " .. tostring(res)) or tostring(res))
			end
		elseif cmd == "luau" or cmd == "lua" then
			local snippet = raw:sub(#args[1] + 2)
			local ok, res = execution.runSource(snippet, "terminal-repl")
			writeLine(ok and ("=> " .. tostring(res)) or tostring(res))
		elseif cmd == "bundle" then
			local res, err = projectBundler.bundleWorkspace(args[2])
			if not res then
				writeLine("Bundle error: " .. tostring(err))
			else
				writeLine(string.format(
					"Bundled %d module(s) -> %s (%d lines, %d bytes) [Copied to clipboard]",
					res.modules, res.outputPath, res.lines, res.bytes
				))
			end
		elseif cmd == "gist" then
			local sub = (args[2] or ""):lower()
			if sub == "import" and args[3] then
				task.spawn(function()
					writeLine("Importing GitHub Gist " .. args[3] .. "...")
					local res, err = githubSync.importGist(args[3])
					if res then
						writeLine(string.format("Imported %d file(s) into gists/", res.count))
					else
						writeLine("Gist import error: " .. tostring(err))
					end
				end)
			elseif sub == "publish" then
				local isPub = (args[3] == "public")
				task.spawn(function()
					writeLine("Publishing active buffer to GitHub Gist...")
					local res, err = githubSync.publishActiveGist({ public = isPub })
					if res then
						writeLine("Published Gist: " .. tostring(res.url) .. " (copied to clipboard)")
					else
						writeLine("Gist publish error: " .. tostring(err))
					end
				end)
			else
				writeLine("Usage: gist import <id|url> | gist publish [public|secret]")
			end
		elseif cmd == "rblx" then
			local sub = (args[2] or "services"):lower()
			local rest = util.trim(raw:match("^%S+%s+%S+%s+(.+)$") or "")
			if sub == "services" then
				local svcs = robloxExplorer.rootServices()
				local names = {}
				for _, s in ipairs(svcs) do
					names[#names + 1] = string.format("%-20s (%s)", s.name, s.className)
				end
				writeLine(#names > 0 and table.concat(names, "\n") or "(no DataModel services exposed)")
			elseif sub == "tree" then
				local inst, err = robloxExplorer.resolvePath(rest ~= "" and rest or "workspace")
				if not inst then writeLine("rblx tree: " .. tostring(err)) return end
				local out = { robloxExplorer.luauPathOf(inst) .. " [" .. tostring(inst.ClassName) .. "]" }
				for _, ch in ipairs(robloxExplorer.childrenOf(inst, 40)) do
					out[#out + 1] = string.format("  ├── %s (%s)", ch.name, ch.className)
				end
				writeLine(table.concat(out, "\n"))
			elseif sub == "props" then
				if rest == "" then writeLine("Usage: rblx props <InstancePath>") return end
				local inst, err = robloxExplorer.resolvePath(rest)
				if not inst then writeLine("rblx props: " .. tostring(err)) return end
				local props = robloxExplorer.inspectProperties(inst)
				local out = {}
				for _, kv in ipairs(props) do
					out[#out + 1] = string.format("  %-18s = %s", kv.key, kv.value)
				end
				writeLine(table.concat(out, "\n"))
			elseif sub == "path" then
				if rest == "" then writeLine("Usage: rblx path <InstancePath>") return end
				local inst, err = robloxExplorer.resolvePath(rest)
				if not inst then writeLine("rblx path: " .. tostring(err)) return end
				local luauPath = robloxExplorer.luauPathOf(inst)
				clipboard.copy(luauPath)
				writeLine("Luau Path (copied): " .. luauPath)
			elseif sub == "decompile" then
				if rest == "" then writeLine("Usage: rblx decompile <InstancePath>") return end
				local inst, err = robloxExplorer.resolvePath(rest)
				if not inst then writeLine("rblx decompile: " .. tostring(err)) return end
				local doc, derr = decompiler.openInstanceScript(inst, true)
				if doc then
					writeLine("Decompiled & saved to workspace: " .. tostring(doc.path))
				else
					writeLine("Decompile error: " .. tostring(derr))
				end
			else
				writeLine("Usage: rblx services | tree [path] | props <path> | path <path> | decompile <path>")
			end
		elseif cmd == "git" then
			local sub = (args[2] or "status"):lower()
			if sub == "status" then
				local st = gitState.status()
				writeLine(string.format("On branch %s | Repo: %s", st.branch or "main", tostring(st.repo or "(unlinked)")))
				if st.total == 0 then
					writeLine("nothing to commit, working tree clean")
				else
					for _, c in ipairs(st.staged) do writeLine("  staged  [" .. c.status .. "] " .. c.path) end
					for _, c in ipairs(st.unstaged) do writeLine("  changed [" .. c.status .. "] " .. c.path) end
				end
			elseif sub == "diff" then
				local targetFile = args[3] and resolveRel(sess, args[3]) or nil
				local st = gitState.status()
				local targets = {}
				if targetFile then
					targets[#targets + 1] = targetFile
				else
					for _, c in ipairs(st.staged) do targets[#targets + 1] = c.path end
					for _, c in ipairs(st.unstaged) do targets[#targets + 1] = c.path end
				end
				if #targets == 0 then
					writeLine("No working tree differences.")
				else
					for _, p in ipairs(targets) do
						local orig = gitState.originalContent(p) or ""
						local cur = workspaceFs.readFile(p) or ""
						local d = codeDiff.compute(orig, cur)
						writeLine(string.format("--- a/%s\n+++ b/%s  (+%d, -%d)", p, p, d.added, d.removed))
						local shown = 0
						for _, r in ipairs(d.rows) do
							if r.kind ~= "context" and shown < 24 then
								shown = shown + 1
								writeLine((r.kind == "add" and "+ " or "- ") .. r.text)
							end
						end
					end
				end
			elseif sub == "stage" or sub == "add" then
				if not args[3] or args[3] == "." or args[3] == "all" or args[3] == "-A" then
					gitState.stageAll()
					writeLine("Staged all modified files.")
				else
					local p = resolveRel(sess, args[3])
					gitState.stage(p)
					writeLine("Staged " .. p)
				end
			elseif sub == "unstage" or sub == "reset" then
				if not args[3] or args[3] == "." or args[3] == "all" then
					gitState.unstageAll()
					writeLine("Unstaged all files.")
				else
					local p = resolveRel(sess, args[3])
					gitState.unstage(p)
					writeLine("Unstaged " .. p)
				end
			elseif sub == "discard" then
				if not args[3] then writeLine("Usage: git discard <file>") return end
				local p = resolveRel(sess, args[3])
				gitState.discardFile(p)
				if codeStore.findByPath(p) then
					codeStore.openFile(p, { reloadFromDisk = true })
				end
				writeLine("Discarded local changes in " .. p)
			elseif sub == "log" then
				if #gitState.commits == 0 then
					writeLine("No recorded commits in this workspace yet.")
				else
					for i = 1, math.min(12, #gitState.commits) do
						local c = gitState.commits[i]
						writeLine(string.format("%s  (%s)  %s", tostring(c.sha or ""):sub(1, 7), tostring(c.time or ""), tostring(c.message or "")))
					end
				end
			elseif sub == "branch" then
				if args[3] then
					task.spawn(function()
						local created, err = githubSync.createBranch(args[3])
						writeLine(created and ("Created & switched to branch " .. args[3]) or ("Branch error: " .. tostring(err)))
					end)
				else
					writeLine("* " .. tostring(gitState.branch or "main"))
				end
			elseif sub == "checkout" then
				if not args[3] then writeLine("Usage: git checkout <branch>") return end
				gitState.branch = args[3]
				gitState.saveMeta()
				gitState.changed:fire()
				if gitState.repo then
					task.spawn(function()
						local snap, err = githubSync.cloneRepo(gitState.repo, { branch = args[3] })
						writeLine(snap and ("Switched to branch " .. args[3]) or ("Checkout error: " .. tostring(err)))
					end)
				else
					writeLine("Switched local branch to " .. args[3])
				end
			elseif sub == "clone" and args[3] then
				task.spawn(function()
					writeLine("Cloning " .. args[3] .. " via HTTP...")
					local snap, err = githubSync.cloneRepo(args[3], { branch = args[4] })
					writeLine(snap and string.format("Cloned %s (%d files) to disk!", snap.fullName, snap.written) or ("Clone error: " .. tostring(err)))
				end)
			elseif sub == "pull" then
				task.spawn(function()
					local snap, err = githubSync.pull()
					writeLine(snap and ("Pulled " .. snap.fullName) or ("Pull error: " .. tostring(err)))
				end)
			elseif sub == "commit" or sub == "push" then
				local msg = raw:match('^git%s+%S+%s+%-m%s+"([^"]+)"')
					or raw:match("^git%s+%S+%s+(.+)$")
					or "Update from VS-RBLX terminal"
				task.spawn(function()
					writeLine("Pushing commit via GitHub REST API...")
					local res, err = githubSync.commitAndPush(msg)
					writeLine(res and ("Pushed commit " .. res.commitSha:sub(1, 7) .. " (" .. res.files .. " files)") or ("Push error: " .. tostring(err)))
				end)
			else
				writeLine("Git subcommands: status, diff, stage, unstage, discard, log, branch, checkout, clone, pull, commit, push")
			end
		elseif cmd == "theme" then
			if args[2] then
				theme.apply(args[2])
				writeLine("Switched theme to " .. theme.currentId)
			else
				local names = {}
				for _, t in ipairs(theme.list()) do names[#names + 1] = t.id end
				writeLine("Themes: " .. table.concat(names, ", "))
			end
		else
			writeLine("Unknown command `" .. cmd .. "`. Type `help` for available commands.")
		end
	end

	return M
end
