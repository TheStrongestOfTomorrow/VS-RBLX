-- Pure Roblox Frame-drawn vector VS Code Codicons & Seti-style colored file/folder icons.
-- Requires zero external rbxassetid uploads so icons never break, blur, or get moderated.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local languages = env.require("runtime/languages")
	local util = env.require("runtime/util")

	local M = {}

	local function lineBar(parent, x, y, w, h, col, rot, z, rad)
		local b = P.frame(parent, {
			size = UDim2.fromOffset(w, h),
			pos = UDim2.fromOffset(x, y),
			bg = col,
			radius = rad,
			zIndex = z,
		})
		if rot then b.Rotation = rot end
		return b
	end

	local function outlineBox(parent, x, y, w, h, col, radius, z, strokeW)
		local f = P.frame(parent, {
			size = UDim2.fromOffset(w, h),
			pos = UDim2.fromOffset(x, y),
			radius = radius or 2,
			border = col,
			borderWidth = strokeW or 1.4,
			zIndex = z,
		})
		return f
	end

	function M.codicon(parent, name, size, color, zIndex)
		local s = size or 20
		local col = color or theme.color.activityIcon
		local z = zIndex or 5
		local root = P.frame(parent, {
			name = "Icon_" .. tostring(name),
			size = UDim2.fromOffset(s, s),
			zIndex = z,
		})

		if name == "explorer" then
			-- Two overlapping document pages with folded corner line
			outlineBox(root, 2, 5, s - 8, s - 7, col, 2, z + 1, 1.4)
			local front = P.frame(root, {
				size = UDim2.fromOffset(s - 8, s - 7),
				pos = UDim2.fromOffset(6, 2),
				bg = theme.color.activityBar,
				radius = 2,
				border = col,
				borderWidth = 1.4,
				zIndex = z + 2,
			})
			front.BackgroundTransparency = 0.25
			lineBar(front, 3, 4, math.max(4, s - 14), 1, col, 0, z + 3)
			lineBar(front, 3, 7, math.max(3, s - 16), 1, col, 0, z + 3)
		elseif name == "search" then
			local r = math.floor(s * 0.58)
			local circle = outlineBox(root, 2, 2, r, r, col, math.floor(r / 2) + 1, z + 1, 1.5)
			circle.Name = "Lens"
			lineBar(root, math.floor(s * 0.56), math.floor(s * 0.69), math.floor(s * 0.36), 2, col, 45, z + 1, 1)
		elseif name == "scm" then
			outlineBox(root, 3, 2, 5, 5, col, 3, z + 2, 1.4)
			outlineBox(root, 3, s - 7, 5, 5, col, 3, z + 2, 1.4)
			outlineBox(root, s - 8, 5, 5, 5, col, 3, z + 2, 1.4)
			lineBar(root, 5, 7, 2, s - 14, col, 0, z + 1)
			lineBar(root, 6, math.floor(s * 0.46), s - 13, 2, col, -20, z + 1)
		elseif name == "debug" then
			-- Play triangle + small debug bug circle on bottom-left
			outlineBox(root, 2, s - 8, 6, 6, col, 3, z + 2, 1.3)
			local playLbl = P.label(root, {
				size = UDim2.fromOffset(s - 2, s - 2),
				pos = UDim2.fromOffset(2, 0),
				text = "▷",
				bold = true,
				textSize = math.max(11, s - 5),
				color = col,
				alignX = Enum.TextXAlignment.Center,
				zIndex = z + 2,
			})
			playLbl.Name = "PlayGlyph"
		elseif name == "extensions" then
			local b = math.floor((s - 7) / 2)
			outlineBox(root, 2, 3, b, b, col, 1, z + 1, 1.4)
			outlineBox(root, 2, 4 + b, b, b, col, 1, z + 1, 1.4)
			outlineBox(root, 3 + b, 4 + b, b, b, col, 1, z + 1, 1.4)
			local detached = outlineBox(root, 5 + b, 1, b, b, col, 1, z + 2, 1.4)
			detached.Rotation = 12
		elseif name == "settings" then
			local r = s - 6
			outlineBox(root, 3, 3, r, r, col, math.floor(r / 2), z + 1, 1.4)
			outlineBox(root, math.floor(s / 2) - 2, math.floor(s / 2) - 2, 4, 4, col, 2, z + 2, 1.4)
			lineBar(root, math.floor(s / 2) - 1, 1, 2, 3, col, 0, z + 1)
			lineBar(root, math.floor(s / 2) - 1, s - 4, 2, 3, col, 0, z + 1)
			lineBar(root, 1, math.floor(s / 2) - 1, 3, 2, col, 0, z + 1)
			lineBar(root, s - 4, math.floor(s / 2) - 1, 3, 2, col, 0, z + 1)
		elseif name == "account" then
			outlineBox(root, math.floor(s / 2) - 4, 2, 8, 8, col, 4, z + 1, 1.4)
			outlineBox(root, 3, s - 8, s - 6, 6, col, 3, z + 1, 1.4)
		elseif name == "sidebar" then
			outlineBox(root, 2, 3, s - 4, s - 6, col, 2, z + 1, 1.3)
			lineBar(root, 6, 4, 2, s - 8, col, 0, z + 2)
		elseif name == "panel" then
			outlineBox(root, 2, 3, s - 4, s - 6, col, 2, z + 1, 1.3)
			lineBar(root, 3, s - 7, s - 6, 2, col, 0, z + 2)
		elseif name == "split" then
			outlineBox(root, 2, 3, s - 4, s - 6, col, 2, z + 1, 1.3)
			lineBar(root, math.floor(s / 2), 4, 1, s - 8, col, 0, z + 2)
		elseif name == "zen" then
			-- Four inward/outward focus corners
			lineBar(root, 2, 2, 4, 1, col, 0, z + 1)
			lineBar(root, 2, 2, 1, 4, col, 0, z + 1)
			lineBar(root, s - 6, 2, 4, 1, col, 0, z + 1)
			lineBar(root, s - 3, 2, 1, 4, col, 0, z + 1)
			lineBar(root, 2, s - 3, 4, 1, col, 0, z + 1)
			lineBar(root, 2, s - 6, 1, 4, col, 0, z + 1)
			lineBar(root, s - 6, s - 3, 4, 1, col, 0, z + 1)
			lineBar(root, s - 3, s - 6, 1, 4, col, 0, z + 1)
			outlineBox(root, 5, 5, s - 10, s - 10, col, 1, z + 2, 1.2)
		elseif name == "opacity" then
			-- Half-filled contrast circle (`◐`)
			local r = s - 4
			local c = outlineBox(root, 2, 2, r, r, col, math.floor(r / 2), z + 1, 1.3)
			c.ClipsDescendants = true
			lineBar(c, 0, 0, math.floor(r / 2), r, col, 0, z + 2)
		elseif name == "newFile" then
			outlineBox(root, 3, 2, s - 7, s - 4, col, 2, z + 1, 1.3)
			lineBar(root, s - 6, s - 7, 5, 1, col, 0, z + 2)
			lineBar(root, s - 4, s - 9, 1, 5, col, 0, z + 2)
		elseif name == "newFolder" then
			lineBar(root, 2, 3, 6, 2, col, 0, z + 1, 1)
			outlineBox(root, 2, 5, s - 5, s - 7, col, 2, z + 1, 1.3)
			lineBar(root, s - 6, s - 7, 5, 1, col, 0, z + 2)
			lineBar(root, s - 4, s - 9, 1, 5, col, 0, z + 2)
		elseif name == "refresh" then
			P.label(root, {
				size = UDim2.fromScale(1, 1),
				text = "↻",
				bold = true,
				textSize = math.max(12, s - 2),
				color = col,
				alignX = Enum.TextXAlignment.Center,
				zIndex = z + 1,
			})
		elseif name == "saveAll" then
			outlineBox(root, 2, 4, s - 6, s - 6, col, 2, z + 1, 1.3)
			outlineBox(root, 4, 2, s - 6, s - 6, col, 2, z + 2, 1.3)
			lineBar(root, 6, 4, s - 10, 3, col, 0, z + 3)
		elseif name == "todo" then
			outlineBox(root, 2, 2, s - 4, s - 4, col, 3, z + 1, 1.3)
			P.label(root, {
				size = UDim2.fromScale(1, 1),
				text = "✓",
				bold = true,
				textSize = math.max(10, s - 4),
				color = col,
				alignX = Enum.TextXAlignment.Center,
				zIndex = z + 2,
			})
		elseif name == "pin" then
			lineBar(root, math.floor(s / 2) - 3, 3, 6, 2, col, 0, z + 2, 1)
			outlineBox(root, math.floor(s / 2) - 2, 5, 4, 5, col, 1, z + 2, 1.2)
			lineBar(root, math.floor(s / 2) - 1, 10, 2, 5, col, 0, z + 1)
		elseif name == "minimize" then
			lineBar(root, 4, math.floor(s / 2), s - 8, 1, col, 0, z + 1)
		elseif name == "maximize" then
			outlineBox(root, 4, 4, s - 8, s - 8, col, 1, z + 1, 1.3)
		elseif name == "close" then
			lineBar(root, 3, math.floor(s / 2), s - 6, 2, col, 45, z + 1)
			lineBar(root, 3, math.floor(s / 2), s - 6, 2, col, -45, z + 1)
		end

		return root
	end

	-- Authentic VS Code Seti-style file & folder icon colors and emblems
	local SETI_FOLDER_COLORS = {
		src = Color3.fromRGB(78, 201, 176),
		ui = Color3.fromRGB(86, 156, 214),
		runtime = Color3.fromRGB(197, 134, 192),
		tools = Color3.fromRGB(220, 173, 96),
		test = Color3.fromRGB(115, 201, 145),
		docs = Color3.fromRGB(79, 193, 255),
		dist = Color3.fromRGB(206, 145, 120),
		web = Color3.fromRGB(241, 224, 90),
		scripts = Color3.fromRGB(0, 162, 255),
		[".github"] = Color3.fromRGB(156, 220, 254),
	}

	local SETI_FILE_SPECS = {
		luau = { glyph = "🌙", text = "LU", rgb = { 0, 162, 255 }, boxed = true },
		lua = { glyph = "LU", rgb = { 81, 160, 213 }, boxed = true },
		typescript = { glyph = "TS", rgb = { 49, 120, 198 }, solid = true },
		javascript = { glyph = "JS", rgb = { 241, 224, 90 }, solid = true, darkText = true },
		python = { glyph = "PY", rgb = { 53, 114, 165 }, boxed = true },
		json = { glyph = "{}", rgb = { 203, 203, 65 } },
		html = { glyph = "<>", rgb = { 227, 76, 38 } },
		css = { glyph = "#", rgb = { 66, 165, 245 } },
		markdown = { glyph = "M↓", rgb = { 81, 154, 186 }, boxed = true },
		rust = { glyph = "RS", rgb = { 222, 165, 132 }, boxed = true },
		go = { glyph = "GO", rgb = { 0, 173, 216 }, boxed = true },
		c = { glyph = "C", rgb = { 104, 159, 216 }, boxed = true },
		cpp = { glyph = "C+", rgb = { 243, 75, 125 }, boxed = true },
		csharp = { glyph = "C#", rgb = { 23, 134, 0 }, boxed = true },
		sql = { glyph = "DB", rgb = { 227, 140, 0 }, boxed = true },
		yaml = { glyph = "Y!", rgb = { 203, 23, 30 } },
		shell = { glyph = "$_", rgb = { 137, 224, 81 } },
		plaintext = { glyph = "≡", rgb = { 150, 150, 150 } },
	}

	local SPECIAL_FILENAMES = {
		["readme.md"] = { glyph = "ⓘ", rgb = { 79, 193, 255 } },
		["license"] = { glyph = "⚖", rgb = { 215, 186, 125 } },
		[".gitignore"] = { glyph = "⎇", rgb = { 241, 76, 76 } },
		["settings.json"] = { glyph = "⚙", rgb = { 156, 220, 254 } },
	}

	function M.fileBadge(parent, langOrPath, isDir, zIndex, isExpanded)
		local z = zIndex or 5
		if isDir then
			local folderName = type(langOrPath) == "string" and util.basename(langOrPath):lower() or ""
			local folderCol = SETI_FOLDER_COLORS[folderName] or Color3.fromRGB(220, 173, 96)
			local wrap = P.frame(parent, {
				name = "FolderBadge",
				size = UDim2.fromOffset(16, 13),
				zIndex = z,
			})
			-- Folder top tab
			P.frame(wrap, {
				size = UDim2.fromOffset(7, 3),
				pos = UDim2.fromOffset(0, 1),
				bg = folderCol,
				radius = 1,
				zIndex = z + 1,
			})
			-- Folder body
			local body = P.frame(wrap, {
				size = UDim2.fromOffset(15, 10),
				pos = UDim2.fromOffset(0, 3),
				bg = folderCol,
				transparency = isExpanded and 0.32 or 0.08,
				radius = 2,
				border = isExpanded and folderCol or nil,
				borderWidth = isExpanded and 1.2 or nil,
				zIndex = z + 1,
			})
			if isExpanded then
				P.frame(body, {
					size = UDim2.fromOffset(13, 5),
					pos = UDim2.fromOffset(1, 4),
					bg = folderCol,
					radius = 1,
					zIndex = z + 2,
				})
			end
			return wrap
		end

		local spec = nil
		if type(langOrPath) == "string" then
			local baseLower = util.basename(langOrPath):lower()
			if SPECIAL_FILENAMES[baseLower] then
				spec = SPECIAL_FILENAMES[baseLower]
			end
		end

		if not spec then
			local lang
			if type(langOrPath) == "table" then
				lang = langOrPath
			elseif type(langOrPath) == "string" and langOrPath:find("%.", 1, true) then
				lang = languages.detect(langOrPath)
			else
				lang = languages.get(langOrPath)
			end
			spec = SETI_FILE_SPECS[lang.id] or {
				glyph = (lang.badge or "F"):sub(1, 2),
				rgb = lang.badgeColor or { 150, 150, 150 },
				boxed = true,
			}
		end

		local rgb = spec.rgb or { 150, 150, 150 }
		local col = Color3.fromRGB(rgb[1], rgb[2], rgb[3])

		local holder = P.frame(parent, {
			name = "SetiBadge",
			size = UDim2.fromOffset(18, 14),
			bg = spec.solid and col or (spec.boxed and col or nil),
			transparency = spec.solid and 0.08 or (spec.boxed and 0.84 or 1),
			radius = 3,
			border = spec.boxed and col or nil,
			borderWidth = spec.boxed and 1 or nil,
			zIndex = z,
		})

		local textCol = col
		if spec.solid then
			textCol = spec.darkText and Color3.fromRGB(24, 24, 24) or Color3.fromRGB(255, 255, 255)
		end

		P.label(holder, {
			name = "SetiGlyph",
			size = UDim2.fromScale(1, 1),
			text = spec.text or spec.glyph or "≡",
			mono = true,
			bold = true,
			textSize = 9,
			color = textCol,
			alignX = Enum.TextXAlignment.Center,
			zIndex = z + 1,
		})
		return holder
	end

	return M
end
