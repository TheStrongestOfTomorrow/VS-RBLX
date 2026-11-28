-- Event-Driven VS Code AI Agent Loop & Permission Gate (`src/ai/agent_loop.lua`).
-- Manages conversation history, `#file` / `#selection` / `#problems` context attachments,
-- multi-turn tool dispatch, and 3-tier Permission Gating (`read_only`, `ask_first`, `auto`).
-- Architectural inspiration credited to Project UAI (MIT © CarlDV / Project-Ptolemy).
return function(env)
	local config = env.require("runtime/config")
	local fsx = env.require("runtime/fsx")
	local signal = env.require("runtime/signal")
	local util = env.require("runtime/util")
	local codeStore = env.require("runtime/code_store")
	local diagnostics = env.require("runtime/diagnostics")
	local robloxExplorer = env.require("runtime/roblox_explorer")
	local providers = env.require("ai/providers")
	local aiTools = env.require("ai/tools")

	local THREADS_FILE = "ai/threads/index.json"
	local LEGACY_HISTORY_FILE = "ai/history.json"
	local MAX_THREADS = 30
	local MAX_HISTORY_MESSAGES = 30
	local MAX_TOOL_ROUNDS = 10

	local M = {
		messages = {}, -- active UI transcript entries
		busy = false,
		cancelled = false,
		historySaveError = nil,
		pendingApproval = nil, -- `{ toolName, args, summary, resolve = fn(allowBool) }`
		stats = { requests = 0, promptTokens = 0, completionTokens = 0 },
		changed = signal.new("ai.changed"),
	}
	local threadRecords = {}
	local activeThreadId = nil
	local nextThreadSerial = 0

	-- Keep this prompt outcome-focused: complex scripts need a repeatable inspect/build/
	-- validate loop, not a magic phrase or a bloated one-shot instruction. Tool schemas
	-- provide exact APIs; permission checks remain enforced by the agent loop below.
	local SYSTEM_PROMPT = table.concat({
		"You are VS-RBLX AI, a capable coding agent inside a Roblox client. Deliver the requested outcome, not just advice, when the user asks for an implementation.",
		"For substantial scripts, multi-file work, or complex GUIs, work in stages: extract explicit requirements and observable acceptance criteria; inspect relevant workspace files, live context, and available APIs; form a concise plan; implement the complete solution; compile it; run only when appropriate and authorized; inspect evidence and fix specific failures. Do not stop at a stub, TODO list, or partial scaffold unless the user asked for one.",
		"Use the actual offered tool schemas. Read existing code and related files before editing; use workspace_search/list/read to build context, workspace_edit_file for a unique surgical change, workspace_write_file for a new or intentionally replaced file, and check_luau_syntax before claiming syntax validation.",
		"Write idiomatic Roblox Luau. Use real Roblox services/APIs, distinguish LocalScript/client behavior from server-authoritative behavior, and never claim a local change replicated unless observed. For recurring connections, instances, input bindings, and tasks, include explicit cleanup and error handling appropriate to their lifetime.",
		"For GUI code, implement the requested controls and states completely; account for touch targets, viewport resizing, scrolling, keyboard/input behavior, readable hierarchy, and cleanup. Avoid unsupported APIs, placeholder callbacks, hidden assumptions, and unrelated features.",
		"When requirements are clear, proceed without ritual questions. Ask only for a decision that genuinely blocks implementation. A tool permission mode controls authorization for VS-RBLX tool calls; it is not a reason to decline ordinary coding help. Never bypass approvals, tool scopes, or applicable safety rules.",
		"Use at most ten tool-call rounds per request, choosing the smallest useful checks. A successful compile proves syntax only; a bounded run proves only the effects actually observed. Report remaining limitations plainly.",
		"For a standalone code request, provide a complete ```luau fenced script, not disconnected fragments, unless the user asked for another format.",
	}, " ")

	function M.permissionMode()
		local m = tostring(config.get("ai.permissionMode", "ask_first") or "ask_first")
		if m ~= "read_only" and m ~= "ask_first" and m ~= "auto" then
			return "ask_first"
		end
		return m
	end

	function M.setPermissionMode(mode)
		if mode ~= "read_only" and mode ~= "ask_first" and mode ~= "auto" then
			mode = "ask_first"
		end
		config.set("ai.permissionMode", mode, { immediate = true })
		M.changed:fire("permission")
		return mode
	end

	function M.cyclePermissionMode()
		local cur = M.permissionMode()
		if cur == "ask_first" then return M.setPermissionMode("auto")
		elseif cur == "auto" then return M.setPermissionMode("read_only")
		else return M.setPermissionMode("ask_first") end
	end

	local function truncateUtf8(value, maxBytes)
		local text = tostring(value or "")
		if #text <= maxBytes then return text end
		local cut = text:sub(1, math.max(0, maxBytes))
		while #cut > 0 and not util.validUtf8(cut) do cut = cut:sub(1, -2) end
		return cut
	end

	local function shortTitle(value, maxBytes)
		local text = util.trim(tostring(value or "")):gsub("%s+", " ")
		if #text <= maxBytes then return text end
		return truncateUtf8(text, math.max(1, maxBytes - 3)) .. "..."
	end

	local function cleanMessages(source)
		local result = {}
		if type(source) ~= "table" then return result end
		local first = math.max(1, #source - MAX_HISTORY_MESSAGES + 1)
		for i = first, #source do
			local item = source[i]
			if type(item) == "table" and (item.role == "user" or item.role == "assistant" or item.role == "tool" or item.role == "error") then
				result[#result + 1] = {
					role = item.role,
					text = truncateUtf8(item.text or "", 16000),
					codeBlock = type(item.codeBlock) == "string" and truncateUtf8(item.codeBlock, 32000) or nil,
					toolName = type(item.toolName) == "string" and truncateUtf8(item.toolName, 128) or nil,
					ok = item.role == "tool" and item.ok == true or nil,
				}
			end
		end
		return result
	end

	local function saveHistory()
		local current
		for _, record in ipairs(threadRecords) do
			if record.id == activeThreadId then current = record break end
		end
		if not current then
			M.historySaveError = "No active conversation"
			return false, M.historySaveError
		end
		current.messages = cleanMessages(M.messages)
		current.updatedAt = os.time()
		local encoded = {}
		for _, record in ipairs(threadRecords) do
			encoded[#encoded + 1] = {
				id = record.id,
				title = record.title,
				createdAt = record.createdAt,
				updatedAt = record.updatedAt,
				archived = record.archived == true,
				messages = record.messages,
			}
		end
		local raw, encodeErr = util.jsonEncode({ version = 1, currentId = activeThreadId, threads = encoded })
		if not raw then
			M.historySaveError = tostring(encodeErr or "Unable to encode conversation index")
			return false, M.historySaveError
		end
		local called, wrote, writeErr = pcall(fsx.write, THREADS_FILE, raw)
		if not called then
			M.historySaveError = tostring(wrote)
			return false, M.historySaveError
		end
		if wrote ~= true then
			M.historySaveError = tostring(writeErr or "Unable to write conversation index")
			return false, M.historySaveError
		end
		M.historySaveError = nil
		return true
	end

	local function threadById(id)
		for _, record in ipairs(threadRecords) do
			if record.id == tostring(id or "") then return record end
		end
		return nil
	end

	local function makeThreadId()
		nextThreadSerial = nextThreadSerial + 1
		local base = "chat-" .. tostring(os.time()) .. "-" .. tostring(nextThreadSerial)
		local id = base
		local suffix = 1
		while threadById(id) do
			suffix = suffix + 1
			id = base .. "-" .. tostring(suffix)
		end
		return id
	end

	local function newThreadRecord(title)
		local now = os.time()
		local record = {
			id = makeThreadId(),
			title = shortTitle(title or "New Chat", 64),
			createdAt = now,
			updatedAt = now,
			archived = false,
			messages = {},
		}
		threadRecords[#threadRecords + 1] = record
		while #threadRecords > MAX_THREADS do
			local oldestIdx = 1
			for i = 2, #threadRecords do
				if (tonumber(threadRecords[i].updatedAt) or 0) < (tonumber(threadRecords[oldestIdx].updatedAt) or 0) then
					oldestIdx = i
				end
			end
			if threadRecords[oldestIdx].id == activeThreadId and #threadRecords > 1 then
				oldestIdx = oldestIdx == 1 and 2 or 1
			end
			table.remove(threadRecords, oldestIdx)
		end
		return record
	end

	function M.currentThread()
		local record = activeThreadId and threadById(activeThreadId) or nil
		if not record then return nil end
		return { id = record.id, title = record.title, createdAt = record.createdAt, updatedAt = record.updatedAt, archived = record.archived == true }
	end

	function M.listThreads()
		local result = {}
		for _, record in ipairs(threadRecords) do
			local last = record.messages and record.messages[#record.messages]
			result[#result + 1] = {
				id = record.id,
				title = record.title,
				createdAt = record.createdAt,
				updatedAt = record.updatedAt,
				archived = record.archived == true,
				messageCount = #(record.messages or {}),
					snippet = shortTitle(last and last.text or "", 72),
					active = record.id == activeThreadId,
			}
		end
		table.sort(result, function(a, b)
			if a.updatedAt == b.updatedAt then return a.id > b.id end
			return a.updatedAt > b.updatedAt
		end)
		return result
	end

	function M.searchThreads(query)
		local needle = util.trim(tostring(query or "")):lower()
		local all = M.listThreads()
		if needle == "" then return all end
		local result = {}
		for _, item in ipairs(all) do
			local record = threadById(item.id)
			local matched = item.title:lower():find(needle, 1, true) ~= nil
			if not matched and record then
				for _, msg in ipairs(record.messages or {}) do
					if tostring(msg.text or ""):lower():find(needle, 1, true) then
						matched = true
						break
					end
				end
			end
			if matched then result[#result + 1] = item end
		end
		return result
	end

	function M.loadHistory()
		threadRecords = {}
		local raw = fsx.read(THREADS_FILE)
		local decoded = raw and util.jsonDecode(raw) or nil
		if type(decoded) == "table" and type(decoded.threads) == "table" then
			for _, item in ipairs(decoded.threads) do
				local cleanId = type(item) == "table" and type(item.id) == "string" and truncateUtf8(item.id, 96) or ""
				if cleanId ~= "" and not threadById(cleanId) then
					threadRecords[#threadRecords + 1] = {
						id = cleanId,
						title = shortTitle(item.title or "New Chat", 64),
						createdAt = tonumber(item.createdAt) or os.time(),
						updatedAt = tonumber(item.updatedAt) or os.time(),
						archived = item.archived == true,
						messages = cleanMessages(item.messages),
					}
				end
			end
			activeThreadId = truncateUtf8(decoded.currentId or "", 96)
		else
			-- Migrate the original single-chat JSON array without discarding it on a bad decode.
			local legacyRaw = fsx.read(LEGACY_HISTORY_FILE)
			local legacy = legacyRaw and util.jsonDecode(legacyRaw) or nil
			if type(legacy) == "table" then
				local migrated = newThreadRecord("Previous Chat")
				migrated.messages = cleanMessages(legacy)
				activeThreadId = migrated.id
			end
		end
		if #threadRecords == 0 then
			local fresh = newThreadRecord("New Chat")
			activeThreadId = fresh.id
		end
		if not threadById(activeThreadId) then
			local recent = M.listThreads()[1]
			activeThreadId = recent and recent.id or threadRecords[1].id
		end
		local active = threadById(activeThreadId)
		M.messages = active.messages
		saveHistory()
	end

	function M.createThread(title)
		if M.busy then return nil, "Cannot switch chats while the AI is processing" end
		saveHistory()
		local record = newThreadRecord(title or "New Chat")
		activeThreadId = record.id
		M.messages = record.messages
		M.pendingApproval = nil
		saveHistory()
		M.changed:fire("thread")
		return M.currentThread()
	end

	function M.switchThread(id)
		if M.busy then return false, "Cannot switch chats while the AI is processing" end
		local record = threadById(id)
		if not record then return false, "Chat not found" end
		if record.id == activeThreadId then return true end
		saveHistory()
		activeThreadId = record.id
		M.messages = record.messages
		M.pendingApproval = nil
		saveHistory()
		M.changed:fire("thread")
		return true
	end

	function M.renameThread(id, title)
		if M.busy then return false, "Cannot rename a chat while the AI is processing" end
		local record = threadById(id)
		if not record then return false, "Chat not found" end
		local clean = shortTitle(title, 64)
		if clean == "" then return false, "Chat title cannot be empty" end
		record.title = clean
		record.updatedAt = os.time()
		saveHistory()
		M.changed:fire("thread")
		return true
	end

	function M.archiveThread(id, archived)
		if M.busy then return false, "Cannot archive a chat while the AI is processing" end
		local record = threadById(id)
		if not record then return false, "Chat not found" end
		local shouldArchive = archived ~= false
		record.archived = shouldArchive
		record.updatedAt = os.time()
		if shouldArchive and record.id == activeThreadId then
			local replacement
			for _, candidate in ipairs(M.listThreads()) do
				if candidate.id ~= record.id and not candidate.archived then
					replacement = candidate.id
					break
				end
			end
			if not replacement then replacement = newThreadRecord("New Chat").id end
			activeThreadId = replacement
			M.messages = threadById(replacement).messages
		end
		local saved, saveErr = saveHistory()
		M.changed:fire("thread")
		if not saved then return false, saveErr end
		return true
	end

	function M.exportThread(id)
		local record = threadById(id)
		if not record then return nil, "Chat not found" end
		local payload = {
			version = 1,
			id = record.id,
			title = record.title,
			createdAt = record.createdAt,
			updatedAt = record.updatedAt,
			archived = record.archived == true,
			messages = cleanMessages(record.messages),
		}
		local raw, encodeErr = util.jsonEncode(payload)
		if not raw then return nil, tostring(encodeErr or "Unable to encode conversation export") end
		local safeId = tostring(record.id):gsub("[^%w%-_]", "_"):sub(1, 96)
		local path = "ai/exports/" .. safeId .. ".json"
		local ok, writeErr = fsx.write(path, raw)
		if not ok then return nil, tostring(writeErr or "Unable to save conversation export") end
		return path
	end

	function M.deleteThread(id)
		if M.busy then return false, "Cannot delete a chat while the AI is processing" end
		local target = threadById(id)
		if not target then return false, "Chat not found" end
		for i = #threadRecords, 1, -1 do
			if threadRecords[i].id == target.id then table.remove(threadRecords, i) break end
		end
		if #threadRecords == 0 then
			local fresh = newThreadRecord("New Chat")
			activeThreadId = fresh.id
		elseif activeThreadId == target.id then
			local recent = M.listThreads()[1]
			activeThreadId = recent.id
		end
		local active = threadById(activeThreadId)
		M.messages = active and active.messages or {}
		M.pendingApproval = nil
		saveHistory()
		M.changed:fire("thread")
		return true
	end

	function M.clearHistory()
		if M.busy then return false end
		M.messages = {}
		M.pendingApproval = nil
		local active = threadById(activeThreadId)
		if active then active.messages = {} end
		saveHistory()
		M.changed:fire("clear")
		return true
	end

	function M.cancel()
		if M.busy then
			M.cancelled = true
		end
		if M.pendingApproval then
			local pa = M.pendingApproval
			M.pendingApproval = nil
			if pa.resolve then pa.resolve(false) end
		end
		M.busy = false
		M.changed:fire("cancel")
	end

	function M.extractFirstCodeBlock(text)
		text = tostring(text or "")
		local fenced = text:match("```[%w_%-]*\r?\n(.-)```")
		if fenced then
			return (fenced:gsub("\r\n", "\n"):gsub("\n$", ""))
		end
		return nil
	end

	local function buildContextBlock(opts)
		opts = opts or {}
		local parts = {}
		local activeDoc = codeStore.active("primary")

		if opts.attachActiveFile ~= false and activeDoc then
			parts[#parts + 1] = string.format(
				"[Active File: %s (%s)]\n```%s\n%s\n```",
				tostring(activeDoc.path or activeDoc.title),
				tostring(activeDoc.langId or "luau"),
				tostring(activeDoc.langId or "luau"),
				tostring(activeDoc.content or ""):sub(1, 12000)
			)
		end

		if type(opts.selectionText) == "string" and opts.selectionText ~= "" then
			parts[#parts + 1] = "[Selected Code]\n```\n" .. opts.selectionText:sub(1, 6000) .. "\n```"
		end

		if opts.attachProblems then
			local list = diagnostics.all()
			local lines = {}
			for i = 1, math.min(15, #list) do
				local d = list[i]
				lines[#lines + 1] = string.format("- %s:%d [%s] %s", tostring(d.title), tonumber(d.line) or 1, tostring(d.severity), tostring(d.message))
			end
			if #lines > 0 then
				parts[#parts + 1] = "[Workspace Diagnostics]\n" .. table.concat(lines, "\n")
			end
		end

		if opts.attachRemotes then
			local rems = robloxExplorer.listRemotes(20)
			local lines = {}
			for _, r in ipairs(rems) do
				lines[#lines + 1] = string.format("- %s (%s)", r.luauPath, r.className)
			end
			if #lines > 0 then
				parts[#parts + 1] = "[Discovered Roblox Remotes]\n" .. table.concat(lines, "\n")
			end
		end

		return table.concat(parts, "\n\n")
	end

	-- Synchronous/async-friendly single turn or full multi-tool agent turn!
	function M.send(userPrompt, opts)
		opts = opts or {}
		local cleanPrompt = util.trim(tostring(userPrompt or ""))
		if cleanPrompt == "" then return nil, "Prompt is empty" end
		if M.busy then return nil, "AI assistant is already processing a request" end

		M.busy = true
		M.cancelled = false

		local activeDoc = codeStore.active("primary")
		local activeCode = (opts.selectionText and opts.selectionText ~= "") and opts.selectionText
			or (activeDoc and activeDoc.content or "")

		-- Never let an arbitrary caller-supplied mode fall through to write access.
		local permMode = M.permissionMode()
		if opts.permissionMode ~= nil then
			if opts.permissionMode == "read_only" or opts.permissionMode == "ask_first" or opts.permissionMode == "auto" then
				permMode = opts.permissionMode
			else
				permMode = "ask_first"
			end
		end
		local toolSchemas = aiTools.schemasForMode(permMode)

		M.messages[#M.messages + 1] = {
			role = "user",
			text = cleanPrompt,
		}
		local activeThread = threadById(activeThreadId)
		if activeThread and activeThread.title == "New Chat" then
			activeThread.title = shortTitle(cleanPrompt, 64)
		end
		saveHistory()
		M.changed:fire("user")

		local wireMsgs = {
			{
				role = "system",
				content = SYSTEM_PROMPT .. " Current tool permission mode: " .. permMode
					.. ". Use only the tools and actions actually listed in this request.",
			},
		}
		local startHist = math.max(1, #M.messages - 10)
		for i = startHist, #M.messages - 1 do
			local m = M.messages[i]
			if m.role == "user" or m.role == "assistant" then
				wireMsgs[#wireMsgs + 1] = { role = m.role, content = m.text }
			end
		end

		local ctxStr = buildContextBlock(opts)
		local fullFinalUser = (ctxStr ~= "") and (ctxStr .. "\n\nUser Request: " .. cleanPrompt) or cleanPrompt
		wireMsgs[#wireMsgs + 1] = { role = "user", content = fullFinalUser }

		local finalReply = nil
		local lastErr = nil

		for _ = 1, MAX_TOOL_ROUNDS do
			if M.cancelled then
				lastErr = "Cancelled by user"
				break
			end

			M.stats.requests = M.stats.requests + 1
			local resp, err = providers.complete({
				providerId = opts.providerId,
				model = opts.model,
				messages = wireMsgs,
				tools = toolSchemas,
				activeCode = activeCode,
			})
			if not resp then
				lastErr = tostring(err)
				break
			end

			M.stats.promptTokens = M.stats.promptTokens + (resp.usage and resp.usage.promptTokens or 0)
			M.stats.completionTokens = M.stats.completionTokens + (resp.usage and resp.usage.completionTokens or 0)

			if type(resp.toolCalls) == "table" and #resp.toolCalls > 0 then
				wireMsgs[#wireMsgs + 1] = {
					role = "assistant",
					content = resp.content or "",
					tool_calls = resp.toolCalls,
				}

				for _, tc in ipairs(resp.toolCalls) do
					if M.cancelled then break end
					local toolDef = aiTools.find(tc.name)
					local parsedArgs = util.jsonDecode(tc.arguments or "{}") or {}
					local toolResult

					if not toolDef then
						toolResult = { ok = false, error = "Unknown tool: " .. tostring(tc.name) }
					elseif (not toolDef.readOnly) and permMode == "read_only" then
						toolResult = { ok = false, error = "Denied: Permission mode is Read Only" }
					elseif (not toolDef.readOnly) and permMode == "ask_first" then
						-- Pause and wait for user approval in UI (or custom `opts.onApprove` callback!)
						local approved = false
						if type(opts.onApprove) == "function" then
							approved = opts.onApprove(tc.name, parsedArgs) == true
						else
							local decided = false
							M.pendingApproval = {
								toolName = tc.name,
								args = parsedArgs,
								summary = string.format("%s(%s)", tc.name, tostring(parsedArgs.path or parsedArgs.code or "...")):sub(1, 120),
								resolve = function(allow)
									approved = (allow == true)
									decided = true
								end,
							}
							M.changed:fire("approval_needed")
							local waitStart = os.clock()
							while not decided and not M.cancelled and (os.clock() - waitStart < 120) do
								task.wait(0.05)
							end
							M.pendingApproval = nil
						end

						if approved then
							local okT, resT = pcall(toolDef.run, parsedArgs)
							toolResult = okT and resT or { ok = false, error = tostring(resT) }
						else
							toolResult = { ok = false, error = "User declined tool execution" }
						end
					else
						local okT, resT = pcall(toolDef.run, parsedArgs)
						toolResult = okT and resT or { ok = false, error = tostring(resT) }
					end

					M.messages[#M.messages + 1] = {
						role = "tool",
						toolName = tc.name,
						ok = toolResult and toolResult.ok == true,
						text = string.format("%s %s", (toolResult and toolResult.ok) and "✓" or "✕", tc.name),
					}
					M.changed:fire("tool")
					saveHistory()

					wireMsgs[#wireMsgs + 1] = {
						role = "tool",
						tool_call_id = tc.id,
						content = util.jsonEncode(toolResult) or "{}",
					}
				end
			else
				local codeBlock = resp.codeBlock or M.extractFirstCodeBlock(resp.content)
				finalReply = {
					role = "assistant",
					text = tostring(resp.content or ""),
					reasoning = tostring(resp.reasoning or ""),
					codeBlock = codeBlock,
				}
				M.messages[#M.messages + 1] = finalReply
				saveHistory()
				break
			end
		end

		M.busy = false
		if not finalReply then
			local errMsg = lastErr or "Reached maximum tool-call iterations"
			M.messages[#M.messages + 1] = {
				role = "error",
				text = "⚠ " .. tostring(errMsg),
			}
			saveHistory()
			M.changed:fire("error")
			return nil, errMsg
		end

		M.changed:fire("reply")
		return finalReply
	end

	M.loadHistory()
	return M
end
