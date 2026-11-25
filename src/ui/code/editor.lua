-- Full VS Code RichText Multi-Language Editor with Gutter, Active Line, Diagnostics,
-- Inline Find & Replace (`Ctrl+F`/`Ctrl+H`), IntelliSense Popup, Minimap, Diff View, & Welcome.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local minimapMod = env.require("ui/code/minimap")
	local diffViewMod = env.require("ui/code/diff_view")
	local welcomeMod = env.require("ui/code/welcome")
	local util = env.require("runtime/util")
	local config = env.require("runtime/config")
	local clock = env.require("runtime/clock")
	local codeStore = env.require("runtime/code_store")
	local codeLexer = env.require("runtime/code_lexer")
	local codeSearch = env.require("runtime/code_search")
	local intellisense = env.require("runtime/intellisense")
	local diagnostics = env.require("runtime/diagnostics")

	local M = {}

	function M.new(parent, paneName)
		local pane = paneName or "primary"
		local gutterW = 50

		local container = P.frame(parent, {
			name = "EditorGroup_" .. pane,
			size = UDim2.fromScale(1, 1),
			bg = theme.color.editor,
			transparency = 1,
			clip = true,
			zIndex = 12,
		})

		local welcome = welcomeMod.new(container)
		local diffViewer = diffViewMod.new(container)

		local codeSurface = P.frame(container, {
			name = "CodeSurface",
			size = UDim2.fromScale(1, 1),
			bg = theme.color.editor,
			transparency = 1,
			clip = true,
			zIndex = 13,
		})

		local scroll = P.scroll(codeSurface, {
			name = "EditorScroll",
			size = UDim2.new(1, -72, 1, 0),
			bg = theme.color.editor,
			transparency = 1,
			direction = Enum.ScrollingDirection.XY,
			autoCanvas = Enum.AutomaticSize.None,
			barThickness = 8,
			zIndex = 14,
		})

		local activeLineHighlight = P.frame(scroll, {
			name = "ActiveLineHighlight",
			size = UDim2.new(1, 0, 0, 20),
			pos = UDim2.fromOffset(0, 6),
			bg = theme.color.activeLine,
			zIndex = 14,
		})

		local gutter = P.frame(scroll, {
			name = "EditorGutter",
			size = UDim2.new(0, gutterW, 1, 0),
			bg = theme.color.editorGutter,
			zIndex = 16,
		})
		local gutterBorder = P.frame(gutter, {
			size = UDim2.new(0, 1, 1, 0),
			pos = UDim2.new(1, -1, 0, 0),
			bg = theme.color.border,
			transparency = 0.55,
			zIndex = 17,
		})

		local presentationLayer = P.frame(scroll, {
			name = "SyntaxLayer",
			size = UDim2.new(1, -gutterW, 1, 0),
			pos = UDim2.fromOffset(gutterW + 8, 6),
			zIndex = 16,
		})

		local box = Instance.new("TextBox", scroll)
		box.Name = "SourceTextBox"
		box.BorderSizePixel = 0
		box.BackgroundTransparency = 1
		box.Position = UDim2.fromOffset(gutterW + 8, 6)
		box.Size = UDim2.fromOffset(800, 600)
		box.MultiLine = true
		box.ClearTextOnFocus = false
		box.RichText = false
		box.TextWrapped = false
		box.Font = theme.font.mono
		box.TextSize = theme.sizes.editorFont
		box.LineHeight = theme.sizes.editorLineHeight / math.max(1, theme.sizes.editorFont)
		box.TextColor3 = theme.color.editorText
		box.TextTransparency = 1
		box.TextXAlignment = Enum.TextXAlignment.Left
		box.TextYAlignment = Enum.TextYAlignment.Top
		box.Text = ""
		box.ZIndex = 17

		local caretBar = P.frame(scroll, {
			name = "EditorCaret",
			size = UDim2.fromOffset(2, theme.sizes.editorLineHeight),
			pos = UDim2.fromOffset(gutterW + 8, 6),
			bg = theme.color.tabActiveText,
			visible = false,
			zIndex = 18,
		})

		-- Minimap
		local minimap = minimapMod.new(codeSurface, function(ratio)
			local maxScroll = math.max(0, scroll.CanvasSize.Y.Offset - scroll.AbsoluteSize.Y)
			scroll.CanvasPosition = Vector2.new(scroll.CanvasPosition.X, math.floor(maxScroll * ratio))
		end)

		-- Inline Find & Replace Bar (`Ctrl+F` / `Ctrl+H`)
		local findCard = P.frame(codeSurface, {
			name = "FindReplaceWidget",
			size = UDim2.fromOffset(336, 68),
			pos = UDim2.new(1, -418, 0, 6),
			bg = theme.color.sideBar,
			radius = 5,
			border = theme.color.border,
			visible = false,
			active = true,
			zIndex = 40,
		})
		P.pad(findCard, 6, 8, 6, 8)

		local _, findInput = P.input(findCard, {
			name = "FindInput",
			size = UDim2.fromOffset(170, 24),
			placeholder = "Find",
			zIndex = 41,
		})
		local matchCounter = P.label(findCard, {
			size = UDim2.fromOffset(62, 24),
			pos = UDim2.fromOffset(176, 0),
			text = "0/0",
			textSize = 11,
			color = theme.color.muted,
			zIndex = 41,
		})
		P.button(findCard, {
			name = "FindNextBtn",
			size = UDim2.fromOffset(24, 24),
			pos = UDim2.fromOffset(240, 0),
			text = "↓",
			radius = 3,
			zIndex = 41,
			onClick = function() end,
		})
		local findNextBtn = findCard:FindFirstChild("FindNextBtn")
		local closeFindBtn = P.button(findCard, {
			name = "CloseFindBtn",
			size = UDim2.fromOffset(24, 24),
			pos = UDim2.fromOffset(296, 0),
			text = "✕",
			radius = 3,
			zIndex = 41,
			onClick = function() findCard.Visible = false end,
		})
		closeFindBtn.Active = true

		local _, replaceInput = P.input(findCard, {
			name = "ReplaceInput",
			size = UDim2.fromOffset(170, 24),
			pos = UDim2.fromOffset(0, 30),
			placeholder = "Replace",
			zIndex = 41,
		})
		local replaceOneBtn = P.button(findCard, {
			name = "ReplaceOneBtn",
			size = UDim2.fromOffset(64, 24),
			pos = UDim2.fromOffset(176, 30),
			bg = theme.color.inputBg,
			text = "Replace",
			textSize = 11,
			radius = 3,
			zIndex = 41,
		})
		local replaceAllBtn = P.button(findCard, {
			name = "ReplaceAllBtn",
			size = UDim2.fromOffset(74, 24),
			pos = UDim2.fromOffset(244, 30),
			bg = theme.color.accent,
			color = Color3.fromRGB(255, 255, 255),
			text = "Replace All",
			textSize = 11,
			radius = 3,
			zIndex = 41,
		})

		-- IntelliSense popup
		local suggestCard = P.frame(codeSurface, {
			name = "IntelliSensePopup",
			size = UDim2.fromOffset(290, 140),
			pos = UDim2.fromOffset(70, 44),
			bg = theme.color.dropdownBg,
			radius = 4,
			border = theme.color.accent,
			visible = false,
			active = true,
			zIndex = 45,
		})
		P.pad(suggestCard, 4, 4, 4, 4)
		P.list(suggestCard, Enum.FillDirection.Vertical, 1)

		-- State & pools
		local currentDoc = nil
		local lexCache = nil
		local syncingText = false
		local isFocused = false
		local linePool = {}
		local numPool = {}
		local diagDotPool = {}
		local findMatches = {}
		local findIndex = 0
		local currentSuggestions = {}
		local suggestSpanStart, suggestSpanEnd = 1, 0

		local debouncedDiag = clock.debounce(0.3, function()
			if currentDoc then
				diagnostics.check(currentDoc)
			end
		end)

		local function updateLayoutWidths()
			local showMini = config.get("editor.minimap", true) == true
			minimap.root.Visible = showMini
			scroll.Size = UDim2.new(1, showMini and -minimap.width or 0, 1, 0)
			gutter.Visible = config.get("editor.lineNumbers", true) ~= false
			local effGutter = gutter.Visible and gutterW or 8
			presentationLayer.Position = UDim2.fromOffset(effGutter + 8, 6)
			box.Position = UDim2.fromOffset(effGutter + 8, 6)
		end

		local function ensureRowWidgets(slot)
			if not linePool[slot] then
				linePool[slot] = P.label(presentationLayer, {
					name = "CodeLine_" .. tostring(slot),
					size = UDim2.new(1, 0, 0, theme.sizes.editorLineHeight),
					mono = true,
					rich = true,
					textSize = theme.sizes.editorFont,
					color = theme.color.editorText,
					zIndex = 16,
				})
				numPool[slot] = P.label(gutter, {
					name = "LineNum_" .. tostring(slot),
					size = UDim2.fromOffset(gutterW - 10, theme.sizes.editorLineHeight),
					mono = true,
					textSize = math.max(11, theme.sizes.editorFont - 1),
					color = theme.color.lineNumber,
					alignX = Enum.TextXAlignment.Right,
					zIndex = 17,
				})
				diagDotPool[slot] = P.frame(gutter, {
					name = "DiagDot_" .. tostring(slot),
					size = UDim2.fromOffset(5, 5),
					bg = theme.color.bad,
					radius = 3,
					visible = false,
					zIndex = 18,
				})
			end
			return linePool[slot], numPool[slot], diagDotPool[slot]
		end

		local function drawVisibleLines()
			if not currentDoc or not lexCache then return end
			local lh = theme.sizes.editorLineHeight
			local fontSz = theme.sizes.editorFont
			box.Font = theme.font.mono
			box.TextSize = fontSz
			box.LineHeight = lh / math.max(1, fontSz)
			box.TextWrapped = config.get("editor.wordWrap", false) == true

			local totalLines = #lexCache.lines
			local maxChars = 40
			for i = 1, totalLines do
				if #lexCache.lines[i] > maxChars then maxChars = #lexCache.lines[i] end
			end
			local charPx = math.ceil(fontSz * 0.62)
			local contentW = math.max(scroll.AbsoluteSize.X, gutterW + maxChars * charPx + 80)
			local contentH = math.max(scroll.AbsoluteSize.Y, totalLines * lh + 64)

			scroll.CanvasSize = UDim2.fromOffset(contentW, contentH)
			box.Size = UDim2.fromOffset(contentW - gutterW - 12, contentH - 12)
			gutter.Size = UDim2.fromOffset(gutterW, contentH)
			presentationLayer.Size = UDim2.fromOffset(contentW - gutterW - 12, contentH - 12)

			local scrollY = scroll.CanvasPosition.Y
			local viewH = math.max(240, scroll.AbsoluteSize.Y)
			local firstVisible = math.max(1, math.floor(scrollY / lh) - 2)
			local lastVisible = math.min(totalLines, firstVisible + math.ceil(viewH / lh) + 6)

			local diagMap = {}
			for _, d in ipairs(diagnostics.byDoc[currentDoc.id] or {}) do
				diagMap[d.line] = d.severity
			end

			local curLine = currentDoc.view.line or 1
			activeLineHighlight.Visible = config.get("editor.renderActiveLine", true) ~= false
			activeLineHighlight.Position = UDim2.fromOffset(0, 6 + (curLine - 1) * lh)
			activeLineHighlight.Size = UDim2.fromOffset(contentW, lh)
			activeLineHighlight.BackgroundColor3 = theme.color.activeLine

			local hasSelection = isFocused and box.SelectionStart > 0 and box.CursorPosition > 0 and box.SelectionStart ~= box.CursorPosition
			box.TextTransparency = hasSelection and 0 or 1
			box.TextColor3 = theme.color.editorText

			local slot = 0
			for ln = firstVisible, lastVisible do
				slot = slot + 1
				local codeLbl, numLbl, dot = ensureRowWidgets(slot)
				codeLbl.Visible = not hasSelection
				codeLbl.Position = UDim2.fromOffset(0, (ln - 1) * lh)
				codeLbl.Size = UDim2.fromOffset(contentW - gutterW - 16, lh)
				codeLbl.TextSize = fontSz
				codeLbl.TextColor3 = theme.color.editorText
				codeLbl.Text = codeLexer.rich(lexCache.lines[ln], lexCache.spans[ln], theme.syntax)

				numLbl.Visible = true
				numLbl.Position = UDim2.fromOffset(4, 6 + (ln - 1) * lh)
				numLbl.Size = UDim2.fromOffset(gutterW - 12, lh)
				numLbl.TextSize = math.max(11, fontSz - 1)
				numLbl.Text = tostring(ln)
				numLbl.TextColor3 = (ln == curLine) and theme.color.lineNumberActive or theme.color.lineNumber

				local sev = diagMap[ln]
				if sev then
					dot.Visible = true
					dot.Position = UDim2.fromOffset(3, 6 + (ln - 1) * lh + math.floor((lh - 5) / 2))
					dot.BackgroundColor3 = (sev == "error") and theme.color.bad or theme.color.warn
				else
					dot.Visible = false
				end
			end

			for k = slot + 1, #linePool do
				linePool[k].Visible = false
				numPool[k].Visible = false
				diagDotPool[k].Visible = false
			end

			-- Update Caret position
			if isFocused and not hasSelection and currentDoc and not currentDoc.readOnly then
				local col = math.max(1, currentDoc.view.col or 1)
				local lineStr = lexCache.lines[curLine] or ""
				local subBefore = lineStr:sub(1, col - 1):gsub("\t", "    ")
				local effGutter = gutter.Visible and gutterW or 8
				local xPx = effGutter + 8 + math.floor(#subBefore * (fontSz * 0.6))
				local yPx = 6 + (curLine - 1) * lh
				caretBar.Position = UDim2.fromOffset(xPx, yPx)
				caretBar.Size = UDim2.fromOffset(2, lh)
				caretBar.Visible = true
			else
				caretBar.Visible = false
			end

			minimap.updateViewport(scrollY, viewH, contentH)
		end

		local function acceptSuggestion(item)
			if not currentDoc or not item then return end
			suggestCard.Visible = false
			local src = box.Text
			local before = src:sub(1, suggestSpanStart - 1)
			local after = src:sub(suggestSpanEnd + 1)
			local nextText = before .. item.insert .. after
			syncingText = true
			box.Text = nextText
			local newCursor = #before + #item.insert + 1
			box.CursorPosition = newCursor
			syncingText = false
			codeStore.updateContent(currentDoc.id, nextText)
			codeStore.setCursor(currentDoc.id, newCursor, -1)
		end

		local function refreshIntelliSense()
			if not isFocused or not currentDoc or currentDoc.readOnly
				or config.get("editor.intellisense", true) == false then
				suggestCard.Visible = false
				return
			end
			local items, _, sIdx, eIdx = intellisense.suggest(box.Text, box.CursorPosition, currentDoc.langId, 6)
			currentSuggestions = items
			suggestSpanStart, suggestSpanEnd = sIdx, eIdx
			if #items == 0 then
				suggestCard.Visible = false
				return
			end

			suggestCard:ClearAllChildren()
			P.pad(suggestCard, 4, 4, 4, 4)
			P.list(suggestCard, Enum.FillDirection.Vertical, 1)
			suggestCard.Size = UDim2.fromOffset(300, #items * 23 + 10)

			local lh = theme.sizes.editorLineHeight
			local curLine = currentDoc.view.line or 1
			local relY = util.clamp(10 + curLine * lh - scroll.CanvasPosition.Y, 28, math.max(30, codeSurface.AbsoluteSize.Y - 160))
			suggestCard.Position = UDim2.fromOffset(gutterW + 24, relY)
			suggestCard.Visible = true

			for idx, sug in ipairs(items) do
				local row = P.button(suggestCard, {
					name = "Suggest_" .. tostring(idx),
					size = UDim2.new(1, 0, 0, 22),
					bg = idx == 1 and theme.color.listActive or nil,
					hoverBg = theme.color.listActive,
					text = "",
					radius = 3,
					order = idx,
					zIndex = 46,
					onClick = function() acceptSuggestion(sug) end,
				})
				P.label(row, {
					size = UDim2.new(1, -90, 1, 0),
					pos = UDim2.fromOffset(6, 0),
					text = sug.label,
					mono = true,
					textSize = 12,
					color = theme.color.tabActiveText,
					truncate = true,
					zIndex = 47,
				})
				P.label(row, {
					size = UDim2.fromOffset(82, 22),
					pos = UDim2.new(1, -86, 0, 0),
					text = sug.detail,
					textSize = 10,
					color = theme.color.muted,
					alignX = Enum.TextXAlignment.Right,
					zIndex = 47,
				})
			end
		end

		local function mountDoc(doc)
			currentDoc = doc
			suggestCard.Visible = false
			if not doc then
				codeSurface.Visible = false
				diffViewer.root.Visible = false
				welcome.root.Visible = true
				welcome.refresh()
				return
			end
			if doc.isDiff then
				welcome.root.Visible = false
				codeSurface.Visible = false
				diffViewer.root.Visible = true
				diffViewer.render(doc)
				return
			end

			welcome.root.Visible = false
			diffViewer.root.Visible = false
			codeSurface.Visible = true

			box.TextEditable = not doc.readOnly
			if box.Text ~= doc.content then
				syncingText = true
				box.Text = doc.content
				syncingText = false
			end
			lexCache = codeLexer.scan(doc.content, doc.langId, lexCache)
			minimap.updateSource(lexCache)
			debouncedDiag.call()
			updateLayoutWidths()
			drawVisibleLines()
			if doc.view.scrollY then
				scroll.CanvasPosition = Vector2.new(doc.view.scrollX or 0, doc.view.scrollY or 0)
			end
		end

		box.Focused:Connect(function()
			isFocused = true
			codeStore.focusedPane = pane
			drawVisibleLines()
		end)

		box.FocusLost:Connect(function()
			isFocused = false
			task.delay(0.15, function()
				if not isFocused then suggestCard.Visible = false end
			end)
			drawVisibleLines()
		end)

		box:GetPropertyChangedSignal("Text"):Connect(function()
			if syncingText or not currentDoc or currentDoc.readOnly then return end
			local raw = box.Text
			if raw:find("\t", 1, true) and config.get("editor.insertSpaces", true) then
				-- Keep literal tabs in existing files unless typed at cursor, handled cleanly
			end
			codeStore.updateContent(currentDoc.id, raw)
			lexCache = codeLexer.scan(currentDoc.content, currentDoc.langId, lexCache)
			minimap.updateSource(lexCache)
			codeStore.setCursor(currentDoc.id, box.CursorPosition, box.SelectionStart)
			debouncedDiag.call()
			drawVisibleLines()
			refreshIntelliSense()
		end)

		box:GetPropertyChangedSignal("CursorPosition"):Connect(function()
			if syncingText or not currentDoc then return end
			codeStore.setCursor(currentDoc.id, box.CursorPosition, box.SelectionStart)
			drawVisibleLines()
		end)

		box:GetPropertyChangedSignal("SelectionStart"):Connect(function()
			if syncingText or not currentDoc then return end
			drawVisibleLines()
		end)

		scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			if currentDoc then
				currentDoc.view.scrollX = scroll.CanvasPosition.X
				currentDoc.view.scrollY = scroll.CanvasPosition.Y
			end
			drawVisibleLines()
		end)

		-- Find & Replace handlers
		local function runFind()
			if not currentDoc then return end
			findMatches = codeSearch.findInText(currentDoc.content, findInput.Text, {})
			if #findMatches == 0 then
				findIndex = 0
				matchCounter.Text = "0/0"
			else
				findIndex = ((findIndex) % #findMatches) + 1
				matchCounter.Text = string.format("%d/%d", findIndex, #findMatches)
				local hit = findMatches[findIndex]
				codeStore.jumpToLine(currentDoc.id, hit.line, hit.col)
			end
		end

		findInput:GetPropertyChangedSignal("Text"):Connect(function()
			findIndex = 0
			runFind()
		end)
		findNextBtn.Activated:Connect(runFind)

		replaceOneBtn.Activated:Connect(function()
			if not currentDoc or findInput.Text == "" then return end
			local updated, count = codeSearch.replaceInText(currentDoc.content, findInput.Text, replaceInput.Text, {
				singleIndex = math.max(1, findIndex),
			})
			if count > 0 then
				codeStore.updateContent(currentDoc.id, updated)
				mountDoc(currentDoc)
				runFind()
			end
		end)

		replaceAllBtn.Activated:Connect(function()
			if not currentDoc or findInput.Text == "" then return end
			local updated, count = codeSearch.replaceInText(currentDoc.content, findInput.Text, replaceInput.Text, {})
			if count > 0 then
				codeStore.updateContent(currentDoc.id, updated)
				mountDoc(currentDoc)
				runFind()
			end
		end)

		codeStore.changed:connect(function()
			mountDoc(codeStore.active(pane))
		end)
		diagnostics.changed:connect(function(docId)
			if currentDoc and currentDoc.id == docId then
				drawVisibleLines()
			end
		end)
		config.changed:connect(function()
			updateLayoutWidths()
			drawVisibleLines()
		end)
		theme.changed:connect(function()
			container.BackgroundColor3 = theme.color.editor
			codeSurface.BackgroundColor3 = theme.color.editor
			scroll.BackgroundColor3 = theme.color.editor
			gutter.BackgroundColor3 = theme.color.editorGutter
			gutterBorder.BackgroundColor3 = theme.color.border
			findCard.BackgroundColor3 = theme.color.sideBar
			suggestCard.BackgroundColor3 = theme.color.dropdownBg
			drawVisibleLines()
		end)

		mountDoc(codeStore.active(pane))

		return {
			root = container,
			box = box,
			openFind = function(showReplace)
				findCard.Visible = true
				findCard.Size = UDim2.fromOffset(336, showReplace and 68 or 36)
				replaceInput.Parent.Visible = showReplace == true
				replaceOneBtn.Visible = showReplace == true
				replaceAllBtn.Visible = showReplace == true
				task.defer(function() pcall(function() findInput:CaptureFocus() end) end)
			end,
			acceptTopSuggestion = function()
				if suggestCard.Visible and currentSuggestions[1] then
					acceptSuggestion(currentSuggestions[1])
					return true
				end
				return false
			end,
			refresh = function()
				mountDoc(codeStore.active(pane))
			end,
			setTransparency = function(bgTrans)
				gutter.BackgroundTransparency = bgTrans
				activeLineHighlight.BackgroundTransparency = math.min(0.92, bgTrans + 0.25)
			end,
		}
	end

	return M
end
