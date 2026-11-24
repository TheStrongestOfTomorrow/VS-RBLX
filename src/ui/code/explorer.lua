-- Collapsible hierarchical File Tree widget with language icons and right-click disk actions.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local icons = env.require("ui/icons")
	local overlay = env.require("ui/overlay")
	local util = env.require("runtime/util")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")

	local M = {}

	function M.new(parent)
		local expanded = { [""] = true, ["src"] = true, ["web"] = true, ["scripts"] = true }
		local holder = P.frame(parent, {
			name = "FileTreeContainer",
			size = UDim2.new(1, 0, 0, 200),
			zIndex = 22,
		})
		holder.AutomaticSize = Enum.AutomaticSize.Y
		P.list(holder, Enum.FillDirection.Vertical, 1)

		local rebuild

		local function promptCreate(baseDir, isFolder)
			local pfx = baseDir ~= "" and (baseDir .. "/") or ""
			overlay.prompt({
				title = isFolder and "New Folder on Local Disk" or "New File on Local Disk",
				subtitle = "Workspace: " .. workspaceFs.diskRootLabel(),
				default = pfx,
				placeholder = pfx .. (isFolder and "folder_name" or "script.luau"),
				mono = true,
				confirmText = "Create",
				onConfirm = function(val)
					local clean = util.normalisePath(val)
					if clean == "" then return end
					if isFolder then
						local ok, err = workspaceFs.createFolder(clean)
						if ok then
							expanded[clean] = true
							overlay.toast("Created folder: " .. clean, "good", 2.5)
						else
							overlay.toast("Error: " .. tostring(err), "bad", 4)
						end
					else
						local ok, err = workspaceFs.writeFile(clean, "")
						if ok then
							codeStore.openFile(clean, { reloadFromDisk = true })
							overlay.toast("Created file on disk: " .. clean, "good", 2.5)
						else
							overlay.toast("Error: " .. tostring(err), "bad", 4)
						end
					end
				end,
			})
		end

		local function promptRename(oldPath)
			overlay.prompt({
				title = "Rename Path on Disk",
				default = oldPath,
				mono = true,
				confirmText = "Rename",
				onConfirm = function(newVal)
					local ok, res = workspaceFs.renamePath(oldPath, newVal)
					if ok then
						local doc = codeStore.findByPath(oldPath)
						if doc then
							codeStore.close(doc.id)
							codeStore.openFile(res)
						end
						overlay.toast("Renamed to " .. tostring(res), "good", 2.5)
					else
						overlay.toast("Rename failed: " .. tostring(res), "bad", 4)
					end
				end,
			})
		end

		rebuild = function()
			holder:ClearAllChildren()
			P.list(holder, Enum.FillDirection.Vertical, 1)
			local activeDoc = codeStore.active()
			local activePath = activeDoc and activeDoc.path or nil
			local orderCounter = 0

			local function renderDir(dirPath, depth)
				if depth > 10 then return end
				local entries = workspaceFs.listDir(dirPath)
				for _, entry in ipairs(entries) do
					orderCounter = orderCounter + 1
					local isSelected = (not entry.isDir) and (entry.path == activePath)
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
							text = expanded[entry.path] and "▾" or "▸",
							textSize = 11,
							color = theme.color.muted,
							zIndex = 24,
						})
					end

					local badge = icons.fileBadge(row, entry.lang, entry.isDir, 24)
					badge.Position = UDim2.fromOffset(indentPx + (entry.isDir and 14 or 4), entry.isDir and 5 or 4)

					local nameX = indentPx + (entry.isDir and 32 or 34)
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
							{ label = "New File Here...", onClick = function() promptCreate(targetDir, false) end },
							{ label = "New Folder Here...", onClick = function() promptCreate(targetDir, true) end },
							{ separator = true },
						}
						if not entry.isDir then
							menu[#menu + 1] = {
								label = "Open to the Side",
								onClick = function() codeStore.openFile(entry.path, { pane = "secondary" }) end,
							}
						end
						menu[#menu + 1] = { label = "Rename...", onClick = function() promptRename(entry.path) end }
						menu[#menu + 1] = {
							label = "Delete from Disk",
							onClick = function()
								workspaceFs.deletePath(entry.path)
								local openDoc = codeStore.findByPath(entry.path)
								if openDoc then codeStore.close(openDoc.id) end
								overlay.toast("Deleted " .. entry.path, "warn", 2.5)
							end,
						}
						overlay.dropdown(p.X + 24, p.Y + 18, menu, 185)
					end)

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
			promptNewFile = function() promptCreate("", false) end,
			promptNewFolder = function() promptCreate("", true) end,
		}
	end

	return M
end
