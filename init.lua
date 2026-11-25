--!globals __VSRBLX_MODULES __VSRBLX_BUILD
-- VS-RBLX Bootstrap (`init.lua`).
--
-- Every file under `src/` is a factory of the form `return function(env) ... end`.
-- `tools/bundle.lua` emits `local __VSRBLX_BUILD` and `local __VSRBLX_MODULES` above
-- this bootstrap in `dist/vsrblx.lua`, so `__VSRBLX_MODULES` is bound directly as a
-- lexical local inside the single-file bundle:
--
--     loadstring(game:HttpGet("https://raw.githubusercontent.com/TheStrongestOfTomorrow/VS-RBLX/main/dist/vsrblx.lua"))()

local MODULES = __VSRBLX_MODULES
local isDevFallback = false

if type(MODULES) ~= "table" then
	if type(loadfile) == "function" then
		isDevFallback = true
		MODULES = setmetatable({}, {
			__index = function(cache, id)
				local relPath = "src/" .. tostring(id) .. ".lua"
				local chunk = loadfile(relPath)
				if not chunk then return nil end
				local factory = chunk()
				cache[id] = factory
				return factory
			end,
		})
	else
		warn("[vsrblx] no module table -- run the bundled dist/vsrblx.lua, not init.lua")
		return nil
	end
end

local hostContext = ...

local VERSION = "1.0.0"
local FOLDER = "VSRBLX"
local BUILD = type(__VSRBLX_BUILD) == "string" and __VSRBLX_BUILD or (VERSION .. "-dev")

-- If executed from autoexec before the DataModel finishes loading, wait cleanly.
if game and type(game.IsLoaded) == "function" then
	local ok, loadedFlag = pcall(function() return game:IsLoaded() end)
	if ok and not loadedFlag and game.Loaded then
		pcall(function() game.Loaded:Wait() end)
	end
end

local globalTable = nil
if type(getgenv) == "function" then
	local ok, g = pcall(getgenv)
	if ok and type(g) == "table" then
		globalTable = g
	end
end
if not globalTable and type(_G) == "table" then
	globalTable = _G
end

local function lookupGlobal(key, directVal)
	if directVal ~= nil then return directVal end
	if globalTable ~= nil then
		local ok, v = pcall(function() return globalTable[key] end)
		if ok and v ~= nil then return v end
	end
	return nil
end

local options = (type(hostContext) == "table" and hostContext)
	or (globalTable and type(globalTable.VSRBLX_CONFIG) == "table" and globalTable.VSRBLX_CONFIG)
	or {}

-- Re-running the same build toggles/reopens the existing window unless `reload = true`;
-- running a newer build tears down the old instance cleanly and mounts the update.
if globalTable then
	local okExisting, existing = pcall(function() return globalTable.VSRBLX end)
	if okExisting and type(existing) == "table" and existing.alive then
		if existing.build == BUILD and options.reload ~= true and not isDevFallback then
			if options.reuse ~= true and type(existing.toggle) == "function" then
				pcall(existing.toggle)
			end
			return existing
		end
		if type(existing.destroy) == "function" then
			pcall(existing.destroy)
		end
	end
end

-- Lazy memoised service lookup via game:GetService (safe even if instances were renamed).
local services = setmetatable({}, {
	__index = function(cache, name)
		if not game or type(game.GetService) ~= "function" then return nil end
		local ok, svc = pcall(function() return game:GetService(name) end)
		if not ok or not svc then return nil end
		cache[name] = svc
		return svc
	end,
})

local playersService = services.Players
local localPlr = playersService and playersService.LocalPlayer or nil
if not localPlr and playersService then
	pcall(function()
		local sig = playersService:GetPropertyChangedSignal("LocalPlayer")
		if sig and not playersService.LocalPlayer then
			-- Brief non-blocking check in case LocalPlayer attaches on the next frame
			task.wait()
		end
		localPlr = playersService.LocalPlayer
	end)
end

local env = {
	version = VERSION,
	buildId = BUILD,
	channel = type(__VSRBLX_BUILD) == "string" and "release" or "dev",
	info = {
		name = "VSRBLX",
		version = VERSION,
		build = BUILD,
		folder = options.folder or FOLDER,
	},
	opts = options,
	context = options,
	services = services,

	-- Service shortcuts
	game = game,
	workspace = services.Workspace or workspace,
	players = playersService,
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
	getgenv = lookupGlobal("getgenv", getgenv),
	gethui = lookupGlobal("gethui", gethui),
	identifyexecutor = lookupGlobal("identifyexecutor", identifyexecutor)
		or lookupGlobal("getexecutorname", getexecutorname),
	loadstring = lookupGlobal("loadstring", loadstring),

	-- Executor local disk filesystem (`writefile` / `readfile`)
	writefile = lookupGlobal("writefile", writefile),
	readfile = lookupGlobal("readfile", readfile),
	appendfile = lookupGlobal("appendfile", appendfile),
	isfile = lookupGlobal("isfile", isfile),
	isfolder = lookupGlobal("isfolder", isfolder),
	makefolder = lookupGlobal("makefolder", makefolder),
	listfiles = lookupGlobal("listfiles", listfiles),
	delfile = lookupGlobal("delfile", delfile),
	delfolder = lookupGlobal("delfolder", delfolder),

	-- Executor HTTP transport (`request` / `http_request` / `syn.request`)
	request = lookupGlobal("request", request),
	http_request = lookupGlobal("http_request", http_request),
	http = lookupGlobal("http", http),
	syn = lookupGlobal("syn", syn),
	fluxus = lookupGlobal("fluxus", fluxus),

	-- Clipboard & script inspection
	setclipboard = lookupGlobal("setclipboard", setclipboard)
		or lookupGlobal("toclipboard", toclipboard),
	getclipboard = lookupGlobal("getclipboard", getclipboard),
	decompile = lookupGlobal("decompile", decompile),
	getscriptbytecode = lookupGlobal("getscriptbytecode", getscriptbytecode),
}

local loaded, loading, requireStack = {}, {}, {}

env.moduleTotal = 0
if not isDevFallback then
	for _ in pairs(MODULES) do
		env.moduleTotal = env.moduleTotal + 1
	end
end
env.moduleCount = 0
env.loadedModules = loaded

function env.require(id)
	local cached = loaded[id]
	if cached ~= nil then return cached end
	if loading[id] then
		local cycle = {}
		for i = 1, #requireStack do cycle[#cycle + 1] = requireStack[i] end
		cycle[#cycle + 1] = tostring(id)
		error("[vsrblx] circular require: " .. table.concat(cycle, " -> "), 2)
	end
	local factory = MODULES[id]
	if type(factory) ~= "function" then
		error("[vsrblx] no module '" .. tostring(id) .. "'", 2)
	end
	loading[id] = true
	requireStack[#requireStack + 1] = tostring(id)
	local ok, result = pcall(factory, env)
	requireStack[#requireStack] = nil
	loading[id] = nil
	if not ok then
		error("[vsrblx] module '" .. tostring(id) .. "' failed to load: " .. tostring(result), 2)
	end
	if result == nil then
		error("[vsrblx] module '" .. tostring(id) .. "' returned nothing", 2)
	end
	loaded[id] = result
	env.moduleCount = env.moduleCount + 1
	if env.onModuleLoaded then
		pcall(env.onModuleLoaded, id, env.moduleCount, env.moduleTotal)
	end
	return result
end

local bootCard = nil

local function start()
	local mountUi = options.headless ~= true and options.ui ~= false

	if mountUi then
		pcall(function()
			bootCard = env.require("ui/boot").show()
		end)
	end

	local lastYield = os.clock()
	env.onModuleLoaded = function(id, count, total)
		if bootCard and bootCard.moduleStep then
			pcall(bootCard.moduleStep, id, count, total)
		end
		if os.clock() - lastYield >= 0.03 then
			task.wait()
			lastYield = os.clock()
		end
	end

	if bootCard then
		task.wait()
	end

	local caps = env.require("runtime/caps")
	env.caps = caps
	local log = env.require("runtime/log")
	local dispose = env.require("runtime/dispose")

	log.info("boot", string.format("VS-RBLX %s (%s) starting -- %s", VERSION, BUILD, caps.summary()))

	local appInstance = nil
	if mountUi then
		options.splash = bootCard
		local appMod = env.require("ui/app")
		appInstance = appMod.mount(options)
		options.splash = nil
	else
		local config = env.require("runtime/config")
		local workspaceFs = env.require("runtime/workspace_fs")
		local gitState = env.require("runtime/git_state")
		config.load()
		workspaceFs.init()
		gitState.loadMeta()
	end

	local sdkMod = env.require("embedding/sdk")
	local handle
	handle = sdkMod.buildHandle(appInstance, function()
		dispose.drain()
		if appInstance and appInstance.screenGui then
			pcall(function() appInstance.screenGui:Destroy() end)
		end
		if globalTable then
			pcall(function()
				if globalTable.VSRBLX == handle then
					globalTable.VSRBLX = nil
				end
			end)
		end
	end)

	env.onModuleLoaded = nil
	if bootCard then
		pcall(bootCard.close)
		bootCard = nil
	end

	if globalTable then
		pcall(function() globalTable.VSRBLX = handle end)
	end
	log.info("boot", "VS-RBLX ready")
	return handle
end

local ok, result = pcall(start)
if not ok then
	env.onModuleLoaded = nil
	warn("[vsrblx] failed to start: " .. tostring(result))
	local disposer = loaded["runtime/dispose"]
	if disposer then pcall(disposer.drain) end
	if bootCard and bootCard.fail then
		pcall(bootCard.fail, result)
	end
	return nil
end

return result
