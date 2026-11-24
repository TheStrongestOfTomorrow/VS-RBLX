-- Multi-language source formatter (`Shift+Alt+F`) for Luau, JSON, C-style braces, and whitespace cleanup.
return function(env)
	local util = env.require("runtime/util")
	local config = env.require("runtime/config")
	local languages = env.require("runtime/languages")

	local M = {}

	local function indentStr(depth)
		local useSpaces = config.get("editor.insertSpaces", true)
		local tabSize = tonumber(config.get("editor.tabSize", 4)) or 4
		if useSpaces then
			return string.rep(" ", math.max(0, depth) * tabSize)
		end
		return string.rep("\t", math.max(0, depth))
	end

	local function prettyJson(val, depth)
		local kind = type(val)
		if val == nil then return "null" end
		if kind == "boolean" then return val and "true" or "false" end
		if kind == "number" then return tostring(val) end
		if kind == "string" then
			return util.jsonEncode(val) or ('"' .. val .. '"')
		end
		if kind == "table" then
			local isArr = true
			local n = 0
			for k in pairs(val) do
				if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
					isArr = false
					break
				end
				n = n + 1
			end
			if isArr and n == #val then
				if n == 0 then return "[]" end
				local items = {}
				for i = 1, n do
					items[i] = indentStr(depth + 1) .. prettyJson(val[i], depth + 1)
				end
				return "[\n" .. table.concat(items, ",\n") .. "\n" .. indentStr(depth) .. "]"
			end
			local keys = util.keys(val)
			if #keys == 0 then return "{}" end
			local rows = {}
			for _, k in ipairs(keys) do
				rows[#rows + 1] = indentStr(depth + 1)
					.. (util.jsonEncode(tostring(k)) or ('"' .. tostring(k) .. '"'))
					.. ": " .. prettyJson(val[k], depth + 1)
			end
			return "{\n" .. table.concat(rows, ",\n") .. "\n" .. indentStr(depth) .. "}"
		end
		return tostring(val)
	end

	local function formatLuau(source)
		local lines = util.lines(source)
		local out = {}
		local depth = 0
		for _, rawLine in ipairs(lines) do
			local trimmed = util.trim(rawLine)
			if trimmed == "" then
				out[#out + 1] = ""
			else
				local codeOnly = trimmed:gsub("%-%-.*$", "")
				local dedentNow = false
				if codeOnly:match("^end[%s%),;]*$")
					or codeOnly:match("^else%f[%W]")
					or codeOnly:match("^elseif%f[%W]")
					or codeOnly:match("^until%f[%W]")
					or codeOnly:match("^[}%]%)][%s,;]*$") then
					dedentNow = true
				end
				if dedentNow then
					depth = math.max(0, depth - 1)
				end
				out[#out + 1] = indentStr(depth) .. trimmed

				local opens = 0
				for _ in codeOnly:gmatch("%f[%w]function%f[%W]") do opens = opens + 1 end
				for _ in codeOnly:gmatch("%f[%w]then%f[%W]") do opens = opens + 1 end
				for _ in codeOnly:gmatch("%f[%w]do%f[%W]") do opens = opens + 1 end
				for _ in codeOnly:gmatch("%f[%w]repeat%f[%W]") do opens = opens + 1 end
				if codeOnly:match("^else%f[%W]") then opens = opens + 1 end
				for _ in codeOnly:gmatch("{") do opens = opens + 1 end

				local closes = 0
				for _ in codeOnly:gmatch("%f[%w]end%f[%W]") do closes = closes + 1 end
				for _ in codeOnly:gmatch("%f[%w]until%f[%W]") do closes = closes + 1 end
				for _ in codeOnly:gmatch("}") do closes = closes + 1 end
				if dedentNow and (codeOnly:match("^end") or codeOnly:match("^until") or codeOnly:match("^[}]")) then
					closes = math.max(0, closes - 1)
				end
				depth = math.max(0, depth + opens - closes)
			end
		end
		return table.concat(out, "\n") .. "\n"
	end

	local function formatBraces(source)
		local lines = util.lines(source)
		local out = {}
		local depth = 0
		for _, rawLine in ipairs(lines) do
			local trimmed = util.trim(rawLine)
			if trimmed == "" then
				out[#out + 1] = ""
			else
				if trimmed:match("^[}%]%)];?,?$") or trimmed:match("^}%s*else") or trimmed:match("^}%s*catch") then
					depth = math.max(0, depth - 1)
				end
				out[#out + 1] = indentStr(depth) .. trimmed
				local opens = 0
				for _ in trimmed:gmatch("{") do opens = opens + 1 end
				local closes = 0
				for _ in trimmed:gmatch("}") do closes = closes + 1 end
				if trimmed:match("^}") then closes = math.max(0, closes - 1) end
				depth = math.max(0, depth + opens - closes)
			end
		end
		return table.concat(out, "\n") .. "\n"
	end

	function M.format(source, langId)
		local lang = languages.get(langId)
		local text = tostring(source or "")
		if lang.id == "json" then
			local decoded, err = util.jsonDecode(text)
			if decoded ~= nil then
				return prettyJson(decoded, 0) .. "\n"
			end
			return text, err
		elseif lang.id == "luau" then
			return formatLuau(text)
		elseif lang.id == "javascript" or lang.id == "typescript" or lang.id == "css"
			or lang.id == "rust" or lang.id == "go" or lang.id == "cpp"
			or lang.id == "csharp" or lang.id == "java" then
			return formatBraces(text)
		else
			local lines = util.lines(text)
			for i = 1, #lines do
				lines[i] = (lines[i]:gsub("[ \t]+$", ""))
			end
			return table.concat(lines, "\n")
		end
	end

	M.formatText = M.format

	function M.formatActive()
		local codeStore = env.require("runtime/code_store")
		local doc = codeStore.active()
		if not doc or doc.readOnly or doc.isDiff then
			return false, "No editable document active"
		end
		local formatted, err = M.format(doc.content, doc.langId)
		if not formatted then
			return false, err or "Format failed"
		end
		codeStore.updateContent(doc.id, formatted)
		return true
	end

	return M
end
