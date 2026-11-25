-- VS Code Explorer Sidebar Viewlet: Open Editors, Local Disk File Tree (`writefile`/
-- `readfile`), and Live Roblox DataModel Script Importer.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local icons = env.require("ui/icons")
	local explorerTreeMod = env.require("ui/code/explorer")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")
	local robloxExplorer = env.require("runtime/roblox_explorer")
	local decompiler = env.require("tools/decompiler")
	local fsSync = env.require("tools/fs_sync")
	local overlay = env.require("ui/overlay")

	local M = {}

	function M.new(parent)
		local root = P.frame(parent, {
			name = "ExplorerViewlet",
			size = UDim2.fromScale(1, 1),
			zIndex = 21,
		})

		local titleRow = P.frame(root, {
			size = UDim2.new(1, 0, 0, 30),
			zIndex = 22,
		})
		P.label(titleRow, {
			size = UDim2.new(1, -112, 1, 0),
			pos = UDim2.fromOffset(12, 0),
			text = "EXPLORER",
			bold = true,
			textSize = 11,
			color = theme.color.muted,
			zIndex = 23,
		})

		local toolRow = P.frame(titleRow, {
			size = UDim2.fromOffset(104, 26),
			pos = UDim2.new(1, -108, 0, 2),
			zIndex = 23,
		})
		P.list(toolRow, Enum.FillDirection.Horizontal, 2, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

		local fileTree = nil
		local toolBtns = {}

		local function makeToolBtn(name, iconName, order, onClick)
			local btn = P.button(toolRow, {
				name = name,
				size = UDim2.fromOffset(24, 22),
				text = "",
				radius = 3,
				order = order,
				zIndex = 24,
				onClick = onClick,
			})
			toolBtns[#toolBtns + 1] = { btn = btn, icon = iconName }
			return btn
		end

		local function redrawToolbarIcons()
			for _, spec in ipairs(toolBtns) do
				spec.btn:ClearAllChildren()
				P.corner(spec.btn, 3)
				local ic = icons.codicon(spec.btn, spec.icon, 15, theme.color.sideBarText, 25)
				ic.Position = UDim2.fromOffset(4, 3)
			end
		end

		makeToolBtn("NewFileBtn", "newFile", 1, function()
			if fileTree then fileTree.promptNewFile("") end
		end)
		makeToolBtn("NewFolderBtn", "newFolder", 2, function()
			if fileTree then fileTree.promptNewFolder("") end
		end)
		makeToolBtn("ReloadDiskBtn", "refresh", 3, function()
			fsSync.reloadFromDisk()
			overlay.toast("Synced with local disk", "good", 2)
		end)
		makeToolBtn("SaveAllBtn", "saveAll", 4, function()
			local n = codeStore.saveAll()
			overlay.toast(string.format("Saved %d file(s) to disk", n), "good", 2)
		end)
		redrawToolbarIcons()

		local scroll = P.scroll(root, {
			name = "ExplorerScroll",
			size = UDim2.new(1, 0, 1, -30),
			pos = UDim2.fromOffset(0, 30),
			zIndex = 22,
		})
		P.list(scroll, Enum.FillDirection.Vertical, 2)

		-- Section 1: Open Editors
		local openExpanded = true
		local openHeader = P.button(scroll, {
			name = "OpenEditorsHeader",
			size = UDim2.new(1, 0, 0, 22),
			bg = theme.color.sideBarHeader,
			hoverBg = theme.color.hover,
			text = "",
			order = 1,
			zIndex = 23,
		})
		local openHeaderLbl = P.label(openHeader, {
			size = UDim2.new(1, -12, 1, 0),
			pos = UDim2.fromOffset(8, 0),
			text = "▾ OPEN EDITORS",
			bold = true,
			textSize = 11,
			color = theme.color.sideBarText,
			zIndex = 24,
		})

		local openList = P.frame(scroll, {
			name = "OpenEditorsList",
			size = UDim2.new(1, 0, 0, 0),
			order = 2,
			zIndex = 23,
		})
		openList.AutomaticSize = Enum.AutomaticSize.Y
		P.list(openList, Enum.FillDirection.Vertical, 1)

		-- Section 2: Local Disk Folder
		local wsHeader = P.frame(scroll, {
			size = UDim2.new(1, 0, 0, 22),
			bg = theme.color.sideBarHeader,
			order = 3,
			zIndex = 23,
		})
		local wsHeaderLbl = P.label(wsHeader, {
			size = UDim2.new(1, -12, 1, 0),
			pos = UDim2.fromOffset(8, 0),
			text = "▾ WORKSPACE: " .. workspaceFs.activeName:upper(),
			bold = true,
			textSize = 11,
			color = theme.color.sideBarText,
			truncate = true,
			zIndex = 24,
		})

		local treeWrap = P.frame(scroll, {
			size = UDim2.new(1, 0, 0, 0),
			order = 4,
			zIndex = 23,
		})
		treeWrap.AutomaticSize = Enum.AutomaticSize.Y
		fileTree = explorerTreeMod.new(treeWrap)

		-- Section 3: Roblox Game Explorer
		local gameExpanded = false
		local gameBtn = P.button(scroll, {
			name = "GameTreeToggle",
			size = UDim2.new(1, 0, 0, 22),
			bg = theme.color.sideBarHeader,
			hoverBg = theme.color.hover,
			alignX = Enum.TextXAlignment.Left,
			bold = true,
			textSize = 11,
			color = theme.color.sideBarText,
			text = "  ▸ ROBLOX DATAMODEL",
			order = 5,
			zIndex = 23,
		})
		local gameContainer = P.frame(scroll, {
			size = UDim2.new(1, 0, 0, 0),
			visible = false,
			order = 6,
			zIndex = 23,
		})
		gameContainer.AutomaticSize = Enum.AutomaticSize.Y
		P.list(gameContainer, Enum.FillDirection.Vertical, 1)

		local expandedInstances = {}
		local function renderGameTree()
			gameContainer:ClearAllChildren()
			if not gameExpanded then return end
			P.list(gameContainer, Enum.FillDirection.Vertical, 1)
			local ord = 0

			local function walkInst(inst, _labelName, depth)
				if depth > 5 or ord > 80 then return end
				for _, ch in ipairs(robloxExplorer.childrenOf(inst, 40)) do
					ord = ord + 1
					local row = P.button(gameContainer, {
						size = UDim2.new(1, 0, 0, 21),
						hoverBg = theme.color.hover,
						alignX = Enum.TextXAlignment.Left,
						textSize = 11,
						color = ch.isScript and theme.color.accent or theme.color.sideBarText,
						text = string.rep("   ", depth) .. (ch.isScript and "📜 " or (ch.hasChildren and "▸ " or "  ")) .. ch.name .. " (" .. ch.className .. ")",
						order = ord,
						zIndex = 24,
						onClick = function()
							if ch.isScript then
								decompiler.openInstanceScript(ch.instance, true)
								overlay.toast("Imported " .. ch.name .. " to workspace", "good", 2.5)
							elseif ch.hasChildren then
								expandedInstances[ch.instance] = not expandedInstances[ch.instance]
								renderGameTree()
							end
						end,
					})
					row.TextTruncate = Enum.TextTruncate.AtEnd
					if expandedInstances[ch.instance] then
						walkInst(ch.instance, ch.name, depth + 1)
					end
				end
			end

			for _, rootSvc in ipairs(robloxExplorer.rootServices()) do
				ord = ord + 1
				local svcInst = rootSvc.instance
				P.button(gameContainer, {
					size = UDim2.new(1, 0, 0, 22),
					hoverBg = theme.color.hover,
					alignX = Enum.TextXAlignment.Left,
					bold = true,
					textSize = 11,
					color = theme.color.sideBarText,
					text = "  " .. (expandedInstances[svcInst] and "▾ " or "▸ ") .. rootSvc.name,
					order = ord,
					zIndex = 24,
					onClick = function()
						expandedInstances[svcInst] = not expandedInstances[svcInst]
						renderGameTree()
					end,
				})
				if expandedInstances[svcInst] then
					walkInst(svcInst, rootSvc.name, 2)
				end
			end
		end

		gameBtn.Activated:Connect(function()
			gameExpanded = not gameExpanded
			gameBtn.Text = gameExpanded and "  ▾ ROBLOX DATAMODEL" or "  ▸ ROBLOX DATAMODEL"
			gameContainer.Visible = gameExpanded
			renderGameTree()
		end)

		local function renderOpenEditors()
			openList:ClearAllChildren()
			openList.Visible = openExpanded
			local arrow = openExpanded and "▾" or "▸"
			openHeaderLbl.Text = string.format("%s OPEN EDITORS (%d)", arrow, #codeStore.tabs)
			if not openExpanded then return end

			P.list(openList, Enum.FillDirection.Vertical, 1)
			local activeDoc = codeStore.active()
			for idx, tab in ipairs(codeStore.tabs) do
				local isCur = activeDoc and activeDoc.id == tab.id
				local row = P.button(openList, {
					name = "OpenEditor_" .. tab.title,
					size = UDim2.new(1, 0, 0, 21),
					bg = isCur and theme.color.listActive or nil,
					hoverBg = theme.color.hover,
					text = "",
					order = idx,
					zIndex = 24,
					activeState = function() return isCur end,
					onClick = function() codeStore.activate(tab.id) end,
				})
				P.button(row, {
					name = "CloseOpenEditorBtn",
					size = UDim2.fromOffset(16, 16),
					pos = UDim2.fromOffset(6, 2),
					text = tab.dirty and "●" or "✕",
					textSize = tab.dirty and 10 or 9,
					color = tab.dirty and theme.color.tabActiveText or theme.color.muted,
					radius = 2,
					zIndex = 25,
					onClick = function() codeStore.requestClose(tab.id) end,
				})
				local badge = icons.fileBadge(row, tab.path ~= "" and tab.path or tab.langId, false, 25)
				badge.Position = UDim2.fromOffset(24, 3)
				P.label(row, {
					size = UDim2.new(1, -50, 1, 0),
					pos = UDim2.fromOffset(46, 0),
					text = tab.title,
					textSize = 12,
					color = isCur and theme.color.tabActiveText or theme.color.sideBarText,
					truncate = true,
					zIndex = 25,
				})
			end
		end

		openHeader.Activated:Connect(function()
			openExpanded = not openExpanded
			renderOpenEditors()
		end)

		codeStore.changed:connect(renderOpenEditors)
		workspaceFs.changed:connect(function()
			wsHeaderLbl.Text = "▾ WORKSPACE: " .. workspaceFs.activeName:upper()
		end)
		theme.changed:connect(function()
			openHeader.BackgroundColor3 = theme.color.sideBarHeader
			wsHeader.BackgroundColor3 = theme.color.sideBarHeader
			gameBtn.BackgroundColor3 = theme.color.sideBarHeader
			redrawToolbarIcons()
			renderOpenEditors()
			if gameExpanded then renderGameTree() end
		end)

		renderOpenEditors()
		return {
			root = root,
			fileTree = fileTree,
		}
	end

	return M
end
