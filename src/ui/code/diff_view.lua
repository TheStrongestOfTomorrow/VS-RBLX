-- Colorized Git Diff Viewer for VS-RBLX Source Control:
-- Supports toggling between Unified Diff and 2-Pane Side-by-Side Diff (synchronized scroll),
-- plus quick Stage (`+`), Unstage (`-`), and Open Working File actions.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local config = env.require("runtime/config")
	local codeDiff = env.require("runtime/code_diff")
	local codeStore = env.require("runtime/code_store")
	local gitState = env.require("runtime/git_state")

	local M = {}

	function M.new(parent)
		local sideBySideMode = config.get("git.sideBySideDiff", true) ~= false
		local activeDoc = nil

		local root = P.frame(parent, {
			name = "DiffViewer",
			size = UDim2.fromScale(1, 1),
			bg = theme.color.editor,
			transparency = 1,
			visible = false,
			zIndex = 15,
		})

		local summaryBar = P.frame(root, {
			name = "DiffSummary",
			size = UDim2.new(1, 0, 0, 28),
			bg = theme.color.sideBarHeader,
			zIndex = 16,
		})
		local summaryLbl = P.label(summaryBar, {
			size = UDim2.new(1, -264, 1, 0),
			pos = UDim2.fromOffset(10, 0),
			text = "Working Tree Diff",
			mono = true,
			textSize = 12,
			color = theme.color.tabActiveText,
			truncate = true,
			zIndex = 17,
		})

		local toolbar = P.frame(summaryBar, {
			name = "DiffToolbar",
			size = UDim2.fromOffset(252, 28),
			pos = UDim2.new(1, -258, 0, 0),
			zIndex = 17,
		})
		P.list(toolbar, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

		local render

		local modeBtn = P.button(toolbar, {
			name = "ToggleDiffModeBtn",
			size = UDim2.fromOffset(96, 22),
			bg = theme.color.accent,
			hoverBg = theme.color.accentHover,
			color = Color3.fromRGB(255, 255, 255),
			bold = true,
			text = sideBySideMode and "Side-by-Side" or "Unified Diff",
			textSize = 11,
			radius = 4,
			order = 1,
			zIndex = 18,
			onClick = function()
				sideBySideMode = not sideBySideMode
				config.set("git.sideBySideDiff", sideBySideMode, { quiet = true })
				if activeDoc then render(activeDoc) end
			end,
		})

		P.button(toolbar, {
			name = "DiffStageBtn",
			size = UDim2.fromOffset(64, 22),
			bg = theme.color.inputBg,
			hoverBg = theme.color.hover,
			text = "+ Stage",
			textSize = 11,
			radius = 4,
			order = 2,
			zIndex = 18,
			onClick = function()
				if activeDoc and activeDoc.path ~= "" then
					gitState.stage(activeDoc.path)
				end
			end,
		})

		P.button(toolbar, {
			name = "DiffOpenFileBtn",
			size = UDim2.fromOffset(74, 22),
			bg = theme.color.inputBg,
			hoverBg = theme.color.hover,
			text = "Edit File",
			textSize = 11,
			radius = 4,
			order = 3,
			zIndex = 18,
			onClick = function()
				if activeDoc and activeDoc.path ~= "" then
					codeStore.openFile(activeDoc.path)
				end
			end,
		})

		-- Unified single scroll pane
		local unifiedScroll = P.scroll(root, {
			name = "DiffUnifiedScroll",
			size = UDim2.new(1, 0, 1, -28),
			pos = UDim2.fromOffset(0, 28),
			bg = theme.color.editor,
			transparency = 1,
			visible = false,
			zIndex = 16,
		})
		P.list(unifiedScroll, Enum.FillDirection.Vertical, 0)

		-- 2-Pane Side-by-Side container with synchronized scrolling
		local splitWrap = P.frame(root, {
			name = "DiffSideBySideWrap",
			size = UDim2.new(1, 0, 1, -28),
			pos = UDim2.fromOffset(0, 28),
			visible = false,
			zIndex = 16,
		})
		local colHeaders = P.frame(splitWrap, {
			size = UDim2.new(1, 0, 0, 20),
			bg = theme.color.panelHeader,
			zIndex = 17,
		})
		P.label(colHeaders, {
			size = UDim2.new(0.5, -8, 1, 0),
			pos = UDim2.fromOffset(8, 0),
			text = "ORIGINAL (HEAD BASELINE)",
			bold = true,
			textSize = 10,
			color = theme.color.muted,
			zIndex = 18,
		})
		P.label(colHeaders, {
			size = UDim2.new(0.5, -8, 1, 0),
			pos = UDim2.new(0.5, 8, 0, 0),
			text = "WORKING TREE (LOCAL DISK)",
			bold = true,
			textSize = 10,
			color = theme.color.good,
			zIndex = 18,
		})
		local centerDivider = P.frame(splitWrap, {
			size = UDim2.new(0, 1, 1, 0),
			pos = UDim2.new(0.5, 0, 0, 0),
			bg = theme.color.border,
			zIndex = 19,
		})

		local leftScroll = P.scroll(splitWrap, {
			name = "DiffLeftPane",
			size = UDim2.new(0.5, -1, 1, -20),
			pos = UDim2.fromOffset(0, 20),
			transparency = 1,
			zIndex = 17,
		})
		local rightScroll = P.scroll(splitWrap, {
			name = "DiffRightPane",
			size = UDim2.new(0.5, 0, 1, -20),
			pos = UDim2.new(0.5, 0, 0, 20),
			transparency = 1,
			zIndex = 17,
		})

		local syncingScroll = false
		leftScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			if syncingScroll then return end
			syncingScroll = true
			rightScroll.CanvasPosition = leftScroll.CanvasPosition
			syncingScroll = false
		end)
		rightScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			if syncingScroll then return end
			syncingScroll = true
			leftScroll.CanvasPosition = rightScroll.CanvasPosition
			syncingScroll = false
		end)

		render = function(doc)
			activeDoc = doc
			modeBtn.Text = sideBySideMode and "Side-by-Side" or "Unified Diff"
			if not doc then return end

			if not sideBySideMode then
				splitWrap.Visible = false
				unifiedScroll.Visible = true
				unifiedScroll:ClearAllChildren()
				P.list(unifiedScroll, Enum.FillDirection.Vertical, 0)

				local result = codeDiff.compute(doc.diffOld or "", doc.diffNew or "")
				summaryLbl.Text = string.format("%s   (+%d, -%d) [Unified]", doc.path, result.added, result.removed)

				for i = 1, math.min(#result.rows, 450) do
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
					local row = P.frame(unifiedScroll, {
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
						textSize = 12,
						color = txtCol,
						truncate = true,
						zIndex = 18,
					})
				end
			else
				unifiedScroll.Visible = false
				splitWrap.Visible = true
				leftScroll:ClearAllChildren()
				rightScroll:ClearAllChildren()
				P.list(leftScroll, Enum.FillDirection.Vertical, 0)
				P.list(rightScroll, Enum.FillDirection.Vertical, 0)

				local sbs = codeDiff.sideBySide(doc.diffOld or "", doc.diffNew or "")
				summaryLbl.Text = string.format("%s   (+%d, -%d) [Side-by-Side]", doc.path, sbs.added, sbs.removed)

				for i = 1, math.min(#sbs.rows, 400) do
					local r = sbs.rows[i]

					local lBg = r.leftKind == "remove" and theme.color.diffRemoveBg or nil
					local lCol = r.leftKind == "remove" and theme.color.bad or theme.color.editorText
					local lRow = P.frame(leftScroll, {
						size = UDim2.new(1, 0, 0, 19),
						bg = lBg,
						transparency = r.leftKind == "empty" and 0.65 or (lBg and 0 or 1),
						order = i,
						zIndex = 18,
					})
					P.label(lRow, {
						size = UDim2.fromOffset(36, 19),
						pos = UDim2.fromOffset(2, 0),
						text = r.leftLine and string.format("%4d", r.leftLine) or "",
						mono = true,
						textSize = 11,
						color = theme.color.lineNumber,
						zIndex = 19,
					})
					P.label(lRow, {
						size = UDim2.new(1, -44, 1, 0),
						pos = UDim2.fromOffset(42, 0),
						text = (r.leftKind == "remove" and "- " or "  ") .. tostring(r.leftText or ""),
						mono = true,
						textSize = 12,
						color = lCol,
						truncate = true,
						zIndex = 19,
					})

					local rBg = r.rightKind == "add" and theme.color.diffAddBg or nil
					local rCol = r.rightKind == "add" and theme.color.good or theme.color.editorText
					local rRow = P.frame(rightScroll, {
						size = UDim2.new(1, 0, 0, 19),
						bg = rBg,
						transparency = r.rightKind == "empty" and 0.65 or (rBg and 0 or 1),
						order = i,
						zIndex = 18,
					})
					P.label(rRow, {
						size = UDim2.fromOffset(36, 19),
						pos = UDim2.fromOffset(2, 0),
						text = r.rightLine and string.format("%4d", r.rightLine) or "",
						mono = true,
						textSize = 11,
						color = theme.color.lineNumber,
						zIndex = 19,
					})
					P.label(rRow, {
						size = UDim2.new(1, -44, 1, 0),
						pos = UDim2.fromOffset(42, 0),
						text = (r.rightKind == "add" and "+ " or "  ") .. tostring(r.rightText or ""),
						mono = true,
						textSize = 12,
						color = rCol,
						truncate = true,
						zIndex = 19,
					})
				end
			end
		end

		theme.changed:connect(function()
			summaryBar.BackgroundColor3 = theme.color.sideBarHeader
			colHeaders.BackgroundColor3 = theme.color.panelHeader
			centerDivider.BackgroundColor3 = theme.color.border
			if activeDoc then render(activeDoc) end
		end)

		return {
			root = root,
			render = render,
			setSideBySide = function(flag)
				sideBySideMode = flag == true
				if activeDoc then render(activeDoc) end
			end,
			isSideBySide = function() return sideBySideMode end,
		}
	end

	return M
end
