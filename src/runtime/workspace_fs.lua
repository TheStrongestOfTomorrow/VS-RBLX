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

	local function cleanWorkspaceName(name)
		local raw = tostring(name or "")
		local clean, err = fsx.sanitise(raw)
		if not clean then return nil, err end
		if clean ~= raw or clean:find("/", 1, true) or clean == "" or clean == "." or clean == ".." then
			return nil, "Project workspace name must be one safe path segment"
		end
		return clean
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

	M.listTree = M.listDir

	function M.allFiles(subDir)
		local out = {}
		for _, item in ipairs(M.listAllFiles(subDir or "")) do
			out[#out + 1] = item.path
		end
		return out
	end

	-- Read-only named-project access for AI authorization scopes. Never changes the
	-- globally active workspace or emits editor change signals.
	function M.projectRoot(name)
		local clean, err = cleanWorkspaceName(name)
		if not clean then return nil, err end
		if M.rawMode then return nil, "Named project scopes are unavailable in raw filesystem mode" end
		return fsx.root .. "/workspaces/" .. clean, clean
	end

	function M.listProjectFiles(name)
		local root, cleanOrErr = M.projectRoot(name)
		if not root then return nil, cleanOrErr end
		local scope = { scope = "workspaces/" .. cleanOrErr }
		local out = {}
		local truncated = false
		local function walk(dir, depth)
			if depth > 14 or #out >= 1200 then truncated = true return end
			for _, item in ipairs(fsx.list(dir, scope)) do
				if item.isDir then
					if item.name ~= ".git" and item.name ~= "node_modules" then walk(item.path, depth + 1) end
				else
					out[#out + 1] = item.path
					if #out >= 1200 then truncated = true return end
				end
			end
		end
		walk("", 0)
		return out, nil, { root = root, truncated = truncated }
	end

	function M.readProjectFile(name, relPath)
		local clean, err = cleanWorkspaceName(name)
		if not clean then return nil, err end
		if M.rawMode then return nil, "Named project scopes are unavailable in raw filesystem mode" end
		local rel, pathErr = fsx.sanitise(relPath, false)
		if not rel then return nil, pathErr end
		return fsx.read(rel, { scope = "workspaces/" .. clean })
	end

	function M.diskPath(relPath)
		local clean = util.normalisePath(relPath or "")
		local root = M.diskRootLabel()
		if clean == "" then return root end
		return root .. "/" .. clean
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
