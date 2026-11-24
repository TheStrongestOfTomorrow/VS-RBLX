-- Indentation-based code folding regions and symbol extraction for breadcrumbs / outline.
return function(env)
	local util = env.require("runtime/util")
	local M = {}

	local function indentWidth(line)
		local width = 0
		for i = 1, #line do
			local c = line:sub(i, i)
			if c == "\t" then
				width = width + 4
			elseif c == " " then
				width = width + 1
			else
				break
			end
		end
		return width
	end

	function M.regions(source)
		local lines = util.lines(source or "")
		local map = {}
		local n = #lines

		for i = 1, n - 1 do
			local line = lines[i]
			if line:find("%S") then
				local baseIndent = indentWidth(line)
				local j = i + 1
				local lastFold = nil
				while j <= n do
					local nxt = lines[j]
					if nxt:find("%S") then
						if indentWidth(nxt) > baseIndent then
							lastFold = j
						else
							break
						end
					end
					j = j + 1
				end
				if lastFold and lastFold > i then
					map[i] = lastFold
				end
			end
		end
		return map
	end

	function M.symbols(source, langId)
		local lines = util.lines(source or "")
		local out = {}
		for i, line in ipairs(lines) do
			local fnName = line:match("function%s+([%w_%.:]+)%s*%(")
				or line:match("local%s+function%s+([%w_]+)%s*%(")
				or line:match("^%s*def%s+([%w_]+)%s*%(")
				or line:match("^%s*async%s+def%s+([%w_]+)%s*%(")
				or line:match("^%s*fn%s+([%w_]+)%s*[%(<]")
				or line:match("^%s*pub%s+fn%s+([%w_]+)%s*[%(<]")
				or line:match("^%s*func%s+([%w_]+)%s*%(")
			local className = line:match("^%s*class%s+([%w_]+)")
				or line:match("^%s*export%s+class%s+([%w_]+)")
				or line:match("^%s*export%s+interface%s+([%w_]+)")
				or line:match("^%s*interface%s+([%w_]+)")
				or line:match("^%s*struct%s+([%w_]+)")
			if fnName then
				out[#out + 1] = { kind = "function", name = fnName, line = i }
			elseif className then
				out[#out + 1] = { kind = "class", name = className, line = i }
			elseif langId == "markdown" and line:match("^#+%s+(.+)$") then
				out[#out + 1] = { kind = "heading", name = line:match("^#+%s+(.+)$"), line = i }
			end
		end
		return out
	end

	return M
end
