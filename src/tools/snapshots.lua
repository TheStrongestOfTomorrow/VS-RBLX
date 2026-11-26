-- Offline Workspace Snapshots (`VSRBLX/snapshots/`) & Executor `autoexec` Exporter (`src/tools/snapshots.lua`).
return function(env)
	local fsx = env.require("runtime/fsx")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")
	local util = env.require("runtime/util")
	local log = env.require("runtime/log")

	local SNAP_INDEX = "snapshots/index.json"

	local M = {}

	function M.list()
		local raw = fsx.read(SNAP_INDEX)
		if not raw then return {} end
		local arr = util.jsonDecode(raw)
		return type(arr) == "table" and arr or {}
	end

	local function saveIndex(list)
		local raw = util.jsonEncode(list)
		if raw then fsx.write(SNAP_INDEX, raw) end
	end

	function M.createSnapshot(label)
		local files = {}
		local count = 0
		for _, relPath in ipairs(workspaceFs.allFiles("")) do
			local body = workspaceFs.readFile(relPath)
			if body ~= nil then
				files[relPath] = body
				count = count + 1
			end
		end

		local id = string.format("snap_%d_%d", math.floor(os.time and os.time() or 0), math.random(1000, 9999))
		local title = util.trim(tostring(label or ""))
		if title == "" then title = "Checkpoint (" .. tostring(count) .. " files)" end

		local payload = util.jsonEncode({
			id = id,
			label = title,
			workspace = workspaceFs.activeName,
			fileCount = count,
			createdAt = os.date and os.date("!%Y-%m-%dT%H:%M:%SZ") or "now",
			files = files,
		})
		if not payload then return nil, "Failed to encode snapshot" end

		local okW, err = fsx.write("snapshots/" .. id .. ".json", payload)
		if not okW then return nil, err end

		local index = M.list()
		table.insert(index, 1, {
			id = id,
			label = title,
			workspace = workspaceFs.activeName,
			fileCount = count,
		})
		while #index > 25 do table.remove(index) end
		saveIndex(index)

		log.info("snapshots", string.format("Created snapshot %s (%d files)", id, count))
		return { id = id, label = title, fileCount = count }
	end

	function M.restoreSnapshot(id)
		local raw = fsx.read("snapshots/" .. tostring(id or "") .. ".json")
		if not raw then return nil, "Snapshot not found: " .. tostring(id) end
		local snap = util.jsonDecode(raw)
		if type(snap) ~= "table" or type(snap.files) ~= "table" then
			return nil, "Corrupted snapshot archive"
		end

		local restored = 0
		for relPath, content in pairs(snap.files) do
			if workspaceFs.writeFile(relPath, tostring(content)) then
				restored = restored + 1
			end
		end
		for _, doc in ipairs(codeStore.tabs) do
			if doc.path and snap.files[doc.path] ~= nil then
				codeStore.openFile(doc.path, { reloadFromDisk = true })
			end
		end
		log.info("snapshots", string.format("Restored snapshot %s (%d files)", tostring(id), restored))
		return { id = id, label = snap.label, restored = restored }
	end

	-- Save active Luau script to Executor `autoexec/` (plus `VSRBLX/autoexec/` backup!)
	function M.saveActiveToAutoexec(customName)
		local doc = codeStore.active("primary")
		if not doc then return nil, "No active script open in editor" end
		local baseName = util.trim(tostring(customName or doc.title or "vsrblx_script.lua"))
		baseName = baseName:gsub("[^%w%._%-]", "_")
		if not baseName:match("%.lua$") and not baseName:match("%.luau$") then
			baseName = baseName .. ".lua"
		end

		-- Always write backup inside `VSRBLX/autoexec/<name>`
		fsx.write("autoexec/" .. baseName, doc.content or "")

		-- Also attempt root executor `autoexec/<name>` if `writefile` is available!
		local wroteRootAutoexec = false
		local wf = env.caps and env.caps.fn and env.caps.fn.writefile
		local mf = env.caps and env.caps.fn and env.caps.fn.makefolder
		if type(wf) == "function" then
			if type(mf) == "function" then pcall(mf, "autoexec") end
			local okRoot = pcall(wf, "autoexec/" .. baseName, doc.content or "")
			wroteRootAutoexec = okRoot == true
		end

		local dest = wroteRootAutoexec and ("autoexec/" .. baseName) or ("VSRBLX/autoexec/" .. baseName)
		log.info("autoexec", "Saved script to " .. dest)
		return { path = dest, wroteRoot = wroteRootAutoexec, bytes = #(doc.content or "") }
	end

	return M
end
