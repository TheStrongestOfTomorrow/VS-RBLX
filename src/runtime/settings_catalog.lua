-- VS Code Settings catalog for the interactive Settings editor & search bar.
return function(_env)
	local M = {}

	M.items = {
		{
			key = "workbench.colorTheme",
			category = "Workbench",
			title = "Color Theme",
			description = "Specifies the color theme used in the VS-RBLX workbench.",
			kind = "select",
			options = {
				{ value = "dark_plus", label = "Dark+ (Default Dark)" },
				{ value = "one_dark", label = "One Dark Pro" },
				{ value = "github_dark", label = "GitHub Dark Default" },
				{ value = "monokai", label = "Monokai Classic" },
				{ value = "dracula", label = "Dracula Official" },
				{ value = "catppuccin", label = "Catppuccin Mocha" },
				{ value = "solarized_dark", label = "Solarized Dark" },
				{ value = "light_plus", label = "Light+ (Default Light)" },
			},
		},
		{
			key = "editor.fontSize",
			category = "Text Editor",
			title = "Font Size",
			description = "Controls the code editor font size in pixels (11 - 22).",
			kind = "number",
			min = 11,
			max = 22,
			step = 1,
		},
		{
			key = "editor.tabSize",
			category = "Text Editor",
			title = "Tab Size",
			description = "The number of spaces a tab is equal to.",
			kind = "number",
			min = 2,
			max = 8,
			step = 2,
		},
		{
			key = "editor.insertSpaces",
			category = "Text Editor",
			title = "Insert Spaces",
			description = "Insert spaces when pressing Tab instead of literal tab characters.",
			kind = "boolean",
		},
		{
			key = "editor.minimap",
			category = "Text Editor",
			title = "Minimap: Enabled",
			description = "Controls whether the right-hand code minimap is shown.",
			kind = "boolean",
		},
		{
			key = "editor.lineNumbers",
			category = "Text Editor",
			title = "Line Numbers",
			description = "Controls the display of line numbers in the editor gutter.",
			kind = "boolean",
		},
		{
			key = "editor.wordWrap",
			category = "Text Editor",
			title = "Word Wrap",
			description = "Controls how lines should wrap in the editor.",
			kind = "boolean",
		},
		{
			key = "editor.intellisense",
			category = "Text Editor",
			title = "Quick Suggestions (IntelliSense)",
			description = "Controls whether completions appear automatically while typing.",
			kind = "boolean",
		},
		{
			key = "editor.autoClosingBrackets",
			category = "Text Editor",
			title = "Auto Closing Brackets",
			description = "Controls whether the editor automatically closes brackets and quotes.",
			kind = "boolean",
		},
		{
			key = "editor.bracketPairColorization",
			category = "Text Editor",
			title = "Bracket Pair Colorization (Rainbow)",
			description = "Colors nested (), [], and {} brackets in gold, orchid, and blue.",
			kind = "boolean",
		},
		{
			key = "editor.indentGuides",
			category = "Text Editor",
			title = "Render Indent Guides",
			description = "Draws vertical indentation guide bars at each tab stop.",
			kind = "boolean",
		},
		{
			key = "editor.stickyScroll",
			category = "Text Editor",
			title = "Sticky Scroll",
			description = "Pins the current function/class scope header at the top of the editor while scrolling.",
			kind = "boolean",
		},
		{
			key = "editor.inlineErrorLens",
			category = "Text Editor",
			title = "Inline Error Underlines & Lens",
			description = "Shows wavy/colored underlines and inline diagnostic text on lines with issues.",
			kind = "boolean",
		},
		{
			key = "keybindings.preset",
			category = "Keybindings",
			title = "Keymap Preset",
			description = "Switches editor shortcuts between VS Code, Sublime Text, or Touch-Friendly presets.",
			kind = "select",
			options = {
				{ value = "vscode", label = "VS Code Default" },
				{ value = "sublime", label = "Sublime Text" },
				{ value = "touch", label = "Touch / Conflict-Free" },
			},
		},
		{
			key = "keybindings.toggleKey",
			category = "Keybindings",
			title = "Toggle Window Hotkey",
			description = "Global hotkey to show/hide the VS-RBLX window inside Roblox.",
			kind = "select",
			options = {
				{ value = "RightShift", label = "RightShift" },
				{ value = "RightControl", label = "RightControl" },
				{ value = "Insert", label = "Insert" },
				{ value = "F4", label = "F4" },
				{ value = "F8", label = "F8" },
			},
		},
		{
			key = "files.autoSave",
			category = "Files",
			title = "Auto Save to Local Disk",
			description = "Controls automatic `writefile` persistence of dirty editors.",
			kind = "select",
			options = {
				{ value = "afterDelay", label = "afterDelay (Auto-write to disk)" },
				{ value = "off", label = "off (Manual Ctrl+S)" },
			},
		},
		{
			key = "window.autoResize",
			category = "Window",
			title = "Auto Resize with Viewport",
			description = "Automatically scales & clamps the VS-RBLX window when the Roblox viewport resizes.",
			kind = "boolean",
		},
		{
			key = "workbench.breadcrumbs",
			category = "Workbench",
			title = "Breadcrumbs: Enabled",
			description = "Enable/disable navigation breadcrumbs above the editor.",
			kind = "boolean",
		},
		{
			key = "github.autoSyncOnPush",
			category = "GitHub",
			title = "Sync Local Disk on Pull/Clone",
			description = "Automatically writes cloned/pulled GitHub files to local executor disk.",
			kind = "boolean",
		},
	}

	function M.search(query)
		local q = tostring(query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
		if q == "" then return M.items end
		local out = {}
		for _, item in ipairs(M.items) do
			if item.key:lower():find(q, 1, true)
				or item.title:lower():find(q, 1, true)
				or item.description:lower():find(q, 1, true)
				or item.category:lower():find(q, 1, true) then
				out[#out + 1] = item
			end
		end
		return out
	end

	return M
end
