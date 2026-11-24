-- Sandboxed Luau execution engine via executor `loadstring`, with captured
-- `print`/`warn` streams, runtime error tracebacks, and task cancellation.
return function(env)
	local caps = env.require("runtime/caps")
	local clock = env.require("runtime/clock")
	local log = env.require("runtime/log")
	local signal = env.require("runtime/signal")

	local M = {
		running = {},
		changed = signal.new("runner.changed"),
	}
	local nextRunId = 0

	local function stringifyArgs(...)
		local out = {}
		for i = 1, select("#", ...) do
			out[i] = tostring(select(i, ...))
		end
		return table.concat(out, "    ")
	end

	function M.execute(source, label)
		if not caps.fn.loadstring then
			local msg = "Host does not expose `loadstring` for dynamic Luau execution."
			log.error("runner", msg)
			return false, msg
		end

		local chunkName = tostring(label or "script.luau")
		local fn, compileErr = caps.fn.loadstring(tostring(source or ""), chunkName)
		if not fn then
			local errMsg = "Syntax error in " .. chunkName .. ": " .. tostring(compileErr)
			log.error("runner", errMsg)
			return false, errMsg
		end

		nextRunId = nextRunId + 1
		local runId = nextRunId
		local startedMs = clock.ms()
		local linesOut = {}

		if type(setfenv) == "function" then
			local baseEnv = caps.fn.getgenv and caps.fn.getgenv() or _G
			local proxy = setmetatable({
				print = function(...)
					local line = stringifyArgs(...)
					linesOut[#linesOut + 1] = line
					log.output("runner", line)
				end,
				warn = function(...)
					local line = "[warn] " .. stringifyArgs(...)
					linesOut[#linesOut + 1] = line
					log.warn("runner", line)
				end,
			}, {
				__index = baseEnv,
				__newindex = baseEnv,
			})
			pcall(setfenv, fn, proxy)
		end

		local record = {
			id = runId,
			label = chunkName,
			startedMs = startedMs,
			thread = nil,
			active = true,
		}
		M.running[runId] = record
		M.changed:fire()
		log.info("runner", string.format("Running %s (task #%d)...", chunkName, runId))

		local execOk, execResult = false, nil
		record.thread = task.spawn(function()
			local ok, res = pcall(fn)
			execOk, execResult = ok, res
			record.active = false
			M.running[runId] = nil
			local elapsed = clock.ms() - startedMs
			if ok then
				if res ~= nil then
					linesOut[#linesOut + 1] = "=> " .. tostring(res)
					log.output("runner", "=> " .. tostring(res))
				end
				log.info("runner", string.format("Finished %s in %d ms.", chunkName, elapsed))
			else
				log.error("runner", string.format("Runtime error in %s (%d ms): %s", chunkName, elapsed, tostring(res)))
			end
			M.changed:fire()
		end)

		return execOk, execResult, linesOut
	end

	function M.stopAll()
		local stopped = 0
		for id, rec in pairs(M.running) do
			if rec.thread then
				pcall(task.cancel, rec.thread)
			end
			rec.active = false
			M.running[id] = nil
			stopped = stopped + 1
		end
		if stopped > 0 then
			log.warn("runner", string.format("Stopped %d running script task(s).", stopped))
			M.changed:fire()
		end
		return stopped
	end

	function M.activeCount()
		local n = 0
		for _ in pairs(M.running) do n = n + 1 end
		return n
	end

	function M.evalExpression(expr)
		if not caps.fn.loadstring then
			return false, "loadstring unavailable"
		end
		local fn, err = caps.fn.loadstring("return " .. tostring(expr or ""), "watch")
		if not fn then
			fn, err = caps.fn.loadstring(tostring(expr or ""), "watch")
		end
		if not fn then return false, tostring(err) end
		if type(setfenv) == "function" then
			local baseEnv = caps.fn.getgenv and caps.fn.getgenv() or _G
			pcall(setfenv, fn, baseEnv)
		end
		local ok, val = pcall(fn)
		return ok, val
	end

	return M
end
