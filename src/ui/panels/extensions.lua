-- VS Code Extensions, Language Packs & Executor Capability Matrix Viewlet (`Ctrl+Shift+X`).
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local icons = env.require("ui/icons")
	local caps = env.require("runtime/caps")
	local languages = env.require("runtime/languages")
	local overlay = env.require("ui/overlay")

	local M = {}

	function M.new(parent)
		local root = P.frame(parent, {
			name = "ExtensionsViewlet",
			size = UDim2.fromScale(1, 1),
			visible = false,
			zIndex = 21,
		})
		P.pad(root, 6, 10, 6, 10)

		P.label(root, {
			size = UDim2.new(1, 0, 0, 22),
			text = "EXTENSIONS & LANGUAGES",
			bold = true,
			textSize = 11,
			color = theme.color.muted,
			zIndex = 22,
		})

		local scroll = P.scroll(root, {
			name = "ExtensionsScroll",
			size = UDim2.new(1, 0, 1, -26),
			pos = UDim2.fromOffset(0, 26),
			zIndex = 22,
		})
		P.list(scroll, Enum.FillDirection.Vertical, 4)

		local ord = 0
		local function addSection(title)
			ord = ord + 1
			P.label(scroll, {
				size = UDim2.new(1, 0, 0, 22),
				bold = true,
				textSize = 11,
				color = theme.color.tabActiveText,
				text = "▾ " .. title,
				order = ord,
				zIndex = 23,
			})
		end

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

		-- 2. Color Themes
		addSection("INSTALLED COLOR THEMES (8)")
		for _, t in ipairs(theme.list()) do
			ord = ord + 1
			local themeId = t.id
			P.button(scroll, {
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

		return { root = root }
	end

	return M
end
