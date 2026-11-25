-- Original VS-RBLX headless Roblox + Executor test harness.
package.path = "test/?.lua;test/mock/?.lua;" .. package.path

local luau = require("luau")
local json = require("json")
local dt = require("datatypes")
local bitLib = require("bit")

local M = {}

local function makeSignal()
	local listeners = {}
	local sig = {}
	function sig:Connect(fn)
		local conn = { Connected = true, fn = fn }
		function conn:Disconnect()
			conn.Connected = false
		end
		listeners[#listeners + 1] = conn
		return setmetatable(conn, { __type = "RBXScriptConnection" })
	end
	function sig:Once(fn)
		local conn
		conn = sig:Connect(function(...)
			conn:Disconnect()
			fn(...)
		end)
		return conn
	end
	function sig:Fire(...)
		local copy = {}
		for i = 1, #listeners do copy[i] = listeners[i] end
		for _, c in ipairs(copy) do
			if c.Connected then
				c.fn(...)
			end
		end
	end
	return sig
end

local function buildBit32()
	local function u32(x) return x < 0 and (x + 4294967296) or x end
	return {
		band = function(a, b) return u32(bitLib.band(a, b)) end,
		bor = function(a, b) return u32(bitLib.bor(a, b)) end,
		bxor = function(a, b) return u32(bitLib.bxor(a, b)) end,
		bnot = function(a) return u32(bitLib.bnot(a)) end,
		lshift = function(a, n) return u32(bitLib.lshift(a, n)) end,
		rshift = function(a, n) return u32(bitLib.rshift(a, n)) end,
	}
end

function M.new(opts)
	opts = opts or {}
	local Enum = dt.makeEnum()
	local nowSec = 0
	local timers = {}
	local viewport = dt.Vector2.new(opts.width or 1440, opts.height or 900)

	local function createInstance(className, parent)
		local props = {
			ClassName = className,
			Name = className,
			Visible = true,
			Active = false,
			Selectable = false,
			Text = "",
			PlaceholderText = "",
			Size = dt.UDim2.fromOffset(100, 100),
			Position = dt.UDim2.fromOffset(0, 0),
			AnchorPoint = dt.Vector2.new(0, 0),
			CanvasPosition = dt.Vector2.new(0, 0),
			CanvasSize = dt.UDim2.fromOffset(0, 0),
			BackgroundColor3 = dt.Color3.fromRGB(30, 30, 30),
			TextColor3 = dt.Color3.fromRGB(212, 212, 212),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			ZIndex = 1,
			LayoutOrder = 0,
			CursorPosition = 1,
			SelectionStart = -1,
			RichText = false,
			MultiLine = false,
			ClearTextOnFocus = false,
		}
		local children = {}
		local propSignals = {}
		local signals = {
			Destroying = makeSignal(),
			Activated = makeSignal(),
			MouseButton1Click = makeSignal(),
			MouseButton2Click = makeSignal(),
			MouseEnter = makeSignal(),
			MouseLeave = makeSignal(),
			InputBegan = makeSignal(),
			InputChanged = makeSignal(),
			InputEnded = makeSignal(),
			Focused = makeSignal(),
			FocusLost = makeSignal(),
		}

		local inst = { __props = props, __children = children, __signals = signals }

		local function computeRect()
			if className == "ScreenGui" then
				return dt.Vector2.new(0, 0), viewport
			end
			local pPos, pSize = dt.Vector2.new(0, 0), viewport
			if props.Parent and props.Parent.__computeRect then
				pPos, pSize = props.Parent.__computeRect()
			end
			local sz = props.Size or dt.UDim2.fromOffset(0, 0)
			local ps = props.Position or dt.UDim2.fromOffset(0, 0)
			local anc = props.AnchorPoint or dt.Vector2.new(0, 0)
			local w = sz.X.Scale * pSize.X + sz.X.Offset
			local h = sz.Y.Scale * pSize.Y + sz.Y.Offset
			local x = pPos.X + ps.X.Scale * pSize.X + ps.X.Offset - w * anc.X
			local y = pPos.Y + ps.Y.Scale * pSize.Y + ps.Y.Offset - h * anc.Y
			return dt.Vector2.new(x, y), dt.Vector2.new(w, h)
		end
		inst.__computeRect = computeRect

		local methods = {}
		function methods:GetChildren()
			local out = {}
			for i = 1, #children do out[i] = children[i] end
			return out
		end
		function methods:GetDescendants()
			local out = {}
			local function walk(list)
				for _, ch in ipairs(list) do
					out[#out + 1] = ch
					walk(ch.__children)
				end
			end
			walk(children)
			return out
		end
		function methods:FindFirstChild(name, recursive)
			for _, ch in ipairs(children) do
				if ch.__props.Name == name then return ch end
			end
			if recursive then
				for _, ch in ipairs(methods.GetDescendants(inst)) do
					if ch.__props.Name == name then return ch end
				end
			end
			return nil
		end
		function methods:IsA(target)
			if className == target then return true end
			if target == "Instance" then return true end
			if target == "GuiObject" then
				return className == "Frame" or className == "ScrollingFrame"
					or className == "TextLabel" or className == "TextButton"
					or className == "TextBox" or className == "ImageLabel" or className == "ImageButton"
			end
			if target == "GuiButton" then
				return className == "TextButton" or className == "ImageButton"
			end
			if target == "LuaSourceContainer" then
				return className == "LocalScript" or className == "ModuleScript" or className == "Script"
			end
			return false
		end
		function methods:IsDescendantOf(ancestor)
			local cur = props.Parent
			while cur do
				if cur == ancestor then return true end
				cur = cur.__props and cur.__props.Parent or nil
			end
			return false
		end
		function methods:GetPropertyChangedSignal(propName)
			if not propSignals[propName] then
				propSignals[propName] = makeSignal()
			end
			return propSignals[propName]
		end
		function methods:CaptureFocus()
			signals.Focused:Fire()
		end
		function methods:ReleaseFocus(enterPressed)
			signals.FocusLost:Fire(enterPressed == true)
		end
		function methods:ClearAllChildren()
			for i = #children, 1, -1 do
				children[i]:Destroy()
			end
		end
		function methods:Destroy()
			signals.Destroying:Fire()
			if props.Parent and props.Parent.__children then
				local list = props.Parent.__children
				for i = #list, 1, -1 do
					if list[i] == inst then table.remove(list, i) end
				end
			end
			props.Parent = nil
			for i = #children, 1, -1 do
				local ch = children[i]
				children[i] = nil
				ch:Destroy()
			end
		end

		setmetatable(inst, {
			__type = "Instance",
			__index = function(_, key)
				if key == "AbsolutePosition" then
					local pos = computeRect()
					return pos
				elseif key == "AbsoluteSize" then
					local _, size = computeRect()
					return size
				elseif key == "TextBounds" then
					local txt = tostring(props.Text or "")
					local lines = 1
					for _ in txt:gmatch("\n") do lines = lines + 1 end
					return dt.Vector2.new(#txt * 7, lines * 18)
				end
				if methods[key] then return methods[key] end
				if signals[key] then return signals[key] end
				return props[key]
			end,
			__newindex = function(_, key, val)
				if key == "Parent" then
					if val and rawget(val, "__lockedParent") then
						error("The current thread cannot access 'CoreGui' (lacking capability Plugin)", 2)
					end
					if props.Parent and props.Parent.__children then
						local oldList = props.Parent.__children
						for i = #oldList, 1, -1 do
							if oldList[i] == inst then table.remove(oldList, i) end
						end
					end
					props.Parent = val
					if val and val.__children then
						val.__children[#val.__children + 1] = inst
					end
				else
					props[key] = val
				end
				if propSignals[key] then
					propSignals[key]:Fire()
				end
			end,
		})

		if parent then inst.Parent = parent end
		return inst
	end

	local Instance = { new = createInstance }
	local coreGui = createInstance("CoreGui")
	if opts.executor == false or opts.lockCoreGui == true then
		rawset(coreGui, "__lockedParent", true)
	end
	local playerGui = createInstance("PlayerGui")
	local localPlayer = createInstance("Player")
	localPlayer.Name = "DevPlayer"
	localPlayer.DisplayName = "DevPlayer"
	localPlayer.UserId = 1001
	playerGui.Parent = localPlayer

	local camera = createInstance("Camera")
	camera.ViewportSize = viewport

	local workspaceInst = createInstance("Workspace")
	workspaceInst.CurrentCamera = camera
	local sampleScript = createInstance("LocalScript", workspaceInst)
	sampleScript.Name = "GameController"
	sampleScript.Source = "-- In-game LocalScript\nprint('Hello from Workspace!')\n"

	local spawnFolder = createInstance("Folder", workspaceInst)
	spawnFolder.Name = "ArenaMap"
	local killBrick = createInstance("Part", spawnFolder)
	killBrick.Name = "Lava Platform"
	killBrick.Position = dt.Vector3.new(12, 4, -8)

	local mockMouse = { Target = killBrick }
	rawset(localPlayer, "GetMouse", function() return mockMouse end)

	local logService = {
		MessageOut = makeSignal(),
	}

	local replicatedStorage = createInstance("ReplicatedStorage")
	local sharedMod = createInstance("ModuleScript", replicatedStorage)
	sharedMod.Name = "SharedConfig"
	sharedMod.Source = "return { version = '2.0.0' }\n"

	local heldKeys = {}
	local uis = {
		TouchEnabled = false,
		MouseEnabled = true,
		KeyboardEnabled = true,
		InputBegan = makeSignal(),
		InputChanged = makeSignal(),
		InputEnded = makeSignal(),
		GetFocusedTextBox = function() return nil end,
		IsKeyDown = function(_, kc)
			local name = type(kc) == "table" and kc.Name or tostring(kc)
			return heldKeys[name] == true
		end,
	}

	local httpHandlers = {}
	local httpLog = {}
	local function dispatchHttp(reqOpts)
		local url = tostring(reqOpts.Url or reqOpts.url or "")
		local method = tostring(reqOpts.Method or reqOpts.method or "GET"):upper()
		httpLog[#httpLog + 1] = { Url = url, Method = method, Headers = reqOpts.Headers or {}, Body = reqOpts.Body }
		for _, handler in ipairs(httpHandlers) do
			local res = handler(reqOpts, url, method)
			if res then
				return {
					StatusCode = res.StatusCode or 200,
					Body = type(res.Body) == "table" and json.encode(res.Body) or tostring(res.Body or ""),
					Headers = res.Headers or {},
					Success = (res.StatusCode or 200) < 400,
				}
			end
		end
		return { StatusCode = 404, Body = '{"message":"Not Found"}', Headers = {}, Success = false }
	end

	local services = {
		CoreGui = coreGui,
		Workspace = workspaceInst,
		ReplicatedStorage = replicatedStorage,
		LogService = logService,
		UserInputService = uis,
		Players = {
			LocalPlayer = localPlayer,
			GetPlayers = function() return { localPlayer } end,
		},
		HttpService = {
			JSONEncode = function(_, v) return json.encode(v) end,
			JSONDecode = function(_, s) return json.decode(s) end,
			RequestAsync = function(_, reqOpts) return dispatchHttp(reqOpts) end,
		},
		TweenService = {
			Create = function(_, target, _info, goals)
				local completed = makeSignal()
				return {
					Completed = completed,
					Play = function()
						for k, v in pairs(goals or {}) do target[k] = v end
						completed:Fire(Enum.PlaybackState.Completed)
					end,
					Cancel = function() end,
				}
			end,
		},
		GuiService = {
			SelectedObject = nil,
			GetGuiInset = function() return dt.Vector2.new(0, 36), dt.Vector2.new(0, 0) end,
		},
		RunService = {
			Heartbeat = makeSignal(),
			RenderStepped = makeSignal(),
			IsStudio = function() return opts.executor == false end,
		},
	}

	local gameObj = createInstance("DataModel")
	workspaceInst.Parent = gameObj
	replicatedStorage.Parent = gameObj
	function gameObj:GetService(name)
		return services[name]
	end
	function gameObj:HttpGet(url)
		local r = dispatchHttp({ Url = url, Method = "GET" })
		return r.Body
	end

	local diskFiles = {}
	local diskFolders = { [""] = true }
	local function norm(p)
		return tostring(p or ""):gsub("\\", "/"):gsub("^/+", ""):gsub("/+$", "")
	end

	local taskApi = {
		wait = function(sec)
			nowSec = nowSec + (tonumber(sec) or 0.016)
			return tonumber(sec) or 0.016
		end,
		spawn = function(fn, ...)
			fn(...)
			return coroutine.create(function() end)
		end,
		defer = function(fn, ...)
			fn(...)
			return coroutine.create(function() end)
		end,
		delay = function(sec, fn, ...)
			local args = { n = select("#", ...), ... }
			local item = { due = nowSec + (tonumber(sec) or 0), fn = fn, args = args, cancelled = false }
			timers[#timers + 1] = item
			return item
		end,
		cancel = function(item)
			if type(item) == "table" then item.cancelled = true end
		end,
	}

	local consoleOut = {}
	local sandbox = {
		game = gameObj,
		workspace = workspaceInst,
		Instance = Instance,
		Enum = Enum,
		Vector2 = dt.Vector2,
		Vector3 = dt.Vector3,
		UDim = dt.UDim,
		UDim2 = dt.UDim2,
		Color3 = dt.Color3,
		TweenInfo = dt.TweenInfo,
		Rect = dt.Rect,
		Font = dt.Font,
		bit32 = buildBit32(),
		task = taskApi,
		tick = function() return 1700000000 + nowSec end,
		time = function() return nowSec end,
		typeof = function(v)
			local mt = type(v) == "table" and getmetatable(v) or nil
			if mt and mt.__type then return mt.__type end
			return type(v)
		end,
		print = function(...)
			local t = {}
			for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
			consoleOut[#consoleOut + 1] = table.concat(t, "\t")
		end,
		warn = function(...)
			local t = {}
			for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
			consoleOut[#consoleOut + 1] = "[WARN] " .. table.concat(t, "\t")
		end,
	}
	if opts.allowHostLoadfile == true then
		sandbox.loadfile = function(path)
			local fh, openErr = io.open(path, "rb")
			if not fh then return nil, openErr end
			local src = fh:read("*a")
			fh:close()
			local fn, lErr = loadstring(src, "@" .. path)
			if not fn then return nil, lErr end
			setfenv(fn, sandbox)
			return fn
		end
	end

	if opts.executor ~= false then
		sandbox.identifyexecutor = function() return "SynapseZ", "4.2" end
		sandbox.getgenv = function() return sandbox end
		sandbox.gethui = function() return coreGui end
		sandbox.request = dispatchHttp
		sandbox.http_request = dispatchHttp
		sandbox.setclipboard = function(s) sandbox.__clipboard = tostring(s) end
		sandbox.decompile = function(inst) return inst.Source or "-- decompiled\n" end

		sandbox.writefile = function(path, body)
			local k = norm(path)
			local dir = k:match("^(.*)/[^/]+$")
			if dir then
				local walk = ""
				for part in dir:gmatch("[^/]+") do
					walk = walk == "" and part or (walk .. "/" .. part)
					diskFolders[walk] = true
				end
			end
			diskFiles[k] = tostring(body)
		end
		sandbox.appendfile = function(path, body)
			local k = norm(path)
			diskFiles[k] = (diskFiles[k] or "") .. tostring(body)
		end
		sandbox.readfile = function(path)
			local k = norm(path)
			if diskFiles[k] == nil then error("File not found: " .. k, 0) end
			return diskFiles[k]
		end
		sandbox.isfile = function(path) return diskFiles[norm(path)] ~= nil end
		sandbox.isfolder = function(path) return diskFolders[norm(path)] == true end
		sandbox.makefolder = function(path)
			local walk = ""
			for part in norm(path):gmatch("[^/]+") do
				walk = walk == "" and part or (walk .. "/" .. part)
				diskFolders[walk] = true
			end
		end
		sandbox.delfile = function(path) diskFiles[norm(path)] = nil end
		sandbox.delfolder = function(path)
			local k = norm(path)
			local pfx = k .. "/"
			diskFolders[k] = nil
			for f in pairs(diskFiles) do
				if f:sub(1, #pfx) == pfx then diskFiles[f] = nil end
			end
			for d in pairs(diskFolders) do
				if d:sub(1, #pfx) == pfx then diskFolders[d] = nil end
			end
		end
		sandbox.listfiles = function(path)
			local k = norm(path)
			if k == "." then k = "" end
			local pfx = k == "" and "" or (k .. "/")
			local seen, out = {}, {}
			local function addFrom(key)
				if pfx == "" or key:sub(1, #pfx) == pfx then
					local rest = key:sub(#pfx + 1)
					local seg = rest:match("^([^/]+)")
					if seg and seg ~= "" then
						local full = pfx .. seg
						if not seen[full] then
							seen[full] = true
							out[#out + 1] = full
						end
					end
				end
			end
			for f in pairs(diskFiles) do addFrom(f) end
			for d in pairs(diskFolders) do
				if d ~= "" and d ~= k then addFrom(d) end
			end
			table.sort(out)
			return out
		end
		sandbox.loadstring = function(src, chunkName)
			local fn, errs = luau.load(src, chunkName or "exec", { entry = true })
			if not fn then
				local e = errs and errs[1]
				return nil, e and (tostring(e.line) .. ": " .. tostring(e.msg)) or "syntax error"
			end
			setfenv(fn, sandbox)
			return fn
		end
	end

	local SAFE_STDLIB = {
		math = math,
		string = string,
		table = table,
		coroutine = coroutine,
		os = { clock = os.clock, time = os.time, difftime = os.difftime },
		utf8 = rawget(_G, "utf8"),
		pcall = pcall,
		xpcall = xpcall,
		ipairs = ipairs,
		pairs = pairs,
		next = next,
		select = select,
		tonumber = tonumber,
		tostring = tostring,
		type = type,
		assert = assert,
		error = error,
		setmetatable = setmetatable,
		getmetatable = getmetatable,
		rawget = rawget,
		rawset = rawset,
		rawequal = rawequal,
		setfenv = setfenv,
		getfenv = getfenv,
		unpack = unpack,
	}
	setmetatable(sandbox, { __index = SAFE_STDLIB })
	sandbox._G = {}

	local H = {
		sandbox = sandbox,
		files = diskFiles,
		folders = diskFolders,
		httpLog = httpLog,
		console = consoleOut,
		coreGui = coreGui,
		playerGui = playerGui,
		camera = camera,
		logService = logService,
		mouse = mockMouse,
		killBrick = killBrick,
		uis = uis,
		heldKeys = heldKeys,
		Enum = Enum,
		dt = dt,
		json = json,
	}

	function H.onHttp(fn)
		httpHandlers[#httpHandlers + 1] = fn
	end

	function H.advance(seconds)
		nowSec = nowSec + (tonumber(seconds) or 0.5)
		local unpackFn = table.unpack or unpack
		for i = #timers, 1, -1 do
			local t = timers[i]
			if t.cancelled then
				table.remove(timers, i)
			elseif t.due <= nowSec then
				table.remove(timers, i)
				t.fn(unpackFn(t.args, 1, t.args.n))
			end
		end
	end

	function H.boot(bundlePath)
		local fh = io.open(bundlePath or "dist/vsrblx.lua", "rb")
		if not fh then return nil, "missing bundle" end
		local src = fh:read("*a")
		fh:close()
		local fn, errs = luau.load(src, "dist/vsrblx.lua", { entry = true })
		if not fn then return nil, errs and errs[1] and errs[1].msg or "parse error" end
		setfenv(fn, sandbox)
		local ok, res = pcall(fn, opts.context)
		if not ok then return nil, tostring(res) end
		H.advance(0.5)
		return res
	end

	function H.screen()
		for _, ch in ipairs(coreGui:GetChildren()) do
			if ch.ClassName == "ScreenGui" then return ch end
		end
		for _, ch in ipairs(playerGui:GetChildren()) do
			if ch.ClassName == "ScreenGui" then return ch end
		end
		return nil
	end

	function H.byName(name, root)
		local top = root or H.screen()
		if not top then return nil end
		for _, d in ipairs(top:GetDescendants()) do
			if d.Name == name then return d end
		end
		return nil
	end

	function H.setViewport(w, h)
		viewport = dt.Vector2.new(w, h)
		camera.ViewportSize = viewport
		camera:GetPropertyChangedSignal("ViewportSize"):Fire()
		H.advance(0.1)
	end

	function H.drag(gui, x1, y1, x2, y2)
		local changed = makeSignal()
		local beginObj = {
			UserInputType = Enum.UserInputType.MouseButton1,
			UserInputState = Enum.UserInputState.Begin,
			Position = dt.Vector3.new(x1, y1, 0),
			Changed = changed,
		}
		gui.InputBegan:Fire(beginObj)
		local moveObj = {
			UserInputType = Enum.UserInputType.MouseMovement,
			UserInputState = Enum.UserInputState.Change,
			Position = dt.Vector3.new(x2, y2, 0),
		}
		uis.InputChanged:Fire(moveObj)
		beginObj.UserInputState = Enum.UserInputState.End
		changed:Fire()
		uis.InputEnded:Fire(beginObj)
		H.advance(0.4)
	end

	function H.click(gui)
		gui.Activated:Fire()
		gui.MouseButton1Click:Fire()
		H.advance(0.1)
	end

	return H
end

return M
