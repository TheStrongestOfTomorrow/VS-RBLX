-- VS Code Workspace Search & Replace Sidebar Viewlet (`Ctrl+Shift+F`).
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local overlay = env.require("ui/overlay")
	local util = env.require("runtime/util")
	local codeSearch = env.require("runtime/code_search")
	local codeStore = env.require("runtime/code_store")

	local M = {}

	function M.new(parent)
		local root = P.frame(parent, {
			name = "SearchViewlet",
			size = UDim2.fromScale(1, 1),
			visible = false,
			zIndex = 21,
		})
		P.pad(root, 6, 10, 6, 10)

		P.label(root, {
			size = UDim2.new(1, 0, 0, 22),
			text = "SEARCH",
			bold = true,
			textSize = 11,
			color = theme.color.muted,
			zIndex = 22,
		})

		local _, queryBox = P.input(root, {
			name = "WorkspaceSearchInput",
			size = UDim2.new(1, 0, 0, 26),
			pos = UDim2.fromOffset(0, 26),
			placeholder = "Search across files...",
			zIndex = 22,
		})

		local _, replaceBox = P.input(root, {
			name = "WorkspaceReplaceInput",
			size = UDim2.new(1, 0, 0, 26),
			pos = UDim2.fromOffset(0, 56),
			placeholder = "Replace with...",
			zIndex = 22,
		})

		local optsRow = P.frame(root, {
			size = UDim2.new(1, 0, 0, 26),
			pos = UDim2.fromOffset(0, 86),
			zIndex = 22,
		})
		P.list(optsRow, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

		local caseSensitive = false
		local wholeWord = false

		local caseBtn = P.button(optsRow, {
			size = UDim2.fromOffset(30, 22),
			bg = theme.color.inputBg,
			text = "Aa",
			mono = true,
			textSize = 11,
			radius = 3,
			order = 1,
			zIndex = 23,
		})
		local wordBtn = P.button(optsRow, {
			size = UDim2.fromOffset(32, 22),
			bg = theme.color.inputBg,
			text = "[ab]",
			mono = true,
			textSize = 10,
			radius = 3,
			order = 2,
			zIndex = 23,
		})
		local replaceAllBtn = P.button(optsRow, {
			name = "WorkspaceReplaceAllBtn",
			size = UDim2.fromOffset(92, 22),
			bg = theme.color.accent,
			hoverBg = theme.color.accentHover,
			color = Color3.fromRGB(255, 255, 255),
			text = "Replace All",
			textSize = 11,
			radius = 3,
			order = 3,
			zIndex = 23,
		})

		local statusLbl = P.label(root, {
			size = UDim2.new(1, 0, 0, 18),
			pos = UDim2.fromOffset(0, 114),
			text = "Type a query to search workspace files.",
			textSize = 11,
			color = theme.color.muted,
			zIndex = 22,
		})

		local resultsScroll = P.scroll(root, {
			name = "SearchResultsScroll",
			size = UDim2.new(1, 0, 1, -136),
			pos = UDim2.fromOffset(0, 136),
			zIndex = 22,
		})
		P.list(resultsScroll, Enum.FillDirection.Vertical, 2)

		local function runSearch()
			resultsScroll:ClearAllChildren()
			P.list(resultsScroll, Enum.FillDirection.Vertical, 2)
			local q = queryBox.Text
			if q == "" then
				statusLbl.Text = "Type a query to search workspace files."
				return
			end
			local scan = codeSearch.searchWorkspace(q, {
				caseSensitive = caseSensitive,
				wholeWord = wholeWord,
			})
			statusLbl.Text = string.format("%d result(s) in %d file(s)", scan.totalMatches, #scan.files)

			local ord = 0
			for _, fileGroup in ipairs(scan.files) do
				ord = ord + 1
				P.label(resultsScroll, {
					size = UDim2.new(1, 0, 0, 20),
					bold = true,
					textSize = 11,
					color = theme.color.tabActiveText,
					text = string.format("▾ %s (%d)", fileGroup.path, #fileGroup.matches),
					truncate = true,
					order = ord,
					zIndex = 23,
				})
				for _, hit in ipairs(fileGroup.matches) do
					if ord < 160 then
						ord = ord + 1
						local targetPath = fileGroup.path
						local targetLn, targetCol = hit.line, hit.col
						local hitBtn = P.button(resultsScroll, {
							size = UDim2.new(1, 0, 0, 20),
							hoverBg = theme.color.hover,
							alignX = Enum.TextXAlignment.Left,
							mono = true,
							textSize = 11,
							color = theme.color.sideBarText,
							text = string.format("  %3d: %s", hit.line, util.trim(hit.lineText)),
							order = ord,
							zIndex = 23,
							onClick = function()
								codeStore.openFile(targetPath, { line = targetLn, col = targetCol })
							end,
						})
						hitBtn.TextTruncate = Enum.TextTruncate.AtEnd
					end
				end
			end
		end

		caseBtn.Activated:Connect(function()
			caseSensitive = not caseSensitive
			caseBtn.BackgroundColor3 = caseSensitive and theme.color.accent or theme.color.inputBg
			runSearch()
		end)
		wordBtn.Activated:Connect(function()
			wholeWord = not wholeWord
			wordBtn.BackgroundColor3 = wholeWord and theme.color.accent or theme.color.inputBg
			runSearch()
		end)
		queryBox:GetPropertyChangedSignal("Text"):Connect(runSearch)

		replaceAllBtn.Activated:Connect(function()
			if queryBox.Text == "" then return end
			local filesChanged, totalRep = codeSearch.replaceAcrossWorkspace(queryBox.Text, replaceBox.Text, {
				caseSensitive = caseSensitive,
				wholeWord = wholeWord,
			})
			overlay.toast(string.format("Replaced %d occurrence(s) across %d file(s)", totalRep, filesChanged), "good", 3)
			runSearch()
		end)

		return {
			root = root,
			focus = function()
				task.defer(function() pcall(function() queryBox:CaptureFocus() end) end)
			end,
		}
	end

	return M
end
