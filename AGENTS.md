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
   luajit test/check.lua init.lua src
   luajit tools/bundle.lua
   luajit tools/bundle.lua --check
   luajit test/run.lua
   node .github/scripts/validate_extension_issue.js --self-test
   ```
   Always commit regenerated `dist/vsrblx.lua`, `dist/vsrblx.localscript.lua`, and `dist/vsrblx.manifest.json` alongside any `src/**` or `init.lua` edits.
4. **Git & PR Discipline**:
   - Push commits directly to the active working branch; only open a GitHub Pull Request when the user explicitly asks for one.
   - Known gotchas:
     - `command_catalog.run(id, ...)` wraps handlers in `pcall`, returning `(ok, result)`.
     - `fsx.resolve(path)` automatically prepends `VSRBLX/`; pass relative paths like `"extensions/installed.json"`, not `"VSRBLX/..."`.
     - GitHub Issue Forms (`.github/ISSUE_TEMPLATE/*.yml`) enforce a strict `<= 200` character cap on top-level `description:`.

---

## 2. Current Codebase Snapshot (Post-Sprint v2A / `arena/dd9f316f-vs-rblx`)

- **Bundle**: `dist/vsrblx.lua` (`84` modules, `85` checked Lua files, `12/12` headless E2E suites passing in `test/run.lua`, build `1.0.0-836b2890e0e29e85`).
- **Key Subsystems**:
  - `init.lua`, `src/embedding/sdk.lua` — Bootstrap, re-execution toggle, `CoreGui` -> `PlayerGui` fallback, `getgenv().VSRBLX` SDK (`api.cryptoVault`, `api.setResizeMode`, `api.toggleResizeMode`, `api.isResizeMode`).
  - `src/runtime/crypto_vault.lua`, `src/ui/panels/vault_modal.lua` — **Zero-Knowledge Master Vault (`🔐`)**: FIPS 180-4 SHA-256, RFC 2104 HMAC-SHA256, RFC 8018 PBKDF2-HMAC-SHA256, and SHA-256-CTR + Encrypt-then-HMAC-SHA256 (`VSRBLX/vault.enc`). Master Key is never stored on disk; plaintext `github.token` is scrubbed from `settings.json`; first-boot modal lets users either `[🔐 Create Vault Key]` or `[Leave Unencrypted]`.
  - `src/runtime/fsx.lua`, `src/runtime/workspace_fs.lua`, `src/runtime/session_journal.lua` — Executor disk persistence (`writefile`/`readfile`) + virtual memory fallback + crash-draft recovery.
  - `src/runtime/languages.lua`, `src/runtime/code_lexer.lua`, `src/runtime/editor_actions.lua` — 17-language RichText lexer, Seti badges, `languages.isPreviewable(...)` gate, Monaco smart typing.
  - `src/runtime/roblox_api_db.lua`, `src/runtime/intellisense.lua` — Deep LSP-style IntelliSense (live `env.game`/`env.workspace` child introspection, variable type inference, cross-file `require("...")` symbol indexing, parameter signature help, hover docs, `F12` Go-to-Definition, `$0` snippets).
  - `src/runtime/preview_engine.lua`, `src/ui/code/preview_pane.lua` — Live Split Preview Engine (`HTML`+`style.css`, `CSS`, `Markdown`, `JSON`/`YAML` tree, `SQL` simulator, `Python`/`JS`/`TS` quick-eval; strictly hidden on non-previewable languages).
  - `src/ui/window.lua`, `src/ui/titlebar.lua`, `src/ui/code/tabs.lua`, `src/ui/statusbar.lua`, `src/ui/overlay.lua`, `src/ui/mobile_bar.lua`, `src/ui/app.lua` — Explicit Topbar Resize Toggle (`⤢` ON/OFF — OFF by default so resize hitboxes never hijack UI/moving), movable floating window in both Desktop & Mobile Mode, draggable `MinimizedPill` (`VS-RBLX ↗`), Multi-Tab Overflow Bar (`‹`, `›`, `+`, `▾ N` Open Tabs switcher), viewport-clamped Modals/Dropdowns, and zero-overlap phone-safe Desktop/Compact breakpoints (`>= 880px` full, `540–879px` `≡ Menu` + `⋯`, `< 540px` ultra-compact).
  - `src/runtime/extension_hub.lua`, `src/ui/panels/extensions.lua`, `.github/ISSUE_TEMPLATE/`, `.github/workflows/extension-gatekeeper.yml`, `.github/scripts/validate_extension_issue.js` — Locked 5-Template Community Extension Hub (`theme-pack`, `snippet-pack`, `command-macro`, `keymap-preset`, `toolbar-tool`), Client Malware Scanner (including `vault.*` setting block), and automated GitHub Issues Gatekeeper.

---

## 3. Active v2 Roadmap

### [x] Combined Sprint v2A (`Sprint v2.1 + Sprint v2.2`) — **SHIPPED**
- **Topbar Resize-Mode Toggle (`⤢` ON / OFF — Both Mobile Acode & Desktop)**:
  - All 8 `Resize*` edge/corner frames are hidden & inactive by default (`win.resizeMode = false`) so they never block TitleBar moving or UI buttons. Clicking `⤢` (`ResizeModeBtn`) turns on visible Push/Pull handles + `ResizeModeBanner` and pauses TitleBar move-dragging until `⤢` is clicked OFF again.
- **Movable Floating Mobile Window + Draggable Minimized Pill + Multi-Tab Overflow Bar**:
  - Mobile Mode now floats (`90% x 86%`) instead of locking full-bleed (unless Maximized `□`), moves freely by dragging `TitleBar`, resizes via `⤢`, and features a draggable `MinimizedPill` (`VS-RBLX ↗`).
  - `src/ui/code/tabs.lua` adds `‹` / `›` horizontal scroll buttons, `+` `NewTabBtn`, and `▾ N` `AllOpenTabsBtn` dropdown switcher so dozens of tabs stay open simultaneously without squishing.
- **Zero-Overlap Phone-Safe Breakpoints**:
  - Adaptive `TitleBar` (`CompactMenuBtn` `≡ Menu`, `CompactMoreBtn` `⋯`), width-aware `StatusBar`, scrollable `BottomPanel` header tabs, clamped narrow Desktop Sidebar/Panel, and viewport-clamped `overlay.lua` modals/dropdowns.
- **Zero-Knowledge Master Vault (`VSRBLX/vault.enc` — `🔐`)**:
  - First-boot onboarding modal (`VaultSetupModal`) offering `[🔐 Create Vault Key]` vs `[Leave Unencrypted]` (`vault.mode = "off"`).
  - Pure Lua 5.1-compatible `SHA-256` (verified against NIST FIPS 180-4 vectors), `HMAC-SHA256`, `PBKDF2-HMAC-SHA256`, and `Encrypt-then-HMAC-SHA256` stream cipher; scrubs plaintext `github.token` from `settings.json`; supports `🔒 Lock Vault` (RAM wipe) and `Wipe / Reset Vault`.

### [ ] Combined Sprint v2B (`Sprint v2.3 + Sprint v2.4`) — **NEXT UP**
- **Static CDN Paginated Registry (`registry/page-N.json`) to Beat GitHub API Rate Limits (`v2.3`)**:
  - Unauthenticated `api.github.com` has a strict `60 req/hr` per-IP limit that breaks under shared mobile/VPN IPs.
  - Upgrade `extension-gatekeeper.yml` so verified extension issues compile into **10-per-page static JSON slices** (`registry/page-1.json`, `page-2.json`, ... + `registry/index.json`) fetched via **`raw.githubusercontent.com` Fastly CDN** (zero 60/hr quota!), backed by executor disk cache (`VSRBLX/extensions/cache/`) and live API fallback.
- **`[⬇ Load 10 More Extensions]` Pagination + Search & Template Filters (`v2.3`)**:
  - Load 10 extensions per page with a **`[⬇ Load 10 More]`** button, keyword/`@author` search bar, and template filter pills.
- **GitHub Sub-Issues Automatic Newest-SemVer Resolver (`v1.0.0` → `v1.2.0`) (`v2.3`)**:
  - Developers post extension updates as **GitHub Sub-Issues** under their parent extension issue.
  - Gatekeeper & VS-RBLX verify **same-author ownership** + **Malware Scan (`🛡 CLEAN`)** across sub-issues, and **automatically resolve & install the highest clean Semantic Version** on download (plus show `⬆ Update` badges for installed extensions).
- **Official First-Party `Project UAI` Tab / Extension (`v2.3`)**:
  - Dedicated **Project UAI** tab/official integration. Because Project UAI automatically self-updates whenever executed, clicking the **Project UAI** tab invokes its loader directly so it checks/updates itself automatically with zero manual maintenance required on VS-RBLX's side (wire user's exact Project UAI loader URL during v2B).
- **Touch Power Workflow, Remote/Property Inspector & Local Snapshots (`v2.4`)**:
  - 1-tap Copy/Paste actions for mobile executors without hardware `Ctrl+C`/`Ctrl+V`, plus 1-click **"Save to `autoexec`"** and multi-script background runner status.
  - 1-click `:FireServer(...)` / `:InvokeServer(...)` Luau call generator, live Explorer property editing (`Position`, `Size`, `Color`, `Transparency`, `Visible`, `Text`, `WalkSpeed`), `Ctrl+D` multi-occurrence selection, and offline workspace snapshots (`VSRBLX/snapshots/`).

---

## 4. Completed Sprint Changelog

- **v1 Foundation & PRs #1–#3**: Core 100% client-Luau VS Code workbench, 17-language RichText lexer, 8 themes, Executor `writefile`/`readfile` persistence, GitHub REST/Git Data clone/pull/commit/push, draggable/8-way-resizable window, single-file `tools/bundle.lua`.
- **Phase 1 QoL (PR #3)**: Ghost-Coding Opacity (`30%–100%`), Zen Mode (`Ctrl+Shift+Z`), Seti & Codicon icons, inline Explorer create/rename (`F2`), dirty-tab save prompt, `TODO`/`FIXME` scanner.
- **Sprint 2 — Phases 2 + 3 (PR #4)**: Crash-proof session & unsaved draft journal, 15-slot Clipboard Ring (`Ctrl+Shift+V`), visual HSV Color Picker + inline swatches, keymap presets, Monaco smart typing, Rainbow Brackets, Indent Guides, Sticky Scroll, Error Lens.
- **Sprint 3 — Phases 4 + 5 (PR #5 -> `3b655ea`)**: Multi-session Terminal + UNIX/Git/Roblox CLI, live `LogService.MessageOut` console + stack-jump, 3D/GUI Eyedropper (`🎯`), standalone Project Bundler (`📦`), 2-pane side-by-side Diff + Git gutter bars + Gist import/publish, interactive Settings UI + raw `.vsrblx/settings.json` sync.
- **Combined Sprint 4 + 5 — Phases 6 + 7 (PR #6 -> `fb2323d`)**: Language-gated Live Split Preview Engine (`HTML`+`style.css`, `CSS`, `Markdown`, `JSON`/`YAML`, `SQL`, `Python`/`JS`/`TS`) + Mobile "Acode" Mode (Android/touch auto-detect prompt, `☰` drawer, `42px` tabs, Quick-Keys symbol bar, keyboard inset, `🎮 Play+Code` split-peek).
- **Finale 6A + 6B (PR #7 -> `1df37d9` & Hotfix PR #8 -> `e172f99`)**: Deep LSP-style IntelliSense Engine (`roblox_api_db.lua`, live DataModel completion, type inference, cross-file `require` indexing, signature help, hover docs, `F12` Go-to-Definition) + Locked 5-Template Community Extension Hub (`extension_hub.lua`), Client Malware Scanner, locked `.github/ISSUE_TEMPLATE/` (`<= 200` char description fix), `extension-gatekeeper.yml` Action, and top-of-`README.md` `[!WARNING]` banner.
- **Combined Sprint v2A — Sprints v2.1 + v2.2 (`arena/dd9f316f-vs-rblx`, build `1.0.0-836b2890e0e29e85`)**: Explicit Topbar Resize-Mode Toggle (`⤢` ON/OFF), movable floating Mobile Mode window, draggable `MinimizedPill` (`VS-RBLX ↗`), Multi-Tab Overflow Bar (`‹ ›` scroll + `▾ N` Open Tabs switcher + `+`), zero-overlap phone-safe Desktop/Compact breakpoints, viewport-clamped Modals, and Zero-Knowledge Master Vault (`crypto_vault.lua` + `vault_modal.lua`: `PBKDF2-HMAC-SHA256` + `Encrypt-then-HMAC-SHA256` in `VSRBLX/vault.enc` with first-boot opt-out).

