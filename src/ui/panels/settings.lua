-- Upgraded Interactive VS Code Settings Sidebar Viewlet (`Ctrl+,`):
-- Category Filter Pills, Dropdown Option Menus, Live Hotkey Capture,
-- `Open settings.json` raw JSON editor sync, and `Reset Defaults`.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local overlay = env.require("ui/overlay")
	local config = env.require("runtime/config")
	local catalog = env.require("runtime/settings_catalog")
	local commands = env.require("runtime/command_catalog")

	local M = {}

	function M.new(parent)
		local activeCategory = "All"

		local root = P.frame(parent, {
			name = "SettingsViewlet",
			size = UDim2.fromScale(1, 1),
			visible = false,
			zIndex = 21,
		})
		P.pad(root, 6, 10, 6, 10)

		local headerRow = P.frame(root, {
			size = UDim2.new(1, 0, 0, 24),
			zIndex = 22,
		})
		P.label(headerRow, {
			size = UDim2.new(1, -138, 1, 0),
			text = "SETTINGS",
			bold = true,
			textSize = 11,
			color = theme.color.muted,
			zIndex = 23,
		})

		P.button(headerRow, {
			name = "OpenSettingsJsonBtn",
			size = UDim2.fromOffset(72, 22),
			pos = UDim2.new(1, -136, 0, 1),
			bg = theme.color.inputBg,
			hoverBg = theme.color.hover,
			text = "{ } JSON",
			mono = true,
			bold = true,
			textSize = 10,
			radius = 4,
			zIndex = 23,
			onClick = function()
				commands.run("preferences.openSettingsJson")
			end,
		})

		P.button(headerRow, {
			name = "ResetSettingsBtn",
			size = UDim2.fromOffset(60, 22),
			pos = UDim2.new(1, -60, 0, 1),
			bg = theme.color.inputBg,
			hoverBg = theme.color.hover,
			text = "↺ Reset",
			textSize = 10,
			color = theme.color.warn,
			radius = 4,
			zIndex = 23,
			onClick = function()
				config.reset()
				overlay.toast("Settings restored to defaults", "info", 2.2)
			end,
		})

		local _, filterBox = P.input(root, {
			name = "SettingsFilterInput",
			size = UDim2.new(1, 0, 0, 26),
			pos = UDim2.fromOffset(0, 28),
			placeholder = "Search settings (theme, font, git, roblox, keymap)...",
			zIndex = 22,
		})

		-- Category filter bar
		local catScroll = P.scroll(root, {
			name = "SettingsCategoryBar",
			size = UDim2.new(1, 0, 0, 24),
			pos = UDim2.fromOffset(0, 58),
			canvasX = true,
			zIndex = 22,
		})
		catScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
		catScroll.CanvasSize = UDim2.fromOffset(0, 0)
		catScroll.ScrollBarThickness = 2
		P.list(catScroll, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

		local scroll = P.scroll(root, {
			name = "SettingsScroll",
			size = UDim2.new(1, 0, 1, -88),
			pos = UDim2.fromOffset(0, 86),
			zIndex = 22,
		})
		P.list(scroll, Enum.FillDirection.Vertical, 6)

		local rebuild

		local function rebuildCategories()
			catScroll:ClearAllChildren()
			P.list(catScroll, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
			for idx, cat in ipairs(catalog.categories()) do
				local isSel = (cat == activeCategory)
				local pill = P.button(catScroll, {
					name = "SettingsCat_" .. cat,
					size = UDim2.fromOffset(#cat * 6 + 16, 20),
					bg = isSel and theme.color.accent or theme.color.inputBg,
					hoverBg = theme.color.hover,
					color = isSel and Color3.fromRGB(255, 255, 255) or theme.color.sideBarText,
					bold = isSel,
					text = cat,
					textSize = 10,
					radius = 10,
					order = idx,
					zIndex = 23,
					activeState = function() return cat == activeCategory end,
					onClick = function()
						activeCategory = cat
						rebuildCategories()
						if rebuild then rebuild() end
					end,
				})
				pill.BackgroundTransparency = 0
			end
		end

		local function optionLabelFor(item, val)
			if item.options then
				for _, opt in ipairs(item.options) do
					if opt.value == val then
						return opt.label or tostring(val)
					end
				end
			end
			return tostring(val)
		end

		rebuild = function()
			scroll:ClearAllChildren()
			P.list(scroll, Enum.FillDirection.Vertical, 6)
			local list = catalog.search(filterBox.Text, activeCategory)
			for idx, item in ipairs(list) do
				local card = P.frame(scroll, {
					size = UDim2.new(1, 0, 0, 62),
					bg = theme.color.inputBg,
					radius = 4,
					order = idx,
					zIndex = 23,
				})
				P.pad(card, 6, 8, 6, 8)
				P.label(card, {
					size = UDim2.new(1, -96, 0, 18),
					bold = true,
					textSize = 12,
					color = theme.color.tabActiveText,
					text = (item.category and (item.category .. ": ") or "") .. (item.title or item.key),
					truncate = true,
					zIndex = 24,
				})
				P.label(card, {
					size = UDim2.new(1, -96, 0, 28),
					pos = UDim2.fromOffset(0, 20),
					textSize = 10,
					color = theme.color.muted,
					text = item.description or "",
					wrap = true,
					zIndex = 24,
				})

				local curVal = config.get(item.key)
				if item.kind == "boolean" then
					local onBtn = P.button(card, {
						name = "Toggle_" .. item.key,
						size = UDim2.fromOffset(74, 24),
						pos = UDim2.new(1, -74, 0, 12),
						bg = curVal and theme.color.accent or theme.color.sideBar,
						color = Color3.fromRGB(255, 255, 255),
						bold = true,
						text = curVal and "✓ ON" or "OFF",
						textSize = 11,
						radius = 4,
						zIndex = 24,
						onClick = function()
							config.set(item.key, not curVal)
						end,
					})
					onBtn.BackgroundTransparency = 0
				elseif item.kind == "number" then
					P.button(card, {
						size = UDim2.fromOffset(24, 24),
						pos = UDim2.new(1, -78, 0, 12),
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
						size = UDim2.fromOffset(28, 24),
						pos = UDim2.new(1, -52, 0, 12),
						mono = true,
						textSize = 11,
						alignX = Enum.TextXAlignment.Center,
						text = tostring(curVal),
						zIndex = 24,
					})
					P.button(card, {
						size = UDim2.fromOffset(24, 24),
						pos = UDim2.new(1, -24, 0, 12),
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
					local ddBtn = P.button(card, {
						name = "Select_" .. item.key,
						size = UDim2.fromOffset(88, 24),
						pos = UDim2.new(1, -88, 0, 12),
						bg = theme.color.sideBar,
						hoverBg = theme.color.hover,
						textSize = 10,
						text = tostring(curVal) .. " ▾",
						radius = 4,
						zIndex = 24,
					})
					ddBtn.BackgroundTransparency = 0
					ddBtn.TextTruncate = Enum.TextTruncate.AtEnd
					ddBtn.Activated:Connect(function()
						local menu = {}
						for _, opt in ipairs(item.options) do
							local optVal = opt.value
							menu[#menu + 1] = {
								label = (optVal == curVal and "✓ " or "   ") .. optionLabelFor(item, optVal),
								onClick = function()
									config.set(item.key, optVal)
								end,
							}
						end
						if item.key == "keybindings.toggleKey" then
							menu[#menu + 1] = { separator = true }
							menu[#menu + 1] = {
								label = "⌨ Capture Any Key...",
								onClick = function()
									commands.run("workbench.changeToggleKey")
								end,
							}
						end
						local p = ddBtn.AbsolutePosition
						overlay.dropdown(math.max(12, p.X - 110), p.Y + 26, menu, 210)
					end)
				end
			end
		end

		filterBox:GetPropertyChangedSignal("Text"):Connect(rebuild)
		config.changed:connect(rebuild)
		theme.changed:connect(function()
			rebuildCategories()
			rebuild()
		end)

		rebuildCategories()
		rebuild()
		return {
			root = root,
			refresh = rebuild,
			setCategory = function(cat)
				activeCategory = cat or "All"
				rebuildCategories()
				rebuild()
			end,
		}
	end

	return M
end
