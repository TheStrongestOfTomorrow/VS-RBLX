-- VS Code Run & Debug Sidebar Viewlet (`Ctrl+Shift+D`) with Luau execution & Watch expressions.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local overlay = env.require("ui/overlay")
	local runner = env.require("runtime/runner")
	local execution = env.require("tools/execution")

	local M = {}

	function M.new(parent)
		local root = P.frame(parent, {
			name = "DebugViewlet",
			size = UDim2.fromScale(1, 1),
			visible = false,
			zIndex = 21,
		})
		P.pad(root, 6, 10, 6, 10)

		P.label(root, {
			size = UDim2.new(1, 0, 0, 22),
			text = "RUN AND DEBUG",
			bold = true,
			textSize = 11,
			color = theme.color.muted,
			zIndex = 22,
		})

		local btnRow = P.frame(root, {
			size = UDim2.new(1, 0, 0, 30),
			pos = UDim2.fromOffset(0, 26),
			zIndex = 22,
		})
		P.button(btnRow, {
			name = "RunActiveScriptBtn",
			size = UDim2.new(0.68, -3, 1, 0),
			bg = theme.color.good,
			color = Color3.fromRGB(18, 22, 18),
			bold = true,
			text = "▶ Run Active Script (F5)",
			textSize = 12,
			radius = 4,
			zIndex = 23,
			onClick = function()
				local ok, err = execution.runActive()
				if ok then
					overlay.toast("Executed active Luau script", "good", 2)
				else
					overlay.toast("Run error: " .. tostring(err), "bad", 4)
				end
			end,
		})
		P.button(btnRow, {
			name = "StopTasksBtn",
			size = UDim2.new(0.32, -3, 1, 0),
			pos = UDim2.new(0.68, 6, 0, 0),
			bg = theme.color.bad,
			color = Color3.fromRGB(255, 255, 255),
			bold = true,
			text = "■ Stop",
			textSize = 12,
			radius = 4,
			zIndex = 23,
			onClick = function()
				local n = execution.stop()
				overlay.toast(string.format("Stopped %d task(s)", n), "warn", 2)
			end,
		})

		-- Watch expressions
		P.label(root, {
			size = UDim2.new(1, 0, 0, 20),
			pos = UDim2.fromOffset(0, 64),
			bold = true,
			textSize = 11,
			color = theme.color.sideBarText,
			text = "▾ WATCH EXPRESSIONS",
			zIndex = 22,
		})

		local _, watchBox = P.input(root, {
			name = "WatchExprInput",
			size = UDim2.new(1, -48, 0, 26),
			pos = UDim2.fromOffset(0, 86),
			mono = true,
			placeholder = "e.g. workspace.Name or 2 ^ 10",
			zIndex = 22,
		})
		local addWatchBtn = P.button(root, {
			size = UDim2.fromOffset(42, 26),
			pos = UDim2.new(1, -42, 0, 86),
			bg = theme.color.accent,
			color = Color3.fromRGB(255, 255, 255),
			text = "Add",
			textSize = 11,
			radius = 4,
			zIndex = 22,
		})

		local watches = { "game and game.PlaceId or 0", "workspace and #workspace:GetChildren() or 0" }
		local watchScroll = P.scroll(root, {
			name = "WatchScroll",
			size = UDim2.new(1, 0, 1, -120),
			pos = UDim2.fromOffset(0, 120),
			zIndex = 22,
		})
		P.list(watchScroll, Enum.FillDirection.Vertical, 3)

		local function refreshWatches()
			watchScroll:ClearAllChildren()
			P.list(watchScroll, Enum.FillDirection.Vertical, 3)
			for idx, expr in ipairs(watches) do
				local ok, val = runner.evalExpression(expr)
				local row = P.frame(watchScroll, {
					size = UDim2.new(1, 0, 0, 36),
					bg = theme.color.inputBg,
					radius = 4,
					order = idx,
					zIndex = 23,
				})
				P.label(row, {
					size = UDim2.new(1, -28, 0, 18),
					pos = UDim2.fromOffset(6, 2),
					mono = true,
					textSize = 11,
					color = theme.color.accent,
					text = expr,
					truncate = true,
					zIndex = 24,
				})
				P.label(row, {
					size = UDim2.new(1, -12, 0, 16),
					pos = UDim2.fromOffset(6, 18),
					mono = true,
					textSize = 11,
					color = ok and theme.color.good or theme.color.bad,
					text = "=> " .. tostring(val),
					truncate = true,
					zIndex = 24,
				})
				P.button(row, {
					size = UDim2.fromOffset(20, 18),
					pos = UDim2.new(1, -22, 0, 2),
					text = "✕",
					textSize = 10,
					zIndex = 24,
					onClick = function()
						table.remove(watches, idx)
						refreshWatches()
					end,
				})
			end
		end

		addWatchBtn.Activated:Connect(function()
			if watchBox.Text ~= "" then
				watches[#watches + 1] = watchBox.Text
				watchBox.Text = ""
				refreshWatches()
			end
		end)
		runner.changed:connect(refreshWatches)

		refreshWatches()
		return { root = root, refresh = refreshWatches }
	end

	return M
end
