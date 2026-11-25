-- Persistent VS Code settings (`VSRBLX/settings.json`) backed by executor `writefile`
-- and `readfile`, with dot-path accessors and debounced disk persistence.
return function(env)
	local util = env.require("runtime/util")
	local fsx = env.require("runtime/fsx")
	local clock = env.require("runtime/clock")
	local signal = env.require("runtime/signal")
	local log = env.require("runtime/log")

	local DEFAULTS = {
		workbench = {
			colorTheme = "dark_plus",
			sideBarVisible = true,
			sideBarWidth = 240,
			panelVisible = true,
			panelHeight = 175,
			activeViewlet = "explorer",
			activePanelTab = "terminal",
			statusBarVisible = true,
			breadcrumbs = true,
			zenMode = false,
		},
		editor = {
			fontSize = 14,
			tabSize = 4,
			insertSpaces = true,
			wordWrap = false,
			minimap = true,
			lineNumbers = true,
			autoClosingBrackets = true,
			autoIndent = true,
			intellisense = true,
			renderActiveLine = true,
			codeFolding = true,
			indentGuides = true,
			bracketPairColorization = true,
			stickyScroll = true,
			inlineErrorLens = true,
		},
		keybindings = {
			preset = "vscode",
			toggleKey = "RightShift",
		},
		files = {
			autoSave = "afterDelay",
			autoSaveDelayMs = 800,
			activeWorkspace = "default",
			recentWorkspaces = { "default" },
		},
		github = {
			token = "",
			username = "",
			activeRepo = "",
			activeBranch = "main",
			autoSyncOnPush = true,
		},
		git = {
			sideBySideDiff = true,
			gutterDecorations = true,
		},
		roblox = {
			captureLogService = true,
		},
		window = {
			autoResize = true,
			widthScale = 0.84,
			heightScale = 0.84,
			placed = false,
			customSize = false,
			maximised = false,
			opacity = 1.0,
			width = 980,
			height = 620,
			x = 0,
			y = 0,
		},
	}

	local M = {
		data = util.deepCopy(DEFAULTS),
		changed = signal.new("config.changed"),
		path = "settings.json",
	}

	local function getAt(root, dotted)
		local cur = root
		for _, part in ipairs(util.split(dotted, ".")) do
			if type(cur) ~= "table" then return nil end
			cur = cur[part]
		end
		return cur
	end

	local function setAt(root, dotted, value)
		local parts = util.split(dotted, ".")
		local cur = root
		for i = 1, #parts - 1 do
			local k = parts[i]
			if type(cur[k]) ~= "table" then cur[k] = {} end
			cur = cur[k]
		end
		cur[parts[#parts]] = value
	end

	local function mergeDefaults(target, defaults)
		for k, v in pairs(defaults) do
			if type(v) == "table" then
				if type(target[k]) ~= "table" then
					target[k] = util.deepCopy(v)
				else
					mergeDefaults(target[k], v)
				end
			elseif target[k] == nil then
				target[k] = v
			end
		end
	end

	function M.saveNow()
		local body, err = util.jsonEncode(M.data)
		if not body then
			log.warn("config", "Failed to encode settings.json: " .. tostring(err))
			return false, err
		end
		return fsx.write(M.path, body)
	end

	local debouncedSave = clock.debounce(0.35, function()
		M.saveNow()
	end)

	function M.load(overrideData)
		if type(overrideData) == "table" then
			M.data = util.deepCopy(overrideData)
			mergeDefaults(M.data, DEFAULTS)
			return true
		end
		local raw = fsx.read(M.path)
		if type(raw) == "string" and raw ~= "" then
			local decoded = util.jsonDecode(raw)
			if type(decoded) == "table" then
				M.data = decoded
				mergeDefaults(M.data, DEFAULTS)
				return true
			end
		end
		M.data = util.deepCopy(DEFAULTS)
		M.saveNow()
		return true
	end

	function M.get(key, fallback)
		local val = getAt(M.data, key)
		if val == nil then
			local def = getAt(DEFAULTS, key)
			if def ~= nil then return def end
			return fallback
		end
		return val
	end

	function M.set(key, value, opts)
		opts = opts or {}
		local prev = getAt(M.data, key)
		setAt(M.data, key, value)
		if opts.immediate then
			M.saveNow()
		else
			debouncedSave.call()
		end
		if not opts.quiet and prev ~= value then
			M.changed:fire(key, value, prev)
		end
	end

	function M.reset()
		M.data = util.deepCopy(DEFAULTS)
		M.saveNow()
		M.changed:fire("*", M.data, nil)
	end

	function M.exportJson()
		return util.jsonEncode(M.data) or "{}"
	end

	function M.importJson(rawJson)
		if type(rawJson) ~= "string" or rawJson == "" then
			return false, "Empty JSON string"
		end
		local decoded, err = util.jsonDecode(rawJson)
		if type(decoded) ~= "table" then
			return false, tostring(err or "Invalid JSON object")
		end
		M.data = decoded
		mergeDefaults(M.data, DEFAULTS)
		M.saveNow()
		M.changed:fire("*", M.data, nil)
		return true
	end

	return M
end
