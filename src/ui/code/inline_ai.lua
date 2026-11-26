-- VS Code `Ctrl+I` Floating Inline AI Edit Bar (`src/ui/code/inline_ai.lua`).
-- Anchors directly inside the active code editor so players can generate or refactor code
-- at their cursor/selection with `[✓ Accept]`, `[◫ Diff]`, and `[✕ Discard]` before committing!
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local overlay = env.require("ui/overlay")
	local codeStore = env.require("runtime/code_store")
	local providers = env.require("ai/providers")
	local agentLoop = env.require("ai/agent_loop")
	local util = env.require("runtime/util")

	local M = {}

	function M.new(editorParent, getEditorBox)
		local proposedText = nil
		local replaceRange = nil -- `{ s = number, e = number }` or nil for full/cursor

		local root = P.frame(editorParent, {
			name = "InlineAiBar",
			size = UDim2.new(1, -28, 0, 40),
			pos = UDim2.fromOffset(14, 8),
			bg = theme.color.sideBar,
			radius = 6,
			border = theme.color.accent,
			clip = true,
			visible = false,
			active = true,
			zIndex = 65,
		})
		P.pad(root, 6, 8, 6, 8)

		local _, inputBox = P.input(root, {
			name = "InlineAiInput",
			size = UDim2.new(1, -124, 0, 26),
			pos = UDim2.fromOffset(0, 0),
			placeholder = "✦ Ask AI to edit selection or generate code at cursor...",
			zIndex = 66,
		})

		local genBtn = P.button(root, {
			name = "InlineAiGenerateBtn",
			size = UDim2.fromOffset(82, 26),
			pos = UDim2.new(1, -114, 0, 0),
			bg = theme.color.accent,
			hoverBg = theme.color.accentHover,
			color = Color3.fromRGB(255, 255, 255),
			bold = true,
			text = "✦ Generate",
			textSize = 11,
			radius = 4,
			zIndex = 66,
		})
		genBtn.BackgroundTransparency = 0

		P.button(root, {
			name = "InlineAiCloseBtn",
			size = UDim2.fromOffset(26, 26),
			pos = UDim2.new(1, -26, 0, 0),
			hoverBg = theme.color.hover,
			text = "✕",
			textSize = 11,
			radius = 4,
			zIndex = 66,
			onClick = function()
				root.Visible = false
				proposedText = nil
			end,
		})

		local previewBox = P.label(root, {
			name = "InlineAiPreviewLabel",
			size = UDim2.new(1, 0, 0, 72),
			pos = UDim2.fromOffset(0, 32),
			bg = theme.color.editor,
			mono = true,
			wrap = true,
			alignY = Enum.TextYAlignment.Top,
			textSize = 11,
			color = theme.color.good,
			text = "",
			visible = false,
			zIndex = 66,
		})
		previewBox.BackgroundTransparency = 0.15

		local reviewRow = P.frame(root, {
			name = "InlineAiReviewRow",
			size = UDim2.new(1, 0, 0, 24),
			pos = UDim2.fromOffset(0, 108),
			visible = false,
			zIndex = 66,
		})
		P.list(reviewRow, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right)

		local discardBtn = P.button(reviewRow, {
			name = "InlineAiDiscardBtn",
			size = UDim2.fromOffset(74, 22),
			bg = theme.color.inputBg,
			hoverBg = theme.color.bad,
			text = "✕ Discard",
			textSize = 10,
			radius = 4,
			order = 1,
			zIndex = 67,
			onClick = function()
				proposedText = nil
				previewBox.Visible = false
				reviewRow.Visible = false
				root.Size = UDim2.new(1, -28, 0, 40)
			end,
		})
		discardBtn.BackgroundTransparency = 0

		local diffBtn = P.button(reviewRow, {
			name = "InlineAiDiffBtn",
			size = UDim2.fromOffset(72, 22),
			bg = theme.color.inputBg,
			hoverBg = theme.color.hover,
			text = "◫ Diff",
			textSize = 10,
			radius = 4,
			order = 2,
			zIndex = 67,
			onClick = function()
				if not proposedText then return end
				local doc = codeStore.active("primary")
				if not doc then return end
				local fullAfter = proposedText
				if replaceRange then
					fullAfter = doc.content:sub(1, replaceRange.s - 1) .. proposedText .. doc.content:sub(replaceRange.e)
				end
				codeStore.openDiff(doc.path or doc.title, doc.content, fullAfter)
			end,
		})
		diffBtn.BackgroundTransparency = 0

		local acceptBtn = P.button(reviewRow, {
			name = "InlineAiAcceptBtn",
			size = UDim2.fromOffset(82, 22),
			bg = theme.color.good,
			color = Color3.fromRGB(16, 24, 20),
			bold = true,
			text = "✓ Accept",
			textSize = 10,
			radius = 4,
			order = 3,
			zIndex = 67,
			onClick = function()
				if not proposedText then return end
				local doc = codeStore.active("primary")
				if doc then
					local nextContent = proposedText
					if replaceRange then
						nextContent = doc.content:sub(1, replaceRange.s - 1) .. proposedText .. doc.content:sub(replaceRange.e)
					end
					codeStore.updateContent(doc.id, nextContent)
					overlay.toast("✓ Accepted inline AI edit", "good", 2)
				end
				proposedText = nil
				previewBox.Visible = false
				reviewRow.Visible = false
				root.Size = UDim2.new(1, -28, 0, 40)
				root.Visible = false
			end,
		})
		acceptBtn.BackgroundTransparency = 0

		local function runInlineGenerate()
			local instruction = util.trim(inputBox.Text)
			if instruction == "" then return end

			local doc = codeStore.active("primary")
			local box = getEditorBox and getEditorBox() or nil
			local selText = ""
			replaceRange = nil

			if doc and box then
				local cPos = tonumber(box.CursorPosition) or 1
				local sPos = tonumber(box.SelectionStart) or -1
				if sPos > 0 and sPos ~= cPos then
					local lo = math.min(sPos, cPos)
					local hi = math.max(sPos, cPos)
					selText = doc.content:sub(lo, hi - 1)
					replaceRange = { s = lo, e = hi }
				elseif cPos > 0 and cPos <= #doc.content + 1 then
					replaceRange = { s = cPos, e = cPos }
				end
			end

			genBtn.Text = "..."
			local sysPrompt = "Return ONLY a ```luau fenced code block implementing the user's inline edit or generation request."
			local userPayload = selText ~= ""
				and ("Target selection:\n```luau\n" .. selText .. "\n```\n\nInstruction: " .. instruction)
				or ("Active file:\n```luau\n" .. tostring(doc and doc.content or ""):sub(1, 4000) .. "\n```\n\nInstruction: " .. instruction)

			local resp, err = providers.complete({
				messages = {
					{ role = "system", content = sysPrompt },
					{ role = "user", content = userPayload },
				},
				activeCode = selText ~= "" and selText or (doc and doc.content or ""),
			})
			genBtn.Text = "✦ Generate"

			if not resp then
				overlay.toast("Inline AI error: " .. tostring(err), "bad", 3)
				return
			end

			local extracted = resp.codeBlock or agentLoop.extractFirstCodeBlock(resp.content) or resp.content
			proposedText = util.trim(tostring(extracted or ""))
			previewBox.Text = proposedText
			previewBox.Visible = true
			reviewRow.Visible = true
			root.Size = UDim2.new(1, -28, 0, 142)
		end

		genBtn.MouseButton1Click:Connect(runInlineGenerate)

		return {
			root = root,
			inputBox = inputBox,
			open = function(prefill)
				root.Visible = true
				if type(prefill) == "string" and prefill ~= "" then
					inputBox.Text = prefill
				end
				pcall(function() inputBox:CaptureFocus() end)
			end,
			close = function()
				root.Visible = false
			end,
			toggle = function()
				root.Visible = not root.Visible
				if root.Visible then
					pcall(function() inputBox:CaptureFocus() end)
				end
				return root.Visible
			end,
			generate = runInlineGenerate,
		}
	end

	return M
end
