-- Deep LSP-Style IntelliSense Engine:
--   1. Live Roblox API + live DataModel Instance child introspection (`game`, `workspace`, Services, Classes, Enums)
--   2. Local variable type inference (`GetService`, `Instance.new`, chained properties, `require(...)`)
--   3. Cross-file workspace symbol indexing (`require("...")` module exports & file path completion)
--   4. Parameter Signature Help (`M.signatureHelp`) with active parameter highlighting
--   5. Rich Hover Documentation (`M.hover`) & Cross-File Go-to-Definition (`M.findDefinition`)
--   6. Expandable `$0` cursor-stop snippet templates + Community Extension snippet packs
return function(env)
	local languages = env.require("runtime/languages")
	local apiDb = env.require("runtime/roblox_api_db")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")
	local util = env.require("runtime/util")

	local M = {}

	-- Dynamic snippet packs installed via Community Extension Hub (`packId -> array of snippets`)
	local customSnippetPacks = {}

	function M.registerSnippetPack(packId, list)
		if type(packId) ~= "string" or type(list) ~= "table" then return false end
		customSnippetPacks[packId] = list
		return true
	end

	function M.unregisterSnippetPack(packId)
		customSnippetPacks[packId] = nil
	end

	-- Expand `$0` caret marker inside an insert template
	function M.expandInsert(rawInsert)
		local text = tostring(rawInsert or "")
		local marker = text:find("%$0")
		if marker then
			local cleaned = text:sub(1, marker - 1) .. text:sub(marker + 2)
			return cleaned, marker - 1
		end
		return text, #text
	end

	function M.currentWord(source, cursorOffset)
		local text = tostring(source or "")
		local pos = util.clamp((tonumber(cursorOffset) or 1) - 1, 0, #text)
		if pos <= 0 then return "", 1, 0 end
		local startIdx = pos
		while startIdx >= 1 and text:sub(startIdx, startIdx):match("[%w_]") do
			startIdx = startIdx - 1
		end
		startIdx = startIdx + 1
		if startIdx > pos then return "", pos + 1, pos end
		return text:sub(startIdx, pos), startIdx, pos
	end

	-- Read latest content of a workspace path (prefers open unsaved editor buffer over disk)
	local function readLatestFile(relPath)
		local norm = tostring(relPath or ""):gsub("^/+", "")
		if norm == "" then return nil end
		for _, doc in ipairs(codeStore.tabs or {}) do
			if doc.path == norm then
				return doc.content
			end
		end
		if workspaceFs.exists(norm) and not workspaceFs.isDir(norm) then
			return workspaceFs.readFile(norm)
		end
		return nil
	end

	function M.listWorkspaceScriptPaths()
		local seen = {}
		local out = {}
		for _, doc in ipairs(codeStore.tabs or {}) do
			if doc.path and doc.path ~= "" and not doc.untitled and not seen[doc.path] then
				seen[doc.path] = true
				out[#out + 1] = doc.path
			end
		end
		local ok, entries = pcall(function() return workspaceFs.allFiles("") end)
		if ok and type(entries) == "table" then
			for _, p in ipairs(entries) do
				if type(p) == "string" and p ~= "" and not seen[p] then
					seen[p] = true
					out[#out + 1] = p
				end
			end
		end
		table.sort(out)
		return out
	end

	-- Resolve a Luau/TS/Python module specifier like `"src/utils"` or `"./math"` to a workspace path
	function M.resolveModulePath(spec, fromPath)
		local raw = tostring(spec or ""):gsub("\\", "/"):gsub("^%./", ""):gsub("^/+", "")
		if raw == "" then return nil end
		local candidates = {
			raw,
			raw .. ".luau",
			raw .. ".lua",
			raw .. "/init.luau",
			raw .. "/init.lua",
			raw:gsub("%.", "/") .. ".luau",
			raw:gsub("%.", "/") .. ".lua",
			raw .. ".ts",
			raw .. ".js",
			raw .. ".py",
		}
		if fromPath and fromPath ~= "" then
			local dir = fromPath:match("^(.*)/[^/]+$")
			if dir and dir ~= "" then
				candidates[#candidates + 1] = dir .. "/" .. raw
				candidates[#candidates + 1] = dir .. "/" .. raw .. ".luau"
				candidates[#candidates + 1] = dir .. "/" .. raw .. ".lua"
			end
		end
		for _, cand in ipairs(candidates) do
			if readLatestFile(cand) ~= nil then
				return cand
			end
		end
		return nil
	end

	-- Parse exported & local functions/fields from a document (`return M`, `function M.foo(...)`, `local function bar(...)`)
	function M.extractSymbols(source, filePath)
		local text = tostring(source or "")
		local lines = util.splitLines(text)
		local returnedVar = nil
		for i = #lines, math.max(1, #lines - 15), -1 do
			local retId = lines[i]:match("^%s*return%s+([%a_][%w_]*)%s*$")
			if retId and retId ~= "nil" and retId ~= "true" and retId ~= "false" then
				returnedVar = retId
				break
			end
		end

		local exports = {}
		local locals = {}

		for ln, line in ipairs(lines) do
			-- Preceding `--` doc comment if present
			local prevComment = nil
			if ln > 1 then
				local cmt = lines[ln - 1]:match("^%s*%-%-+%s*(.+)$") or lines[ln - 1]:match("^%s*//+(.+)$") or lines[ln - 1]:match("^%s*#+(.+)$")
				if cmt then prevComment = util.trim(cmt) end
			end

			-- `function Table.name(params)` or `function Table:name(params)`
			local tbl, sep, fnName, rawParams = line:match("^%s*function%s+([%a_][%w_]*)([%.:])([%a_][%w_]*)%s*%(([^%)]*)%)")
			if tbl and fnName then
				local paramList = {}
				for p in tostring(rawParams or ""):gmatch("[^,]+") do
					local tp = util.trim(p)
					if tp ~= "" then paramList[#paramList + 1] = tp end
				end
				local entry = {
					name = fnName,
					kind = (sep == ":") and "method" or "function",
					access = sep,
					params = paramList,
					ret = "any",
					line = ln,
					file = filePath,
					insert = fnName .. ((#paramList > 0) and "($0)" or "()"),
					doc = prevComment or string.format("Defined in %s:%d", filePath or "buffer", ln),
				}
				if not returnedVar or tbl == returnedVar then
					exports[#exports + 1] = entry
				end
				locals[tbl .. sep .. fnName] = entry
			end

			-- `Table.field = ...`
			if returnedVar then
				local propName, rhs = line:match("^%s*" .. returnedVar .. "%.([%a_][%w_]*)%s*=%s*(.+)$")
				if propName and not rhs:find("^function") then
					exports[#exports + 1] = {
						name = propName,
						kind = "property",
						access = ".",
						ret = "any",
						line = ln,
						file = filePath,
						doc = prevComment or string.format("Exported field in %s:%d", filePath or "buffer", ln),
					}
				elseif propName and rhs:find("^function") then
					local fParams = rhs:match("^function%s*%(([^%)]*)%)") or ""
					local pList = {}
					for p in fParams:gmatch("[^,]+") do
						local tp = util.trim(p)
						if tp ~= "" then pList[#pList + 1] = tp end
					end
					exports[#exports + 1] = {
						name = propName,
						kind = "function",
						access = ".",
						params = pList,
						ret = "any",
						line = ln,
						file = filePath,
						insert = propName .. ((#pList > 0) and "($0)" or "()"),
						doc = prevComment or string.format("Exported function in %s:%d", filePath or "buffer", ln),
					}
				end
			end

			-- `local function foo(params)` or `function foo(params)` or TS `export function foo(params)` or Python `def foo(params):`
			local lName, lParams = line:match("^%s*local%s+function%s+([%a_][%w_]*)%s*%(([^%)]*)%)")
			if not lName then
				lName, lParams = line:match("^%s*function%s+([%a_][%w_]*)%s*%(([^%)]*)%)")
			end
			if not lName then
				local isExp, tsName, tsParams = line:match("^%s*(export%s+)function%s+([%a_][%w_]*)%s*%(([^%)]*)%)")
				if isExp and tsName then
					lName, lParams = tsName, tsParams
				end
			end
			if not lName then
				lName, lParams = line:match("^%s*def%s+([%a_][%w_]*)%s*%(([^%)]*)%)")
			end
			if lName then
				local pList = {}
				for p in tostring(lParams or ""):gmatch("[^,]+") do
					local tp = util.trim(p)
					if tp ~= "" then pList[#pList + 1] = tp end
				end
				local entry = {
					name = lName,
					kind = "function",
					access = ".",
					params = pList,
					ret = "any",
					line = ln,
					file = filePath,
					insert = lName .. ((#pList > 0) and "($0)" or "()"),
					doc = prevComment or string.format("Function in %s:%d", filePath or "buffer", ln),
				}
				locals[lName] = entry
				if line:find("^%s*export%s+") or line:find("^%s*def%s+") then
					exports[#exports + 1] = entry
				end
			end

			-- `local varName = ...`
			local vName = line:match("^%s*local%s+([%a_][%w_]*)%s*=")
			if vName and not locals[vName] then
				locals[vName] = {
					name = vName,
					kind = "variable",
					line = ln,
					file = filePath,
					doc = prevComment or string.format("Local variable in %s:%d", filePath or "buffer", ln),
				}
			end
		end

		return exports, locals, returnedVar
	end

	-- Infer local variable types & `require` bindings inside a Luau source buffer
	function M.inferScope(source, currentPath)
		local varTypes = {
			game = "DataModel",
			workspace = "Workspace",
			script = "Instance",
		}
		local moduleVars = {} -- varName -> resolved workspace file path
		for _, svc in ipairs(apiDb.services) do
			-- Direct service globals not set unless bound, except `workspace`
			if svc.name == "Workspace" then
				varTypes.Workspace = "Workspace"
			end
		end

		for line in tostring(source or ""):gmatch("[^\n]+") do
			-- `local X = game:GetService("ServiceName")`
			local v1, svcName = line:match("local%s+([%a_][%w_]*)%s*=%s*game:GetService%(%s*[\"']([%a_][%w_]*)[\"']%s*%)")
			if v1 and svcName then
				varTypes[v1] = apiDb.classes[svcName] and svcName or "Instance"
			end

			-- `local X = Instance.new("ClassName")`
			local v2, clsName = line:match("local%s+([%a_][%w_]*)%s*=%s*Instance%.new%(%s*[\"']([%a_][%w_]*)[\"']")
			if v2 and clsName then
				if apiDb.classes[clsName] then
					varTypes[v2] = clsName
				else
					local mapped = "Instance"
					for _, cc in ipairs(apiDb.creatableClasses) do
						if cc.name == clsName then
							mapped = apiDb.classes[clsName] and clsName or (cc.base or "Instance")
							break
						end
					end
					varTypes[v2] = mapped
				end
			end

			-- `local X = require("path")`
			local v3, reqSpec = line:match("local%s+([%a_][%w_]*)%s*=%s*require%(%s*[\"']([^\"']+)[\"']%s*%)")
			if v3 and reqSpec then
				local resolved = M.resolveModulePath(reqSpec, currentPath)
				if resolved then
					moduleVars[v3] = resolved
				end
			end

			-- `local X = Y.Prop` (e.g. `local lp = Players.LocalPlayer`, `local char = lp.Character`, `local sig = btn.Activated`)
			local lhs, recv, prop = line:match("local%s+([%a_][%w_]*)%s*=%s*([%a_][%w_]*)%.([%a_][%w_]*)%s*$")
			if lhs and recv and prop and varTypes[recv] then
				local mem = apiDb.findClassMember(varTypes[recv], prop)
				if mem and mem.ret then
					local cleanRet = mem.ret:gsub("%?$", "")
					if apiDb.classes[cleanRet] then
						varTypes[lhs] = cleanRet
					end
				end
			end
		end

		return varTypes, moduleVars
	end

	-- Safely inspect live Roblox DataModel children for `game` / `workspace` / Services
	local function liveInstanceForChain(chainExpr, varTypes)
		local rootGame = env.game
		if not rootGame then return nil end
		local parts = {}
		for seg in tostring(chainExpr or ""):gmatch("[%a_][%w_]*") do
			parts[#parts + 1] = seg
		end
		if #parts == 0 then return nil end

		local cur = nil
		local startIdx = 2
		local head = parts[1]
		if head == "game" then
			cur = rootGame
		elseif head == "workspace" or head == "Workspace" then
			cur = env.workspace or (env.services and env.services.Workspace) or nil
		elseif varTypes[head] and varTypes[head] ~= "Instance" then
			local okS, svc = pcall(function() return rootGame:GetService(varTypes[head]) end)
			if okS and svc then cur = svc end
		end

		if not cur then return nil end
		for i = startIdx, #parts do
			local seg = parts[i]
			local okChild, nextInst = pcall(function()
				if cur.FindFirstChild then
					return cur:FindFirstChild(seg)
				end
				return cur[seg]
			end)
			if okChild and nextInst then
				cur = nextInst
			else
				return nil
			end
		end
		return cur
	end

	local function resolveChainClass(chainExpr, varTypes)
		-- Direct `game:GetService("X")`
		local inlineSvc = chainExpr:match("^game:GetService%(%s*[\"']([%a_][%w_]*)[\"']%s*%)$")
		if inlineSvc then
			return apiDb.classes[inlineSvc] and inlineSvc or "Instance"
		end
		local inlineNew = chainExpr:match("^Instance%.new%(%s*[\"']([%a_][%w_]*)[\"']%s*%)$")
		if inlineNew then
			return apiDb.classes[inlineNew] and inlineNew or "Instance"
		end

		local parts = {}
		for seg in tostring(chainExpr or ""):gmatch("[%a_][%w_]*") do
			parts[#parts + 1] = seg
		end
		if #parts == 0 then return nil end
		local curType = varTypes[parts[1]]
		if not curType then return nil end
		for i = 2, #parts do
			local mem = apiDb.findClassMember(curType, parts[i])
			if mem and mem.ret then
				local clean = mem.ret:gsub("%?$", "")
				curType = apiDb.classes[clean] and clean or "Instance"
			else
				curType = "Instance"
			end
		end
		return curType
	end

	local function formatSignatureLabel(name, params, ret, sep)
		local pStr = table.concat(params or {}, ", ")
		local prefix = sep == ":" and ":" or ""
		local rStr = (ret and ret ~= "") and (" -> " .. ret) or ""
		return string.format("%s%s(%s)%s", prefix, name, pStr, rStr)
	end

	-- Main LSP Completion Engine
	function M.suggest(source, cursorOffset, langId, maxItems, currentPath)
		local text = tostring(source or "")
		local pos = util.clamp((tonumber(cursorOffset) or 1) - 1, 0, #text)
		local beforeCursor = text:sub(1, pos)
		local lineBefore = beforeCursor:match("([^\n]*)$") or ""
		local lang = languages.get(langId)
		local limit = maxItems or 8
		local items = {}
		local seen = {}

		local function addItem(spec)
			if #items >= limit then return end
			if seen[spec.label] then return end
			seen[spec.label] = true
			items[#items + 1] = {
				label = spec.label,
				insert = spec.insert or spec.label,
				kind = spec.kind or "word",
				detail = spec.detail or lang.name,
				doc = spec.doc or "",
				signature = spec.signature or "",
			}
		end

		-- 1. Special String-Literal Contexts (`GetService("...")`, `Instance.new("...")`, `require("...")`)
		local svcPrefix = lineBefore:match("GetService%(%s*[\"']([%w_]*)$")
		if svcPrefix ~= nil then
			local low = svcPrefix:lower()
			local sStart = pos - #svcPrefix + 1
			for _, svc in ipairs(apiDb.services) do
				if low == "" or svc.name:lower():find(low, 1, true) == 1 then
					addItem({
						label = svc.name,
						insert = svc.name,
						kind = "class",
						detail = "Roblox Service",
						signature = 'game:GetService("' .. svc.name .. '")',
						doc = svc.doc,
					})
				end
			end
			return items, svcPrefix, sStart, pos
		end

		local newClsPrefix = lineBefore:match("Instance%.new%(%s*[\"']([%w_]*)$")
		if newClsPrefix ~= nil then
			local low = newClsPrefix:lower()
			local sStart = pos - #newClsPrefix + 1
			for _, cls in ipairs(apiDb.creatableClasses) do
				if low == "" or cls.name:lower():find(low, 1, true) == 1 then
					addItem({
						label = cls.name,
						insert = cls.name,
						kind = "constructor",
						detail = cls.base or "Instance",
						signature = 'Instance.new("' .. cls.name .. '")',
						doc = cls.doc,
					})
				end
			end
			return items, newClsPrefix, sStart, pos
		end

		local reqPrefix = lineBefore:match("require%(%s*[\"']([^\"']*)$")
		if reqPrefix ~= nil then
			local low = reqPrefix:lower()
			local sStart = pos - #reqPrefix + 1
			for _, p in ipairs(M.listWorkspaceScriptPaths()) do
				if p ~= currentPath then
					local cleanMod = p:gsub("%.luau$", ""):gsub("%.lua$", "")
					if low == "" or cleanMod:lower():find(low, 1, true) or p:lower():find(low, 1, true) then
						addItem({
							label = cleanMod,
							insert = cleanMod,
							kind = "module",
							detail = p,
							signature = 'require("' .. cleanMod .. '")',
							doc = "Workspace module at `" .. p .. "`.",
						})
					end
				end
			end
			return items, reqPrefix, sStart, pos
		end

		-- 2. Member Access Completion (`receiver.prefix` or `receiver:prefix` — works even with 0-char prefix!)
		local enumCat, enumPart = lineBefore:match("Enum%.([%a_][%w_]*)%.([%w_]*)$")
		if enumCat and apiDb.enums[enumCat] then
			local low = enumPart:lower()
			local sStart = pos - #enumPart + 1
			for _, item in ipairs(apiDb.enums[enumCat]) do
				if low == "" or item:lower():find(low, 1, true) == 1 then
					addItem({
						label = item,
						insert = item,
						kind = "enum",
						detail = "Enum." .. enumCat,
						signature = "Enum." .. enumCat .. "." .. item,
						doc = "Roblox Enum item `" .. item .. "`.",
					})
				end
			end
			return items, enumPart, sStart, pos
		end

		local receiverExpr, accessOp, memPrefix = lineBefore:match("([%a_][%w_%.]*[%w_%)%\"'])([%.:])([%w_]*)$")
		if not receiverExpr then
			receiverExpr, accessOp, memPrefix = lineBefore:match("([%a_][%w_]*)([%.:])([%w_]*)$")
		end

		if receiverExpr and accessOp then
			local low = memPrefix:lower()
			local sStart = pos - #memPrefix + 1

			-- 2a. `Enum.<Category>`
			if receiverExpr == "Enum" and accessOp == "." then
				for catName, list in pairs(apiDb.enums) do
					if low == "" or catName:lower():find(low, 1, true) == 1 then
						addItem({
							label = catName,
							insert = catName,
							kind = "enum",
							detail = string.format("Enum (%d)", #list),
							signature = "Enum." .. catName,
							doc = "Roblox Enum category `" .. catName .. "`.",
						})
					end
				end
				table.sort(items, function(a, b) return a.label < b.label end)
				return items, memPrefix, sStart, pos
			end

			-- 2b. Built-in Luau / Roblox Libraries (`task.`, `UDim2.`, `Color3.`, `Vector3.`, `CFrame.`, `string.`, `table.`, `math.`)
			if accessOp == "." and apiDb.libraries[receiverExpr] then
				for _, fn in ipairs(apiDb.libraries[receiverExpr]) do
					if low == "" or fn.name:lower():find(low, 1, true) == 1 then
						addItem({
							label = fn.name,
							insert = fn.insert or fn.name,
							kind = fn.kind or "function",
							detail = fn.ret or receiverExpr,
							signature = receiverExpr .. "." .. formatSignatureLabel(fn.name, fn.params, fn.ret, "."),
							doc = fn.doc,
						})
					end
				end
				return items, memPrefix, sStart, pos
			end

			-- 2c. Cross-file Workspace `require(...)` Module Exports (`utils.foo`) & Current-Module Table
			local varTypes, moduleVars = M.inferScope(text, currentPath)
			if moduleVars[receiverExpr] then
				local targetFile = moduleVars[receiverExpr]
				local modSrc = readLatestFile(targetFile)
				if modSrc then
					local exports = M.extractSymbols(modSrc, targetFile)
					for _, ex in ipairs(exports) do
						if (accessOp == ":" and ex.access == ":") or (accessOp == "." and ex.access ~= ":") then
							if low == "" or ex.name:lower():find(low, 1, true) == 1 then
								addItem({
									label = ex.name,
									insert = ex.insert or ex.name,
									kind = ex.kind or "function",
									detail = targetFile,
									signature = ex.params and formatSignatureLabel(ex.name, ex.params, ex.ret, ex.access) or ex.name,
									doc = ex.doc,
								})
							end
						end
					end
				end
				if #items > 0 then
					return items, memPrefix, sStart, pos
				end
			end

			-- 2d. Live DataModel Child Introspection + Static Roblox Class Inheritance
			local liveInst = liveInstanceForChain(receiverExpr, varTypes)
			if liveInst and accessOp == "." then
				local okChildren, children = pcall(function() return liveInst:GetChildren() end)
				if okChildren and type(children) == "table" then
					for _, ch in ipairs(children) do
						local chName = tostring(ch.Name or "")
						local chClass = tostring(ch.ClassName or "Instance")
						if chName:match("^[%a_][%w_]*$") and (low == "" or chName:lower():find(low, 1, true) == 1) then
							addItem({
								label = chName,
								insert = chName,
								kind = "instance",
								detail = chClass .. " (live)",
								signature = receiverExpr .. "." .. chName .. ": " .. chClass,
								doc = "Live DataModel child Instance (`" .. chClass .. "`).",
							})
						end
					end
				end
			end

			local inferredClass = resolveChainClass(receiverExpr, varTypes)
			if not inferredClass and liveInst then
				local okCls, cName = pcall(function() return liveInst.ClassName end)
				if okCls and type(cName) == "string" and cName ~= "" then
					inferredClass = cName
				end
			end
			if inferredClass then
				for _, m in ipairs(apiDb.membersOfClass(inferredClass)) do
					local accessMatch = (accessOp == ":" and m.access == ":") or (accessOp == "." and m.access == ".")
					if accessMatch and (low == "" or m.name:lower():find(low, 1, true) == 1) then
						addItem({
							label = m.name,
							insert = m.insert or m.name,
							kind = m.kind,
							detail = m.ret or inferredClass,
							signature = m.params and formatSignatureLabel(m.name, m.params, m.ret, m.access) or (m.name .. ": " .. tostring(m.ret)),
							doc = m.doc,
						})
					end
				end
				if #items > 0 then
					return items, memPrefix, sStart, pos
				end
			end
		end

		-- 3. Standard Identifier / Snippet / Global / Document Symbol Completion
		local prefix, startIdx, endIdx = M.currentWord(text, cursorOffset)
		if #prefix < 2 then return {}, prefix, startIdx, endIdx end
		local lowPrefix = prefix:lower()
		seen[prefix] = true

		local function matchesPrefix(candidate)
			local lowC = candidate:lower()
			return lowC:sub(1, #lowPrefix) == lowPrefix
		end

		-- 3a. Installed Community Extension Snippet Packs + Rich Built-in Snippets
		for _, pack in pairs(customSnippetPacks) do
			for _, snip in ipairs(pack) do
				if (not snip.lang or snip.lang == "*" or snip.lang == lang.id) and matchesPrefix(snip.trigger) then
					addItem({
						label = snip.trigger,
						insert = snip.insert,
						kind = "snippet",
						detail = snip.label or "ext snippet",
						signature = "snippet · " .. tostring(snip.trigger),
						doc = snip.detail or snip.label or "Community Extension Snippet",
					})
				end
			end
		end

		for _, snip in ipairs(apiDb.snippets[lang.id] or {}) do
			if matchesPrefix(snip.trigger) then
				addItem({
					label = snip.trigger,
					insert = snip.insert,
					kind = "snippet",
					detail = snip.label,
					signature = "snippet · " .. snip.trigger,
					doc = snip.doc,
				})
			end
		end

		for _, snip in ipairs(lang.snippets or {}) do
			if matchesPrefix(snip.trigger) then
				addItem({
					label = snip.trigger,
					insert = snip.insert,
					kind = "snippet",
					detail = snip.label,
					signature = "snippet · " .. snip.trigger,
					doc = snip.label,
				})
			end
		end

		-- 3b. Luau Globals, Libraries & Executor Functions
		if lang.id == "luau" then
			for gName, gSpec in pairs(apiDb.globals) do
				if matchesPrefix(gName) then
					addItem({
						label = gName,
						insert = gSpec.insert or gName,
						kind = gSpec.kind or "builtin",
						detail = gSpec.ret or gSpec.kind,
						signature = formatSignatureLabel(gName, gSpec.params, gSpec.ret, "."),
						doc = gSpec.doc,
					})
				end
			end
			for libName in pairs(apiDb.libraries) do
				if matchesPrefix(libName) then
					addItem({
						label = libName,
						insert = libName,
						kind = "module",
						detail = "Luau/Roblox Library",
						signature = "library " .. libName,
						doc = "Standard Roblox / Luau library `" .. libName .. "`.",
					})
				end
			end
		end

		-- 3c. Current Document Functions & Variables
		local _, docLocals = M.extractSymbols(text, currentPath)
		for symName, sym in pairs(docLocals) do
			if not symName:find("[%.:]") and matchesPrefix(symName) then
				addItem({
					label = symName,
					insert = sym.insert or symName,
					kind = sym.kind or "symbol",
					detail = string.format("line %d", sym.line or 1),
					signature = sym.params and formatSignatureLabel(symName, sym.params, sym.ret, ".") or symName,
					doc = sym.doc,
				})
			end
		end

		-- 3d. Language Keywords, Builtins, Types & Document Words
		for word in pairs(lang.keywords or {}) do
			if matchesPrefix(word) then
				addItem({ label = word, insert = word, kind = "keyword", detail = "keyword", doc = lang.name .. " keyword." })
			end
		end
		for word in pairs(lang.builtins or {}) do
			if matchesPrefix(word) then
				addItem({ label = word, insert = word, kind = "builtin", detail = "builtin", doc = lang.name .. " built-in symbol." })
			end
		end
		for word in pairs(lang.types or {}) do
			if matchesPrefix(word) then
				addItem({ label = word, insert = word, kind = "type", detail = "type", doc = lang.name .. " type annotation." })
			end
		end
		for token in text:gmatch("[%a_][%w_]+") do
			if #token >= 3 and matchesPrefix(token) then
				addItem({ label = token, insert = token, kind = "symbol", detail = "document", doc = "Identifier in current document." })
			end
		end

		local rank = {
			snippet = 1,
			instance = 2,
			property = 3,
			method = 4,
			event = 5,
			["function"] = 5,
			constructor = 5,
			executor = 6,
			module = 7,
			variable = 8,
			builtin = 9,
			keyword = 10,
			type = 11,
			symbol = 12,
		}
		table.sort(items, function(a, b)
			local ra, rb = rank[a.kind] or 15, rank[b.kind] or 15
			if ra ~= rb then return ra < rb end
			return a.label < b.label
		end)

		if #items > limit then
			local trimmed = {}
			for i = 1, limit do trimmed[i] = items[i] end
			items = trimmed
		end

		return items, prefix, startIdx, endIdx
	end

	-- Parameter Signature Help (`M.signatureHelp`)
	function M.signatureHelp(source, cursorOffset, langId, currentPath)
		local text = tostring(source or "")
		local pos = util.clamp((tonumber(cursorOffset) or 1) - 1, 0, #text)
		if pos <= 0 then return nil end

		-- Scan backwards on the recent window (up to 400 chars) to find the enclosing unclosed `(`
		local minScan = math.max(1, pos - 400)
		local depth = 0
		local openParenPos = nil
		local activeCommaCount = 0
		local inStr = nil

		for i = pos, minScan, -1 do
			local ch = text:sub(i, i)
			if inStr then
				if ch == inStr and text:sub(i - 1, i - 1) ~= "\\" then
					inStr = nil
				end
			else
				if ch == '"' or ch == "'" then
					inStr = ch
				elseif ch == ")" or ch == "]" or ch == "}" then
					depth = depth + 1
				elseif ch == "(" then
					if depth == 0 then
						openParenPos = i
						break
					else
						depth = depth - 1
					end
				elseif (ch == "[" or ch == "{") and depth > 0 then
					depth = depth - 1
				elseif ch == "," and depth == 0 then
					activeCommaCount = activeCommaCount + 1
				end
			end
		end

		if not openParenPos then return nil end

		local callPrefix = text:sub(math.max(1, openParenPos - 80), openParenPos - 1)
		local recv, sep, fnName = callPrefix:match("([%a_][%w_]*)([%.:])([%a_][%w_]*)%s*$")
		local bareFn = (not recv) and callPrefix:match("([%a_][%w_]*)%s*$") or nil
		local activeParam = activeCommaCount + 1

		-- Check Luau libraries (`Color3.fromRGB`, `UDim2.new`, `task.delay`, `math.clamp`, ...)
		if recv and sep == "." and apiDb.libraries[recv] then
			for _, fn in ipairs(apiDb.libraries[recv]) do
				if fn.name == fnName and fn.params then
					return {
						name = recv .. "." .. fnName,
						params = fn.params,
						ret = fn.ret or "()",
						activeParam = activeParam,
						doc = fn.doc or "",
					}
				end
			end
		end

		local varTypes, moduleVars = M.inferScope(text, currentPath)

		-- Check cross-file `require` module function (`utils.compute(...)`)
		if recv and moduleVars[recv] then
			local modSrc = readLatestFile(moduleVars[recv])
			if modSrc then
				local exports = M.extractSymbols(modSrc, moduleVars[recv])
				for _, ex in ipairs(exports) do
					if ex.name == fnName and ex.params then
						return {
							name = recv .. sep .. fnName,
							params = ex.params,
							ret = ex.ret or "any",
							activeParam = activeParam,
							doc = ex.doc or "",
						}
					end
				end
			end
		end

		-- Check Roblox class method (`game:GetService(...)`, `workspace:Raycast(...)`, `TweenService:Create(...)`)
		if recv and fnName then
			local cls = resolveChainClass(recv, varTypes) or (sep == ":" and "Instance" or nil)
			if cls then
				local m = apiDb.findClassMember(cls, fnName)
				if m and m.params then
					return {
						name = cls .. sep .. fnName,
						params = m.params,
						ret = m.ret or "()",
						activeParam = activeParam,
						doc = m.doc or "",
					}
				end
			end
		end

		-- Check Global / Executor function or Current-Document function
		if bareFn then
			if langId == "luau" and apiDb.globals[bareFn] and apiDb.globals[bareFn].params then
				local g = apiDb.globals[bareFn]
				return {
					name = bareFn,
					params = g.params,
					ret = g.ret or "()",
					activeParam = activeParam,
					doc = g.doc or "",
				}
			end
			local _, docLocals = M.extractSymbols(text, currentPath)
			local lf = docLocals[bareFn]
			if lf and lf.params then
				return {
					name = bareFn,
					params = lf.params,
					ret = lf.ret or "any",
					activeParam = activeParam,
					doc = lf.doc or "",
				}
			end
		end

		return nil
	end

	-- Extract full `receiver.member` or `word` under `cursorOffset`
	local function symbolContextAt(source, cursorOffset)
		local text = tostring(source or "")
		local pos = util.clamp(tonumber(cursorOffset) or 1, 1, math.max(1, #text))
		if not text:sub(pos, pos):match("[%w_]") and pos > 1 and text:sub(pos - 1, pos - 1):match("[%w_]") then
			pos = pos - 1
		end
		local s, e = pos, pos
		while s > 1 and text:sub(s - 1, s - 1):match("[%w_]") do s = s - 1 end
		while e < #text and text:sub(e + 1, e + 1):match("[%w_]") do e = e + 1 end
		local word = text:sub(s, e)
		if not word:match("^[%a_][%w_]*$") then return nil end

		local sep = (s > 1) and text:sub(s - 1, s - 1) or ""
		local recv = nil
		if sep == "." or sep == ":" then
			local rs = s - 2
			local re = rs
			while rs >= 1 and text:sub(rs, rs):match("[%w_]") do rs = rs - 1 end
			rs = rs + 1
			if rs <= re then
				recv = text:sub(rs, re)
			end
		end
		return {
			word = word,
			receiver = recv,
			sep = (sep == "." or sep == ":") and sep or nil,
			startPos = s,
			endPos = e,
		}
	end

	-- Hover Documentation (`M.hover`)
	function M.hover(source, cursorOffset, langId, currentPath)
		local text = tostring(source or "")
		local ctx = symbolContextAt(text, cursorOffset)
		if not ctx then return nil end

		local varTypes, moduleVars = M.inferScope(text, currentPath)
		local _, docLocals = M.extractSymbols(text, currentPath)

		-- 1. `Library.member` (`Color3.fromRGB`, `task.spawn`, etc.)
		if ctx.receiver and apiDb.libraries[ctx.receiver] then
			for _, fn in ipairs(apiDb.libraries[ctx.receiver]) do
				if fn.name == ctx.word then
					return {
						title = ctx.receiver .. "." .. ctx.word,
						kind = fn.kind or "function",
						signature = ctx.receiver .. "." .. formatSignatureLabel(fn.name, fn.params, fn.ret, "."),
						doc = fn.doc or "",
					}
				end
			end
		end

		-- 2. Cross-file `require`d module export (`utils.helper`)
		if ctx.receiver and moduleVars[ctx.receiver] then
			local targetFile = moduleVars[ctx.receiver]
			local modSrc = readLatestFile(targetFile)
			if modSrc then
				local exports = M.extractSymbols(modSrc, targetFile)
				for _, ex in ipairs(exports) do
					if ex.name == ctx.word then
						return {
							title = ctx.receiver .. (ctx.sep or ".") .. ctx.word,
							kind = ex.kind or "function",
							signature = ex.params and formatSignatureLabel(ex.name, ex.params, ex.ret, ex.access) or ex.name,
							doc = ex.doc or "",
							file = targetFile,
							line = ex.line,
						}
					end
				end
			end
		end

		-- 3. Roblox Class Member (`Players.LocalPlayer`, `workspace:Raycast`, `btn.Activated`, etc.)
		if ctx.receiver then
			local cls = resolveChainClass(ctx.receiver, varTypes) or "Instance"
			local mem = apiDb.findClassMember(cls, ctx.word)
			if mem then
				return {
					title = cls .. mem.access .. mem.name,
					kind = mem.kind,
					signature = mem.params and (cls .. formatSignatureLabel(mem.name, mem.params, mem.ret, mem.access))
						or string.format("(%s) %s.%s: %s", mem.kind, cls, mem.name, tostring(mem.ret)),
					doc = mem.doc or "",
				}
			end
		end

		-- 4. Global / Executor Function
		if langId == "luau" and apiDb.globals[ctx.word] then
			local g = apiDb.globals[ctx.word]
			return {
				title = ctx.word,
				kind = g.kind,
				signature = formatSignatureLabel(ctx.word, g.params, g.ret, "."),
				doc = g.doc or "",
			}
		end

		-- 5. Local Variable with Inferred Roblox Type or `require` Module
		if moduleVars[ctx.word] then
			return {
				title = ctx.word,
				kind = "module",
				signature = string.format('local %s = require("%s")', ctx.word, moduleVars[ctx.word]),
				doc = "Imported workspace module `" .. moduleVars[ctx.word] .. "`.",
				file = moduleVars[ctx.word],
				line = 1,
			}
		end

		if varTypes[ctx.word] then
			local cls = varTypes[ctx.word]
			local defSym = docLocals[ctx.word]
			return {
				title = ctx.word,
				kind = "variable",
				signature = string.format("local %s: %s", ctx.word, cls),
				doc = "Inferred Roblox type `" .. cls .. "`.",
				file = currentPath,
				line = defSym and defSym.line or nil,
			}
		end

		-- 6. Current-Document Function or Variable
		if docLocals[ctx.word] then
			local sym = docLocals[ctx.word]
			return {
				title = ctx.word,
				kind = sym.kind,
				signature = sym.params and formatSignatureLabel(ctx.word, sym.params, sym.ret, ".") or ("local " .. ctx.word),
				doc = sym.doc or "",
				file = currentPath,
				line = sym.line,
			}
		end

		return nil
	end

	-- Cross-File & Intra-File Go-to-Definition (`F12`)
	function M.findDefinition(source, cursorOffset, _langId, currentPath)
		local text = tostring(source or "")
		-- Check if cursor is directly on a `require("...")` string literal
		local lineStart = cursorOffset
		while lineStart > 1 and text:sub(lineStart - 1, lineStart - 1) ~= "\n" do
			lineStart = lineStart - 1
		end
		local lineEnd = text:find("\n", cursorOffset, true) or (#text + 1)
		local curLineStr = text:sub(lineStart, lineEnd - 1)
		local reqSpec = curLineStr:match("require%(%s*[\"']([^\"']+)[\"']%s*%)")
		if reqSpec then
			local resolved = M.resolveModulePath(reqSpec, currentPath)
			if resolved then
				return { file = resolved, line = 1, symbol = reqSpec }
			end
		end

		local hov = M.hover(text, cursorOffset, "luau", currentPath)
		if hov and hov.line then
			return {
				file = hov.file or currentPath,
				line = hov.line,
				symbol = hov.title,
			}
		end

		local ctx = symbolContextAt(text, cursorOffset)
		if not ctx then return nil end
		-- Scan workspace files for exported function matching `ctx.word`
		for _, path in ipairs(M.listWorkspaceScriptPaths()) do
			local fSrc = readLatestFile(path)
			if fSrc then
				local exports = M.extractSymbols(fSrc, path)
				for _, ex in ipairs(exports) do
					if ex.name == ctx.word and ex.line then
						return { file = path, line = ex.line, symbol = ex.name }
					end
				end
			end
		end
		return nil
	end

	return M
end
