-- VS Code popups, dropdown menus, input prompts, modals, and bottom-right toast notifications.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")

	local M = {
		layer = nil,
		toastStack = nil,
		activeMenu = nil,
		activeModal = nil,
	}

	function M.mount(parentScreen)
		if M.layer then
			pcall(function() M.layer:Destroy() end)
		end
		M.layer = P.frame(parentScreen, {
			name = "OverlayLayer",
			size = UDim2.fromScale(1, 1),
			zIndex = 200,
		})
		M.toastStack = P.frame(M.layer, {
			name = "ToastStack",
			size = UDim2.fromOffset(320, 260),
			pos = UDim2.new(1, -332, 1, -296),
			zIndex = 260,
		})
		P.list(M.toastStack, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom)
	end

	function M.closeMenu()
		if M.activeMenu then
			pcall(function() M.activeMenu:Destroy() end)
			M.activeMenu = nil
		end
	end

	function M.closeModal()
		if M.activeModal then
			pcall(function() M.activeModal:Destroy() end)
			M.activeModal = nil
		end
	end

	function M.openModal(name, width, height)
		M.closeModal()
		local parentTarget = M.layer
		local backdrop = P.button(parentTarget, {
			name = "ModalBackdrop_" .. tostring(name or "Dialog"),
			size = UDim2.fromScale(1, 1),
			bg = Color3.fromRGB(0, 0, 0),
			transparency = 0.45,
			text = "",
			zIndex = 230,
			onClick = function() M.closeModal() end,
		})
		local card = P.frame(backdrop, {
			name = tostring(name or "ModalCard"),
			size = UDim2.fromOffset(width or 480, height or 320),
			pos = UDim2.new(0.5, 0, 0.46, 0),
			anchor = Vector2.new(0.5, 0.5),
			bg = theme.color.sideBar,
			radius = 6,
			border = theme.color.border,
			active = true,
			zIndex = 231,
		})
		M.activeModal = backdrop
		return card, backdrop
	end

	function M.dropdown(x, y, items, width)
		M.closeMenu()
		if not M.layer then return end

		local backdrop = P.button(M.layer, {
			name = "MenuBackdrop",
			size = UDim2.fromScale(1, 1),
			text = "",
			zIndex = 210,
			onClick = function() M.closeMenu() end,
		})
		backdrop.BackgroundTransparency = 1

		local menuW = width or 220
		local menuH = 8
		for _, it in ipairs(items) do
			menuH = menuH + (it.separator and 7 or 24)
		end

		local card = P.frame(backdrop, {
			name = "DropdownCard",
			size = UDim2.fromOffset(menuW, menuH),
			pos = UDim2.fromOffset(x, y),
			bg = theme.color.dropdownBg,
			radius = 4,
			border = theme.color.border,
			zIndex = 215,
		})
		P.pad(card, 4, 4, 4, 4)
		P.list(card, Enum.FillDirection.Vertical, 0)

		for idx, item in ipairs(items) do
			if item.separator then
				local sepWrap = P.frame(card, {
					size = UDim2.new(1, 0, 0, 7),
					order = idx,
					zIndex = 216,
				})
				P.frame(sepWrap, {
					size = UDim2.new(1, -8, 0, 1),
					pos = UDim2.fromOffset(4, 3),
					bg = theme.color.border,
					zIndex = 217,
				})
			else
				local row = P.button(card, {
					name = "MenuItem_" .. tostring(idx),
					size = UDim2.new(1, 0, 0, 24),
					hoverBg = theme.color.listActive,
					text = "",
					radius = 3,
					order = idx,
					zIndex = 216,
					onClick = function()
						M.closeMenu()
						if item.onClick then item.onClick() end
					end,
				})
				P.label(row, {
					size = UDim2.new(1, -70, 1, 0),
					pos = UDim2.fromOffset(10, 0),
					text = item.label or "",
					color = theme.color.sideBarText,
					textSize = 12,
					zIndex = 217,
				})
				if item.shortcut and item.shortcut ~= "" then
					P.label(row, {
						size = UDim2.fromOffset(64, 24),
						pos = UDim2.new(1, -70, 0, 0),
						text = item.shortcut,
						color = theme.color.muted,
						textSize = 11,
						alignX = Enum.TextXAlignment.Right,
						zIndex = 217,
					})
				end
			end
		end

		M.activeMenu = backdrop
		return backdrop
	end

	function M.prompt(spec)
		M.closeModal()
		if not M.layer then return end

		local backdrop = P.button(M.layer, {
			name = "ModalBackdrop",
			size = UDim2.fromScale(1, 1),
			bg = Color3.fromRGB(0, 0, 0),
			transparency = 0.45,
			text = "",
			zIndex = 230,
			onClick = function() M.closeModal() end,
		})

		local boxCard = P.frame(backdrop, {
			name = "PromptModal",
			size = UDim2.fromOffset(spec.width or 420, spec.height or 146),
			pos = UDim2.new(0.5, 0, 0.34, 0),
			anchor = Vector2.new(0.5, 0.5),
			bg = theme.color.sideBar,
			radius = 6,
			border = theme.color.border,
			active = true,
			zIndex = 235,
		})
		P.pad(boxCard, 12, 14, 12, 14)

		P.label(boxCard, {
			size = UDim2.new(1, 0, 0, 20),
			text = spec.title or "Input",
			bold = true,
			textSize = 14,
			color = theme.color.tabActiveText,
			zIndex = 236,
		})

		if spec.subtitle then
			P.label(boxCard, {
				size = UDim2.new(1, 0, 0, 18),
				pos = UDim2.fromOffset(0, 22),
				text = spec.subtitle,
				textSize = 12,
				color = theme.color.muted,
				zIndex = 236,
			})
		end

		local inputWrap, field = P.input(boxCard, {
			name = "PromptField",
			size = UDim2.new(1, 0, 0, 28),
			pos = UDim2.fromOffset(0, 48),
			value = spec.default or "",
			placeholder = spec.placeholder or "",
			mono = spec.mono == true,
			zIndex = 236,
			onSubmit = function(val)
				M.closeModal()
				if spec.onConfirm then spec.onConfirm(val) end
			end,
		})
		inputWrap.Active = true

		local actions = P.frame(boxCard, {
			size = UDim2.new(1, 0, 0, 28),
			pos = UDim2.new(0, 0, 1, -28),
			zIndex = 236,
		})
		P.list(actions, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right)

		P.button(actions, {
			name = "CancelBtn",
			size = UDim2.fromOffset(74, 26),
			bg = theme.color.inputBg,
			hoverBg = theme.color.hover,
			text = "Cancel",
			radius = 4,
			order = 1,
			zIndex = 237,
			onClick = function() M.closeModal() end,
		})
		P.button(actions, {
			name = "ConfirmBtn",
			size = UDim2.fromOffset(92, 26),
			bg = theme.color.accent,
			hoverBg = theme.color.accentHover,
			color = Color3.fromRGB(255, 255, 255),
			bold = true,
			text = spec.confirmText or "Confirm",
			radius = 4,
			order = 2,
			zIndex = 237,
			onClick = function()
				local v = field.Text
				M.closeModal()
				if spec.onConfirm then spec.onConfirm(v) end
			end,
		})

		M.activeModal = backdrop
		task.defer(function()
			pcall(function() field:CaptureFocus() end)
		end)
		return backdrop, field
	end

	function M.confirm(spec)
		M.closeModal()
		if not M.layer then return end
		spec = spec or {}

		local backdrop = P.button(M.layer, {
			name = "ConfirmBackdrop",
			size = UDim2.fromScale(1, 1),
			bg = Color3.fromRGB(0, 0, 0),
			transparency = 0.45,
			text = "",
			zIndex = 230,
			onClick = function()
				M.closeModal()
				if spec.onCancel then spec.onCancel() end
			end,
		})

		local card = P.frame(backdrop, {
			name = "ConfirmModal",
			size = UDim2.fromOffset(spec.width or 430, spec.height or 142),
			pos = UDim2.new(0.5, 0, 0.36, 0),
			anchor = Vector2.new(0.5, 0.5),
			bg = theme.color.sideBar,
			radius = 6,
			border = theme.color.border,
			active = true,
			zIndex = 235,
		})
		P.pad(card, 14, 16, 14, 16)

		P.label(card, {
			name = "ConfirmTitle",
			size = UDim2.new(1, 0, 0, 22),
			text = spec.title or "Confirm Action",
			bold = true,
			textSize = 13,
			color = theme.color.tabActiveText,
			truncate = true,
			zIndex = 236,
		})

		P.label(card, {
			name = "ConfirmMessage",
			size = UDim2.new(1, 0, 0, 38),
			pos = UDim2.fromOffset(0, 26),
			text = spec.message or "",
			wrap = true,
			textSize = 12,
			color = theme.color.muted,
			alignY = Enum.TextYAlignment.Top,
			zIndex = 236,
		})

		local actions = P.frame(card, {
			name = "ConfirmActions",
			size = UDim2.new(1, 0, 0, 28),
			pos = UDim2.new(0, 0, 1, -28),
			zIndex = 236,
		})
		P.list(actions, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right)

		P.button(actions, {
			name = "ConfirmCancelBtn",
			size = UDim2.fromOffset(74, 26),
			bg = theme.color.inputBg,
			hoverBg = theme.color.hover,
			text = spec.cancelText or "Cancel",
			radius = 4,
			order = 1,
			zIndex = 237,
			onClick = function()
				M.closeModal()
				if spec.onCancel then spec.onCancel() end
			end,
		})

		if spec.secondaryText then
			P.button(actions, {
				name = "ConfirmSecondaryBtn",
				size = UDim2.fromOffset(92, 26),
				bg = theme.color.inputBg,
				hoverBg = theme.color.bad,
				text = spec.secondaryText,
				radius = 4,
				order = 2,
				zIndex = 237,
				onClick = function()
					M.closeModal()
					if spec.onSecondary then spec.onSecondary() end
				end,
			})
		end

		P.button(actions, {
			name = "ConfirmPrimaryBtn",
			size = UDim2.fromOffset(96, 26),
			bg = theme.color.accent,
			hoverBg = theme.color.accentHover,
			color = Color3.fromRGB(255, 255, 255),
			bold = true,
			text = spec.primaryText or "Save",
			radius = 4,
			order = 3,
			zIndex = 237,
			onClick = function()
				M.closeModal()
				if spec.onPrimary then spec.onPrimary() end
			end,
		})

		M.activeModal = backdrop
		return backdrop, card
	end

	function M.toast(message, kind, durationSec)
		if not M.toastStack then return end
		local stripeColor = theme.color.accent
		if kind == "good" then stripeColor = theme.color.good
		elseif kind == "warn" then stripeColor = theme.color.warn
		elseif kind == "bad" then stripeColor = theme.color.bad end

		local card = P.frame(M.toastStack, {
			name = "Toast",
			size = UDim2.fromOffset(310, 44),
			bg = theme.color.sideBar,
			radius = 4,
			border = theme.color.border,
			zIndex = 262,
		})
		P.frame(card, {
			size = UDim2.new(0, 4, 1, 0),
			bg = stripeColor,
			radius = 2,
			zIndex = 263,
		})
		P.label(card, {
			size = UDim2.new(1, -22, 1, -8),
			pos = UDim2.fromOffset(12, 4),
			text = tostring(message or ""),
			wrap = true,
			textSize = 12,
			color = theme.color.sideBarText,
			zIndex = 263,
		})

		task.delay(durationSec or 3.5, function()
			pcall(function() card:Destroy() end)
		end)
		return card
	end

	return M
end
