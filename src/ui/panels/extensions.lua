-- VS Code Extensions, Locked 5-Template Community Extension Hub, Malware Scanner & Capabilities Viewlet (`Ctrl+Shift+X`).
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local icons = env.require("ui/icons")
	local caps = env.require("runtime/caps")
	local languages = env.require("runtime/languages")
	local extensionHub = env.require("runtime/extension_hub")
	local clipboard = env.require("runtime/clipboard")
	local codeStore = env.require("runtime/code_store")
	local commands = env.require("runtime/command_catalog")
	local util = env.require("runtime/util")
	local overlay = env.require("ui/overlay")

	local M = {}

	function M.new(parent)
		local activeSubTab = "hub" -- `"hub"` | `"scanner"` | `"system"`
		local scannerText = util.jsonEncode(extensionHub.STARTER_CATALOG[1]) or "{}"
		local lastScanResult = extensionHub.scanSubmission(scannerText)

		local root = P.frame(parent, {
			name = "ExtensionsViewlet",
			size = UDim2.fromScale(1, 1),
			visible = false,
			zIndex = 21,
		})
		P.pad(root, 6, 8, 6, 8)

		P.label(root, {
			size = UDim2.new(1, 0, 0, 20),
			text = "EXTENSIONS & SECURITY HUB",
			bold = true,
			textSize = 11,
			color = theme.color.muted,
			zIndex = 22,
		})

		local tabStrip = P.frame(root, {
			name = "ExtensionsSubTabs",
			size = UDim2.new(1, 0, 0, 26),
			pos = UDim2.fromOffset(0, 22),
			zIndex = 22,
		})
		P.list(tabStrip, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left)

		local scroll = P.scroll(root, {
			name = "ExtensionsScroll",
			size = UDim2.new(1, 0, 1, -54),
			pos = UDim2.fromOffset(0, 52),
			zIndex = 22,
		})
		P.list(scroll, Enum.FillDirection.Vertical, 5)

		local tabButtons = {}
		local renderView

		local SUB_TABS = {
			{ id = "hub", label = "📦 Hub" },
			{ id = "scanner", label = "🛡 Scanner" },
			{ id = "system", label = "⚙ Host & Themes" },
		}
		for idx, st in ipairs(SUB_TABS) do
			local b = P.button(tabStrip, {
				name = "ExtTab_" .. st.id,
				size = UDim2.fromOffset(#st.label * 6 + 14, 24),
				bg = (st.id == activeSubTab) and theme.color.accent or theme.color.inputBg,
				hoverBg = theme.color.hover,
				color = (st.id == activeSubTab) and Color3.fromRGB(255, 255, 255) or theme.color.sideBarText,
				bold = true,
				text = st.label,
				textSize = 11,
				radius = 4,
				order = idx,
				zIndex = 23,
				onClick = function()
					activeSubTab = st.id
					renderView()
				end,
			})
			b.BackgroundTransparency = 0
			tabButtons[st.id] = b
		end

		local function renderExtensionCard(ord, item)
			local scan = item.scan or extensionHub.scanSubmission(item.manifest or {})
			local manifest = scan.manifest or item.manifest or {}
			local extId = tostring(manifest.id or ("issue-" .. tostring(item.issueNumber or ord)))
			local tmplInfo = extensionHub.ALLOWED_TEMPLATES[tostring(manifest.template or "")]
			local isInst = scan.ok and extensionHub.isInstalled(extId)

			local card = P.frame(scroll, {
				name = "ExtCard_" .. extId,
				size = UDim2.new(1, 0, 0, 86),
				bg = theme.color.inputBg,
				radius = 5,
				border = scan.ok and theme.color.border or theme.color.bad,
				order = ord,
				zIndex = 23,
			})
			P.pad(card, 6, 8, 6, 8)

			P.label(card, {
				size = UDim2.new(1, -78, 0, 16),
				bold = true,
				textSize = 12,
				color = theme.color.tabActiveText,
				text = tostring(manifest.name or item.title or extId),
				truncate = true,
				zIndex = 24,
			})

			-- Security Verdict Badge (`🛡 CLEAN` vs `⛔ BLOCKED`)
			P.label(card, {
				name = "ExtScanBadge_" .. extId,
				size = UDim2.fromOffset(74, 16),
				pos = UDim2.new(1, -74, 0, 0),
				bold = true,
				mono = true,
				textSize = 10,
				alignX = Enum.TextXAlignment.Right,
				color = scan.ok and theme.color.good or theme.color.bad,
				text = scan.ok and "🛡 CLEAN" or "⛔ BLOCKED",
				zIndex = 24,
			})

			local metaLine = string.format(
				"%s  ·  v%s  ·  @%s%s",
				tmplInfo and tmplInfo.badge or "⛔ INVALID",
				tostring(manifest.version or "0.0.0"),
				tostring(manifest.author or item.author or "community"),
				item.issueNumber and (" (#" .. tostring(item.issueNumber) .. ")") or ""
			)
			P.label(card, {
				size = UDim2.new(1, 0, 0, 14),
				pos = UDim2.fromOffset(0, 17),
				mono = true,
				textSize = 10,
				color = theme.color.accent,
				text = metaLine,
				truncate = true,
				zIndex = 24,
			})

			local summaryStr = scan.ok
				and tostring(manifest.summary or "")
				or ("Blocked: " .. tostring((scan.findings and scan.findings[1]) or "Failed template/malware verification"))
			P.label(card, {
				size = UDim2.new(1, 0, 0, 18),
				pos = UDim2.fromOffset(0, 32),
				textSize = 10,
				color = scan.ok and theme.color.muted or theme.color.bad,
				text = summaryStr,
				truncate = true,
				zIndex = 24,
			})

			local actions = P.frame(card, {
				size = UDim2.new(1, 0, 0, 22),
				pos = UDim2.new(0, 0, 1, -22),
				zIndex = 24,
			})
			P.list(actions, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left)

			if scan.ok then
				local installBtn = P.button(actions, {
					name = (isInst and "ExtUninstallBtn_" or "ExtInstallBtn_") .. extId,
					size = UDim2.fromOffset(74, 20),
					bg = isInst and theme.color.hover or theme.color.accent,
					hoverBg = isInst and theme.color.bad or theme.color.accentHover,
					color = Color3.fromRGB(255, 255, 255),
					bold = true,
					text = isInst and "Uninstall" or "Install",
					textSize = 10,
					radius = 3,
					order = 1,
					zIndex = 25,
					onClick = function()
						if isInst then
							extensionHub.uninstall(extId)
							overlay.toast("Uninstalled " .. tostring(manifest.name), "info", 2)
						else
							local okI, errOrMan = extensionHub.install(manifest)
							if okI then
								overlay.toast("🛡 Verified & installed: " .. tostring(manifest.name), "good", 2.4)
								if manifest.template == "theme-pack" then
									local tid = "ext_" .. extId:gsub("[^%w_]", "_")
									theme.apply(tid)
								end
							else
								overlay.toast(tostring(errOrMan), "bad", 3)
							end
						end
					end,
				})
				installBtn.BackgroundTransparency = 0
			end

			local inspectBtn = P.button(actions, {
				name = "ExtInspectBtn_" .. extId,
				size = UDim2.fromOffset(66, 20),
				bg = theme.color.sideBar,
				hoverBg = theme.color.hover,
				text = "Inspect",
				textSize = 10,
				radius = 3,
				order = 2,
				zIndex = 25,
				onClick = function()
					local body = util.jsonEncode(manifest) or "{}"
					codeStore.openVirtualTab("ext_" .. extId, extId .. ".json", body, "json", true)
				end,
			})
			inspectBtn.BackgroundTransparency = 0
		end

		renderView = function()
			for tid, btn in pairs(tabButtons) do
				local on = (tid == activeSubTab)
				btn.BackgroundColor3 = on and theme.color.accent or theme.color.inputBg
				btn.TextColor3 = on and Color3.fromRGB(255, 255, 255) or theme.color.sideBarText
			end

			scroll:ClearAllChildren()
			P.list(scroll, Enum.FillDirection.Vertical, 5)
			local ord = 0

			local function addSection(title)
				ord = ord + 1
				P.label(scroll, {
					size = UDim2.new(1, 0, 0, 20),
					bold = true,
					textSize = 11,
					color = theme.color.tabActiveText,
					text = "▾ " .. title,
					order = ord,
					zIndex = 23,
				})
			end

			if activeSubTab == "hub" then
				-- Sync Header Banner
				ord = ord + 1
				local syncCard = P.frame(scroll, {
					name = "HubSyncBanner",
					size = UDim2.new(1, 0, 0, 56),
					bg = theme.color.sideBarHeader,
					radius = 5,
					border = theme.color.border,
					order = ord,
					zIndex = 23,
				})
				P.pad(syncCard, 6, 8, 6, 8)
				P.label(syncCard, {
					size = UDim2.new(1, 0, 0, 18),
					text = "🛡 Locked 5-Template GitHub Issues Hub",
					bold = true,
					textSize = 11,
					color = theme.color.good,
					truncate = true,
					zIndex = 24,
				})
				local syncBtn = P.button(syncCard, {
					name = "SyncGitHubExtensionsBtn",
					size = UDim2.new(1, 0, 0, 22),
					pos = UDim2.fromOffset(0, 22),
					bg = theme.color.accent,
					hoverBg = theme.color.accentHover,
					color = Color3.fromRGB(255, 255, 255),
					bold = true,
					text = "↻ Sync Community Extensions (GitHub Issues)",
					textSize = 10,
					radius = 4,
					zIndex = 24,
					onClick = function()
						local list, err = extensionHub.syncFromGitHub()
						if not list then
							overlay.toast("Hub sync failed: " .. tostring(err), "bad", 3)
						else
							overlay.toast(string.format("Scanned %d GitHub Issue extension(s)", #list), "good", 2.4)
						end
					end,
				})
				syncBtn.BackgroundTransparency = 0

				-- Installed Quick-Tools Bar (`toolbar-tool` extensions)
				local activeTools = extensionHub.listActiveToolbarTools()
				if #activeTools > 0 then
					addSection(string.format("ACTIVE QUICK-TOOLS (%d)", #activeTools))
					for _, tl in ipairs(activeTools) do
						ord = ord + 1
						local tb = P.button(scroll, {
							name = "RunExtTool_" .. tl.commandId,
							size = UDim2.new(1, 0, 0, 24),
							bg = theme.color.inputBg,
							hoverBg = theme.color.accent,
							alignX = Enum.TextXAlignment.Left,
							text = "  🛠 " .. tl.label .. "  (" .. tl.extName .. ")",
							textSize = 11,
							radius = 4,
							order = ord,
							zIndex = 23,
							onClick = function()
								commands.run(tl.commandId)
								overlay.toast("Applied tool: " .. tl.label, "good", 1.8)
							end,
						})
						tb.BackgroundTransparency = 0
					end
				end

				-- Live Synced GitHub Issues Extensions
				if #extensionHub.remoteCatalog > 0 then
					addSection(string.format("GITHUB ISSUES COMMUNITY FEED (%d)", #extensionHub.remoteCatalog))
					for _, rem in ipairs(extensionHub.remoteCatalog) do
						ord = ord + 1
						renderExtensionCard(ord, rem)
					end
				end

				-- Verified Official 5-Template Starter Packs
				addSection("OFFICIAL VERIFIED 5-TEMPLATE PACKS (5)")
				for _, starter in ipairs(extensionHub.STARTER_CATALOG) do
					ord = ord + 1
					renderExtensionCard(ord, {
						manifest = starter,
						scan = extensionHub.scanSubmission(starter),
						author = starter.author,
					})
				end

			elseif activeSubTab == "scanner" then
				addSection("GENERATE ALLOWED TEMPLATE MANIFEST")
				ord = ord + 1
				local genRow = P.frame(scroll, {
					size = UDim2.new(1, 0, 0, 52),
					zIndex = 23,
					order = ord,
				})
				P.list(genRow, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left)
				for idx, tmplId in ipairs(extensionHub.TEMPLATE_LIST) do
					if idx <= 3 then
						local gb = P.button(genRow, {
							name = "GenTemplate_" .. tmplId,
							size = UDim2.fromOffset(72, 22),
							bg = theme.color.inputBg,
							hoverBg = theme.color.hover,
							text = tmplId:gsub("%-pack$", ""):gsub("%-preset$", ""),
							mono = true,
							textSize = 10,
							radius = 3,
							order = idx,
							zIndex = 24,
							onClick = function()
								local sample = extensionHub.generateSampleManifest(tmplId)
								scannerText = util.jsonEncode(sample) or "{}"
								lastScanResult = extensionHub.scanSubmission(scannerText)
								renderView()
							end,
						})
						gb.BackgroundTransparency = 0
					end
				end
				ord = ord + 1
				local genRow2 = P.frame(scroll, {
					size = UDim2.new(1, 0, 0, 24),
					pos = UDim2.fromOffset(0, 0),
					zIndex = 23,
					order = ord,
				})
				P.list(genRow2, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left)
				for idx = 4, #extensionHub.TEMPLATE_LIST do
					local tmplId = extensionHub.TEMPLATE_LIST[idx]
					local gb = P.button(genRow2, {
						name = "GenTemplate_" .. tmplId,
						size = UDim2.fromOffset(96, 22),
						bg = theme.color.inputBg,
						hoverBg = theme.color.hover,
						text = tmplId,
						mono = true,
						textSize = 10,
						radius = 3,
						order = idx,
						zIndex = 24,
						onClick = function()
							local sample = extensionHub.generateSampleManifest(tmplId)
							scannerText = util.jsonEncode(sample) or "{}"
							lastScanResult = extensionHub.scanSubmission(scannerText)
							renderView()
						end,
					})
					gb.BackgroundTransparency = 0
				end

				addSection("CLIENT MALWARE & SCHEMA SCANNER")
				ord = ord + 1
				local boxWrap = P.frame(scroll, {
					size = UDim2.new(1, 0, 0, 96),
					bg = theme.color.inputBg,
					radius = 4,
					border = theme.color.border,
					order = ord,
					zIndex = 23,
				})
				local payloadBox = Instance.new("TextBox", boxWrap)
				payloadBox.Name = "ScannerPayloadInput"
				payloadBox.Size = UDim2.new(1, -10, 1, -8)
				payloadBox.Position = UDim2.fromOffset(5, 4)
				payloadBox.BackgroundTransparency = 1
				payloadBox.BorderSizePixel = 0
				payloadBox.MultiLine = true
				payloadBox.ClearTextOnFocus = false
				payloadBox.TextWrapped = true
				payloadBox.Font = theme.font.mono
				payloadBox.TextSize = 10
				payloadBox.TextColor3 = theme.color.editorText
				payloadBox.TextXAlignment = Enum.TextXAlignment.Left
				payloadBox.TextYAlignment = Enum.TextYAlignment.Top
				payloadBox.Text = scannerText
				payloadBox.ZIndex = 24

				payloadBox:GetPropertyChangedSignal("Text"):Connect(function()
					scannerText = payloadBox.Text
				end)

				ord = ord + 1
				local btnBar = P.frame(scroll, {
					size = UDim2.new(1, 0, 0, 24),
					order = ord,
					zIndex = 23,
				})
				P.list(btnBar, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left)

				local runScanBtn = P.button(btnBar, {
					name = "RunMalwareScanBtn",
					size = UDim2.fromOffset(66, 22),
					bg = theme.color.accent,
					hoverBg = theme.color.accentHover,
					color = Color3.fromRGB(255, 255, 255),
					bold = true,
					text = "🛡 Scan",
					textSize = 10,
					radius = 3,
					order = 1,
					zIndex = 24,
					onClick = function()
						lastScanResult = extensionHub.scanSubmission(scannerText)
						renderView()
					end,
				})
				runScanBtn.BackgroundTransparency = 0

				local instCustomBtn = P.button(btnBar, {
					name = "InstallScannedPayloadBtn",
					size = UDim2.fromOffset(68, 22),
					bg = theme.color.good,
					hoverBg = theme.color.accent,
					color = Color3.fromRGB(16, 24, 20),
					bold = true,
					text = "Install",
					textSize = 10,
					radius = 3,
					order = 2,
					zIndex = 24,
					onClick = function()
						local okI, msg = extensionHub.install(scannerText)
						lastScanResult = extensionHub.scanSubmission(scannerText)
						if okI then
							overlay.toast("🛡 Installed verified extension!", "good", 2.4)
						else
							overlay.toast(tostring(msg), "bad", 3.2)
						end
						renderView()
					end,
				})
				instCustomBtn.BackgroundTransparency = 0

				local copyIssueBtn = P.button(btnBar, {
					name = "CopyGitHubIssueMarkdownBtn",
					size = UDim2.fromOffset(82, 22),
					bg = theme.color.inputBg,
					hoverBg = theme.color.hover,
					text = "Copy Issue MD",
					textSize = 10,
					radius = 3,
					order = 3,
					zIndex = 24,
					onClick = function()
						local sc = extensionHub.scanSubmission(scannerText)
						if not sc.ok or not sc.manifest then
							overlay.toast("Fix scanner errors before copying Issue Markdown", "warn", 2.5)
							return
						end
						local md = extensionHub.generateIssueMarkdown(sc.manifest)
						clipboard.copy(md)
						overlay.toast("Copied GitHub Issue Form Markdown to clipboard!", "good", 2.5)
					end,
				})
				copyIssueBtn.BackgroundTransparency = 0

				-- Scan Verdict Card
				ord = ord + 1
				local resCard = P.frame(scroll, {
					name = "MalwareScanVerdictCard",
					size = UDim2.new(1, 0, 0, 74),
					bg = theme.color.sideBarHeader,
					radius = 4,
					border = lastScanResult.ok and theme.color.good or theme.color.bad,
					order = ord,
					zIndex = 23,
				})
				P.pad(resCard, 6, 8, 6, 8)
				P.label(resCard, {
					name = "MalwareScanVerdictTitle",
					size = UDim2.new(1, 0, 0, 16),
					bold = true,
					textSize = 11,
					color = lastScanResult.ok and theme.color.good or theme.color.bad,
					text = lastScanResult.ok
						and ("🛡 VERIFIED CLEAN — Template `" .. tostring(lastScanResult.manifest.template) .. "`")
						or string.format("⛔ BLOCKED (%d security/schema violation(s))", #(lastScanResult.findings or {})),
					truncate = true,
					zIndex = 24,
				})
				P.label(resCard, {
					name = "MalwareScanVerdictDetail",
					size = UDim2.new(1, 0, 0, 44),
					pos = UDim2.fromOffset(0, 18),
					wrap = true,
					textSize = 10,
					alignY = Enum.TextYAlignment.Top,
					color = theme.color.sideBarText,
					text = lastScanResult.ok
						and "Zero executable code, webhooks, obfuscators, or disallowed fields detected."
						or table.concat(lastScanResult.findings or {}, " | "),
					zIndex = 24,
				})

			else
				-- 1. Executor Capabilities
				addSection("EXECUTOR HOST CAPABILITIES (" .. caps.executor .. ")")
				local capRows = {
					{ name = "Local Disk File Read/Write", detail = "writefile / readfile", ok = caps.has("fs") },
					{ name = "Local Disk Folder Tree", detail = "listfiles / makefolder", ok = caps.has("fsTree") },
					{ name = "GitHub HTTP Request API", detail = tostring(caps.requestName or caps.http), ok = caps.has("httpRequest") or caps.has("httpGet") },
					{ name = "Luau Compiler & Runner", detail = "loadstring", ok = caps.has("loadstring") },
					{ name = "System Clipboard", detail = "setclipboard", ok = caps.has("clipboard") },
					{ name = "Instance Script Decompiler", detail = "decompile", ok = caps.has("decompile") },
				}
				for _, c in ipairs(capRows) do
					ord = ord + 1
					local card = P.frame(scroll, {
						size = UDim2.new(1, 0, 0, 34),
						bg = theme.color.inputBg,
						radius = 4,
						order = ord,
						zIndex = 23,
					})
					P.label(card, {
						size = UDim2.new(1, -66, 0, 18),
						pos = UDim2.fromOffset(8, 2),
						bold = true,
						textSize = 11,
						color = theme.color.tabActiveText,
						text = c.name,
						truncate = true,
						zIndex = 24,
					})
					P.label(card, {
						size = UDim2.new(1, -66, 0, 14),
						pos = UDim2.fromOffset(8, 18),
						mono = true,
						textSize = 10,
						color = theme.color.muted,
						text = c.detail,
						zIndex = 24,
					})
					P.label(card, {
						size = UDim2.fromOffset(56, 34),
						pos = UDim2.new(1, -60, 0, 0),
						bold = true,
						textSize = 10,
						alignX = Enum.TextXAlignment.Right,
						color = c.ok and theme.color.good or theme.color.warn,
						text = c.ok and "ACTIVE" or "FALLBACK",
						zIndex = 24,
					})
				end

				-- 2. Installed Color Themes (Built-in + Community Theme Packs!)
				local allThemes = theme.list()
				addSection(string.format("INSTALLED COLOR THEMES (%d)", #allThemes))
				for _, t in ipairs(allThemes) do
					ord = ord + 1
					local themeId = t.id
					P.button(scroll, {
						name = "ApplyThemeBtn_" .. themeId,
						size = UDim2.new(1, 0, 0, 26),
						bg = theme.color.inputBg,
						hoverBg = theme.color.listActive,
						alignX = Enum.TextXAlignment.Left,
						textSize = 12,
						color = theme.color.sideBarText,
						text = "  🎨  " .. t.label,
						radius = 4,
						order = ord,
						zIndex = 23,
						onClick = function()
							theme.apply(themeId)
							overlay.toast("Applied theme: " .. t.label, "good", 2)
						end,
					})
				end

				-- 3. Built-in Multi-Language Support
				addSection(string.format("BUILT-IN LANGUAGE MODES (%d)", #languages.list))
				for _, lang in ipairs(languages.list) do
					ord = ord + 1
					local row = P.frame(scroll, {
						size = UDim2.new(1, 0, 0, 26),
						bg = theme.color.inputBg,
						radius = 4,
						order = ord,
						zIndex = 23,
					})
					local b = icons.fileBadge(row, lang, false, 24)
					b.Position = UDim2.fromOffset(6, 6)
					local extLabel = (#(lang.extensions or {}) > 0) and ("  (." .. table.concat(lang.extensions, ", .") .. ")") or ""
					P.label(row, {
						size = UDim2.new(1, -44, 1, 0),
						pos = UDim2.fromOffset(36, 0),
						textSize = 11,
						color = theme.color.sideBarText,
						text = lang.name .. extLabel,
						truncate = true,
						zIndex = 24,
					})
				end
			end
		end

		extensionHub.changed:connect(renderView)
		theme.changed:connect(renderView)
		renderView()

		return {
			root = root,
			refresh = renderView,
		}
	end

	return M
end
