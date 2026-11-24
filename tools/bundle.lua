-- VS-RBLX Bundler: compiles src/**/*.lua + init.lua into standalone Luau artifacts:
--   * dist/vsrblx.lua             (Executor loadstring bundle)
--   * dist/vsrblx.localscript.lua (Roblox Studio LocalScript bundle)
--   * dist/vsrblx.manifest.json   (Build hash and module line-range map)
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
		mod.hash = buildIdFn("mod", { mod }, "")
		modules[#modules + 1] = mod
		totalBytes = totalBytes + #src
	end
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

local version = boot:match('local VERSION = "([^"]+)"') or "1.0.0"
local buildId = buildIdFn(version, modules, boot)

local lines = {}
local lineCursor = 1
local function emit(block)
	lines[#lines + 1] = block
	local startLine = lineCursor
	local _, count = block:gsub("\n", "\n")
	lineCursor = lineCursor + count + 1
	return startLine, lineCursor - 1
end

emit("-- VS-RBLX v" .. version .. " | Visual Studio Code Clone in Roblox (100% Luau)")
emit("-- Build: " .. buildId)
emit(string.format("-- Modules: %d | Source size: %d bytes", #modules, totalBytes))
emit("--")
emit("-- Executor:")
emit('--   loadstring(game:HttpGet("https://raw.githubusercontent.com/TheStrongestOfTomorrow/VS-RBLX/main/dist/vsrblx.lua"))()')
emit("-- Roblox Studio:")
emit("--   Paste dist/vsrblx.localscript.lua inside StarterPlayer > StarterPlayerScripts")
emit("")
emit(string.format("local __VSRBLX_BUILD = %q", buildId))
emit("local __VSRBLX_MODULES = {}")
emit("")

for _, mod in ipairs(modules) do
	emit("-- [" .. mod.id .. "] (" .. mod.bytes .. " bytes)")
	emit(string.format('__VSRBLX_MODULES[%q] = (function()', mod.id))
	mod.startLine, mod.endLine = emit(mod.source)
	emit("end)()")
	emit("")
end

emit("-- [bootstrap]")
local bootStart, bootEnd = emit(boot)
emit("")

local bundleText = table.concat(lines, "\n")
local localScriptText = "--!nocheck\n-- VS-RBLX Standalone LocalScript (StarterPlayerScripts / StarterGui)\n" .. bundleText

local parsedOk, parsedErrs = luau.load(bundleText, "dist/vsrblx.lua", { entry = true })
if not parsedOk then
	io.stderr:write("Assembled bundle failed syntax validation:\n")
	for _, e in ipairs(parsedErrs or {}) do
		io.stderr:write(string.format("  line %d: %s\n", e.line or 0, e.msg or "?"))
	end
	os.exit(1)
end

local manifestParts = {
	'{"name":"VS-RBLX","version":' .. string.format("%q", version),
	',"buildId":' .. string.format("%q", buildId),
	string.format(',"bootstrap":{"startLine":%d,"endLine":%d},"modules":[', bootStart, bootEnd),
}
for i, mod in ipairs(modules) do
	manifestParts[#manifestParts + 1] = (i > 1 and "," or "") .. string.format(
		'{"id":%q,"bytes":%d,"hash":%q,"startLine":%d,"endLine":%d}',
		mod.id, mod.bytes, mod.hash, mod.startLine, mod.endLine
	)
end
manifestParts[#manifestParts + 1] = "]}\n"
local manifestText = table.concat(manifestParts)

if checkOnly then
	local cur = readAll("dist/vsrblx.lua")
	if not cur or cur:gsub("\r\n", "\n") ~= bundleText then
		io.stderr:write("dist/vsrblx.lua is out of date; run luajit tools/bundle.lua\n")
		os.exit(1)
	end
	print("Bundle is up to date: " .. buildId)
	return
end

os.execute("mkdir -p dist")
writeAll("dist/vsrblx.lua", bundleText)
writeAll("dist/vsrblx.localscript.lua", localScriptText)
writeAll("dist/vsrblx.manifest.json", manifestText)
print(string.format("Built dist/vsrblx.lua (%d modules, %d bytes, build %s)", #modules, #bundleText, buildId))
