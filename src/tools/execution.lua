-- Editor buffer execution helper for Run & Debug (`F5`).
return function(env)
	local codeStore = env.require("runtime/code_store")
	local runner = env.require("runtime/runner")
	local languages = env.require("runtime/languages")
	local log = env.require("runtime/log")

	local M = {}

	function M.runActive()
		local doc = codeStore.active()
		if not doc then
			log.warn("runner", "No active editor tab to run.")
			return false, "No active editor tab"
		end
		if doc.langId ~= "luau" then
			local lang = languages.get(doc.langId)
			local msg = string.format(
				"Direct in-game execution runs Luau scripts. '%s' is %s (use GitHub Sync / Disk Save for external runtimes).",
				doc.title,
				lang.name
			)
			log.warn("runner", msg)
			return false, msg
		end
		if doc.dirty and not doc.untitled then
			codeStore.save(doc.id, { silent = true })
		end
		return runner.execute(doc.content, doc.path ~= "" and doc.path or doc.title)
	end

	function M.stop()
		return runner.stopAll()
	end

	return M
end
