-- Pure-Luau Monaco-style Smart Typing & Line Editing Engine (`src/runtime/editor_actions.lua`).
-- Powers auto-closing brackets/quotes, smart Enter auto-indent, Tab/Shift+Tab block indent,
-- Ctrl+/ line comment toggle, Alt+Up/Down move line, Shift+Alt+Down duplicate, Ctrl+Shift+K
-- delete line, and Ctrl+D / Ctrl+L word & line selection.
return function(env)
	local util = env.require("runtime/util")
	local languages = env.require("runtime/languages")

	local BACKTICK = string.char(96)

	local AUTO_PAIRS = {
		["("] = ")",
		["["] = "]",
		["{"] = "}",
		['"'] = '"',
		["'"] = "'",
		[BACKTICK] = BACKTICK,
	}

	local CLOSERS = {
		[")"] = "(",
		["]"] = "[",
		["}"] = "{",
		['"'] = '"',
		["'"] = "'",
		[BACKTICK] = BACKTICK,
	}

	local M = {
		pairs = AUTO_PAIRS,
		closers = CLOSERS,
	}

	-- Splits `source` into lines and returns line range `[startLine, endLine]` covered by `(cursor, selStart)`
	function M.lineSpanForOffsets(source, cursorOffset, selOffset)
		local text = tostring(source or "")
		local lines = util.lines(text)
		local starts = {}
		local pos = 1
		for i = 1, #lines do
			starts[i] = pos
			pos = pos + #lines[i] + 1
		end

		local function lineAt(offset)
			local clamped = util.clamp(tonumber(offset) or 1, 1, #text + 1)
			local ln = 1
			for i = 1, #starts do
				if starts[i] <= clamped then ln = i else break end
			end
			return ln
		end

		local cPos = util.clamp(tonumber(cursorOffset) or 1, 1, #text + 1)
		local sPos = (tonumber(selOffset) and tonumber(selOffset) > 0) and util.clamp(tonumber(selOffset), 1, #text + 1) or cPos
		local minOff = math.min(cPos, sPos)
		local maxOff = math.max(cPos, sPos)
		local firstLine = lineAt(minOff)
		local lastLine = lineAt(maxOff)
		if maxOff > minOff and maxOff == starts[lastLine] and lastLine > firstLine then
			lastLine = lastLine - 1
		end
		return lines, starts, firstLine, lastLine, minOff, maxOff
	end

	-- 1. Toggle Line Comment (`Ctrl+/`)
	function M.toggleComment(source, cursorOffset, selOffset, langId)
		local lang = languages.get(langId)
		local prefix = lang.lineComment
		local suffix = ""
		if not prefix or prefix == "" then
			if lang.id == "html" or lang.id == "markdown" then
				prefix, suffix = "<!-- ", " -->"
			elseif lang.blockComment then
				prefix = lang.blockComment[1] .. " "
				suffix = " " .. lang.blockComment[2]
			else
				prefix = "--"
			end
		else
			prefix = prefix .. " "
		end

		local rawPrefix = util.trim(prefix)
		local lines, starts, firstLine, lastLine = M.lineSpanForOffsets(source, cursorOffset, selOffset)

		local allCommented = true
		local hasNonEmpty = false
		for i = firstLine, lastLine do
			local trimmed = util.trim(lines[i])
			if trimmed ~= "" then
				hasNonEmpty = true
				if not util.startsWith(trimmed, rawPrefix) then
					allCommented = false
					break
				end
			end
		end

		local deltaFirst = 0
		for i = firstLine, lastLine do
			local ln = lines[i]
			if allCommented and hasNonEmpty then
				local lead = ln:match("^(%s*)") or ""
				local rest = ln:sub(#lead + 1)
				if util.startsWith(rest, prefix) then
					rest = rest:sub(#prefix + 1)
				elseif util.startsWith(rest, rawPrefix) then
					rest = rest:sub(#rawPrefix + 1)
				end
				if suffix ~= "" and util.endsWith(rest, suffix) then
					rest = rest:sub(1, #rest - #suffix)
				end
				local updated = lead .. rest
				if i == firstLine then deltaFirst = #updated - #ln end
				lines[i] = updated
			elseif ln:find("%S") or firstLine == lastLine then
				local lead = ln:match("^(%s*)") or ""
				local rest = ln:sub(#lead + 1)
				local updated = lead .. prefix .. rest .. suffix
				if i == firstLine then deltaFirst = #updated - #ln end
				lines[i] = updated
			end
		end

		local result = table.concat(lines, "\n")
		local nextCursor = util.clamp((tonumber(cursorOffset) or 1) + deltaFirst, 1, #result + 1)
		return result, nextCursor
	end

	-- 2. Indent / Outdent Single Line or Selected Block (`Tab` / `Shift+Tab`)
	function M.indentBlock(source, cursorOffset, selOffset, tabSize, insertSpaces, outdent)
		local unit = (insertSpaces ~= false) and string.rep(" ", tonumber(tabSize) or 4) or "\t"
		local tSize = tonumber(tabSize) or 4
		local hasSel = tonumber(selOffset) and tonumber(selOffset) > 0 and tonumber(selOffset) ~= tonumber(cursorOffset)

		if not hasSel and not outdent then
			local text = tostring(source or "")
			local c = util.clamp(tonumber(cursorOffset) or 1, 1, #text + 1)
			local updated = text:sub(1, c - 1) .. unit .. text:sub(c)
			return updated, c + #unit, -1
		end

		local lines, starts, firstLine, lastLine, minOff, maxOff = M.lineSpanForOffsets(source, cursorOffset, selOffset)
		local totalDelta = 0
		local firstDelta = 0

		for i = firstLine, lastLine do
			local ln = lines[i]
			local updated = ln
			if outdent then
				if util.startsWith(ln, "\t") then
					updated = ln:sub(2)
				else
					local spaces = #(ln:match("^( +)") or "")
					local strip = math.min(spaces, tSize)
					updated = ln:sub(strip + 1)
				end
			else
				updated = unit .. ln
			end
			local d = #updated - #ln
			if i == firstLine then firstDelta = d end
			totalDelta = totalDelta + d
			lines[i] = updated
		end

		local result = table.concat(lines, "\n")
		if hasSel then
			return result, math.max(1, maxOff + totalDelta), math.max(1, minOff + firstDelta)
		end
		return result, util.clamp((tonumber(cursorOffset) or 1) + firstDelta, 1, #result + 1), -1
	end

	-- 3. Move Line(s) Up or Down (`Alt+Up` / `Alt+Down`)
	function M.moveLines(source, cursorOffset, selOffset, direction)
		local lines, starts, firstLine, lastLine = M.lineSpanForOffsets(source, cursorOffset, selOffset)
		local colOffset = math.max(0, (tonumber(cursorOffset) or 1) - starts[firstLine])

		if direction < 0 then
			if firstLine <= 1 then return source, cursorOffset, selOffset end
			local above = table.remove(lines, firstLine - 1)
			table.insert(lines, lastLine, above)
			firstLine = firstLine - 1
		else
			if lastLine >= #lines then return source, cursorOffset, selOffset end
			local below = table.remove(lines, lastLine + 1)
			table.insert(lines, firstLine, below)
			firstLine = firstLine + 1
		end

		local result = table.concat(lines, "\n")
		local _, newStarts = M.lineSpanForOffsets(result, 1, -1)
		local newCursor = math.min(#result + 1, newStarts[firstLine] + colOffset)
		return result, newCursor, -1
	end

	-- 4. Duplicate Line(s) Down or Up (`Shift+Alt+Down` / `Shift+Alt+Up`)
	function M.duplicateLines(source, cursorOffset, selOffset, direction)
		local lines, starts, firstLine, lastLine = M.lineSpanForOffsets(source, cursorOffset, selOffset)
		local colOffset = math.max(0, (tonumber(cursorOffset) or 1) - starts[firstLine])
		local block = {}
		for i = firstLine, lastLine do
			block[#block + 1] = lines[i]
		end

		local insertPos = direction < 0 and firstLine or (lastLine + 1)
		for idx = #block, 1, -1 do
			table.insert(lines, insertPos, block[idx])
		end

		local targetLine = direction < 0 and firstLine or (lastLine + 1)
		local result = table.concat(lines, "\n")
		local _, newStarts = M.lineSpanForOffsets(result, 1, -1)
		local newCursor = math.min(#result + 1, newStarts[targetLine] + colOffset)
		return result, newCursor
	end

	-- 5. Delete Line (`Ctrl+Shift+K`)
	function M.deleteLines(source, cursorOffset, selOffset)
		local lines, _, firstLine, lastLine = M.lineSpanForOffsets(source, cursorOffset, selOffset)
		for i = lastLine, firstLine, -1 do
			table.remove(lines, i)
		end
		if #lines == 0 then lines[1] = "" end
		local result = table.concat(lines, "\n")
		local _, newStarts = M.lineSpanForOffsets(result, 1, -1)
		local target = math.min(firstLine, #lines)
		return result, newStarts[target] or 1
	end

	-- 6. Select Word at Cursor (`Ctrl+D`) & Select Full Line (`Ctrl+L`)
	function M.wordAtCursor(source, cursorOffset)
		local text = tostring(source or "")
		if text == "" then return 1, 1, "" end
		local pos = util.clamp(tonumber(cursorOffset) or 1, 1, #text)
		if not text:sub(pos, pos):match("[%w_]") and pos > 1 and text:sub(pos - 1, pos - 1):match("[%w_]") then
			pos = pos - 1
		end
		if not text:sub(pos, pos):match("[%w_]") then
			return pos, pos, ""
		end
		local s = pos
		while s > 1 and text:sub(s - 1, s - 1):match("[%w_]") do s = s - 1 end
		local e = pos
		while e < #text and text:sub(e + 1, e + 1):match("[%w_]") do e = e + 1 end
		return s, e + 1, text:sub(s, e)
	end

	function M.lineBoundsAtCursor(source, cursorOffset)
		local lines, starts, firstLine = M.lineSpanForOffsets(source, cursorOffset, -1)
		local s = starts[firstLine] or 1
		local e = s + #(lines[firstLine] or "")
		if firstLine < #lines then e = e + 1 end
		return s, e
	end

	-- 7. Smart Typing Post-Processor: detects single-char insertions (auto-close pairs,
	-- overtype, smart Enter auto-indent, and empty-pair Backspace) between `prevText` and `newText`.
	local function shouldIncreaseIndent(lineBeforeCursor, langId)
		local trimmed = util.trim(lineBeforeCursor)
		if trimmed == "" then return false end
		local lastChar = trimmed:sub(-1)
		if lastChar == "{" or lastChar == "(" or lastChar == "[" or lastChar == ":" then
			return true
		end
		if langId == "luau" or langId == "lua" then
			if trimmed:match("%f[%w]then$")
				or trimmed:match("%f[%w]do$")
				or trimmed:match("%f[%w]repeat$")
				or trimmed:match("%f[%w]else$")
				or trimmed:match("function%s*[%w_%.:]*%s*%b()$") then
				return true
			end
		end
		return false
	end

	function M.applySmartTyping(prevText, newText, newCursor, opts)
		opts = opts or {}
		if type(prevText) ~= "string" or type(newText) ~= "string" then
			return newText, newCursor
		end

		local lenDiff = #newText - #prevText
		local unit = (opts.insertSpaces ~= false) and string.rep(" ", tonumber(opts.tabSize) or 4) or "\t"

		-- Case A: Single-character Backspace inside an empty auto-pair `(|)` -> deletes both!
		if lenDiff == -1 and opts.autoClosingBrackets ~= false then
			local delPos = util.clamp((tonumber(newCursor) or 1), 1, #prevText)
			local deletedChar = prevText:sub(delPos, delPos)
			local expectedCloser = AUTO_PAIRS[deletedChar]
			if expectedCloser and prevText:sub(delPos + 1, delPos + 1) == expectedCloser then
				local verify = prevText:sub(1, delPos - 1) .. prevText:sub(delPos + 1)
				if verify == newText then
					local stripped = newText:sub(1, delPos - 1) .. newText:sub(delPos + 1)
					return stripped, delPos
				end
			end
			return newText, newCursor
		end

		if lenDiff ~= 1 then
			return newText, newCursor
		end

		local insPos = util.clamp((tonumber(newCursor) or 1) - 1, 1, #newText)
		local typed = newText:sub(insPos, insPos)
		local verifyPrev = newText:sub(1, insPos - 1) .. newText:sub(insPos + 1)
		if verifyPrev ~= prevText then
			return newText, newCursor
		end

		local charAfter = newText:sub(insPos + 1, insPos + 1)
		local charBefore = insPos > 1 and newText:sub(insPos - 1, insPos - 1) or ""

		-- Case B: Tab key typed inside TextBox -> convert literal `\t` to spaces if insertSpaces
		if typed == "\t" and opts.insertSpaces ~= false then
			local expanded = newText:sub(1, insPos - 1) .. unit .. newText:sub(insPos + 1)
			return expanded, insPos + #unit
		end

		-- Case C: Smart Enter auto-indent (+ `{|}` two-line block expansion)
		if typed == "\n" and opts.autoIndent ~= false then
			local beforeNewline = newText:sub(1, insPos - 1)
			local lastNl = beforeNewline:match(".*()\n")
			local currentLine = lastNl and beforeNewline:sub(lastNl + 1) or beforeNewline
			local baseIndent = currentLine:match("^([ \t]*)") or ""
			local addExtra = shouldIncreaseIndent(currentLine, opts.langId or "luau")

			if charBefore == "{" and charAfter == "}"
				or charBefore == "(" and charAfter == ")"
				or charBefore == "[" and charAfter == "]" then
				local innerIndent = baseIndent .. unit
				local expanded = newText:sub(1, insPos)
					.. innerIndent
					.. "\n"
					.. baseIndent
					.. newText:sub(insPos + 1)
				return expanded, insPos + 1 + #innerIndent
			end

			local nextIndent = addExtra and (baseIndent .. unit) or baseIndent
			if nextIndent ~= "" then
				local indented = newText:sub(1, insPos) .. nextIndent .. newText:sub(insPos + 1)
				return indented, insPos + 1 + #nextIndent
			end
			return newText, newCursor
		end

		-- Case D: Auto-closing brackets & quotes + smart overtype
		if opts.autoClosingBrackets ~= false then
			-- Smart overtype over an already-present closing delimiter
			if CLOSERS[typed] and charAfter == typed then
				-- Only overtype quotes if not preceded by backslash
				if charBefore ~= "\\" then
					return prevText, insPos + 1
				end
			end

			local closer = AUTO_PAIRS[typed]
			if closer then
				local nextIsWord = charAfter ~= "" and charAfter:match("[%w_]") ~= nil
				local isQuote = (typed == '"' or typed == "'" or typed == BACKTICK)
				local prevIsWordOrQuote = isQuote and (charBefore:match("[%w_\"'`\\]") ~= nil)
				if not nextIsWord and not prevIsWordOrQuote then
					local paired = newText:sub(1, insPos) .. closer .. newText:sub(insPos + 1)
					return paired, insPos + 1
				end
			end
		end

		return newText, newCursor
	end

	return M
end
