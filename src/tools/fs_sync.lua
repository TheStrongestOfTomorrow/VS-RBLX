-- Local executor disk workspace management (`readfile`, `writefile`, `listfiles`).
return function(env)
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")
	local gitState = env.require("runtime/git_state")
	local log = env.require("runtime/log")

	local M = {}

	function M.reloadFromDisk()
		codeStore.syncWithWorkspace()
		workspaceFs.changed:fire({ reason = "reload" })
		log.info("fs", "Reloaded workspace tree from local disk: " .. workspaceFs.diskRootLabel())
		return true
	end

	function M.switchWorkspace(name)
		codeStore.saveAll()
		local ok, err = workspaceFs.openWorkspace(name)
		if not ok then return false, err end
		gitState.loadMeta()
		for i = #codeStore.tabs, 1, -1 do
			local t = codeStore.tabs[i]
			codeStore.byId[t.id] = nil
			codeStore.tabs[i] = nil
		end
		codeStore.activeId = nil
		local files = workspaceFs.listAllFiles("")
		if files[1] then
			codeStore.openFile(files[1].path)
		end
		return true
	end

	function M.mountRawFolder(folderPath)
		codeStore.saveAll()
		local ok, err = workspaceFs.mountExecutorFolder(folderPath)
		if not ok then return false, err end
		for i = #codeStore.tabs, 1, -1 do
			local t = codeStore.tabs[i]
			codeStore.byId[t.id] = nil
			codeStore.tabs[i] = nil
		end
		codeStore.activeId = nil
		local files = workspaceFs.listAllFiles("")
		if files[1] then
			codeStore.openFile(files[1].path)
		end
		return true
	end

	return M
end
