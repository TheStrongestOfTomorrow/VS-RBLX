-- Left 48px VS Code Activity Bar with active left indicator bar and SCM change count badge.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local icons = env.require("ui/icons")
	local config = env.require("runtime/config")
	local gitState = env.require("runtime/git_state")
	local commands = env.require("runtime/command_catalog")

	local M = {}

	local ITEMS = {
		{ id = "explorer", icon = "explorer", title = "Explorer" },
		{ id = "search", icon = "search", title = "Search" },
		{ id = "scm", icon = "scm", title = "Source Control (GitHub)" },
		{ id = "debug", icon = "debug", title = "Run and Debug" },
		{ id = "extensions", icon = "extensions", title = "Extensions & Languages" },
	}

	function M.new(parent, onSelectViewlet)
		local w = theme.sizes.activityBar
		local root = P.frame(parent, {
			name = "ActivityBar",
			size = UDim2.new(0, w, 1, 0),
			bg = theme.color.activityBar,
			zIndex = 25,
		})
		local rightRule = P.frame(root, {
			size = UDim2.new(0, 1, 1, 0),
			pos = UDim2.new(1, -1, 0, 0),
			bg = theme.color.border,
			zIndex = 26,
		})

		local topGroup = P.frame(root, {
			name = "TopIcons",
			size = UDim2.new(1, 0, 0, #ITEMS * 48),
			zIndex = 26,
		})
		P.list(topGroup, Enum.FillDirection.Vertical, 0)

		local entries = {}
		local scmBadge, scmBadgeLbl

		for idx, spec in ipairs(ITEMS) do
			local btn = P.button(topGroup, {
				name = "Activity_" .. spec.id,
				size = UDim2.fromOffset(w, 48),
				hoverBg = theme.color.hover,
				text = "",
				order = idx,
				zIndex = 27,
				onClick = function()
					if onSelectViewlet then onSelectViewlet(spec.id) end
				end,
			})
			local bar = P.frame(btn, {
				name = "ActiveBar",
				size = UDim2.new(0, 2, 0, 32),
				pos = UDim2.fromOffset(0, 8),
				bg = theme.color.activityIndicator,
				visible = false,
				zIndex = 29,
			})
			local icHolder = P.frame(btn, {
				size = UDim2.fromOffset(22, 22),
				pos = UDim2.fromOffset(13, 13),
				zIndex = 28,
			})
			entries[spec.id] = { btn = btn, bar = bar, icHolder = icHolder, iconName = spec.icon }

			if spec.id == "scm" then
				scmBadge = P.frame(btn, {
					name = "ScmBadge",
					size = UDim2.fromOffset(16, 16),
					pos = UDim2.fromOffset(26, 26),
					bg = theme.color.accent,
					radius = 8,
					visible = false,
					zIndex = 30,
				})
				scmBadgeLbl = P.label(scmBadge, {
					size = UDim2.fromScale(1, 1),
					text = "0",
					bold = true,
					textSize = 10,
					color = Color3.fromRGB(255, 255, 255),
					alignX = Enum.TextXAlignment.Center,
					zIndex = 31,
				})
			end
		end

		local bottomGroup = P.frame(root, {
			name = "BottomIcons",
			size = UDim2.new(1, 0, 0, 96),
			pos = UDim2.new(0, 0, 1, -96),
			zIndex = 26,
		})
		P.list(bottomGroup, Enum.FillDirection.Vertical, 0)

		local accountBtn = P.button(bottomGroup, {
			name = "Activity_account",
			size = UDim2.fromOffset(w, 48),
			hoverBg = theme.color.hover,
			text = "",
			order = 1,
			zIndex = 27,
			onClick = function() commands.run("github.auth") end,
		})
		local accIcon = icons.codicon(accountBtn, "account", 20, theme.color.activityIcon, 28)
		accIcon.Position = UDim2.fromOffset(14, 14)

		local settingsBtn = P.button(bottomGroup, {
			name = "Activity_settings",
			size = UDim2.fromOffset(w, 48),
			hoverBg = theme.color.hover,
			text = "",
			order = 2,
			zIndex = 27,
			onClick = function()
				if onSelectViewlet then onSelectViewlet("settings") end
			end,
		})
		local gearIcon = icons.codicon(settingsBtn, "settings", 20, theme.color.activityIcon, 28)
		gearIcon.Position = UDim2.fromOffset(14, 14)

		local function redrawIcons()
			local current = config.get("workbench.activeViewlet", "explorer")
			local sidebarShown = config.get("workbench.sideBarVisible", true)
			for id, e in pairs(entries) do
				local isActive = sidebarShown and (current == id)
				e.bar.Visible = isActive
				e.bar.BackgroundColor3 = theme.color.activityIndicator
				e.icHolder:ClearAllChildren()
				icons.codicon(
					e.icHolder,
					e.iconName,
					22,
					isActive and theme.color.activityIconActive or theme.color.activityIcon,
					28
				)
			end
		end

		local function refreshScmCount()
			local st = gitState.status()
			if st.total > 0 then
				scmBadge.Visible = true
				scmBadge.BackgroundColor3 = theme.color.accent
				scmBadgeLbl.Text = st.total > 99 and "99+" or tostring(st.total)
			else
				scmBadge.Visible = false
			end
		end

		config.changed:connect(function(key)
			if key == "*" or key == "workbench.activeViewlet" or key == "workbench.sideBarVisible" then
				redrawIcons()
			end
		end)
		gitState.changed:connect(refreshScmCount)
		theme.changed:connect(function()
			root.BackgroundColor3 = theme.color.activityBar
			rightRule.BackgroundColor3 = theme.color.border
			redrawIcons()
			refreshScmCount()
		end)

		redrawIcons()
		refreshScmCount()
		return {
			root = root,
			refresh = redrawIcons,
			refreshScm = refreshScmCount,
		}
	end

	return M
end
