-- VS Code Welcome Tab shown when no editor tabs are open.
return function(env)
	local P = env.require("ui/primitives")
	local theme = env.require("ui/theme")
	local brand = env.require("ui/brand")
	local caps = env.require("runtime/caps")
	local fsx = env.require("runtime/fsx")
	local config = env.require("runtime/config")
	local commands = env.require("runtime/command_catalog")
	local fsSync = env.require("tools/fs_sync")

	local M = {}

	function M.new(parent)
		local root = P.scroll(parent, {
			name = "WelcomeScreen",
			size = UDim2.fromScale(1, 1),
			bg = theme.color.editor,
			visible = false,
			zIndex = 14,
		})
		P.pad(root, 32, 36, 32, 36)

		local headerRow = P.frame(root, {
			size = UDim2.new(1, 0, 0, 56),
			zIndex = 15,
		})
		local logo = brand.draw(headerRow, 42, 16)
		logo.Position = UDim2.fromOffset(0, 6)

		local titleLbl = P.label(headerRow, {
			size = UDim2.new(1, -58, 0, 28),
			pos = UDim2.fromOffset(56, 2),
			text = "Visual Studio Code · Roblox Edition",
			bold = true,
			textSize = 22,
			color = theme.color.tabActiveText,
			zIndex = 16,
		})
		local subLbl = P.label(headerRow, {
			size = UDim2.new(1, -58, 0, 20),
			pos = UDim2.fromOffset(56, 32),
			text = string.format(
				"100%% Luau  |  Host: %s  |  Disk: %s  |  HTTP: %s",
				caps.executor,
				fsx.isBackedByDisk() and "writefile / readfile" or "Virtual Disk",
				caps.requestName or caps.http
			),
			textSize = 12,
			color = theme.color.muted,
			zIndex = 16,
		})

		local grid = P.frame(root, {
			size = UDim2.new(1, 0, 0, 260),
			pos = UDim2.fromOffset(0, 82),
			zIndex = 15,
		})

		local leftCol = P.frame(grid, {
			size = UDim2.new(0.48, 0, 1, 0),
			zIndex = 15,
		})
		P.list(leftCol, Enum.FillDirection.Vertical, 8)

		P.label(leftCol, {
			size = UDim2.new(1, 0, 0, 20),
			text = "Start",
			bold = true,
			textSize = 14,
			color = theme.color.tabActiveText,
			order = 1,
			zIndex = 16,
		})

		local START_ACTIONS = {
			{ label = "+  New Disk File...", cmd = "file.newDiskFile" },
			{ label = "📂  Switch Local Disk Workspace...", cmd = "workspace.switch" },
			{ label = "💾  Mount Raw Executor Folder...", cmd = "workspace.mountRaw" },
			{ label = "⎇  Clone GitHub Repository...", cmd = "github.clone" },
			{ label = "🔑  Set GitHub Personal Access Token...", cmd = "github.auth" },
			{ label = "🎨  Switch Color Theme...", cmd = "workbench.commandPalette" },
		}

		for idx, act in ipairs(START_ACTIONS) do
			P.button(leftCol, {
				size = UDim2.new(1, 0, 0, 26),
				alignX = Enum.TextXAlignment.Left,
				text = "  " .. act.label,
				color = theme.color.accent,
				radius = 4,
				order = idx + 1,
				zIndex = 16,
				onClick = function() commands.run(act.cmd) end,
			})
		end

		local rightCol = P.frame(grid, {
			size = UDim2.new(0.48, 0, 1, 0),
			pos = UDim2.new(0.52, 0, 0, 0),
			zIndex = 15,
		})
		P.list(rightCol, Enum.FillDirection.Vertical, 6)

		P.label(rightCol, {
			size = UDim2.new(1, 0, 0, 20),
			text = "Recent Disk Workspaces",
			bold = true,
			textSize = 14,
			color = theme.color.tabActiveText,
			order = 1,
			zIndex = 16,
		})

		local recentBox = P.frame(rightCol, {
			size = UDim2.new(1, 0, 0, 180),
			order = 2,
			zIndex = 16,
		})
		P.list(recentBox, Enum.FillDirection.Vertical, 4)

		local function refreshRecent()
			recentBox:ClearAllChildren()
			P.list(recentBox, Enum.FillDirection.Vertical, 4)
			local recent = config.get("files.recentWorkspaces", { "default" })
			if type(recent) == "table" then
				for i, name in ipairs(recent) do
					local wsName = tostring(name)
					P.button(recentBox, {
						size = UDim2.new(1, 0, 0, 24),
						alignX = Enum.TextXAlignment.Left,
						text = "  VSRBLX/workspaces/" .. wsName,
						mono = true,
						textSize = 12,
						color = theme.color.sideBarText,
						radius = 4,
						order = i,
						zIndex = 17,
						onClick = function() fsSync.switchWorkspace(wsName) end,
					})
				end
			end
		end

		config.changed:connect(function(key)
			if key == "*" or key == "files.recentWorkspaces" then refreshRecent() end
		end)
		theme.changed:connect(function()
			root.BackgroundColor3 = theme.color.editor
			titleLbl.TextColor3 = theme.color.tabActiveText
			subLbl.TextColor3 = theme.color.muted
		end)

		refreshRecent()
		return {
			root = root,
			refresh = refreshRecent,
		}
	end

	return M
end
