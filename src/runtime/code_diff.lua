-- Line-by-line LCS diff engine for VS-RBLX Source Control and unified Diff Viewer.
return function(env)
	local util = env.require("runtime/util")
	local M = {}

	function M.compute(oldSource, newSource)
		local a = util.lines(oldSource or "")
		local b = util.lines(newSource or "")
		local m, n = #a, #b

		local prefix = 0
		while prefix < m and prefix < n and a[prefix + 1] == b[prefix + 1] do
			prefix = prefix + 1
		end
		local suffix = 0
		while suffix < (m - prefix) and suffix < (n - prefix)
			and a[m - suffix] == b[n - suffix] do
			suffix = suffix + 1
		end

		local rows = {}
		local addedCount, removedCount = 0, 0

		for i = 1, prefix do
			rows[#rows + 1] = { kind = "context", oldLine = i, newLine = i, text = a[i] }
		end

		local midM = m - prefix - suffix
		local midN = n - prefix - suffix

		if midM == 0 and midN == 0 then
			return { rows = rows, added = 0, removed = 0 }
		end

		if midM * midN <= 90000 then
			local dp = {}
			for i = 0, midM do
				dp[i] = {}
				dp[i][0] = 0
			end
			for j = 0, midN do dp[0][j] = 0 end
			for i = 1, midM do
				local ai = a[prefix + i]
				local row = dp[i]
				local prevRow = dp[i - 1]
				for j = 1, midN do
					if ai == b[prefix + j] then
						row[j] = prevRow[j - 1] + 1
					else
						local up = prevRow[j]
						local left = row[j - 1]
						row[j] = up >= left and up or left
					end
				end
			end

			local midRows = {}
			local i, j = midM, midN
			while i > 0 or j > 0 do
				if i > 0 and j > 0 and a[prefix + i] == b[prefix + j] then
					midRows[#midRows + 1] = {
						kind = "context",
						oldLine = prefix + i,
						newLine = prefix + j,
						text = a[prefix + i],
					}
					i = i - 1
					j = j - 1
				elseif j > 0 and (i == 0 or dp[i][j - 1] >= dp[i - 1][j]) then
					addedCount = addedCount + 1
					midRows[#midRows + 1] = {
						kind = "add",
						oldLine = nil,
						newLine = prefix + j,
						text = b[prefix + j],
					}
					j = j - 1
				else
					removedCount = removedCount + 1
					midRows[#midRows + 1] = {
						kind = "remove",
						oldLine = prefix + i,
						newLine = nil,
						text = a[prefix + i],
					}
					i = i - 1
				end
			end
			for k = #midRows, 1, -1 do
				rows[#rows + 1] = midRows[k]
			end
		else
			for i = 1, midM do
				removedCount = removedCount + 1
				rows[#rows + 1] = { kind = "remove", oldLine = prefix + i, newLine = nil, text = a[prefix + i] }
			end
			for j = 1, midN do
				addedCount = addedCount + 1
				rows[#rows + 1] = { kind = "add", oldLine = nil, newLine = prefix + j, text = b[prefix + j] }
			end
		end

		for k = 1, suffix do
			rows[#rows + 1] = {
				kind = "context",
				oldLine = m - suffix + k,
				newLine = n - suffix + k,
				text = a[m - suffix + k],
			}
		end

		return {
			rows = rows,
			added = addedCount,
			removed = removedCount,
		}
	end

	-- Pairs contiguous remove+add blocks into 2-column Side-by-Side rows
	function M.sideBySide(oldSource, newSource)
		local unified = M.compute(oldSource, newSource)
		local rows = unified.rows
		local out = {}
		local idx = 1
		local total = #rows

		while idx <= total do
			local r = rows[idx]
			if r.kind == "context" then
				out[#out + 1] = {
					leftLine = r.oldLine,
					leftText = r.text,
					leftKind = "context",
					rightLine = r.newLine,
					rightText = r.text,
					rightKind = "context",
				}
				idx = idx + 1
			else
				local remBlock, addBlock = {}, {}
				while idx <= total and rows[idx].kind == "remove" do
					remBlock[#remBlock + 1] = rows[idx]
					idx = idx + 1
				end
				while idx <= total and rows[idx].kind == "add" do
					addBlock[#addBlock + 1] = rows[idx]
					idx = idx + 1
				end
				local span = math.max(#remBlock, #addBlock)
				for k = 1, span do
					local rem = remBlock[k]
					local add = addBlock[k]
					out[#out + 1] = {
						leftLine = rem and rem.oldLine or nil,
						leftText = rem and rem.text or "",
						leftKind = rem and "remove" or "empty",
						rightLine = add and add.newLine or nil,
						rightText = add and add.text or "",
						rightKind = add and "add" or "empty",
					}
				end
			end
		end

		return {
			rows = out,
			added = unified.added,
			removed = unified.removed,
		}
	end

	-- Returns `{ [newLineNumber] = "add" | "modify" | "delete" }` for Editor Gutter Git indicators
	function M.lineMarkers(oldSource, newSource)
		if oldSource == newSource then return {} end
		local unified = M.compute(oldSource or "", newSource or "")
		local markers = {}
		local pendingRemove = false
		local lastNewLine = 1

		for _, r in ipairs(unified.rows) do
			if r.kind == "remove" then
				pendingRemove = true
			elseif r.kind == "add" then
				local ln = r.newLine or lastNewLine
				markers[ln] = pendingRemove and "modify" or "add"
				lastNewLine = ln
			else
				if pendingRemove then
					local anchor = r.newLine or lastNewLine
					if not markers[anchor] then
						markers[anchor] = "delete"
					end
					pendingRemove = false
				end
				if r.newLine then
					lastNewLine = r.newLine
				end
			end
		end

		if pendingRemove and not markers[lastNewLine] then
			markers[lastNewLine] = "delete"
		end
		return markers
	end

	return M
end
