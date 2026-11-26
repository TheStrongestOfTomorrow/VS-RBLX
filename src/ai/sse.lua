-- Buffered Server-Sent Events (SSE) & JSON Replay Parser (`src/ai/sse.lua`).
-- Roblox executor HTTP (`request`) returns the complete response body once finished.
-- When an OpenAI-compatible or Anthropic endpoint responds with `text/event-stream`
-- (`data: {...}\n\n`), this parser replays every delta chunk to reconstruct full text,
-- reasoning traces, tool calls, and token usage cleanly.
return function(env)
	local util = env.require("runtime/util")

	local M = {}

	-- Parse OpenAI Chat Completions response (either standard JSON or `data:` SSE stream)
	function M.parseOpenAI(rawBody)
		rawBody = tostring(rawBody or "")
		local trimmed = util.trim(rawBody)
		if trimmed == "" then
			return nil, "Empty provider response body"
		end

		-- Plain JSON response (`stream = false` or buffered gateway JSON)
		if trimmed:sub(1, 1) == "{" then
			local obj = util.jsonDecode(trimmed)
			if type(obj) ~= "table" then
				return nil, "Invalid JSON from OpenAI-compatible provider"
			end
			if type(obj.error) == "table" and obj.error.message then
				return nil, tostring(obj.error.message)
			end
			local choice = type(obj.choices) == "table" and obj.choices[1] or nil
			local msg = choice and choice.message or {}
			local toolCalls = {}
			if type(msg.tool_calls) == "table" then
				for _, tc in ipairs(msg.tool_calls) do
					local fn = tc["function"] or {}
					toolCalls[#toolCalls + 1] = {
						id = tostring(tc.id or ("call_" .. tostring(#toolCalls + 1))),
						name = tostring(fn.name or ""),
						arguments = tostring(fn.arguments or "{}"),
					}
				end
			end
			local usage = type(obj.usage) == "table" and obj.usage or {}
			return {
				content = tostring(msg.content or ""),
				reasoning = tostring(msg.reasoning_content or msg.reasoning or ""),
				toolCalls = toolCalls,
				usage = {
					promptTokens = tonumber(usage.prompt_tokens) or 0,
					completionTokens = tonumber(usage.completion_tokens) or 0,
				},
			}
		end

		-- Buffered SSE (`data: {...}`) replay
		local contentParts = {}
		local reasonParts = {}
		local toolMap = {}
		local toolOrder = {}
		local promptTok = 0
		local compTok = 0

		for line in (rawBody .. "\n"):gmatch("([^\r\n]*)\r?\n") do
			local payload = line:match("^data:%s*(.+)$")
			if payload and payload ~= "[DONE]" then
				local chunk = util.jsonDecode(payload)
				if type(chunk) == "table" then
					if type(chunk.error) == "table" and chunk.error.message then
						return nil, tostring(chunk.error.message)
					end
					if type(chunk.usage) == "table" then
						promptTok = tonumber(chunk.usage.prompt_tokens) or promptTok
						compTok = tonumber(chunk.usage.completion_tokens) or compTok
					end
					local choice = type(chunk.choices) == "table" and chunk.choices[1] or nil
					local delta = choice and (choice.delta or choice.message) or nil
					if type(delta) == "table" then
						if type(delta.content) == "string" and delta.content ~= "" then
							contentParts[#contentParts + 1] = delta.content
						end
						local rc = delta.reasoning_content or delta.reasoning
						if type(rc) == "string" and rc ~= "" then
							reasonParts[#reasonParts + 1] = rc
						end
						if type(delta.tool_calls) == "table" then
							for _, tc in ipairs(delta.tool_calls) do
								local idx = tonumber(tc.index) or 0
								local slot = toolMap[idx]
								if not slot then
									slot = { id = "", name = "", args = {} }
									toolMap[idx] = slot
									toolOrder[#toolOrder + 1] = idx
								end
								if type(tc.id) == "string" and tc.id ~= "" then
									slot.id = tc.id
								end
								local fn = tc["function"]
								if type(fn) == "table" then
									if type(fn.name) == "string" and fn.name ~= "" then
										slot.name = slot.name .. fn.name
									end
									if type(fn.arguments) == "string" and fn.arguments ~= "" then
										slot.args[#slot.args + 1] = fn.arguments
									end
								end
							end
						end
					end
				end
			end
		end

		table.sort(toolOrder)
		local toolCalls = {}
		for i, idx in ipairs(toolOrder) do
			local slot = toolMap[idx]
			if slot and slot.name ~= "" then
				toolCalls[#toolCalls + 1] = {
					id = slot.id ~= "" and slot.id or ("call_" .. tostring(i)),
					name = slot.name,
					arguments = table.concat(slot.args),
				}
			end
		end

		return {
			content = table.concat(contentParts),
			reasoning = table.concat(reasonParts),
			toolCalls = toolCalls,
			usage = {
				promptTokens = promptTok,
				completionTokens = compTok,
			},
		}
	end

	-- Parse Anthropic `/v1/messages` response (JSON or SSE)
	function M.parseAnthropic(rawBody)
		rawBody = tostring(rawBody or "")
		local trimmed = util.trim(rawBody)
		if trimmed == "" then
			return nil, "Empty Anthropic response body"
		end

		if trimmed:sub(1, 1) == "{" then
			local obj = util.jsonDecode(trimmed)
			if type(obj) ~= "table" then
				return nil, "Invalid Anthropic JSON response"
			end
			if type(obj.error) == "table" and obj.error.message then
				return nil, tostring(obj.error.message)
			end
			local textParts = {}
			local reasonParts = {}
			local toolCalls = {}
			if type(obj.content) == "table" then
				for _, block in ipairs(obj.content) do
					if block.type == "text" and type(block.text) == "string" then
						textParts[#textParts + 1] = block.text
					elseif block.type == "thinking" and type(block.thinking) == "string" then
						reasonParts[#reasonParts + 1] = block.thinking
					elseif block.type == "tool_use" then
						toolCalls[#toolCalls + 1] = {
							id = tostring(block.id or ("toolu_" .. tostring(#toolCalls + 1))),
							name = tostring(block.name or ""),
							arguments = util.jsonEncode(block.input or {}) or "{}",
						}
					end
				end
			end
			local u = type(obj.usage) == "table" and obj.usage or {}
			return {
				content = table.concat(textParts, "\n"),
				reasoning = table.concat(reasonParts, "\n"),
				toolCalls = toolCalls,
				usage = {
					promptTokens = tonumber(u.input_tokens) or 0,
					completionTokens = tonumber(u.output_tokens) or 0,
				},
			}
		end

		-- Buffered Anthropic SSE (`event: content_block_delta` / `data: {...}`)
		local textParts = {}
		local reasonParts = {}
		local blocks = {}
		local blockOrder = {}
		local inTok, outTok = 0, 0

		for line in (rawBody .. "\n"):gmatch("([^\r\n]*)\r?\n") do
			local payload = line:match("^data:%s*(.+)$")
			if payload then
				local ev = util.jsonDecode(payload)
				if type(ev) == "table" then
					if ev.type == "error" and type(ev.error) == "table" then
						return nil, tostring(ev.error.message or "Anthropic SSE error")
					elseif ev.type == "message_start" and type(ev.message) == "table" and type(ev.message.usage) == "table" then
						inTok = tonumber(ev.message.usage.input_tokens) or inTok
					elseif ev.type == "message_delta" and type(ev.usage) == "table" then
						outTok = tonumber(ev.usage.output_tokens) or outTok
					elseif ev.type == "content_block_start" and type(ev.content_block) == "table" then
						local idx = tonumber(ev.index) or 0
						local cb = ev.content_block
						blocks[idx] = {
							kind = tostring(cb.type or ""),
							id = tostring(cb.id or ""),
							name = tostring(cb.name or ""),
							jsonParts = {},
						}
						blockOrder[#blockOrder + 1] = idx
					elseif ev.type == "content_block_delta" and type(ev.delta) == "table" then
						local idx = tonumber(ev.index) or 0
						local d = ev.delta
						if d.type == "text_delta" and type(d.text) == "string" then
							textParts[#textParts + 1] = d.text
						elseif d.type == "thinking_delta" and type(d.thinking) == "string" then
							reasonParts[#reasonParts + 1] = d.thinking
						elseif d.type == "input_json_delta" and blocks[idx] and type(d.partial_json) == "string" then
							local jp = blocks[idx].jsonParts
							jp[#jp + 1] = d.partial_json
						end
					end
				end
			end
		end

		table.sort(blockOrder)
		local toolCalls = {}
		for _, idx in ipairs(blockOrder) do
			local b = blocks[idx]
			if b and b.kind == "tool_use" and b.name ~= "" then
				toolCalls[#toolCalls + 1] = {
					id = b.id ~= "" and b.id or ("toolu_" .. tostring(#toolCalls + 1)),
					name = b.name,
					arguments = (#b.jsonParts > 0) and table.concat(b.jsonParts) or "{}",
				}
			end
		end

		return {
			content = table.concat(textParts),
			reasoning = table.concat(reasonParts),
			toolCalls = toolCalls,
			usage = { promptTokens = inTok, completionTokens = outTok },
		}
	end

	return M
end
