-- Command Palette (`Ctrl+Shift+P` / `F1`) action registry for VS-RBLX.
return function(_env)
	local M = { list = {}, byId = {} }

	function M.register(spec)
		if not spec or not spec.id then return end
		if M.byId[spec.id] then
			local existing = M.byId[spec.id]
			for k, v in pairs(spec) do existing[k] = v end
			return existing
		end
		M.byId[spec.id] = spec
		M.list[#M.list + 1] = spec
		return spec
	end

	function M.run(id, ...)
		local cmd = M.byId[id]
		if not cmd or type(cmd.run) ~= "function" then return false, "unknown command: " .. tostring(id) end
		return pcall(cmd.run, ...)
	end

	function M.search(query)
		local q = tostring(query or ""):lower():gsub("^>%s*", ""):gsub("^%s+", ""):gsub("%s+$", "")
		local out = {}
		for _, cmd in ipairs(M.list) do
			local label = (cmd.category and (cmd.category .. ": " .. cmd.title) or cmd.title or cmd.id)
			if q == "" or label:lower():find(q, 1, true) or cmd.id:lower():find(q, 1, true) then
				out[#out + 1] = {
					id = cmd.id,
					label = label,
					shortcut = cmd.shortcut or "",
					category = cmd.category or "General",
					run = cmd.run,
				}
			end
		end
		table.sort(out, function(a, b) return a.label < b.label end)
		return out
	end

	return M
end
