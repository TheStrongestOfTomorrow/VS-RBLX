-- Live Roblox DataModel inspector allowing developers to browse Workspace,
-- ReplicatedStorage, Players, StarterGui, and open/decompile scripts in VS-RBLX.
return function(env)
	local caps = env.require("runtime/caps")
	local M = {}

	local ROOTS = {
		"Workspace",
		"ReplicatedStorage",
		"Players",
		"StarterPlayer",
		"StarterGui",
		"Lighting",
	}

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
			"-- Instance: %s (%s)\n-- Source is not readable without executor `decompile()` support.\n",
			tostring(inst.Name),
			tostring(inst.ClassName)
		), "stub"
	end

	return M
end
