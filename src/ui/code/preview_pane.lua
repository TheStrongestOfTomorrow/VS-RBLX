-- VS Code Live Split Preview Pane (`src/ui/code/preview_pane.lua`):
-- Renders real-time visual previews for previewable languages ONLY:
--   • HTML (+ live workspace `style.css` cascade)
--   • CSS (palette swatches + live selector style cards)
--   • Markdown (GFM headings, RichText, syntax-colored code blocks, tables, tasks)
--   • JSON & YAML/TOML (interactive collapsible tree inspector)
--   • SQL (CREATE / INSERT / SELECT data table grid)
--   • Python / JavaScript / TypeScript (quick-eval output + variable state inspector)
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local overlay = env.require("ui/overlay")
	local util = env.require("runtime/util")
	local config = env.require("runtime/config")
	local languages = env.require("runtime/languages")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")
	local codeLexer = env.require("runtime/code_lexer")
	local previewEngine = env.require("runtime/preview_engine")

	local M = {}

	function M.new(parent, callbacks)
		callbacks = callbacks or {}
		local targetDoc = nil
		local collapsedNodes = {}

		local root = P.frame(parent, {
			name = "LivePreviewPane",
			size = UDim2.new(0.5, 0, 1, 0),
			pos = UDim2.new(0.5, 0, 0, 0),
			bg = theme.color.editor,
			visible = false,
			clip = true,
			zIndex = 14,
		})
		local leftBorder = P.frame(root, {
			size = UDim2.new(0, 1, 1, 0),
			bg = theme.color.border,
			zIndex = 30,
		})

		local header = P.frame(root, {
			name = "PreviewHeader",
			size = UDim2.new(1, 0, 0, theme.sizes.tabBar),
			bg = theme.color.tabBar,
			zIndex = 20,
		})
		local headerRule = P.frame(header, {
			size = UDim2.new(1, 0, 0, 1),
			pos = UDim2.new(0, 0, 1, -1),
			bg = theme.color.border,
			zIndex = 21,
		})

		local titleLbl = P.label(header, {
			name = "PreviewTitleLabel",
			size = UDim2.new(1, -146, 1, 0),
			pos = UDim2.fromOffset(12, 0),
			text = "◫ LIVE PREVIEW",
			bold = true,
			textSize = 11,
			color = theme.color.tabActiveText,
			truncate = true,
			zIndex = 22,
		})

		local btnRow = P.frame(header, {
			size = UDim2.fromOffset(136, theme.sizes.tabBar - 2),
			pos = UDim2.new(1, -140, 0, 1),
			zIndex = 22,
		})
		P.list(btnRow, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

		local renderDoc

		P.button(btnRow, {
			name = "RefreshPreviewBtn",
			size = UDim2.fromOffset(62, 24),
			bg = theme.color.inputBg,
			hoverBg = theme.color.hover,
			text = "↻ Sync",
			textSize = 11,
			radius = 4,
			order = 1,
			zIndex = 23,
			onClick = function()
				if targetDoc then renderDoc(targetDoc) end
			end,
		})

		P.button(btnRow, {
			name = "ClosePreviewBtn",
			size = UDim2.fromOffset(28, 24),
			bg = theme.color.inputBg,
			hoverBg = theme.color.bad,
			text = "✕",
			textSize = 11,
			radius = 4,
			order = 2,
			zIndex = 23,
			onClick = function()
				if callbacks.onClose then callbacks.onClose() end
			end,
		})

		local scroll = P.scroll(root, {
			name = "PreviewScrollSurface",
			size = UDim2.new(1, -1, 1, -theme.sizes.tabBar),
			pos = UDim2.fromOffset(1, theme.sizes.tabBar),
			bg = theme.color.editor,
			zIndex = 16,
		})
		P.pad(scroll, 12, 14, 16, 14)
		P.list(scroll, Enum.FillDirection.Vertical, 8)

		local function resolveWorkspaceFile(relHref, baseDocPath)
			local cleanHref = util.normalisePath(tostring(relHref or ""):gsub("^%./", ""))
			local candidates = { cleanHref }
			if baseDocPath and baseDocPath ~= "" then
				local baseDir = util.dirname(baseDocPath)
				if baseDir ~= "" then
					table.insert(candidates, 1, util.joinPath(baseDir, cleanHref))
				end
			end
			-- Check open buffers first so unsaved live edits in `style.css` reflect immediately!
			for _, cand in ipairs(candidates) do
				local openTab = codeStore.findByPath(cand)
				if openTab then return openTab.content end
			end
			for _, tab in ipairs(codeStore.tabs) do
				if util.basename(tab.path) == util.basename(cleanHref) and tab.langId == "css" then
					return tab.content
				end
			end
			for _, cand in ipairs(candidates) do
				local diskBody = workspaceFs.readFile(cand)
				if type(diskBody) == "string" then return diskBody end
			end
			return nil
		end

		local function renderHtml(doc)
			local parsed = previewEngine.parseHtml(doc.content, function(href)
				return resolveWorkspaceFile(href, doc.path)
			end)
			local sheetInfo = #parsed.linkedSheets > 0 and (" + " .. table.concat(parsed.linkedSheets, ", ")) or ""
			titleLbl.Text = string.format("◫ PREVIEW: %s%s", doc.title, sheetInfo)

			local canvasBg = (parsed.bodyStyle and parsed.bodyStyle.bg) or Color3.fromRGB(248, 250, 252)
			local defaultTxtCol = (parsed.bodyStyle and parsed.bodyStyle.color) or Color3.fromRGB(24, 28, 36)

			local browserCard = P.frame(scroll, {
				name = "HtmlPreviewSurface",
				size = UDim2.new(1, 0, 0, 0),
				bg = canvasBg,
				radius = 6,
				border = theme.color.border,
				order = 1,
				zIndex = 17,
			})
			browserCard.AutomaticSize = Enum.AutomaticSize.Y
			P.pad(browserCard, 12, 14, 14, 14)
			P.list(browserCard, Enum.FillDirection.Vertical, 8)

			-- Simulated browser address bar
			local urlBar = P.frame(browserCard, {
				size = UDim2.new(1, 0, 0, 24),
				bg = Color3.fromRGB(30, 34, 42),
				radius = 4,
				order = 0,
				zIndex = 18,
			})
			P.label(urlBar, {
				size = UDim2.new(1, -16, 1, 0),
				pos = UDim2.fromOffset(8, 0),
				mono = true,
				textSize = 11,
				color = Color3.fromRGB(190, 205, 230),
				text = string.format("🌐 %s  —  local://%s%s", parsed.title, doc.path ~= "" and doc.path or doc.title, sheetInfo),
				truncate = true,
				zIndex = 19,
			})

			for idx, node in ipairs(parsed.nodes) do
				local st = node.style or {}
				local txtCol = st.color or defaultTxtCol
				local alignX = Enum.TextXAlignment.Left
				if st.align == "center" then alignX = Enum.TextXAlignment.Center
				elseif st.align == "right" then alignX = Enum.TextXAlignment.Right end

				if node.tag == "hr" then
					P.frame(browserCard, {
						size = UDim2.new(1, 0, 0, 1),
						bg = Color3.fromRGB(203, 213, 225),
						order = idx,
						zIndex = 18,
					})
				elseif node.tag == "h1" or node.tag == "h2" or node.tag == "h3" or node.tag == "h4" then
					local sizes = { h1 = 22, h2 = 18, h3 = 15, h4 = 13 }
					local lbl = P.label(browserCard, {
						name = "HtmlHeading_" .. tostring(idx),
						size = UDim2.new(1, 0, 0, (st.fontSize or sizes[node.tag]) + 8),
						text = node.text,
						bold = true,
						textSize = st.fontSize or sizes[node.tag],
						color = txtCol,
						alignX = alignX,
						wrap = true,
						order = idx,
						zIndex = 18,
					})
					if st.bg then
						lbl.BackgroundTransparency = 0
						lbl.BackgroundColor3 = st.bg
					end
				elseif node.tag == "button" then
					local btnBg = st.bg or Color3.fromRGB(37, 99, 235)
					local btnCol = st.color or Color3.fromRGB(255, 255, 255)
					local b = P.button(browserCard, {
						name = "HtmlButton_" .. tostring(idx),
						size = UDim2.fromOffset(math.max(96, #node.text * 8 + 28), 32),
						bg = btnBg,
						hoverBg = btnBg:Lerp(Color3.fromRGB(255, 255, 255), 0.14),
						color = btnCol,
						bold = true,
						text = node.text ~= "" and node.text or "Button",
						textSize = st.fontSize or 13,
						radius = st.radius or 6,
						order = idx,
						zIndex = 18,
						onClick = function()
							overlay.toast("HTML <button> clicked: " .. tostring(node.text), "info", 1.8)
						end,
					})
					b.BackgroundTransparency = 0
				elseif node.tag == "input" then
					P.input(browserCard, {
						name = "HtmlInput_" .. tostring(idx),
						size = UDim2.new(0.75, 0, 0, 30),
						bg = st.bg or Color3.fromRGB(255, 255, 255),
						color = st.color or Color3.fromRGB(20, 24, 32),
						placeholder = node.text,
						order = idx,
						zIndex = 18,
					})
				elseif node.tag == "card" or node.tag == "banner" then
					local card = P.frame(browserCard, {
						name = "HtmlCard_" .. tostring(idx),
						size = UDim2.new(1, 0, 0, 0),
						bg = st.bg or canvasBg:Lerp(Color3.fromRGB(128, 128, 128), 0.12),
						radius = st.radius or 6,
						border = st.borderColor,
						order = idx,
						zIndex = 18,
					})
					card.AutomaticSize = Enum.AutomaticSize.Y
					local padPx = util.clamp(st.padding or 10, 4, 28)
					P.pad(card, padPx, padPx, padPx, padPx)
					P.label(card, {
						size = UDim2.new(1, 0, 0, 0),
						text = node.text ~= "" and node.text or ("<" .. tostring(node.label) .. ">"),
						bold = st.bold,
						textSize = st.fontSize or 13,
						color = txtCol,
						alignX = alignX,
						wrap = true,
						zIndex = 19,
					}).AutomaticSize = Enum.AutomaticSize.Y
				else
					local prefix = node.tag == "li" and "• " or ""
					local lbl = P.label(browserCard, {
						size = UDim2.new(1, 0, 0, 0),
						text = prefix .. tostring(node.text or ""),
						mono = (node.tag == "code" or node.tag == "pre"),
						bold = st.bold,
						textSize = st.fontSize or 13,
						color = node.tag == "a" and Color3.fromRGB(37, 99, 235) or txtCol,
						alignX = alignX,
						wrap = true,
						order = idx,
						zIndex = 18,
					})
					lbl.AutomaticSize = Enum.AutomaticSize.Y
				end
			end
		end

		local function renderCss(doc)
			local parsed = previewEngine.parseCss(doc.content)
			titleLbl.Text = string.format("◫ CSS DESIGN PREVIEW: %s (%d rules)", doc.title, #parsed.rules)

			-- If workspace has an HTML file, offer 1-click jump to preview HTML+CSS together!
			for _, fPath in ipairs(workspaceFs.allFiles()) do
				if util.endsWith(fPath:lower(), ".html") then
					local jumpHtmlBtn = P.button(scroll, {
						name = "PreviewLinkedHtmlBtn",
						size = UDim2.new(1, 0, 0, 28),
						bg = theme.color.accent,
						hoverBg = theme.color.accentHover,
						color = Color3.fromRGB(255, 255, 255),
						bold = true,
						text = "🌐 Preview Applied to " .. fPath,
						textSize = 11,
						radius = 4,
						order = 0,
						zIndex = 18,
						onClick = function()
							local hDoc = codeStore.openFile(fPath)
							if hDoc then renderDoc(hDoc) end
						end,
					})
					jumpHtmlBtn.BackgroundTransparency = 0
					break
				end
			end

			if #parsed.swatches > 0 then
				local palCard = P.frame(scroll, {
					name = "CssSwatchGrid",
					size = UDim2.new(1, 0, 0, 56),
					bg = theme.color.sideBar,
					radius = 5,
					border = theme.color.border,
					order = 1,
					zIndex = 17,
				})
				P.pad(palCard, 6, 8, 6, 8)
				P.label(palCard, {
					size = UDim2.new(1, 0, 0, 14),
					text = "COLOR PALETTE (" .. tostring(#parsed.swatches) .. ")",
					bold = true,
					textSize = 10,
					color = theme.color.muted,
					zIndex = 18,
				})
				local swRow = P.frame(palCard, {
					size = UDim2.new(1, 0, 0, 26),
					pos = UDim2.fromOffset(0, 18),
					zIndex = 18,
				})
				P.list(swRow, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
				for idx, sw in ipairs(parsed.swatches) do
					if idx <= 8 then
						local chip = P.frame(swRow, {
							size = UDim2.fromOffset(74, 22),
							bg = sw.color3,
							radius = 4,
							border = theme.color.border,
							order = idx,
							zIndex = 19,
						})
						P.label(chip, {
							size = UDim2.fromScale(1, 1),
							text = sw.hex,
							mono = true,
							bold = true,
							textSize = 10,
							color = Color3.fromRGB(255, 255, 255),
							alignX = Enum.TextXAlignment.Center,
							zIndex = 20,
						})
					end
				end
			end

			for idx, rule in ipairs(parsed.rules) do
				local bgCol = previewEngine.parseCssColor(rule.props["background-color"] or rule.props["background"]) or theme.color.inputBg
				local fgCol = previewEngine.parseCssColor(rule.props["color"]) or theme.color.editorText
				local card = P.frame(scroll, {
					name = "CssRuleCard_" .. tostring(idx),
					size = UDim2.new(1, 0, 0, 54),
					bg = bgCol,
					radius = 6,
					border = theme.color.border,
					order = idx + 2,
					zIndex = 17,
				})
				P.pad(card, 6, 10, 6, 10)
				P.label(card, {
					size = UDim2.new(1, 0, 0, 18),
					mono = true,
					bold = true,
					textSize = 12,
					color = fgCol,
					text = rule.selector,
					zIndex = 18,
				})
				local summary = {}
				for k, v in pairs(rule.props) do
					summary[#summary + 1] = k .. ": " .. v
				end
				table.sort(summary)
				P.label(card, {
					size = UDim2.new(1, 0, 0, 20),
					pos = UDim2.fromOffset(0, 20),
					mono = true,
					textSize = 10,
					color = fgCol,
					text = table.concat(summary, "; "),
					truncate = true,
					zIndex = 18,
				})
			end
		end

		local function renderMarkdown(doc)
			titleLbl.Text = "◫ MARKDOWN PREVIEW: " .. doc.title
			local blocks = previewEngine.parseMarkdown(doc.content)
			for idx, b in ipairs(blocks) do
				if b.kind == "heading" then
					local sizes = { 22, 18, 15, 13 }
					local wrap = P.frame(scroll, {
						name = "MdHeading_" .. tostring(idx),
						size = UDim2.new(1, 0, 0, sizes[b.level] + 12),
						order = idx,
						zIndex = 17,
					})
					P.label(wrap, {
						size = UDim2.new(1, 0, 1, -4),
						rich = true,
						bold = true,
						textSize = sizes[b.level],
						color = theme.color.tabActiveText,
						text = previewEngine.inlineMarkdownRich(b.text),
						truncate = true,
						zIndex = 18,
					})
					if b.level <= 2 then
						P.frame(wrap, {
							size = UDim2.new(1, 0, 0, 1),
							pos = UDim2.new(0, 0, 1, -1),
							bg = theme.color.border,
							zIndex = 18,
						})
					end
				elseif b.kind == "hr" then
					P.frame(scroll, {
						size = UDim2.new(1, 0, 0, 1),
						bg = theme.color.border,
						order = idx,
						zIndex = 17,
					})
				elseif b.kind == "code" then
					local scan = codeLexer.scan(b.text, b.lang)
					local richLines = {}
					for li = 1, #scan.lines do
						richLines[li] = codeLexer.rich(scan.lines[li], scan.spans[li], theme.syntax)
					end
					local codeBox = P.frame(scroll, {
						name = "MdCodeFence_" .. tostring(idx),
						size = UDim2.new(1, 0, 0, math.max(32, #scan.lines * 17 + 16)),
						bg = theme.color.sideBar,
						radius = 5,
						border = theme.color.border,
						order = idx,
						zIndex = 17,
					})
					P.pad(codeBox, 8, 10, 8, 10)
					P.label(codeBox, {
						size = UDim2.fromScale(1, 1),
						mono = true,
						rich = true,
						textSize = 12,
						color = theme.color.editorText,
						alignY = Enum.TextYAlignment.Top,
						wrap = true,
						text = table.concat(richLines, "\n"),
						zIndex = 18,
					})
				elseif b.kind == "quote" then
					local qFrame = P.frame(scroll, {
						size = UDim2.new(1, 0, 0, 26),
						bg = theme.color.inputBg,
						radius = 3,
						order = idx,
						zIndex = 17,
					})
					P.frame(qFrame, {
						size = UDim2.new(0, 3, 1, 0),
						bg = theme.color.accent,
						zIndex = 18,
					})
					P.label(qFrame, {
						size = UDim2.new(1, -16, 1, 0),
						pos = UDim2.fromOffset(12, 0),
						rich = true,
						textSize = 12,
						color = theme.color.muted,
						text = previewEngine.inlineMarkdownRich(b.text),
						wrap = true,
						zIndex = 18,
					})
				elseif b.kind == "task" or b.kind == "bullet" or b.kind == "numbered" then
					local prefix = "•  "
					if b.kind == "task" then
						prefix = b.checked and "☑  " or "☐  "
					elseif b.kind == "numbered" then
						prefix = tostring(b.num) .. ".  "
					end
					local lbl = P.label(scroll, {
						size = UDim2.new(1, 0, 0, 20),
						rich = true,
						textSize = 13,
						color = (b.kind == "task" and b.checked) and theme.color.good or theme.color.editorText,
						text = prefix .. previewEngine.inlineMarkdownRich(b.text),
						wrap = true,
						order = idx,
						zIndex = 17,
					})
					lbl.AutomaticSize = Enum.AutomaticSize.Y
				elseif b.kind == "table" then
					local tblCard = P.frame(scroll, {
						name = "MdTable_" .. tostring(idx),
						size = UDim2.new(1, 0, 0, #b.rows * 24 + 4),
						bg = theme.color.sideBar,
						radius = 4,
						border = theme.color.border,
						order = idx,
						zIndex = 17,
					})
					P.list(tblCard, Enum.FillDirection.Vertical, 0)
					for ri, cells in ipairs(b.rows) do
						local rFrame = P.frame(tblCard, {
							size = UDim2.new(1, 0, 0, 24),
							bg = ri == 1 and theme.color.sideBarHeader or (ri % 2 == 0 and theme.color.editor or theme.color.sideBar),
							order = ri,
							zIndex = 18,
						})
						local colW = 1 / math.max(1, #cells)
						for ci, cellTxt in ipairs(cells) do
							P.label(rFrame, {
								size = UDim2.new(colW, -8, 1, 0),
								pos = UDim2.new(colW * (ci - 1), 6, 0, 0),
								bold = (ri == 1),
								textSize = 11,
								color = ri == 1 and theme.color.tabActiveText or theme.color.editorText,
								text = cellTxt,
								truncate = true,
								zIndex = 19,
							})
						end
					end
				else
					local pLbl = P.label(scroll, {
						size = UDim2.new(1, 0, 0, 0),
						rich = true,
						textSize = 13,
						color = theme.color.editorText,
						text = previewEngine.inlineMarkdownRich(b.text),
						wrap = true,
						order = idx,
						zIndex = 17,
					})
					pLbl.AutomaticSize = Enum.AutomaticSize.Y
				end
			end
		end

		local function renderStructuredTree(doc)
			local parsed = previewEngine.parseStructuredData(doc.content, doc.langId)
			titleLbl.Text = string.format("◫ %s TREE INSPECTOR: %s", (parsed.format or doc.langId):upper(), doc.title)
			if not parsed.ok then
				local errCard = P.frame(scroll, {
					name = "PreviewSyntaxErrorCard",
					size = UDim2.new(1, 0, 0, 52),
					bg = theme.color.diffRemoveBg,
					radius = 5,
					border = theme.color.bad,
					order = 1,
					zIndex = 17,
				})
				P.pad(errCard, 8, 10, 8, 10)
				P.label(errCard, {
					size = UDim2.fromScale(1, 1),
					mono = true,
					textSize = 12,
					color = theme.color.bad,
					wrap = true,
					text = "⊗ Parse Error: " .. tostring(parsed.error),
					zIndex = 18,
				})
				return
			end

			local ord = 0
			local function walkValue(keyLabel, val, pathKey, depth)
				if ord > 180 or depth > 8 then return end
				ord = ord + 1
				if type(val) == "table" then
					local keys = util.keys(val)
					local isCollapsed = collapsedNodes[pathKey] == true
					local row = P.button(scroll, {
						name = "TreeNode_" .. pathKey,
						size = UDim2.new(1, 0, 0, 21),
						hoverBg = theme.color.hover,
						alignX = Enum.TextXAlignment.Left,
						mono = true,
						bold = true,
						textSize = 12,
						color = theme.color.accent,
						text = string.format(
							"%s%s %s  (%d items)",
							string.rep("   ", depth),
							isCollapsed and "▸" or "▾",
							keyLabel,
							#keys
						),
						order = ord,
						zIndex = 18,
						onClick = function()
							collapsedNodes[pathKey] = not collapsedNodes[pathKey]
							renderDoc(doc)
						end,
					})
					row.TextTruncate = Enum.TextTruncate.AtEnd
					if not isCollapsed then
						for _, k in ipairs(keys) do
							walkValue(tostring(k), val[k], pathKey .. "." .. tostring(k), depth + 1)
						end
					end
				else
					local valStr = type(val) == "string" and string.format("%q", val) or tostring(val)
					local vHex = "#ce9178"
					if type(val) == "number" then vHex = "#b5cea8"
					elseif type(val) == "boolean" then vHex = "#569cd6" end
					P.label(scroll, {
						size = UDim2.new(1, 0, 0, 19),
						mono = true,
						rich = true,
						textSize = 12,
						color = theme.color.editorText,
						text = string.format(
							'%s<font color="#9cdcfe">%s</font>: <font color="%s">%s</font>',
							string.rep("   ", depth + 1),
							util.escapeRichText(keyLabel),
							vHex,
							util.escapeRichText(valStr)
						),
						truncate = true,
						order = ord,
						zIndex = 18,
					})
				end
			end

			walkValue("root", parsed.data, "root", 0)
		end

		local function renderSql(doc)
			local res = previewEngine.runSqlPreview(doc.content)
			titleLbl.Text = string.format("◫ SQL TABLE PREVIEW: %s (%d result set(s))", doc.title, #res.results)

			if #res.results == 0 then
				P.label(scroll, {
					size = UDim2.new(1, 0, 0, 26),
					text = "Write CREATE TABLE, INSERT INTO, or SELECT statements to preview tabular results live.",
					color = theme.color.muted,
					textSize = 12,
					wrap = true,
					order = 1,
					zIndex = 17,
				})
				return
			end

			for idx, set in ipairs(res.results) do
				local cardH = 30 + (1 + math.max(1, #set.rows)) * 22
				local card = P.frame(scroll, {
					name = "SqlResultGrid_" .. tostring(idx),
					size = UDim2.new(1, 0, 0, cardH),
					bg = theme.color.sideBar,
					radius = 5,
					border = theme.color.border,
					order = idx,
					zIndex = 17,
				})
				P.label(card, {
					size = UDim2.new(1, -16, 0, 24),
					pos = UDim2.fromOffset(8, 2),
					bold = true,
					textSize = 11,
					color = theme.color.accent,
					text = string.format("%s  (%d rows)", set.title, #set.rows),
					truncate = true,
					zIndex = 18,
				})

				local grid = P.frame(card, {
					size = UDim2.new(1, -8, 1, -28),
					pos = UDim2.fromOffset(4, 26),
					zIndex = 18,
				})
				P.list(grid, Enum.FillDirection.Vertical, 0)

				local cols = #set.columns > 0 and set.columns or { "(empty)" }
				local colW = 1 / #cols

				local hdrRow = P.frame(grid, {
					size = UDim2.new(1, 0, 0, 22),
					bg = theme.color.sideBarHeader,
					order = 1,
					zIndex = 19,
				})
				for ci, cName in ipairs(cols) do
					P.label(hdrRow, {
						size = UDim2.new(colW, -6, 1, 0),
						pos = UDim2.new(colW * (ci - 1), 6, 0, 0),
						mono = true,
						bold = true,
						textSize = 11,
						color = theme.color.tabActiveText,
						text = tostring(cName),
						truncate = true,
						zIndex = 20,
					})
				end

				for ri, rData in ipairs(set.rows) do
					local rFrame = P.frame(grid, {
						size = UDim2.new(1, 0, 0, 22),
						bg = ri % 2 == 0 and theme.color.editor or theme.color.sideBar,
						order = ri + 1,
						zIndex = 19,
					})
					for ci, cName in ipairs(cols) do
						P.label(rFrame, {
							size = UDim2.new(colW, -6, 1, 0),
							pos = UDim2.new(colW * (ci - 1), 6, 0, 0),
							mono = true,
							textSize = 11,
							color = theme.color.editorText,
							text = tostring(rData[cName] ~= nil and rData[cName] or "NULL"),
							truncate = true,
							zIndex = 20,
						})
					end
				end
			end
		end

		local function renderScriptQuickEval(doc)
			local res = previewEngine.runScriptPreview(doc.content, doc.langId)
			titleLbl.Text = string.format("◫ %s QUICK-EVAL PREVIEW: %s", res.lang:upper(), doc.title)

			local outCard = P.frame(scroll, {
				name = "ScriptEvalOutputCard",
				size = UDim2.new(1, 0, 0, math.max(54, #res.output * 19 + 34)),
				bg = theme.color.sideBar,
				radius = 5,
				border = theme.color.border,
				order = 1,
				zIndex = 17,
			})
			P.pad(outCard, 6, 10, 8, 10)
			P.label(outCard, {
				size = UDim2.new(1, 0, 0, 18),
				bold = true,
				textSize = 10,
				color = theme.color.good,
				text = "▶ STDOUT PREVIEW (" .. tostring(#res.output) .. " line(s))",
				zIndex = 18,
			})
			local outText = #res.output > 0
				and table.concat(res.output, "\n")
				or "(Add print(...) or console.log(...) calls to preview live output)"
			P.label(outCard, {
				size = UDim2.new(1, 0, 1, -20),
				pos = UDim2.fromOffset(0, 20),
				mono = true,
				textSize = 12,
				color = #res.output > 0 and theme.color.editorText or theme.color.muted,
				alignY = Enum.TextYAlignment.Top,
				wrap = true,
				text = outText,
				zIndex = 18,
			})

			if #res.variables > 0 then
				local varCard = P.frame(scroll, {
					name = "ScriptEvalVarsCard",
					size = UDim2.new(1, 0, 0, #res.variables * 20 + 30),
					bg = theme.color.sideBar,
					radius = 5,
					border = theme.color.border,
					order = 2,
					zIndex = 17,
				})
				P.pad(varCard, 6, 10, 6, 10)
				P.label(varCard, {
					size = UDim2.new(1, 0, 0, 18),
					bold = true,
					textSize = 10,
					color = theme.color.accent,
					text = "EVALUATED VARIABLES",
					zIndex = 18,
				})
				for vi, kv in ipairs(res.variables) do
					P.label(varCard, {
						size = UDim2.new(1, 0, 0, 19),
						pos = UDim2.fromOffset(0, 18 + (vi - 1) * 19),
						mono = true,
						textSize = 12,
						color = theme.color.editorText,
						text = string.format("%s = %s", kv.name, kv.value),
						truncate = true,
						zIndex = 18,
					})
				end
			end
		end

		renderDoc = function(doc)
			if not doc or not languages.isPreviewable(doc) then
				return false
			end
			targetDoc = doc
			scroll:ClearAllChildren()
			P.pad(scroll, 12, 14, 16, 14)
			P.list(scroll, Enum.FillDirection.Vertical, 8)

			local lid = doc.langId
			if lid == "html" then
				renderHtml(doc)
			elseif lid == "css" then
				renderCss(doc)
			elseif lid == "markdown" then
				renderMarkdown(doc)
			elseif lid == "json" or lid == "yaml" then
				renderStructuredTree(doc)
			elseif lid == "sql" then
				renderSql(doc)
			elseif lid == "python" or lid == "javascript" or lid == "typescript" then
				renderScriptQuickEval(doc)
			end
			return true
		end

		theme.changed:connect(function()
			root.BackgroundColor3 = theme.color.editor
			leftBorder.BackgroundColor3 = theme.color.border
			header.BackgroundColor3 = theme.color.tabBar
			headerRule.BackgroundColor3 = theme.color.border
			scroll.BackgroundColor3 = theme.color.editor
			if root.Visible and targetDoc then
				renderDoc(targetDoc)
			end
		end)

		return {
			root = root,
			render = renderDoc,
			currentDoc = function() return targetDoc end,
			setTransparency = function(bgTrans)
				root.BackgroundTransparency = bgTrans
				header.BackgroundTransparency = bgTrans
				scroll.BackgroundTransparency = bgTrans
			end,
		}
	end

	return M
end
