-- VS Code Settings Sidebar Viewlet (`Ctrl+,`) backed by `runtime/settings_catalog` & `config`.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local config = env.require("runtime/config")
	local catalog = env.require("runtime/settings_catalog")

	local M = {}

	function M.new(parent)
		local root = P.frame(parent, {
			name = "SettingsViewlet",
			size = UDim2.fromScale(1, 1),
			visible = false,
			zIndex = 21,
		})
		P.pad(root, 6, 10, 6, 10)

		P.label(root, {
			size = UDim2.new(1, 0, 0, 22),
			text = "SETTINGS",
			bold = true,
			textSize = 11,
			color = theme.color.muted,
			zIndex = 22,
		})

		local _, filterBox = P.input(root, {
			name = "SettingsFilterInput",
			size = UDim2.new(1, 0, 0, 26),
			pos = UDim2.fromOffset(0, 26),
			placeholder = "Search settings...",
			zIndex = 22,
		})

		local scroll = P.scroll(root, {
			name = "SettingsScroll",
			size = UDim2.new(1, 0, 1, -60),
			pos = UDim2.fromOffset(0, 58),
			zIndex = 22,
		})
		P.list(scroll, Enum.FillDirection.Vertical, 6)

		local function rebuild()
			scroll:ClearAllChildren()
			P.list(scroll, Enum.FillDirection.Vertical, 6)
			local list = catalog.search(filterBox.Text)
			for idx, item in ipairs(list) do
				local card = P.frame(scroll, {
					size = UDim2.new(1, 0, 0, 58),
					bg = theme.color.inputBg,
					radius = 4,
					order = idx,
					zIndex = 23,
				})
				P.pad(card, 6, 8, 6, 8)
				P.label(card, {
					size = UDim2.new(1, -90, 0, 18),
					bold = true,
					textSize = 12,
					color = theme.color.tabActiveText,
					text = item.title or item.key,
					truncate = true,
					zIndex = 24,
				})
				P.label(card, {
					size = UDim2.new(1, -90, 0, 24),
					pos = UDim2.fromOffset(0, 20),
					textSize = 10,
					color = theme.color.muted,
					text = item.description or "",
					wrap = true,
					zIndex = 24,
				})

				local curVal = config.get(item.key)
				if item.kind == "boolean" then
					P.button(card, {
						size = UDim2.fromOffset(72, 24),
						pos = UDim2.new(1, -72, 0, 10),
						bg = curVal and theme.color.accent or theme.color.sideBar,
						color = Color3.fromRGB(255, 255, 255),
						bold = true,
						text = curVal and "ON" or "OFF",
						textSize = 11,
						radius = 4,
						zIndex = 24,
						onClick = function()
							config.set(item.key, not curVal)
						end,
					})
				elseif item.kind == "number" then
					P.button(card, {
						size = UDim2.fromOffset(24, 24),
						pos = UDim2.new(1, -76, 0, 10),
						bg = theme.color.sideBar,
						text = "−",
						radius = 3,
						zIndex = 24,
						onClick = function()
							local nextN = math.max(item.min or 1, (tonumber(curVal) or 14) - (item.step or 1))
							config.set(item.key, nextN)
						end,
					})
					P.label(card, {
						size = UDim2.fromOffset(26, 24),
						pos = UDim2.new(1, -50, 0, 10),
						mono = true,
						textSize = 11,
						alignX = Enum.TextXAlignment.Center,
						text = tostring(curVal),
						zIndex = 24,
					})
					P.button(card, {
						size = UDim2.fromOffset(24, 24),
						pos = UDim2.new(1, -24, 0, 10),
						bg = theme.color.sideBar,
						text = "+",
						radius = 3,
						zIndex = 24,
						onClick = function()
							local nextN = math.min(item.max or 99, (tonumber(curVal) or 14) + (item.step or 1))
							config.set(item.key, nextN)
						end,
					})
				elseif item.kind == "select" and item.options then
					P.button(card, {
						size = UDim2.fromOffset(82, 24),
						pos = UDim2.new(1, -82, 0, 10),
						bg = theme.color.sideBar,
						textSize = 10,
						text = tostring(curVal),
						radius = 4,
						zIndex = 24,
						onClick = function()
							local curIdx = 1
							for oi, opt in ipairs(item.options) do
								if opt.value == curVal then curIdx = oi; break end
							end
							local nextOpt = item.options[(curIdx % #item.options) + 1]
							config.set(item.key, nextOpt.value)
						end,
					})
				end
			end
		end

		filterBox:GetPropertyChangedSignal("Text"):Connect(rebuild)
		config.changed:connect(rebuild)
		theme.changed:connect(rebuild)

		rebuild()
		return { root = root, refresh = rebuild }
	end

	return M
end
