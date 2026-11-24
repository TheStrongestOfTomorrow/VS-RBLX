-- Clock, debounce and throttle utilities built on Roblox's task library.
return function(_env)
	local unpackValues = table.unpack or unpack
	local M = {}

	function M.now()
		if type(DateTime) == "table" and type(DateTime.now) == "function" then
			local ok, dt = pcall(DateTime.now)
			if ok and dt and dt.UnixTimestampMillis then
				return dt.UnixTimestampMillis / 1000
			end
		end
		if type(tick) == "function" then return tick() end
		return os.clock()
	end

	function M.ms()
		return math.floor(M.now() * 1000)
	end

	function M.timestamp()
		if type(DateTime) == "table" and type(DateTime.now) == "function" then
			local ok, dt = pcall(function()
				return DateTime.fromUnixTimestamp(DateTime.now().UnixTimestamp):FormatLocalTime("HH:mm:ss", "en-us")
			end)
			if ok and type(dt) == "string" then return dt end
		end
		local secs = math.floor(M.now()) % 86400
		local h = math.floor(secs / 3600)
		local m = math.floor((secs % 3600) / 60)
		local s = secs % 60
		return string.format("%02d:%02d:%02d", h, m, s)
	end

	function M.debounce(seconds, fn)
		local pendingThread = nil
		local latestArgs = nil
		local cancelled = false
		local handle = {}

		local function flush()
			pendingThread = nil
			if cancelled or not latestArgs then return end
			local args = latestArgs
			latestArgs = nil
			fn(unpackValues(args, 1, args.n))
		end

		function handle.call(...)
			cancelled = false
			latestArgs = { n = select("#", ...), ... }
			if pendingThread then
				pcall(task.cancel, pendingThread)
				pendingThread = nil
			end
			pendingThread = task.delay(seconds or 0.2, flush)
		end

		function handle.flush()
			if pendingThread then
				pcall(task.cancel, pendingThread)
				pendingThread = nil
			end
			flush()
		end

		function handle.cancel()
			cancelled = true
			latestArgs = nil
			if pendingThread then
				pcall(task.cancel, pendingThread)
				pendingThread = nil
			end
		end

		return setmetatable(handle, {
			__call = function(_, ...)
				handle.call(...)
			end,
		})
	end

	return M
end
