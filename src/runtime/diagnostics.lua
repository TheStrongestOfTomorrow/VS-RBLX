-- Real-time syntax & bracket diagnostics feeding VS-RBLX editor gutter markers,
-- status bar error/warning counters, and the bottom Problems panel.
return function(env)
	local caps = env.require("runtime/caps")
	local util = env.require("runtime/util")
	local languages = env.require("runtime/languages")
	local signal = env.require("runtime/signal")

	local M = {
		byDoc = {},
		changed = signal.new("diagnostics.changed"),
	}

	local function checkBracketBalance(source)
		local issues = {}
		local stack = {}
		local pairsMap = { ["("] = ")", ["["] = "]", ["{"] = "}" }
		local closers = { [")"] = "(", ["]"] = "[", ["}"] = "{" }
		local lines = util.lines(source)

		for ln, line in ipairs(lines) do
			local inQuote = nil
			local i = 1
			while i <= #line do
				local c = line:sub(i, i)
				if inQuote then
					if c == "\\" then
						i = i + 1
					elseif c == inQuote then
						inQuote = nil
					end
				else
					if c == "/" and line:sub(i + 1, i + 1) == "/" then
						break
					elseif c == "#" then
						break
					elseif c == '"' or c == "'" then
						inQuote = c
					elseif pairsMap[c] then
						stack[#stack + 1] = { char = c, expect = pairsMap[c], line = ln, col = i }
					elseif closers[c] then
						local top = stack[#stack]
						if not top or top.char ~= closers[c] then
							issues[#issues + 1] = {
								severity = "error",
								line = ln,
								col = i,
								message = string.format("Unexpected closing '%s'", c),
							}
							return issues
						else
							stack[#stack] = nil
						end
					end
				end
				i = i + 1
			end
		end

		if #stack > 0 then
			local top = stack[#stack]
			issues[#issues + 1] = {
				severity = "error",
				line = top.line,
				col = top.col,
				message = string.format("Unclosed '%s' (expected '%s')", top.char, top.expect),
			}
		end
		return issues
	end

	function M.check(doc)
		if not doc or doc.isDiff then return {} end
		local source = tostring(doc.content or "")
		local lang = languages.get(doc.langId)
		local list = {}

		if lang.id == "luau" and caps.fn.loadstring then
			local fn, err = caps.fn.loadstring(source, doc.path or "chunk")
			if not fn and err then
				local ln = tonumber(tostring(err):match(":(%d+):")) or 1
				local msg = tostring(err):match(":%d+:%s*(.*)$") or tostring(err)
				list[#list + 1] = {
					severity = "error",
					line = ln,
					col = 1,
					message = msg,
					path = doc.path,
					docId = doc.id,
				}
			end
		elseif lang.id == "json" then
			if source:find("%S") then
				local decoded, err = util.jsonDecode(source)
				if decoded == nil and err then
					list[#list + 1] = {
						severity = "error",
						line = 1,
						col = 1,
						message = tostring(err),
						path = doc.path,
						docId = doc.id,
					}
				end
			end
		elseif lang.id == "javascript" or lang.id == "typescript" or lang.id == "python"
			or lang.id == "rust" or lang.id == "go" or lang.id == "cpp" or lang.id == "csharp" or lang.id == "java" then
			for _, issue in ipairs(checkBracketBalance(source)) do
				issue.path = doc.path
				issue.docId = doc.id
				list[#list + 1] = issue
			end
		end

		local lines = util.lines(source)
		for i, line in ipairs(lines) do
			if line:find("TODO", 1, true) or line:find("FIXME", 1, true) then
				list[#list + 1] = {
					severity = "warn",
					line = i,
					col = 1,
					message = "Note marker: " .. util.trim(line):sub(1, 70),
					path = doc.path,
					docId = doc.id,
				}
			end
		end

		M.byDoc[doc.id] = list
		M.changed:fire(doc.id, list)
		return list
	end

	function M.remove(docId)
		M.byDoc[docId] = nil
		M.changed:fire(docId, {})
	end

	function M.all()
		local errorsCount, warnsCount = 0, 0
		local items = {}
		for _, list in pairs(M.byDoc) do
			for _, item in ipairs(list) do
				items[#items + 1] = item
				if item.severity == "error" then
					errorsCount = errorsCount + 1
				else
					warnsCount = warnsCount + 1
				end
			end
		end
		table.sort(items, function(a, b)
			if a.path ~= b.path then return tostring(a.path) < tostring(b.path) end
			return (a.line or 1) < (b.line or 1)
		end)
		return items, errorsCount, warnsCount
	end

	return M
end
