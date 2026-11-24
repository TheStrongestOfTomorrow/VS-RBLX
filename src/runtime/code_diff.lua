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

	return M
end
