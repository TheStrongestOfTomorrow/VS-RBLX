-- System clipboard bridge (`setclipboard`/`toclipboard`) + Persistent 15-Slot Clipboard Ring History.
return function(env)
	local caps = env.require("runtime/caps")
	local fsx = env.require("runtime/fsx")
	local util = env.require("runtime/util")
	local clock = env.require("runtime/clock")
	local signal = env.require("runtime/signal")

	local MAX_SLOTS = 15
	local HISTORY_PATH = "clipboard_history.json"

	local M = {
		buffer = "",
		history = {},
		maxSlots = MAX_SLOTS,
		changed = signal.new("clipboard.changed"),
	}

	local loadedOnce = false

	local function makePreview(txt)
		local single = util.trim(tostring(txt or ""):gsub("%s+", " "))
		if #single > 58 then
			return single:sub(1, 55) .. "..."
		end
		return single
	end

	local saveDebounced = clock.debounce(0.4, function()
		local body = util.jsonEncode(M.history)
		if body then
			fsx.write(HISTORY_PATH, body)
		end
	end)

	function M.load()
		if loadedOnce then return M.history end
		loadedOnce = true
		local raw = fsx.read(HISTORY_PATH)
		if type(raw) == "string" and raw ~= "" then
			local decoded = util.jsonDecode(raw)
			if type(decoded) == "table" then
				M.history = {}
				for i = 1, math.min(#decoded, MAX_SLOTS) do
					local entry = decoded[i]
					if type(entry) == "table" and type(entry.text) == "string" and entry.text ~= "" then
						M.history[#M.history + 1] = {
							text = entry.text,
							preview = entry.preview or makePreview(entry.text),
							chars = #entry.text,
							time = entry.time or clock.timestamp(),
						}
					end
				end
				if M.history[1] then
					M.buffer = M.history[1].text
				end
			end
		end
		return M.history
	end

	function M.push(text)
		M.load()
		local value = tostring(text or "")
		if value == "" then return false end
		M.buffer = value

		for i = #M.history, 1, -1 do
			if M.history[i].text == value then
				table.remove(M.history, i)
			end
		end

		local _, nlCount = value:gsub("\n", "")
		table.insert(M.history, 1, {
			text = value,
			preview = makePreview(value),
			chars = #value,
			lines = nlCount + 1,
			time = clock.timestamp(),
		})

		while #M.history > MAX_SLOTS do
			table.remove(M.history)
		end

		saveDebounced.call()
		M.changed:fire(M.history)
		return true
	end

	function M.set(text)
		local value = tostring(text or "")
		M.push(value)
		if caps.fn.clipboard then
			local ok = pcall(caps.fn.clipboard, value)
			return ok, ok and "system" or "internal"
		end
		return true, "internal"
	end

	M.copy = M.set

	function M.get(slotIndex)
		M.load()
		if slotIndex then
			local item = M.history[tonumber(slotIndex) or 1]
			return item and item.text or ""
		end
		return M.buffer
	end

	function M.list()
		M.load()
		return M.history
	end

	function M.clear()
		M.history = {}
		M.buffer = ""
		fsx.write(HISTORY_PATH, "[]")
		M.changed:fire(M.history)
	end

	return M
end
