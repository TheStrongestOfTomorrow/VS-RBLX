-- Interactive VS Code HSV Color Picker Widget (`src/ui/code/color_picker.lua`).
-- Opens from inline editor color swatches (`#hex`, `Color3.fromRGB`, `Color3.new`, `rgb()`)
-- and rewrites the color literal in-place while preserving the original syntax format.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local util = env.require("runtime/util")
	local dispose = env.require("runtime/dispose")
	local colorUtils = env.require("runtime/color_utils")

	local PRESET_SWATCHES = {
		{ 0, 122, 204 },   -- VS Code Blue
		{ 78, 201, 176 },  -- Teal
		{ 115, 201, 145 }, -- Mint Green
		{ 255, 204, 0 },   -- Gold
		{ 241, 76, 76 },   -- Coral Red
		{ 197, 134, 192 }, -- Orchid
		{ 86, 156, 214 },  -- Sky Blue
		{ 255, 255, 255 }, -- White
		{ 30, 30, 30 },    -- Charcoal
	}

	local function hsvColor3(h, s, v)
		local r, g, b = colorUtils.hsvToRgb(h, s, v)
		return Color3.fromRGB(r, g, b)
	end

	local M = {}

	function M.new(parentSurface)
		local curH, curS, curV = 0.58, 0.85, 0.90
		local curR, curG, curB = 34, 150, 230
		local activeSpec = nil
		local activeDragMode = nil

		local card = P.frame(parentSurface, {
			name = "InlineColorPicker",
			size = UDim2.fromOffset(244, 212),
			pos = UDim2.fromOffset(80, 36),
			bg = theme.color.sideBar,
			radius = 6,
			border = theme.color.accent,
			visible = false,
			active = true,
			zIndex = 52,
		})
		P.pad(card, 8, 10, 8, 10)

		-- Header row: live color preview box + formatted literal preview + Close `✕`
		local previewChip = P.frame(card, {
			name = "PickerPreviewSwatch",
			size = UDim2.fromOffset(22, 22),
			bg = Color3.fromRGB(curR, curG, curB),
			radius = 4,
			border = theme.color.border,
			zIndex = 53,
		})
		local titleLbl = P.label(card, {
			name = "PickerTitleLabel",
			size = UDim2.new(1, -56, 0, 22),
			pos = UDim2.fromOffset(28, 0),
			mono = true,
			bold = true,
			textSize = 11,
			color = theme.color.tabActiveText,
			text = "#2296e6",
			truncate = true,
			zIndex = 53,
		})
		P.button(card, {
			name = "ClosePickerBtn",
			size = UDim2.fromOffset(22, 22),
			pos = UDim2.new(1, -22, 0, 0),
			text = "✕",
			textSize = 11,
			color = theme.color.muted,
			radius = 3,
			zIndex = 54,
			onClick = function()
				card.Visible = false
				activeSpec = nil
			end,
		})

		-- Saturation / Value 2D Canvas (left) + Hue Vertical Strip (right)
		local svBox = P.frame(card, {
			name = "SVCanvas",
			size = UDim2.fromOffset(186, 94),
			pos = UDim2.fromOffset(0, 28),
			bg = hsvColor3(curH, 1, 1),
			radius = 4,
			border = theme.color.border,
			clip = true,
			active = true,
			zIndex = 53,
		})
		-- White horizontal gradient simulation + dark vertical overlay simulation
		local satOverlay = P.frame(svBox, {
			size = UDim2.fromScale(1, 1),
			bg = Color3.fromRGB(255, 255, 255),
			transparency = 0.55,
			zIndex = 54,
		})
		local valOverlay = P.frame(svBox, {
			size = UDim2.fromScale(1, 1),
			bg = Color3.fromRGB(0, 0, 0),
			transparency = 0.65,
			zIndex = 55,
		})
		local svKnob = P.frame(svBox, {
			name = "SVKnob",
			size = UDim2.fromOffset(10, 10),
			anchor = Vector2.new(0.5, 0.5),
			bg = Color3.fromRGB(255, 255, 255),
			radius = 5,
			border = Color3.fromRGB(0, 0, 0),
			zIndex = 57,
		})

		local hueBar = P.frame(card, {
			name = "HueBar",
			size = UDim2.fromOffset(24, 94),
			pos = UDim2.fromOffset(196, 28),
			bg = theme.color.inputBg,
			radius = 4,
			border = theme.color.border,
			clip = true,
			active = true,
			zIndex = 53,
		})
		-- 6-band crisp HSV rainbow slices
		for seg = 0, 5 do
			P.frame(hueBar, {
				size = UDim2.new(1, 0, 1 / 6, 1),
				pos = UDim2.new(0, 0, seg / 6, 0),
				bg = hsvColor3(seg / 6, 1, 1),
				zIndex = 54,
			})
		end
		local hueKnob = P.frame(hueBar, {
			name = "HueKnob",
			size = UDim2.new(1, 0, 0, 4),
			bg = Color3.fromRGB(255, 255, 255),
			border = Color3.fromRGB(0, 0, 0),
			zIndex = 56,
		})

		-- Quick palette preset row
		local presetRow = P.frame(card, {
			name = "PresetSwatches",
			size = UDim2.new(1, 0, 0, 18),
			pos = UDim2.fromOffset(0, 128),
			zIndex = 53,
		})
		P.list(presetRow, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

		-- Hex input + Apply button row
		local hexWrap, hexInput = P.input(card, {
			name = "PickerHexInput",
			size = UDim2.fromOffset(124, 24),
			pos = UDim2.fromOffset(0, 152),
			mono = true,
			placeholder = "#ff5577",
			zIndex = 54,
		})
		hexWrap.Active = true

		local applyBtn = P.button(card, {
			name = "ApplyColorBtn",
			size = UDim2.fromOffset(92, 24),
			pos = UDim2.new(1, -92, 0, 152),
			bg = theme.color.accent,
			hoverBg = theme.color.accentHover,
			color = Color3.fromRGB(255, 255, 255),
			bold = true,
			text = "Apply Color",
			textSize = 11,
			radius = 4,
			zIndex = 54,
		})

		local rgbInfoLbl = P.label(card, {
			size = UDim2.new(1, 0, 0, 16),
			pos = UDim2.fromOffset(0, 180),
			mono = true,
			textSize = 10,
			color = theme.color.muted,
			text = "RGB(34, 150, 230)",
			zIndex = 53,
		})

		local syncingHex = false

		local function refreshControls()
			curR, curG, curB = colorUtils.hsvToRgb(curH, curS, curV)
			local c3 = Color3.fromRGB(curR, curG, curB)
			previewChip.BackgroundColor3 = c3
			svBox.BackgroundColor3 = hsvColor3(curH, 1, 1)
			satOverlay.BackgroundTransparency = curS * 0.85 + 0.15
			valOverlay.BackgroundTransparency = curV * 0.85 + 0.15
			svKnob.Position = UDim2.new(curS, 0, 1 - curV, 0)
			hueKnob.Position = UDim2.new(0, 0, curH, -2)

			local hexStr = colorUtils.rgbToHex(curR, curG, curB)
			local formatted = activeSpec
				and colorUtils.formatColor(curR, curG, curB, activeSpec.format, activeSpec.alphaTail)
				or hexStr
			titleLbl.Text = formatted
			rgbInfoLbl.Text = string.format("RGB(%d, %d, %d)  •  HSV(%d°, %d%%, %d%%)",
				curR, curG, curB,
				math.floor(curH * 360 + 0.5),
				math.floor(curS * 100 + 0.5),
				math.floor(curV * 100 + 0.5)
			)
			if not syncingHex then
				syncingHex = true
				hexInput.Text = hexStr
				syncingHex = false
			end
		end

		local function commitColor()
			local spec = activeSpec
			if not spec or not spec.onApply then return end
			local replacement = colorUtils.formatColor(curR, curG, curB, spec.format, spec.alphaTail)
			local prevLast = spec.last
			spec.last = spec.first + #replacement - 1
			spec.onApply(replacement, curR, curG, curB, prevLast)
		end

		for idx, rgb in ipairs(PRESET_SWATCHES) do
			P.button(presetRow, {
				name = "PresetColor_" .. tostring(idx),
				size = UDim2.fromOffset(20, 16),
				bg = Color3.fromRGB(rgb[1], rgb[2], rgb[3]),
				hoverBg = Color3.fromRGB(rgb[1], rgb[2], rgb[3]),
				text = "",
				radius = 3,
				border = theme.color.border,
				order = idx,
				zIndex = 54,
				onClick = function()
					curH, curS, curV = colorUtils.rgbToHsv(rgb[1], rgb[2], rgb[3])
					refreshControls()
					commitColor()
				end,
			})
		end

		hexInput.FocusLost:Connect(function(enterPressed)
			if syncingHex then return end
			local r, g, b = colorUtils.hexToRgb(hexInput.Text)
			if r then
				curH, curS, curV = colorUtils.rgbToHsv(r, g, b)
				refreshControls()
				if enterPressed then commitColor() end
			end
		end)

		applyBtn.Activated:Connect(function()
			commitColor()
			card.Visible = false
			activeSpec = nil
		end)

		local function updateFromPointer(pos)
			if activeDragMode == "sv" then
				local relX = util.clamp((pos.X - svBox.AbsolutePosition.X) / math.max(1, svBox.AbsoluteSize.X), 0, 1)
				local relY = util.clamp((pos.Y - svBox.AbsolutePosition.Y) / math.max(1, svBox.AbsoluteSize.Y), 0, 1)
				curS = relX
				curV = 1 - relY
				refreshControls()
			elseif activeDragMode == "hue" then
				local relY = util.clamp((pos.Y - hueBar.AbsolutePosition.Y) / math.max(1, hueBar.AbsoluteSize.Y), 0, 0.999)
				curH = relY
				refreshControls()
			end
		end

		svBox.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				activeDragMode = "sv"
				updateFromPointer(input.Position)
			end
		end)
		hueBar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				activeDragMode = "hue"
				updateFromPointer(input.Position)
			end
		end)

		if env.uis then
			dispose.connection(env.uis.InputChanged:Connect(function(input)
				if not activeDragMode then return end
				if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
					updateFromPointer(input.Position)
				end
			end))
			dispose.connection(env.uis.InputEnded:Connect(function(input)
				if not activeDragMode then return end
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					activeDragMode = nil
					commitColor()
				end
			end))
		end

		theme.changed:connect(function()
			card.BackgroundColor3 = theme.color.sideBar
			titleLbl.TextColor3 = theme.color.tabActiveText
			rgbInfoLbl.TextColor3 = theme.color.muted
		end)

		return {
			root = card,
			open = function(spec, xPx, yPx)
				activeSpec = spec
				curH, curS, curV = colorUtils.rgbToHsv(spec.r or 0, spec.g or 122, spec.b or 204)
				refreshControls()
				local maxX = math.max(12, parentSurface.AbsoluteSize.X - 256)
				local maxY = math.max(12, parentSurface.AbsoluteSize.Y - 220)
				card.Position = UDim2.fromOffset(util.clamp(xPx or 64, 12, maxX), util.clamp(yPx or 32, 12, maxY))
				card.Visible = true
			end,
			setRgb = function(r, g, b)
				curH, curS, curV = colorUtils.rgbToHsv(r, g, b)
				refreshControls()
				commitColor()
			end,
			close = function()
				card.Visible = false
				activeSpec = nil
			end,
		}
	end

	return M
end
