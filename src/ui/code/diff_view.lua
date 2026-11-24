-- Colorized Git Unified Diff Viewer for VS-RBLX Source Control changes.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local codeDiff = env.require("runtime/code_diff")

	local M = {}

	function M.new(parent)
		local root = P.frame(parent, {
			name = "DiffViewer",
			size = UDim2.fromScale(1, 1),
			bg = theme.color.editor,
			visible = false,
			zIndex = 15,
		})

		local summaryBar = P.frame(root, {
			name = "DiffSummary",
			size = UDim2.new(1, 0, 0, 26),
			bg = theme.color.sideBarHeader,
			zIndex = 16,
		})
		local summaryLbl = P.label(summaryBar, {
			size = UDim2.new(1, -16, 1, 0),
			pos = UDim2.fromOffset(10, 0),
			text = "Working Tree Diff",
			mono = true,
			textSize = 12,
			color = theme.color.tabActiveText,
			zIndex = 17,
		})

		local scroll = P.scroll(root, {
			name = "DiffScroll",
			size = UDim2.new(1, 0, 1, -26),
			pos = UDim2.fromOffset(0, 26),
			bg = theme.color.editor,
			zIndex = 16,
		})
		P.list(scroll, Enum.FillDirection.Vertical, 0)

		local function render(doc)
			scroll:ClearAllChildren()
			P.list(scroll, Enum.FillDirection.Vertical, 0)
			if not doc then return end
			local result = codeDiff.compute(doc.diffOld or "", doc.diffNew or "")
			summaryLbl.Text = string.format("%s   (+%d added, -%d removed)", doc.path, result.added, result.removed)

			local maxRows = math.min(#result.rows, 450)
			for i = 1, maxRows do
				local r = result.rows[i]
				local rowBg = nil
				local prefix = "  "
				local txtCol = theme.color.editorText
				if r.kind == "add" then
					rowBg = theme.color.diffAddBg
					prefix = "+ "
					txtCol = theme.color.good
				elseif r.kind == "remove" then
					rowBg = theme.color.diffRemoveBg
					prefix = "- "
					txtCol = theme.color.bad
				end

				local row = P.frame(scroll, {
					size = UDim2.new(1, 0, 0, 19),
					bg = rowBg,
					order = i,
					zIndex = 17,
				})
				local lnNum = string.format("%4s %4s", r.oldLine and tostring(r.oldLine) or "", r.newLine and tostring(r.newLine) or "")
				P.label(row, {
					size = UDim2.fromOffset(72, 19),
					pos = UDim2.fromOffset(4, 0),
					text = lnNum,
					mono = true,
					textSize = 12,
					color = theme.color.lineNumber,
					zIndex = 18,
				})
				P.label(row, {
					size = UDim2.new(1, -84, 1, 0),
					pos = UDim2.fromOffset(80, 0),
					text = prefix .. tostring(r.text or ""),
					mono = true,
					textSize = 13,
					color = txtCol,
					zIndex = 18,
				})
			end
		end

		theme.changed:connect(function()
			root.BackgroundColor3 = theme.color.editor
			summaryBar.BackgroundColor3 = theme.color.sideBarHeader
			scroll.BackgroundColor3 = theme.color.editor
		end)

		return {
			root = root,
			render = render,
		}
	end

	return M
end
