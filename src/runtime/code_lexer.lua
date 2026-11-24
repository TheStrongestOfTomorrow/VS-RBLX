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
		}
		local state = ""
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
			if oldIndex and prevEndState == state then
				result.spans[i] = previous.spans[oldIndex]
				state = previous.states[oldIndex]
			else
				result.spans[i], state = M.line(lines[i], state, cleanLang)
			end
			result.states[i] = state
		end
		return result
	end

	function M.rich(line, spans, colors)
		if #line == 0 then return "" end
		local out = {}
		for _, span in ipairs(spans or {}) do
			local seg = util.escapeRichText(line:sub(span.first, span.last))
			local hex = colors and colors[span.kind]
			if hex and span.kind ~= "text" then
				out[#out + 1] = '<font color="' .. hex .. '">' .. seg .. "</font>"
			else
				out[#out + 1] = seg
			end
		end
		return table.concat(out)
	end

	return M
end
