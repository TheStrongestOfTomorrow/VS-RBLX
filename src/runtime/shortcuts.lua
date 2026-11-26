-- Keyboard shortcut listener, custom toggle hotkey binder, & Keymap Preset Switcher
-- (`vscode`, `sublime`, `touch`).
return function(env)
	local dispose = env.require("runtime/dispose")
	local config = env.require("runtime/config")
	local commands = env.require("runtime/command_catalog")

	local M = {
		bindings = {},
		customPresets = {},
		enabled = true,
		installed = false,
		capturingCallback = nil,
	}

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

	function M.clear()
		M.bindings = {}
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

	function M.captureNextKey(callback)
		M.capturingCallback = callback
	end

	function M.registerCustomPreset(presetId, bindingsList)
		if type(presetId) ~= "string" or type(bindingsList) ~= "table" then return false end
		M.customPresets[presetId] = bindingsList
		if config.get("keybindings.preset", "vscode") == presetId then
			M.applyPreset(presetId)
		end
		return true
	end

	function M.unregisterCustomPreset(presetId)
		M.customPresets[presetId] = nil
		if config.get("keybindings.preset", "vscode") == presetId then
			config.set("keybindings.preset", "vscode")
		end
	end

	-- Applies base VS Code bindings + active preset (`vscode`, `sublime`, `touch` or custom extension preset) + custom toggle hotkey
	function M.applyPreset(presetName, toggleKeyName)
		local preset = tostring(presetName or config.get("keybindings.preset", "vscode") or "vscode")
		local toggleKey = tostring(toggleKeyName or config.get("keybindings.toggleKey", "RightShift") or "RightShift")
		M.clear()

		-- Custom Window Toggle Key
		if toggleKey ~= "" and toggleKey ~= "None" then
			M.bind({ key = toggleKey }, "workbench.toggleWindow", true)
		end

		-- Universal Workbench & File Shortcuts
		M.bind({ key = "F11" }, "window.maximize", true)
		M.bind({ key = "F12" }, "editor.gotoDefinition", true)
		M.bind({ ctrl = true, key = "Space" }, "editor.triggerSuggest", true)
		M.bind({ ctrl = true, key = "I" }, "ai.inlineEdit", true)
		M.bind({ ctrl = true, alt = true, key = "I" }, "ai.toggleChat", true)
		M.bind({ ctrl = true, shift = true, key = "I" }, "editor.showHover", true)
		M.bind({ ctrl = true, shift = true, key = "Z" }, "workbench.toggleZenMode", true)
		M.bind({ ctrl = true, shift = true, key = "M" }, "workbench.showTodos", true)
		M.bind({ ctrl = true, shift = true, key = "P" }, "workbench.commandPalette", true)
		M.bind({ key = "F1" }, "workbench.commandPalette", true)
		M.bind({ key = "F2" }, "file.rename", false)
		M.bind({ ctrl = true, key = "P" }, "workbench.quickOpen", true)
		M.bind({ ctrl = true, key = "B" }, "workbench.toggleSideBar", true)
		M.bind({ ctrl = true, key = "J" }, "workbench.togglePanel", true)
		M.bind({ ctrl = true, key = "Backquote" }, "workbench.togglePanel", true)
		M.bind({ ctrl = true, shift = true, key = "E" }, "workbench.viewExplorer", true)
		M.bind({ ctrl = true, shift = true, key = "F" }, "workbench.viewSearch", true)
		M.bind({ ctrl = true, shift = true, key = "G" }, "workbench.viewScm", true)
		M.bind({ ctrl = true, shift = true, key = "D" }, "workbench.viewDebug", true)
		M.bind({ ctrl = true, shift = true, key = "X" }, "workbench.viewExtensions", true)
		M.bind({ ctrl = true, key = "Comma" }, "workbench.viewSettings", true)
		M.bind({ ctrl = true, key = "S" }, "file.save", true)
		M.bind({ ctrl = true, shift = true, key = "S" }, "file.saveAll", true)
		M.bind({ ctrl = true, key = "N" }, "file.newUntitled", true)
		M.bind({ ctrl = true, key = "W" }, "file.closeTab", true)
		M.bind({ ctrl = true, shift = true, key = "V" }, "edit.clipboardHistory", true)

		-- Monaco Editing Shortcuts
		M.bind({ ctrl = true, key = "Z" }, "edit.undo", true)
		M.bind({ ctrl = true, key = "Y" }, "edit.redo", true)
		M.bind({ ctrl = true, key = "Slash" }, "editor.toggleComment", true)
		M.bind({ alt = true, key = "Up" }, "editor.moveLineUp", true)
		M.bind({ alt = true, key = "Down" }, "editor.moveLineDown", true)
		M.bind({ shift = true, alt = true, key = "Down" }, "editor.duplicateLineDown", true)
		M.bind({ shift = true, alt = true, key = "Up" }, "editor.duplicateLineUp", true)
		M.bind({ ctrl = true, shift = true, key = "K" }, "editor.deleteLine", true)
		M.bind({ ctrl = true, key = "D" }, "editor.selectWord", true)
		M.bind({ ctrl = true, key = "L" }, "editor.selectLine", true)
		M.bind({ ctrl = true, key = "RightBracket" }, "editor.indentLines", true)
		M.bind({ ctrl = true, key = "LeftBracket" }, "editor.outdentLines", true)
		M.bind({ ctrl = true, key = "F" }, "editor.find", true)
		M.bind({ ctrl = true, key = "H" }, "editor.replace", true)
		M.bind({ ctrl = true, key = "G" }, "editor.gotoLine", true)
		M.bind({ shift = true, alt = true, key = "F" }, "editor.format", true)
		M.bind({ ctrl = true, key = "Backslash" }, "editor.toggleSplit", true)
		M.bind({ alt = true, key = "Z" }, "editor.toggleWordWrap", true)
		M.bind({ key = "F5" }, "run.activeFile", true)

		-- Preset-specific extras
		if preset == "sublime" then
			M.bind({ ctrl = true, shift = true, key = "D" }, "editor.duplicateLineDown", true)
			M.bind({ ctrl = true, shift = true, key = "Up" }, "editor.moveLineUp", true)
			M.bind({ ctrl = true, shift = true, key = "Down" }, "editor.moveLineDown", true)
		elseif preset == "touch" then
			M.bind({ key = "F8" }, "run.activeFile", true)
			M.bind({ key = "F4" }, "workbench.toggleWindow", true)
		elseif M.customPresets[preset] then
			for _, cb in ipairs(M.customPresets[preset]) do
				if type(cb) == "table" and type(cb.key) == "string" and type(cb.command) == "string" then
					M.bind({
						ctrl = cb.ctrl == true,
						shift = cb.shift == true,
						alt = cb.alt == true,
						key = cb.key,
					}, cb.command, true)
				end
			end
		end
	end

	function M.install()
		if M.installed or not env.uis then return end
		M.installed = true
		dispose.connection(env.uis.InputBegan:Connect(function(input, gameProcessed)
			if not M.enabled then return end
			if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
			local keyName = input.KeyCode and input.KeyCode.Name or ""
			if keyName == "" or keyName == "Unknown" then return end

			-- Interactive custom toggle hotkey capture
			if M.capturingCallback then
				local ignoreMod = keyName == "LeftControl" or keyName == "RightControl"
					or keyName == "LeftShift" or keyName == "LeftAlt" or keyName == "RightAlt"
				if not ignoreMod then
					local cb = M.capturingCallback
					M.capturingCallback = nil
					pcall(cb, keyName)
					return
				end
			end

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
