-- HTTP header helper with automatic credential redaction for logs.
return function(_env)
	local M = {}

	function M.github(token, hasJsonBody)
		local h = {
			["Accept"] = "application/vnd.github+json",
			["X-GitHub-Api-Version"] = "2022-11-28",
			["User-Agent"] = "VS-RBLX/1.0 (Roblox-Luau-Workbench)",
		}
		if type(token) == "string" and token ~= "" then
			h["Authorization"] = "Bearer " .. token
		end
		if hasJsonBody then
			h["Content-Type"] = "application/json"
		end
		return h
	end

	function M.redact(headers)
		local out = {}
		if type(headers) ~= "table" then return out end
		for k, v in pairs(headers) do
			local lk = tostring(k):lower()
			if lk == "authorization" or lk == "x-api-key" or lk == "cookie" then
				out[k] = "<redacted>"
			else
				out[k] = tostring(v)
			end
		end
		return out
	end

	return M
end
