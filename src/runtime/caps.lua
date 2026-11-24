-- Host capability probe for Roblox Executors and Studio LocalScripts.
--
-- Probes executor filesystem (`readfile`, `writefile`, `listfiles`, `makefolder`,
-- `delfile`, `delfolder`), executor HTTP (`request`, `http_request`, `syn.request`,
-- `http.request`, `fluxus.request`, `game:HttpGet`, `HttpService`), script execution
-- (`loadstring`), clipboard, `gethui`, and `decompile`.
return function(env)
	local M = {}

	local function callable(value)
		return type(value) == "function" and value or nil
	end

	local function findRequests()
		local candidates = {
			{ name = "request", fn = callable(request) },
			{ name = "http_request", fn = callable(http_request) },
			{ name = "syn.request", fn = type(syn) == "table" and callable(syn.request) or nil },
			{ name = "http.request", fn = type(http) == "table" and callable(http.request) or nil },
			{ name = "fluxus.request", fn = type(fluxus) == "table" and callable(fluxus.request) or nil },
		}
		local found, seen = {}, {}
		for _, candidate in ipairs(candidates) do
			if candidate.fn and not seen[candidate.fn] then
				seen[candidate.fn] = true
				found[#found + 1] = candidate
			end
		end
		return found
	end

	local function findClipboard()
		return callable(setclipboard)
			or callable(toclipboard)
			or (type(syn) == "table" and callable(syn.write_clipboard))
			or nil
	end

	local requestAliases = findRequests()
	local primaryRequest = requestAliases[1]
	local requestFn = primaryRequest and primaryRequest.fn or nil
	local requestName = primaryRequest and primaryRequest.name or nil

	local compiler = callable(loadstring)
	if not compiler and callable(getgenv) then
		local ok, globals = pcall(getgenv)
		if ok and type(globals) == "table" then
			local readOk, candidate = pcall(function() return globals.loadstring end)
			if readOk then compiler = callable(candidate) end
		end
	end

	local httpGetFn = nil
	pcall(function()
		if game and type(game.HttpGet) == "function" then
			httpGetFn = function(url)
				return game:HttpGet(url)
			end
		end
	end)

	M.fn = {
		request = requestFn,
		httpGet = httpGetFn,
		readfile = callable(readfile),
		writefile = callable(writefile),
		appendfile = callable(appendfile),
		isfile = callable(isfile),
		isfolder = callable(isfolder),
		makefolder = callable(makefolder),
		listfiles = callable(listfiles),
		delfile = callable(delfile),
		delfolder = callable(delfolder),
		loadstring = compiler,
		getgenv = callable(getgenv),
		gethui = callable(gethui),
		clipboard = findClipboard(),
		identify = callable(identifyexecutor) or callable(getexecutorname),
		decompile = callable(decompile),
		getscriptbytecode = callable(getscriptbytecode),
		customasset = callable(getcustomasset),
		cloneref = callable(cloneref),
	}

	M.requestName = requestName
	M.fs = (M.fn.readfile ~= nil and M.fn.writefile ~= nil)
	M.fsList = (M.fn.listfiles ~= nil)
	M.fsFolders = (M.fn.makefolder ~= nil and M.fn.isfolder ~= nil)
	M.exec = (M.fn.loadstring ~= nil)
	M.clipboard = (M.fn.clipboard ~= nil)
	M.decompile = (M.fn.decompile ~= nil)

	if M.fn.request then
		M.http = "executor"
		M.httpWrite = true
	elseif M.fn.httpGet then
		M.http = "httpget"
		M.httpWrite = false
	else
		local ok, available = pcall(function()
			return env.services.HttpService ~= nil
		end)
		M.http = (ok and available) and "httpservice" or "none"
		M.httpWrite = (M.http == "httpservice")
	end

	M.executor = "LocalScript"
	if M.fn.identify then
		local ok, name, ver = pcall(M.fn.identify)
		if ok and type(name) == "string" and name ~= "" then
			M.executor = ver and (name .. " " .. tostring(ver)) or name
		end
	elseif M.fs or M.fn.request then
		M.executor = "Executor"
	end

	function M.matrix()
		return {
			{ key = "executor", label = "Host Runtime", value = M.executor, ok = true },
			{ key = "fs", label = "Local Disk (readfile/writefile)", value = M.fs and "Supported" or "Virtual Memory Fallback", ok = M.fs },
			{ key = "fsList", label = "Directory Scan (listfiles/makefolder)", value = M.fsList and "Supported" or "Virtual Tree", ok = M.fsList },
			{ key = "http", label = "HTTP Transport", value = M.http .. (M.requestName and (" (" .. M.requestName .. ")") or ""), ok = M.http ~= "none" },
			{ key = "githubPush", label = "GitHub Push/Sync (PUT/POST)", value = M.httpWrite and "Supported" or "Read-Only (HttpGet)", ok = M.httpWrite },
			{ key = "exec", label = "Luau Execution (loadstring)", value = M.exec and "Supported" or "Unavailable", ok = M.exec },
			{ key = "clipboard", label = "System Clipboard", value = M.clipboard and "Supported" or "Internal Buffer", ok = M.clipboard },
			{ key = "decompile", label = "Script Decompiler", value = M.decompile and "Supported" or "Unavailable", ok = M.decompile },
		}
	end

	function M.summary()
		return string.format(
			"%s | disk:%s | http:%s | exec:%s",
			M.executor,
			M.fs and "executor-fs" or "memory",
			M.requestName or M.http,
			M.exec and "yes" or "no"
		)
	end

	function M.has(feature)
		if feature == "fs" then return M.fs == true end
		if feature == "fsTree" then return M.fsList == true and M.fsFolders == true end
		if feature == "httpRequest" then return M.fn.request ~= nil or M.http == "httpservice" end
		if feature == "httpGet" then return M.fn.httpGet ~= nil end
		if feature == "loadstring" then return M.exec == true end
		if feature == "clipboard" then return M.clipboard == true end
		if feature == "decompile" then return M.decompile == true end
		return M[feature] == true
	end

	return M
end
