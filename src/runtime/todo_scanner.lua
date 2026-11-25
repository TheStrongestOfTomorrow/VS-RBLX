-- Workspace & Open-Buffer TODO / FIXME / BUG / HACK / NOTE Comment Tracker (`src/runtime/todo_scanner.lua`).
-- Uses the incremental syntax lexer so tags are matched strictly inside comments
-- (never false-positiving on string literals or identifiers).
return function(env)
	local util = env.require("runtime/util")
	local clock = env.require("runtime/clock")
	local signal = env.require("runtime/signal")
	local languages = env.require("runtime/languages")
	local codeLexer = env.require("runtime/code_lexer")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")

	local TAG_META = {
		FIXME = { group = "fixme", rank = 1 },
		BUG = { group = "fixme", rank = 1 },
		HACK = { group = "todo", rank = 2 },
		TODO = { group = "todo", rank = 2 },
		NOTE = { group = "note", rank = 3 },
	}

	local fileCache = {}

	local M = {
		changed = signal.new("todo_scanner.changed"),
		lastItems = {},
		lastCounts = { total = 0, fixme = 0, todo = 0, note = 0 },
	}

	local function extractFromSource(source, langId, pathLabel, docId)
		local cacheKey = tostring(langId or "") .. "\0" .. tostring(pathLabel or "")
		local cached = fileCache[cacheKey]
		if cached and cached.source == source and cached.docId == docId then
			return cached.items
		end

		local items = {}
		if type(source) ~= "string" or source == "" then
			fileCache[cacheKey] = { source = source, docId = docId, items = items }
			return items
		end

		-- Fast pre-check so files without any candidate keywords skip full lexing
		local upperProbe = source:upper()
		if not (
			upperProbe:find("TODO", 1, true)
			or upperProbe:find("FIXME", 1, true)
			or upperProbe:find("BUG", 1, true)
			or upperProbe:find("HACK", 1, true)
			or upperProbe:find("NOTE", 1, true)
		) then
			fileCache[cacheKey] = { source = source, docId = docId, items = items }
			return items
		end

		local scanned = codeLexer.scan(source, langId)
		for lineIdx, spans in ipairs(scanned.spans) do
			local lineText = scanned.lines[lineIdx] or ""
			for _, sp in ipairs(spans or {}) do
				if sp.kind == "todo_tag" or sp.kind == "todo_fixme" or sp.kind == "todo_note" then
					local token = lineText:sub(sp.first, sp.last)
					local rawWord = (token:match("^([%a]+)") or "TODO"):upper()
					local meta = TAG_META[rawWord] or TAG_META.TODO
					local msg = util.trim(lineText:sub(sp.last + 1))
					msg = msg:gsub("^[:%-–—%s]+", ""):gsub("%*%/$", ""):gsub("%]%]$", "")
					msg = util.trim(msg)
					if msg == "" then
						msg = "(no description)"
					end
					items[#items + 1] = {
						tag = rawWord,
						group = meta.group,
						rank = meta.rank,
						path = pathLabel,
						docId = docId,
						line = lineIdx,
						col = sp.first,
						message = msg,
					}
				end
			end
		end

		fileCache[cacheKey] = { source = source, docId = docId, items = items }
		return items
	end

	function M.scanAll()
		local all = {}
		local seenPaths = {}

		-- 1. Scan open buffers first so unsaved live edits update immediately
		for _, doc in ipairs(codeStore.tabs) do
			if not doc.isDiff then
				local p = doc.path ~= "" and util.normalisePath(doc.path) or ""
				if p ~= "" and not doc.untitled then
					seenPaths[p] = true
				end
				local label = (p ~= "" and not doc.untitled) and p or doc.title
				local found = extractFromSource(doc.content, doc.langId, label, doc.id)
				for i = 1, #found do
					all[#all + 1] = found[i]
				end
			end
		end

		-- 2. Scan remaining workspace files on disk
		local diskFiles = workspaceFs.listAllFiles("")
		for _, entry in ipairs(diskFiles) do
			local cleanPath = util.normalisePath(entry.path)
			if not seenPaths[cleanPath] then
				local lang = languages.detect(cleanPath)
				local raw = workspaceFs.readFile(cleanPath)
				if type(raw) == "string" and #raw <= 250000 then
					local found = extractFromSource(raw, lang.id, cleanPath, nil)
					for i = 1, #found do
						all[#all + 1] = found[i]
					end
				end
			end
		end

		table.sort(all, function(a, b)
			if a.rank ~= b.rank then return a.rank < b.rank end
			if a.path ~= b.path then return tostring(a.path) < tostring(b.path) end
			return (a.line or 1) < (b.line or 1)
		end)

		local counts = { total = #all, fixme = 0, todo = 0, note = 0 }
		for i = 1, #all do
			local g = all[i].group
			counts[g] = (counts[g] or 0) + 1
		end

		M.lastItems = all
		M.lastCounts = counts
		return all, counts
	end

	local notifyDebounced = clock.debounce(0.25, function()
		M.scanAll()
		M.changed:fire(M.lastItems, M.lastCounts)
	end)

	codeStore.changed:connect(function()
		notifyDebounced.call()
	end)
	workspaceFs.changed:connect(function()
		fileCache = {}
		notifyDebounced.call()
	end)

	return M
end
