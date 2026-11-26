-- Locked 5-Template Community Extension Hub, Malware Scanner & Runtime Installer (`src/runtime/extension_hub.lua`).
-- Pure Lua 5.1-compatible module. Zero `loadstring` or arbitrary code execution is EVER performed by extensions.
return function(env)
	local fsx = env.require("runtime/fsx")
	local util = env.require("runtime/util")
	local signal = env.require("runtime/signal")
	local log = env.require("runtime/log")
	local config = env.require("runtime/config")
	local codeStore = env.require("runtime/code_store")
	local commands = env.require("runtime/command_catalog")
	local intellisense = env.require("runtime/intellisense")
	local shortcuts = env.require("runtime/shortcuts")
	local theme = env.require("ui/theme")
	local http = env.require("net/http")
	local headersUtil = env.require("net/headers")
	local github = env.require("net/github")

	local INSTALLED_FILE = "extensions/installed.json"
	local DEFAULT_HUB_REPO = "TheStrongestOfTomorrow/VS-RBLX"

	local M = {
		changed = signal.new("extensionHub.changed"),
		hubRepo = DEFAULT_HUB_REPO,
		installed = {},     -- extId -> manifest
		activeCleanup = {}, -- extId -> cleanup fn
		remoteCatalog = {}, -- list of { id, manifest, scan, issueNumber, author, htmlUrl }
	}

	-- Exact 5 Allowed Community Extension Templates
	M.ALLOWED_TEMPLATES = {
		["theme-pack"] = {
			id = "theme-pack",
			label = "Color Theme Pack",
			badge = "🎨 THEME",
			desc = "Declarative `#RRGGBB` workbench & syntax color palette.",
		},
		["snippet-pack"] = {
			id = "snippet-pack",
			label = "Language Snippet Pack",
			badge = "⇥ SNIPPETS",
			desc = "Declarative autocomplete snippet triggers (`$0` cursor stops).",
		},
		["command-macro"] = {
			id = "command-macro",
			label = "Safe Command Macro",
			badge = "⚡ MACRO",
			desc = "Allowlisted multi-step IDE actions (no raw code execution).",
		},
		["keymap-preset"] = {
			id = "keymap-preset",
			label = "Keybinding Preset",
			badge = "⌨ KEYMAP",
			desc = "Maps keyboard chords to built-in VS-RBLX command IDs.",
		},
		["toolbar-tool"] = {
			id = "toolbar-tool",
			label = "Editor Quick-Tool",
			badge = "🛠 TOOL",
			desc = "Safe declarative text transform or boilerplate header inserter.",
		},
	}

	M.TEMPLATE_LIST = { "theme-pack", "snippet-pack", "command-macro", "keymap-preset", "toolbar-tool" }

	-- Strict Malware, Webhook, Obfuscator & Sandbox-Escape Signatures
	local MALWARE_SIGNATURES = {
		{ pat = "loadstring%s*%(", reason = "Dynamic code execution (`loadstring`) is forbidden in extensions" },
		{ pat = "loadfile%s*%(", reason = "Filesystem chunk loading (`loadfile`) is forbidden" },
		{ pat = "dofile%s*%(", reason = "Filesystem execution (`dofile`) is forbidden" },
		{ pat = "setfenv%s*%(", reason = "Environment hijacking (`setfenv`) is forbidden" },
		{ pat = "getfenv%s*%(", reason = "Environment inspection (`getfenv`) is forbidden" },
		{ pat = "string%.dump", reason = "Bytecode serialization (`string.dump`) is forbidden" },
		{ pat = "discord%.com/api/webhooks", reason = "Discord webhook exfiltration URL blocked" },
		{ pat = "discordapp%.com/api/webhooks", reason = "Discord webhook exfiltration URL blocked" },
		{ pat = "hooks%.slack%.com", reason = "Slack webhook exfiltration URL blocked" },
		{ pat = "api%.telegram%.org/bot", reason = "Telegram bot exfiltration URL blocked" },
		{ pat = "webhook", reason = "Webhook reference is forbidden in extensions" },
		{ pat = "httpget", reason = "Outbound `HttpGet` network call is forbidden", nocase = true },
		{ pat = "httppost", reason = "Outbound `HttpPost` network call is forbidden", nocase = true },
		{ pat = "requestasync", reason = "Outbound `RequestAsync` network call is forbidden", nocase = true },
		{ pat = "syn%.request", reason = "Executor `syn.request` network call is forbidden", nocase = true },
		{ pat = "http_request", reason = "Executor `http_request` network call is forbidden", nocase = true },
		{ pat = "fluxus%.request", reason = "Executor `fluxus.request` network call is forbidden", nocase = true },
		{ pat = "websocket", reason = "WebSocket connection is forbidden", nocase = true },
		{ pat = "pastebin%.com", reason = "External paste host URL is forbidden", nocase = true },
		{ pat = "hastebin", reason = "External paste host URL is forbidden", nocase = true },
		{ pat = "grabify", reason = "IP logger domain blocked", nocase = true },
		{ pat = "ipify", reason = "IP lookup endpoint blocked", nocase = true },
		{ pat = "getgenv%s*%(", reason = "Global executor environment access (`getgenv`) is forbidden" },
		{ pat = "getrenv%s*%(", reason = "Roblox global environment access (`getrenv`) is forbidden" },
		{ pat = "getreg%s*%(", reason = "Lua registry access (`getreg`) is forbidden" },
		{ pat = "getgc%s*%(", reason = "Garbage collector scan (`getgc`) is forbidden" },
		{ pat = "hookfunction", reason = "Function hooking (`hookfunction`) is forbidden" },
		{ pat = "hookmetamethod", reason = "Metamethod hooking (`hookmetamethod`) is forbidden" },
		{ pat = "newcclosure", reason = "C-closure wrapping (`newcclosure`) is forbidden" },
		{ pat = "getrawmetatable", reason = "Raw metatable access is forbidden" },
		{ pat = "setrawmetatable", reason = "Raw metatable mutation is forbidden" },
		{ pat = "writefile%s*%(", reason = "Direct executor `writefile` call is forbidden" },
		{ pat = "delfile%s*%(", reason = "Direct executor `delfile` call is forbidden" },
		{ pat = "delfolder%s*%(", reason = "Direct executor `delfolder` call is forbidden" },
		{ pat = "appendfile%s*%(", reason = "Direct executor `appendfile` call is forbidden" },
		{ pat = "queue_on_teleport", reason = "Teleport persistence payload (`queue_on_teleport`) is forbidden" },
		{ pat = "github%.pat", reason = "Reading `github.pat` credential setting is forbidden", nocase = true },
		{ pat = "ghp_[%w]+", reason = "Embedded GitHub Personal Access Token detected" },
		{ pat = "github_pat_[%w_]+", reason = "Embedded fine-grained GitHub PAT detected" },
		{ pat = "moonsec", reason = "Obfuscated payload signature (`MoonSec`) blocked", nocase = true },
		{ pat = "luraph", reason = "Obfuscated payload signature (`Luraph`) blocked", nocase = true },
		{ pat = "ironbrew", reason = "Obfuscated payload signature (`IronBrew`) blocked", nocase = true },
	}

	local ALLOWED_ROOT_KEYS = {
		id = true,
		name = true,
		version = true,
		author = true,
		summary = true,
		template = true,
		theme = true,
		snippets = true,
		macros = true,
		keymap = true,
		tools = true,
	}

	local SAFE_MACRO_OPS = {
		insertText = true,
		openFile = true,
		setSetting = true,
		applyTheme = true,
		openPreview = true,
		bundleWorkspace = true,
		toast = true,
	}

	local BLOCKED_SETTING_PREFIXES = {
		"github.",
		"vault.",
	}

	local SAFE_TRANSFORMS = {
		uppercase = true,
		lowercase = true,
		sortLines = true,
		trimLines = true,
		wrapPcall = true,
		insertHeader = true,
	}

	-- Parse a GitHub Issue YAML-Form Markdown body into structured sections
	function M.parseIssueMarkdown(markdown)
		local body = tostring(markdown or ""):gsub("\r\n", "\n")
		local sections = {}
		local currentHeading = nil
		local buf = {}

		local function flush()
			if currentHeading then
				sections[currentHeading] = util.trim(table.concat(buf, "\n"))
			end
			buf = {}
		end

		for line in (body .. "\n"):gmatch("([^\n]*)\n") do
			local h = line:match("^###%s+(.+)$")
			if h then
				flush()
				currentHeading = util.trim(h)
			elseif currentHeading then
				buf[#buf + 1] = line
			end
		end
		flush()

		local jsonText = sections["Manifest JSON"] or ""
		local fenced = jsonText:match("```[%w_%-]*%s*(.-)%s*```")
		if fenced then
			jsonText = util.trim(fenced)
		end

		return {
			template = sections["Extension Template"],
			id = sections["Extension ID"],
			name = sections["Display Name"],
			version = sections["Version"],
			summary = sections["Summary"],
			manifestJson = jsonText,
			attestations = sections["Security Attestations"] or "",
			sections = sections,
		}
	end

	local function scanStringForMalware(str, fieldLabel, findings)
		local s = tostring(str or "")
		if s == "" then return end
		local low = s:lower()

		-- Detect escaped bytecode sequences (`\108\111\097\100...` or `\x6c\x6f...`)
		local decEscapes = 0
		for _ in s:gmatch("\\%d%d?%d?") do decEscapes = decEscapes + 1 end
		if decEscapes >= 6 then
			findings[#findings + 1] = string.format("[%s] Decimal-escaped bytecode sequence detected (%d escapes)", fieldLabel, decEscapes)
		end
		local hexEscapes = 0
		for _ in s:gmatch("\\x%x%x") do hexEscapes = hexEscapes + 1 end
		if hexEscapes >= 6 then
			findings[#findings + 1] = string.format("[%s] Hex-escaped payload sequence detected (%d escapes)", fieldLabel, hexEscapes)
		end

		for _, rule in ipairs(MALWARE_SIGNATURES) do
			local hay = rule.nocase and low or s
			if hay:find(rule.pat) then
				findings[#findings + 1] = string.format("[%s] %s", fieldLabel, rule.reason)
			end
		end
	end

	local function scanValueRecursive(val, pathLabel, findings, depth)
		if depth > 8 then
			findings[#findings + 1] = pathLabel .. ": Nesting depth exceeds maximum limit (8)"
			return
		end
		local t = type(val)
		if t == "string" then
			if #val > 4096 then
				findings[#findings + 1] = pathLabel .. ": String field exceeds 4 KB safety cap"
			end
			scanStringForMalware(val, pathLabel, findings)
		elseif t == "table" then
			local count = 0
			for k, v in pairs(val) do
				count = count + 1
				if count > 80 then
					findings[#findings + 1] = pathLabel .. ": Object/array exceeds 80 entries safety cap"
					break
				end
				if type(k) == "string" then
					scanStringForMalware(k, pathLabel .. ".<key>", findings)
				end
				scanValueRecursive(v, pathLabel .. "." .. tostring(k), findings, depth + 1)
			end
		elseif t ~= "number" and t ~= "boolean" and t ~= "nil" then
			findings[#findings + 1] = pathLabel .. ": Unsupported Lua type `" .. t .. "`"
		end
	end

	-- Full Multi-Layer Client Malware & Schema Scanner
	function M.scanSubmission(input)
		local findings = {}
		local manifest = nil
		local rawText = ""

		if type(input) == "table" and input.body and (input.number or input.title) then
			-- GitHub Issue API object
			rawText = tostring(input.title or "") .. "\n" .. tostring(input.body or "")
			if #rawText > 32768 then
				return { ok = false, risk = "BLOCKED", findings = { "Issue body exceeds 32 KB limit" } }
			end
			scanStringForMalware(input.title or "", "issue.title", findings)
			local parsedForm = M.parseIssueMarkdown(input.body)
			scanStringForMalware(parsedForm.summary or "", "issue.summary", findings)
			if parsedForm.manifestJson == "" then
				findings[#findings + 1] = "Missing `### Manifest JSON` fenced block from official Community Extension Issue Form"
			else
				local decoded, dErr = util.jsonDecode(parsedForm.manifestJson)
				if type(decoded) ~= "table" then
					findings[#findings + 1] = "Invalid Manifest JSON: " .. tostring(dErr)
				else
					manifest = decoded
					if parsedForm.template and parsedForm.template ~= "" and manifest.template ~= parsedForm.template then
						findings[#findings + 1] = string.format(
							"Template mismatch between form dropdown (`%s`) and manifest (`%s`)",
							tostring(parsedForm.template),
							tostring(manifest.template)
						)
					end
					if parsedForm.id and parsedForm.id ~= "" and manifest.id ~= parsedForm.id then
						findings[#findings + 1] = string.format(
							"Extension ID mismatch between form (`%s`) and manifest (`%s`)",
							tostring(parsedForm.id),
							tostring(manifest.id)
						)
					end
				end
			end
		elseif type(input) == "string" then
			rawText = input
			if #rawText > 32768 then
				return { ok = false, risk = "BLOCKED", findings = { "Extension payload exceeds 32 KB limit" } }
			end
			if input:find("###%s+Extension Template") or input:find("###%s+Manifest JSON") then
				local parsedForm = M.parseIssueMarkdown(input)
				scanStringForMalware(parsedForm.summary or "", "form.summary", findings)
				local decoded, dErr = util.jsonDecode(parsedForm.manifestJson)
				if type(decoded) ~= "table" then
					findings[#findings + 1] = "Invalid Manifest JSON: " .. tostring(dErr)
				else
					manifest = decoded
					if parsedForm.template and parsedForm.template ~= "" and manifest.template ~= parsedForm.template then
						findings[#findings + 1] = "Form template does not match manifest.template"
					end
				end
			else
				local decoded, dErr = util.jsonDecode(input)
				if type(decoded) ~= "table" then
					findings[#findings + 1] = "Invalid JSON manifest: " .. tostring(dErr)
				else
					manifest = decoded
				end
			end
		elseif type(input) == "table" then
			manifest = input
		else
			findings[#findings + 1] = "Unsupported extension input type"
		end

		if type(manifest) ~= "table" then
			return {
				ok = false,
				risk = "BLOCKED",
				findings = findings,
				manifest = nil,
			}
		end

		-- 1. Root Key Allowlist Check
		for k in pairs(manifest) do
			if not ALLOWED_ROOT_KEYS[k] then
				findings[#findings + 1] = "Unknown/disallowed manifest root property: `" .. tostring(k) .. "`"
			end
		end

		-- 2. Required Metadata Check
		local extId = tostring(manifest.id or "")
		local extName = tostring(manifest.name or "")
		local extVer = tostring(manifest.version or "")
		local tmpl = tostring(manifest.template or "")

		if not extId:match("^[a-z0-9][a-z0-9%-_]+$") or #extId > 48 then
			findings[#findings + 1] = "Invalid `id`: must be lowercase kebab/snake-case (`^[a-z0-9][a-z0-9-_]+$`, max 48 chars)"
		end
		if #extName < 3 or #extName > 64 then
			findings[#findings + 1] = "Invalid `name`: must be 3–64 characters"
		end
		if not extVer:match("^%d+%.%d+%.%d+$") then
			findings[#findings + 1] = "Invalid `version`: must follow strict SemVer (`X.Y.Z`)"
		end
		if not M.ALLOWED_TEMPLATES[tmpl] then
			findings[#findings + 1] = "Disallowed `template`: `" .. tmpl .. "` (must be one of: " .. table.concat(M.TEMPLATE_LIST, ", ") .. ")"
		end

		-- 3. Deep Recursive Malware Signature Scan
		scanValueRecursive(manifest, "manifest", findings, 1)

		-- 4. Template-Specific Schema Enforcement
		if tmpl == "theme-pack" then
			if type(manifest.theme) ~= "table" then
				findings[#findings + 1] = "`theme-pack` requires a `theme` object"
			else
				if type(manifest.theme.colors) ~= "table" then
					findings[#findings + 1] = "`theme-pack` requires `theme.colors` hex map"
				else
					for ck, cv in pairs(manifest.theme.colors) do
						if type(cv) ~= "string" or not cv:match("^#%x%x%x%x%x%x$") then
							findings[#findings + 1] = string.format("Invalid hex color `theme.colors.%s`: `%s`", tostring(ck), tostring(cv))
						end
					end
				end
				if manifest.theme.syntax ~= nil then
					if type(manifest.theme.syntax) ~= "table" then
						findings[#findings + 1] = "`theme.syntax` must be an object"
					else
						for sk, sv in pairs(manifest.theme.syntax) do
							if type(sv) ~= "string" or not sv:match("^#%x%x%x%x%x%x$") then
								findings[#findings + 1] = string.format("Invalid hex color `theme.syntax.%s`: `%s`", tostring(sk), tostring(sv))
							end
						end
					end
				end
			end
		elseif tmpl == "snippet-pack" then
			if type(manifest.snippets) ~= "table" or #manifest.snippets == 0 or #manifest.snippets > 25 then
				findings[#findings + 1] = "`snippet-pack` requires `snippets` array (1–25 items)"
			else
				for idx, sn in ipairs(manifest.snippets) do
					if type(sn) ~= "table" or type(sn.trigger) ~= "string" or not sn.trigger:match("^[%w_%-]+$")
						or type(sn.insert) ~= "string" or sn.insert == "" then
						findings[#findings + 1] = string.format("Invalid snippet at `snippets[%d]`", idx)
					end
				end
			end
		elseif tmpl == "command-macro" then
			if type(manifest.macros) ~= "table" or #manifest.macros == 0 or #manifest.macros > 10 then
				findings[#findings + 1] = "`command-macro` requires `macros` array (1–10 items)"
			else
				for idx, mc in ipairs(manifest.macros) do
					if type(mc) ~= "table" or type(mc.id) ~= "string" or not mc.id:match("^[%w_%-%.]+$")
						or type(mc.title) ~= "string" or type(mc.steps) ~= "table" or #mc.steps == 0 or #mc.steps > 8 then
						findings[#findings + 1] = string.format("Invalid macro definition at `macros[%d]`", idx)
					else
						for sIdx, step in ipairs(mc.steps) do
							local op = type(step) == "table" and tostring(step.op or "") or ""
							if not SAFE_MACRO_OPS[op] then
								findings[#findings + 1] = string.format("Disallowed macro step op `%s` at `macros[%d].steps[%d]`", op, idx, sIdx)
							elseif op == "setSetting" then
								local skey = tostring(step.key or "")
								for _, bp in ipairs(BLOCKED_SETTING_PREFIXES) do
									if skey:lower():find(bp, 1, true) == 1 then
										findings[#findings + 1] = "Macro cannot modify protected credential setting `" .. skey .. "`"
									end
								end
							elseif op == "openFile" then
								local p = tostring(step.path or "")
								if p:find("%.%.", 1, true) or p:find("^/") or p:lower():find("%.vsrblx", 1, true) then
									findings[#findings + 1] = "Macro `openFile` path traversal / `.vsrblx` access blocked"
								end
							end
						end
					end
				end
			end
		elseif tmpl == "keymap-preset" then
			if type(manifest.keymap) ~= "table" or type(manifest.keymap.bindings) ~= "table"
				or #manifest.keymap.bindings == 0 or #manifest.keymap.bindings > 30 then
				findings[#findings + 1] = "`keymap-preset` requires `keymap.bindings` array (1–30 items)"
			else
				for idx, kb in ipairs(manifest.keymap.bindings) do
					if type(kb) ~= "table" or type(kb.key) ~= "string" or not kb.key:match("^[%a%d]+$")
						or type(kb.command) ~= "string" or kb.command:find("^run%.") then
						findings[#findings + 1] = string.format("Invalid or disallowed keybinding at `keymap.bindings[%d]`", idx)
					end
				end
			end
		elseif tmpl == "toolbar-tool" then
			if type(manifest.tools) ~= "table" or #manifest.tools == 0 or #manifest.tools > 6 then
				findings[#findings + 1] = "`toolbar-tool` requires `tools` array (1–6 items)"
			else
				for idx, tl in ipairs(manifest.tools) do
					if type(tl) ~= "table" or type(tl.id) ~= "string" or type(tl.label) ~= "string"
						or not SAFE_TRANSFORMS[tostring(tl.transform or "")] then
						findings[#findings + 1] = string.format("Invalid or disallowed `transform` at `tools[%d]`", idx)
					end
				end
			end
		end

		local clean = (#findings == 0)
		return {
			ok = clean,
			risk = clean and "CLEAN" or "BLOCKED",
			findings = findings,
			manifest = clean and manifest or nil,
		}
	end

	-- Execute a safe declarative `toolbar-tool` text transform on the active buffer
	local function executeSafeTransform(toolSpec)
		local doc = codeStore.active()
		if not doc or doc.readOnly then return false end
		local src = tostring(doc.content or "")
		local tf = tostring(toolSpec.transform or "")
		local updated = src
		if tf == "uppercase" then
			updated = src:upper()
		elseif tf == "lowercase" then
			updated = src:lower()
		elseif tf == "sortLines" then
			local lines = util.splitLines(src)
			table.sort(lines)
			updated = table.concat(lines, "\n")
		elseif tf == "trimLines" then
			local lines = util.splitLines(src)
			for i = 1, #lines do
				lines[i] = lines[i]:gsub("[ \t]+$", "")
			end
			updated = table.concat(lines, "\n")
		elseif tf == "wrapPcall" then
			updated = "local ok, err = pcall(function()\n" .. src .. "\nend)\nif not ok then warn(err) end\n"
		elseif tf == "insertHeader" then
			local hdr = tostring(toolSpec.headerText or "-- Module Header")
			updated = hdr .. "\n" .. src
		end
		codeStore.updateContent(doc.id, updated)
		return true
	end

	-- Activate a verified extension in the live workbench (purely declarative — zero `loadstring`!)
	local function mountVerifiedExtension(manifest)
		local extId = manifest.id
		if M.activeCleanup[extId] then
			pcall(M.activeCleanup[extId])
			M.activeCleanup[extId] = nil
		end

		local tmpl = manifest.template
		if tmpl == "theme-pack" then
			local themeId = "ext_" .. extId:gsub("[^%w_]", "_")
			theme.registerCustomTheme(themeId, {
				name = manifest.name .. " (Ext)",
				isLight = manifest.theme.isLight == true,
				colors = manifest.theme.colors,
				syntax = manifest.theme.syntax,
			})
			M.activeCleanup[extId] = function()
				theme.unregisterCustomTheme(themeId)
			end
		elseif tmpl == "snippet-pack" then
			intellisense.registerSnippetPack(extId, manifest.snippets)
			M.activeCleanup[extId] = function()
				intellisense.unregisterSnippetPack(extId)
			end
		elseif tmpl == "command-macro" then
			local registeredIds = {}
			for _, mc in ipairs(manifest.macros) do
				local fullId = "ext." .. extId .. "." .. mc.id
				registeredIds[#registeredIds + 1] = fullId
				commands.register({
					id = fullId,
					title = mc.title,
					category = "Ext · " .. manifest.name,
					run = function()
						for _, step in ipairs(mc.steps) do
							if step.op == "insertText" then
								local doc = codeStore.active()
								if doc and not doc.readOnly then
									local cur = doc.view.cursor or (#doc.content + 1)
									local s = doc.content
									local ins = tostring(step.text or "")
									codeStore.updateContent(doc.id, s:sub(1, cur - 1) .. ins .. s:sub(cur))
								end
							elseif step.op == "openFile" and type(step.path) == "string" then
								codeStore.openFile(step.path)
							elseif step.op == "setSetting" and type(step.key) == "string" then
								config.set(step.key, step.value)
							elseif step.op == "applyTheme" and type(step.themeId) == "string" then
								theme.apply(step.themeId)
							elseif step.op == "openPreview" then
								commands.run("preview.openToSide")
							elseif step.op == "bundleWorkspace" then
								commands.run("project.bundle")
							end
						end
						return true
					end,
				})
			end
			M.activeCleanup[extId] = function()
				for _, cid in ipairs(registeredIds) do
					commands.unregister(cid)
				end
			end
		elseif tmpl == "keymap-preset" then
			local presetId = "ext_" .. extId
			shortcuts.registerCustomPreset(presetId, manifest.keymap.bindings)
			M.activeCleanup[extId] = function()
				shortcuts.unregisterCustomPreset(presetId)
			end
		elseif tmpl == "toolbar-tool" then
			local registeredIds = {}
			for _, tl in ipairs(manifest.tools) do
				local fullId = "ext." .. extId .. "." .. tl.id
				registeredIds[#registeredIds + 1] = fullId
				commands.register({
					id = fullId,
					title = tl.label,
					category = "Tool · " .. manifest.name,
					run = function()
						return executeSafeTransform(tl)
					end,
				})
			end
			M.activeCleanup[extId] = function()
				for _, cid in ipairs(registeredIds) do
					commands.unregister(cid)
				end
			end
		end
	end

	local function persistInstalled()
		local encoded = util.jsonEncode(M.installed)
		if encoded then
			pcall(function() fsx.write(INSTALLED_FILE, encoded) end)
		end
	end

	function M.install(submissionOrManifest)
		local scan = M.scanSubmission(submissionOrManifest)
		if not scan.ok or not scan.manifest then
			return false, "Blocked by Malware & Schema Scanner: " .. table.concat(scan.findings, "; "), scan
		end
		local manifest = scan.manifest
		M.installed[manifest.id] = manifest
		mountVerifiedExtension(manifest)
		persistInstalled()
		log.info("extensions", "Installed verified extension: " .. manifest.id .. " (" .. manifest.template .. ")")
		M.changed:fire(manifest.id)
		return true, manifest, scan
	end

	function M.uninstall(extId)
		if not M.installed[extId] then return false end
		if M.activeCleanup[extId] then
			pcall(M.activeCleanup[extId])
			M.activeCleanup[extId] = nil
		end
		M.installed[extId] = nil
		persistInstalled()
		log.info("extensions", "Uninstalled extension: " .. tostring(extId))
		M.changed:fire(extId)
		return true
	end

	function M.isInstalled(extId)
		return M.installed[extId] ~= nil
	end

	function M.listActiveToolbarTools()
		local out = {}
		for extId, manifest in pairs(M.installed) do
			if manifest.template == "toolbar-tool" and type(manifest.tools) == "table" then
				for _, tl in ipairs(manifest.tools) do
					out[#out + 1] = {
						commandId = "ext." .. extId .. "." .. tl.id,
						label = tl.label,
						extName = manifest.name,
					}
				end
			end
		end
		table.sort(out, function(a, b) return a.label < b.label end)
		return out
	end

	-- 5 Built-in Verified Starter Extensions (one for each of the 5 allowed templates!)
	M.STARTER_CATALOG = {
		{
			id = "cyberpunk-neon-theme",
			name = "Cyberpunk Neon 2077",
			version = "1.0.0",
			author = "VS-RBLX Official",
			summary = "High-contrast synthwave dark theme with electric cyan & magenta syntax tokens.",
			template = "theme-pack",
			theme = {
				isLight = false,
				colors = {
					titleBar = "#0b0716",
					activityBar = "#120b24",
					sideBar = "#100a20",
					editor = "#090612",
					editorGutter = "#090612",
					statusBar = "#ff2a85",
					accent = "#00f0ff",
					tabActive = "#090612",
					tabActiveTop = "#00f0ff",
				},
				syntax = {
					keyword = "#ff2a85",
					builtin = "#00f0ff",
					type = "#fcee09",
					string = "#39ff14",
					number = "#ff9e00",
					comment = "#6c5b9e",
					call = "#00f0ff",
				},
			},
		},
		{
			id = "roblox-net-combat-snippets",
			name = "Roblox Remote & Combat Snippets",
			version = "1.0.0",
			author = "VS-RBLX Official",
			summary = "Verified Luau snippets for RemoteEvents, debounce cooldowns, and Character Humanoid checks.",
			template = "snippet-pack",
			snippets = {
				{
					lang = "luau",
					trigger = "remfire",
					label = "RemoteEvent :FireServer()",
					insert = 'local ReplicatedStorage = game:GetService("ReplicatedStorage")\nReplicatedStorage:WaitForChild("$0"):FireServer()',
					detail = "Waits for a RemoteEvent in ReplicatedStorage and fires to server.",
				},
				{
					lang = "luau",
					trigger = "debounce",
					label = "Cooldown debounce guard",
					insert = "local busy = false\nlocal function withCooldown()\n\tif busy then return end\n\tbusy = true\n\t$0\n\ttask.wait(0.5)\n\tbusy = false\nend",
					detail = "Thread-safe cooldown debounce pattern.",
				},
				{
					lang = "luau",
					trigger = "humcheck",
					label = "Alive Humanoid guard",
					insert = 'local char = Players.LocalPlayer.Character\nlocal hum = char and char:FindFirstChildOfClass("Humanoid")\nif not hum or hum.Health <= 0 then return end\n$0',
					detail = "Checks LocalPlayer Character and alive Humanoid.",
				},
			},
		},
		{
			id = "luau-header-service-macros",
			name = "Luau Module Header & Services Macro",
			version = "1.0.0",
			author = "VS-RBLX Official",
			summary = "Adds 1-click Command Palette macros to insert standard Roblox service imports.",
			template = "command-macro",
			macros = {
				{
					id = "insertServicesBlock",
					title = "Insert Standard Roblox Services Header",
					steps = {
						{
							op = "insertText",
							text = "--!strict\nlocal Players = game:GetService(\"Players\")\nlocal ReplicatedStorage = game:GetService(\"ReplicatedStorage\")\nlocal RunService = game:GetService(\"RunService\")\n\n",
						},
					},
				},
			},
		},
		{
			id = "fleet-ergonomic-keymap",
			name = "JetBrains / Fleet Keymap Pack",
			version = "1.0.0",
			author = "VS-RBLX Official",
			summary = "Adds Alt+Enter suggest trigger and Ctrl+Alt+L document formatting.",
			template = "keymap-preset",
			keymap = {
				bindings = {
					{ ctrl = true, alt = true, key = "L", command = "editor.format" },
					{ alt = true, key = "Return", command = "editor.triggerSuggest" },
					{ ctrl = true, key = "E", command = "workbench.quickOpen" },
				},
			},
		},
		{
			id = "luau-buffer-power-tools",
			name = "Buffer Sort, Trim & pcall Wrapper Tools",
			version = "1.0.0",
			author = "VS-RBLX Official",
			summary = "Adds Sort Lines, Trim Trailing Whitespace, and Wrap in pcall() quick-action pills.",
			template = "toolbar-tool",
			tools = {
				{ id = "sortLines", label = "AZ Sort Lines", transform = "sortLines" },
				{ id = "trimLines", label = "✂ Trim Spaces", transform = "trimLines" },
				{ id = "wrapPcall", label = "🛡 Wrap pcall", transform = "wrapPcall" },
			},
		},
	}

	-- Fetch live community extension issues from GitHub Issues API & run every one through Malware Scanner!
	function M.syncFromGitHub(repoOverride)
		local repo = util.trim(repoOverride or M.hubRepo or DEFAULT_HUB_REPO)
		if repo == "" then repo = DEFAULT_HUB_REPO end
		M.hubRepo = repo

		local res = http.send({
			url = string.format("https://api.github.com/repos/%s/issues?state=open&per_page=30", repo),
			method = "GET",
			headers = headersUtil.github(github.token(), false),
		})
		if not res.ok or type(res.json) ~= "table" then
			return nil, res.error or ("HTTP " .. tostring(res.status))
		end

		local entries = {}
		for _, issue in ipairs(res.json) do
			if type(issue) == "table" and issue.pull_request == nil then
				local scan = M.scanSubmission(issue)
				entries[#entries + 1] = {
					issueNumber = issue.number,
					title = tostring(issue.title or ("Issue #" .. tostring(issue.number))),
					author = (type(issue.user) == "table" and tostring(issue.user.login or "community")) or "community",
					htmlUrl = tostring(issue.html_url or ""),
					comments = tonumber(issue.comments) or 0,
					scan = scan,
					manifest = scan.manifest,
				}
			end
		end

		M.remoteCatalog = entries
		log.info("extensions", string.format("Synced %d community extension issue(s) from %s", #entries, repo))
		M.changed:fire("*")
		return entries
	end

	-- Generate a clean, valid sample manifest for any of the 5 allowed templates
	function M.generateSampleManifest(templateId)
		for _, starter in ipairs(M.STARTER_CATALOG) do
			if starter.template == templateId then
				local encoded = util.jsonEncode(starter)
				local copy = encoded and util.jsonDecode(encoded) or starter
				copy.id = "my-" .. templateId
				copy.author = "your-github-handle"
				return copy
			end
		end
		return M.STARTER_CATALOG[1]
	end

	function M.generateIssueMarkdown(manifest)
		local jsonStr = util.jsonEncode(manifest) or "{}"
		return table.concat({
			"### Extension Template",
			"",
			tostring(manifest.template or "theme-pack"),
			"",
			"### Extension ID",
			"",
			tostring(manifest.id or "my-extension"),
			"",
			"### Display Name",
			"",
			tostring(manifest.name or "My Extension"),
			"",
			"### Version",
			"",
			tostring(manifest.version or "1.0.0"),
			"",
			"### Summary",
			"",
			tostring(manifest.summary or "Declarative community extension for VS-RBLX."),
			"",
			"### Manifest JSON",
			"",
			"```json",
			jsonStr,
			"```",
			"",
			"### Security Attestations",
			"",
			"- [X] This submission strictly uses one of the 5 declarative templates and contains zero executable Luau/bytecode.",
			"- [X] This submission contains zero webhooks, outbound URLs, obfuscated strings, or credential reads.",
		}, "\n")
	end

	-- Restore previously installed extensions on boot (re-scanning each one!)
	function M.loadInstalled()
		local raw = fsx.read(INSTALLED_FILE)
		if not raw then return end
		local decoded = util.jsonDecode(raw)
		if type(decoded) ~= "table" then return end
		for extId, manifest in pairs(decoded) do
			local scan = M.scanSubmission(manifest)
			if scan.ok and scan.manifest then
				M.installed[extId] = scan.manifest
				mountVerifiedExtension(scan.manifest)
			else
				log.warn("extensions", "Skipped tampered persisted extension `" .. tostring(extId) .. "`")
			end
		end
	end

	M.loadInstalled()

	return M
end
