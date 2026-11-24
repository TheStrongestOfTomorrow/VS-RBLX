-- FNV-1a 32-bit hash generator for deterministic VS-RBLX bundle build IDs.
return function(version, modules, bootstrap)
	local h1 = 2166136261
	local h2 = 16777619

	local function feed(text)
		local s = tostring(text or ""):gsub("\r\n", "\n")
		for i = 1, #s do
			local b = s:byte(i)
			h1 = ((h1 + b) * 16777619) % 4294967291
			h2 = ((h2 * 65599) + b) % 4294967279
		end
	end

	feed(version)
	for _, mod in ipairs(modules or {}) do
		feed(mod.id)
		feed(mod.source)
	end
	feed(bootstrap)
	return string.format("%s-%08x%08x", tostring(version or "1.0.0"), h1, h2)
end
