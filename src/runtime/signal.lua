-- Lightweight synchronous pub/sub signal used across runtime and UI modules.
return function(_env)
	local M = {}

	function M.new(name)
		local listeners = {}
		local nextId = 0
		local sig = { name = name or "signal" }

		function sig:connect(fn)
			if type(fn) ~= "function" then return function() end end
			nextId = nextId + 1
			local id = nextId
			listeners[#listeners + 1] = { id = id, fn = fn, active = true }
			return function()
				for i = #listeners, 1, -1 do
					if listeners[i].id == id then
						listeners[i].active = false
						table.remove(listeners, i)
						break
					end
				end
			end
		end

		function sig:once(fn)
			local off
			off = sig:connect(function(...)
				if off then off(); off = nil end
				fn(...)
			end)
			return off
		end

		function sig:fire(...)
			local snapshot = {}
			for i = 1, #listeners do snapshot[i] = listeners[i] end
			for i = 1, #snapshot do
				local entry = snapshot[i]
				if entry.active then
					pcall(entry.fn, ...)
				end
			end
		end

		function sig:clear()
			for i = #listeners, 1, -1 do
				listeners[i].active = false
				listeners[i] = nil
			end
		end

		return sig
	end

	return M
end
