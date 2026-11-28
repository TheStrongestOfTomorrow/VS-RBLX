-- Full VS Code Monaco-Style Multi-Language Editor (`src/ui/code/editor.lua`):
-- Gutter, Active Line, Indent Guides, Rainbow Brackets, Sticky Scroll Scope Header,
-- Inline Error Squiggles & Error Lens, Inline Color Swatches + HSV Color Picker,
-- Smart Auto-Closing Pairs & Auto-Indent, Inline Find/Replace, IntelliSense, Minimap & Diff.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local minimapMod = env.require("ui/code/minimap")
	local diffViewMod = env.require("ui/code/diff_view")
	local welcomeMod = env.require("ui/code/welcome")
	local colorPickerMod = env.require("ui/code/color_picker")
	local util = env.require("runtime/util")
	local config = env.require("runtime/config")
	local clock = env.require("runtime/clock")
	local codeStore = env.require("runtime/code_store")
	local codeLexer = env.require("runtime/code_lexer")
	local codeFolding = env.require("runtime/code_folding")
	local codeSearch = env.require("runtime/code_search")
	local colorUtils = env.require("runtime/color_utils")
	local editorActions = env.require("runtime/editor_actions")
	local clipboard = env.require("runtime/clipboard")
	local codeDiff = env.require("runtime/code_diff")
	local gitState = env.require("runtime/git_state")
	local intellisense = env.require("runtime/intellisense")
	local diagnostics = env.require("runtime/diagnostics")

	local M = {}

	function M.new(parent, paneName)
		local pane = paneName or "primary"
		local gutterW = 54

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

		-- Sticky Scroll Pinned Scope Header (`editor.stickyScroll`)
		local stickyBar = P.button(codeSurface, {
			name = "StickyScrollBar",
			size = UDim2.new(1, -72, 0, 22),
			pos = UDim2.fromOffset(0, 0),
			bg = theme.color.sideBarHeader,
			hoverBg = theme.color.hover,
			text = "",
			visible = false,
			zIndex = 32,
		})
		local stickyBottomBorder = P.frame(stickyBar, {
			size = UDim2.new(1, 0, 0, 1),
			pos = UDim2.new(0, 0, 1, -1),
			bg = theme.color.border,
			zIndex = 33,
		})
		local stickyLineNum = P.label(stickyBar, {
			name = "StickyLineNum",
			size = UDim2.fromOffset(gutterW - 10, 22),
			pos = UDim2.fromOffset(4, 0),
			mono = true,
			textSize = 11,
			color = theme.color.muted,
			alignX = Enum.TextXAlignment.Right,
			zIndex = 33,
		})
		local stickyCodeLbl = P.label(stickyBar, {
			name = "StickyScopeLabel",
			size = UDim2.new(1, -(gutterW + 16), 1, 0),
			pos = UDim2.fromOffset(gutterW + 8, 0),
			mono = true,
			rich = true,
			textSize = 12,
			color = theme.color.editorText,
			truncate = true,
			zIndex = 33,
		})
		local stickyTargetLine = 1

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

		local guidesLayer = P.frame(scroll, {
			name = "IndentGuidesLayer",
			size = UDim2.new(1, -gutterW, 1, 0),
			pos = UDim2.fromOffset(gutterW + 8, 6),
			zIndex = 15,
		})

		local presentationLayer = P.frame(scroll, {
			name = "SyntaxLayer",
			size = UDim2.new(1, -gutterW, 1, 0),
			pos = UDim2.fromOffset(gutterW + 8, 6),
			zIndex = 16,
		})

		local swatchLayer = P.frame(scroll, {
			name = "ColorSwatchLayer",
			size = UDim2.new(0, gutterW, 1, 0),
			pos = UDim2.fromOffset(0, 0),
			zIndex = 19,
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

		-- Visual HSV Color Picker
		local colorPicker = colorPickerMod.new(codeSurface)

		-- Inline Find & Replace Bar (`Ctrl+F` / `Ctrl+H`)
		local findCard = P.frame(codeSurface, {
			name = "FindReplaceWidget",
			size = UDim2.fromOffset(336, 68),
			pos = UDim2.new(1, -418, 0, 26),
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
		local findNextBtn = P.button(findCard, {
			name = "FindNextBtn",
			size = UDim2.fromOffset(24, 24),
			pos = UDim2.fromOffset(240, 0),
			text = "↓",
			radius = 3,
			zIndex = 41,
		})
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

		-- Parameter Signature Help Floating Pill (`SignatureHelpCard`)
		local sigHelpCard = P.frame(codeSurface, {
			name = "SignatureHelpCard",
			size = UDim2.fromOffset(380, 44),
			pos = UDim2.fromOffset(70, 8),
			bg = theme.color.dropdownBg,
			radius = 5,
			border = theme.color.border,
			visible = false,
			active = true,
			zIndex = 48,
		})
		P.pad(sigHelpCard, 4, 8, 4, 8)
		local sigHelpLbl = P.label(sigHelpCard, {
			name = "SignatureHelpLabel",
			size = UDim2.new(1, 0, 0, 18),
			mono = true,
			rich = true,
			textSize = 11,
			color = theme.color.tabActiveText,
			truncate = true,
			zIndex = 49,
		})
		local sigHelpDoc = P.label(sigHelpCard, {
			name = "SignatureHelpDoc",
			size = UDim2.new(1, 0, 0, 16),
			pos = UDim2.fromOffset(0, 19),
			textSize = 10,
			color = theme.color.muted,
			truncate = true,
			zIndex = 49,
		})

		-- Hover Documentation Card (`HoverDocCard` — `Ctrl+K` / `F1` / `editor.showHover`)
		local hoverCard = P.frame(codeSurface, {
			name = "HoverDocCard",
			size = UDim2.fromOffset(390, 96),
			pos = UDim2.fromOffset(72, 28),
			bg = theme.color.dropdownBg,
			radius = 6,
			border = theme.color.accent,
			visible = false,
			active = true,
			zIndex = 50,
		})
		P.pad(hoverCard, 6, 10, 6, 10)
		local hoverTitleLbl = P.label(hoverCard, {
			name = "HoverTitle",
			size = UDim2.new(1, -110, 0, 18),
			bold = true,
			textSize = 12,
			color = theme.color.tabActiveText,
			truncate = true,
			zIndex = 51,
		})
		local hoverDefTarget = nil
		local hoverGotoBtn = P.button(hoverCard, {
			name = "HoverGotoDefBtn",
			size = UDim2.fromOffset(78, 18),
			pos = UDim2.new(1, -104, 0, 0),
			bg = theme.color.accent,
			hoverBg = theme.color.accentHover,
			color = Color3.fromRGB(255, 255, 255),
			bold = true,
			text = "Go to Def ↗",
			textSize = 10,
			radius = 3,
			visible = false,
			zIndex = 52,
			onClick = function()
				hoverCard.Visible = false
				if hoverDefTarget and hoverDefTarget.file then
					local opened = codeStore.openFile(hoverDefTarget.file)
					if opened and hoverDefTarget.line then
						codeStore.jumpToLine(opened.id, hoverDefTarget.line, 1)
					end
				elseif hoverDefTarget and hoverDefTarget.line and currentDoc then
					codeStore.jumpToLine(currentDoc.id, hoverDefTarget.line, 1)
				end
			end,
		})
		P.button(hoverCard, {
			name = "HoverCloseBtn",
			size = UDim2.fromOffset(20, 18),
			pos = UDim2.new(1, -20, 0, 0),
			text = "✕",
			textSize = 10,
			radius = 3,
			zIndex = 52,
			onClick = function() hoverCard.Visible = false end,
		})
		local hoverSigLbl = P.label(hoverCard, {
			name = "HoverSig",
			size = UDim2.new(1, 0, 0, 20),
			pos = UDim2.fromOffset(0, 20),
			mono = true,
			textSize = 11,
			color = theme.color.accent,
			truncate = true,
			zIndex = 51,
		})
		local hoverDocLbl = P.label(hoverCard, {
			name = "HoverDoc",
			size = UDim2.new(1, 0, 0, 38),
			pos = UDim2.fromOffset(0, 42),
			wrap = true,
			textSize = 11,
			color = theme.color.editorText,
			alignY = Enum.TextYAlignment.Top,
			zIndex = 51,
		})

		-- LSP IntelliSense popup (`IntelliSensePopup`)
		local suggestCard = P.frame(codeSurface, {
			name = "IntelliSensePopup",
			size = UDim2.fromOffset(340, 170),
			pos = UDim2.fromOffset(70, 44),
			bg = theme.color.dropdownBg,
			radius = 5,
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
		local foldRegions = {}
		local docSymbols = {}
		local syncingText = false
		local isFocused = false
		local linePool = {}
		local numPool = {}
		local diagDotPool = {}
		local gitBarPool = {}
		local squigglePool = {}
		local errorLensPool = {}
		local guidePool = {}
		local swatchPool = {}
		local gitLineMarkers = {}
		local findMatches = {}
		local findIndex = 0
		local currentSuggestions = {}
		local selectedSuggestIdx = 1
		local suggestSpanStart, suggestSpanEnd = 1, 0

		stickyBar.Activated:Connect(function()
			if currentDoc and stickyTargetLine >= 1 then
				codeStore.jumpToLine(currentDoc.id, stickyTargetLine, 1)
			end
		end)

		local debouncedDiag = clock.debounce(0.3, function()
			if currentDoc then
				diagnostics.check(currentDoc)
			end
		end)

		local function updateSymbolsAndRegions()
			if not currentDoc then
				foldRegions = {}
				docSymbols = {}
				gitLineMarkers = {}
				return
			end
			foldRegions = codeFolding.regions(currentDoc.content)
			docSymbols = codeFolding.symbols(currentDoc.content, currentDoc.langId)
			if currentDoc.path ~= "" and config.get("git.gutterDecorations", true) ~= false then
				local base = gitState.originalContent(currentDoc.path)
				if base ~= nil then
					gitLineMarkers = codeDiff.lineMarkers(base, currentDoc.content)
				else
					gitLineMarkers = {}
				end
			else
				gitLineMarkers = {}
			end
		end

		local function updateLayoutWidths()
			local showMini = config.get("editor.minimap", true) == true
			minimap.root.Visible = showMini
			local rightInset = showMini and -minimap.width or 0
			scroll.Size = UDim2.new(1, rightInset, 1, 0)
			stickyBar.Size = UDim2.new(1, rightInset, 0, 22)
			gutter.Visible = config.get("editor.lineNumbers", true) ~= false
			local effGutter = gutter.Visible and gutterW or 8
			guidesLayer.Position = UDim2.fromOffset(effGutter + 8, 6)
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
					size = UDim2.fromOffset(gutterW - 18, theme.sizes.editorLineHeight),
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
				squigglePool[slot] = P.frame(presentationLayer, {
					name = "DiagUnderline_" .. tostring(slot),
					size = UDim2.fromOffset(80, 2),
					bg = theme.color.bad,
					radius = 1,
					visible = false,
					zIndex = 18,
				})
				errorLensPool[slot] = P.label(presentationLayer, {
					name = "ErrorLens_" .. tostring(slot),
					size = UDim2.fromOffset(320, theme.sizes.editorLineHeight),
					mono = true,
					textSize = 11,
					color = theme.color.bad,
					truncate = true,
					visible = false,
					zIndex = 17,
				})
				gitBarPool[slot] = P.frame(gutter, {
					name = "GitDiffBar_" .. tostring(slot),
					size = UDim2.fromOffset(3, theme.sizes.editorLineHeight),
					bg = theme.color.good,
					visible = false,
					zIndex = 19,
				})
			end
			return linePool[slot], numPool[slot], diagDotPool[slot], squigglePool[slot], errorLensPool[slot], gitBarPool[slot]
		end

		local function ensureGuideWidget(idx)
			if not guidePool[idx] then
				guidePool[idx] = P.frame(guidesLayer, {
					name = "IndentGuide_" .. tostring(idx),
					size = UDim2.fromOffset(1, 20),
					bg = theme.color.border,
					transparency = 0.45,
					visible = false,
					zIndex = 15,
				})
			end
			return guidePool[idx]
		end

		local function ensureSwatchWidget(idx)
			if not swatchPool[idx] then
				local btn = P.button(swatchLayer, {
					name = "ColorSwatch_" .. tostring(idx),
					size = UDim2.fromOffset(11, 11),
					bg = Color3.fromRGB(255, 255, 255),
					hoverBg = Color3.fromRGB(255, 255, 255),
					text = "",
					radius = 2,
					border = Color3.fromRGB(255, 255, 255),
					visible = false,
					zIndex = 22,
				})
				btn.BackgroundTransparency = 0
				swatchPool[idx] = { btn = btn, spec = nil, line = 1, yPx = 0 }
				btn.Activated:Connect(function()
					local entry = swatchPool[idx]
					if not entry or not entry.spec or not currentDoc or currentDoc.readOnly then return end
					local targetDocId = currentDoc.id
					local targetLine = entry.line
					local pickerSpec = {
						r = entry.spec.r,
						g = entry.spec.g,
						b = entry.spec.b,
						first = entry.spec.first,
						last = entry.spec.last,
						format = entry.spec.format,
						alphaTail = entry.spec.alphaTail,
					}
					pickerSpec.onApply = function(newLiteral, _r, _g, _b, prevLast)
						local liveDoc = codeStore.get(targetDocId)
						if not liveDoc then return end
						local updated = colorUtils.replaceColorOnLine(
							liveDoc.content,
							targetLine,
							pickerSpec.first,
							prevLast or pickerSpec.last,
							newLiteral
						)
						codeStore.updateContent(targetDocId, updated)
					end
					local relY = math.max(26, entry.yPx - scroll.CanvasPosition.Y)
					colorPicker.open(pickerSpec, gutterW + 16, relY)
				end)
			end
			return swatchPool[idx]
		end

		local function indentSpacesOf(lineStr, tabSz)
			local count = 0
			for i = 1, #lineStr do
				local c = lineStr:sub(i, i)
				if c == " " then
					count = count + 1
				elseif c == "\t" then
					count = count + tabSz
				else
					break
				end
			end
			return count
		end

		local function drawVisibleLines()
			if not currentDoc or not lexCache then return end
			local lh = theme.sizes.editorLineHeight
			local fontSz = theme.sizes.editorFont
			local tabSz = tonumber(config.get("editor.tabSize", 4)) or 4
			local useRainbow = config.get("editor.bracketPairColorization", true) ~= false
			local showGuides = config.get("editor.indentGuides", true) ~= false
			local showSticky = config.get("editor.stickyScroll", true) ~= false
			local showErrorLens = config.get("editor.inlineErrorLens", true) ~= false

			box.Font = theme.font.mono
			box.TextSize = fontSz
			box.LineHeight = lh / math.max(1, fontSz)
			box.TextWrapped = config.get("editor.wordWrap", false) == true

			local totalLines = #lexCache.lines
			local maxChars = 40
			for i = 1, totalLines do
				if #lexCache.lines[i] > maxChars then maxChars = #lexCache.lines[i] end
			end
			local charPx = math.max(6, math.floor(fontSz * 0.6 + 0.5))
			local contentW = math.max(scroll.AbsoluteSize.X, gutterW + maxChars * charPx + 120)
			local contentH = math.max(scroll.AbsoluteSize.Y, totalLines * lh + 64)

			scroll.CanvasSize = UDim2.fromOffset(contentW, contentH)
			box.Size = UDim2.fromOffset(contentW - gutterW - 12, contentH - 12)
			gutter.Size = UDim2.fromOffset(gutterW, contentH)
			swatchLayer.Size = UDim2.fromOffset(gutterW, contentH)
			guidesLayer.Size = UDim2.fromOffset(contentW - gutterW - 12, contentH - 12)
			presentationLayer.Size = UDim2.fromOffset(contentW - gutterW - 12, contentH - 12)

			local scrollY = scroll.CanvasPosition.Y
			local topScrolledLine = math.floor(scrollY / lh) + 1
			local viewH = math.max(240, scroll.AbsoluteSize.Y)
			local firstVisible = math.max(1, topScrolledLine - 2)
			local lastVisible = math.min(totalLines, firstVisible + math.ceil(viewH / lh) + 6)

			-- Sticky Scroll Calculation
			local activeScopeSym = nil
			if showSticky and topScrolledLine > 1 and #docSymbols > 0 then
				for _, sym in ipairs(docSymbols) do
					if sym.line < topScrolledLine then
						local regionEnd = foldRegions[sym.line] or (sym.line + 40)
						if topScrolledLine <= regionEnd then
							activeScopeSym = sym
						end
					else
						break
					end
				end
			end
			if activeScopeSym and lexCache.lines[activeScopeSym.line] then
				stickyTargetLine = activeScopeSym.line
				stickyLineNum.Text = tostring(activeScopeSym.line)
				stickyCodeLbl.Text = codeLexer.rich(
					util.trim(lexCache.lines[activeScopeSym.line]),
					lexCache.spans[activeScopeSym.line],
					theme.syntax,
					{ rainbow = useRainbow }
				)
				stickyBar.Visible = true
			else
				stickyBar.Visible = false
			end

			local diagMap = {}
			for _, d in ipairs(diagnostics.byDoc[currentDoc.id] or {}) do
				if not diagMap[d.line] or d.severity == "error" then
					diagMap[d.line] = d
				end
			end

			local curLine = currentDoc.view.line or 1
			local curLineIndentLevels = math.floor(indentSpacesOf(lexCache.lines[curLine] or "", tabSz) / tabSz)

			activeLineHighlight.Visible = config.get("editor.renderActiveLine", true) ~= false
			activeLineHighlight.Position = UDim2.fromOffset(0, 6 + (curLine - 1) * lh)
			activeLineHighlight.Size = UDim2.fromOffset(contentW, lh)
			activeLineHighlight.BackgroundColor3 = theme.color.activeLine

			local hasSelection = isFocused and box.SelectionStart > 0 and box.CursorPosition > 0 and box.SelectionStart ~= box.CursorPosition
			box.TextTransparency = hasSelection and 0 or 1
			box.TextColor3 = theme.color.editorText

			local slot = 0
			local guideCount = 0
			local swatchCount = 0
			local lastNonBlankLevels = 0

			for ln = firstVisible, lastVisible do
				slot = slot + 1
				local lineStr = lexCache.lines[ln] or ""
				local codeLbl, numLbl, dot, squiggle, errLens, gitBar = ensureRowWidgets(slot)
				codeLbl.Visible = not hasSelection
				codeLbl.Position = UDim2.fromOffset(0, (ln - 1) * lh)
				codeLbl.Size = UDim2.fromOffset(contentW - gutterW - 16, lh)
				codeLbl.TextSize = fontSz
				codeLbl.TextColor3 = theme.color.editorText
				codeLbl.Text = codeLexer.rich(lineStr, lexCache.spans[ln], theme.syntax, { rainbow = useRainbow })

				numLbl.Visible = true
				numLbl.Position = UDim2.fromOffset(4, 6 + (ln - 1) * lh)
				numLbl.Size = UDim2.fromOffset(gutterW - 20, lh)
				numLbl.TextSize = math.max(11, fontSz - 1)
				numLbl.Text = tostring(ln)
				numLbl.TextColor3 = (ln == curLine) and theme.color.lineNumberActive or theme.color.lineNumber

				-- Live Git Gutter Diff Bar (green = add, blue = modify, red = delete)
				local gKind = gitLineMarkers[ln]
				if gKind then
					gitBar.Visible = true
					if gKind == "add" then
						gitBar.BackgroundColor3 = theme.color.good
						gitBar.Position = UDim2.fromOffset(gutterW - 4, 6 + (ln - 1) * lh + 1)
						gitBar.Size = UDim2.fromOffset(3, lh - 2)
					elseif gKind == "modify" then
						gitBar.BackgroundColor3 = theme.color.accent
						gitBar.Position = UDim2.fromOffset(gutterW - 4, 6 + (ln - 1) * lh + 1)
						gitBar.Size = UDim2.fromOffset(3, lh - 2)
					else
						gitBar.BackgroundColor3 = theme.color.bad
						gitBar.Position = UDim2.fromOffset(gutterW - 6, 6 + (ln - 1) * lh + lh - 4)
						gitBar.Size = UDim2.fromOffset(5, 4)
					end
				else
					gitBar.Visible = false
				end

				-- Vertical Indent Guides
				if showGuides then
					local levels = 0
					if lineStr:find("%S") then
						levels = math.floor(indentSpacesOf(lineStr, tabSz) / tabSz)
						lastNonBlankLevels = levels
					else
						levels = lastNonBlankLevels
					end
					for lv = 1, math.min(levels, 8) do
						guideCount = guideCount + 1
						local gBar = ensureGuideWidget(guideCount)
						local gx = (lv - 1) * tabSz * charPx
						local isActiveGuide = (lv == curLineIndentLevels)
						gBar.Position = UDim2.fromOffset(gx, (ln - 1) * lh)
						gBar.Size = UDim2.fromOffset(1, lh)
						gBar.BackgroundColor3 = isActiveGuide and theme.color.muted or theme.color.border
						gBar.BackgroundTransparency = isActiveGuide and 0.25 or 0.58
						gBar.Visible = true
					end
				end

				-- Inline Color Swatch Detection
				local colorsFound = colorUtils.findColorsInLine(lineStr)
				if #colorsFound > 0 then
					swatchCount = swatchCount + 1
					local sw = ensureSwatchWidget(swatchCount)
					local firstColor = colorsFound[1]
					local yPos = 6 + (ln - 1) * lh + math.floor((lh - 11) / 2)
					sw.spec = firstColor
					sw.line = ln
					sw.yPx = yPos
					sw.btn.BackgroundColor3 = firstColor.color3
					sw.btn.Position = UDim2.fromOffset(gutterW - 14, yPos)
					sw.btn.Visible = true
				end

				-- Diagnostics Gutter Dot + Inline Squiggle Underline + Error Lens
				local diagItem = diagMap[ln]
				if diagItem then
					local isErr = (diagItem.severity == "error")
					local sevCol = isErr and theme.color.bad or theme.color.warn
					dot.Visible = true
					dot.Position = UDim2.fromOffset(3, 6 + (ln - 1) * lh + math.floor((lh - 5) / 2))
					dot.BackgroundColor3 = sevCol

					if showErrorLens and not hasSelection then
						local leadLen = #(lineStr:match("^(%s*)") or "")
						local trimmedLen = math.max(3, #util.trim(lineStr))
						local underX = leadLen * charPx
						local underW = math.min(360, trimmedLen * charPx)
						squiggle.Position = UDim2.fromOffset(underX, (ln - 1) * lh + lh - 3)
						squiggle.Size = UDim2.fromOffset(underW, 2)
						squiggle.BackgroundColor3 = sevCol
						squiggle.BackgroundTransparency = isErr and 0.08 or 0.22
						squiggle.Visible = true

						errLens.Position = UDim2.fromOffset((#lineStr + 3) * charPx, (ln - 1) * lh)
						errLens.Text = (isErr and "⊗ " or "⚠ ") .. tostring(diagItem.message or "")
						errLens.TextColor3 = sevCol
						errLens.TextTransparency = 0.25
						errLens.Visible = true
					else
						squiggle.Visible = false
						errLens.Visible = false
					end
				else
					dot.Visible = false
					squiggle.Visible = false
					errLens.Visible = false
				end
			end

			for k = slot + 1, #linePool do
				linePool[k].Visible = false
				numPool[k].Visible = false
				diagDotPool[k].Visible = false
				squigglePool[k].Visible = false
				errorLensPool[k].Visible = false
				if gitBarPool[k] then gitBarPool[k].Visible = false end
			end
			for k = guideCount + 1, #guidePool do
				guidePool[k].Visible = false
			end
			for k = swatchCount + 1, #swatchPool do
				swatchPool[k].btn.Visible = false
			end

			-- Update Caret position
			if isFocused and not hasSelection and currentDoc and not currentDoc.readOnly then
				local col = math.max(1, currentDoc.view.col or 1)
				local lineStr = lexCache.lines[curLine] or ""
				local subBefore = lineStr:sub(1, col - 1):gsub("\t", string.rep(" ", tabSz))
				local effGutter = gutter.Visible and gutterW or 8
				local xPx = effGutter + 8 + #subBefore * charPx
				local yPx = 6 + (curLine - 1) * lh
				caretBar.Position = UDim2.fromOffset(xPx, yPx)
				caretBar.Size = UDim2.fromOffset(2, lh)
				caretBar.Visible = true
			else
				caretBar.Visible = false
			end

			minimap.updateViewport(scrollY, viewH, contentH)
		end

		-- The invisible native TextBox owns input, but the highlighted text/caret are
		-- drawn in the outer ScrollingFrame. Keep that visual caret in view as users
		-- type or move with touch/keyboard; native TextBox scrolling alone is not enough.
		local function revealCursor()
			if not isFocused or not currentDoc or currentDoc.readOnly then return end
			local lh = math.max(1, theme.sizes.editorLineHeight)
			local line = math.max(1, currentDoc.view.line or 1)
			local col = math.max(1, currentDoc.view.col or 1)
			local lineText = (lexCache and lexCache.lines[line]) or ""
			local viewSize = scroll.AbsoluteSize
			local canvasSize = scroll.CanvasSize
			local pos = scroll.CanvasPosition
			local viewH = math.max(1, viewSize.Y)
			local viewW = math.max(1, viewSize.X)
			local caretTop = 6 + (line - 1) * lh
			local caretBottom = caretTop + lh
			local stickyInset = stickyBar.Visible and 24 or 4
			local targetY = pos.Y
			if caretTop < pos.Y + stickyInset then
				targetY = caretTop - stickyInset
			elseif caretBottom > pos.Y + viewH - 4 then
				targetY = caretBottom - viewH + 4
			end
			local maxY = math.max(0, canvasSize.Y.Offset - viewH)
			targetY = util.clamp(targetY, 0, maxY)

			local targetX = pos.X
			if not box.TextWrapped then
				local fontSz = theme.sizes.editorFont
				local charPx = math.max(6, math.floor(fontSz * 0.6 + 0.5))
				local tabSz = tonumber(config.get("editor.tabSize", 4)) or 4
				local prefix = lineText:sub(1, col - 1):gsub("\t", string.rep(" ", tabSz))
				local effGutter = gutter.Visible and gutterW or 8
				local caretX = effGutter + 8 + #prefix * charPx
				if caretX < pos.X + effGutter + 8 then
					targetX = caretX - effGutter - 8
				elseif caretX + 2 > pos.X + viewW - 4 then
					targetX = caretX + 6 - viewW
				end
				targetX = util.clamp(targetX, 0, math.max(0, canvasSize.X.Offset - viewW))
			end

			if targetX ~= pos.X or targetY ~= pos.Y then
				scroll.CanvasPosition = Vector2.new(targetX, targetY)
			end
		end

		local function applyEditResult(nextText, nextCursor, nextSel)
			if not currentDoc or currentDoc.readOnly then return false end
			syncingText = true
			box.Text = nextText
			if nextSel and nextSel > 0 then
				box.SelectionStart = nextSel
			else
				box.SelectionStart = -1
			end
			box.CursorPosition = nextCursor or 1
			syncingText = false
			codeStore.updateContent(currentDoc.id, nextText)
			codeStore.setCursor(currentDoc.id, nextCursor or 1, nextSel or -1)
			lexCache = codeLexer.scan(currentDoc.content, currentDoc.langId, lexCache)
			updateSymbolsAndRegions()
			minimap.updateSource(lexCache)
			debouncedDiag.call()
			drawVisibleLines()
			revealCursor()
			return true
		end

		local KIND_BADGES = {
			snippet = { icon = "⇥", col = "func" },
			method = { icon = "ƒ", col = "func" },
			["function"] = { icon = "ƒ", col = "func" },
			constructor = { icon = "▣", col = "type" },
			class = { icon = "▣", col = "type" },
			property = { icon = "◈", col = "number" },
			event = { icon = "⚡", col = "keyword" },
			instance = { icon = "⬡", col = "type" },
			enum = { icon = "∈", col = "number" },
			executor = { icon = "⚙", col = "keyword" },
			module = { icon = "📦", col = "string" },
			variable = { icon = "𝑥", col = "ident" },
			keyword = { icon = "🔑", col = "keyword" },
			builtin = { icon = "λ", col = "func" },
			type = { icon = "𝑇", col = "type" },
			symbol = { icon = "◦", col = "comment" },
		}

		local function acceptSuggestion(item)
			if not currentDoc or not item then return end
			suggestCard.Visible = false
			local src = box.Text
			local before = src:sub(1, suggestSpanStart - 1)
			local after = src:sub(suggestSpanEnd + 1)
			local expanded, caretOffset = intellisense.expandInsert(item.insert)
			local nextText = before .. expanded .. after
			applyEditResult(nextText, #before + caretOffset + 1, -1)
		end

		local function refreshSignatureHelp()
			if not isFocused or not currentDoc or currentDoc.readOnly
				or config.get("editor.intellisense", true) == false then
				sigHelpCard.Visible = false
				return
			end
			local sig = intellisense.signatureHelp(box.Text, box.CursorPosition, currentDoc.langId, currentDoc.path)
			if not sig then
				sigHelpCard.Visible = false
				return
			end
			local escParts = {}
			for i, p in ipairs(sig.params or {}) do
				local ep = util.escapeRichText(p)
				if i == sig.activeParam or (i == #(sig.params or {}) and p:find("^%.%.%.")) then
					escParts[#escParts + 1] = string.format('<font color="#%s"><b>%s</b></font>', theme.color.accent:ToHex(), ep)
				else
					escParts[#escParts + 1] = ep
				end
			end
			sigHelpLbl.Text = string.format(
				"%s(%s) -> %s",
				util.escapeRichText(sig.name),
				table.concat(escParts, ", "),
				util.escapeRichText(sig.ret or "()")
			)
			sigHelpDoc.Text = sig.doc or ""
			local lh = theme.sizes.editorLineHeight
			local curLine = currentDoc.view.line or 1
			local aboveY = math.max(4, 6 + (curLine - 1) * lh - scroll.CanvasPosition.Y - 46)
			sigHelpCard.Position = UDim2.fromOffset(gutterW + 20, aboveY)
			sigHelpCard.Visible = true
		end

		local function renderSuggestionsUI()
			if #currentSuggestions == 0 then
				suggestCard.Visible = false
				return
			end
			selectedSuggestIdx = util.clamp(selectedSuggestIdx, 1, #currentSuggestions)
			suggestCard:ClearAllChildren()
			P.pad(suggestCard, 4, 5, 4, 5)
			P.list(suggestCard, Enum.FillDirection.Vertical, 1)

			local selItem = currentSuggestions[selectedSuggestIdx]
			local hasFooter = selItem and ((selItem.signature and selItem.signature ~= "") or (selItem.doc and selItem.doc ~= ""))
			local footerH = hasFooter and 38 or 0
			suggestCard.Size = UDim2.fromOffset(348, #currentSuggestions * 23 + 10 + footerH)

			local lh = theme.sizes.editorLineHeight
			local curLine = currentDoc.view.line or 1
			local relY = util.clamp(10 + curLine * lh - scroll.CanvasPosition.Y, 28, math.max(30, codeSurface.AbsoluteSize.Y - 210))
			suggestCard.Position = UDim2.fromOffset(gutterW + 24, relY)
			suggestCard.Visible = true

			for idx, sug in ipairs(currentSuggestions) do
				local badge = KIND_BADGES[sug.kind] or KIND_BADGES.symbol
				local row = P.button(suggestCard, {
					name = "Suggest_" .. tostring(idx),
					size = UDim2.new(1, 0, 0, 22),
					bg = idx == selectedSuggestIdx and theme.color.listActive or nil,
					hoverBg = theme.color.listActive,
					text = "",
					radius = 3,
					order = idx,
					zIndex = 46,
					onClick = function() acceptSuggestion(sug) end,
				})
				P.label(row, {
					size = UDim2.fromOffset(18, 22),
					pos = UDim2.fromOffset(4, 0),
					text = badge.icon,
					mono = true,
					bold = true,
					textSize = 11,
					alignX = Enum.TextXAlignment.Center,
					color = theme.syntax[badge.col] or theme.color.accent,
					zIndex = 47,
				})
				P.label(row, {
					size = UDim2.new(1, -120, 1, 0),
					pos = UDim2.fromOffset(24, 0),
					text = sug.label,
					mono = true,
					textSize = 12,
					color = theme.color.tabActiveText,
					truncate = true,
					zIndex = 47,
				})
				P.label(row, {
					size = UDim2.fromOffset(92, 22),
					pos = UDim2.new(1, -96, 0, 0),
					text = sug.detail,
					textSize = 10,
					color = theme.color.muted,
					alignX = Enum.TextXAlignment.Right,
					truncate = true,
					zIndex = 47,
				})
			end

			if hasFooter then
				local docBox = P.frame(suggestCard, {
					name = "SuggestDocFooter",
					size = UDim2.new(1, 0, 0, 36),
					bg = theme.color.sideBar,
					radius = 3,
					order = 99,
					zIndex = 46,
				})
				P.pad(docBox, 3, 6, 3, 6)
				P.label(docBox, {
					name = "SuggestDocSig",
					size = UDim2.new(1, 0, 0, 14),
					mono = true,
					textSize = 10,
					color = theme.color.accent,
					text = (selItem.signature ~= "" and selItem.signature) or selItem.label,
					truncate = true,
					zIndex = 47,
				})
				P.label(docBox, {
					name = "SuggestDocText",
					size = UDim2.new(1, 0, 0, 16),
					pos = UDim2.fromOffset(0, 15),
					textSize = 10,
					color = theme.color.muted,
					text = selItem.doc or "",
					truncate = true,
					zIndex = 47,
				})
			end
		end

		local function refreshIntelliSense(forceOpen)
			if (not forceOpen and not isFocused) or not currentDoc or currentDoc.readOnly
				or config.get("editor.intellisense", true) == false then
				suggestCard.Visible = false
				return
			end
			local curOff = box.CursorPosition > 0 and box.CursorPosition or (currentDoc.view.cursor or 1)
			local items, _, sIdx, eIdx = intellisense.suggest(box.Text, curOff, currentDoc.langId, 7, currentDoc.path)
			currentSuggestions = items
			selectedSuggestIdx = 1
			suggestSpanStart, suggestSpanEnd = sIdx, eIdx
			renderSuggestionsUI()
			refreshSignatureHelp()
		end

		local function showHoverAtCursor()
			if not currentDoc then return nil end
			local curOff = box.CursorPosition > 0 and box.CursorPosition or (currentDoc.view.cursor or 1)
			local info = intellisense.hover(currentDoc.content, curOff, currentDoc.langId, currentDoc.path)
			if not info then
				hoverCard.Visible = false
				return nil
			end
			hoverTitleLbl.Text = string.format("%s  ·  %s", info.title or "", info.kind or "symbol")
			hoverSigLbl.Text = info.signature or ""
			hoverDocLbl.Text = info.doc or ""
			if info.line then
				hoverDefTarget = { file = info.file, line = info.line }
				hoverGotoBtn.Visible = true
			else
				hoverDefTarget = nil
				hoverGotoBtn.Visible = false
			end
			local lh = theme.sizes.editorLineHeight
			local curLine = currentDoc.view.line or 1
			local relY = util.clamp(8 + curLine * lh - scroll.CanvasPosition.Y, 24, math.max(26, codeSurface.AbsoluteSize.Y - 120))
			hoverCard.Position = UDim2.fromOffset(gutterW + 24, relY)
			hoverCard.Visible = true
			return info
		end

		local function gotoDefinitionAtCursor()
			if not currentDoc then return nil end
			local curOff = box.CursorPosition > 0 and box.CursorPosition or (currentDoc.view.cursor or 1)
			local def = intellisense.findDefinition(currentDoc.content, curOff, currentDoc.langId, currentDoc.path)
			if not def then return nil end
			if def.file and def.file ~= "" and def.file ~= currentDoc.path then
				local targetDoc = codeStore.openFile(def.file)
				if targetDoc then
					codeStore.jumpToLine(targetDoc.id, def.line or 1, 1)
				end
			else
				codeStore.jumpToLine(currentDoc.id, def.line or 1, 1)
			end
			return def
		end

		local function mountDoc(doc)
			local switchedDoc = (doc ~= currentDoc)
			currentDoc = doc
			suggestCard.Visible = false
			sigHelpCard.Visible = false
			if switchedDoc then
				hoverCard.Visible = false
				colorPicker.close()
			end
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
				box.CursorPosition = doc.view.cursor or 1
				syncingText = false
			end
			lexCache = codeLexer.scan(doc.content, doc.langId, lexCache)
			updateSymbolsAndRegions()
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
			revealCursor()
		end)

		box.FocusLost:Connect(function()
			isFocused = false
			task.delay(0.15, function()
				if not isFocused then
					suggestCard.Visible = false
					sigHelpCard.Visible = false
				end
			end)
			drawVisibleLines()
		end)

		box:GetPropertyChangedSignal("Text"):Connect(function()
			if syncingText or not currentDoc or currentDoc.readOnly then return end
			local raw = box.Text
			local prev = currentDoc.content
			local smartText, smartCursor = editorActions.applySmartTyping(prev, raw, box.CursorPosition, {
				langId = currentDoc.langId,
				tabSize = config.get("editor.tabSize", 4),
				insertSpaces = config.get("editor.insertSpaces", true),
				autoClosingBrackets = config.get("editor.autoClosingBrackets", true),
				autoIndent = config.get("editor.autoIndent", true),
			})
			if smartText ~= raw then
				syncingText = true
				box.Text = smartText
				box.CursorPosition = smartCursor
				syncingText = false
			end
			codeStore.updateContent(currentDoc.id, smartText)
			lexCache = codeLexer.scan(currentDoc.content, currentDoc.langId, lexCache)
			updateSymbolsAndRegions()
			minimap.updateSource(lexCache)
			codeStore.setCursor(currentDoc.id, box.CursorPosition, box.SelectionStart)
			debouncedDiag.call()
			drawVisibleLines()
			revealCursor()
			refreshIntelliSense()
		end)

		box:GetPropertyChangedSignal("CursorPosition"):Connect(function()
			if syncingText or not currentDoc then return end
			codeStore.setCursor(currentDoc.id, box.CursorPosition, box.SelectionStart)
			drawVisibleLines()
			revealCursor()
			refreshSignatureHelp()
		end)

		box:GetPropertyChangedSignal("SelectionStart"):Connect(function()
			if syncingText or not currentDoc then return end
			-- Capture newly selected text ≥ 3 chars into clipboard ring when copied/selected on Ctrl+C
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

		-- Programmatic & Shortcut-Driven Monaco Actions
		local function runAction(actionName, arg)
			if not currentDoc then return false end
			local cur = box.CursorPosition > 0 and box.CursorPosition or (currentDoc.view.cursor or 1)
			local sel = box.SelectionStart

			if actionName == "selectWord" then
				local s, e, word = editorActions.wordAtCursor(currentDoc.content, cur)
				box.SelectionStart = s
				box.CursorPosition = e
				codeStore.setCursor(currentDoc.id, e, s)
				if word ~= "" then clipboard.push(word) end
				drawVisibleLines()
				return true, word
			elseif actionName == "selectNextOccurrence" then
				local nextCur, nextSel, matched = editorActions.selectNextOccurrence(currentDoc.content, cur, sel)
				box.SelectionStart = nextSel
				box.CursorPosition = nextCur
				codeStore.setCursor(currentDoc.id, nextCur, nextSel)
				drawVisibleLines()
				return true, matched
			elseif actionName == "pasteText" then
				local clipTxt = tostring(arg or clipboard.latest() or "")
				if clipTxt == "" then return false end
				local lo = (sel > 0 and sel ~= cur) and math.min(sel, cur) or cur
				local hi = (sel > 0 and sel ~= cur) and math.max(sel, cur) or cur
				local updated = currentDoc.content:sub(1, lo - 1) .. clipTxt .. currentDoc.content:sub(hi)
				local afterCur = lo + #clipTxt
				codeStore.updateContent(currentDoc.id, updated)
				box.Text = updated
				box.SelectionStart = -1
				box.CursorPosition = afterCur
				codeStore.setCursor(currentDoc.id, afterCur, -1)
				return true, clipTxt
			elseif actionName == "selectLine" then
				local s, e = editorActions.lineBoundsAtCursor(currentDoc.content, cur)
				box.SelectionStart = s
				box.CursorPosition = e
				codeStore.setCursor(currentDoc.id, e, s)
				drawVisibleLines()
				return true
			elseif actionName == "copySelectionOrLine" then
				if sel and sel > 0 and sel ~= cur then
					local a, b = math.min(sel, cur), math.max(sel, cur) - 1
					clipboard.copy(currentDoc.content:sub(a, b))
				else
					local s, e = editorActions.lineBoundsAtCursor(currentDoc.content, cur)
					clipboard.copy(currentDoc.content:sub(s, e - 1))
				end
				return true
			end

			if currentDoc.readOnly then return false end

			if actionName == "toggleComment" then
				local nextText, nextCur = editorActions.toggleComment(currentDoc.content, cur, sel, currentDoc.langId)
				return applyEditResult(nextText, nextCur, -1)
			elseif actionName == "indent" or actionName == "outdent" then
				local nextText, nextCur, nextSel = editorActions.indentBlock(
					currentDoc.content,
					cur,
					sel,
					config.get("editor.tabSize", 4),
					config.get("editor.insertSpaces", true),
					actionName == "outdent"
				)
				return applyEditResult(nextText, nextCur, nextSel)
			elseif actionName == "moveLineUp" or actionName == "moveLineDown" then
				local dir = actionName == "moveLineUp" and -1 or 1
				local nextText, nextCur = editorActions.moveLines(currentDoc.content, cur, sel, dir)
				return applyEditResult(nextText, nextCur, -1)
			elseif actionName == "duplicateLineDown" or actionName == "duplicateLineUp" then
				local dir = actionName == "duplicateLineUp" and -1 or 1
				local nextText, nextCur = editorActions.duplicateLines(currentDoc.content, cur, sel, dir)
				return applyEditResult(nextText, nextCur, -1)
			elseif actionName == "deleteLine" then
				local s, e = editorActions.lineBoundsAtCursor(currentDoc.content, cur)
				clipboard.push(currentDoc.content:sub(s, e - 1))
				local nextText, nextCur = editorActions.deleteLines(currentDoc.content, cur, sel)
				return applyEditResult(nextText, nextCur, -1)
			elseif actionName == "insertText" then
				local insertStr = tostring(arg or "")
				if insertStr == "" then return false end
				local minPos = cur
				local maxPos = cur
				if sel and sel > 0 and sel ~= cur then
					minPos = math.min(sel, cur)
					maxPos = math.max(sel, cur)
				end
				local src = currentDoc.content
				local nextText = src:sub(1, minPos - 1) .. insertStr .. src:sub(maxPos)
				return applyEditResult(nextText, minPos + #insertStr, -1)
			end
			return false
		end

		codeStore.changed:connect(function()
			mountDoc(codeStore.active(pane))
		end)
		diagnostics.changed:connect(function(docId)
			if currentDoc and currentDoc.id == docId then
				drawVisibleLines()
			end
		end)
		gitState.changed:connect(function()
			updateSymbolsAndRegions()
			drawVisibleLines()
		end)
		config.changed:connect(function()
			updateSymbolsAndRegions()
			updateLayoutWidths()
			drawVisibleLines()
		end)
		theme.changed:connect(function()
			gutter.BackgroundColor3 = theme.color.editorGutter
			gutterBorder.BackgroundColor3 = theme.color.border
			stickyBar.BackgroundColor3 = theme.color.sideBarHeader
			stickyBottomBorder.BackgroundColor3 = theme.color.border
			stickyLineNum.TextColor3 = theme.color.muted
			findCard.BackgroundColor3 = theme.color.sideBar
			suggestCard.BackgroundColor3 = theme.color.dropdownBg
			sigHelpCard.BackgroundColor3 = theme.color.dropdownBg
			hoverCard.BackgroundColor3 = theme.color.dropdownBg
			drawVisibleLines()
		end)

		mountDoc(codeStore.active(pane))

		return {
			root = container,
			box = box,
			colorPicker = colorPicker,
			runAction = runAction,
			openFind = function(showReplace)
				findCard.Visible = true
				findCard.Size = UDim2.fromOffset(336, showReplace and 68 or 36)
				replaceInput.Parent.Visible = showReplace == true
				replaceOneBtn.Visible = showReplace == true
				replaceAllBtn.Visible = showReplace == true
				task.defer(function() pcall(function() findInput:CaptureFocus() end) end)
			end,
			triggerSuggest = function()
				refreshIntelliSense(true)
				return currentSuggestions
			end,
			moveSuggestSelection = function(delta)
				if not suggestCard.Visible or #currentSuggestions == 0 then return false end
				local nextIdx = ((selectedSuggestIdx - 1 + (delta or 1)) % #currentSuggestions) + 1
				selectedSuggestIdx = nextIdx
				renderSuggestionsUI()
				return true
			end,
			acceptTopSuggestion = function()
				if suggestCard.Visible and currentSuggestions[selectedSuggestIdx] then
					acceptSuggestion(currentSuggestions[selectedSuggestIdx])
					return true
				end
				return false
			end,
			showHover = showHoverAtCursor,
			gotoDefinition = gotoDefinitionAtCursor,
			refresh = function()
				mountDoc(codeStore.active(pane))
			end,
			setTransparency = function(bgTrans)
				gutter.BackgroundTransparency = bgTrans
				stickyBar.BackgroundTransparency = math.min(0.45, bgTrans * 0.65)
				activeLineHighlight.BackgroundTransparency = math.min(0.92, bgTrans + 0.25)
			end,
		}
	end

	return M
end
