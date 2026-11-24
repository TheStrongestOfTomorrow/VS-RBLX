-- Scoped host context validation for embedded VS-RBLX instances.
return function(_env)
	local M = {}

	function M.normalise(hostContext)
		local ctx = type(hostContext) == "table" and hostContext or {}
		return {
			ui = ctx.ui ~= false,
			workspace = type(ctx.workspace) == "string" and ctx.workspace or nil,
			repo = type(ctx.repo) == "string" and ctx.repo or nil,
			theme = type(ctx.theme) == "string" and ctx.theme or nil,
			initialFiles = type(ctx.files) == "table" and ctx.files or nil,
		}
	end

	return M
end
