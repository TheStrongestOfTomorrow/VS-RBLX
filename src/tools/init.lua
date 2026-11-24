-- Unified tool registry for VS-RBLX developer actions.
return function(env)
	local M = {
		formatter = env.require("tools/formatter"),
		githubSync = env.require("tools/github_sync"),
		fsSync = env.require("tools/fs_sync"),
		execution = env.require("tools/execution"),
		decompiler = env.require("tools/decompiler"),
		terminal = env.require("tools/terminal_cmds"),
	}
	return M
end
