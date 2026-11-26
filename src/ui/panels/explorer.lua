-- VS Code Explorer Sidebar Viewlet:
-- Open Editors, Local Disk File Tree (`writefile`/`readfile`), and Live Roblox DataModel
-- Explorer (3D/GUI Eyedropper Picker, Copy Luau Path, Property Inspector & Script Decompiler).
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local icons = env.require("ui/icons")
	local explorerTreeMod = env.require("ui/code/explorer")
	local workspaceFs = env.require("runtime/workspace_fs")
	local codeStore = env.require("runtime/code_store")
	local clipboard = env.require("runtime/clipboard")
	local robloxExplorer = env.require("runtime/roblox_explorer")
	local commands = env.require("runtime/command_catalog")
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
			size = UDim2.new(1, -134, 1, 0),
			pos = UDim2.fromOffset(12, 0),
			text = "EXPLORER",
			bold = true,
			textSize = 11,
			color = theme.color.muted,
			zIndex = 23,
		})

		local toolRow = P.frame(titleRow, {
			size = UDim2.fromOffset(128, 26),
			pos = UDim2.new(1, -132, 0, 2),
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
		P.button(toolRow, {
			name = "BundleProjectBtn",
			size = UDim2.fromOffset(24, 22),
			text = "📦",
			textSize = 12,
			radius = 3,
			order = 5,
			zIndex = 24,
			onClick = function()
				commands.run("workspace.bundle")
			end,
		})
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

		-- Section 3: Roblox Game DataModel Explorer + Eyedropper
		local gameExpanded = false
		local gameHeader = P.frame(scroll, {
			size = UDim2.new(1, 0, 0, 22),
			bg = theme.color.sideBarHeader,
			order = 5,
			zIndex = 23,
		})
		local gameBtn = P.button(gameHeader, {
			name = "GameTreeToggle",
			size = UDim2.new(1, -58, 1, 0),
			hoverBg = theme.color.hover,
			alignX = Enum.TextXAlignment.Left,
			bold = true,
			textSize = 11,
			color = theme.color.sideBarText,
			text = "  ▸ ROBLOX DATAMODEL",
			zIndex = 24,
		})
		P.button(gameHeader, {
			name = "DataModelEyedropperBtn",
			size = UDim2.fromOffset(52, 18),
			pos = UDim2.new(1, -56, 0, 2),
			bg = theme.color.accent,
			hoverBg = theme.color.accentHover,
			color = Color3.fromRGB(255, 255, 255),
			bold = true,
			text = "🎯 Pick",
			textSize = 10,
			radius = 3,
			zIndex = 25,
			onClick = function()
				commands.run("roblox.pickInstance")
			end,
		})

		local gameContainer = P.frame(scroll, {
			size = UDim2.new(1, 0, 0, 0),
			visible = false,
			order = 6,
			zIndex = 23,
		})
		gameContainer.AutomaticSize = Enum.AutomaticSize.Y
		P.list(gameContainer, Enum.FillDirection.Vertical, 1)

		local function openInstanceInspector(inst)
			local props = robloxExplorer.inspectProperties(inst) or {}
			local luauPath = robloxExplorer.luauPathOf(inst)
			local clsName = tostring(inst.ClassName or "Instance")
			local isRemote = (clsName == "RemoteEvent" or clsName == "RemoteFunction" or clsName == "UnreliableRemoteEvent" or clsName == "BindableEvent" or clsName == "BindableFunction")

			local card = overlay.openModal("ExplorerPropTweakerModal", 440, 310)
			P.pad(card, 12, 14, 12, 14)

			P.label(card, {
				size = UDim2.new(1, -28, 0, 20),
				bold = true,
				textSize = 13,
				color = theme.color.tabActiveText,
				text = "🔧 Live Property Tweaker — " .. tostring(inst.Name) .. " (" .. clsName .. ")",
				truncate = true,
				zIndex = 232,
			})
			P.button(card, {
				size = UDim2.fromOffset(24, 22),
				pos = UDim2.new(1, -24, 0, 0),
				text = "✕",
				radius = 4,
				zIndex = 232,
				onClick = function() overlay.closeModal() end,
			})

			P.label(card, {
				size = UDim2.new(1, 0, 0, 16),
				pos = UDim2.fromOffset(0, 22),
				mono = true,
				textSize = 10,
				color = theme.color.accent,
				text = luauPath,
				truncate = true,
				zIndex = 232,
			})

			local propScroll = P.scroll(card, {
				name = "PropTweakerScroll",
				size = UDim2.new(1, 0, 1, -76),
				pos = UDim2.fromOffset(0, 42),
				bg = theme.color.editor,
				zIndex = 232,
			})
			P.pad(propScroll, 6, 6, 6, 6)
			P.list(propScroll, Enum.FillDirection.Vertical, 4)

			for idx, kv in ipairs(props) do
				local pName = tostring(kv.name or kv.key or "")
				local pVal = tostring(kv.value or "")
				local readOnly = (pName == "ClassName" or pName == "Children" or pName == "LuauPath")

				local row = P.frame(propScroll, {
					size = UDim2.new(1, 0, 0, 26),
					order = idx,
					zIndex = 233,
				})
				P.label(row, {
					size = UDim2.fromOffset(118, 26),
					mono = true,
					textSize = 11,
					color = theme.color.sideBarText,
					text = pName,
					truncate = true,
					zIndex = 234,
				})
				if readOnly then
					P.label(row, {
						size = UDim2.new(1, -124, 1, 0),
						pos = UDim2.fromOffset(122, 0),
						mono = true,
						textSize = 11,
						color = theme.color.muted,
						text = pVal,
						truncate = true,
						zIndex = 234,
					})
				else
					local _, vBox = P.input(row, {
						name = "PropInput_" .. pName,
						size = UDim2.new(1, -178, 0, 24),
						pos = UDim2.fromOffset(122, 1),
						mono = true,
						value = pVal,
						zIndex = 234,
					})
					local setBtn = P.button(row, {
						name = "PropApply_" .. pName,
						size = UDim2.fromOffset(50, 24),
						pos = UDim2.new(1, -50, 0, 1),
						bg = theme.color.inputBg,
						hoverBg = theme.color.accent,
						text = "Apply",
						textSize = 10,
						radius = 3,
						zIndex = 234,
						onClick = function()
							local okS, msg = robloxExplorer.setPropertyLive(inst, pName, vBox.Text)
							if okS then
								vBox.Text = tostring(msg)
								overlay.toast("Updated " .. pName .. " = " .. tostring(msg), "good", 1.8)
							else
								overlay.toast("Set failed: " .. tostring(msg), "bad", 2.5)
							end
						end,
					})
					setBtn.BackgroundTransparency = 0
				end
			end

			local foot = P.frame(card, {
				size = UDim2.new(1, 0, 0, 26),
				pos = UDim2.new(0, 0, 1, -26),
				zIndex = 232,
			})
			P.list(foot, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right)

			if isRemote then
				local remBtn = P.button(foot, {
					name = "PropGenRemoteBtn",
					size = UDim2.fromOffset(148, 24),
					bg = theme.color.good,
					color = Color3.fromRGB(16, 24, 20),
					bold = true,
					text = "⚡ Generate Remote Luau",
					textSize = 10,
					radius = 4,
					order = 1,
					zIndex = 233,
					onClick = function()
						local snip = robloxExplorer.generateRemoteSnippet(inst)
						overlay.closeModal()
						local doc = codeStore.newUntitled(snip, "luau")
						doc.title = tostring(inst.Name) .. "_Remote.luau"
						codeStore.changed:fire({ reason = "remoteSnippet", id = doc.id })
					end,
				})
				remBtn.BackgroundTransparency = 0
			end

			local snapBtn = P.button(foot, {
				name = "PropOpenSnapshotTabBtn",
				size = UDim2.fromOffset(132, 24),
				bg = theme.color.accent,
				hoverBg = theme.color.accentHover,
				color = Color3.fromRGB(255, 255, 255),
				bold = true,
				text = "Open in Editor Tab",
				textSize = 10,
				radius = 4,
				order = 2,
				zIndex = 233,
				onClick = function()
					overlay.closeModal()
					local lines = {
						"-- Roblox Instance Inspector",
						"local target = " .. luauPath,
						"local properties = {",
					}
					for _, kv in ipairs(props) do
						lines[#lines + 1] = string.format("\t[%q] = %q,", tostring(kv.name or kv.key), tostring(kv.value))
					end
					lines[#lines + 1] = "}"
					local doc = codeStore.newUntitled(table.concat(lines, "\n"), "luau")
					doc.title = "Inspect: " .. tostring(inst.Name)
					codeStore.changed:fire({ reason = "inspect", id = doc.id })
				end,
			})
			snapBtn.BackgroundTransparency = 0
		end

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
					local row = P.frame(gameContainer, {
						size = UDim2.new(1, 0, 0, 21),
						order = ord,
						zIndex = 24,
					})
					local mainBtn = P.button(row, {
						size = UDim2.new(1, -42, 1, 0),
						hoverBg = theme.color.hover,
						alignX = Enum.TextXAlignment.Left,
						textSize = 11,
						color = ch.isScript and theme.color.accent or theme.color.sideBarText,
						text = string.rep("   ", depth) .. (ch.isScript and "📜 " or (ch.hasChildren and "▸ " or "  ")) .. ch.name .. " (" .. ch.className .. ")",
						zIndex = 25,
						onClick = function()
							if ch.isScript then
								decompiler.openInstanceScript(ch.instance, true)
								overlay.toast("Decompiled & saved " .. ch.name .. " to disk", "good", 2.5)
							elseif ch.hasChildren then
								expandedInstances[ch.instance] = not expandedInstances[ch.instance]
								renderGameTree()
							else
								openInstanceInspector(ch.instance)
							end
						end,
					})
					mainBtn.TextTruncate = Enum.TextTruncate.AtEnd

					-- Copy Luau Path (`📋`)
					P.button(row, {
						name = "CopyPath_" .. ch.name,
						size = UDim2.fromOffset(18, 18),
						pos = UDim2.new(1, -40, 0, 1),
						text = "📋",
						textSize = 10,
						radius = 2,
						zIndex = 26,
						onClick = function()
							local lp = robloxExplorer.luauPathOf(ch.instance)
							clipboard.copy(lp)
							overlay.toast("Copied Luau path: " .. lp, "good", 2.2)
						end,
					})

					-- Inspect Properties (`ℹ`)
					P.button(row, {
						name = "InspectInst_" .. ch.name,
						size = UDim2.fromOffset(18, 18),
						pos = UDim2.new(1, -20, 0, 1),
						text = "ℹ",
						textSize = 10,
						color = theme.color.accent,
						radius = 2,
						zIndex = 26,
						onClick = function()
							openInstanceInspector(ch.instance)
						end,
					})

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
			gameHeader.BackgroundColor3 = theme.color.sideBarHeader
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
