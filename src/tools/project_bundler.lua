-- 1-Click Multi-File Luau Workspace Bundler (`src/tools/project_bundler.lua`).
-- Packs all `.luau` / `.lua` modules in the active VS-RBLX workspace into a single
-- standalone, ready-to-share `.lua` script saved on local executor disk (`writefile`).
return function(env)
	local util = env.require("runtime/util")
	local clock = env.require("runtime/clock")
	local log = env.require("runtime/log")
	local clipboard = env.require("runtime/clipboard")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")

	local M = {}

	local ENTRY_CANDIDATES = {
		"init.luau",
		"init.lua",
		"src/main.luau",
		"src/main.lua",
		"src/init.luau",
		"src/init.lua",
		"main.luau",
		"main.lua",
	}

	local function stripLuaExt(path)
		return (path:gsub("%.luau$", ""):gsub("%.lua$", ""))
	end

	local function currentFileBody(relPath)
		local openDoc = codeStore.findByPath(relPath)
		if openDoc then
			return openDoc.content
		end
		return workspaceFs.readFile(relPath)
	end

	function M.bundleWorkspace(outputRelPath)
		local wsName = workspaceFs.activeName or "project"
		local defaultOut = "dist/" .. wsName:gsub("[^%w%-_]", "_") .. ".bundle.lua"
		local targetOut = util.normalisePath(outputRelPath ~= nil and outputRelPath ~= "" and outputRelPath or defaultOut)

		local allFiles = workspaceFs.listAllFiles("")
		local luaFiles = {}
		for _, item in ipairs(allFiles) do
			local p = util.normalisePath(item.path)
			if p ~= targetOut and not util.startsWith(p, "dist/") then
				if util.endsWith(p:lower(), ".luau") or util.endsWith(p:lower(), ".lua") then
					luaFiles[#luaFiles + 1] = p
				end
			end
		end
		table.sort(luaFiles)

		if #luaFiles == 0 then
			return nil, "No .luau or .lua files found in workspace '" .. wsName .. "'"
		end

		local entryPath = nil
		local fileSet = {}
		for _, p in ipairs(luaFiles) do fileSet[p] = true end
		for _, cand in ipairs(ENTRY_CANDIDATES) do
			if fileSet[cand] then
				entryPath = cand
				break
			end
		end
		if not entryPath then
			entryPath = luaFiles[1]
		end

		local chunks = {
			"-- Bundled by VS-RBLX Standalone Project Bundler",
			"-- Workspace: " .. wsName .. " (" .. tostring(#luaFiles) .. " Luau module(s))",
			"-- Entry: " .. entryPath .. " | Built at " .. clock.timestamp(),
			"",
			"local __BUNDLE_MODULES = {}",
			"local __BUNDLE_CACHE = {}",
			"local function __bundle_require(id)",
			"\tlocal clean = tostring(id):gsub('\\\\', '/'):gsub('^src/', ''):gsub('%.luau$', ''):gsub('%.lua$', '')",
			"\tif __BUNDLE_CACHE[clean] ~= nil then return __BUNDLE_CACHE[clean] end",
			"\tlocal fn = __BUNDLE_MODULES[clean] or __BUNDLE_MODULES['src/' .. clean]",
			"\tif not fn then error('Module not found in bundle: ' .. tostring(id), 2) end",
			"\tlocal res = fn(__bundle_require)",
			"\t__BUNDLE_CACHE[clean] = (res ~= nil) and res or true",
			"\treturn __BUNDLE_CACHE[clean]",
			"end",
			"",
		}

		local moduleCount = 0
		for _, relPath in ipairs(luaFiles) do
			if relPath ~= entryPath then
				local src = tostring(currentFileBody(relPath) or ""):gsub("\r\n", "\n")
				local modId = stripLuaExt(relPath)
				local shortId = modId:gsub("^src/", "")
				moduleCount = moduleCount + 1
				chunks[#chunks + 1] = string.format("-- [%s]", relPath)
				chunks[#chunks + 1] = string.format("__BUNDLE_MODULES[%q] = function(require)", shortId)
				chunks[#chunks + 1] = src
				chunks[#chunks + 1] = "end"
				if shortId ~= modId then
					chunks[#chunks + 1] = string.format("__BUNDLE_MODULES[%q] = __BUNDLE_MODULES[%q]", modId, shortId)
				end
				chunks[#chunks + 1] = ""
			end
		end

		local entrySrc = tostring(currentFileBody(entryPath) or ""):gsub("\r\n", "\n")
		chunks[#chunks + 1] = "-- [Entry: " .. entryPath .. "]"
		chunks[#chunks + 1] = "return (function(require)"
		chunks[#chunks + 1] = entrySrc
		chunks[#chunks + 1] = "end)(__bundle_require)"
		chunks[#chunks + 1] = ""

		local finalSource = table.concat(chunks, "\n")
		local ok, writeErr = workspaceFs.writeFile(targetOut, finalSource)
		if not ok then
			return nil, writeErr
		end

		clipboard.copy(finalSource)
		log.info("bundle", string.format("Bundled %d file(s) -> %s (%s)", #luaFiles, targetOut, util.formatBytes(#finalSource)))
		return {
			outputPath = targetOut,
			entryPath = entryPath,
			fileCount = #luaFiles,
			modules = #luaFiles,
			moduleCount = moduleCount,
			lines = util.countLines(finalSource),
			bytes = #finalSource,
			source = finalSource,
			content = finalSource,
		}
	end

	return M
end
