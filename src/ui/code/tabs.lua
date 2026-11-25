-- VS Code Multi-Tab Editor Bar with Seti file badges, dirty dots (`●`) with hover `✕`,
-- pin state, unsaved close prompt, Run (`▶`) button, Save button, and Split Editor button.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local icons = env.require("ui/icons")
	local overlay = env.require("ui/overlay")
	local codeStore = env.require("runtime/code_store")
	local commands = env.require("runtime/command_catalog")
	local clipboard = env.require("runtime/clipboard")

	local M = {}

	function M.new(parent, paneName)
		local pane = paneName or "primary"
		local h = theme.sizes.tabBar

		local root = P.frame(parent, {
			name = "TabBar_" .. pane,
			size = UDim2.new(1, 0, 0, h),
			bg = theme.color.tabBar,
			zIndex = 20,
		})
		local bottomBorder = P.frame(root, {
			size = UDim2.new(1, 0, 0, 1),
			pos = UDim2.new(0, 0, 1, -1),
			bg = theme.color.border,
			zIndex = 21,
		})

		local tabsScroll = P.scroll(root, {
			name = "TabsScroll",
			size = UDim2.new(1, -106, 1, -1),
			direction = Enum.ScrollingDirection.X,
			autoCanvas = Enum.AutomaticSize.X,
			barThickness = 3,
			zIndex = 21,
		})
		P.list(tabsScroll, Enum.FillDirection.Horizontal, 1)

		local actionsBar = P.frame(root, {
			name = "EditorActions",
			size = UDim2.fromOffset(102, h - 1),
			pos = UDim2.new(1, -104, 0, 0),
			zIndex = 22,
		})
		P.list(actionsBar, Enum.FillDirection.Horizontal, 2, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

		P.button(actionsBar, {
			name = "RunTabBtn",
			size = UDim2.fromOffset(30, 26),
			text = "▶",
			bold = true,
			color = theme.color.good,
			radius = 4,
			order = 1,
			zIndex = 23,
			onClick = function() commands.run("run.active") end,
		})

		P.button(actionsBar, {
			name = "SaveTabBtn",
			size = UDim2.fromOffset(34, 26),
			text = "Save",
			textSize = 11,
			color = theme.color.sideBarText,
			radius = 4,
			order = 2,
			zIndex = 23,
			onClick = function() commands.run("file.save") end,
		})

		local splitBtn = P.button(actionsBar, {
			name = "SplitPaneBtn",
			size = UDim2.fromOffset(28, 26),
			text = "⫿",
			textSize = 14,
			color = theme.color.sideBarText,
			radius = 4,
			order = 3,
			zIndex = 23,
			onClick = function() codeStore.toggleSplit() end,
		})

		local function rebuild()
			tabsScroll:ClearAllChildren()
			P.list(tabsScroll, Enum.FillDirection.Horizontal, 1)
			local activeDoc = codeStore.active(pane)
			local activeId = activeDoc and activeDoc.id or nil

			for idx, doc in ipairs(codeStore.tabs) do
				local isCurrent = (doc.id == activeId)
				local tabW = math.max(116, math.min(206, #doc.title * 7 + (doc.pinned and 68 or 58)))
				local tabBtn = P.button(tabsScroll, {
					name = "Tab_" .. doc.title,
					size = UDim2.fromOffset(tabW, h - 1),
					bg = isCurrent and theme.color.tabActive or theme.color.tabInactive,
					hoverBg = isCurrent and theme.color.tabActive or theme.color.hover,
					text = "",
					order = idx,
					zIndex = 22,
					activeState = function() return isCurrent end,
					onClick = function()
						codeStore.activate(doc.id, pane)
					end,
				})
				tabBtn.BackgroundTransparency = root.BackgroundTransparency

				if isCurrent then
					P.frame(tabBtn, {
						name = "ActiveTopAccent",
						size = UDim2.new(1, 0, 0, 2),
						bg = theme.color.tabActiveTop,
						zIndex = 24,
					})
				end

				P.frame(tabBtn, {
					size = UDim2.new(0, 1, 1, 0),
					pos = UDim2.new(1, -1, 0, 0),
					bg = theme.color.border,
					zIndex = 23,
				})

				local badge = icons.fileBadge(tabBtn, doc.path ~= "" and doc.path or doc.langId, false, 23)
				badge.Position = UDim2.fromOffset(8, math.floor((h - 14) / 2))

				local titleX = 31
				if doc.pinned then
					local pinIc = icons.codicon(tabBtn, "pin", 13, theme.color.accent, 23)
					pinIc.Position = UDim2.fromOffset(29, math.floor((h - 13) / 2))
					titleX = 44
				end

				P.label(tabBtn, {
					size = UDim2.new(1, -(titleX + 28), 1, 0),
					pos = UDim2.fromOffset(titleX, 0),
					text = doc.title,
					textSize = 12,
					color = isCurrent and theme.color.tabActiveText or theme.color.tabInactiveText,
					truncate = true,
					zIndex = 23,
				})

				local restingGlyph = doc.dirty and "●" or (doc.pinned and "•" or "✕")
				local closeOrDot = P.button(tabBtn, {
					name = "CloseTabBtn",
					size = UDim2.fromOffset(20, 20),
					pos = UDim2.new(1, -24, 0.5, -10),
					text = restingGlyph,
					textSize = doc.dirty and 12 or 11,
					color = doc.dirty and theme.color.tabActiveText or theme.color.muted,
					radius = 3,
					zIndex = 24,
					onClick = function()
						if doc.pinned then
							codeStore.togglePin(doc.id)
						else
							codeStore.requestClose(doc.id)
						end
					end,
				})
				closeOrDot.Active = true
				if doc.dirty and not doc.pinned then
					closeOrDot.MouseEnter:Connect(function()
						closeOrDot.Text = "✕"
						closeOrDot.TextSize = 11
					end)
					closeOrDot.MouseLeave:Connect(function()
						closeOrDot.Text = "●"
						closeOrDot.TextSize = 12
					end)
				end

				tabBtn.MouseButton2Click:Connect(function()
					local p = tabBtn.AbsolutePosition
					local menu = {
						{ label = doc.pinned and "Unpin Tab" or "Pin Tab", onClick = function() codeStore.togglePin(doc.id) end },
						{ label = "Save to Local Disk", shortcut = "Ctrl+S", onClick = function() codeStore.save(doc.id) end },
					}
					if doc.path and doc.path ~= "" then
						menu[#menu + 1] = {
							label = "Copy Relative Path",
							onClick = function()
								clipboard.copy(doc.path)
								overlay.toast("Copied: " .. doc.path, "info", 1.8)
							end,
						}
						if not doc.untitled then
							menu[#menu + 1] = {
								label = "Split Editor Right",
								onClick = function() codeStore.openFile(doc.path, { pane = "secondary" }) end,
							}
						end
					end
					menu[#menu + 1] = { separator = true }
					menu[#menu + 1] = { label = "Close", shortcut = "Ctrl+W", onClick = function() codeStore.requestClose(doc.id) end }
					menu[#menu + 1] = { label = "Close Others", onClick = function() codeStore.closeOthers(doc.id) end }
					menu[#menu + 1] = { label = "Close to the Right", onClick = function() codeStore.closeToRight(doc.id) end }
					menu[#menu + 1] = { label = "Close Saved", onClick = function() codeStore.closeSaved() end }
					menu[#menu + 1] = { label = "Close All Clean Tabs", onClick = function() codeStore.closeAll() end }
					overlay.dropdown(p.X, p.Y + h, menu, 196)
				end)
			end
		end

		codeStore.changed:connect(rebuild)
		theme.changed:connect(function()
			root.BackgroundColor3 = theme.color.tabBar
			bottomBorder.BackgroundColor3 = theme.color.border
			splitBtn.TextColor3 = theme.color.sideBarText
			rebuild()
		end)

		rebuild()
		return {
			root = root,
			refresh = rebuild,
			setTransparency = function(bgTrans)
				root.BackgroundTransparency = bgTrans
				rebuild()
			end,
		}
	end

	return M
end
