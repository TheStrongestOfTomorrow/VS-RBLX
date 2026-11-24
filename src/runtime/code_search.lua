-- Single-file and workspace-wide multi-file search & replace engine for VS-RBLX.
return function(env)
	local util = env.require("runtime/util")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")

	local M = {}

	local function isWordBoundary(text, first, last)
		local before = first > 1 and text:sub(first - 1, first - 1) or ""
		local after = last < #text and text:sub(last + 1, last + 1) or ""
		local prevWord = before ~= "" and before:match("[%w_]") ~= nil
		local nextWord = after ~= "" and after:match("[%w_]") ~= nil
		return (not prevWord) and (not nextWord)
	end

	function M.findInText(source, query, opts)
		opts = opts or {}
		local q = tostring(query or "")
		if q == "" then return {} end
		local text = tostring(source or "")
		local hay = opts.caseSensitive and text or text:lower()
		local needle = opts.caseSensitive and q or q:lower()
		local plain = opts.usePattern ~= true
		local matches = {}
		local limit = opts.limit or 500

		local lines = util.lines(text)
		local lineOffsets = { 1 }
		for i = 1, #lines - 1 do
			lineOffsets[i + 1] = lineOffsets[i] + #lines[i] + 1
		end

		local function lineColAt(offset)
			local lo, hi = 1, #lineOffsets
			while lo < hi do
				local mid = math.floor((lo + hi + 1) / 2)
				if lineOffsets[mid] <= offset then lo = mid else hi = mid - 1 end
			end
			return lo, offset - lineOffsets[lo] + 1
		end

		local pos = 1
		while pos <= #hay and #matches < limit do
			local ok, a, b = pcall(string.find, hay, needle, pos, plain)
			if not ok or not a then break end
			if b < a then
				pos = a + 1
			else
				if not opts.wholeWord or isWordBoundary(text, a, b) then
					local ln, col = lineColAt(a)
					matches[#matches + 1] = {
						first = a,
						last = b,
						line = ln,
						col = col,
						lineText = lines[ln] or "",
						matched = text:sub(a, b),
					}
				end
				pos = b + 1
			end
		end

		return matches
	end

	function M.replaceInText(source, query, replacement, opts)
		local matches = M.findInText(source, query, opts)
		if #matches == 0 then return source, 0 end
		local rep = tostring(replacement or "")
		local parts = {}
		local cursor = 1
		local maxReplace = (opts and opts.singleIndex) or nil
		local replaced = 0

		for idx, m in ipairs(matches) do
			if not maxReplace or idx == maxReplace then
				parts[#parts + 1] = source:sub(cursor, m.first - 1)
				parts[#parts + 1] = rep
				cursor = m.last + 1
				replaced = replaced + 1
			end
		end
		parts[#parts + 1] = source:sub(cursor)
		return table.concat(parts), replaced
	end

	function M.searchWorkspace(query, opts)
		opts = opts or {}
		local q = tostring(query or "")
		if q == "" then return { files = {}, totalMatches = 0 } end
		local allFiles = workspaceFs.listAllFiles("")
		local results = {}
		local total = 0

		for _, entry in ipairs(allFiles) do
			local openDoc = codeStore.findByPath(entry.path)
			local content = openDoc and openDoc.content or workspaceFs.readFile(entry.path)
			if type(content) == "string" then
				local hits = M.findInText(content, q, opts)
				if #hits > 0 then
					total = total + #hits
					results[#results + 1] = {
						path = entry.path,
						name = entry.name,
						matches = hits,
					}
				end
			end
		end

		return {
			files = results,
			totalMatches = total,
		}
	end

	function M.replaceAcrossWorkspace(query, replacement, opts)
		local scan = M.searchWorkspace(query, opts)
		local filesChanged, totalReplaced = 0, 0
		for _, item in ipairs(scan.files) do
			local openDoc = codeStore.findByPath(item.path)
			local current = openDoc and openDoc.content or workspaceFs.readFile(item.path)
			if type(current) == "string" then
				local updated, count = M.replaceInText(current, query, replacement, opts)
				if count > 0 then
					filesChanged = filesChanged + 1
					totalReplaced = totalReplaced + count
					workspaceFs.writeFile(item.path, updated)
					if openDoc then
						openDoc.content = updated
						openDoc.savedContent = updated
						openDoc.dirty = false
					end
				end
			end
		end
		if filesChanged > 0 then
			codeStore.changed:fire({ reason = "replaceAll", files = filesChanged })
		end
		return filesChanged, totalReplaced
	end

	return M
end
