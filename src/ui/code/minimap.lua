-- VS Code Right-Side Code Minimap with miniature colorized bars and clickable viewport slider.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local util = env.require("runtime/util")

	local M = {}

	function M.new(parent, onJumpRatio)
		local width = 72
		local root = P.frame(parent, {
			name = "Minimap",
			size = UDim2.new(0, width, 1, 0),
			pos = UDim2.new(1, -width, 0, 0),
			bg = theme.color.editor,
			clip = true,
			active = true,
			zIndex = 16,
		})
		local leftRule = P.frame(root, {
			size = UDim2.new(0, 1, 1, 0),
			bg = theme.color.border,
			transparency = 0.5,
			zIndex = 17,
		})

		local canvas = P.frame(root, {
			name = "MiniLines",
			size = UDim2.new(1, -8, 1, -8),
			pos = UDim2.fromOffset(5, 4),
			zIndex = 17,
		})

		local slider = P.frame(root, {
			name = "ViewportSlider",
			size = UDim2.new(1, 0, 0, 44),
			pos = UDim2.fromOffset(0, 0),
			bg = theme.color.selection,
			transparency = 0.65,
			zIndex = 18,
		})

		local bars = {}
		local MAX_BARS = 85

		local function ensureBar(i)
			if not bars[i] then
				bars[i] = P.frame(canvas, {
					size = UDim2.fromOffset(20, 2),
					pos = UDim2.fromOffset(0, (i - 1) * 3),
					bg = theme.color.muted,
					transparency = 0.35,
					zIndex = 17,
				})
			end
			return bars[i]
		end

		local function updateSource(lexScan)
			if not lexScan or not lexScan.lines then return end
			local total = #lexScan.lines
			local step = math.max(1, math.ceil(total / MAX_BARS))
			local idx = 0
			for lineNo = 1, total, step do
				idx = idx + 1
				if idx > MAX_BARS then break end
				local line = lexScan.lines[lineNo] or ""
				local bar = ensureBar(idx)
				local trimmed = util.trim(line)
				if trimmed == "" then
					bar.Visible = false
				else
					bar.Visible = true
					local indent = #(line:match("^(%s*)") or "")
					local w = util.clamp(math.floor(#trimmed * 0.75), 4, width - 14)
					bar.Position = UDim2.fromOffset(util.clamp(indent * 2, 0, 24), (idx - 1) * 3)
					bar.Size = UDim2.fromOffset(w, 2)
					local spans = lexScan.spans[lineNo]
					local firstKind = spans and spans[1] and spans[1].kind or "text"
					local colHex = theme.syntax[firstKind]
					bar.BackgroundColor3 = colHex and Color3.fromHex(colHex) or theme.color.muted
				end
			end
			for k = idx + 1, #bars do
				bars[k].Visible = false
			end
		end

		local function updateViewport(scrollY, viewHeight, contentHeight)
			local h = math.max(1, root.AbsoluteSize.Y)
			local totalH = math.max(contentHeight, viewHeight, 1)
			local fracH = util.clamp(viewHeight / totalH, 0.08, 1)
			local fracY = util.clamp(scrollY / math.max(1, totalH - viewHeight), 0, 1)
			local sliderH = math.floor(h * fracH)
			local sliderY = math.floor((h - sliderH) * fracY)
			slider.Size = UDim2.new(1, 0, 0, sliderH)
			slider.Position = UDim2.fromOffset(0, sliderY)
		end

		root.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				local relY = input.Position.Y - root.AbsolutePosition.Y
				local ratio = util.clamp(relY / math.max(1, root.AbsoluteSize.Y), 0, 1)
				if onJumpRatio then onJumpRatio(ratio) end
			end
		end)

		theme.changed:connect(function()
			root.BackgroundColor3 = theme.color.editor
			leftRule.BackgroundColor3 = theme.color.border
			slider.BackgroundColor3 = theme.color.selection
		end)

		return {
			root = root,
			width = width,
			updateSource = updateSource,
			updateViewport = updateViewport,
		}
	end

	return M
end
