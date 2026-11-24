-- VS-RBLX: Visual Studio Code for Roblox (100% Luau · LocalScript & Executor IDE)
-- Supports executor disk persistence (`writefile`/`readfile`), GitHub HTTP sync,
-- 17-language RichText syntax highlighting, and a draggable/auto-resized/resizable workbench.

local VERSION = "1.0.0"

local function safeGlobal(name)
	local ok, val = pcall(function()
		local g = (type(getgenv) == "function" and getgenv()) or _G
		if g and g[name] ~= nil then return g[name] end
		return _G[name]
	end)
	if ok and val ~= nil then return val end
	return rawget(_G, name)
end

local function safeService(name)
	if game and type(game.GetService) == "function" then
		local ok, svc = pcall(function() return game:GetService(name) end)
		if ok and svc then return svc end
	end
	return nil
end

local function createEnv(customOpts)
	customOpts = customOpts or {}
	local buildMeta = rawget(_G, "__VSRBLX_BUILD") or {
		version = VERSION,
		id = VERSION .. "-dev",
		channel = "dev",
	}
	local moduleTable = rawget(_G, "__VSRBLX_MODULES") or {}
	local loaded = {}
	local loading = {}

	local services = {
		Workspace = workspace or safeService("Workspace"),
		Players = safeService("Players"),
		UserInputService = safeService("UserInputService"),
		TweenService = safeService("TweenService"),
		HttpService = safeService("HttpService"),
		RunService = safeService("RunService"),
		TextService = safeService("TextService"),
		GuiService = safeService("GuiService"),
		CoreGui = safeService("CoreGui"),
		ReplicatedStorage = safeService("ReplicatedStorage"),
		StarterPlayer = safeService("StarterPlayer"),
		StarterGui = safeService("StarterGui"),
	}

	local localPlr = services.Players and services.Players.LocalPlayer or nil

	local env = {
		version = buildMeta.version or VERSION,
		buildId = buildMeta.id or (VERSION .. "-dev"),
		channel = buildMeta.channel or "dev",
		info = {
			version = buildMeta.version or VERSION,
			build = buildMeta.id or (VERSION .. "-dev"),
			folder = customOpts.folder or "VSRBLX",
		},
		opts = customOpts,
		services = services,

		-- Service shortcuts
		game = game,
		workspace = services.Workspace,
		players = services.Players,
		plr = localPlr,
		uis = services.UserInputService,
		tween = services.TweenService,
		hs = services.HttpService,
		httpService = services.HttpService,
		runService = services.RunService,
		textService = services.TextService,
		guisvc = services.GuiService,
		guiService = services.GuiService,
		coreGui = services.CoreGui,

		-- Executor host capabilities
		getgenv = safeGlobal("getgenv"),
		gethui = safeGlobal("gethui"),
		identifyexecutor = safeGlobal("identifyexecutor") or safeGlobal("getexecutorname"),
		loadstring = safeGlobal("loadstring") or loadstring,

		-- Executor local disk filesystem (`writefile` / `readfile`)
		writefile = safeGlobal("writefile"),
		readfile = safeGlobal("readfile"),
		appendfile = safeGlobal("appendfile"),
		isfile = safeGlobal("isfile"),
		isfolder = safeGlobal("isfolder"),
		makefolder = safeGlobal("makefolder"),
		listfiles = safeGlobal("listfiles"),
		delfile = safeGlobal("delfile"),
		delfolder = safeGlobal("delfolder"),

		-- Executor HTTP transport (`request` / `http_request` / `syn.request`)
		request = safeGlobal("request"),
		http_request = safeGlobal("http_request"),
		http = safeGlobal("http"),
		syn = safeGlobal("syn"),
		fluxus = safeGlobal("fluxus"),

		-- Clipboard & script inspection
		setclipboard = safeGlobal("setclipboard") or safeGlobal("toclipboard"),
		getclipboard = safeGlobal("getclipboard"),
		decompile = safeGlobal("decompile"),
		getscriptbytecode = safeGlobal("getscriptbytecode"),
	}

	local function resolveFactory(modId)
		if moduleTable[modId] then
			return moduleTable[modId]
		end
		local relPath = "src/" .. modId .. ".lua"
		if type(loadfile) == "function" then
			local chunk, err = loadfile(relPath)
			if not chunk then error("Failed to load " .. relPath .. ": " .. tostring(err)) end
			return chunk()
		end
		if type(env.readfile) == "function" and type(env.loadstring) == "function" then
			local ok, src = pcall(env.readfile, relPath)
			if ok and type(src) == "string" then
				local chunk, err = env.loadstring(src, "@" .. relPath)
				if not chunk then error("Compile error in " .. relPath .. ": " .. tostring(err)) end
				return chunk()
			end
		end
		error("Module not found: " .. tostring(modId))
	end

	function env.require(modId)
		if loaded[modId] ~= nil then
			return loaded[modId]
		end
		if loading[modId] then
			error("Circular module dependency detected: " .. tostring(modId))
		end
		loading[modId] = true
		local factory = resolveFactory(modId)
		if type(factory) ~= "function" then
			loading[modId] = nil
			error("Module " .. tostring(modId) .. " must return function(env)")
		end
		local result = factory(env)
		loading[modId] = nil
		loaded[modId] = result == nil and true or result
		return loaded[modId]
	end

	return env
end

local function boot(userOpts)
	local globalHost = (type(getgenv) == "function" and getgenv()) or _G
	local bootCfg = userOpts or (globalHost and globalHost.VSRBLX_CONFIG) or {}

	if globalHost and type(globalHost.VSRBLX) == "table" and type(globalHost.VSRBLX.destroy) == "function" then
		pcall(globalHost.VSRBLX.destroy)
	end

	local env = createEnv(bootCfg)
	local dispose = env.require("runtime/dispose")
	local sdkMod = env.require("embedding/sdk")

	local appInstance = nil
	if not bootCfg.headless then
		local appMod = env.require("ui/app")
		appInstance = appMod.mount(bootCfg)
	else
		local config = env.require("runtime/config")
		local workspaceFs = env.require("runtime/workspace_fs")
		local gitState = env.require("runtime/git_state")
		config.load()
		workspaceFs.init()
		gitState.loadMeta()
	end

	local api = sdkMod.buildHandle(appInstance, function()
		if dispose.all then
			dispose.all()
		elseif dispose.cleanupAll then
			dispose.cleanupAll()
		end
	end)
	if globalHost then
		globalHost.VSRBLX = api
	end
	return api
end

local autoBoot = true
local host = (type(getgenv) == "function" and getgenv()) or _G
if host and host.VSRBLX_NO_AUTOBOOT == true then
	autoBoot = false
end

if autoBoot then
	return boot()
end

return {
	version = VERSION,
	createEnv = createEnv,
	boot = boot,
}
