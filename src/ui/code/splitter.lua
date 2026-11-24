-- Interactive draggable vertical/horizontal splitters between VS Code Sidebar,
-- Editor Groups, and the Bottom Terminal Panel.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local dispose = env.require("runtime/dispose")

	local M = {}

	function M.vertical(parent, zIndex, onDelta)
		local sash = P.frame(parent, {
			name = "VerticalSash",
			size = UDim2.new(0, 4, 1, 0),
			bg = theme.color.accent,
			transparency = 1,
			active = true,
			zIndex = zIndex or 35,
		})
		local dragging = false
		local startX = 0

		sash.MouseEnter:Connect(function() sash.BackgroundTransparency = 0.25 end)
		sash.MouseLeave:Connect(function() if not dragging then sash.BackgroundTransparency = 1 end end)

		sash.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				startX = input.Position.X
				sash.BackgroundTransparency = 0
			end
		end)

		if env.uis then
			dispose.connection(env.uis.InputChanged:Connect(function(input)
				if not dragging then return end
				if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
					local dx = input.Position.X - startX
					startX = input.Position.X
					if onDelta then onDelta(dx) end
				end
			end))
			dispose.connection(env.uis.InputEnded:Connect(function(input)
				if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
					dragging = false
					sash.BackgroundTransparency = 1
				end
			end))
		end

		return sash
	end

	function M.horizontal(parent, zIndex, onDelta)
		local sash = P.frame(parent, {
			name = "HorizontalSash",
			size = UDim2.new(1, 0, 0, 4),
			bg = theme.color.accent,
			transparency = 1,
			active = true,
			zIndex = zIndex or 35,
		})
		local dragging = false
		local startY = 0

		sash.MouseEnter:Connect(function() sash.BackgroundTransparency = 0.25 end)
		sash.MouseLeave:Connect(function() if not dragging then sash.BackgroundTransparency = 1 end end)

		sash.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				startY = input.Position.Y
				sash.BackgroundTransparency = 0
			end
		end)

		if env.uis then
			dispose.connection(env.uis.InputChanged:Connect(function(input)
				if not dragging then return end
				if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
					local dy = input.Position.Y - startY
					startY = input.Position.Y
					if onDelta then onDelta(dy) end
				end
			end))
			dispose.connection(env.uis.InputEnded:Connect(function(input)
				if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
					dragging = false
					sash.BackgroundTransparency = 1
				end
			end))
		end

		return sash
	end

	return M
end
