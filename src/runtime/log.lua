-- Ring-buffer structured logger feeding VS-RBLX's Output and HTTP/Git panels.
return function(env)
	local clock = env.require("runtime/clock")
	local signal = env.require("runtime/signal")

	local LIMIT = 400
	local entries = {}
	local M = {
		mirror = false,
		added = signal.new("log.added"),
		cleared = signal.new("log.cleared"),
	}

	local function push(level, channel, message)
		local item = {
			time = clock.timestamp(),
			ms = clock.ms(),
			level = level,
			channel = tostring(channel or "app"),
			message = tostring(message or ""),
		}
		entries[#entries + 1] = item
		if #entries > LIMIT then
			table.remove(entries, 1)
		end
		if M.mirror then
			if level == "error" or level == "warn" then
				warn(string.format("[VS-RBLX/%s] %s", item.channel, item.message))
			else
				print(string.format("[VS-RBLX/%s] %s", item.channel, item.message))
			end
		end
		M.added:fire(item)
		return item
	end

	function M.info(channel, message) return push("info", channel, message) end
	function M.warn(channel, message) return push("warn", channel, message) end
	function M.error(channel, message) return push("error", channel, message) end
	function M.output(channel, message) return push("output", channel, message) end

	function M.list(channelFilter)
		if not channelFilter or channelFilter == "all" then
			local out = {}
			for i = 1, #entries do out[i] = entries[i] end
			return out
		end
		local out = {}
		for i = 1, #entries do
			if entries[i].channel == channelFilter then
				out[#out + 1] = entries[i]
			end
		end
		return out
	end

	function M.clear()
		for i = #entries, 1, -1 do entries[i] = nil end
		M.cleared:fire()
	end

	return M
end
