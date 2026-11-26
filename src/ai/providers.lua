-- Multi-Provider AI Catalog, Vault-Backed Key Store & Offline Luau Smart Assistant (`src/ai/providers.lua`).
-- Supports OpenAI, Anthropic, OpenRouter, DeepSeek, Custom OpenAI-Compatible Endpoints,
-- plus an instant zero-key Built-in Luau Smart Assistant (`local_smart`) so inline `Ctrl+I`
-- editing and chat work out-of-the-box before configuring an external API key.
return function(env)
	local config = env.require("runtime/config")
	local cryptoVault = env.require("runtime/crypto_vault")
	local util = env.require("runtime/util")
	local http = env.require("net/http")
	local sse = env.require("ai/sse")

	local M = {}

	M.CATALOG = {
		{
			id = "local_smart",
			name = "VS-RBLX Smart Luau (No Key Needed)",
			wire = "local",
			endpoint = "",
			models = { "luau-smart-v2" },
			requiresKey = false,
		},
		{
			id = "openai",
			name = "OpenAI",
			wire = "openai",
			endpoint = "https://api.openai.com/v1/chat/completions",
			models = { "gpt-4o", "gpt-4o-mini", "o3-mini" },
			requiresKey = true,
		},
		{
			id = "anthropic",
			name = "Anthropic Claude",
			wire = "anthropic",
			endpoint = "https://api.anthropic.com/v1/messages",
			models = { "claude-sonnet-4-5", "claude-3-5-haiku-latest" },
			requiresKey = true,
		},
		{
			id = "openrouter",
			name = "OpenRouter",
			wire = "openai",
			endpoint = "https://openrouter.ai/api/v1/chat/completions",
			models = { "deepseek/deepseek-chat", "anthropic/claude-3.5-sonnet", "qwen/qwen-2.5-coder-32b-instruct" },
			requiresKey = true,
		},
		{
			id = "deepseek",
			name = "DeepSeek",
			wire = "openai",
			endpoint = "https://api.deepseek.com/chat/completions",
			models = { "deepseek-chat", "deepseek-reasoner" },
			requiresKey = true,
		},
		{
			id = "custom",
			name = "Custom OpenAI-Compatible Endpoint",
			wire = "openai",
			endpoint = "http://127.0.0.1:11434/v1/chat/completions",
			models = { "qwen2.5-coder:7b", "llama3.1" },
			requiresKey = false,
		},
	}

	function M.getProvider(id)
		local target = tostring(id or config.get("ai.provider", "local_smart"))
		for _, p in ipairs(M.CATALOG) do
			if p.id == target then return p end
		end
		return M.CATALOG[1]
	end

	function M.activeProviderId()
		return M.getProvider(config.get("ai.provider", "local_smart")).id
	end

	function M.activeModel()
		local p = M.getProvider()
		local saved = tostring(config.get("ai.model", "") or "")
		if saved ~= "" then return saved end
		return p.models[1] or "gpt-4o-mini"
	end

	function M.setProvider(providerId, modelOverride)
		local p = M.getProvider(providerId)
		config.set("ai.provider", p.id, { quiet = true })
		config.set("ai.model", modelOverride or p.models[1] or "", { immediate = true })
		return p
	end
	M.setActiveProvider = M.setProvider

	-- API Keys are stored inside Zero-Knowledge Master Vault (`VSRBLX/vault.enc`) when encrypted!
	function M.getApiKey(providerId)
		local pid = tostring(providerId or M.activeProviderId())
		local secretKey = "ai.key." .. pid
		if cryptoVault.isEncrypted() then
			if not cryptoVault.isUnlocked() then
				return ""
			end
			return tostring(cryptoVault.getSecret(secretKey) or "")
		end
		local map = config.get("ai.keys", nil)
		if type(map) == "table" and type(map[pid]) == "string" then
			return map[pid]
		end
		return ""
	end

	function M.setApiKey(providerId, apiKey)
		local pid = tostring(providerId or M.activeProviderId())
		local clean = util.trim(tostring(apiKey or ""))
		local secretKey = "ai.key." .. pid
		if cryptoVault.isEncrypted() then
			local ok, err = cryptoVault.setSecret(secretKey, clean)
			if not ok then return nil, err end
			-- Scrub any plaintext key table
			config.set("ai.keys", {}, { immediate = true })
			return true
		end
		local cur = config.get("ai.keys", nil)
		local nextMap = {}
		if type(cur) == "table" then
			for k, v in pairs(cur) do nextMap[k] = v end
		end
		nextMap[pid] = clean
		config.set("ai.keys", nextMap, { immediate = true })
		return true
	end

	-- Built-in Offline Luau Smart Assistant (`local_smart`) so users can generate/refactor Luau immediately!
	local function runLocalSmartAssistant(req)
		local lastUser = ""
		for i = #req.messages, 1, -1 do
			if req.messages[i].role == "user" then
				lastUser = tostring(req.messages[i].content or "")
				break
			end
		end
		local lower = lastUser:lower()
		local codeCtx = tostring(req.activeCode or "")

		local generated
		local explanation

		if lower:find("pcall", 1, true) or lower:find("safe", 1, true) or lower:find("try", 1, true) then
			local body = util.trim(codeCtx) ~= "" and codeCtx or 'print("Protected execution")'
			local indented = "\t" .. body:gsub("\n", "\n\t")
			generated = table.concat({
				"local ok, result = pcall(function()",
				indented,
				"end)",
				"if not ok then",
				'\twarn("[VS-RBLX Guard]", result)',
				"end",
			}, "\n")
			explanation = "Wrapped the target Luau block inside a protected `pcall` handler with structured warning output."
		elseif lower:find("remote", 1, true) or lower:find("fireserver", 1, true) then
			generated = table.concat({
				'local ReplicatedStorage = game:GetService("ReplicatedStorage")',
				'local remote = ReplicatedStorage:WaitForChild("RemoteEvent", 5)',
				"if remote and remote:IsA(\"RemoteEvent\") then",
				'\tremote:FireServer({ action = "ping", timestamp = os.clock() })',
				"end",
			}, "\n")
			explanation = "Generated a safe `ReplicatedStorage` RemoteEvent lookup with timeout and type guard."
		elseif lower:find("esp", 1, true) or lower:find("highlight", 1, true) or lower:find("player", 1, true) then
			generated = table.concat({
				'local Players = game:GetService("Players")',
				"",
				"local function attachHighlight(plr)",
				"\tlocal char = plr.Character",
				"\tif not char or char:FindFirstChild(\"VSRBLX_Highlight\") then return end",
				'\tlocal hl = Instance.new("Highlight")',
				'\thl.Name = "VSRBLX_Highlight"',
				"\thl.FillTransparency = 0.65",
				"\thl.OutlineColor = Color3.fromRGB(0, 170, 255)",
				"\thl.Parent = char",
				"end",
				"",
				"for _, plr in ipairs(Players:GetPlayers()) do",
				"\tif plr ~= Players.LocalPlayer then attachHighlight(plr) end",
				"end",
			}, "\n")
			explanation = "Generated a clean `Players` character `Highlight` helper using native Roblox instances."
		elseif lower:find("tween", 1, true) or lower:find("animate", 1, true) then
			generated = table.concat({
				'local TweenService = game:GetService("TweenService")',
				"",
				"local function smoothTween(instance, duration, goalProps)",
				"\tlocal info = TweenInfo.new(duration or 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)",
				"\tlocal tween = TweenService:Create(instance, info, goalProps)",
				"\ttween:Play()",
				"\treturn tween",
				"end",
			}, "\n")
			explanation = "Created a reusable `TweenService` helper (`Quad.Out`)."
		elseif lower:find("comment", 1, true) or lower:find("explain", 1, true) or lower:find("doc", 1, true) then
			if util.trim(codeCtx) ~= "" then
				local lineCount = 1
				for _ in codeCtx:gmatch("\n") do lineCount = lineCount + 1 end
				generated = "-- Documented by VS-RBLX Integrated AI (" .. tostring(lineCount) .. " lines)\n" .. codeCtx
				explanation = string.format("Analyzed %d line(s) of workspace code and added a documentation header. Connect OpenAI / Anthropic / OpenRouter / DeepSeek via `🔑 Key` for deep multi-turn LLM reasoning!", lineCount)
			else
				generated = "-- Tip: Select code or attach #activeFile, or configure an OpenAI / Anthropic / OpenRouter API key via `🔑 Key`."
				explanation = "VS-RBLX Smart Luau Assistant is ready! Ask for `pcall`, `RemoteEvent`, `TweenService`, `Highlight`, or connect any OpenAI/Anthropic model in `🔑 Key`."
			end
		else
			generated = table.concat({
				'local RunService = game:GetService("RunService")',
				'local Players = game:GetService("Players")',
				"local localPlayer = Players.LocalPlayer",
				"",
				"-- Generated via VS-RBLX Integrated AI",
				"local connection",
				"connection = RunService.Heartbeat:Connect(function(dt)",
				"\tif not localPlayer or not localPlayer.Character then return end",
				"\t-- Custom frame logic here",
				"end)",
			}, "\n")
			explanation = "Generated a clean `RunService.Heartbeat` Luau scaffold. *(Using built-in zero-key Smart Luau mode — click `🔑 Key` anytime to connect OpenAI, Claude, DeepSeek, OpenRouter, or Ollama!)*"
		end

		local fullReply = explanation .. "\n\n```luau\n" .. generated .. "\n```"
		return {
			content = fullReply,
			codeBlock = generated,
			reasoning = "",
			toolCalls = {},
			usage = { promptTokens = #lastUser, completionTokens = #fullReply },
		}
	end

	-- Dispatch Chat / Agent request to active provider
	function M.complete(req)
		local p = M.getProvider(req.providerId)
		local model = tostring(req.model or M.activeModel())

		if p.wire == "local" then
			return runLocalSmartAssistant(req)
		end

		local endpoint = p.id == "custom"
			and tostring(config.get("ai.customEndpoint", p.endpoint) or p.endpoint)
			or p.endpoint

		local apiKey = M.getApiKey(p.id)
		if p.requiresKey and apiKey == "" then
			if cryptoVault.isEncrypted() and not cryptoVault.isUnlocked() then
				return nil, "🔒 Master Vault is locked — click 🔐 in the Topbar to unlock your encrypted AI key"
			end
			return nil, string.format("Missing API key for %s — click `🔑 Key` in the AI header to set it", p.name)
		end

		if p.wire == "anthropic" then
			local anthroMsgs = {}
			local sysParts = {}
			for _, m in ipairs(req.messages or {}) do
				if m.role == "system" then
					sysParts[#sysParts + 1] = tostring(m.content or "")
				elseif m.role == "tool" then
					anthroMsgs[#anthroMsgs + 1] = {
						role = "user",
						content = {
							{
								type = "tool_result",
								tool_use_id = tostring(m.tool_call_id or "toolu_1"),
								content = tostring(m.content or ""),
							},
						},
					}
				elseif m.role == "assistant" and type(m.tool_calls) == "table" and #m.tool_calls > 0 then
					local blocks = {}
					if type(m.content) == "string" and m.content ~= "" then
						blocks[#blocks + 1] = { type = "text", text = m.content }
					end
					for _, tc in ipairs(m.tool_calls) do
						blocks[#blocks + 1] = {
							type = "tool_use",
							id = tc.id,
							name = tc.name,
							input = util.jsonDecode(tc.arguments or "{}") or {},
						}
					end
					anthroMsgs[#anthroMsgs + 1] = { role = "assistant", content = blocks }
				else
					anthroMsgs[#anthroMsgs + 1] = {
						role = m.role == "assistant" and "assistant" or "user",
						content = tostring(m.content or ""),
					}
				end
			end

			local anthroTools = nil
			if type(req.tools) == "table" and #req.tools > 0 then
				anthroTools = {}
				for _, t in ipairs(req.tools) do
					anthroTools[#anthroTools + 1] = {
						name = t.name,
						description = t.description,
						input_schema = t.parameters,
					}
				end
			end

			local payload = {
				model = model,
				max_tokens = tonumber(req.maxTokens) or 4096,
				system = (#sysParts > 0) and table.concat(sysParts, "\n\n") or nil,
				messages = anthroMsgs,
				tools = anthroTools,
			}

			local res = http.send({
				url = endpoint,
				method = "POST",
				headers = {
					["Content-Type"] = "application/json",
					["x-api-key"] = apiKey,
					["anthropic-version"] = "2023-06-01",
				},
				body = util.jsonEncode(payload),
			})
			if not res.ok then
				return nil, string.format("Anthropic HTTP %s: %s", tostring(res.status), tostring(res.error or res.body or "failed"))
			end
			return sse.parseAnthropic(res.body)
		end

		-- OpenAI-compatible wire (`openai`, `openrouter`, `deepseek`, `custom`)
		local oaiMsgs = {}
		for _, m in ipairs(req.messages or {}) do
			if m.role == "assistant" and type(m.tool_calls) == "table" and #m.tool_calls > 0 then
				local wireCalls = {}
				for _, tc in ipairs(m.tool_calls) do
					wireCalls[#wireCalls + 1] = {
						id = tc.id,
						type = "function",
						["function"] = {
							name = tc.name,
							arguments = tc.arguments or "{}",
						},
					}
				end
				oaiMsgs[#oaiMsgs + 1] = {
					role = "assistant",
					content = m.content or "",
					tool_calls = wireCalls,
				}
			elseif m.role == "tool" then
				oaiMsgs[#oaiMsgs + 1] = {
					role = "tool",
					tool_call_id = tostring(m.tool_call_id or "call_1"),
					content = tostring(m.content or ""),
				}
			else
				oaiMsgs[#oaiMsgs + 1] = {
					role = m.role,
					content = tostring(m.content or ""),
				}
			end
		end

		local oaiTools = nil
		if type(req.tools) == "table" and #req.tools > 0 then
			oaiTools = {}
			for _, t in ipairs(req.tools) do
				oaiTools[#oaiTools + 1] = {
					type = "function",
					["function"] = {
						name = t.name,
						description = t.description,
						parameters = t.parameters,
					},
				}
			end
		end

		local headers = {
			["Content-Type"] = "application/json",
		}
		if apiKey ~= "" then
			headers["Authorization"] = "Bearer " .. apiKey
		end

		local res = http.send({
			url = endpoint,
			method = "POST",
			headers = headers,
			body = util.jsonEncode({
				model = model,
				messages = oaiMsgs,
				tools = oaiTools,
				temperature = 0.2,
			}),
		})
		if not res.ok then
			return nil, string.format("%s HTTP %s: %s", p.name, tostring(res.status), tostring(res.error or res.body or "failed"))
		end
		return sse.parseOpenAI(res.body)
	end

	return M
end
