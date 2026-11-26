-- VS Code Multi-Tab Editor Bar (`src/ui/code/tabs.lua`):
-- Seti file badges, dirty dots (`●`) with hover `✕`, pin state, unsaved close prompt,
-- Language-Gated `◫ Preview` (`Open Preview to the Side` — shown ONLY on previewable
-- languages, omitted on non-preview languages), Run (`▶`), Save, Split, and `40px` Touch Mode.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local icons = env.require("ui/icons")
	local overlay = env.require("ui/overlay")
	local languages = env.require("runtime/languages")
	local codeStore = env.require("runtime/code_store")
	local commands = env.require("runtime/command_catalog")
	local clipboard = env.require("runtime/clipboard")

	local M = {}

	function M.new(parent, paneName)
		local pane = paneName or "primary"
		local h = theme.sizes.tabBar
		local mobileMode = false

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
			size = UDim2.new(1, -244, 1, -1),
			direction = Enum.ScrollingDirection.X,
			autoCanvas = Enum.AutomaticSize.X,
			barThickness = 3,
			zIndex = 21,
		})
		P.list(tabsScroll, Enum.FillDirection.Horizontal, 1)

		local actionsBar = P.frame(root, {
			name = "EditorActions",
			size = UDim2.fromOffset(240, h - 1),
			pos = UDim2.new(1, -242, 0, 0),
			zIndex = 22,
		})
		P.list(actionsBar, Enum.FillDirection.Horizontal, 2, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

		-- Multi-Tab Overflow Controls (`‹`, `›`, `+`, and `▾ N` Open Tabs Switcher!)
		local scrollLeftBtn = P.button(actionsBar, {
			name = "ScrollTabsLeftBtn",
			size = UDim2.fromOffset(20, 24),
			text = "‹",
			bold = true,
			textSize = 14,
			color = theme.color.muted,
			radius = 4,
			order = -4,
			zIndex = 23,
			onClick = function()
				local cx = tabsScroll.CanvasPosition.X
				tabsScroll.CanvasPosition = Vector2.new(math.max(0, cx - 150), 0)
			end,
		})

		local scrollRightBtn = P.button(actionsBar, {
			name = "ScrollTabsRightBtn",
			size = UDim2.fromOffset(20, 24),
			text = "›",
			bold = true,
			textSize = 14,
			color = theme.color.muted,
			radius = 4,
			order = -3,
			zIndex = 23,
			onClick = function()
				local cx = tabsScroll.CanvasPosition.X
				tabsScroll.CanvasPosition = Vector2.new(cx + 150, 0)
			end,
		})

		local newTabBtn = P.button(actionsBar, {
			name = "NewTabBtn",
			size = UDim2.fromOffset(22, 24),
			text = "+",
			bold = true,
			textSize = 13,
			color = theme.color.tabActiveText,
			radius = 4,
			order = -2,
			zIndex = 23,
			onClick = function()
				commands.run("file.newUntitled")
			end,
		})

		local allTabsBtn = P.button(actionsBar, {
			name = "AllOpenTabsBtn",
			size = UDim2.fromOffset(36, 24),
			bg = theme.color.inputBg,
			hoverBg = theme.color.hover,
			text = "▾ 1",
			mono = true,
			bold = true,
			textSize = 10,
			color = theme.color.tabActiveText,
			radius = 4,
			order = -1,
			zIndex = 23,
			onClick = function()
				local items = {
					{ label = "＋ New Untitled Tab", shortcut = "Ctrl+N", onClick = function() commands.run("file.newUntitled") end },
					{ separator = true },
				}
				local curActive = codeStore.active(pane)
				local curId = curActive and curActive.id or nil
				for idx, d in ipairs(codeStore.tabs) do
					local prefix = (d.id == curId) and "● " or "   "
					local dirtySuffix = d.dirty and " *" or ""
					items[#items + 1] = {
						label = string.format("%s%d. %s%s", prefix, idx, d.title, dirtySuffix),
						shortcut = d.langId or "",
						onClick = function()
							codeStore.activate(d.id, pane)
						end,
					}
				end
				items[#items + 1] = { separator = true }
				items[#items + 1] = { label = "Close Saved Tabs", onClick = function() codeStore.closeSaved() end }
				items[#items + 1] = { label = "Close All Clean Tabs", onClick = function() codeStore.closeAll() end }
				local p = actionsBar.AbsolutePosition
				overlay.dropdown(p.X, p.Y + h, items, 240)
			end,
		})
		allTabsBtn.BackgroundTransparency = 0.25

		-- Language-gated Live Split Preview button (strictly hidden on non-previewable languages!)
		local previewBtn = P.button(actionsBar, {
			name = "OpenPreviewBtn_" .. pane,
			size = UDim2.fromOffset(66, 26),
			bg = theme.color.accent,
			hoverBg = theme.color.accentHover,
			color = Color3.fromRGB(255, 255, 255),
			bold = true,
			text = "◫ Preview",
			textSize = 11,
			radius = 4,
			visible = false,
			order = 1,
			zIndex = 23,
			onClick = function()
				commands.run("preview.openToSide")
			end,
		})
		previewBtn.BackgroundTransparency = 0

		local runBtn = P.button(actionsBar, {
			name = "RunTabBtn",
			size = UDim2.fromOffset(28, 26),
			text = "▶",
			bold = true,
			color = theme.color.good,
			radius = 4,
			order = 2,
			zIndex = 23,
			onClick = function() commands.run("run.active") end,
		})

		local saveBtn = P.button(actionsBar, {
			name = "SaveTabBtn",
			size = UDim2.fromOffset(34, 26),
			text = "Save",
			textSize = 11,
			color = theme.color.sideBarText,
			radius = 4,
			order = 3,
			zIndex = 23,
			onClick = function() commands.run("file.save") end,
		})

		local splitBtn = P.button(actionsBar, {
			name = "SplitPaneBtn",
			size = UDim2.fromOffset(26, 26),
			text = "⫿",
			textSize = 14,
			color = theme.color.sideBarText,
			radius = 4,
			order = 4,
			zIndex = 23,
			onClick = function() codeStore.toggleSplit() end,
		})

		local currentBarW = 800

		local function rebuild()
			root.Size = UDim2.new(1, 0, 0, h)
			local compact = currentBarW < 520
			local totalTabs = #codeStore.tabs
			allTabsBtn.Text = "▾ " .. tostring(totalTabs)

			-- Show `‹ ›` scroll arrows when 3+ tabs are open and width allows
			local showArrows = (totalTabs >= 3) and (not compact)
			scrollLeftBtn.Visible = showArrows
			scrollRightBtn.Visible = showArrows
			saveBtn.Visible = not compact
			splitBtn.Visible = not compact
			previewBtn.Size = UDim2.fromOffset(compact and 30 or 64, 26)
			previewBtn.Text = compact and "◫" or "◫ Preview"

			local actW = compact and 136 or (showArrows and 254 or 210)
			actionsBar.Size = UDim2.fromOffset(actW, h - 1)
			actionsBar.Position = UDim2.new(1, -(actW + 2), 0, 0)
			tabsScroll.Size = UDim2.new(1, -(actW + 6), 1, -1)

			local activeDoc = codeStore.active(pane)
			local activeId = activeDoc and activeDoc.id or nil
			local canPrev = (pane == "primary") and (activeDoc ~= nil) and languages.isPreviewable(activeDoc)
			previewBtn.Visible = canPrev
			local actionW = canPrev and 180 or 108
			tabsScroll.Size = UDim2.new(1, -actionW, 1, -1)

			local btnH = mobileMode and 32 or 26
			previewBtn.Size = UDim2.fromOffset(68, btnH)
			runBtn.Size = UDim2.fromOffset(mobileMode and 34 or 30, btnH)
			saveBtn.Size = UDim2.fromOffset(mobileMode and 40 or 36, btnH)
			splitBtn.Size = UDim2.fromOffset(mobileMode and 32 or 28, btnH)

			tabsScroll:ClearAllChildren()
			P.list(tabsScroll, Enum.FillDirection.Horizontal, 1)

			for idx, doc in ipairs(codeStore.tabs) do
				local isCurrent = (doc.id == activeId)
				local minTabW = mobileMode and 132 or 116
				local tabW = math.max(minTabW, math.min(216, #doc.title * 7 + (doc.pinned and 72 or 62)))
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
						size = UDim2.new(1, 0, 0, mobileMode and 3 or 2),
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

				local closeSize = mobileMode and 26 or 20
				P.label(tabBtn, {
					size = UDim2.new(1, -(titleX + closeSize + 8), 1, 0),
					pos = UDim2.fromOffset(titleX, 0),
					text = doc.title,
					textSize = mobileMode and 13 or 12,
					color = isCurrent and theme.color.tabActiveText or theme.color.tabInactiveText,
					truncate = true,
					zIndex = 23,
				})

				local restingGlyph = doc.dirty and "●" or (doc.pinned and "•" or "✕")
				local closeOrDot = P.button(tabBtn, {
					name = "CloseTabBtn",
					size = UDim2.fromOffset(closeSize, closeSize),
					pos = UDim2.new(1, -(closeSize + 4), 0.5, -math.floor(closeSize * 0.5)),
					text = restingGlyph,
					textSize = doc.dirty and 12 or 11,
					color = doc.dirty and theme.color.tabActiveText or theme.color.muted,
					radius = 4,
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
					if languages.isPreviewable(doc) then
						menu[#menu + 1] = {
							label = "◫ Open Preview to the Side",
							onClick = function()
								codeStore.activate(doc.id, "primary")
								commands.run("preview.openToSide")
							end,
						}
					end
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
					overlay.dropdown(p.X, p.Y + h, menu, 210)
				end)
			end
		end

		codeStore.changed:connect(rebuild)
		theme.changed:connect(function()
			root.BackgroundColor3 = theme.color.tabBar
			bottomBorder.BackgroundColor3 = theme.color.border
			previewBtn.BackgroundColor3 = theme.color.accent
			splitBtn.TextColor3 = theme.color.sideBarText
			rebuild()
		end)

		rebuild()
		return {
			root = root,
			previewButton = previewBtn,
			allTabsButton = allTabsBtn,
			refresh = rebuild,
			reflow = function(barW)
				currentBarW = tonumber(barW) or currentBarW
				rebuild()
			end,
			height = function() return h end,
			setMobileMode = function(flag)
				mobileMode = flag == true
				h = mobileMode and 42 or theme.sizes.tabBar
				rebuild()
			end,
			setTransparency = function(bgTrans)
				root.BackgroundTransparency = bgTrans
				rebuild()
			end,
		}
	end

	return M
end
