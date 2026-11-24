-- Imports live Roblox game scripts (`LocalScript` / `ModuleScript`) into VS-RBLX
-- tabs or saves them directly onto local executor disk (`writefile`).
return function(env)
	local robloxExplorer = env.require("runtime/roblox_explorer")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")
	local log = env.require("runtime/log")

	local M = {}

	function M.openInstanceScript(inst, saveToWorkspace)
		local src, origin = robloxExplorer.readScriptSource(inst)
		if not src then return nil, origin end
		local safeName = tostring(inst.Name or "Script"):gsub("[^%w%-_]", "_") .. ".luau"
		if saveToWorkspace then
			local relPath = "game_imports/" .. safeName
			workspaceFs.writeFile(relPath, src)
			log.info("fs", "Imported game script to disk: " .. relPath .. " (" .. origin .. ")")
			return codeStore.openFile(relPath, { reloadFromDisk = true })
		end
		return codeStore.openVirtualTab(
			"rbx_" .. safeName .. "_" .. tostring(origin),
			safeName .. " [Game]",
			src,
			"luau",
			false
		)
	end

	return M
end
