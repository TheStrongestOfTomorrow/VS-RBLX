-- System clipboard bridge (`setclipboard`/`toclipboard`) with internal buffer fallback.
return function(env)
	local caps = env.require("runtime/caps")
	local M = { buffer = "" }

	function M.set(text)
		local value = tostring(text or "")
		M.buffer = value
		if caps.fn.clipboard then
			local ok = pcall(caps.fn.clipboard, value)
			return ok, ok and "system" or "internal"
		end
		return true, "internal"
	end

	function M.get()
		return M.buffer
	end

	return M
end
