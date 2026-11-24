-- Startup stage tracker for VS-RBLX boot splash.
return function(env)
	local clock = env.require("runtime/clock")
	local signal = env.require("runtime/signal")

	local M = {
		stage = "init",
		detail = "Starting VS-RBLX...",
		startedAt = clock.ms(),
		changed = signal.new("boot.changed"),
	}

	function M.update(stage, detail)
		M.stage = tostring(stage or M.stage)
		M.detail = tostring(detail or M.detail)
		M.changed:fire(M.stage, M.detail)
	end

	return M
end
