-- Unified tool registry for VS-RBLX developer actions.
return function(env)
	local M = {
		formatter = env.require("tools/formatter"),
		githubSync = env.require("tools/github_sync"),
		fsSync = env.require("tools/fs_sync"),
		execution = env.require("tools/execution"),
		decompiler = env.require("tools/decompiler"),
		terminal = env.require("tools/terminal_cmds"),
		instancePicker = env.require("tools/instance_picker"),
		projectBundler = env.require("tools/project_bundler"),
		snapshots = env.require("tools/snapshots"),
	}
	return M
end
