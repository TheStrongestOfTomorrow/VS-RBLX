-- Clean Roblox UI constructor primitives for VS-RBLX panels, buttons, inputs, and scrollbars.
return function(env)
	local theme = env.require("ui/theme")
	local P = {}

	function P.corner(inst, radius)
		local c = Instance.new("UICorner", inst)
		c.CornerRadius = UDim.new(0, radius or 4)
		return c
	end

	function P.stroke(inst, color, thickness)
		local s = Instance.new("UIStroke", inst)
		s.Color = color or theme.color.border
		s.Thickness = thickness or 1
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		return s
	end

	function P.pad(inst, top, right, bottom, left)
		local p = Instance.new("UIPadding", inst)
		p.PaddingTop = UDim.new(0, top or 0)
		p.PaddingRight = UDim.new(0, right or top or 0)
		p.PaddingBottom = UDim.new(0, bottom or top or 0)
		p.PaddingLeft = UDim.new(0, left or right or top or 0)
		return p
	end

	function P.list(inst, dir, gap, hAlign, vAlign)
		local l = Instance.new("UIListLayout", inst)
		l.FillDirection = dir or Enum.FillDirection.Vertical
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.Padding = UDim.new(0, gap or 0)
		if hAlign then l.HorizontalAlignment = hAlign end
		if vAlign then l.VerticalAlignment = vAlign end
		return l
	end

	function P.frame(parent, props)
		props = props or {}
		local f = Instance.new("Frame", parent)
		f.Name = props.name or "Frame"
		f.BorderSizePixel = 0
		f.Size = props.size or UDim2.fromScale(1, 1)
		f.Position = props.pos or UDim2.fromOffset(0, 0)
		if props.anchor then f.AnchorPoint = props.anchor end
		if props.bg then
			f.BackgroundColor3 = props.bg
			f.BackgroundTransparency = props.transparency or 0
		else
			f.BackgroundTransparency = 1
		end
		if props.clip then f.ClipsDescendants = true end
		if props.zIndex then f.ZIndex = props.zIndex end
		if props.order then f.LayoutOrder = props.order end
		if props.visible ~= nil then f.Visible = props.visible end
		if props.active ~= nil then f.Active = props.active end
		if props.radius then P.corner(f, props.radius) end
		if props.border then P.stroke(f, props.border, props.borderWidth) end
		return f
	end

	function P.label(parent, props)
		props = props or {}
		local lbl = Instance.new("TextLabel", parent)
		lbl.Name = props.name or "Label"
		lbl.BorderSizePixel = 0
		lbl.BackgroundTransparency = props.bg and (props.transparency or 0) or 1
		if props.bg then lbl.BackgroundColor3 = props.bg end
		lbl.Size = props.size or UDim2.new(1, 0, 0, 20)
		lbl.Position = props.pos or UDim2.fromOffset(0, 0)
		lbl.Font = props.mono and theme.font.mono or (props.bold and theme.font.uiBold or theme.font.ui)
		lbl.TextSize = props.textSize or theme.sizes.uiFont
		lbl.TextColor3 = props.color or theme.color.sideBarText
		lbl.Text = tostring(props.text or "")
		lbl.RichText = props.rich == true
		lbl.TextWrapped = props.wrap == true
		lbl.TextTruncate = props.truncate and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None
		lbl.TextXAlignment = props.alignX or Enum.TextXAlignment.Left
		lbl.TextYAlignment = props.alignY or Enum.TextYAlignment.Center
		if props.zIndex then lbl.ZIndex = props.zIndex end
		if props.order then lbl.LayoutOrder = props.order end
		if props.visible ~= nil then lbl.Visible = props.visible end
		return lbl
	end

	function P.button(parent, props)
		props = props or {}
		local btn = Instance.new("TextButton", parent)
		btn.Name = props.name or "Button"
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = false
		local baseBg = props.bg
		local hoverBg = props.hoverBg or theme.color.hover
		btn.BackgroundColor3 = baseBg or hoverBg
		btn.BackgroundTransparency = baseBg and (props.transparency or 0) or 1
		btn.Size = props.size or UDim2.fromOffset(80, 26)
		btn.Position = props.pos or UDim2.fromOffset(0, 0)
		btn.Font = props.mono and theme.font.mono or (props.bold and theme.font.uiMedium or theme.font.ui)
		btn.TextSize = props.textSize or theme.sizes.uiFont
		btn.TextColor3 = props.color or theme.color.sideBarText
		btn.Text = tostring(props.text or "")
		btn.TextXAlignment = props.alignX or Enum.TextXAlignment.Center
		if props.zIndex then btn.ZIndex = props.zIndex end
		if props.order then btn.LayoutOrder = props.order end
		if props.visible ~= nil then btn.Visible = props.visible end
		if props.radius then P.corner(btn, props.radius) end
		if props.border then P.stroke(btn, props.border, 1) end

		btn.MouseEnter:Connect(function()
			if props.activeState and props.activeState() then return end
			btn.BackgroundColor3 = hoverBg
			btn.BackgroundTransparency = 0
		end)
		btn.MouseLeave:Connect(function()
			if props.activeState and props.activeState() then return end
			if baseBg then
				btn.BackgroundColor3 = baseBg
				btn.BackgroundTransparency = props.transparency or 0
			else
				btn.BackgroundTransparency = 1
			end
		end)
		if props.onClick then
			btn.Activated:Connect(props.onClick)
		end
		return btn
	end

	function P.input(parent, props)
		props = props or {}
		local wrap = P.frame(parent, {
			name = props.name or "InputWrap",
			size = props.size or UDim2.new(1, 0, 0, 26),
			pos = props.pos,
			bg = props.bg or theme.color.inputBg,
			radius = 3,
			order = props.order,
			zIndex = props.zIndex,
		})
		local borderStroke = P.stroke(wrap, theme.color.inputBorder, 1)
		P.pad(wrap, 0, 6, 0, 6)

		local box = Instance.new("TextBox", wrap)
		box.Name = "Field"
		box.BorderSizePixel = 0
		box.BackgroundTransparency = 1
		box.Size = UDim2.fromScale(1, 1)
		box.ClearTextOnFocus = false
		box.MultiLine = props.multiLine == true
		box.Font = props.mono and theme.font.mono or theme.font.ui
		box.TextSize = props.textSize or theme.sizes.uiFont
		box.TextColor3 = theme.color.editorText
		box.PlaceholderText = props.placeholder or ""
		box.PlaceholderColor3 = theme.color.muted
		box.Text = props.value or ""
		box.TextXAlignment = Enum.TextXAlignment.Left
		box.TextYAlignment = props.multiLine and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
		if props.zIndex then box.ZIndex = props.zIndex + 1 end

		box.Focused:Connect(function()
			borderStroke.Color = theme.color.inputFocus
		end)
		box.FocusLost:Connect(function(enterPressed)
			borderStroke.Color = theme.color.inputBorder
			if props.onSubmit and enterPressed then
				props.onSubmit(box.Text)
			end
			if props.onFocusLost then
				props.onFocusLost(box.Text, enterPressed)
			end
		end)
		if props.onChange then
			box:GetPropertyChangedSignal("Text"):Connect(function()
				props.onChange(box.Text)
			end)
		end
		return wrap, box
	end

	function P.scroll(parent, props)
		props = props or {}
		local sf = Instance.new("ScrollingFrame", parent)
		sf.Name = props.name or "Scroll"
		sf.BorderSizePixel = 0
		sf.Size = props.size or UDim2.fromScale(1, 1)
		sf.Position = props.pos or UDim2.fromOffset(0, 0)
		sf.BackgroundTransparency = props.bg and 0 or 1
		if props.bg then sf.BackgroundColor3 = props.bg end
		sf.ScrollBarThickness = props.barThickness or 6
		sf.ScrollBarImageColor3 = theme.color.muted
		sf.CanvasSize = props.canvasSize or UDim2.fromOffset(0, 0)
		sf.AutomaticCanvasSize = props.autoCanvas or Enum.AutomaticSize.Y
		sf.ScrollingDirection = props.direction or Enum.ScrollingDirection.Y
		if props.zIndex then sf.ZIndex = props.zIndex end
		if props.order then sf.LayoutOrder = props.order end
		return sf
	end

	return P
end
