-- Pure Roblox Frame-drawn vector VS Code Codicons & language file badges.
-- Requires zero external rbxassetid uploads so icons never break or get moderated.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local languages = env.require("runtime/languages")

	local M = {}

	local function lineBar(parent, x, y, w, h, col, rot, z)
		local b = P.frame(parent, {
			size = UDim2.fromOffset(w, h),
			pos = UDim2.fromOffset(x, y),
			bg = col,
			zIndex = z,
		})
		if rot then b.Rotation = rot end
		return b
	end

	local function outlineBox(parent, x, y, w, h, col, radius, z)
		local f = P.frame(parent, {
			size = UDim2.fromOffset(w, h),
			pos = UDim2.fromOffset(x, y),
			radius = radius or 2,
			border = col,
			borderWidth = 1.5,
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
			outlineBox(root, 3, 5, s - 9, s - 7, col, 2, z + 1)
			outlineBox(root, 6, 2, s - 9, s - 7, col, 2, z + 2)
		elseif name == "search" then
			local r = math.floor(s * 0.56)
			local circle = outlineBox(root, 2, 2, r, r, col, math.floor(r / 2), z + 1)
			circle.Name = "Lens"
			lineBar(root, math.floor(s * 0.56), math.floor(s * 0.68), math.floor(s * 0.36), 2, col, 45, z + 1)
		elseif name == "scm" then
			outlineBox(root, 4, 2, 5, 5, col, 3, z + 2)
			outlineBox(root, 4, s - 7, 5, 5, col, 3, z + 2)
			outlineBox(root, s - 9, 5, 5, 5, col, 3, z + 2)
			lineBar(root, 6, 7, 2, s - 14, col, 0, z + 1)
			lineBar(root, 6, math.floor(s * 0.48), s - 13, 2, col, -18, z + 1)
		elseif name == "debug" then
			outlineBox(root, 3, 3, s - 6, s - 6, col, 3, z + 1)
			local playLbl = P.label(root, {
				size = UDim2.fromScale(1, 1),
				text = "▶",
				textSize = math.max(10, s - 7),
				color = col,
				alignX = Enum.TextXAlignment.Center,
				zIndex = z + 2,
			})
			playLbl.Position = UDim2.fromOffset(1, 0)
		elseif name == "extensions" then
			local b = math.floor((s - 7) / 2)
			outlineBox(root, 2, 2, b, b, col, 1, z + 1)
			outlineBox(root, 2, 4 + b, b, b, col, 1, z + 1)
			outlineBox(root, 4 + b, 4 + b, b, b, col, 1, z + 1)
			outlineBox(root, 5 + b, 1, b, b, col, 1, z + 2)
		elseif name == "settings" then
			local r = s - 6
			outlineBox(root, 3, 3, r, r, col, math.floor(r / 2), z + 1)
			outlineBox(root, math.floor(s / 2) - 2, math.floor(s / 2) - 2, 4, 4, col, 2, z + 2)
			lineBar(root, math.floor(s / 2) - 1, 1, 2, 3, col, 0, z + 1)
			lineBar(root, math.floor(s / 2) - 1, s - 4, 2, 3, col, 0, z + 1)
			lineBar(root, 1, math.floor(s / 2) - 1, 3, 2, col, 0, z + 1)
			lineBar(root, s - 4, math.floor(s / 2) - 1, 3, 2, col, 0, z + 1)
		elseif name == "account" then
			outlineBox(root, math.floor(s / 2) - 4, 2, 8, 8, col, 4, z + 1)
			outlineBox(root, 3, s - 8, s - 6, 6, col, 3, z + 1)
		elseif name == "sidebar" then
			outlineBox(root, 2, 3, s - 4, s - 6, col, 2, z + 1)
			lineBar(root, 7, 4, 2, s - 8, col, 0, z + 2)
		elseif name == "panel" then
			outlineBox(root, 2, 3, s - 4, s - 6, col, 2, z + 1)
			lineBar(root, 3, s - 8, s - 6, 2, col, 0, z + 2)
		elseif name == "split" then
			outlineBox(root, 2, 3, s - 4, s - 6, col, 2, z + 1)
			lineBar(root, math.floor(s / 2), 4, 1, s - 8, col, 0, z + 2)
		elseif name == "minimize" then
			lineBar(root, 4, math.floor(s / 2), s - 8, 1, col, 0, z + 1)
		elseif name == "maximize" then
			outlineBox(root, 4, 4, s - 8, s - 8, col, 1, z + 1)
		elseif name == "close" then
			lineBar(root, 3, math.floor(s / 2), s - 6, 2, col, 45, z + 1)
			lineBar(root, 3, math.floor(s / 2), s - 6, 2, col, -45, z + 1)
		end

		return root
	end

	function M.fileBadge(parent, langId, isDir, zIndex)
		local z = zIndex or 5
		if isDir then
			local folderBox = P.frame(parent, {
				name = "FolderBadge",
				size = UDim2.fromOffset(14, 11),
				bg = Color3.fromRGB(220, 173, 96),
				radius = 2,
				zIndex = z,
			})
			return folderBox
		end
		local lang = type(langId) == "table" and langId or languages.get(langId)
		local rgb = lang.badgeColor or { 150, 150, 150 }
		local badgeColor = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		local lbl = P.label(parent, {
			name = "LangBadge",
			size = UDim2.fromOffset(26, 14),
			text = lang.badge or "FILE",
			mono = true,
			bold = true,
			textSize = 9,
			color = badgeColor,
			alignX = Enum.TextXAlignment.Center,
			zIndex = z,
		})
		return lbl
	end

	return M
end
