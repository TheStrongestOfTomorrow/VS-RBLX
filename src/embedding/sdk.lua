-- Public programmatic SDK returned by `loadstring(...)()` and stored in `getgenv().VSRBLX`.
return function(env)
	local fsx = env.require("runtime/fsx")
	local config = env.require("runtime/config")
	local workspaceFs = env.require("runtime/workspace_fs")
	local languages = env.require("runtime/languages")
	local robloxApiDb = env.require("runtime/roblox_api_db")
	local intellisense = env.require("runtime/intellisense")
	local previewEngine = env.require("runtime/preview_engine")
	local extensionHub = env.require("runtime/extension_hub")
	local cryptoVault = env.require("runtime/crypto_vault")
	local codeStore = env.require("runtime/code_store")
	local codeDiff = env.require("runtime/code_diff")
	local todoScanner = env.require("runtime/todo_scanner")
	local clipboard = env.require("runtime/clipboard")
	local sessionJournal = env.require("runtime/session_journal")
	local colorUtils = env.require("runtime/color_utils")
	local editorActions = env.require("runtime/editor_actions")
	local robloxExplorer = env.require("runtime/roblox_explorer")
	local robloxConsole = env.require("runtime/roblox_console")
	local gitState = env.require("runtime/git_state")
	local commands = env.require("runtime/command_catalog")
	local theme = env.require("ui/theme")
	local responsive = env.require("ui/responsive")
	local githubSync = env.require("tools/github_sync")
	local execution = env.require("tools/execution")
	local terminalCmds = env.require("tools/terminal_cmds")
	local instancePicker = env.require("tools/instance_picker")
	local projectBundler = env.require("tools/project_bundler")
	local snapshots = env.require("tools/snapshots")
	local aiProviders = env.require("ai/providers")
	local aiTools = env.require("ai/tools")
	local aiAgent = env.require("ai/agent_loop")

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
			languages = languages,
			robloxApiDb = robloxApiDb,
			intellisense = intellisense,
			previewEngine = previewEngine,
			extensionHub = extensionHub,
			cryptoVault = cryptoVault,
			vault = cryptoVault,
			responsive = responsive,
			codeStore = codeStore,
			editor = codeStore,
			codeDiff = codeDiff,
			todos = todoScanner,
			clipboard = clipboard,
			session = sessionJournal,
			colorUtils = colorUtils,
			editorActions = editorActions,
			robloxExplorer = robloxExplorer,
			robloxConsole = robloxConsole,
			terminal = terminalCmds,
			instancePicker = instancePicker,
			bundler = projectBundler,
			snapshots = snapshots,
			aiProviders = aiProviders,
			aiTools = aiTools,
			aiAgent = aiAgent,
			ai = aiAgent,
			git = gitState,
			github = githubSync,
			theme = theme,
			openFile = function(path, opts) return codeStore.openFile(path, opts) end,
			writeFile = function(path, content) return workspaceFs.writeFile(path, content) end,
			readFile = function(path) return workspaceFs.readFile(path) end,
			openPreview = function() return commands.run("preview.openToSide") end,
			closePreview = function() return commands.run("preview.close") end,
			scanExtension = function(payload) return extensionHub.scanSubmission(payload) end,
			installExtension = function(payload) return extensionHub.install(payload) end,
			uninstallExtension = function(extId) return extensionHub.uninstall(extId) end,
			syncExtensions = function(repo) return extensionHub.syncFromGitHub(repo) end,
			bundleWorkspace = function(outPath) return projectBundler.bundleWorkspace(outPath) end,
			cloneRepo = function(repo, opts) return githubSync.cloneRepo(repo, opts) end,
			pullRepo = function() return githubSync.pull() end,
			commitAndPush = function(msg) return githubSync.commitAndPush(msg) end,
			pushRepo = function(msg) return githubSync.commitAndPush(msg) end,
			importGist = function(spec) return githubSync.importGist(spec) end,
			publishGist = function(opts) return githubSync.publishActiveGist(opts) end,
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
			setMobileMode = function(flag)
				if app and app.setMobileMode then return app.setMobileMode(flag) end
				return false
			end,
			isMobileMode = function()
				if app and app.isMobileMode then return app.isMobileMode() end
				return false
			end,
			setResizeMode = function(flag)
				if app and app.window and app.window.setResizeMode then return app.window.setResizeMode(flag) end
				return false
			end,
			toggleResizeMode = function()
				if app and app.window and app.window.toggleResizeMode then return app.window.toggleResizeMode() end
				return false
			end,
			isResizeMode = function()
				if app and app.window then return app.window.resizeMode == true end
				return false
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
