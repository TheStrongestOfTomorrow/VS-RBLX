-- Public programmatic SDK returned by `loadstring(...)()` and stored in `getgenv().VSRBLX`.
return function(env)
	local fsx = env.require("runtime/fsx")
	local config = env.require("runtime/config")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")
	local todoScanner = env.require("runtime/todo_scanner")
	local clipboard = env.require("runtime/clipboard")
	local sessionJournal = env.require("runtime/session_journal")
	local colorUtils = env.require("runtime/color_utils")
	local editorActions = env.require("runtime/editor_actions")
	local gitState = env.require("runtime/git_state")
	local commands = env.require("runtime/command_catalog")
	local theme = env.require("ui/theme")
	local githubSync = env.require("tools/github_sync")
	local execution = env.require("tools/execution")

	local M = {}

	function M.buildHandle(app, destroyFn)
		local handle = {
			version = env.info.version,
			buildId = env.info.build,
			build = env.info.build,
			alive = true,
			env = env,
			_env = env,
			app = app,
			fs = fsx,
			config = config,
			workspace = workspaceFs,
			codeStore = codeStore,
			editor = codeStore,
			todos = todoScanner,
			clipboard = clipboard,
			session = sessionJournal,
			colorUtils = colorUtils,
			editorActions = editorActions,
			git = gitState,
			github = githubSync,
			theme = theme,
			openFile = function(path, opts) return codeStore.openFile(path, opts) end,
			writeFile = function(path, content) return workspaceFs.writeFile(path, content) end,
			readFile = function(path) return workspaceFs.readFile(path) end,
			cloneRepo = function(repo, opts) return githubSync.cloneRepo(repo, opts) end,
			pullRepo = function() return githubSync.pull() end,
			commitAndPush = function(msg) return githubSync.commitAndPush(msg) end,
			pushRepo = function(msg) return githubSync.commitAndPush(msg) end,
			runActive = function() return execution.runActive() end,
			runCommand = function(id, ...) return commands.run(id, ...) end,
			setTheme = function(themeId) return theme.apply(themeId) end,
			setOpacity = function(alpha)
				if app and app.window then return app.window.setOpacity(alpha) end
				return nil
			end,
			getOpacity = function()
				if app and app.window then return app.window.getOpacity() end
				return 1.0
			end,
			toggleZenMode = function() return commands.run("workbench.toggleZenMode") end,
			show = function() if app and app.window then app.window.show() end end,
			hide = function() if app and app.window then app.window.hide() end end,
			toggle = function() if app and app.window then app.window.toggle() end end,
		}
		handle.destroy = function()
			if not handle.alive then return end
			handle.alive = false
			if destroyFn then destroyFn() end
		end
		return handle
	end

	M.create = M.buildHandle
	return M
end
