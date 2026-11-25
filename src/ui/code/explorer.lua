-- Collapsible hierarchical File Tree widget with Seti file/folder badges, inline VS Code
-- create/rename input with live validation, and right-click disk actions.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local icons = env.require("ui/icons")
	local overlay = env.require("ui/overlay")
	local util = env.require("runtime/util")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")
	local clipboard = env.require("runtime/clipboard")

	local M = {}

	local function validateInlineName(rawName, parentDir, isDir, oldPath)
		local trimmed = util.trim(tostring(rawName or ""))
		if trimmed == "" then
			return false, "A file or folder name must be provided.", ""
		end
		if trimmed == "." or trimmed == ".." then
			return false, "The name '" .. trimmed .. "' is not valid as a file or folder name.", ""
		end
		if trimmed:find("[\\:%*%?\"<>|]") then
			return false, "Name contains invalid characters (\\ : * ? \" < > |).", ""
		end
		if util.startsWith(trimmed, "/") or trimmed:sub(-1) == "/" then
			return false, "Name cannot start or end with a slash.", ""
		end
		local fullRel = parentDir ~= "" and util.joinPath(parentDir, trimmed) or util.normalisePath(trimmed)
		if oldPath and fullRel == oldPath then
			return true, nil, fullRel
		end
		if workspaceFs.exists(fullRel) or workspaceFs.isDir(fullRel) then
			return false, "A file or folder '" .. util.basename(fullRel) .. "' already exists at this location.", fullRel
		end
		return true, nil, fullRel
	end

	function M.new(parent)
		local expanded = { [""] = true, ["src"] = true, ["web"] = true, ["scripts"] = true }
		local inlineState = nil
		local activeInlineBox = nil

		local holder = P.frame(parent, {
			name = "FileTreeContainer",
			size = UDim2.new(1, 0, 0, 200),
			zIndex = 22,
		})
		holder.AutomaticSize = Enum.AutomaticSize.Y
		P.list(holder, Enum.FillDirection.Vertical, 1)

		local rebuild

		local function cancelInline()
			if not inlineState then return end
			inlineState = nil
			activeInlineBox = nil
			rebuild()
		end

		local function commitInline(overrideValue)
			if not inlineState then return false, "no inline edit active" end
			local st = inlineState
			local textVal = overrideValue ~= nil and tostring(overrideValue)
				or (activeInlineBox and activeInlineBox.Text)
				or st.value
				or ""

			-- Unchanged rename -> cleanly cancel without error
			if st.mode == "rename" and util.trim(textVal) == util.basename(st.targetPath) then
				cancelInline()
				return true, st.targetPath
			end

			local valid, errMsg, resolvedPath = validateInlineName(
				textVal,
				st.dir,
				st.mode == "newFolder" or st.isDir,
				st.targetPath
			)
			if not valid then
				st.value = textVal
				st.error = errMsg
				rebuild()
				return false, errMsg
			end

			inlineState = nil
			activeInlineBox = nil

			if st.mode == "newFolder" then
				local ok, err = workspaceFs.createFolder(resolvedPath)
				if ok then
					expanded[resolvedPath] = true
					overlay.toast("Created folder: " .. resolvedPath, "good", 2.2)
					rebuild()
					return true, resolvedPath
				end
				overlay.toast("Error: " .. tostring(err), "bad", 4)
				rebuild()
				return false, err
			elseif st.mode == "newFile" then
				local ok, err = workspaceFs.writeFile(resolvedPath, "")
				if ok then
					codeStore.openFile(resolvedPath, { reloadFromDisk = true })
					overlay.toast("Created file: " .. resolvedPath, "good", 2.2)
					rebuild()
					return true, resolvedPath
				end
				overlay.toast("Error: " .. tostring(err), "bad", 4)
				rebuild()
				return false, err
			elseif st.mode == "rename" then
				local ok, res = workspaceFs.renamePath(st.targetPath, resolvedPath)
				if ok then
					codeStore.renameOpenFile(st.targetPath, res)
					overlay.toast("Renamed to " .. tostring(res), "good", 2.2)
					rebuild()
					return true, res
				end
				overlay.toast("Rename failed: " .. tostring(res), "bad", 4)
				rebuild()
				return false, res
			end
			return false, "unknown inline mode"
		end

		local function startInlineCreate(baseDir, isFolder)
			local dir = util.normalisePath(baseDir or "")
			if dir ~= "" then
				-- Expand ancestor directories so the inline input is immediately visible
				local accum = ""
				for _, seg in ipairs(util.split(dir, "/")) do
					if seg ~= "" then
						accum = accum == "" and seg or (accum .. "/" .. seg)
						expanded[accum] = true
					end
				end
			end
			inlineState = {
				mode = isFolder and "newFolder" or "newFile",
				dir = dir,
				isDir = isFolder == true,
				value = "",
				error = nil,
			}
			rebuild()
		end

		local function startInlineRename(targetPath)
			local clean = util.normalisePath(targetPath or "")
			if clean == "" then return false end
			local dir = util.dirname(clean)
			local isFolder = workspaceFs.isDir(clean)
			inlineState = {
				mode = "rename",
				targetPath = clean,
				dir = dir,
				isDir = isFolder,
				value = util.basename(clean),
				error = nil,
			}
			rebuild()
			return true
		end

		local function renderInlineEditor(depth, orderCounter)
			local st = inlineState
			local indentPx = 8 + depth * 12
			local wrap = P.frame(holder, {
				name = "ExplorerInlineEditor",
				size = UDim2.new(1, 0, 0, st.error and 44 or 24),
				order = orderCounter,
				zIndex = 26,
			})

			local row = P.frame(wrap, {
				name = "InlineInputRow",
				size = UDim2.new(1, -4, 0, 23),
				pos = UDim2.fromOffset(2, 0),
				bg = theme.color.listActive,
				radius = 2,
				zIndex = 26,
			})

			local iconSlot = P.frame(row, {
				name = "InlinePreviewBadge",
				size = UDim2.fromOffset(20, 16),
				pos = UDim2.fromOffset(indentPx + 4, 4),
				zIndex = 27,
			})

			local function updatePreviewBadge(txt)
				iconSlot:ClearAllChildren()
				local probe = util.trim(txt or "") ~= "" and txt or (st.isDir and "folder" or "file.luau")
				icons.fileBadge(iconSlot, probe, st.isDir, 28, false)
			end
			updatePreviewBadge(st.value)

			local boxX = indentPx + 26
			local inputContainer = P.frame(row, {
				name = "InlineFieldFrame",
				size = UDim2.new(1, -(boxX + 42), 0, 19),
				pos = UDim2.fromOffset(boxX, 2),
				bg = theme.color.inputBg,
				radius = 2,
				zIndex = 27,
			})
			local borderStroke = P.stroke(inputContainer, st.error and theme.color.bad or theme.color.inputFocus, 1)

			local tb = Instance.new("TextBox", inputContainer)
			tb.Name = "InlineExplorerInput"
			tb.BackgroundTransparency = 1
			tb.BorderSizePixel = 0
			tb.Size = UDim2.new(1, -8, 1, 0)
			tb.Position = UDim2.fromOffset(4, 0)
			tb.Font = theme.font.mono
			tb.TextSize = 12
			tb.TextColor3 = theme.color.tabActiveText
			tb.PlaceholderColor3 = theme.color.muted
			tb.PlaceholderText = st.isDir and "folder_name" or "script.luau"
			tb.Text = st.value or ""
			tb.ClearTextOnFocus = false
			tb.TextXAlignment = Enum.TextXAlignment.Left
			tb.ZIndex = 28
			activeInlineBox = tb

			local errorBanner = P.frame(wrap, {
				name = "InlineErrorBanner",
				size = UDim2.new(1, -(boxX + 6), 0, 20),
				pos = UDim2.fromOffset(boxX + 2, 23),
				bg = Color3.fromRGB(90, 29, 29),
				border = theme.color.bad,
				radius = 2,
				visible = st.error ~= nil,
				zIndex = 30,
			})
			local errorLbl = P.label(errorBanner, {
				name = "InlineErrorText",
				size = UDim2.new(1, -8, 1, 0),
				pos = UDim2.fromOffset(4, 0),
				text = st.error or "",
				textSize = 10,
				color = Color3.fromRGB(255, 210, 210),
				truncate = true,
				zIndex = 31,
			})

			P.button(row, {
				name = "InlineConfirmBtn",
				size = UDim2.fromOffset(18, 19),
				pos = UDim2.new(1, -38, 0, 2),
				bg = theme.color.accent,
				hoverBg = theme.color.accentHover,
				color = Color3.fromRGB(255, 255, 255),
				bold = true,
				text = "✓",
				textSize = 11,
				radius = 2,
				zIndex = 28,
				onClick = function() commitInline(tb.Text) end,
			})
			P.button(row, {
				name = "InlineCancelBtn",
				size = UDim2.fromOffset(18, 19),
				pos = UDim2.new(1, -19, 0, 2),
				hoverBg = theme.color.hover,
				color = theme.color.muted,
				text = "✕",
				textSize = 10,
				radius = 2,
				zIndex = 28,
				onClick = function() cancelInline() end,
			})

			tb:GetPropertyChangedSignal("Text"):Connect(function()
				st.value = tb.Text
				updatePreviewBadge(tb.Text)
				if util.trim(tb.Text) == "" and st.mode ~= "rename" then
					st.error = nil
					borderStroke.Color = theme.color.inputFocus
					errorBanner.Visible = false
					wrap.Size = UDim2.new(1, 0, 0, 24)
					return
				end
				local ok, errMsg = validateInlineName(tb.Text, st.dir, st.isDir, st.targetPath)
				st.error = ok and nil or errMsg
				borderStroke.Color = ok and theme.color.inputFocus or theme.color.bad
				errorLbl.Text = errMsg or ""
				errorBanner.Visible = not ok
				wrap.Size = UDim2.new(1, 0, 0, ok and 24 or 44)
			end)

			tb.FocusLost:Connect(function(enterPressed)
				if not inlineState then return end
				if enterPressed then
					commitInline(tb.Text)
				elseif util.trim(tb.Text) == "" then
					cancelInline()
				end
			end)

			task.defer(function()
				pcall(function() tb:CaptureFocus() end)
			end)
		end

		rebuild = function()
			activeInlineBox = nil
			holder:ClearAllChildren()
			P.list(holder, Enum.FillDirection.Vertical, 1)
			local activeDoc = codeStore.active()
			local activePath = activeDoc and activeDoc.path or nil
			local orderCounter = 0

			local function renderDir(dirPath, depth)
				if depth > 10 then return end

				if inlineState and (inlineState.mode == "newFile" or inlineState.mode == "newFolder") and inlineState.dir == dirPath then
					orderCounter = orderCounter + 1
					renderInlineEditor(depth, orderCounter)
				end

				local entries = workspaceFs.listDir(dirPath)
				for _, entry in ipairs(entries) do
					if inlineState and inlineState.mode == "rename" and inlineState.targetPath == entry.path then
						orderCounter = orderCounter + 1
						renderInlineEditor(depth, orderCounter)
					else
						orderCounter = orderCounter + 1
						local isSelected = (not entry.isDir) and (entry.path == activePath)
						local isOpenFolder = entry.isDir and expanded[entry.path] == true
						local row = P.button(holder, {
							name = "Tree_" .. entry.name,
							size = UDim2.new(1, 0, 0, 22),
							bg = isSelected and theme.color.listActive or nil,
							hoverBg = theme.color.hover,
							text = "",
							order = orderCounter,
							zIndex = 23,
							activeState = function() return isSelected end,
							onClick = function()
								if entry.isDir then
									expanded[entry.path] = not expanded[entry.path]
									rebuild()
								else
									codeStore.openFile(entry.path)
								end
							end,
						})

						local indentPx = 8 + depth * 12
						if entry.isDir then
							P.label(row, {
								size = UDim2.fromOffset(12, 22),
								pos = UDim2.fromOffset(indentPx, 0),
								text = isOpenFolder and "▾" or "▸",
								textSize = 11,
								color = theme.color.muted,
								zIndex = 24,
							})
						end

						local badge = icons.fileBadge(row, entry.path, entry.isDir, 24, isOpenFolder)
						badge.Position = UDim2.fromOffset(indentPx + (entry.isDir and 13 or 4), 4)

						local nameX = indentPx + (entry.isDir and 33 or 27)
						P.label(row, {
							size = UDim2.new(1, -(nameX + 8), 1, 0),
							pos = UDim2.fromOffset(nameX, 0),
							text = entry.name,
							textSize = 12,
							color = isSelected and theme.color.tabActiveText or theme.color.sideBarText,
							truncate = true,
							zIndex = 24,
						})

						row.MouseButton2Click:Connect(function()
							local p = row.AbsolutePosition
							local targetDir = entry.isDir and entry.path or util.dirname(entry.path)
							local menu = {
								{ label = "New File...", onClick = function() startInlineCreate(targetDir, false) end },
								{ label = "New Folder...", onClick = function() startInlineCreate(targetDir, true) end },
								{ separator = true },
							}
							if not entry.isDir then
								menu[#menu + 1] = {
									label = "Open to the Side",
									onClick = function() codeStore.openFile(entry.path, { pane = "secondary" }) end,
								}
							end
							menu[#menu + 1] = {
								label = "Copy Relative Path",
								onClick = function()
									clipboard.copy(entry.path)
									overlay.toast("Copied path: " .. entry.path, "info", 1.8)
								end,
							}
							menu[#menu + 1] = { label = "Rename", shortcut = "F2", onClick = function() startInlineRename(entry.path) end }
							menu[#menu + 1] = {
								label = "Delete from Disk",
								onClick = function()
									overlay.confirm({
										title = "Delete '" .. entry.name .. "' from disk?",
										message = "This will remove '" .. entry.path .. "' from the active workspace.",
										primaryText = "Delete",
										cancelText = "Cancel",
										onPrimary = function()
											workspaceFs.deletePath(entry.path)
											local openDoc = codeStore.findByPath(entry.path)
											if openDoc then codeStore.close(openDoc.id, { force = true }) end
											overlay.toast("Deleted " .. entry.path, "warn", 2.5)
										end,
									})
								end,
							}
							overlay.dropdown(p.X + 24, p.Y + 18, menu, 190)
						end)
					end

					if entry.isDir and expanded[entry.path] then
						renderDir(entry.path, depth + 1)
					end
				end
			end

			renderDir("", 0)
		end

		workspaceFs.changed:connect(rebuild)
		codeStore.changed:connect(rebuild)
		theme.changed:connect(rebuild)

		rebuild()
		return {
			root = holder,
			refresh = rebuild,
			promptNewFile = function(dir) startInlineCreate(dir or "", false) end,
			promptNewFolder = function(dir) startInlineCreate(dir or "", true) end,
			startRename = startInlineRename,
			getInlineState = function() return inlineState end,
			commitInline = commitInline,
			cancelInline = cancelInline,
		}
	end

	return M
end
