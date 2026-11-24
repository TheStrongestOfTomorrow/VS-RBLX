-- Executor HTTP transport layer (`request` / `http_request` / `syn.request` /
-- `http.request` / `fluxus.request` / `game:HttpGet` / `HttpService:RequestAsync`).
return function(env)
	local caps = env.require("runtime/caps")
	local util = env.require("runtime/util")
	local clock = env.require("runtime/clock")
	local headersUtil = env.require("net/headers")
	local log = env.require("runtime/log")
	local signal = env.require("runtime/signal")

	local HISTORY_MAX = 100
	local M = {
		history = {},
		changed = signal.new("http.changed"),
	}

	local function record(entry)
		M.history[#M.history + 1] = entry
		if #M.history > HISTORY_MAX then
			table.remove(M.history, 1)
		end
		M.changed:fire(entry)
	end

	function M.send(spec)
		local url = tostring(spec.url or spec.Url or "")
		local method = tostring(spec.method or spec.Method or "GET"):upper()
		local reqHeaders = spec.headers or spec.Headers or {}
		local body = spec.body or spec.Body
		if type(body) == "table" then
			body = util.jsonEncode(body)
		end

		local startMs = clock.ms()
		local response = nil
		local transportUsed = caps.http

		if caps.fn.request then
			local ok, raw = pcall(caps.fn.request, {
				Url = url,
				Method = method,
				Headers = reqHeaders,
				Body = body,
			})
			if ok and type(raw) == "table" then
				local code = tonumber(raw.StatusCode or raw.Status) or 0
				response = {
					ok = code >= 200 and code < 300,
					status = code,
					body = tostring(raw.Body or ""),
					headers = raw.Headers or {},
				}
			else
				response = { ok = false, status = 0, body = "", error = tostring(raw or "request failed") }
			end
		elseif method == "GET" and caps.fn.httpGet then
			transportUsed = "game:HttpGet"
			local ok, rawBody = pcall(caps.fn.httpGet, url)
			if ok and type(rawBody) == "string" then
				response = { ok = true, status = 200, body = rawBody, headers = {} }
			else
				response = { ok = false, status = 0, body = "", error = tostring(rawBody or "HttpGet failed") }
			end
		elseif env.hs and type(env.hs.RequestAsync) == "function" then
			transportUsed = "HttpService"
			local cleanHeaders = {}
			for k, v in pairs(reqHeaders) do
				local lk = k:lower()
				if lk ~= "user-agent" and lk ~= "host" and lk ~= "content-length" then
					cleanHeaders[k] = v
				end
			end
			local ok, raw = pcall(function()
				return env.hs:RequestAsync({
					Url = url,
					Method = method,
					Headers = cleanHeaders,
					Body = body,
				})
			end)
			if ok and type(raw) == "table" then
				local code = tonumber(raw.StatusCode) or 0
				response = {
					ok = code >= 200 and code < 300,
					status = code,
					body = tostring(raw.Body or ""),
					headers = raw.Headers or {},
				}
			else
				response = { ok = false, status = 0, body = "", error = tostring(raw or "RequestAsync failed") }
			end
		else
			response = {
				ok = false,
				status = 0,
				body = "",
				error = "No executor HTTP function (`request`, `http_request`, or `HttpService`) available.",
			}
		end

		local durationMs = clock.ms() - startMs
		if response.body ~= "" and spec.json ~= false then
			local decoded = util.jsonDecode(response.body)
			if decoded ~= nil then
				response.json = decoded
			end
		end

		record({
			time = clock.timestamp(),
			method = method,
			url = url,
			status = response.status,
			ok = response.ok,
			ms = durationMs,
			bytes = #response.body,
			transport = transportUsed,
			headers = headersUtil.redact(reqHeaders),
			error = response.error,
		})

		if not response.ok and not spec.quiet then
			log.warn("http", string.format("%s %s -> %d (%s)", method, url, response.status, response.error or "HTTP error"))
		end

		return response
	end

	function M.get(url, headers, opts)
		opts = opts or {}
		opts.url = url
		opts.method = "GET"
		opts.headers = headers
		return M.send(opts)
	end

	function M.clearHistory()
		for i = #M.history, 1, -1 do M.history[i] = nil end
		M.changed:fire(nil)
	end

	return M
end
