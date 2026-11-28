-- Bundler: src/**/*.lua + init.lua -> dist/vsrblx.lua, the single file a user runs.
--
--   luajit tools/bundle.lua
--
-- Follows the ProjectUAI single-chunk architecture:
--   1. Declares `local __VSRBLX_BUILD` and `local __VSRBLX_MODULES = {}` at top of chunk
--   2. Registers each `src/<id>.lua` factory via `__VSRBLX_MODULES["<id>"] = (function() ... end)()`
--   3. Emits `init.lua` at the bottom of the same chunk so `local MODULES = __VSRBLX_MODULES`
--      connects directly in lexical scope with zero external file/network fetches.
package.path = "test/?.lua;" .. package.path
local luau = require("luau")
local buildIdFn = dofile("tools/build_id.lua")

local checkOnly = false
for _, option in ipairs(arg or {}) do
	if option == "--check" then checkOnly = true end
end

local function listLua(dir)
	local out = {}
	local pipe = io.popen('find "' .. dir .. '" -name "*.lua" -type f 2>/dev/null')
	if not pipe then return out end
	for line in pipe:lines() do
		local clean = line:gsub("\\", "/"):gsub("%s+$", "")
		if clean ~= "" then out[#out + 1] = clean end
	end
	pipe:close()
	table.sort(out)
	return out
end

local function readAll(path)
	local fh = io.open(path, "rb")
	if not fh then return nil end
	local body = fh:read("*a")
	fh:close()
	return body
end

local function writeAll(path, body)
	local fh = io.open(path, "wb")
	if not fh then return false, "unable to write " .. path end
	fh:write(body)
	fh:close()
	return true
end

-- Remove indentation only while lexically in code. This keeps every physical newline
-- (and therefore manifest source line mapping) but avoids oversized executor HttpGet
-- payloads. Whitespace inside quoted strings, long strings, and long comments is exact.
local function stripCodeIndent(source)
	local out = {}
	local i, n = 1, #source
	local lineStart = true
	local state = "code"
	local quote = nil
	local longEq = nil

	local function longOpen(pos)
		if source:sub(pos, pos) ~= "[" then return nil end
		local j = pos + 1
		while source:sub(j, j) == "=" do j = j + 1 end
		if source:sub(j, j) == "[" then return source:sub(pos + 1, j - 1), j - pos + 1 end
		return nil
	end

	while i <= n do
		if lineStart and state == "code" then
			while source:sub(i, i) == " " or source:sub(i, i) == "\t" do i = i + 1 end
			lineStart = false
			if i > n then break end
		end

		local ch = source:sub(i, i)
		local next2 = source:sub(i, i + 1)
		if state == "code" then
			if ch == "\n" then
				out[#out + 1] = ch
				i = i + 1
				lineStart = true
			elseif next2 == "--" then
				out[#out + 1] = "--"
				i = i + 2
				local eq, width = longOpen(i)
				if eq ~= nil then
					out[#out + 1] = source:sub(i, i + width - 1)
					i = i + width
					longEq = eq
					state = "long_comment"
				else
					state = "line_comment"
				end
			elseif ch == "'" or ch == '"' then
				out[#out + 1] = ch
				quote = ch
				state = "quoted"
				i = i + 1
			elseif ch == "[" then
				local eq, width = longOpen(i)
				if eq ~= nil then
					out[#out + 1] = source:sub(i, i + width - 1)
					i = i + width
					longEq = eq
					state = "long_string"
				else
					out[#out + 1] = ch
					i = i + 1
				end
			else
				out[#out + 1] = ch
				i = i + 1
			end
		elseif state == "line_comment" then
			if ch == "\n" then
				out[#out + 1] = ch
				i = i + 1
				state = "code"
				lineStart = true
			else
				out[#out + 1] = ch
				i = i + 1
			end
		elseif state == "quoted" then
			out[#out + 1] = ch
			i = i + 1
			if ch == "\\" and i <= n then
				out[#out + 1] = source:sub(i, i)
				if source:sub(i, i) == "\n" then lineStart = false end
				i = i + 1
			elseif ch == quote then
				state = "code"
			end
		elseif state == "long_string" or state == "long_comment" then
			local close = "]" .. longEq .. "]"
			if source:sub(i, i + #close - 1) == close then
				out[#out + 1] = close
				i = i + #close
				state = "code"
			else
				out[#out + 1] = ch
				i = i + 1
				if ch == "\n" then lineStart = false end
			end
		end
	end
	return table.concat(out)
end

local indentFixture = '  local quoted = "\\n\\tvalue"\n\tlocal long = [=[\n  keep this literal indent\n]=]\n\t--[=[\n  keep this comment body\n]=]\n\treturn quoted\n'
local compactFixture = 'local quoted = "\\n\\tvalue"\nlocal long = [=[\n  keep this literal indent\n]=]\n--[=[\n  keep this comment body\n]=]\nreturn quoted\n'
if stripCodeIndent(indentFixture) ~= compactFixture then
	io.stderr:write("Bundle indentation compactor changed string/comment content.\n")
	os.exit(1)
end

local modules = {}
local totalBytes = 0
for _, path in ipairs(listLua("src")) do
	local id = path:match("^src/(.+)%.lua$") or path:match(".*/src/(.+)%.lua$")
	if id then
		local src = (readAll(path) or ""):gsub("\r\n", "\n"):gsub("%s+$", "")
		local ok, errs = luau.load(src, id)
		if not ok then
			io.stderr:write("Syntax error in " .. id .. ":\n")
			for _, e in ipairs(errs or {}) do
				io.stderr:write(string.format("  line %d: %s\n", e.line or 0, e.msg or "?"))
			end
			os.exit(1)
		end
		local mod = { id = id, source = src, bytes = #src }
		mod.hash = buildIdFn("module", { mod }, "")
		modules[#modules + 1] = mod
		totalBytes = totalBytes + #src
	end
end

if #modules == 0 then
	io.stderr:write("No modules found under src/\n")
	os.exit(1)
end

local boot = (readAll("init.lua") or ""):gsub("\r\n", "\n"):gsub("%s+$", "")
if boot == "" then
	io.stderr:write("init.lua is missing\n")
	os.exit(1)
end
local bootOk, bootErrs = luau.load(boot, "init.lua", { entry = true })
if not bootOk then
	io.stderr:write("Syntax error in init.lua:\n")
	for _, e in ipairs(bootErrs or {}) do
		io.stderr:write(string.format("  line %d: %s\n", e.line or 0, e.msg or "?"))
	end
	os.exit(1)
end

local version = boot:match('local VERSION = "([^"]+)"')
if not version then
	io.stderr:write('init.lua must declare local VERSION = "<semver>"\n')
	os.exit(1)
end
local buildId = buildIdFn(version, modules, boot)

local lines = {}
local lineCursor = 1
local function emit(block)
	lines[#lines + 1] = block
	local startLine = lineCursor
	local _, count = block:gsub("\n", "")
	lineCursor = lineCursor + count + 1
	return startLine, lineCursor - 1
end

emit("-- VS-RBLX " .. version .. " -- Visual Studio Code for Roblox (100% Luau).")
emit("-- Build " .. buildId)
emit("--")
emit("-- Generated by tools/bundle.lua. Do not edit: change src/ and rebuild.")
emit(string.format("-- %d modules, %d bytes of source.", #modules, totalBytes))
emit("--")
emit("-- Usage:")
emit('--     loadstring(game:HttpGet("https://raw.githubusercontent.com/TheStrongestOfTomorrow/VS-RBLX/main/dist/vsrblx.lua"))()')
emit("--")
for _, mod in ipairs(modules) do
	emit(string.format("--   %-28s %6d bytes  %s", mod.id, mod.bytes, mod.hash))
end
emit("")
emit(string.format("local __VSRBLX_BUILD = %q", buildId))
emit("local __VSRBLX_MODULES = {}")
emit("")

for _, mod in ipairs(modules) do
	emit("-- " .. ("="):rep(74))
	emit("-- " .. mod.id)
	emit("-- " .. ("="):rep(74))
	emit(string.format('__VSRBLX_MODULES[%q] = (function()', mod.id))
	mod.startLine, mod.endLine = emit(stripCodeIndent(mod.source))
	emit("end)()")
	emit("")
end

emit("-- " .. ("="):rep(74))
emit("-- bootstrap")
emit("-- " .. ("="):rep(74))
local bootStart, bootEnd = emit(stripCodeIndent(boot))
emit("")

local bundleText = table.concat(lines, "\n")
local localScriptText = "--!nocheck\n-- VS-RBLX Standalone LocalScript (StarterPlayerScripts / StarterGui)\n" .. bundleText
local MAX_LOADER_BYTES = 990000
if #bundleText > MAX_LOADER_BYTES then
	io.stderr:write(string.format(
		"Bundle is %d bytes; the direct HttpGet/loadstring safety budget is %d bytes. Reduce source or improve bundle compaction before publishing.\n",
		#bundleText,
		MAX_LOADER_BYTES
	))
	os.exit(1)
end

local parsedOk, parsedErrs = luau.load(bundleText, "dist/vsrblx.lua", { entry = true })
if not parsedOk then
	io.stderr:write("Assembled bundle failed syntax check:\n")
	for _, e in ipairs(parsedErrs or {}) do
		io.stderr:write(string.format("  dist/vsrblx.lua:%d: %s\n", e.line or 0, e.msg or "?"))
	end
	os.exit(1)
end

local manifestParts = {
	'{"format":"vsrblx-build","version":1,',
	string.format('"buildId":%q,', buildId),
	string.format('"bootstrap":{"sourceStartLine":%d,"sourceEndLine":%d},', bootStart, bootEnd),
	'"modules":[',
}
for i, mod in ipairs(modules) do
	manifestParts[#manifestParts + 1] = (i > 1 and "," or "") .. string.format(
		'{"id":%q,"bytes":%d,"hash":%q,"sourceStartLine":%d,"sourceEndLine":%d}',
		mod.id, mod.bytes, mod.hash, mod.startLine, mod.endLine
	)
end
manifestParts[#manifestParts + 1] = "]}\n"
local manifestText = table.concat(manifestParts)

if checkOnly then
	for path, expected in pairs({
		["dist/vsrblx.lua"] = bundleText,
		["dist/vsrblx.localscript.lua"] = localScriptText,
		["dist/vsrblx.manifest.json"] = manifestText,
	}) do
		local cur = readAll(path)
		if not cur or cur:gsub("\r\n", "\n") ~= expected then
			io.stderr:write(path .. " is stale; run luajit tools/bundle.lua\n")
			os.exit(1)
		end
	end
	print("Bundle and manifest are up to date: " .. buildId)
	return
end

os.execute("mkdir -p dist")
assert(writeAll("dist/vsrblx.lua", bundleText))
assert(writeAll("dist/vsrblx.localscript.lua", localScriptText))
assert(writeAll("dist/vsrblx.manifest.json", manifestText))
print(string.format("dist/vsrblx.lua written: %d modules, %d bytes (%s)", #modules, #bundleText, buildId))
