-- Brief VS Code startup splash card shown while modules & disk workspace initialise.
return function(env)
	local caps = env.require("runtime/caps")
	local M = {}

	function M.show()
		local parentGui = nil
		if caps.fn.gethui then
			local ok, hui = pcall(caps.fn.gethui)
			if ok and hui then parentGui = hui end
		end
		if not parentGui then parentGui = env.services.CoreGui end
		if not parentGui and env.plr then parentGui = env.plr:FindFirstChild("PlayerGui") end
		if not parentGui then return nil end

		local sg = Instance.new("ScreenGui")
		sg.Name = "VSRBLX_Boot"
		sg.IgnoreGuiInset = true
		sg.DisplayOrder = 999
		local ok = pcall(function() sg.Parent = parentGui end)
		if not ok and env.plr and env.plr:FindFirstChild("PlayerGui") then
			pcall(function() sg.Parent = env.plr.PlayerGui end)
		end

		local card = Instance.new("Frame", sg)
		card.Size = UDim2.fromOffset(290, 74)
		card.Position = UDim2.fromScale(0.5, 0.5)
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		card.BorderSizePixel = 0
		local corner = Instance.new("UICorner", card)
		corner.CornerRadius = UDim.new(0, 6)
		local stroke = Instance.new("UIStroke", card)
		stroke.Color = Color3.fromRGB(0, 122, 204)
		stroke.Thickness = 1

		local title = Instance.new("TextLabel", card)
		title.Size = UDim2.new(1, -24, 0, 22)
		title.Position = UDim2.fromOffset(12, 12)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.SourceSansBold
		title.TextSize = 15
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = "VS-RBLX · Visual Studio Code"

		local detail = Instance.new("TextLabel", card)
		detail.Size = UDim2.new(1, -24, 0, 18)
		detail.Position = UDim2.fromOffset(12, 36)
		detail.BackgroundTransparency = 1
		detail.Font = Enum.Font.SourceSans
		detail.TextSize = 12
		detail.TextColor3 = Color3.fromRGB(160, 160, 160)
		detail.TextXAlignment = Enum.TextXAlignment.Left
		detail.Text = "Mounting workbench..."

		local barBg = Instance.new("Frame", card)
		barBg.Size = UDim2.new(1, -24, 0, 3)
		barBg.Position = UDim2.fromOffset(12, 58)
		barBg.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
		barBg.BorderSizePixel = 0

		local barFill = Instance.new("Frame", barBg)
		barFill.Size = UDim2.new(0.25, 0, 1, 0)
		barFill.BackgroundColor3 = Color3.fromRGB(0, 122, 204)
		barFill.BorderSizePixel = 0

		return {
			step = function(stageText, ratio)
				detail.Text = tostring(stageText or "")
				barFill.Size = UDim2.new(math.max(0.1, math.min(1, tonumber(ratio) or 0.5)), 0, 1, 0)
			end,
			close = function()
				pcall(function() sg:Destroy() end)
			end,
		}
	end

	return M
end
