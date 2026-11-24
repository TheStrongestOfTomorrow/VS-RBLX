-- VS-RBLX static checker: parses all Luau modules and validates the env.require graph.
package.path = "test/?.lua;" .. package.path
local luau = require("luau")

local function findLuaFiles(dir)
	local list = {}
	local pipe = io.popen('find "' .. dir .. '" -name "*.lua" -type f 2>/dev/null')
	if not pipe then return list end
	for line in pipe:lines() do
		local clean = line:gsub("\\", "/"):gsub("%s+$", "")
		if clean ~= "" then list[#list + 1] = clean end
	end
	pipe:close()
	table.sort(list)
	return list
end

local function readFile(path)
	local fh = io.open(path, "rb")
	if not fh then return nil end
	local data = fh:read("*a")
	fh:close()
	return data
end

local knownModules = {}
local srcFiles = findLuaFiles("src")
for _, path in ipairs(srcFiles) do
	local id = path:match("^src/(.+)%.lua$") or path:match(".*/src/(.+)%.lua$")
	if id then knownModules[id] = path end
end

local targetArg = arg and arg[1]
local checkList = {}
if targetArg then
	for _, path in ipairs(findLuaFiles(targetArg)) do
		local id = path:match("^src/(.+)%.lua$") or path:match(".*/src/(.+)%.lua$")
		checkList[#checkList + 1] = { path = path, id = id }
	end
else
	for _, path in ipairs(srcFiles) do
		local id = path:match("^src/(.+)%.lua$") or path:match(".*/src/(.+)%.lua$")
		checkList[#checkList + 1] = { path = path, id = id }
	end
	if readFile("init.lua") then
		checkList[#checkList + 1] = { path = "init.lua", id = nil }
	end
end

local failures = 0
print(string.format("VS-RBLX check: %d file(s)", #checkList))
for _, item in ipairs(checkList) do
	local body = readFile(item.path)
	local fn, errs = luau.load(body or "", item.path, { entry = item.id == nil })
	if not fn then
		failures = failures + 1
		print("FAIL " .. item.path)
		for _, e in ipairs(errs or {}) do
			print(string.format("  line %d: %s", e.line or 0, e.msg or "syntax error"))
		end
	else
		local missing = {}
		for _, dep in ipairs(luau.requires(body)) do
			if not knownModules[dep.path] then
				missing[#missing + 1] = string.format("line %d: unknown module '%s'", dep.line, dep.path)
			end
		end
		if #missing > 0 then
			failures = failures + 1
			print("FAIL " .. item.path)
			for _, m in ipairs(missing) do print("  " .. m) end
		else
			print("ok   " .. item.path)
		end
	end
end

print(string.format("Summary: %d checked, %d failures", #checkList, failures))
os.exit(failures > 0 and 1 or 0)
