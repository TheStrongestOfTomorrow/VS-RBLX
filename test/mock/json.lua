-- Minimal RFC-8259 JSON encoder/decoder used by VS-RBLX's offline LuaJIT test runner.
local M = {}

local ESC = {
	['"'] = '\\"',
	["\\"] = "\\\\",
	["\b"] = "\\b",
	["\f"] = "\\f",
	["\n"] = "\\n",
	["\r"] = "\\r",
	["\t"] = "\\t",
}

local function quoteStr(s)
	return '"' .. s:gsub('[%c"\\]', function(ch)
		return ESC[ch] or string.format("\\u%04x", ch:byte())
	end) .. '"'
end

local function isSeq(t)
	local count = 0
	for k in pairs(t) do
		if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then return false end
		count = count + 1
	end
	return count == #t
end

function M.encode(val)
	local kind = type(val)
	if val == nil then return "null" end
	if kind == "boolean" then return val and "true" or "false" end
	if kind == "number" then
		if val == math.floor(val) and math.abs(val) < 1e14 then
			return string.format("%d", val)
		end
		return tostring(val)
	end
	if kind == "string" then return quoteStr(val) end
	if kind == "table" then
		if isSeq(val) then
			local out = {}
			for i = 1, #val do out[i] = M.encode(val[i]) end
			return "[" .. table.concat(out, ",") .. "]"
		end
		local keys = {}
		for k in pairs(val) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		local out = {}
		for _, k in ipairs(keys) do
			if val[k] ~= nil then
				out[#out + 1] = quoteStr(tostring(k)) .. ":" .. M.encode(val[k])
			end
		end
		return "{" .. table.concat(out, ",") .. "}"
	end
	error("JSONEncode unsupported type: " .. kind, 0)
end

function M.decode(str)
	local pos = 1
	local len = #str

	local function skipWs()
		local _, stop = str:find("^[ \t\r\n]+", pos)
		if stop then pos = stop + 1 end
	end

	local parseVal

	local function parseStr()
		pos = pos + 1
		local parts = {}
		while pos <= len do
			local c = str:sub(pos, pos)
			if c == '"' then
				pos = pos + 1
				return table.concat(parts)
			elseif c == "\\" then
				local nxt = str:sub(pos + 1, pos + 1)
				pos = pos + 2
				if nxt == "n" then parts[#parts + 1] = "\n"
				elseif nxt == "t" then parts[#parts + 1] = "\t"
				elseif nxt == "r" then parts[#parts + 1] = "\r"
				elseif nxt == "b" then parts[#parts + 1] = "\b"
				elseif nxt == "f" then parts[#parts + 1] = "\f"
				elseif nxt == "u" then
					local hex = tonumber(str:sub(pos, pos + 3), 16) or 63
					pos = pos + 4
					parts[#parts + 1] = hex < 128 and string.char(hex) or "?"
				else
					parts[#parts + 1] = nxt
				end
			else
				parts[#parts + 1] = c
				pos = pos + 1
			end
		end
		error("Unterminated JSON string", 0)
	end

	parseVal = function()
		skipWs()
		local c = str:sub(pos, pos)
		if c == '"' then
			return parseStr()
		elseif c == "{" then
			pos = pos + 1
			local obj = {}
			skipWs()
			if str:sub(pos, pos) == "}" then
				pos = pos + 1
				return obj
			end
			while true do
				skipWs()
				local k = parseStr()
				skipWs()
				if str:sub(pos, pos) ~= ":" then error("Expected ':'", 0) end
				pos = pos + 1
				obj[k] = parseVal()
				skipWs()
				local sep = str:sub(pos, pos)
				pos = pos + 1
				if sep == "}" then return obj end
				if sep ~= "," then error("Expected ',' or '}'", 0) end
			end
		elseif c == "[" then
			pos = pos + 1
			local arr = {}
			skipWs()
			if str:sub(pos, pos) == "]" then
				pos = pos + 1
				return arr
			end
			local idx = 1
			while true do
				arr[idx] = parseVal()
				idx = idx + 1
				skipWs()
				local sep = str:sub(pos, pos)
				pos = pos + 1
				if sep == "]" then return arr end
				if sep ~= "," then error("Expected ',' or ']'", 0) end
			end
		elseif str:sub(pos, pos + 3) == "true" then
			pos = pos + 4
			return true
		elseif str:sub(pos, pos + 4) == "false" then
			pos = pos + 5
			return false
		elseif str:sub(pos, pos + 3) == "null" then
			pos = pos + 4
			return nil
		else
			local num = str:match("^%-?%d+%.?%d*[eE]?[%+%-]?%d*", pos)
			if not num or num == "" then error("Unexpected token at " .. pos, 0) end
			pos = pos + #num
			return tonumber(num)
		end
	end

	return parseVal()
end

return M
