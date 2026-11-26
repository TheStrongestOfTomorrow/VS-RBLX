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

## 2. Current Codebase Snapshot (Post-v1 / `main` @ `e172f99`)

- **Bundle**: `dist/vsrblx.lua` (`82` modules, `83` checked Lua files, `11/11` headless E2E suites passing in `test/run.lua`).
- **Key Subsystems**:
  - `init.lua`, `src/embedding/sdk.lua` — Bootstrap, re-execution toggle, `CoreGui` -> `PlayerGui` fallback, `getgenv().VSRBLX` SDK.
  - `src/runtime/fsx.lua`, `src/runtime/workspace_fs.lua`, `src/runtime/session_journal.lua` — Executor disk persistence (`writefile`/`readfile`) + virtual memory fallback + crash-draft recovery.
  - `src/runtime/languages.lua`, `src/runtime/code_lexer.lua`, `src/runtime/editor_actions.lua` — 17-language RichText lexer, Seti badges, `languages.isPreviewable(...)` gate, Monaco smart typing.
  - `src/runtime/roblox_api_db.lua`, `src/runtime/intellisense.lua` — Deep LSP-style IntelliSense (live `env.game`/`env.workspace` child introspection, variable type inference, cross-file `require("...")` symbol indexing, parameter signature help, hover docs, `F12` Go-to-Definition, `$0` snippets).
  - `src/runtime/preview_engine.lua`, `src/ui/code/preview_pane.lua` — Live Split Preview Engine (`HTML`+`style.css`, `CSS`, `Markdown`, `JSON`/`YAML` tree, `SQL` simulator, `Python`/`JS`/`TS` quick-eval; strictly hidden on non-previewable languages).
  - `src/ui/mobile_bar.lua`, `src/ui/responsive.lua`, `src/ui/window.lua`, `src/ui/titlebar.lua`, `src/ui/app.lua` — Draggable/8-way-resizable window, Ghost opacity (`30%–100%`), Zen Mode, and Acode Mobile Mode (`☰` slide-over drawer, `42px` touch tabs, Quick-Keys bar, keyboard inset, `🎮 Play+Code` dock).
  - `src/runtime/extension_hub.lua`, `src/ui/panels/extensions.lua`, `.github/ISSUE_TEMPLATE/`, `.github/workflows/extension-gatekeeper.yml`, `.github/scripts/validate_extension_issue.js` — Locked 5-Template Community Extension Hub (`theme-pack`, `snippet-pack`, `command-macro`, `keymap-preset`, `toolbar-tool`), Client Malware Scanner, and automated GitHub Issues Gatekeeper.

---

## 3. Active v2 Roadmap (Pending Implementation)

### [ ] Sprint v2.1 — Topbar Resize-Mode Toggle (`⤢`), Multi-Tab Bar & Zero-Overlap Layout (Mobile + Desktop)
- **Topbar Resize-Mode Toggle (`⤢` ON / OFF — Both Mobile Acode & Desktop)**:
  - **Root cause**: Always-active invisible `Resize*` frames (`zIndex = 95`) around all 8 edges/corners intercept touch/mouse clicks on TitleBar, tabs, and scrollbars, preventing players from moving the UI cleanly.
  - **Fix**: Keep all 8 resize handles **completely disabled & hidden (`Visible = false`, `Active = false`) by default (`Resize Mode = OFF`)**. Add a dedicated **`⤢` Resize Toggle button** on `TitleBar`:
    - **Turn ON**: Highlights `⤢`, renders visible Push/Pull handles on all 4 edges & 4 corners, and pauses TitleBar move-dragging so players can push/pull to resize cleanly.
    - **Turn OFF**: Hides handles, locks the new custom size, and restores smooth unobstructed TitleBar moving & UI clicks.
- **Movable Floating Window in Mobile Mode + Draggable Minimized Pill**:
  - Stop forcing `isMobFull` (`100%` screen lock) in Mobile Mode unless explicitly Maximized (`□`) so phone players can resize and move VS-RBLX around their screen freely; make `MinimizedPill` (`VS-RBLX ↗`) draggable so it never blocks Roblox mobile controls.
- **True Multi-Tab Overflow Bar**:
  - Support opening arbitrarily many files/extension views in separate persistent tabs simultaneously with horizontal scrolling, `‹ ›` scroll buttons, and a `▾` Open Tabs dropdown so tabs never squish or overwrite each other.
- **Zero-Overlap Adaptive Desktop & Compact UI (Phone-Safe Desktop Mode)**:
  - Root cause: `TitleBar` (`284px` menus + `252px` search pill + `328px` right controls = `864px`) and `StatusBar` (`~800px`) overlap/merge text when Desktop Mode runs on phones (`640px–844px`).
  - Fix: Width-aware breakpoints on `TitleBar` (collapse menus into `≡ Menu`, shrink search pill to `⌕`, collapse extra toggles into `⋯`), horizontally scrollable/adaptive `StatusBar` & `BottomPanel` headers, and viewport-clamped Modals (`<= 94%` viewport W/H).

### [ ] Sprint v2.2 — Zero-Knowledge Master Vault & Deep GitHub PAT Encryption (`🔐`)
- **First-Boot Master Vault Prompt (with Clean Opt-Out)**:
  - On first launch, prompt: **`[🔐 Create Master Vault Key]`** vs **`[Leave Unencrypted / Don't Want To]`** (which sets `vault.mode = "off"`, leaves everything unencrypted, and never nags again; re-enableable in Settings).
- **Unrecoverable-Without-Key Cryptographic Vault (`VSRBLX/vault.enc`)**:
  - Pure-Luau **PBKDF2-HMAC-SHA256** (with random per-vault salt) + **Authenticated Stream Cipher (Encrypt-then-HMAC-SHA256)**.
  - Master Key is **never** persisted to disk. Once encrypted into `VSRBLX/vault.enc` (and scrubbed from plaintext `settings.json`), **not even VS-RBLX itself or any external script can recover the GitHub PAT** without the user entering their Master Key.
  - Includes **`🔒 Lock Vault Now`** (instant RAM key/PAT wipe) + **`Reset / Wipe Vault`** for forgotten keys.

### [ ] Sprint v2.3 — Zero-Rate-Limit CDN Marketplace, `[Load 10 More]`, Sub-Issue SemVer & Official `Project UAI` Tab
- **Static CDN Paginated Registry (`registry/page-N.json`) to Beat GitHub API Rate Limits**:
  - Unauthenticated `api.github.com` has a strict `60 req/hr` per-IP limit that breaks under shared mobile/VPN IPs.
  - Upgrade `extension-gatekeeper.yml` so verified extension issues compile into **10-per-page static JSON slices** (`registry/page-1.json`, `page-2.json`, ... + `registry/index.json`) fetched via **`raw.githubusercontent.com` Fastly CDN** (zero 60/hr quota!), backed by executor disk cache (`VSRBLX/extensions/cache/`) and live API fallback.
- **`[⬇ Load 10 More Extensions]` Pagination + Search & Template Filters**:
  - Load 10 extensions per page with a **`[⬇ Load 10 More]`** button, keyword/`@author` search bar, and template filter pills.
- **GitHub Sub-Issues Automatic Newest-SemVer Resolver (`v1.0.0` → `v1.2.0`)**:
  - Developers post extension updates as **GitHub Sub-Issues** under their parent extension issue.
  - Gatekeeper & VS-RBLX verify **same-author ownership** + **Malware Scan (`🛡 CLEAN`)** across sub-issues, and **automatically resolve & install the highest clean Semantic Version** on download (plus show `⬆ Update` badges for installed extensions).
- **Official First-Party `Project UAI` Tab / Extension**:
  - Add a dedicated **Project UAI** tab/official integration. Because Project UAI automatically self-updates whenever executed, clicking the **Project UAI** tab invokes its loader directly so it checks/updates itself automatically with zero manual maintenance required on VS-RBLX's side (wire user's exact Project UAI loader URL during v2.3).

### [ ] Sprint v2.4 — Touch Power Workflow, Remote/Property Inspector & Local Snapshots
- **Touch Copy/Paste Toolbar & Executor `autoexec` Multi-Script Runner**:
  - 1-tap Copy/Paste actions for mobile executors without hardware `Ctrl+C`/`Ctrl+V`, plus 1-click **"Save to `autoexec`"** and multi-script background runner status.
- **RemoteEvent Snippet Generator, Live Property Tweaker & Offline Snapshots (`VSRBLX/snapshots/`)**:
  - 1-click `:FireServer(...)` / `:InvokeServer(...)` Luau call generator, live Explorer property editing (`Position`, `Size`, `Color`, `Transparency`, `Visible`, `Text`, `WalkSpeed`), `Ctrl+D` multi-occurrence selection, and offline workspace snapshots.

---

## 4. Completed Sprint Changelog

- **v1 Foundation & PRs #1–#3**: Core 100% client-Luau VS Code workbench, 17-language RichText lexer, 8 themes, Executor `writefile`/`readfile` persistence, GitHub REST/Git Data clone/pull/commit/push, draggable/8-way-resizable window, single-file `tools/bundle.lua`.
- **Phase 1 QoL (PR #3)**: Ghost-Coding Opacity (`30%–100%`), Zen Mode (`Ctrl+Shift+Z`), Seti & Codicon icons, inline Explorer create/rename (`F2`), dirty-tab save prompt, `TODO`/`FIXME` scanner.
- **Sprint 2 — Phases 2 + 3 (PR #4)**: Crash-proof session & unsaved draft journal, 15-slot Clipboard Ring (`Ctrl+Shift+V`), visual HSV Color Picker + inline swatches, keymap presets, Monaco smart typing, Rainbow Brackets, Indent Guides, Sticky Scroll, Error Lens.
- **Sprint 3 — Phases 4 + 5 (PR #5 -> `3b655ea`)**: Multi-session Terminal + UNIX/Git/Roblox CLI, live `LogService.MessageOut` console + stack-jump, 3D/GUI Eyedropper (`🎯`), standalone Project Bundler (`📦`), 2-pane side-by-side Diff + Git gutter bars + Gist import/publish, interactive Settings UI + raw `.vsrblx/settings.json` sync.
- **Combined Sprint 4 + 5 — Phases 6 + 7 (PR #6 -> `fb2323d`)**: Language-gated Live Split Preview Engine (`HTML`+`style.css`, `CSS`, `Markdown`, `JSON`/`YAML`, `SQL`, `Python`/`JS`/`TS`) + Mobile "Acode" Mode (Android/touch auto-detect prompt, `☰` drawer, `42px` tabs, Quick-Keys symbol bar, keyboard inset, `🎮 Play+Code` split-peek).
- **Finale 6A + 6B (PR #7 -> `1df37d9` & Hotfix PR #8 -> `e172f99`)**: Deep LSP-style IntelliSense Engine (`roblox_api_db.lua`, live DataModel completion, type inference, cross-file `require` indexing, signature help, hover docs, `F12` Go-to-Definition) + Locked 5-Template Community Extension Hub (`extension_hub.lua`), Client Malware Scanner, locked `.github/ISSUE_TEMPLATE/` (`<= 200` char description fix), `extension-gatekeeper.yml` Action, and top-of-`README.md` `[!WARNING]` banner.
