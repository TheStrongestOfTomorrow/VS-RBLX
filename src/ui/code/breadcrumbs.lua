-- VS Code Path & Symbol Breadcrumbs bar above the editor viewport.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local overlay = env.require("ui/overlay")
	local util = env.require("runtime/util")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")
	local codeFolding = env.require("runtime/code_folding")

	local M = {}

	function M.new(parent, paneName)
		local pane = paneName or "primary"
		local h = theme.sizes.breadcrumbs

		local bar = P.frame(parent, {
			name = "Breadcrumbs_" .. pane,
			size = UDim2.new(1, 0, 0, h),
			pos = UDim2.fromOffset(0, theme.sizes.tabBar),
			bg = theme.color.breadcrumbBg,
			zIndex = 19,
		})
		local rule = P.frame(bar, {
			size = UDim2.new(1, 0, 0, 1),
			pos = UDim2.new(0, 0, 1, -1),
			bg = theme.color.border,
			zIndex = 20,
		})

		local pathBtn = P.button(bar, {
			name = "BreadcrumbTrail",
			size = UDim2.new(1, -16, 1, 0),
			pos = UDim2.fromOffset(8, 0),
			alignX = Enum.TextXAlignment.Left,
			text = "",
			textSize = 11,
			color = theme.color.muted,
			zIndex = 20,
		})

		local function refresh()
			local doc = codeStore.active(pane)
			if not doc then
				pathBtn.Text = workspaceFs.activeName .. "  ›  (no file open)"
				return
			end
			local segments = { workspaceFs.activeName }
			for _, seg in ipairs(util.split(doc.path ~= "" and doc.path or doc.title, "/")) do
				if seg ~= "" then segments[#segments + 1] = seg end
			end
			local syms = codeFolding.symbols(doc.content, doc.langId)
			local curLine = doc.view.line or 1
			local currentSym = nil
			for _, sym in ipairs(syms) do
				if sym.line <= curLine then currentSym = sym end
			end
			if currentSym then
				segments[#segments + 1] = "ƒ " .. currentSym.name
			end
			pathBtn.Text = table.concat(segments, "  ›  ")
		end

		pathBtn.Activated:Connect(function()
			local doc = codeStore.active(pane)
			if not doc then return end
			local syms = codeFolding.symbols(doc.content, doc.langId)
			if #syms == 0 then return end
			local menu = {}
			for _, s in ipairs(syms) do
				local targetLn = s.line
				menu[#menu + 1] = {
					label = string.format("%s (%s)", s.name, s.kind),
					shortcut = "Ln " .. tostring(s.line),
					onClick = function() codeStore.jumpToLine(doc.id, targetLn, 1) end,
				}
			end
			local p = pathBtn.AbsolutePosition
			overlay.dropdown(p.X + 80, p.Y + h, menu, 240)
		end)

		codeStore.changed:connect(refresh)
		codeStore.cursorChanged:connect(refresh)
		workspaceFs.changed:connect(refresh)
		theme.changed:connect(function()
			bar.BackgroundColor3 = theme.color.breadcrumbBg
			rule.BackgroundColor3 = theme.color.border
			pathBtn.TextColor3 = theme.color.muted
		end)

		refresh()
		return {
			root = bar,
			refresh = refresh,
		}
	end

	return M
end
