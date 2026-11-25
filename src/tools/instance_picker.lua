-- Interactive In-Game 3D Part & GUI Eyedropper Picker (`src/tools/instance_picker.lua`).
-- Lets players click/tap any 3D BasePart or GuiObject in the live Roblox game and inserts
-- its exact Luau expression (`workspace.Map.Door`, etc.) straight at the active editor cursor.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local overlay = env.require("ui/overlay")
	local dispose = env.require("runtime/dispose")
	local clipboard = env.require("runtime/clipboard")
	local robloxExplorer = env.require("runtime/roblox_explorer")

	local M = {
		active = false,
	}

	local banner = nil
	local bannerLbl = nil
	local activeConns = {}
	local onPickCallback = nil
	local restoreWindowFn = nil

	local function cleanupPicker()
		M.active = false
		for i = #activeConns, 1, -1 do
			local c = activeConns[i]
			activeConns[i] = nil
			pcall(function() c:Disconnect() end)
		end
		if banner then
			pcall(function() banner:Destroy() end)
			banner = nil
			bannerLbl = nil
		end
		if restoreWindowFn then
			local fn = restoreWindowFn
			restoreWindowFn = nil
			pcall(fn)
		end
	end

	function M.pickInstance(inst, insertFn)
		if not inst then return nil end
		local luauPath = robloxExplorer.luauPathOf(inst)
		clipboard.copy(luauPath)
		if type(insertFn) == "function" then
			insertFn(luauPath, inst)
		elseif type(onPickCallback) == "function" then
			onPickCallback(luauPath, inst)
		end
		return luauPath
	end

	local function resolveTargetAtScreenPos(x, y)
		-- 1. Check PlayerGui GUI elements (excluding VS-RBLX's own ScreenGui)
		if env.plr then
			local pg = nil
			pcall(function() pg = env.plr:FindFirstChildOfClass("PlayerGui") end)
			if pg and type(pg.GetGuiObjectsAtPosition) == "function" then
				local ok, list = pcall(function() return pg:GetGuiObjectsAtPosition(x, y) end)
				if ok and type(list) == "table" then
					for _, guiObj in ipairs(list) do
						local fullName = ""
						pcall(function() fullName = tostring(guiObj:GetFullName()) end)
						if not fullName:find("VSRBLX_", 1, true) then
							return guiObj
						end
					end
				end
			end
			-- 2. Fallback to LocalPlayer:GetMouse().Target for 3D BaseParts
			if type(env.plr.GetMouse) == "function" then
				local okM, mouse = pcall(function() return env.plr:GetMouse() end)
				if okM and mouse and mouse.Target then
					return mouse.Target
				end
			end
		end
		return nil
	end

	function M.start(parentScreen, windowObj, insertFn)
		if M.active then
			cleanupPicker()
			return false
		end
		M.active = true
		onPickCallback = insertFn

		-- Temporarily hide window into ghost/peek state so the player has full view of the 3D world
		if windowObj and windowObj.visible and not windowObj.minimised then
			windowObj.root.Visible = false
			restoreWindowFn = function()
				if windowObj then windowObj.root.Visible = true end
			end
		end

		banner = P.frame(parentScreen, {
			name = "EyedropperBanner",
			size = UDim2.fromOffset(440, 36),
			pos = UDim2.new(0.5, 0, 0, 14),
			anchor = Vector2.new(0.5, 0),
			bg = theme.color.sideBar,
			radius = 18,
			border = theme.color.accent,
			active = true,
			zIndex = 280,
		})
		bannerLbl = P.label(banner, {
			name = "EyedropperTargetLabel",
			size = UDim2.new(1, -84, 1, 0),
			pos = UDim2.fromOffset(14, 0),
			mono = true,
			bold = true,
			textSize = 11,
			color = theme.color.tabActiveText,
			text = "🎯 Click/Tap any 3D Part or GUI to insert path...",
			truncate = true,
			zIndex = 281,
		})
		P.button(banner, {
			name = "CancelEyedropperBtn",
			size = UDim2.fromOffset(62, 24),
			pos = UDim2.new(1, -68, 0.5, -12),
			bg = theme.color.bad,
			color = Color3.fromRGB(255, 255, 255),
			bold = true,
			text = "Cancel",
			textSize = 11,
			radius = 12,
			zIndex = 282,
			onClick = function()
				cleanupPicker()
			end,
		})

		if env.uis then
			activeConns[#activeConns + 1] = env.uis.InputChanged:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseMovement and bannerLbl then
					local hovered = resolveTargetAtScreenPos(input.Position.X, input.Position.Y)
					if hovered then
						bannerLbl.Text = "🎯 " .. robloxExplorer.luauPathOf(hovered)
					else
						bannerLbl.Text = "🎯 Click/Tap any 3D Part or GUI to insert path..."
					end
				end
			end)

			activeConns[#activeConns + 1] = env.uis.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Escape then
					cleanupPicker()
					return
				end
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					if banner then
						local p, s = banner.AbsolutePosition, banner.AbsoluteSize
						if input.Position.X >= p.X and input.Position.X <= p.X + s.X
							and input.Position.Y >= p.Y and input.Position.Y <= p.Y + s.Y then
							return
						end
					end
					local target = resolveTargetAtScreenPos(input.Position.X, input.Position.Y)
					cleanupPicker()
					if target then
						local expr = M.pickInstance(target, insertFn)
						overlay.toast("Inserted: " .. tostring(expr), "good", 2.5)
					else
						overlay.toast("No 3D Part or GUI found under cursor", "warn", 2)
					end
				end
			end)
		end

		dispose.add(cleanupPicker)
		return true
	end

	M.cancel = cleanupPicker
	return M
end
