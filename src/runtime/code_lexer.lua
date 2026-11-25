-- Incremental line-state multi-language syntax highlighter for VS-RBLX.
-- Raw document source is never mutated by RichText presentation.
return function(env)
	local languages = env.require("runtime/languages")
	local util = env.require("runtime/util")

	local BACKTICK = string.char(96)
	local M = {}

	function M.lines(source)
		local lines, starts, first = {}, {}, 1
		local clean = tostring(source or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
		local pos = 1
		while true do
			local nl = clean:find("\n", pos, true)
			if not nl then
				local seg = clean:sub(pos)
				lines[#lines + 1] = seg
				starts[#starts + 1] = first
				break
			end
			local seg = clean:sub(pos, nl - 1)
			lines[#lines + 1] = seg
			starts[#starts + 1] = first
			first = first + #seg + 1
			pos = nl + 1
		end
		if #lines == 0 then
			lines[1], starts[1] = "", 1
		end
		return lines, starts
	end

	local function longBracketAt(text, at)
		local eq = text:match("^%[(=*)%[", at)
		if not eq then return nil, nil end
		return "]" .. eq .. "]", #eq + 2
	end

	local function lexMarkdownLine(text, state)
		local spans = {}
		if state == "fence" then
			if text:match("^%s*" .. BACKTICK .. BACKTICK .. BACKTICK) then
				spans[1] = { kind = "keyword", first = 1, last = #text }
				return spans, ""
			end
			if #text > 0 then
				spans[1] = { kind = "string", first = 1, last = #text }
			end
			return spans, "fence"
		end
		if text:match("^%s*" .. BACKTICK .. BACKTICK .. BACKTICK) then
			spans[1] = { kind = "keyword", first = 1, last = #text }
			return spans, "fence"
		end
		if text:match("^%s*#+%s") then
			spans[1] = { kind = "keyword", first = 1, last = #text }
			return spans, ""
		end
		if text:match("^%s*>") then
			spans[1] = { kind = "comment", first = 1, last = #text }
			return spans, ""
		end
		local i = 1
		while i <= #text do
			local ch = text:sub(i, i)
			if ch == BACKTICK then
				local stop = text:find(BACKTICK, i + 1, true)
				local last = stop or #text
				spans[#spans + 1] = { kind = "string", first = i, last = last }
				i = last + 1
			elseif ch == "*" and text:sub(i + 1, i + 1) == "*" then
				local stop = text:find("**", i + 2, true)
				local last = stop and (stop + 1) or #text
				spans[#spans + 1] = { kind = "type", first = i, last = last }
				i = last + 1
			elseif ch == "[" then
				local close = text:find(")", i + 1, true)
				if close and text:sub(i, close):find("%]%(") then
					spans[#spans + 1] = { kind = "call", first = i, last = close }
					i = close + 1
				else
					spans[#spans + 1] = { kind = "text", first = i, last = i }
					i = i + 1
				end
			else
				local prev = spans[#spans]
				if prev and prev.kind == "text" and prev.last + 1 == i then
					prev.last = i
				else
					spans[#spans + 1] = { kind = "text", first = i, last = i }
				end
				i = i + 1
			end
		end
		return spans, ""
	end

	function M.line(text, state, langId)
		local lang = languages.get(langId)
		state = state or ""
		if lang.id == "plaintext" then
			if #text == 0 then return {}, "" end
			return { { kind = "text", first = 1, last = #text } }, ""
		end
		if lang.markdownMode then
			return lexMarkdownLine(text, state)
		end

		local spans = {}
		local i = 1
		local len = #text

		local function add(kind, a, b)
			if b < a then
				i = a + 1
				return
			end
			local previous = spans[#spans]
			if previous and previous.kind == kind and previous.last + 1 == a then
				previous.last = b
			else
				spans[#spans + 1] = { kind = kind, first = a, last = b }
			end
			i = b + 1
		end

		local lineCom = lang.lineComment
		local blockOpen = lang.blockComment and lang.blockComment[1] or nil
		local blockClose = lang.blockComment and lang.blockComment[2] or nil

		if state == "" and lang.preprocessor and text:match("^%s*#[%a_]+") then
			add("decorator", 1, len)
			return spans, ""
		end

		while i <= len do
			if state ~= "" then
				local kind = state:sub(1, 1) == "c" and "comment" or "string"
				local closeSeq = state:sub(2)
				local stop = text:find(closeSeq, i, true)
				if stop then
					add(kind, i, stop + #closeSeq - 1)
					state = ""
				else
					add(kind, i, len)
				end
			else
				local ch = text:sub(i, i)
				if lang.id == "luau" and blockOpen and text:sub(i, i + 1) == "--" then
					local closeBr, width = longBracketAt(text, i + 2)
					if closeBr then
						local stop = text:find(closeBr, i + 2 + width, true)
						if stop then
							add("comment", i, stop + #closeBr - 1)
						else
							add("comment", i, len)
							state = "c" .. closeBr
						end
					else
						add("comment", i, len)
					end
				elseif blockOpen and text:sub(i, i + #blockOpen - 1) == blockOpen then
					local stop = text:find(blockClose, i + #blockOpen, true)
					if stop then
						add("comment", i, stop + #blockClose - 1)
					else
						add("comment", i, len)
						state = "c" .. blockClose
					end
				elseif lineCom and text:sub(i, i + #lineCom - 1) == lineCom then
					add("comment", i, len)
				elseif lang.tripleStrings and (text:sub(i, i + 2) == '"""' or text:sub(i, i + 2) == "'''") then
					local quote3 = text:sub(i, i + 2)
					local stop = text:find(quote3, i + 3, true)
					if stop then
						add("string", i, stop + 2)
					else
						add("string", i, len)
						state = "s" .. quote3
					end
				elseif lang.longStrings and ch == "[" and longBracketAt(text, i) then
					local closeBr, width = longBracketAt(text, i)
					local stop = text:find(closeBr, i + width, true)
					if stop then
						add("string", i, stop + #closeBr - 1)
					else
						add("string", i, len)
						state = "s" .. closeBr
					end
				elseif ch == '"' or ch == "'" or (lang.templateStrings and ch == BACKTICK) then
					local j = i + 1
					while j <= len do
						local cj = text:sub(j, j)
						if cj == "\\" then
							j = j + 2
						elseif cj == ch then
							j = j + 1
							break
						else
							j = j + 1
						end
					end
					local endIdx = math.min(len, j - 1)
					local isProp = false
					if lang.jsonMode and ch == '"' then
						if text:match("^%s*:", endIdx + 1) then isProp = true end
					end
					if ch == BACKTICK and endIdx == len and text:sub(len, len) ~= BACKTICK then
						state = "s" .. BACKTICK
					end
					add(isProp and "property" or "string", i, endIdx)
				elseif lang.decorators and (ch == "@" or (lang.id == "rust" and text:sub(i, i + 1) == "#[")) then
					local matchEnd = text:match("^@[%w_%.]+()", i) or text:match("^#%[[^%]]*%]?()", i)
					if matchEnd then
						add("decorator", i, matchEnd - 1)
					else
						add("text", i, i)
					end
				elseif lang.markupMode and (ch == "<" or ch == ">") then
					local tagMatch = text:match("^</?[%w_%-:]+()", i)
					if tagMatch then
						add("tag", i, tagMatch - 1)
					else
						add("tag", i, i)
					end
				elseif lang.jsonMode and i == 1 and text:match("^%s*[%w_%-%.]+%s*[:=]") then
					local keyEnd = text:match("^%s*[%w_%-%.]+()", 1)
					add("property", 1, keyEnd - 1)
				elseif ch:match("[%a_]") then
					local word = text:match("^[%a_][%w_%-]*", i)
					if not lang.markupMode and lang.id ~= "css" then
						word = text:match("^[%a_][%w_]*", i)
					end
					local lookup = lang.caseInsensitive and word:lower() or word
					local afterIdx = i + #word
					local isCall = text:match("^%s*[%(%!]", afterIdx) ~= nil
					local kind = "text"
					if lang.keywords[lookup] then
						kind = "keyword"
					elseif lang.types and lang.types[lookup] then
						kind = "type"
					elseif lang.builtins and lang.builtins[lookup] then
						kind = "builtin"
					elseif lang.markupMode and text:match("^%s*=", afterIdx) then
						kind = "property"
					elseif isCall then
						kind = "call"
					end
					add(kind, i, i + #word - 1)
				elseif ch:match("%d") or (ch == "." and text:sub(i + 1, i + 1):match("%d")) then
					local num = text:match("^0[xX][%x]+", i)
						or text:match("^%d+%.?%d*[eE][%+%-]?%d+", i)
						or text:match("^%.%d+", i)
						or text:match("^%d+%.?%d*", i)
					if num and num:sub(-1) == "." and text:sub(i + #num, i + #num) == "." then
						num = num:sub(1, -2)
					end
					add("number", i, i + #(num or ch) - 1)
				else
					add("text", i, i)
				end
			end
		end
		return spans, state
	end

	local TODO_TAG_KIND = {
		TODO = "todo_tag",
		FIXME = "todo_fixme",
		BUG = "todo_fixme",
		HACK = "todo_tag",
		NOTE = "todo_note",
	}

	local function splitCommentTodoSpans(text, spans)
		if not spans or #spans == 0 then return spans end
		local hasComment = false
		for i = 1, #spans do
			if spans[i].kind == "comment" then
				hasComment = true
				break
			end
		end
		if not hasComment then return spans end

		local out = {}
		for idx = 1, #spans do
			local sp = spans[idx]
			if sp.kind ~= "comment" then
				out[#out + 1] = sp
			else
				local cursor = sp.first
				local stopAt = sp.last
				local scanPos = cursor
				while scanPos <= stopAt do
					local mStart, mEnd, rawTag = text:find("([%a]+)", scanPos)
					if not mStart or mStart > stopAt then
						break
					end
					if mEnd > stopAt then
						mEnd = stopAt
						rawTag = text:sub(mStart, mEnd)
					end
					local tagKind = TODO_TAG_KIND[rawTag:upper()]
					local prevCh = mStart > 1 and text:sub(mStart - 1, mStart - 1) or " "
					local nextCh = mEnd < #text and text:sub(mEnd + 1, mEnd + 1) or ""
					local validBoundary = (not prevCh:match("[%w_]"))
						and (nextCh == ":" or nextCh == "(" or nextCh == " " or nextCh == "-" or rawTag == rawTag:upper())
					if tagKind and validBoundary then
						local tagEnd = mEnd
						if text:sub(tagEnd + 1, tagEnd + 1) == "(" then
							local closeParen = text:find(")", tagEnd + 2, true)
							if closeParen and closeParen <= stopAt and closeParen - tagEnd <= 24 then
								tagEnd = closeParen
							end
						end
						if tagEnd < stopAt and text:sub(tagEnd + 1, tagEnd + 1) == ":" then
							tagEnd = tagEnd + 1
						end
						if mStart > cursor then
							out[#out + 1] = { kind = "comment", first = cursor, last = mStart - 1 }
						end
						out[#out + 1] = { kind = tagKind, first = mStart, last = tagEnd }
						cursor = tagEnd + 1
						scanPos = cursor
					else
						scanPos = mEnd + 1
					end
				end
				if cursor <= stopAt then
					out[#out + 1] = { kind = "comment", first = cursor, last = stopAt }
				end
			end
		end
		return out
	end

	local BRACKET_OPEN = { ["("] = true, ["["] = true, ["{"] = true }
	local BRACKET_CLOSE = { [")"] = "(", ["]"] = "[", ["}"] = "{" }
	local BRACKET_RICH_COLORS = {
		bracket1 = "#ffd700",
		bracket2 = "#da70d6",
		bracket3 = "#179fff",
		bracket_bad = "#f14c4c",
	}

	local function applyRainbowBracketsToLine(text, spans, startDepth)
		local depth = startDepth or 0
		if not spans or #spans == 0 then return spans, depth end

		local hasPlain = false
		for i = 1, #spans do
			if spans[i].kind == "text" then
				local slice = text:sub(spans[i].first, spans[i].last)
				if slice:find("[%(%)%[%]%{%}]") then
					hasPlain = true
					break
				end
			end
		end
		if not hasPlain then
			return spans, depth
		end

		local out = {}
		for idx = 1, #spans do
			local sp = spans[idx]
			if sp.kind ~= "text" then
				out[#out + 1] = sp
			else
				local runStart = sp.first
				for pos = sp.first, sp.last do
					local ch = text:sub(pos, pos)
					if BRACKET_OPEN[ch] then
						if pos > runStart then
							out[#out + 1] = { kind = "text", first = runStart, last = pos - 1 }
						end
						local level = (depth % 3) + 1
						out[#out + 1] = { kind = "bracket" .. tostring(level), first = pos, last = pos }
						depth = depth + 1
						runStart = pos + 1
					elseif BRACKET_CLOSE[ch] then
						if pos > runStart then
							out[#out + 1] = { kind = "text", first = runStart, last = pos - 1 }
						end
						if depth > 0 then
							depth = depth - 1
							local level = (depth % 3) + 1
							out[#out + 1] = { kind = "bracket" .. tostring(level), first = pos, last = pos }
						else
							out[#out + 1] = { kind = "bracket_bad", first = pos, last = pos }
						end
						runStart = pos + 1
					end
				end
				if runStart <= sp.last then
					out[#out + 1] = { kind = "text", first = runStart, last = sp.last }
				end
			end
		end
		return out, depth
	end

	function M.scan(source, langId, previous)
		local cleanLang = languages.get(langId).id
		if previous and previous.source == source and previous.langId == cleanLang then
			return previous
		end
		local lines, starts = M.lines(source)
		local prefix, suffix = 0, 0
		if previous and previous.langId == cleanLang then
			while prefix < math.min(#lines, #previous.lines) and lines[prefix + 1] == previous.lines[prefix + 1] do
				prefix = prefix + 1
			end
			while suffix < math.min(#lines, #previous.lines) - prefix
				and lines[#lines - suffix] == previous.lines[#previous.lines - suffix] do
				suffix = suffix + 1
			end
		end
		local result = {
			source = source,
			langId = cleanLang,
			lines = lines,
			starts = starts,
			spans = {},
			states = {},
			depths = {},
		}
		local state = ""
		local bracketDepth = 0
		for i = 1, #lines do
			local oldIndex = nil
			if previous and previous.langId == cleanLang then
				if i <= prefix then
					oldIndex = i
				elseif i > #lines - suffix then
					oldIndex = i + #previous.lines - #lines
				end
			end
			local prevEndState = (oldIndex and oldIndex > 1) and previous.states[oldIndex - 1] or ""
			local prevEndDepth = (oldIndex and oldIndex > 1 and previous.depths) and previous.depths[oldIndex - 1] or 0
			if oldIndex and prevEndState == state and prevEndDepth == bracketDepth then
				result.spans[i] = previous.spans[oldIndex]
				state = previous.states[oldIndex]
				bracketDepth = (previous.depths and previous.depths[oldIndex]) or bracketDepth
			else
				local rawSpans
				rawSpans, state = M.line(lines[i], state, cleanLang)
				local withTodo = splitCommentTodoSpans(lines[i], rawSpans)
				result.spans[i], bracketDepth = applyRainbowBracketsToLine(lines[i], withTodo, bracketDepth)
			end
			result.states[i] = state
			result.depths[i] = bracketDepth
		end
		return result
	end

	local TODO_RICH_COLORS = {
		todo_tag = "#ffcc00",
		todo_fixme = "#f14c4c",
		todo_note = "#4fc1ff",
	}

	function M.rich(line, spans, colors, opts)
		if #line == 0 then return "" end
		local useRainbow = not (opts and opts.rainbow == false)
		local out = {}
		for _, span in ipairs(spans or {}) do
			local seg = util.escapeRichText(line:sub(span.first, span.last))
			local todoHex = TODO_RICH_COLORS[span.kind]
			local bracketHex = useRainbow and BRACKET_RICH_COLORS[span.kind] or nil
			if todoHex then
				out[#out + 1] = '<b><font color="' .. todoHex .. '">' .. seg .. "</font></b>"
			elseif bracketHex then
				out[#out + 1] = '<font color="' .. bracketHex .. '">' .. seg .. "</font>"
			else
				local hex = colors and colors[span.kind]
				if hex and span.kind ~= "text" then
					out[#out + 1] = '<font color="' .. hex .. '">' .. seg .. "</font>"
				else
					out[#out + 1] = seg
				end
			end
		end
		return table.concat(out)
	end

	return M
end
