-- Startup splash & GUI host mounter for VS-RBLX.
return function(env)
	local caps = env.require("runtime/caps")
	local M = {}

	-- Mounts a ScreenGui safely across all Roblox Executors and Studio LocalScripts:
	-- tries explicit parent -> gethui() -> CoreGui -> Players.LocalPlayer.PlayerGui.
	function M.mountScreenGui(sg, preferredParent)
		local function tryParent(target)
			if not target then return false end
			local ok = pcall(function() sg.Parent = target end)
			return ok and sg.Parent ~= nil
		end

		if tryParent(preferredParent) then return true end

		if caps.fn.gethui then
			local ok, hui = pcall(caps.fn.gethui)
			if ok and hui and tryParent(hui) then
				return true
			end
		end

		if caps.fn.protectGui then
			pcall(caps.fn.protectGui, sg)
		end

		if tryParent(env.services.CoreGui) then
			return true
		end

		local plr = env.plr or (env.services.Players and env.services.Players.LocalPlayer)
		if plr then
			local pg = nil
			pcall(function() pg = plr:FindFirstChildOfClass("PlayerGui") end)
			if not pg then
				pcall(function() pg = plr:FindFirstChild("PlayerGui") end)
			end
			if not pg and type(plr.WaitForChild) == "function" then
				local ok, waited = pcall(function() return plr:WaitForChild("PlayerGui", 5) end)
				if ok then pg = waited end
			end
			if tryParent(pg) then
				return true
			end
		end

		return false
	end

	function M.show()
		local sg = Instance.new("ScreenGui")
		sg.Name = "VSRBLX_Boot"
		sg.ResetOnSpawn = false
		sg.IgnoreGuiInset = true
		sg.DisplayOrder = 999
		if not M.mountScreenGui(sg) then
			pcall(function() sg:Destroy() end)
			return nil
		end

		local card = Instance.new("Frame", sg)
		card.Size = UDim2.fromOffset(310, 76)
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
		detail.TextTruncate = Enum.TextTruncate.AtEnd
		detail.Text = "Starting workbench..."

		local barBg = Instance.new("Frame", card)
		barBg.Size = UDim2.new(1, -24, 0, 3)
		barBg.Position = UDim2.fromOffset(12, 60)
		barBg.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
		barBg.BorderSizePixel = 0

		local barFill = Instance.new("Frame", barBg)
		barFill.Size = UDim2.new(0.12, 0, 1, 0)
		barFill.BackgroundColor3 = Color3.fromRGB(0, 122, 204)
		barFill.BorderSizePixel = 0

		return {
			step = function(stageText, ratio)
				detail.Text = tostring(stageText or "")
				barFill.Size = UDim2.new(math.max(0.08, math.min(1, tonumber(ratio) or 0.5)), 0, 1, 0)
			end,
			moduleStep = function(id, count, total)
				detail.Text = "Loading " .. tostring(id)
				local frac = total and total > 0 and (count / total) * 0.8 or 0.4
				barFill.Size = UDim2.new(math.max(0.1, math.min(0.85, frac)), 0, 1, 0)
			end,
			fail = function(reason)
				stroke.Color = Color3.fromRGB(241, 76, 76)
				barFill.BackgroundColor3 = Color3.fromRGB(241, 76, 76)
				barFill.Size = UDim2.new(1, 0, 1, 0)
				title.Text = "VS-RBLX Failed to Start"
				detail.TextColor3 = Color3.fromRGB(241, 76, 76)
				detail.Text = tostring(reason or "Unknown error")
				task.delay(6, function()
					pcall(function() sg:Destroy() end)
				end)
			end,
			close = function()
				pcall(function() sg:Destroy() end)
			end,
		}
	end

	return M
end
