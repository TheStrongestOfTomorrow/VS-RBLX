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
