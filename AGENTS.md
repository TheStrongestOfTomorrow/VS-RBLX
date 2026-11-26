# AGENTS.md — Contributor Rules, Architecture Memory & Sprint Handoff Log

> **MANDATORY RULE FOR ALL AGENTS:**
> Whenever you complete a sprint, feature, architectural change, or bugfix, **you MUST update `AGENTS.md`** (specifically **Current Status**, **Active v2 Roadmap**, and **Completed Changelog**) before committing. This file serves as the persistent cross-session memory so the project owner can switch agents or start fresh threads anytime with zero lost context.

---

## 1. Non-Negotiable Authoring & Repository Rules

1. **Pure Lua 5.1-Compatible Client Luau (`init.lua` + `src/**`)**:
   - Every module under `src/` must return a factory function: `return function(env) ... end`.
   - Resolve internal modules strictly via `env.require("category/name")` (never `script.Parent` or `loadfile`).
   - **Never** use Luau-only syntax in `init.lua` or `src/**` so offline `LuaJIT 2.1` passes 100%:
     - NO `continue`, NO compound assignments (`+=`, `-=`, `..=`), NO floor division `//`, NO Luau type annotations (`x: number`, `export type`), NO backtick string interpolation, and NO regex `(?:...)` non-capturing groups in Lua string patterns.
2. **Preserve Single-Line Loader in `README.md`**:
   - Never alter or break the single-line Quick Start loader:
     ```lua
     loadstring(game:HttpGet("https://raw.githubusercontent.com/TheStrongestOfTomorrow/VS-RBLX/main/dist/vsrblx.lua"))()
     ```
   - Do **NOT** create a separate `ROADMAP.md` file — keep all roadmap tracking right here in `AGENTS.md` (and condensed in chat replies).
3. **Verification Gauntlet (Run Before Every Commit)**:
   ```bash
   # If luajit is not preinstalled in the container, compile LuaJIT 2.1 into /tmp/bin/luajit first.
   luajit test/check.lua
   luajit tools/bundle.lua
   luajit tools/bundle.lua --check
   luajit test/run.lua
   node .github/scripts/validate_extension_issue.js --self-test
   node .github/scripts/build_extension_registry.js --self-test
   ```
   Always commit regenerated `dist/vsrblx.lua`, `dist/vsrblx.localscript.lua`, and `dist/vsrblx.manifest.json` alongside any `src/**` or `init.lua` edits.
4. **Git & PR Discipline**:
   - Push commits directly to the active working branch; only open a GitHub Pull Request when the user explicitly asks for one.
   - Known gotchas:
     - `command_catalog.run(id, ...)` wraps handlers in `pcall`, returning `(ok, result)`.
     - `fsx.resolve(path)` automatically prepends `VSRBLX/`; pass relative paths like `"extensions/installed.json"`, not `"VSRBLX/..."`.
     - GitHub Issue Forms (`.github/ISSUE_TEMPLATE/*.yml`) enforce a strict `<= 200` character cap on top-level `description:`.

---

## 2. Current Codebase Snapshot (Post-Sprint v2B / `arena/dd9f316f-vs-rblx` — All v2 Roadmap Sprints Shipped)

- **Bundle**: `dist/vsrblx.lua` (`91` modules, `92` checked Lua files, `13/13` headless E2E suites passing in `test/run.lua`, build `1.0.0-dffd0bd2d4e085c2`).
- **Key Subsystems**:
  - `init.lua`, `src/embedding/sdk.lua` — Bootstrap, re-execution toggle, `CoreGui` -> `PlayerGui` fallback, `getgenv().VSRBLX` SDK (`api.cryptoVault`/`api.vault`, `api.aiProviders`, `api.aiTools`, `api.aiAgent`/`api.ai`, `api.snapshots`, `api.setResizeMode`, `api.toggleResizeMode`, `api.isResizeMode`).
  - `src/ai/sse.lua`, `src/ai/providers.lua`, `src/ai/tools.lua`, `src/ai/agent_loop.lua`, `src/ui/panels/ai_chat.lua`, `src/ui/code/inline_ai.lua` — **VS-RBLX Integrated VS Code AI Editor (`✦ AI` / `Ctrl+Alt+I` & `Ctrl+I`)**: Clean-room Secondary Right-Side AI Sidebar (`AIChatSidebar`) and Floating Inline AI Edit Bar (`InlineAiBar` with `[✓ Accept]`, `[◫ Diff]`, `[✕ Discard]`). Supports Built-in Zero-Key Smart Luau Mode (`local_smart`), OpenAI, Anthropic Claude, OpenRouter, DeepSeek, and Custom OpenAI-Compatible / Ollama endpoints; Vault-encrypted API keys (`ai.key.<provider>` inside `VSRBLX/vault.enc`); buffered SSE replay (`sse.lua`); 3-mode Permission Gate (`🛡 Ask First` · `⚡ Auto Edit` · `👁 Read Only`); surgical `workspace_edit_file`, non-executing `check_luau_syntax`, cooperative loop-deadline `run_luau_bounded`, and live DataModel/Remote tools. Explicitly credits **[Project UAI (`Project-Ptolemy/ProjectUAI`)](https://github.com/Project-Ptolemy/ProjectUAI)** by **CarlDV / Project-Ptolemy** *(MIT License)* for executor AI architectural inspiration (never embeds or copies Project UAI code/UI).
  - `src/runtime/crypto_vault.lua`, `src/ui/panels/vault_modal.lua` — **Zero-Knowledge Master Vault (`🔐`)**: FIPS 180-4 SHA-256, RFC 2104 HMAC-SHA256, RFC 8018 PBKDF2-HMAC-SHA256, and SHA-256-CTR + Encrypt-then-HMAC-SHA256 (`VSRBLX/vault.enc`). Encrypts GitHub PATs & AI API keys; scrubs plaintext secrets from `settings.json`; first-boot modal lets users either `[🔐 Create Vault Key]` or `[Leave Unencrypted]`.
  - `src/runtime/fsx.lua`, `src/runtime/workspace_fs.lua`, `src/runtime/session_journal.lua`, `src/tools/snapshots.lua` — Executor disk persistence (`writefile`/`readfile`) + virtual memory fallback + crash-draft recovery + offline Workspace Snapshots (`VSRBLX/snapshots/`) + 1-click `autoexec/` script exporter.
  - `src/runtime/languages.lua`, `src/runtime/code_lexer.lua`, `src/runtime/editor_actions.lua`, `src/ui/code/editor.lua` — 17-language RichText lexer, Seti badges, `languages.isPreviewable(...)` gate, Monaco smart typing, `Ctrl+D` (`selectNextOccurrence`), and touch `pasteText` / `selectWord`.
  - `src/runtime/roblox_api_db.lua`, `src/runtime/intellisense.lua`, `src/runtime/roblox_explorer.lua`, `src/ui/panels/explorer.lua` — Deep LSP-style IntelliSense + Live Roblox DataModel Explorer with 3D/GUI Eyedropper (`🎯`), **Live Property Tweaker** (`ExplorerPropTweakerModal` / `setPropertyLive`), and **RemoteEvent `:FireServer` / `:InvokeServer` Luau Snippet Generator** (`generateRemoteSnippet`).
  - `src/runtime/preview_engine.lua`, `src/ui/code/preview_pane.lua` — Live Split Preview Engine (`HTML`+`style.css`, `CSS`, `Markdown`, `JSON`/`YAML` tree, `SQL` simulator, `Python`/`JS`/`TS` quick-eval; strictly hidden on non-previewable languages).
  - `src/ui/window.lua`, `src/ui/titlebar.lua`, `src/ui/code/tabs.lua`, `src/ui/statusbar.lua`, `src/ui/overlay.lua`, `src/ui/mobile_bar.lua`, `src/ui/app.lua` — Explicit Topbar Resize Toggle (`⤢` ON/OFF), `✦ AI` & `🔐` Topbar controls, movable floating window in both Desktop & Mobile Mode, draggable `MinimizedPill` (`VS-RBLX ↗`), Multi-Tab Overflow Bar (`‹`, `›`, `+`, `▾ N`), Mobile Quick-Keys (`📋 Copy`, `📥 Paste`, `✦ AI`, `⚡ Autoexec`), viewport-clamped Modals/Dropdowns, and zero-overlap phone-safe breakpoints.
  - `src/runtime/extension_hub.lua`, `src/ui/panels/extensions.lua`, `.github/scripts/validate_extension_issue.js`, `.github/scripts/build_extension_registry.js`, `.github/workflows/extension-gatekeeper.yml`, `registry/index.json`, `registry/page-1.json` — **Zero-Rate-Limit Static CDN Marketplace (`10/page` + `[⬇ Load 10 More]` + Sub-Issues SemVer Resolver)**: Pre-compiled 10-per-page `registry/page-N.json` served via `raw.githubusercontent.com` Fastly CDN (zero 60/hr GitHub API quota), automatic newest-clean-SemVer resolution across same-author GitHub Sub-Issues (rejecting cross-author spoofs & tainted releases), search & filter pills, `⬆ Update` badges, and Client Malware Scanner blocking `github.*`, `vault.*`, and `ai.*` settings tampering.

---

## 3. Active v2 Roadmap

### [x] Combined Sprint v2A (`Sprint v2.1 + Sprint v2.2`) — **SHIPPED (`c303927`)**
- **Topbar Resize-Mode Toggle (`⤢` ON / OFF — Both Mobile Acode & Desktop)**:
  - All 8 `Resize*` edge/corner frames are hidden & inactive by default (`win.resizeMode = false`) so they never block TitleBar moving or UI buttons. Clicking `⤢` (`ResizeModeBtn`) turns on visible Push/Pull handles + `ResizeModeBanner` and pauses TitleBar move-dragging until `⤢` is clicked OFF again.
- **Movable Floating Mobile Window + Draggable Minimized Pill + Multi-Tab Overflow Bar**:
  - Mobile Mode floats (`90% x 86%`), moves freely by dragging `TitleBar`, resizes via `⤢`, and features a draggable `MinimizedPill` (`VS-RBLX ↗`).
  - `src/ui/code/tabs.lua` adds `‹` / `›` horizontal scroll buttons, `+` `NewTabBtn`, and `▾ N` `AllOpenTabsBtn` dropdown switcher.
- **Zero-Overlap Phone-Safe Breakpoints & Zero-Knowledge Master Vault (`VSRBLX/vault.enc` — `🔐`)**:
  - Adaptive `TitleBar` (`CompactMenuBtn` `≡ Menu`, `CompactMoreBtn` `⋯`), width-aware `StatusBar`, and viewport-clamped `overlay.lua` modals/dropdowns.
  - Pure Lua 5.1-compatible `SHA-256`, `HMAC-SHA256`, `PBKDF2-HMAC-SHA256`, and `Encrypt-then-HMAC-SHA256` stream cipher with first-boot `[Leave Unencrypted]` opt-out.

### [x] Combined Sprint v2B (`Sprint v2.3 + Sprint v2.4 + Integrated VS Code AI Editor`) — **SHIPPED**
- **VS-RBLX Integrated VS Code AI Editor (`✦ AI` Secondary Sidebar + `Ctrl+I` Inline Edit Bar — Replaces External Loader)**:
  - Per explicit user direction, VS-RBLX does **NOT** embed or launch external `Project UAI` via `loadstring`; instead, it ships a 100% original **VS Code-styled Secondary Right-Side AI Sidebar (`AIChatSidebar`, `Ctrl+Alt+I`)** + **Floating `Ctrl+I` Inline AI Bar (`InlineAiBar`)** while explicitly crediting **Project UAI (`Project-Ptolemy/ProjectUAI`, MIT © 2026 CarlDV)** in the UI (`AiAttributionLabel`), `README.md`, and `AGENTS.md` for its executor AI engineering patterns (buffered SSE replay, `Read Only / Ask First / Auto` permission gate, surgical `workspace_edit_file`, non-executing `check_luau_syntax`, and cooperative deadline-guarded `run_luau_bounded`).
- **Zero-Rate-Limit Static CDN Paginated Registry (`registry/page-N.json`) + `[⬇ Load 10 More]` + Sub-Issues SemVer Resolver (`v2.3`)**:
  - `.github/scripts/build_extension_registry.js` + `extension-gatekeeper.yml` compile verified issues & sub-issues into static 10-per-page `registry/page-N.json` slices served via `raw.githubusercontent.com` Fastly CDN, with executor disk cache (`VSRBLX/extensions/cache/`) and live API fallback.
  - Same-author + Malware-Scan-verified GitHub Sub-Issues automatically resolve to the highest clean Semantic Version (`resolveSubIssueFamily`), with `ExtSearchInput`, template filters, `⬆ Update` button, and `LoadMoreExtensionsBtn` (`[⬇ Load 10 More]`).
- **Touch Power Workflow, Remote/Property Inspector & Local Snapshots (`v2.4`)**:
  - 1-tap `📋 Copy`, `📥 Paste`, `✦ AI`, and `⚡ Autoexec` on mobile Quick-Keys (`mobile_bar.lua`), `Ctrl+D` (`selectNextOccurrence`), offline Workspace Snapshots (`VSRBLX/snapshots/`), RemoteEvent `:FireServer`/`:InvokeServer` snippet generator, and Live Explorer Property Tweaker (`ExplorerPropTweakerModal`).

---

## 4. Completed Sprint Changelog

- **v1 Foundation & PRs #1–#3**: Core 100% client-Luau VS Code workbench, 17-language RichText lexer, 8 themes, Executor `writefile`/`readfile` persistence, GitHub REST/Git Data clone/pull/commit/push, draggable/8-way-resizable window, single-file `tools/bundle.lua`.
- **Phase 1 QoL (PR #3)**: Ghost-Coding Opacity (`30%–100%`), Zen Mode (`Ctrl+Shift+Z`), Seti & Codicon icons, inline Explorer create/rename (`F2`), dirty-tab save prompt, `TODO`/`FIXME` scanner.
- **Sprint 2 — Phases 2 + 3 (PR #4)**: Crash-proof session & unsaved draft journal, 15-slot Clipboard Ring (`Ctrl+Shift+V`), visual HSV Color Picker + inline swatches, keymap presets, Monaco smart typing, Rainbow Brackets, Indent Guides, Sticky Scroll, Error Lens.
- **Sprint 3 — Phases 4 + 5 (PR #5 -> `3b655ea`)**: Multi-session Terminal + UNIX/Git/Roblox CLI, live `LogService.MessageOut` console + stack-jump, 3D/GUI Eyedropper (`🎯`), standalone Project Bundler (`📦`), 2-pane side-by-side Diff + Git gutter bars + Gist import/publish, interactive Settings UI + raw `.vsrblx/settings.json` sync.
- **Combined Sprint 4 + 5 — Phases 6 + 7 (PR #6 -> `fb2323d`)**: Language-gated Live Split Preview Engine (`HTML`+`style.css`, `CSS`, `Markdown`, `JSON`/`YAML`, `SQL`, `Python`/`JS`/`TS`) + Mobile "Acode" Mode (Android/touch auto-detect prompt, `☰` drawer, `42px` tabs, Quick-Keys symbol bar, keyboard inset, `🎮 Play+Code` split-peek).
- **Finale 6A + 6B (PR #7 -> `1df37d9` & Hotfix PR #8 -> `e172f99`)**: Deep LSP-style IntelliSense Engine (`roblox_api_db.lua`, live DataModel completion, type inference, cross-file `require` indexing, signature help, hover docs, `F12` Go-to-Definition) + Locked 5-Template Community Extension Hub (`extension_hub.lua`), Client Malware Scanner, locked `.github/ISSUE_TEMPLATE/` (`<= 200` char description fix), `extension-gatekeeper.yml` Action, and top-of-`README.md` `[!WARNING]` banner.
- **Combined Sprint v2A — Sprints v2.1 + v2.2 (`arena/dd9f316f-vs-rblx`, commit `c303927`, build `1.0.0-836b2890e0e29e85`)**: Explicit Topbar Resize-Mode Toggle (`⤢` ON/OFF), movable floating Mobile Mode window, draggable `MinimizedPill` (`VS-RBLX ↗`), Multi-Tab Overflow Bar (`‹ ›` scroll + `▾ N` Open Tabs switcher + `+`), zero-overlap phone-safe Desktop/Compact breakpoints, viewport-clamped Modals, and Zero-Knowledge Master Vault (`crypto_vault.lua` + `vault_modal.lua`: `PBKDF2-HMAC-SHA256` + `Encrypt-then-HMAC-SHA256` in `VSRBLX/vault.enc` with first-boot opt-out).
- **Combined Sprint v2B — Sprints v2.3 + v2.4 + VS-RBLX Integrated VS Code AI Editor (`arena/dd9f316f-vs-rblx`, build `1.0.0-dffd0bd2d4e085c2`)**: Clean-room VS Code Secondary Right-Side AI Sidebar (`ai_chat.lua`) + `Ctrl+I` Floating Inline AI Bar (`inline_ai.lua`) + Vault-encrypted multi-provider SSE/Agent engine (`sse.lua`, `providers.lua`, `tools.lua`, `agent_loop.lua`) with explicit MIT attribution to `Project UAI` (`Project-Ptolemy/ProjectUAI` © 2026 CarlDV); Zero-Rate-Limit Static CDN 10-per-page Marketplace (`build_extension_registry.js`, `registry/index.json`, `registry/page-1.json`, `[⬇ Load 10 More]`) + automatic same-author GitHub Sub-Issues SemVer resolver; and Touch/Inspector Power Tools (`snapshots.lua`, `autoexec/`, RemoteEvent snippet generator, Live Property Tweaker, `Ctrl+D` multi-occurrence, mobile Copy/Paste/`✦ AI`/`⚡ Autoexec`).


