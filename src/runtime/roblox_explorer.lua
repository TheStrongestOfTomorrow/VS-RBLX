-- Live Roblox DataModel inspector: browse services, generate valid Luau Instance paths,
-- inspect Instance properties safely, and read/decompile scripts into VS-RBLX.
return function(env)
	local caps = env.require("runtime/caps")
	local util = env.require("runtime/util")

	local M = {}

	local ROOTS = {
		"Workspace",
		"ReplicatedStorage",
		"Players",
		"StarterPlayer",
		"StarterGui",
		"Lighting",
	}

	local function isValidIdent(str)
		if type(str) ~= "string" or str == "" then return false end
		return str:match("^[%a_][%w_]*$") ~= nil
	end

	function M.formatChildAccess(childName)
		local n = tostring(childName or "")
		if isValidIdent(n) then
			return "." .. n
		end
		local escaped = n:gsub("\\", "\\\\"):gsub('"', '\\"')
		return '["' .. escaped .. '"]'
	end

	-- Produces a clean, copy-paste-ready Luau expression pointing to `inst`
	function M.luauPathOf(inst)
		if not inst then return "nil" end
		if inst == env.game then return "game" end
		if inst == env.workspace then return "workspace" end

		local chain = {}
		local cur = inst
		local guard = 0
		while cur and cur ~= env.game and guard < 40 do
			guard = guard + 1
			chain[#chain + 1] = cur
			local ok, p = pcall(function() return cur.Parent end)
			if not ok then break end
			cur = p
		end

		if #chain == 0 then return "nil" end

		local top = chain[#chain]
		local topClass = ""
		local topName = ""
		pcall(function()
			topClass = tostring(top.ClassName or "")
			topName = tostring(top.Name or "")
		end)

		local expr
		if top == env.workspace or topClass == "Workspace" or topName == "Workspace" then
			expr = "workspace"
		elseif topClass ~= "" then
			expr = string.format('game:GetService(%q)', topClass)
		else
			expr = "game" .. M.formatChildAccess(topName)
		end

		-- Shortcut LocalPlayer if path starts under Players.<LocalPlayerName>
		local startIdx = #chain - 1
		if (topClass == "Players" or topName == "Players") and startIdx >= 1 and env.plr and chain[startIdx] == env.plr then
			expr = 'game:GetService("Players").LocalPlayer'
			startIdx = startIdx - 1
		end

		for i = startIdx, 1, -1 do
			local node = chain[i]
			local nm = ""
			pcall(function() nm = tostring(node.Name or "") end)
			expr = expr .. M.formatChildAccess(nm)
		end

		return expr
	end

	-- Resolves dot/slash paths (`Workspace.Map.Spawn`) AND Luau paths (`workspace.ArenaMap["Lava Platform"]`,
	-- `game:GetService("ReplicatedStorage").SharedConfig`) back into live Instances!
	function M.resolvePath(pathSpec)
		local raw = util.trim(tostring(pathSpec or ""))
		if raw == "" or raw == "game" then return env.game end
		if raw:lower() == "workspace" then return env.workspace end

		-- Strip leading `game:GetService("X")` prefix if present
		local svcName, tailAfterSvc = raw:match('^game:GetService%(%s*["\']([^"\']+)["\']%s*%)(.*)$')
		local cur = nil
		local rest = raw
		if svcName then
			cur = env.services[svcName]
			if not cur and env.game then
				pcall(function() cur = env.game:FindFirstChild(svcName) end)
			end
			if not cur then return nil, "Service not found: " .. tostring(svcName) end
			rest = tailAfterSvc or ""
		end

		-- Tokenize `.Name`, `/Name`, `["Name"]`, `['Name']`, or bare leading `Name`
		local parts = {}
		local pos = 1
		local n = #rest
		while pos <= n do
			local ch = rest:sub(pos, pos)
			if ch == "." or ch == "/" or ch == " " then
				pos = pos + 1
			elseif rest:sub(pos, pos + 1) == '["' then
				local closePos = rest:find('"]', pos + 2, true)
				if not closePos then break end
				local inner = rest:sub(pos + 2, closePos - 1):gsub('\\"', '"'):gsub("\\\\", "\\")
				parts[#parts + 1] = inner
				pos = closePos + 2
			elseif rest:sub(pos, pos + 1) == "['" then
				local closePos = rest:find("']", pos + 2, true)
				if not closePos then break end
				local inner = rest:sub(pos + 2, closePos - 1):gsub("\\'", "'"):gsub("\\\\", "\\")
				parts[#parts + 1] = inner
				pos = closePos + 2
			else
				local nextSep = rest:find("[%.%/%[]", pos)
				local seg = nextSep and rest:sub(pos, nextSep - 1) or rest:sub(pos)
				seg = util.trim(seg)
				if seg ~= "" then parts[#parts + 1] = seg end
				pos = nextSep or (n + 1)
			end
		end

		if not cur then
			if #parts == 0 then return nil, "Invalid path: " .. raw end
			local first = parts[1]
			if first:lower() == "game" then
				cur = env.game
				table.remove(parts, 1)
				first = parts[1]
			end
			if not first then return cur end
			if not cur then
				if first:lower() == "workspace" then
					cur = env.workspace
				else
					cur = env.services[first]
					if not cur and env.game then
						pcall(function() cur = env.game:FindFirstChild(first) end)
					end
				end
				table.remove(parts, 1)
			end
		end

		for _, seg in ipairs(parts) do
			if not cur then return nil, "Instance not found along: " .. raw end
			if seg == "LocalPlayer" and cur == env.players then
				cur = env.plr
			else
				local nxt = nil
				pcall(function() nxt = cur:FindFirstChild(seg) end)
				cur = nxt
			end
		end
		if not cur then return nil, "Instance not found: " .. raw end
		return cur
	end

	local PROBE_PROPS = {
		"Name",
		"ClassName",
		"Position",
		"Size",
		"Anchored",
		"CanCollide",
		"Transparency",
		"Visible",
		"Active",
		"Text",
		"Value",
		"Enabled",
	}

	function M.inspectProperties(inst)
		if not inst then return nil, "Instance not found" end
		local props = {}
		for _, propName in ipairs(PROBE_PROPS) do
			local ok, val = pcall(function() return inst[propName] end)
			if ok and val ~= nil then
				props[#props + 1] = {
					name = propName,
					value = tostring(val),
					kind = type(val),
				}
			end
		end
		local childCount = 0
		pcall(function() childCount = #inst:GetChildren() end)
		props[#props + 1] = { name = "Children", value = tostring(childCount), kind = "number" }
		props[#props + 1] = { name = "LuauPath", value = M.luauPathOf(inst), kind = "string" }
		return props
	end

	function M.rootServices()
		local out = {}
		for _, name in ipairs(ROOTS) do
			local svc = env.services[name]
			if svc then
				out[#out + 1] = {
					name = name,
					className = svc.ClassName or name,
					instance = svc,
				}
			end
		end
		return out
	end

	function M.childrenOf(inst, limit)
		if not inst then return {} end
		local ok, children = pcall(function() return inst:GetChildren() end)
		if not ok or type(children) ~= "table" then return {} end
		local maxItems = limit or 120
		local out = {}
		for i = 1, math.min(#children, maxItems) do
			local ch = children[i]
			local isScript = false
			pcall(function()
				isScript = ch:IsA("LuaSourceContainer")
			end)
			local hasKids = false
			pcall(function()
				hasKids = #ch:GetChildren() > 0
			end)
			out[#out + 1] = {
				name = tostring(ch.Name or ch.ClassName),
				className = tostring(ch.ClassName or "Instance"),
				instance = ch,
				isScript = isScript,
				hasChildren = hasKids,
			}
		end
		table.sort(out, function(a, b)
			if a.isScript ~= b.isScript then return a.isScript end
			return a.name:lower() < b.name:lower()
		end)
		return out
	end

	function M.readScriptSource(inst)
		if not inst then return nil, "no instance" end
		local okSrc, rawSrc = pcall(function() return inst.Source end)
		if okSrc and type(rawSrc) == "string" and rawSrc ~= "" then
			return rawSrc, "Source"
		end
		if caps.fn.decompile then
			local okDec, decompiled = pcall(caps.fn.decompile, inst)
			if okDec and type(decompiled) == "string" and decompiled ~= "" then
				return decompiled, "decompile"
			end
		end
		return string.format(
			"-- Instance: %s (%s)\n-- Path: %s\n-- Source is not readable without executor `decompile()` support.\n",
			tostring(inst.Name),
			tostring(inst.ClassName),
			M.luauPathOf(inst)
		), "stub"
	end

	return M
end
