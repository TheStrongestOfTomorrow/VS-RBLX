-- Keyboard shortcut listener & dispatcher supporting Ctrl/Cmd + Shift + Alt chords.
return function(env)
	local dispose = env.require("runtime/dispose")
	local commands = env.require("runtime/command_catalog")

	local M = { bindings = {}, enabled = true }

	local function ctrlDown()
		local uis = env.uis
		if not uis then return false end
		local ok, down = pcall(function()
			return uis:IsKeyDown(Enum.KeyCode.LeftControl)
				or uis:IsKeyDown(Enum.KeyCode.RightControl)
				or uis:IsKeyDown(Enum.KeyCode.LeftMeta)
				or uis:IsKeyDown(Enum.KeyCode.RightMeta)
		end)
		return ok and down == true
	end

	local function shiftDown()
		local uis = env.uis
		if not uis then return false end
		local ok, down = pcall(function()
			return uis:IsKeyDown(Enum.KeyCode.LeftShift) or uis:IsKeyDown(Enum.KeyCode.RightShift)
		end)
		return ok and down == true
	end

	local function altDown()
		local uis = env.uis
		if not uis then return false end
		local ok, down = pcall(function()
			return uis:IsKeyDown(Enum.KeyCode.LeftAlt) or uis:IsKeyDown(Enum.KeyCode.RightAlt)
		end)
		return ok and down == true
	end

	function M.bind(chord, commandId, allowWhenTyping)
		M.bindings[#M.bindings + 1] = {
			ctrl = chord.ctrl == true,
			shift = chord.shift == true,
			alt = chord.alt == true,
			key = chord.key,
			commandId = commandId,
			allowWhenTyping = allowWhenTyping ~= false,
		}
	end

	function M.install()
		if not env.uis then return end
		dispose.connection(env.uis.InputBegan:Connect(function(input, gameProcessed)
			if not M.enabled then return end
			if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
			local keyName = input.KeyCode and input.KeyCode.Name or ""
			local c, s, a = ctrlDown(), shiftDown(), altDown()
			local focusedBox = nil
			pcall(function() focusedBox = env.uis:GetFocusedTextBox() end)

			for _, b in ipairs(M.bindings) do
				if b.key == keyName and b.ctrl == c and b.shift == s and b.alt == a then
					if (not focusedBox and not gameProcessed) or b.allowWhenTyping then
						commands.run(b.commandId)
						return
					end
				end
			end
		end))
	end

	return M
end
