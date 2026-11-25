-- Acode-Inspired Mobile Quick-Keys Bar & Play-While-Coding Strip (`src/ui/mobile_bar.lua`):
-- Provides 1-tap touch access to programming symbols (`Tab`, `{`, `}`, `(`, `)`, `[`, `]`,
-- `"`, `'`, `=`, `.`, `:`, `,`, `;`, `_`, `+`, `-`, `<`, `>`), Undo/Redo, Play+Code split-peek,
-- and Run (`▶`) so mobile/Android players can code smoothly on touch screens.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local commands = env.require("runtime/command_catalog")

	local M = {}

	local KEYS = {
		{ id = "tab", label = "⇥ Tab", width = 50, insert = "\t" },
		{ id = "lbrace", label = "{", width = 32, insert = "{" },
		{ id = "rbrace", label = "}", width = 32, insert = "}" },
		{ id = "lparen", label = "(", width = 32, insert = "(" },
		{ id = "rparen", label = ")", width = 32, insert = ")" },
		{ id = "lbrack", label = "[", width = 32, insert = "[" },
		{ id = "rbrack", label = "]", width = 32, insert = "]" },
		{ id = "dquote", label = '"', width = 32, insert = '"' },
		{ id = "squote", label = "'", width = 32, insert = "'" },
		{ id = "eq", label = "=", width = 32, insert = "=" },
		{ id = "dot", label = ".", width = 30, insert = "." },
		{ id = "colon", label = ":", width = 30, insert = ":" },
		{ id = "comma", label = ",", width = 30, insert = "," },
		{ id = "semi", label = ";", width = 30, insert = ";" },
		{ id = "under", label = "_", width = 32, insert = "_" },
		{ id = "minus", label = "-", width = 32, insert = "-" },
		{ id = "plus", label = "+", width = 32, insert = "+" },
		{ id = "lt", label = "<", width = 32, insert = "<" },
		{ id = "gt", label = ">", width = 32, insert = ">" },
		{ id = "undo", label = "↶", width = 36, cmd = "edit.undo" },
		{ id = "redo", label = "↷", width = 36, cmd = "edit.redo" },
		{ id = "play", label = "🎮 Play+Code", width = 88, cmd = "mobile.togglePlayWhileCoding", accent = true },
		{ id = "run", label = "▶ Run", width = 56, cmd = "run.active", good = true },
	}

	function M.new(parent, onInsertSymbol)
		local height = 38
		local root = P.frame(parent, {
			name = "MobileQuickKeysBar",
			size = UDim2.new(1, 0, 0, height),
			bg = theme.color.sideBarHeader,
			visible = false,
			zIndex = 36,
		})
		local topRule = P.frame(root, {
			size = UDim2.new(1, 0, 0, 1),
			bg = theme.color.border,
			zIndex = 37,
		})

		local keyScroll = P.scroll(root, {
			name = "MobileQuickKeysScroll",
			size = UDim2.new(1, 0, 1, -1),
			pos = UDim2.fromOffset(0, 1),
			direction = Enum.ScrollingDirection.X,
			autoCanvas = Enum.AutomaticSize.X,
			barThickness = 2,
			zIndex = 37,
		})
		P.pad(keyScroll, 3, 6, 3, 6)
		P.list(keyScroll, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

		local keyBtns = {}
		for idx, spec in ipairs(KEYS) do
			local btnBg = theme.color.inputBg
			local txtCol = theme.color.tabActiveText
			if spec.accent then
				btnBg = theme.color.accent
				txtCol = Color3.fromRGB(255, 255, 255)
			elseif spec.good then
				btnBg = theme.color.good
				txtCol = Color3.fromRGB(20, 24, 20)
			end
			local btn = P.button(keyScroll, {
				name = "QuickKey_" .. spec.id,
				size = UDim2.fromOffset(spec.width, 30),
				bg = btnBg,
				hoverBg = theme.color.hover,
				color = txtCol,
				mono = (spec.insert ~= nil),
				bold = true,
				text = spec.label,
				textSize = 12,
				radius = 5,
				order = idx,
				zIndex = 38,
				onClick = function()
					if spec.insert and onInsertSymbol then
						onInsertSymbol(spec.insert)
					elseif spec.cmd then
						commands.run(spec.cmd)
					end
				end,
			})
			btn.BackgroundTransparency = 0
			keyBtns[#keyBtns + 1] = { btn = btn, spec = spec }
		end

		theme.changed:connect(function()
			root.BackgroundColor3 = theme.color.sideBarHeader
			topRule.BackgroundColor3 = theme.color.border
			for _, entry in ipairs(keyBtns) do
				if entry.spec.accent then
					entry.btn.BackgroundColor3 = theme.color.accent
				elseif entry.spec.good then
					entry.btn.BackgroundColor3 = theme.color.good
				else
					entry.btn.BackgroundColor3 = theme.color.inputBg
					entry.btn.TextColor3 = theme.color.tabActiveText
				end
			end
		end)

		return {
			root = root,
			height = height,
			setTransparency = function(bgTrans)
				root.BackgroundTransparency = math.min(0.45, bgTrans)
			end,
		}
	end

	return M
end
