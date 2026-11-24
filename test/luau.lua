-- Clean Luau-to-LuaJIT syntax validator and module dependency extractor for VS-RBLX.
local M = {}

local function buildLineLookup(src)
	local starts = { 1 }
	local pos = 1
	while true do
		local nl = src:find("\n", pos, true)
		if not nl then break end
		starts[#starts + 1] = nl + 1
		pos = nl + 1
	end
	return function(offset)
		local lo, hi = 1, #starts
		while lo < hi do
			local mid = math.floor((lo + hi + 1) / 2)
			if starts[mid] <= offset then lo = mid else hi = mid - 1 end
		end
		return lo
	end
end

function M.stripStringsAndComments(src)
	local chars = {}
	local n = #src
	for i = 1, n do chars[i] = src:sub(i, i) end

	local function blankRange(a, b)
		for k = a, math.min(b, n) do
			if chars[k] ~= "\n" then chars[k] = " " end
		end
	end

	local i = 1
	while i <= n do
		local c = src:sub(i, i)
		if c == "-" and src:sub(i + 1, i + 1) == "-" then
			local eq = src:match("^%-%-%[(=*)%[", i)
			if eq then
				local closeTag = "]" .. eq .. "]"
				local hit = src:find(closeTag, i + 4 + #eq, true)
				local stop = hit and (hit + #closeTag - 1) or n
				blankRange(i, stop)
				i = stop + 1
			else
				local nl = src:find("\n", i, true)
				local stop = nl and (nl - 1) or n
				blankRange(i, stop)
				i = stop + 1
			end
		elseif c == "[" and src:match("^%[=*%[", i) then
			local eq = src:match("^%[(=*)%[", i)
			local closeTag = "]" .. eq .. "]"
			local hit = src:find(closeTag, i + 2 + #eq, true)
			local stop = hit and (hit + #closeTag - 1) or n
			blankRange(i, stop)
			i = stop + 1
		elseif c == '"' or c == "'" then
			local j = i + 1
			while j <= n do
				local cj = src:sub(j, j)
				if cj == "\\" then
					j = j + 2
				elseif cj == c or cj == "\n" then
					break
				else
					j = j + 1
				end
			end
			blankRange(i, math.min(j, n))
			i = math.min(j, n) + 1
		else
			i = i + 1
		end
	end
	return table.concat(chars)
end

function M.load(src, name, opts)
	opts = opts or {}
	local lineAt = buildLineLookup(src)
	local problems = {}

	if not opts.entry then
		if not src:find("^return function%(") and not src:find("\nreturn function%(") then
			problems[#problems + 1] = { line = 1, msg = "module must return function(env)" }
			return nil, problems
		end
	end

	local loader = loadstring or load
	local fn, err = loader(src, "@" .. tostring(name or "chunk"))
	if not fn then
		local ln = tonumber(tostring(err):match(":(%d+):")) or lineAt(1)
		local detail = tostring(err):match(":%d+:%s*(.*)$") or tostring(err)
		problems[#problems + 1] = { line = ln, msg = detail }
		return nil, problems
	end
	return fn, nil
end

function M.requires(src)
	local masked = M.stripStringsAndComments(src)
	local lineAt = buildLineLookup(src)
	local deps = {}
	local pos = 1
	while true do
		local a, b = masked:find("env%.require%s*%(", pos)
		if not a then break end
		local target = src:match('^%s*["\']([^"\']+)["\']', b + 1)
		if target then
			deps[#deps + 1] = { path = target, line = lineAt(a) }
		end
		pos = b + 1
	end
	return deps
end

return M
