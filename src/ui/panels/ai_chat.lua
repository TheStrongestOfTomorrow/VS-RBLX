-- VS Code-Style Integrated AI Secondary Sidebar (`src/ui/panels/ai_chat.lua`).
-- 100% original VS-RBLX UI modelled after VS Code's Secondary AI Chat & Diff Review panel.
-- Multi-provider (Smart Luau zero-key, OpenAI, Anthropic, OpenRouter, DeepSeek, Custom),
-- Vault-encrypted API keys, `#file` / `#problems` / `#remotes` context chips,
-- 3-mode Permission Gate (`Ask First` / `Auto` / `Read Only`), and 1-click Diff / Apply!
-- Agent loop & tool engineering inspired by Project UAI (MIT © CarlDV / Project-Ptolemy).
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local overlay = env.require("ui/overlay")
	local config = env.require("runtime/config")
	local codeStore = env.require("runtime/code_store")
	local clipboard = env.require("runtime/clipboard")
	local cryptoVault = env.require("runtime/crypto_vault")
	local commands = env.require("runtime/command_catalog")
	local providers = env.require("ai/providers")
	local agentLoop = env.require("ai/agent_loop")

	local M = {}

	local function openApiKeyModal(onSaved)
		local p = providers.getProvider()
		local card = overlay.openModal("AiProviderKeyModal", 440, 228)
		P.pad(card, 12, 14, 12, 14)

		P.label(card, {
			size = UDim2.new(1, -28, 0, 20),
			text = "🔑 AI Provider & Endpoint Settings",
			bold = true,
			textSize = 13,
			color = theme.color.tabActiveText,
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

		local vaultNote = cryptoVault.isEncrypted()
			and (cryptoVault.isUnlocked() and "🔓 Stored inside Zero-Knowledge Master Vault (`vault.enc`)." or "🔒 Master Vault is LOCKED — unlock via 🔐 first to save keys.")
			or "Stored locally (click 🔐 in Topbar anytime to enable Zero-Knowledge Vault encryption)."

		P.label(card, {
			size = UDim2.new(1, 0, 0, 18),
			pos = UDim2.fromOffset(0, 24),
			text = "Provider: " .. p.name .. "  ·  Model: " .. providers.activeModel(),
			textSize = 11,
			color = theme.color.accent,
			truncate = true,
			zIndex = 232,
		})
		P.label(card, {
			size = UDim2.new(1, 0, 0, 18),
			pos = UDim2.fromOffset(0, 42),
			text = vaultNote,
			textSize = 10,
			color = theme.color.muted,
			truncate = true,
			zIndex = 232,
		})

		local _, keyBox = P.input(card, {
			name = "AiApiKeyInput",
			size = UDim2.new(1, 0, 0, 28),
			pos = UDim2.fromOffset(0, 68),
			mono = true,
			value = providers.getApiKey(p.id),
			placeholder = p.requiresKey and ("sk-... (" .. p.name .. " API Key)") or "Optional API key (not required for this mode)",
			zIndex = 232,
		})

		local _, endpointBox = P.input(card, {
			name = "AiCustomEndpointInput",
			size = UDim2.new(1, -138, 0, 26),
			pos = UDim2.fromOffset(0, 104),
			mono = true,
			value = tostring(config.get("ai.customEndpoint", "http://127.0.0.1:11434/v1/chat/completions")),
			placeholder = "Custom OpenAI URL (when Custom selected)",
			zIndex = 232,
		})
		local _, modelBox = P.input(card, {
			name = "AiCustomModelInput",
			size = UDim2.fromOffset(132, 26),
			pos = UDim2.new(1, -132, 0, 104),
			mono = true,
			value = providers.activeModel(),
			placeholder = "Model ID",
			zIndex = 232,
		})

		local statusLbl = P.label(card, {
			size = UDim2.new(1, 0, 0, 18),
			pos = UDim2.fromOffset(0, 136),
			text = "",
			textSize = 11,
			color = theme.color.bad,
			truncate = true,
			zIndex = 232,
		})

		local btnRow = P.frame(card, {
			size = UDim2.new(1, 0, 0, 28),
			pos = UDim2.new(0, 0, 1, -28),
			zIndex = 232,
		})
		P.list(btnRow, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right)

		if cryptoVault.isEncrypted() and not cryptoVault.isUnlocked() then
			local unlockBtn = P.button(btnRow, {
				size = UDim2.fromOffset(118, 26),
				bg = theme.color.warn,
				color = Color3.fromRGB(20, 20, 20),
				bold = true,
				text = "🔒 Unlock Vault",
				textSize = 11,
				radius = 4,
				order = 1,
				zIndex = 233,
				onClick = function()
					commands.run("vault.open")
				end,
			})
			unlockBtn.BackgroundTransparency = 0
		end

		local saveBtn = P.button(btnRow, {
			name = "AiSaveKeyBtn",
			size = UDim2.fromOffset(128, 26),
			bg = theme.color.accent,
			hoverBg = theme.color.accentHover,
			color = Color3.fromRGB(255, 255, 255),
			bold = true,
			text = "Save AI Settings",
			textSize = 11,
			radius = 4,
			order = 2,
			zIndex = 233,
			onClick = function()
				config.set("ai.customEndpoint", endpointBox.Text, { quiet = true })
				config.set("ai.model", modelBox.Text, { immediate = true })
				if keyBox.Text ~= "" or not cryptoVault.isEncrypted() then
					local okK, errK = providers.setApiKey(p.id, keyBox.Text)
					if not okK then
						statusLbl.Text = tostring(errK)
						return
					end
				end
				overlay.closeModal()
				if onSaved then onSaved() end
				overlay.toast("Saved AI settings (" .. p.name .. " · " .. modelBox.Text .. ")", "good", 2.4)
			end,
		})
		saveBtn.BackgroundTransparency = 0
	end

	function M.new(parent, callbacks)
		callbacks = callbacks or {}
		local attachFile = true
		local attachProblems = false
		local attachRemotes = false

		local root = P.frame(parent, {
			name = "AIChatSidebar",
			size = UDim2.fromScale(1, 1),
			bg = theme.color.sideBar,
			clip = true,
			visible = false,
			zIndex = 20,
		})
		local leftBorder = P.frame(root, {
			size = UDim2.new(0, 1, 1, 0),
			bg = theme.color.border,
			zIndex = 24,
		})

		-- Top VS Code Secondary Sidebar Header
		local header = P.frame(root, {
			name = "AIChatHeader",
			size = UDim2.new(1, -1, 0, 30),
			pos = UDim2.fromOffset(1, 0),
			bg = theme.color.sideBarHeader,
			zIndex = 21,
		})
		P.label(header, {
			size = UDim2.new(1, -96, 1, 0),
			pos = UDim2.fromOffset(10, 0),
			text = "✦ INTEGRATED AI",
			bold = true,
			textSize = 11,
			color = theme.color.tabActiveText,
			truncate = true,
			zIndex = 22,
		})

		local hdrBtns = P.frame(header, {
			size = UDim2.fromOffset(90, 30),
			pos = UDim2.new(1, -92, 0, 0),
			zIndex = 22,
		})
		P.list(hdrBtns, Enum.FillDirection.Horizontal, 2, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

		local keyBtn = P.button(hdrBtns, {
			name = "AiApiKeyBtn",
			size = UDim2.fromOffset(34, 22),
			bg = theme.color.inputBg,
			hoverBg = theme.color.hover,
			text = "🔑",
			textSize = 11,
			radius = 4,
			order = 1,
			zIndex = 23,
		})
		keyBtn.BackgroundTransparency = 0

		P.button(hdrBtns, {
			name = "AiNewChatBtn",
			size = UDim2.fromOffset(24, 22),
			hoverBg = theme.color.hover,
			text = "＋",
			bold = true,
			textSize = 12,
			radius = 4,
			order = 2,
			zIndex = 23,
			onClick = function()
				agentLoop.clearHistory()
			end,
		})

		P.button(hdrBtns, {
			name = "AiCloseSidebarBtn",
			size = UDim2.fromOffset(24, 22),
			hoverBg = theme.color.hover,
			text = "✕",
			textSize = 11,
			radius = 4,
			order = 3,
			zIndex = 23,
			onClick = function()
				if callbacks.onClose then callbacks.onClose() end
			end,
		})

		-- Provider & Model Selector Bar
		local providerBar = P.frame(root, {
			size = UDim2.new(1, -12, 0, 24),
			pos = UDim2.fromOffset(6, 33),
			zIndex = 21,
		})
		local providerBtn = P.button(providerBar, {
			name = "AiProviderBtn",
			size = UDim2.new(1, 0, 1, 0),
			bg = theme.color.inputBg,
			hoverBg = theme.color.hover,
			alignX = Enum.TextXAlignment.Left,
			mono = true,
			textSize = 10,
			color = theme.color.sideBarText,
			text = "",
			radius = 4,
			border = theme.color.inputBorder,
			zIndex = 22,
		})
		providerBtn.BackgroundTransparency = 0

		local function refreshProviderLabel()
			local p = providers.getProvider()
			providerBtn.Text = string.format("  ▾ %s · %s", p.name, providers.activeModel())
		end

		providerBtn.MouseButton1Click:Connect(function()
			local items = {}
			for _, p in ipairs(providers.CATALOG) do
				for _, modName in ipairs(p.models) do
					local pid, mName, pLabel = p.id, modName, p.name
					items[#items + 1] = {
						label = pLabel .. " — " .. mName,
						shortcut = p.requiresKey and "API Key" or "Free/Local",
						onClick = function()
							providers.setProvider(pid, mName)
							refreshProviderLabel()
						end,
					}
				end
			end
			items[#items + 1] = { separator = true }
			items[#items + 1] = {
				label = "🔑 Configure API Key / Custom Endpoint...",
				onClick = function() openApiKeyModal(refreshProviderLabel) end,
			}
			local pos = providerBtn.AbsolutePosition
			overlay.dropdown(pos.X, pos.Y + 26, items, 260)
		end)
		keyBtn.MouseButton1Click:Connect(function()
			openApiKeyModal(refreshProviderLabel)
		end)

		-- Context Chips Strip (`#file`, `#problems`, `#remotes`, `Ctrl+I Inline`)
		local ctxRow = P.frame(root, {
			name = "AiContextStrip",
			size = UDim2.new(1, -12, 0, 22),
			pos = UDim2.fromOffset(6, 60),
			zIndex = 21,
		})
		P.list(ctxRow, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

		local function makeCtxChip(name, label, initOn, onToggle)
			local btn = P.button(ctxRow, {
				name = name,
				size = UDim2.fromOffset(#label * 6 + 12, 20),
				bg = initOn and theme.color.accent or theme.color.inputBg,
				hoverBg = theme.color.hover,
				color = initOn and Color3.fromRGB(255, 255, 255) or theme.color.muted,
				bold = true,
				text = label,
				textSize = 10,
				radius = 10,
				zIndex = 22,
			})
			btn.BackgroundTransparency = 0
			btn.MouseButton1Click:Connect(function()
				local nextState = onToggle()
				btn.BackgroundColor3 = nextState and theme.color.accent or theme.color.inputBg
				btn.TextColor3 = nextState and Color3.fromRGB(255, 255, 255) or theme.color.muted
			end)
			return btn
		end

		makeCtxChip("AiCtxFileBtn", "#file", attachFile, function()
			attachFile = not attachFile
			return attachFile
		end)
		makeCtxChip("AiCtxProblemsBtn", "#problems", attachProblems, function()
			attachProblems = not attachProblems
			return attachProblems
		end)
		makeCtxChip("AiCtxRemotesBtn", "#remotes", attachRemotes, function()
			attachRemotes = not attachRemotes
			return attachRemotes
		end)
		local inlineOpenBtn = P.button(ctxRow, {
			name = "AiTriggerInlineBtn",
			size = UDim2.fromOffset(66, 20),
			bg = theme.color.inputBg,
			hoverBg = theme.color.hover,
			color = theme.color.tabActiveText,
			bold = true,
			text = "✦ Ctrl+I",
			textSize = 10,
			radius = 10,
			zIndex = 22,
			onClick = function()
				commands.run("ai.inlineEdit")
			end,
		})
		inlineOpenBtn.BackgroundTransparency = 0

		-- Chat Transcript Scroll
		local transcript = P.scroll(root, {
			name = "AiTranscriptScroll",
			size = UDim2.new(1, -10, 1, -184),
			pos = UDim2.fromOffset(5, 86),
			zIndex = 21,
		})
		P.pad(transcript, 4, 4, 8, 4)
		P.list(transcript, Enum.FillDirection.Vertical, 6)

		-- Bottom Composer + Permission Chip + Project UAI Credit Footer
		local footer = P.frame(root, {
			name = "AiComposerFooter",
			size = UDim2.new(1, -10, 0, 94),
			pos = UDim2.new(0, 5, 1, -96),
			bg = theme.color.sideBar,
			zIndex = 22,
		})

		local inputWrap, promptBox = P.input(footer, {
			name = "AiPromptInput",
			size = UDim2.new(1, 0, 0, 44),
			pos = UDim2.fromOffset(0, 0),
			multiline = true,
			placeholder = "Ask AI to write, refactor, or inspect Roblox... (Ctrl+I for inline edit)",
			zIndex = 23,
		})
		inputWrap.Size = UDim2.new(1, 0, 0, 44)

		local permLabels = {
			ask_first = "🛡 Ask First",
			auto = "⚡ Auto Edit",
			read_only = "👁 Read Only",
		}
		local permChip = P.button(footer, {
			name = "AiPermissionChip",
			size = UDim2.fromOffset(92, 22),
			pos = UDim2.fromOffset(0, 48),
			bg = theme.color.inputBg,
			hoverBg = theme.color.hover,
			bold = true,
			textSize = 10,
			color = theme.color.tabActiveText,
			text = permLabels[agentLoop.permissionMode()] or "🛡 Ask First",
			radius = 4,
			zIndex = 23,
			onClick = function()
				local m = agentLoop.cyclePermissionMode()
				overlay.toast("AI Permission Mode -> " .. (permLabels[m] or m), "info", 1.8)
			end,
		})
		permChip.BackgroundTransparency = 0

		local sendBtn = P.button(footer, {
			name = "AiSendBtn",
			size = UDim2.fromOffset(72, 22),
			pos = UDim2.new(1, -72, 0, 48),
			bg = theme.color.accent,
			hoverBg = theme.color.accentHover,
			color = Color3.fromRGB(255, 255, 255),
			bold = true,
			text = "Send ➤",
			textSize = 11,
			radius = 4,
			zIndex = 23,
		})
		sendBtn.BackgroundTransparency = 0

		-- Explicit Non-Copyrighted Open-Source Engineering Credit
		P.label(footer, {
			name = "AiAttributionLabel",
			size = UDim2.new(1, 0, 0, 18),
			pos = UDim2.fromOffset(0, 74),
			textSize = 9,
			color = theme.color.muted,
			truncate = true,
			text = "VS-RBLX AI · Agent loop inspired by Project UAI (MIT © CarlDV / Project-Ptolemy)",
			zIndex = 23,
		})

		local function applyCodeToActiveEditor(code)
			local doc = codeStore.active("primary")
			if not doc then
				doc = codeStore.newUntitled(code, "luau")
			else
				codeStore.updateContent(doc.id, code)
			end
			overlay.toast("✓ Applied AI code to " .. tostring(doc.title), "good", 2.2)
		end

		local function previewCodeDiff(code)
			local doc = codeStore.active("primary")
			local before = doc and doc.content or ""
			local name = doc and (doc.path or doc.title) or "AI_Proposal.luau"
			codeStore.openDiff(name, before, code)
		end

		local function renderMessages()
			transcript:ClearAllChildren()
			P.pad(transcript, 4, 4, 8, 4)
			P.list(transcript, Enum.FillDirection.Vertical, 6)

			permChip.Text = permLabels[agentLoop.permissionMode()] or "🛡 Ask First"
			sendBtn.Text = agentLoop.busy and "■ Stop" or "Send ➤"
			sendBtn.BackgroundColor3 = agentLoop.busy and theme.color.bad or theme.color.accent

			if #agentLoop.messages == 0 and not agentLoop.pendingApproval then
				local welcome = P.frame(transcript, {
					name = "AiWelcomeCard",
					size = UDim2.new(1, 0, 0, 124),
					bg = theme.color.inputBg,
					radius = 5,
					border = theme.color.border,
					order = 1,
					zIndex = 22,
				})
				P.pad(welcome, 8, 10, 8, 10)
				P.label(welcome, {
					size = UDim2.new(1, 0, 0, 18),
					bold = true,
					textSize = 12,
					color = theme.color.tabActiveText,
					text = "✦ VS-RBLX Integrated AI Editor",
					zIndex = 23,
				})
				P.label(welcome, {
					size = UDim2.new(1, 0, 0, 62),
					pos = UDim2.fromOffset(0, 20),
					wrap = true,
					alignY = Enum.TextYAlignment.Top,
					textSize = 11,
					color = theme.color.muted,
					text = "• Press Ctrl+I inside any file for inline code edits & diff preview.\n• Works immediately in Smart Luau mode, or click 🔑 to connect OpenAI, Claude, DeepSeek, or OpenRouter.\n• Inspired by Project UAI's MIT agent architecture.",
					zIndex = 23,
				})
				local quickRow = P.frame(welcome, {
					size = UDim2.new(1, 0, 0, 22),
					pos = UDim2.new(0, 0, 1, -22),
					zIndex = 23,
				})
				P.list(quickRow, Enum.FillDirection.Horizontal, 4)
				for idx, qPrompt in ipairs({ "Wrap active code in pcall", "Generate RemoteEvent snippet" }) do
					local qp = qPrompt
					local qb = P.button(quickRow, {
						size = UDim2.fromOffset(#qp * 5 + 18, 20),
						bg = theme.color.editor,
						hoverBg = theme.color.hover,
						text = qp,
						textSize = 10,
						color = theme.color.accent,
						radius = 4,
						order = idx,
						zIndex = 24,
						onClick = function()
							task.spawn(function()
								agentLoop.send(qp, {
									attachActiveFile = attachFile,
									attachProblems = attachProblems,
									attachRemotes = attachRemotes,
								})
							end)
						end,
					})
					qb.BackgroundTransparency = 0
				end
				return
			end

			for idx, msg in ipairs(agentLoop.messages) do
				if msg.role == "tool" then
					local pill = P.label(transcript, {
						name = "AiToolEvent_" .. tostring(idx),
						size = UDim2.new(1, 0, 0, 18),
						mono = true,
						textSize = 10,
						color = msg.ok and theme.color.good or theme.color.warn,
						text = "  ⚙ " .. tostring(msg.text),
						truncate = true,
						order = idx,
						zIndex = 22,
					})
					pill.BackgroundTransparency = 1
				else
					local isUser = (msg.role == "user")
					local isErr = (msg.role == "error")
					local textLines = 1
					for _ in tostring(msg.text or ""):gmatch("\n") do textLines = textLines + 1 end
					local estH = math.min(240, math.max(38, textLines * 15 + math.floor(#tostring(msg.text or "") / 36) * 14 + 26))
					local hasCode = type(msg.codeBlock) == "string" and msg.codeBlock ~= ""
					local totalH = estH + (hasCode and 28 or 0)

					local card = P.frame(transcript, {
						name = "AiMsgCard_" .. tostring(idx),
						size = UDim2.new(1, 0, 0, totalH),
						bg = isUser and theme.color.editor or theme.color.inputBg,
						radius = 5,
						border = isErr and theme.color.bad or (isUser and theme.color.accent or theme.color.border),
						order = idx,
						zIndex = 22,
					})
					P.pad(card, 6, 8, 6, 8)

					P.label(card, {
						size = UDim2.new(1, 0, 0, 14),
						bold = true,
						textSize = 10,
						color = isUser and theme.color.accent or (isErr and theme.color.bad or theme.color.good),
						text = isUser and "YOU" or (isErr and "AI ERROR" or "✦ VS-RBLX AI"),
						zIndex = 23,
					})

					P.label(card, {
						size = UDim2.new(1, 0, 0, estH - 22),
						pos = UDim2.fromOffset(0, 16),
						wrap = true,
						alignY = Enum.TextYAlignment.Top,
						mono = hasCode,
						textSize = 11,
						color = theme.color.tabActiveText,
						text = tostring(msg.text or ""),
						zIndex = 23,
					})

					if hasCode then
						local codeStr = msg.codeBlock
						local actRow = P.frame(card, {
							size = UDim2.new(1, 0, 0, 22),
							pos = UDim2.new(0, 0, 1, -22),
							zIndex = 23,
						})
						P.list(actRow, Enum.FillDirection.Horizontal, 4)

						local applyBtn = P.button(actRow, {
							name = "AiApplyCodeBtn_" .. tostring(idx),
							size = UDim2.fromOffset(68, 20),
							bg = theme.color.accent,
							hoverBg = theme.color.accentHover,
							color = Color3.fromRGB(255, 255, 255),
							bold = true,
							text = "✓ Apply",
							textSize = 10,
							radius = 3,
							order = 1,
							zIndex = 24,
							onClick = function() applyCodeToActiveEditor(codeStr) end,
						})
						applyBtn.BackgroundTransparency = 0

						local diffBtn = P.button(actRow, {
							name = "AiDiffCodeBtn_" .. tostring(idx),
							size = UDim2.fromOffset(64, 20),
							bg = theme.color.editor,
							hoverBg = theme.color.hover,
							text = "◫ Diff",
							textSize = 10,
							color = theme.color.sideBarText,
							radius = 3,
							order = 2,
							zIndex = 24,
							onClick = function() previewCodeDiff(codeStr) end,
						})
						diffBtn.BackgroundTransparency = 0

						local copyBtn = P.button(actRow, {
							size = UDim2.fromOffset(58, 20),
							bg = theme.color.editor,
							hoverBg = theme.color.hover,
							text = "📋 Copy",
							textSize = 10,
							color = theme.color.sideBarText,
							radius = 3,
							order = 3,
							zIndex = 24,
							onClick = function()
								clipboard.copy(codeStr)
								overlay.toast("Copied AI code block to clipboard", "good", 1.8)
							end,
						})
						copyBtn.BackgroundTransparency = 0
					end
				end
			end

			-- Interactive Ask-First Permission Approval Card
			if agentLoop.pendingApproval then
				local pa = agentLoop.pendingApproval
				local appCard = P.frame(transcript, {
					name = "AiApprovalCard",
					size = UDim2.new(1, 0, 0, 74),
					bg = theme.color.editor,
					radius = 5,
					border = theme.color.warn,
					order = 999,
					zIndex = 23,
				})
				P.pad(appCard, 6, 8, 6, 8)
				P.label(appCard, {
					size = UDim2.new(1, 0, 0, 34),
					wrap = true,
					textSize = 11,
					color = theme.color.warn,
					text = "🛡 Permission Requested: " .. tostring(pa.summary),
					zIndex = 24,
				})
				local bRow = P.frame(appCard, {
					size = UDim2.new(1, 0, 0, 22),
					pos = UDim2.new(0, 0, 1, -22),
					zIndex = 24,
				})
				P.list(bRow, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right)
				local denyB = P.button(bRow, {
					name = "AiDenyToolBtn",
					size = UDim2.fromOffset(64, 20),
					bg = theme.color.inputBg,
					hoverBg = theme.color.bad,
					text = "✕ Deny",
					textSize = 10,
					radius = 3,
					order = 1,
					zIndex = 25,
					onClick = function()
						if pa.resolve then pa.resolve(false) end
					end,
				})
				denyB.BackgroundTransparency = 0
				local allowB = P.button(bRow, {
					name = "AiApproveToolBtn",
					size = UDim2.fromOffset(72, 20),
					bg = theme.color.good,
					color = Color3.fromRGB(16, 24, 20),
					bold = true,
					text = "✓ Allow",
					textSize = 10,
					radius = 3,
					order = 2,
					zIndex = 25,
					onClick = function()
						if pa.resolve then pa.resolve(true) end
					end,
				})
				allowB.BackgroundTransparency = 0
			end
		end

		local function submitPrompt()
			if agentLoop.busy then
				agentLoop.cancel()
				return
			end
			local txt = promptBox.Text
			if txt == nil or txt:match("^%s*$") then return end
			promptBox.Text = ""
			task.spawn(function()
				agentLoop.send(txt, {
					attachActiveFile = attachFile,
					attachProblems = attachProblems,
					attachRemotes = attachRemotes,
				})
			end)
		end

		sendBtn.MouseButton1Click:Connect(submitPrompt)
		agentLoop.changed:connect(renderMessages)
		theme.changed:connect(function()
			root.BackgroundColor3 = theme.color.sideBar
			leftBorder.BackgroundColor3 = theme.color.border
			header.BackgroundColor3 = theme.color.sideBarHeader
			footer.BackgroundColor3 = theme.color.sideBar
			refreshProviderLabel()
			renderMessages()
		end)

		refreshProviderLabel()
		renderMessages()

		return {
			root = root,
			promptBox = promptBox,
			refresh = renderMessages,
			openKeyModal = function() openApiKeyModal(refreshProviderLabel) end,
			setTransparency = function(bgTrans)
				root.BackgroundTransparency = bgTrans
				header.BackgroundTransparency = bgTrans
				footer.BackgroundTransparency = bgTrans
			end,
		}
	end

	return M
end
