-- Multi-Language Live Preview Engine (`src/runtime/preview_engine.lua`):
-- Pure Lua 5.1-compatible Luau parsers & quick-evaluators for previewable languages ONLY:
--   1. HTML (+ live workspace `style.css` & `<style>` CSS cascade)
--   2. CSS (selector style cards + color swatch extraction)
--   3. Markdown (GFM headings, RichText spans, code fences, blockquotes, lists, tasks, tables)
--   4. JSON & YAML/TOML/ENV (structured collapsible tree + validation)
--   5. SQL (in-memory CREATE TABLE / INSERT INTO / SELECT ... WHERE ... LIMIT simulator)
--   6. Python / JavaScript / TypeScript (sandboxed quick-eval output + variable & symbol inspector)
return function(env)
	local util = env.require("runtime/util")
	local languages = env.require("runtime/languages")
	local colorUtils = env.require("runtime/color_utils")

	local M = {}

	local NAMED_COLORS = {
		white = { 255, 255, 255 },
		black = { 18, 18, 18 },
		red = { 239, 68, 68 },
		green = { 34, 197, 94 },
		blue = { 59, 130, 246 },
		yellow = { 250, 204, 21 },
		orange = { 249, 115, 22 },
		purple = { 168, 85, 247 },
		pink = { 236, 72, 153 },
		cyan = { 6, 182, 212 },
		gray = { 148, 163, 184 },
		grey = { 148, 163, 184 },
		dodgerblue = { 30, 144, 255 },
		coral = { 255, 127, 80 },
		gold = { 255, 215, 0 },
		teal = { 20, 184, 166 },
		navy = { 30, 58, 138 },
	}

	function M.canPreview(langIdOrDoc)
		return languages.isPreviewable(langIdOrDoc)
	end

	function M.parseCssColor(valStr)
		local s = util.trim(tostring(valStr or "")):lower()
		if s == "" or s == "transparent" or s == "none" then return nil end
		if NAMED_COLORS[s] then
			local c = NAMED_COLORS[s]
			return Color3.fromRGB(c[1], c[2], c[3])
		end
		local hits = colorUtils.findColorsInLine(valStr)
		if #hits > 0 then
			return hits[1].color3
		end
		-- Support 3-digit hex `#abc`
		local h3 = s:match("#(%x%x%x)$") or s:match("#(%x%x%x)[^%x]")
		if h3 then
			local r = tonumber(h3:sub(1, 1) .. h3:sub(1, 1), 16) or 0
			local g = tonumber(h3:sub(2, 2) .. h3:sub(2, 2), 16) or 0
			local b = tonumber(h3:sub(3, 3) .. h3:sub(3, 3), 16) or 0
			return Color3.fromRGB(r, g, b)
		end
		return nil
	end

	local function parsePx(valStr)
		local s = tostring(valStr or "")
		local num = tonumber(s:match("([%-%d%.]+)%s*px")) or tonumber(s:match("^%s*([%-%d%.]+)%s*$"))
		if num then return math.floor(num + 0.5) end
		local rem = tonumber(s:match("([%-%d%.]+)%s*r?em"))
		if rem then return math.floor(rem * 16 + 0.5) end
		return nil
	end

	local function parseDeclarations(declBlock)
		local props = {}
		for pair in tostring(declBlock or ""):gmatch("([^;]+)") do
			local k, v = pair:match("^%s*([%w%-]+)%s*:%s*(.-)%s*$")
			if k and v and v ~= "" then
				v = v:gsub("%s*!important%s*$", "")
				props[k:lower()] = v
			end
		end
		return props
	end

	function M.parseCss(cssSource)
		local clean = tostring(cssSource or ""):gsub("/%*.-%*/", "")
		local rules = {}
		local bySelector = {}
		local swatches = {}
		local seenHex = {}

		for _, ln in ipairs(util.lines(clean)) do
			for _, hit in ipairs(colorUtils.findColorsInLine(ln)) do
				local hex = string.format("#%02x%02x%02x", hit.r, hit.g, hit.b)
				if not seenHex[hex] then
					seenHex[hex] = true
					swatches[#swatches + 1] = {
						hex = hex,
						raw = hit.raw,
						color3 = hit.color3,
					}
				end
			end
		end

		for selGroup, body in clean:gmatch("([^{}]+)%s*{([^{}]*)}") do
			local props = parseDeclarations(body)
			local selectors = util.split(selGroup, ",")
			for _, rawSel in ipairs(selectors) do
				local sel = util.trim(rawSel)
				if sel ~= "" and not util.startsWith(sel, "@") then
					if not bySelector[sel] then bySelector[sel] = {} end
					for pk, pv in pairs(props) do
						bySelector[sel][pk] = pv
					end
					rules[#rules + 1] = {
						selector = sel,
						props = props,
					}
				end
			end
		end

		return {
			rules = rules,
			bySelector = bySelector,
			swatches = swatches,
		}
	end

	local function mergeProps(dst, src)
		if not src then return dst end
		for k, v in pairs(src) do dst[k] = v end
		return dst
	end

	local function resolveNodeStyle(tag, idAttr, classAttr, inlineStyle, cssMap)
		local merged = {}
		mergeProps(merged, cssMap["*"])
		mergeProps(merged, cssMap[tag])
		if classAttr and classAttr ~= "" then
			for cls in classAttr:gmatch("%S+") do
				mergeProps(merged, cssMap["." .. cls])
				mergeProps(merged, cssMap[tag .. "." .. cls])
			end
		end
		if idAttr and idAttr ~= "" then
			mergeProps(merged, cssMap["#" .. idAttr])
		end
		if inlineStyle and inlineStyle ~= "" then
			mergeProps(merged, parseDeclarations(inlineStyle))
		end

		return {
			bg = M.parseCssColor(merged["background-color"] or merged["background"]),
			color = M.parseCssColor(merged["color"]),
			borderColor = M.parseCssColor(merged["border-color"] or merged["border"]),
			radius = parsePx(merged["border-radius"]),
			padding = parsePx(merged["padding"]),
			fontSize = parsePx(merged["font-size"]),
			bold = (merged["font-weight"] == "bold" or (tonumber(merged["font-weight"]) or 400) >= 600),
			align = merged["text-align"],
			raw = merged,
		}
	end

	local function stripTags(htmlFrag)
		return util.trim((tostring(htmlFrag or "")
			:gsub("<br%s*/?>", "\n")
			:gsub("<[^>]+>", "")
			:gsub("&nbsp;", " ")
			:gsub("&amp;", "&")
			:gsub("&lt;", "<")
			:gsub("&gt;", ">")
			:gsub("&quot;", '"')))
	end

	function M.parseHtml(htmlSource, cssLoaderFn)
		local src = tostring(htmlSource or "")
		local title = src:match("<[tT][iI][tT][lL][eE][^>]*>(.-)</[tT][iI][tT][lL][eE]>")
		title = title and stripTags(title) or "HTML Document"

		local cssChunks = {}
		local linkedSheets = {}

		-- Collect `<link rel="stylesheet" href="...">`
		for attrs in src:gmatch("<[lL][iI][nN][kK]([^>]-)>") do
			local href = attrs:match('[hH][rR][eE][fF]%s*=%s*["\']([^"\']+)["\']')
			local rel = attrs:match('[rR][eE][lL]%s*=%s*["\']([^"\']+)["\']')
			if href and (not rel or rel:lower():find("stylesheet", 1, true)) then
				linkedSheets[#linkedSheets + 1] = href
				if type(cssLoaderFn) == "function" then
					local extCss = cssLoaderFn(href)
					if type(extCss) == "string" and extCss ~= "" then
						cssChunks[#cssChunks + 1] = extCss
					end
				end
			end
		end

		-- Also auto-link workspace `style.css` when present if not already loaded!
		if #linkedSheets == 0 and type(cssLoaderFn) == "function" then
			local autoCss = cssLoaderFn("style.css")
			if type(autoCss) == "string" and autoCss ~= "" then
				linkedSheets[#linkedSheets + 1] = "style.css"
				cssChunks[#cssChunks + 1] = autoCss
			end
		end

		-- Collect inline `<style>...</style>`
		for block in src:gmatch("<[sS][tT][yY][lL][eE][^>]*>(.-)</[sS][tT][yY][lL][eE]>") do
			cssChunks[#cssChunks + 1] = block
		end

		local cssParsed = M.parseCss(table.concat(cssChunks, "\n"))
		local bodyStyle = resolveNodeStyle("body", nil, nil, nil, cssParsed.bySelector)

		-- Extract body content (or fallback to full source without head/style/script)
		local bodyHtml = src:match("<[bB][oO][dD][yY][^>]*>(.-)</[bB][oO][dD][yY]>") or src
		bodyHtml = bodyHtml
			:gsub("<!%-%-.-%-%->", "")
			:gsub("<[hH][eE][aA][dD][^>]*>.-</[hH][eE][aA][dD]>", "")
			:gsub("<[sS][tT][yY][lL][eE][^>]*>.-</[sS][tT][yY][lL][eE]>", "")
			:gsub("<[sS][cC][rR][iI][pP][tT][^>]*>.-</[sS][cC][rR][iI][pP][tT]>", "")

		local nodes = {}
		local pos = 1
		local len = #bodyHtml

		local LEAF_TAGS = {
			h1 = true, h2 = true, h3 = true, h4 = true,
			p = true, button = true, a = true, li = true,
			code = true, pre = true, span = true, label = true,
		}
		local CONTAINER_TAGS = {
			div = true, section = true, header = true, footer = true,
			main = true, article = true, nav = true, aside = true,
		}

		while pos <= len and #nodes < 120 do
			local openStart, openEnd, slash, rawTag, rawAttrs = bodyHtml:find("<(/?)([%w]+)(.-)>", pos)
			if not openStart then
				local tailTxt = stripTags(bodyHtml:sub(pos))
				if tailTxt ~= "" then
					nodes[#nodes + 1] = { tag = "p", text = tailTxt, style = resolveNodeStyle("p", nil, nil, nil, cssParsed.bySelector) }
				end
				break
			end

			if openStart > pos then
				local between = stripTags(bodyHtml:sub(pos, openStart - 1))
				if between ~= "" then
					nodes[#nodes + 1] = { tag = "p", text = between, style = resolveNodeStyle("p", nil, nil, nil, cssParsed.bySelector) }
				end
			end

			local tag = rawTag:lower()
			if slash == "/" then
				pos = openEnd + 1
			elseif tag == "hr" then
				nodes[#nodes + 1] = { tag = "hr", text = "", style = {} }
				pos = openEnd + 1
			elseif tag == "br" then
				pos = openEnd + 1
			elseif tag == "input" then
				local ph = rawAttrs:match('[pP][lL][aA][cC][eE][hH][oO][lL][dD][eE][rR]%s*=%s*["\']([^"\']*)["\']')
					or rawAttrs:match('[vV][aA][lL][uU][eE]%s*=%s*["\']([^"\']*)["\']')
					or "Input..."
				local idAttr = rawAttrs:match('[iI][dD]%s*=%s*["\']([^"\']+)["\']')
				local clsAttr = rawAttrs:match('[cC][lL][aA][sS][sS]%s*=%s*["\']([^"\']+)["\']')
				local stAttr = rawAttrs:match('[sS][tT][yY][lL][eE]%s*=%s*["\']([^"\']+)["\']')
				nodes[#nodes + 1] = {
					tag = "input",
					text = ph,
					style = resolveNodeStyle("input", idAttr, clsAttr, stAttr, cssParsed.bySelector),
				}
				pos = openEnd + 1
			elseif LEAF_TAGS[tag] then
				local closePat = "</" .. tag .. "%s*>"
				local cStart, cEnd = bodyHtml:lower():find(closePat, openEnd + 1)
				local inner = cStart and bodyHtml:sub(openEnd + 1, cStart - 1) or ""
				local idAttr = rawAttrs:match('[iI][dD]%s*=%s*["\']([^"\']+)["\']')
				local clsAttr = rawAttrs:match('[cC][lL][aA][sS][sS]%s*=%s*["\']([^"\']+)["\']')
				local stAttr = rawAttrs:match('[sS][tT][yY][lL][eE]%s*=%s*["\']([^"\']+)["\']')
				local hrefAttr = rawAttrs:match('[hH][rR][eE][fF]%s*=%s*["\']([^"\']+)["\']')
				nodes[#nodes + 1] = {
					tag = tag,
					text = stripTags(inner),
					href = hrefAttr,
					style = resolveNodeStyle(tag, idAttr, clsAttr, stAttr, cssParsed.bySelector),
				}
				pos = cEnd and (cEnd + 1) or (openEnd + 1)
			elseif CONTAINER_TAGS[tag] then
				local idAttr = rawAttrs:match('[iI][dD]%s*=%s*["\']([^"\']+)["\']')
				local clsAttr = rawAttrs:match('[cC][lL][aA][sS][sS]%s*=%s*["\']([^"\']+)["\']')
				local stAttr = rawAttrs:match('[sS][tT][yY][lL][eE]%s*=%s*["\']([^"\']+)["\']')
				local st = resolveNodeStyle(tag, idAttr, clsAttr, stAttr, cssParsed.bySelector)
				-- Look ahead to next tag; if pure text inside single div/card, render styled card!
				local closePat = "</" .. tag .. "%s*>"
				local cStart, cEnd = bodyHtml:lower():find(closePat, openEnd + 1)
				local innerRaw = cStart and bodyHtml:sub(openEnd + 1, cStart - 1) or ""
				local hasNestedBlock = innerRaw:find("<[dD][iI][vV]") or innerRaw:find("<[hH][1-4]") or innerRaw:find("<[bB][uU][tT][tT][oO][nN]")
				if cStart and not hasNestedBlock then
					local txt = stripTags(innerRaw)
					if txt ~= "" or st.bg then
						nodes[#nodes + 1] = {
							tag = "card",
							label = clsAttr or idAttr or tag,
							text = txt,
							style = st,
						}
					end
					pos = cEnd + 1
				else
					if st.bg or st.borderColor or clsAttr or idAttr then
						nodes[#nodes + 1] = {
							tag = "banner",
							label = (idAttr and ("#" .. idAttr)) or (clsAttr and ("." .. clsAttr)) or tag,
							text = "",
							style = st,
						}
					end
					pos = openEnd + 1
				end
			else
				pos = openEnd + 1
			end
		end

		return {
			title = title,
			linkedSheets = linkedSheets,
			bodyStyle = bodyStyle,
			css = cssParsed,
			nodes = nodes,
		}
	end

	-- Formats inline Markdown (`**bold**`, `*italic*`, `` `code` ``, `[label](url)`) into Roblox RichText
	function M.inlineMarkdownRich(text, codeHex, linkHex)
		local esc = util.escapeRichText(tostring(text or ""))
		local cHex = codeHex or "#ce9178"
		local lHex = linkHex or "#4fc1ff"
		esc = esc:gsub("`([^`]+)`", '<font color="' .. cHex .. '"><b>%1</b></font>')
		esc = esc:gsub("%*%*([^%*]+)%*%*", "<b>%1</b>")
		esc = esc:gsub("__([^_]+)__", "<b>%1</b>")
		esc = esc:gsub("%*([^%*]+)%*", "<i>%1</i>")
		esc = esc:gsub("%[([^%]]+)%]%(([^%)]+)%)", '<font color="' .. lHex .. '"><u>%1</u></font>')
		return esc
	end

	function M.parseMarkdown(mdSource)
		local lns = util.lines(tostring(mdSource or ""))
		local blocks = {}
		local i = 1
		local total = #lns

		while i <= total do
			local line = lns[i]
			local trimmed = util.trim(line)

			-- Fenced code block
			local fenceLang = trimmed:match("^```([%w_%-%+]*)")
			if fenceLang ~= nil then
				local codeLines = {}
				i = i + 1
				while i <= total and not util.trim(lns[i]):match("^```") do
					codeLines[#codeLines + 1] = lns[i]
					i = i + 1
				end
				blocks[#blocks + 1] = {
					kind = "code",
					lang = fenceLang ~= "" and fenceLang:lower() or "luau",
					text = table.concat(codeLines, "\n"),
				}
				i = i + 1
			elseif trimmed == "" then
				i = i + 1
			elseif trimmed:match("^%-%-%-+$") or trimmed:match("^%*%*%*+$") then
				blocks[#blocks + 1] = { kind = "hr" }
				i = i + 1
			elseif line:match("^(#+)%s+(.+)$") then
				local hashes, headingText = line:match("^(#+)%s+(.+)$")
				blocks[#blocks + 1] = {
					kind = "heading",
					level = math.min(4, #hashes),
					text = headingText,
				}
				i = i + 1
			elseif trimmed:match("^>%s?(.*)$") then
				local quoteText = trimmed:match("^>%s?(.*)$")
				blocks[#blocks + 1] = {
					kind = "quote",
					text = quoteText,
				}
				i = i + 1
			elseif trimmed:match("^[-%*]%s+%[([xX ])%]%s+(.+)$") then
				local mark, taskText = trimmed:match("^[-%*]%s+%[([xX ])%]%s+(.+)$")
				blocks[#blocks + 1] = {
					kind = "task",
					checked = (mark:lower() == "x"),
					text = taskText,
				}
				i = i + 1
			elseif trimmed:match("^[-%*%+]%s+(.+)$") then
				local itemText = trimmed:match("^[-%*%+]%s+(.+)$")
				blocks[#blocks + 1] = {
					kind = "bullet",
					text = itemText,
				}
				i = i + 1
			elseif trimmed:match("^(%d+)%.%s+(.+)$") then
				local num, itemText = trimmed:match("^(%d+)%.%s+(.+)$")
				blocks[#blocks + 1] = {
					kind = "numbered",
					num = num,
					text = itemText,
				}
				i = i + 1
			elseif trimmed:sub(1, 1) == "|" and trimmed:sub(-1) == "|" then
				local rows = {}
				while i <= total do
					local rTrim = util.trim(lns[i])
					if rTrim:sub(1, 1) ~= "|" then break end
					if not rTrim:match("^[|%s:%-]+$") then
						local cells = {}
						for cell in rTrim:sub(2, -2):gmatch("([^|]+)") do
							cells[#cells + 1] = util.trim(cell)
						end
						rows[#rows + 1] = cells
					end
					i = i + 1
				end
				if #rows > 0 then
					blocks[#blocks + 1] = { kind = "table", rows = rows }
				end
			else
				blocks[#blocks + 1] = {
					kind = "paragraph",
					text = trimmed,
				}
				i = i + 1
			end
		end

		return blocks
	end

	-- Parses JSON or lightweight YAML/TOML/ENV into a Lua value tree
	local function parseSimpleYaml(source)
		local root = {}
		local stack = { { indent = -1, tbl = root } }
		local currentSection = nil

		for _, rawLine in ipairs(util.lines(source)) do
			local stripped = rawLine:gsub("#.*$", "")
			if stripped:find("%S") then
				local indent = #(stripped:match("^(%s*)") or "")
				local trimmed = util.trim(stripped)

				-- INI/TOML `[section]`
				local secName = trimmed:match("^%[([^%]]+)%]$")
				if secName then
					root[secName] = root[secName] or {}
					currentSection = root[secName]
					stack = { { indent = -1, tbl = currentSection } }
				else
					while #stack > 1 and indent <= stack[#stack].indent do
						table.remove(stack)
					end
					local target = stack[#stack].tbl

					local listVal = trimmed:match("^%-%s+(.+)$")
					if listVal then
						local cleanV = listVal:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
						if cleanV == "true" then cleanV = true
						elseif cleanV == "false" then cleanV = false
						elseif tonumber(cleanV) then cleanV = tonumber(cleanV) end
						target[#target + 1] = cleanV
					else
						local k, v = trimmed:match("^([%w_%-%./]+)%s*[:=]%s*(.*)$")
						if k then
							v = util.trim(v)
							if v == "" then
								local child = {}
								target[k] = child
								stack[#stack + 1] = { indent = indent, tbl = child }
							else
								local cleanV = v:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
								if cleanV == "true" then cleanV = true
								elseif cleanV == "false" then cleanV = false
								elseif cleanV == "null" or cleanV == "~" then cleanV = "null"
								elseif tonumber(cleanV) then cleanV = tonumber(cleanV) end
								target[k] = cleanV
							end
						end
					end
				end
			end
		end
		return root
	end

	function M.parseStructuredData(source, langId)
		local lid = tostring(langId or "json"):lower()
		if lid == "json" then
			local decoded, err = util.jsonDecode(source)
			if decoded == nil then
				return { ok = false, error = tostring(err or "Invalid JSON syntax") }
			end
			return { ok = true, data = decoded, format = "JSON" }
		else
			local ok, parsed = pcall(parseSimpleYaml, source)
			if not ok then
				return { ok = false, error = tostring(parsed) }
			end
			return { ok = true, data = parsed, format = "YAML / Config" }
		end
	end

	-- Lightweight Pure-Luau SQL Table Simulator (`CREATE TABLE`, `INSERT INTO`, `SELECT`)
	local function parseSqlTuple(tupleStr)
		local vals = {}
		local pos = 1
		local s = tostring(tupleStr or "")
		local n = #s
		while pos <= n do
			while pos <= n and s:sub(pos, pos):match("%s") do pos = pos + 1 end
			if pos > n then break end
			local ch = s:sub(pos, pos)
			if ch == "'" or ch == '"' then
				local closeIdx = s:find(ch, pos + 1, true)
				if closeIdx then
					vals[#vals + 1] = s:sub(pos + 1, closeIdx - 1)
					pos = closeIdx + 1
				else
					vals[#vals + 1] = s:sub(pos + 1)
					break
				end
				local comma = s:find(",", pos, true)
				pos = comma and (comma + 1) or (n + 1)
			else
				local comma = s:find(",", pos, true)
				local tok = util.trim(comma and s:sub(pos, comma - 1) or s:sub(pos))
				if tok:upper() == "NULL" then
					vals[#vals + 1] = "NULL"
				elseif tok:upper() == "TRUE" then
					vals[#vals + 1] = true
				elseif tok:upper() == "FALSE" then
					vals[#vals + 1] = false
				elseif tonumber(tok) then
					vals[#vals + 1] = tonumber(tok)
				else
					vals[#vals + 1] = tok
				end
				pos = comma and (comma + 1) or (n + 1)
			end
		end
		return vals
	end

	function M.runSqlPreview(sqlSource)
		local clean = tostring(sqlSource or "")
			:gsub("/%*.-%*/", " ")
			:gsub("%-%-[^\r\n]*", " ")
		local tables = {}
		local tableOrder = {}
		local results = {}

		for stmt in clean:gmatch("([^;]+)") do
			local s = util.trim(stmt:gsub("%s+", " "))
			if s ~= "" then
				local upper = s:upper()
				if util.startsWith(upper, "CREATE TABLE") then
					local tblName, colsBody = s:match("^[cC][rR][eE][aA][tT][eE]%s+[tT][aA][bB][lL][eE]%s+[iI]?[fF]?%s*[nN]?[oO]?[tT]?%s*[eE]?[xX]?[iI]?[sS]?[tT]?[sS]?%s*([%w_]+)%s*%((.+)%)$")
					if not tblName then
						tblName, colsBody = s:match("^[cC][rR][eE][aA][tT][eE]%s+[tT][aA][bB][lL][eE]%s+([%w_]+)%s*%((.+)%)$")
					end
					if tblName and colsBody then
						local cols = {}
						for colDef in colsBody:gmatch("([^,]+)") do
							local cName = util.trim(colDef):match("^([%w_]+)")
							local cUpper = (cName or ""):upper()
							if cName and cUpper ~= "PRIMARY" and cUpper ~= "FOREIGN" and cUpper ~= "CONSTRAINT" and cUpper ~= "UNIQUE" then
								cols[#cols + 1] = cName
							end
						end
						tables[tblName:lower()] = { name = tblName, columns = cols, rows = {} }
						tableOrder[#tableOrder + 1] = tblName:lower()
					end
				elseif util.startsWith(upper, "INSERT INTO") then
					local tblName, colSpec, valuesTail = s:match("^[iI][nN][sS][eE][rR][tT]%s+[iI][nN][tT][oO]%s+([%w_]+)%s*(%b())%s*[vV][aA][lL][uU][eE][sS]%s*(.+)$")
					if not tblName then
						tblName, valuesTail = s:match("^[iI][nN][sS][eE][rR][tT]%s+[iI][nN][tT][oO]%s+([%w_]+)%s+[vV][aA][lL][uU][eE][sS]%s*(.+)$")
					end
					if tblName and valuesTail then
						local key = tblName:lower()
						local t = tables[key]
						local targetCols = nil
						if colSpec then
							targetCols = parseSqlTuple(colSpec:sub(2, -2))
						end
						if not t then
							t = { name = tblName, columns = targetCols or {}, rows = {} }
							tables[key] = t
							tableOrder[#tableOrder + 1] = key
						end
						for tup in valuesTail:gmatch("%(([^%)]*)%)") do
							local vals = parseSqlTuple(tup)
							if #t.columns == 0 then
								for ci = 1, #vals do t.columns[ci] = "col_" .. tostring(ci) end
							end
							local rowMap = {}
							local colsUse = targetCols or t.columns
							for ci, colName in ipairs(colsUse) do
								rowMap[colName] = vals[ci]
							end
							t.rows[#t.rows + 1] = rowMap
						end
					end
				elseif util.startsWith(upper, "SELECT ") then
					local colsPart, tblName, tailPart = s:match("^[sS][eE][lL][eE][cC][tT]%s+(.-)%s+[fF][rR][oO][mM]%s+([%w_]+)(.*)$")
					if colsPart and tblName then
						local t = tables[tblName:lower()]
						if t then
							local limitN = tonumber((tailPart or ""):match("[lL][iI][mM][iI][tT]%s+(%d+)")) or 50
							local whereCol, whereOp, whereVal = (tailPart or ""):match("[wW][hH][eE][rR][eE]%s+([%w_]+)%s*([=!<>]+)%s*(['\"]?[%w_%-%.]+['\"]?)")
							if whereVal then
								whereVal = whereVal:gsub("^['\"]", ""):gsub("['\"]$", "")
							end

							local selCols = {}
							if util.trim(colsPart) == "*" then
								for _, c in ipairs(t.columns) do selCols[#selCols + 1] = c end
							else
								for c in colsPart:gmatch("([^,]+)") do
									local cleanC = util.trim(c):match("([%w_]+)$") or util.trim(c)
									selCols[#selCols + 1] = cleanC
								end
							end

							local outRows = {}
							for _, r in ipairs(t.rows) do
								local keep = true
								if whereCol and whereOp and whereVal ~= nil then
									local rv = r[whereCol]
									local numCmp = tonumber(whereVal)
									if whereOp == "=" then
										keep = tostring(rv) == whereVal
									elseif whereOp == "!=" or whereOp == "<>" then
										keep = tostring(rv) ~= whereVal
									elseif whereOp == ">" and numCmp and tonumber(rv) then
										keep = tonumber(rv) > numCmp
									elseif whereOp == "<" and numCmp and tonumber(rv) then
										keep = tonumber(rv) < numCmp
									elseif whereOp == ">=" and numCmp and tonumber(rv) then
										keep = tonumber(rv) >= numCmp
									elseif whereOp == "<=" and numCmp and tonumber(rv) then
										keep = tonumber(rv) <= numCmp
									end
								end
								if keep then
									outRows[#outRows + 1] = r
									if #outRows >= limitN then break end
								end
							end

							results[#results + 1] = {
								title = "Query Result — " .. t.name,
								query = s,
								columns = selCols,
								rows = outRows,
							}
						end
					elseif not s:lower():find(" from ", 1, true) then
						-- Scalar SELECT preview e.g. `SELECT 1 + 1 AS sum`
						local vals = parseSqlTuple(s:sub(8))
						local cols = {}
						local row = {}
						for idx, v in ipairs(vals) do
							local colLabel = "expr_" .. tostring(idx)
							cols[#cols + 1] = colLabel
							row[colLabel] = v
						end
						results[#results + 1] = {
							title = "Scalar Query",
							query = s,
							columns = cols,
							rows = { row },
						}
					end
				end
			end
		end

		-- If there were CREATE/INSERT tables but no explicit SELECT, preview all populated tables!
		if #results == 0 then
			for _, key in ipairs(tableOrder) do
				local t = tables[key]
				results[#results + 1] = {
					title = "Table Schema & Rows — " .. t.name,
					query = "SELECT * FROM " .. t.name,
					columns = t.columns,
					rows = t.rows,
				}
			end
		end

		return {
			tableCount = #tableOrder,
			results = results,
		}
	end

	-- Quick-Eval Preview Runner for Python, JavaScript, and TypeScript
	local function evalSimpleExpr(expr, vars)
		local s = util.trim(tostring(expr or "")):gsub(";%s*$", "")
		if s == "" then return "" end
		if s == "true" or s == "True" then return true end
		if s == "false" or s == "False" then return false end
		if s == "None" or s == "null" or s == "undefined" then return "null" end
		if tonumber(s) then return tonumber(s) end

		-- Template literal `` `Hello ${name}` `` or Python `f"Hello {name}"`
		local fBody = s:match('^[fF]["\'](.-)["\']$')
		if fBody then
			return (fBody:gsub("{([%w_]+)}", function(k)
				return vars[k] ~= nil and tostring(vars[k]) or ("{" .. k .. "}")
			end))
		end
		local tplBody = s:match("^`(.-)`$")
		if tplBody then
			return (tplBody:gsub("%${([%w_]+)}", function(k)
				return vars[k] ~= nil and tostring(vars[k]) or ("${" .. k .. "}")
			end))
		end

		local strLit = s:match('^"(.-)"$') or s:match("^'(.-)'$")
		if strLit then return strLit end

		if vars[s] ~= nil then return vars[s] end

		-- Array / List literal `[1, 2, 3]`
		local listInner = s:match("^%[(.*)%]$")
		if listInner then
			local items = {}
			for part in listInner:gmatch("([^,]+)") do
				items[#items + 1] = tostring(evalSimpleExpr(part, vars))
			end
			return "[" .. table.concat(items, ", ") .. "]"
		end

		-- Safe arithmetic / identifier substitution (`a + b * 2`)
		local substituted = s:gsub("([%a_][%w_]*)", function(id)
			local v = vars[id]
			if type(v) == "number" then return tostring(v) end
			if id == "math" or id == "Math" then return "math" end
			return id
		end)
		if substituted:match("^[%d%s%+%-%*/%%%^%(%)%.]+$") then
			local fn = loadstring("return " .. substituted)
			if fn then
				setfenv(fn, {})
				local ok, val = pcall(fn)
				if ok and val ~= nil then return val end
			end
		end

		-- String concatenation `"a" + "b"`
		if s:find("+", 1, true) then
			local parts = util.split(s, "+")
			local out = {}
			for _, p in ipairs(parts) do
				out[#out + 1] = tostring(evalSimpleExpr(p, vars))
			end
			return table.concat(out)
		end

		return s
	end

	function M.runScriptPreview(source, langId)
		local lid = tostring(langId or "python"):lower()
		local vars = {}
		local output = {}
		local symbols = {}

		for lineNo, rawLine in ipairs(util.lines(tostring(source or ""))) do
			local trimmed = util.trim(rawLine)
			if lid == "python" then
				trimmed = util.trim(trimmed:gsub("#.*$", ""))
			else
				trimmed = util.trim(trimmed:gsub("//.*$", ""))
			end

			if trimmed ~= "" then
				-- Detect function / class declarations
				local pyFn = trimmed:match("^def%s+([%w_]+)%s*%((.-)%)")
				local pyCls = trimmed:match("^class%s+([%w_]+)")
				local jsFn = trimmed:match("function%s+([%w_]+)%s*%((.-)%)")
					or trimmed:match("^export%s+const%s+([%w_]+)%s*=.*=>")
					or trimmed:match("^const%s+([%w_]+)%s*=.*=>")
				local tsIface = trimmed:match("interface%s+([%w_]+)") or trimmed:match("^export%s+interface%s+([%w_]+)")

				if pyFn then
					symbols[#symbols + 1] = { kind = "def", name = pyFn .. "(" .. tostring(trimmed:match("%((.-)%)" ) or "") .. ")", line = lineNo }
				elseif pyCls then
					symbols[#symbols + 1] = { kind = "class", name = pyCls, line = lineNo }
				elseif jsFn then
					symbols[#symbols + 1] = { kind = "fn", name = jsFn .. "(...)", line = lineNo }
				elseif tsIface then
					symbols[#symbols + 1] = { kind = "interface", name = tsIface, line = lineNo }
				end

				-- Detect `print(...)` or `console.log(...)`
				local printArgs = nil
				if lid == "python" then
					printArgs = trimmed:match("^print%s*%((.+)%)%s*$")
				else
					printArgs = trimmed:match("^console%.log%s*%((.+)%)%s*;?%s*$")
						or trimmed:match("^console%.info%s*%((.+)%)%s*;?%s*$")
				end

				if printArgs then
					local pieces = {}
					for arg in printArgs:gmatch("([^,]+)") do
						pieces[#pieces + 1] = tostring(evalSimpleExpr(arg, vars))
					end
					output[#output + 1] = table.concat(pieces, " ")
				else
					-- Variable assignment (`x = ...`, `const x: number = ...`, `let x = ...`)
					local varName, rhs
					if lid == "python" then
						varName, rhs = trimmed:match("^([%a_][%w_]*)%s*:%s*[%w_%[%],%s]+%s*=%s*(.+)$")
						if not varName then
							varName, rhs = trimmed:match("^([%a_][%w_]*)%s*=%s*(.+)$")
						end
					else
						varName, rhs = trimmed:match("^const%s+([%a_][%w_]*)[^=]*=%s*(.-);?$")
						if not varName then
							varName, rhs = trimmed:match("^let%s+([%a_][%w_]*)[^=]*=%s*(.-);?$")
						end
						if not varName then
							varName, rhs = trimmed:match("^var%s+([%a_][%w_]*)[^=]*=%s*(.-);?$")
						end
						if not varName then
							varName, rhs = trimmed:match("^([%a_][%w_]*)%s*=%s*(.-);?$")
						end
					end
					if varName and rhs and not rhs:find("=>", 1, true) then
						vars[varName] = evalSimpleExpr(rhs, vars)
					end
				end
			end
		end

		local varList = {}
		for _, k in ipairs(util.keys(vars)) do
			varList[#varList + 1] = { name = k, value = tostring(vars[k]) }
		end

		return {
			lang = languages.get(lid).name,
			output = output,
			variables = varList,
			symbols = symbols,
		}
	end

	return M
end
