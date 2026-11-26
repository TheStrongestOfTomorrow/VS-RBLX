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

	local HISTORY_FILE = "ai/history.json"
	local MAX_TOOL_ROUNDS = 6

	local M = {
		messages = {}, -- UI transcript entries
		busy = false,
		cancelled = false,
		pendingApproval = nil, -- `{ toolName, args, summary, resolve = fn(allowBool) }`
		stats = { requests = 0, promptTokens = 0, completionTokens = 0 },
		changed = signal.new("ai.changed"),
	}

	local SYSTEM_PROMPT = table.concat({
		"You are VS-RBLX AI, an integrated VS Code-style coding assistant running directly inside Roblox.",
		"Follow the smallest-complete-change principle: read workspace files before editing, prefer surgical `workspace_edit_file` replacements, and verify Luau syntax via `check_luau_syntax`.",
		"Write clean Lua 5.1-compatible Roblox Luau (`game:GetService(...)`, `task.spawn`, `pcall`) and wrap standalone code suggestions in ```luau fenced blocks.",
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

	local function saveHistory()
		local slim = {}
		local startIdx = math.max(1, #M.messages - 30)
		for i = startIdx, #M.messages do
			local it = M.messages[i]
			if it.role == "user" or it.role == "assistant" then
				slim[#slim + 1] = {
					role = it.role,
					text = it.text,
					codeBlock = it.codeBlock,
				}
			end
		end
		local raw = util.jsonEncode(slim)
		if raw then pcall(fsx.write, HISTORY_FILE, raw) end
	end

	function M.loadHistory()
		local raw = fsx.read(HISTORY_FILE)
		if not raw then return end
		local arr = util.jsonDecode(raw)
		if type(arr) ~= "table" then return end
		M.messages = {}
		for _, it in ipairs(arr) do
			if type(it) == "table" and (it.role == "user" or it.role == "assistant") then
				M.messages[#M.messages + 1] = {
					role = it.role,
					text = tostring(it.text or ""),
					codeBlock = it.codeBlock,
				}
			end
		end
	end

	function M.clearHistory()
		M.messages = {}
		M.pendingApproval = nil
		pcall(fsx.delete, HISTORY_FILE)
		M.changed:fire("clear")
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

		M.messages[#M.messages + 1] = {
			role = "user",
			text = cleanPrompt,
		}
		M.changed:fire("user")

		local wireMsgs = {
			{ role = "system", content = SYSTEM_PROMPT },
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

		local permMode = opts.permissionMode or M.permissionMode()
		local toolSchemas = aiTools.schemasForMode(permMode)

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
			M.changed:fire("error")
			return nil, errMsg
		end

		M.changed:fire("reply")
		return finalReply
	end

	M.loadHistory()
	return M
end
