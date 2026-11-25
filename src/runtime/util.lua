-- Shared pure Luau helpers: strings, paths, tables, math, UTF-8 and JSON wrappers.
return function(env)
	local M = {}

	function M.clamp(value, lo, hi)
		if value < lo then return lo end
		if value > hi then return hi end
		return value
	end

	function M.round(value)
		return math.floor(value + 0.5)
	end

	function M.trim(text)
		return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
	end

	function M.split(text, sep)
		local out = {}
		local str = tostring(text or "")
		local delim = sep or "/"
		if delim == "" then
			for i = 1, #str do out[i] = str:sub(i, i) end
			return out
		end
		local pos = 1
		while true do
			local hit = str:find(delim, pos, true)
			if not hit then
				out[#out + 1] = str:sub(pos)
				break
			end
			out[#out + 1] = str:sub(pos, hit - 1)
			pos = hit + #delim
		end
		return out
	end

	function M.startsWith(text, prefix)
		local s = tostring(text or "")
		local p = tostring(prefix or "")
		return s:sub(1, #p) == p
	end

	function M.endsWith(text, suffix)
		local s = tostring(text or "")
		local p = tostring(suffix or "")
		return p == "" or s:sub(-#p) == p
	end

	function M.escapePattern(text)
		return (tostring(text or ""):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
	end

	function M.escapeRichText(text)
		return (tostring(text or "")
			:gsub("&", "&amp;")
			:gsub("<", "&lt;")
			:gsub(">", "&gt;")
			:gsub('"', "&quot;")
			:gsub("'", "&apos;"))
	end

	function M.validUtf8(text)
		if type(text) ~= "string" then return false end
		if utf8 and type(utf8.len) == "function" then
			local ok, count = pcall(utf8.len, text)
			return ok and count ~= nil
		end
		return true
	end

	function M.normalisePath(path)
		local clean = tostring(path or ""):gsub("\\", "/"):gsub("/+", "/"):gsub("^/+", ""):gsub("/+$", "")
		return clean
	end

	M.normalizePath = M.normalisePath

	function M.basename(path)
		local clean = M.normalisePath(path)
		if clean == "" then return "" end
		return clean:match("([^/]+)$") or clean
	end

	function M.dirname(path)
		local clean = M.normalisePath(path)
		local parent = clean:match("^(.*)/[^/]+$")
		return parent or ""
	end

	function M.extname(path)
		local base = M.basename(path)
		local ext = base:match("%.([^%.]+)$")
		return ext and ext:lower() or ""
	end

	function M.joinPath(a, b)
		local left = M.normalisePath(a)
		local right = M.normalisePath(b)
		if left == "" then return right end
		if right == "" then return left end
		return left .. "/" .. right
	end

	function M.deepCopy(value, seen)
		if type(value) ~= "table" then return value end
		seen = seen or {}
		if seen[value] then return seen[value] end
		local copy = {}
		seen[value] = copy
		for k, v in pairs(value) do
			copy[M.deepCopy(k, seen)] = M.deepCopy(v, seen)
		end
		return copy
	end

	function M.shallowCopy(tbl)
		local out = {}
		if type(tbl) == "table" then
			for k, v in pairs(tbl) do out[k] = v end
		end
		return out
	end

	function M.keys(tbl)
		local out = {}
		if type(tbl) == "table" then
			for k in pairs(tbl) do out[#out + 1] = k end
		end
		table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
		return out
	end

	function M.countLines(text)
		local s = tostring(text or "")
		if s == "" then return 1 end
		local _, n = s:gsub("\n", "\n")
		return n + 1
	end

	function M.lines(text)
		local out = {}
		local s = tostring(text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
		local pos = 1
		while true do
			local nl = s:find("\n", pos, true)
			if not nl then
				out[#out + 1] = s:sub(pos)
				break
			end
			out[#out + 1] = s:sub(pos, nl - 1)
			pos = nl + 1
		end
		if #out == 0 then out[1] = "" end
		return out
	end

	M.splitLines = M.lines

	function M.formatBytes(bytes)
		local n = tonumber(bytes) or 0
		if n < 1024 then return string.format("%d B", n) end
		if n < 1024 * 1024 then return string.format("%.1f KB", n / 1024) end
		return string.format("%.2f MB", n / (1024 * 1024))
	end

	function M.jsonEncode(value)
		local ok, encoded = pcall(function()
			return env.hs:JSONEncode(value)
		end)
		if ok and type(encoded) == "string" then return encoded end
		return nil, tostring(encoded)
	end

	function M.jsonDecode(text)
		if type(text) ~= "string" or text == "" then return nil, "empty json" end
		local ok, decoded = pcall(function()
			return env.hs:JSONDecode(text)
		end)
		if ok then return decoded end
		return nil, tostring(decoded)
	end

	function M.colorToHex(color)
		if not color then return "#cccccc" end
		return string.format(
			"#%02x%02x%02x",
			M.clamp(math.floor(color.R * 255 + 0.5), 0, 255),
			M.clamp(math.floor(color.G * 255 + 0.5), 0, 255),
			M.clamp(math.floor(color.B * 255 + 0.5), 0, 255)
		)
	end

	return M
end
