-- VS Code Command Palette (`>`), Quick Open File Finder (`Ctrl+P`), Go to Line (`:`),
-- and Go to Symbol (`@`) modal overlay.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local icons = env.require("ui/icons")
	local util = env.require("runtime/util")
	local commands = env.require("runtime/command_catalog")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")
	local codeFolding = env.require("runtime/code_folding")

	local M = { openState = false }

	function M.new(parentWindow)
		local backdrop = P.button(parentWindow, {
			name = "CommandPaletteBackdrop",
			size = UDim2.fromScale(1, 1),
			text = "",
			visible = false,
			zIndex = 160,
			onClick = function()
				backdrop.Visible = false
				M.openState = false
			end,
		})
		backdrop.BackgroundTransparency = 1

		local card = P.frame(backdrop, {
			name = "CommandPaletteCard",
			size = UDim2.fromOffset(500, 320),
			pos = UDim2.new(0.5, 0, 0, 36),
			anchor = Vector2.new(0.5, 0),
			bg = theme.color.dropdownBg,
			radius = 6,
			border = theme.color.border,
			active = true,
			zIndex = 162,
		})
		P.pad(card, 8, 8, 8, 8)

		local inputWrap, box = P.input(card, {
			name = "PaletteInput",
			size = UDim2.new(1, 0, 0, 30),
			placeholder = "Search files by name, or type '>' for commands, ':' for line, '@' for symbols",
			zIndex = 163,
		})
		inputWrap.Active = true

		local listScroll = P.scroll(card, {
			name = "PaletteResults",
			size = UDim2.new(1, 0, 1, -38),
			pos = UDim2.fromOffset(0, 38),
			zIndex = 163,
		})
		P.list(listScroll, Enum.FillDirection.Vertical, 2)

		local currentResults = {}

		local function closePalette()
			backdrop.Visible = false
			M.openState = false
		end

		local function populate(rawText)
			listScroll:ClearAllChildren()
			P.list(listScroll, Enum.FillDirection.Vertical, 2)
			currentResults = {}
			local text = tostring(rawText or "")

			if util.startsWith(text, ">") then
				local found = commands.search(text:sub(2))
				for idx, cmd in ipairs(found) do
					if idx <= 40 then
						currentResults[#currentResults + 1] = function()
							closePalette()
							commands.run(cmd.id)
						end
						local row = P.button(listScroll, {
							name = "Cmd_" .. cmd.id,
							size = UDim2.new(1, 0, 0, 26),
							hoverBg = theme.color.listActive,
							text = "",
							radius = 3,
							order = idx,
							zIndex = 164,
							onClick = currentResults[#currentResults],
						})
						P.label(row, {
							size = UDim2.new(1, -100, 1, 0),
							pos = UDim2.fromOffset(8, 0),
							text = cmd.label,
							textSize = 12,
							color = theme.color.sideBarText,
							truncate = true,
							zIndex = 165,
						})
						if cmd.shortcut ~= "" then
							P.label(row, {
								size = UDim2.fromOffset(90, 26),
								pos = UDim2.new(1, -96, 0, 0),
								text = cmd.shortcut,
								textSize = 11,
								color = theme.color.muted,
								alignX = Enum.TextXAlignment.Right,
								zIndex = 165,
							})
						end
					end
				end
			elseif util.startsWith(text, ":") then
				local ln = tonumber(util.trim(text:sub(2))) or 1
				currentResults[1] = function()
					closePalette()
					local doc = codeStore.active()
					if doc then codeStore.jumpToLine(doc.id, ln, 1) end
				end
				P.button(listScroll, {
					size = UDim2.new(1, 0, 0, 28),
					hoverBg = theme.color.listActive,
					text = "  Go to Line " .. tostring(ln),
					alignX = Enum.TextXAlignment.Left,
					radius = 3,
					zIndex = 164,
					onClick = currentResults[1],
				})
			elseif util.startsWith(text, "@") then
				local doc = codeStore.active()
				local q = util.trim(text:sub(2)):lower()
				local syms = doc and codeFolding.symbols(doc.content, doc.langId) or {}
				local rank = 0
				for _, sym in ipairs(syms) do
					if q == "" or sym.name:lower():find(q, 1, true) then
						rank = rank + 1
						local targetLn = sym.line
						currentResults[rank] = function()
							closePalette()
							if doc then codeStore.jumpToLine(doc.id, targetLn, 1) end
						end
						local row = P.button(listScroll, {
							size = UDim2.new(1, 0, 0, 26),
							hoverBg = theme.color.listActive,
							text = "",
							radius = 3,
							order = rank,
							zIndex = 164,
							onClick = currentResults[rank],
						})
						P.label(row, {
							size = UDim2.new(1, -60, 1, 0),
							pos = UDim2.fromOffset(8, 0),
							text = string.format("[%s] %s", sym.kind, sym.name),
							mono = true,
							textSize = 12,
							color = theme.color.sideBarText,
							zIndex = 165,
						})
						P.label(row, {
							size = UDim2.fromOffset(50, 26),
							pos = UDim2.new(1, -56, 0, 0),
							text = "Ln " .. tostring(sym.line),
							textSize = 11,
							color = theme.color.muted,
							alignX = Enum.TextXAlignment.Right,
							zIndex = 165,
						})
					end
				end
			else
				local q = util.trim(text):lower()
				local files = workspaceFs.listAllFiles("")
				local rank = 0
				for _, f in ipairs(files) do
					if rank < 35 and (q == "" or f.path:lower():find(q, 1, true)) then
						rank = rank + 1
						local targetPath = f.path
						currentResults[rank] = function()
							closePalette()
							codeStore.openFile(targetPath)
						end
						local row = P.button(listScroll, {
							name = "FileHit_" .. tostring(rank),
							size = UDim2.new(1, 0, 0, 26),
							hoverBg = theme.color.listActive,
							text = "",
							radius = 3,
							order = rank,
							zIndex = 164,
							onClick = currentResults[rank],
						})
						local badge = icons.fileBadge(row, f.lang, false, 165)
						badge.Position = UDim2.fromOffset(6, 6)
						P.label(row, {
							size = UDim2.new(1, -42, 1, 0),
							pos = UDim2.fromOffset(36, 0),
							text = f.name .. "   —   " .. f.path,
							textSize = 12,
							color = theme.color.sideBarText,
							truncate = true,
							zIndex = 165,
						})
					end
				end
			end
		end

		box:GetPropertyChangedSignal("Text"):Connect(function()
			if backdrop.Visible then
				populate(box.Text)
			end
		end)

		box.FocusLost:Connect(function(enterPressed)
			if enterPressed and currentResults[1] then
				currentResults[1]()
			end
		end)

		local api = {}
		function api.open(prefix)
			M.openState = true
			backdrop.Visible = true
			card.BackgroundColor3 = theme.color.dropdownBg
			box.Text = prefix or ""
			populate(box.Text)
			task.defer(function()
				pcall(function()
					box:CaptureFocus()
					box.CursorPosition = #box.Text + 1
				end)
			end)
		end

		function api.close()
			closePalette()
		end

		return api
	end

	return M
end
