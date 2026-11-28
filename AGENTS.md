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
   node .github/scripts/validate_extension_version.js --self-test
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

## 2. Current Status & Codebase Snapshot

### Current Status

- **Active branch**: `arena/b5eee7cb-vs-rblx`, based on `dbe41159ad5cbcec3dc31ba2d65ebcecf30fb30e` (`main`). Do not switch branches.
- **UI reliability remains the active priority.** Existing fixes cover short/keyboard-constrained viewport bounds, narrow-window sidebar budgeting, mobile AI overlay behavior, bottom-panel space, and caret auto-reveal while typing/navigating long files. The current pass adds a touch-aware Desktop Mode on compact phones/tablets: a temporary workspace drawer, larger tab targets, full-width editor when the drawer is closed, compact split/preview behavior, and a narrower Play-While-Coding dock without switching to Acode Mode. Headless checks cover the modeled behavior, but required Roblox Studio/executor visual smoke checks on phone-sized and desktop viewports have **not** been performed; do not mark Sprint v3.0 complete yet.
- **Saved AI conversations (v3A slice)** now support bounded persistent threads, automatic first-prompt titles, create/switch/rename/archive/restore/delete, title/transcript search, and local JSON export. UI controls are integrated; history is stored under `VSRBLX/ai/threads/index.json`, migrates legacy `ai/history.json`, caps at 30 threads and 30 transcript entries per thread, and keeps tool/error status entries. Remaining v3A items are still open below.
- **Verification**: LuaJIT static checker (94 files), Luau 0.748 parser (93 modules + init + both bundles), deterministic bundle check, all 13 headless E2E suites, all three extension validation/registry Node self-tests, and YAML/embedded Action-script syntax checks pass. Added `.github/workflows/luau-syntax.yml` so future pushes/PRs compile source and generated bundles with official Luau rather than relying only on LuaJIT parsing. The loader bundle is lexically compacted to 945,677 bytes with a 990,000-byte generation budget; compaction preserves literal/comment contents and source-line mapping, and has fixture coverage. This is a plausible mitigation for the reported `loadstring` malformed-string parse failure, not yet confirmed in the user's executor; exact executor and full console error are still needed if it persists. Headless tests do not establish in-client visual correctness.
- **AI scope slice**: Project listing and reads are recursive/paged; live DataModel has bounded recursive inspection and a bounded script-read tool. AI-owned artifacts are isolated per conversation under `VSRBLX/ai/workspaces/threads/<thread-id>`, while any earlier `VSRBLX/ai/workspaces/default` data is preserved and assigned to the first recorded thread. An explicit transfer tool supports copying into the active project only after a dedicated in-UI approval (even in Auto Edit), with separate overwrite consent. Live DataModel mutation remains follow-up work; non-active projects now require explicit in-UI authorization, and grants are read-only and thread-scoped.

### Codebase Snapshot

- **Bundle**: `dist/vsrblx.lua` (`93` modules, `94` checked Lua files, `13/13` headless E2E suites passing in `test/run.lua`, build `1.0.0-88037b68efdb3d02`).
- **Key Subsystems**:
  - `src/runtime/ai_workspace.lua` — Private per-thread AI artifact filesystem under `VSRBLX/ai/workspaces/threads/<thread-id>`, separate from project workspace paths and saved AI thread storage; preserves prior default-root data and exposes bounded list/read/write/delete primitives with traversal and file-size checks.
  - `init.lua`, `src/embedding/sdk.lua` — Bootstrap, re-execution toggle, `CoreGui` -> `PlayerGui` fallback, `getgenv().VSRBLX` SDK (`api.cryptoVault`/`api.vault`, `api.aiProviders`, `api.aiTools`, `api.aiAgent`/`api.ai`, `api.snapshots`, `api.setResizeMode`, `api.toggleResizeMode`, `api.isResizeMode`).
  - `src/ai/sse.lua`, `src/ai/providers.lua`, `src/ai/tools.lua`, `src/ai/agent_loop.lua`, `src/ai/uai_adapter.lua`, `src/ui/panels/ai_chat.lua`, `src/ui/code/inline_ai.lua` — **VS-RBLX Integrated VS Code AI Editor (`✦ AI` / `Ctrl+Alt+I` & `Ctrl+I`)**: Clean-room Secondary Right-Side AI Sidebar (`AIChatSidebar`) and Floating Inline AI Edit Bar (`InlineAiBar` with `[✓ Accept]`, `[◫ Diff]`, `[✕ Discard]`). Defaults out-of-the-box to **Kilo Code (`kilo` · `kilo-auto/free` + `:free` cloud models via `https://api.kilo.ai/api/gateway/chat/completions` with `/api/openrouter` fallback & live `refreshKiloFreeModels()` sync — ZERO API key or account required)** alongside Offline Smart Luau Mode (`local_smart`), OpenAI, Anthropic Claude, OpenRouter, DeepSeek, and Custom OpenAI-Compatible / Ollama endpoints; Vault-encrypted API keys (`ai.key.<provider>` inside `VSRBLX/vault.enc`); buffered SSE replay (`sse.lua`); 3-mode Permission Gate (`🛡 Ask First` · `⚡ Auto Edit` · `👁 Read Only`); surgical `workspace_edit_file`, non-executing `check_luau_syntax`, cooperative loop-deadline `run_luau_bounded`, and live DataModel/Remote tools. Explicitly credits **[Project UAI (`Project-Ptolemy/ProjectUAI`)](https://github.com/Project-Ptolemy/ProjectUAI)** by **CarlDV / Project-Ptolemy** *(MIT License)* for executor AI architectural inspiration. A separate opt-in adapter uses only Project UAI's documented public loader/client-handle contract; it does not bundle or copy UAI source/UI.
  - `src/runtime/crypto_vault.lua`, `src/ui/panels/vault_modal.lua` — **Zero-Knowledge Master Vault (`🔐`)**: FIPS 180-4 SHA-256, RFC 2104 HMAC-SHA256, RFC 8018 PBKDF2-HMAC-SHA256, and SHA-256-CTR + Encrypt-then-HMAC-SHA256 (`VSRBLX/vault.enc`). Encrypts GitHub PATs & AI API keys; scrubs plaintext secrets from `settings.json`; first-boot modal lets users either `[🔐 Create Vault Key]` or `[Leave Unencrypted]`.
  - `src/runtime/fsx.lua`, `src/runtime/workspace_fs.lua`, `src/runtime/session_journal.lua`, `src/tools/snapshots.lua` — Executor disk persistence (`writefile`/`readfile`) + virtual memory fallback + crash-draft recovery + offline Workspace Snapshots (`VSRBLX/snapshots/`) + 1-click `autoexec/` script exporter.
  - `src/runtime/languages.lua`, `src/runtime/code_lexer.lua`, `src/runtime/editor_actions.lua`, `src/ui/code/editor.lua` — 17-language RichText lexer, Seti badges, `languages.isPreviewable(...)` gate, Monaco smart typing, `Ctrl+D` (`selectNextOccurrence`), and touch `pasteText` / `selectWord`.
  - `src/runtime/roblox_api_db.lua`, `src/runtime/intellisense.lua`, `src/runtime/roblox_explorer.lua`, `src/ui/panels/explorer.lua` — Deep LSP-style IntelliSense + Live Roblox DataModel Explorer with 3D/GUI Eyedropper (`🎯`), **Live Property Tweaker** (`ExplorerPropTweakerModal` / `setPropertyLive`), and **RemoteEvent `:FireServer` / `:InvokeServer` Luau Snippet Generator** (`generateRemoteSnippet`).
  - `src/runtime/preview_engine.lua`, `src/ui/code/preview_pane.lua` — Live Split Preview Engine (`HTML`+`style.css`, `CSS`, `Markdown`, `JSON`/`YAML` tree, `SQL` simulator, `Python`/`JS`/`TS` quick-eval; strictly hidden on non-previewable languages).
  - `src/ui/window.lua`, `src/ui/titlebar.lua`, `src/ui/code/tabs.lua`, `src/ui/statusbar.lua`, `src/ui/overlay.lua`, `src/ui/mobile_bar.lua`, `src/ui/app.lua` — Explicit Topbar Resize Toggle (`⤢` ON/OFF), `✦ AI` & `🔐` Topbar controls, movable floating window in both Desktop & Mobile Mode, draggable `MinimizedPill` (`VS-RBLX ↗`), Multi-Tab Overflow Bar (`‹`, `›`, `+`, `▾ N`), Mobile Quick-Keys (`📋 Copy`, `📥 Paste`, `✦ AI`, `⚡ Autoexec`), viewport-clamped Modals/Dropdowns, and zero-overlap phone-safe breakpoints.
  - `src/runtime/extension_hub.lua`, `src/ui/panels/extensions.lua`, `.github/scripts/validate_extension_issue.js`, `.github/scripts/validate_extension_version.js`, `.github/scripts/build_extension_registry.js`, `.github/workflows/extension-gatekeeper.yml`, `CONTRIBUTING_EXTENSIONS.md`, `registry/index.json`, `registry/page-1.json` — **Zero-Rate-Limit Static CDN Marketplace (`10/page` + `[⬇ Load 10 More]` + Owner-Verified Version Sub-Issues)**: Pre-compiled 10-per-page `registry/page-N.json` served via `raw.githubusercontent.com` Fastly CDN, owner-authored SemVer updates linked only after parent-author verification, sub-issue labels/schema/malware checks, and canonical-manifest SHA-256 provenance in version history; community comments remain discussion, not releases. Gatekeeper failures record findings and rejection/review labels; search/filter pills, update badges, and the client malware scanner remain in place.

---

## 3. Shipped v2 Roadmap

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
- **VS-RBLX Integrated VS Code AI Editor (`✦ AI` Secondary Sidebar + `Ctrl+I` Inline Edit Bar)**:
  - The original VS-RBLX agent and VS Code-styled sidebar remain independent. A later, separately user-approved integration adds an opt-in **Project UAI** button using only its documented public loader/client-handle contract; it never bundles UAI code or UI, pins a revision, manages its updater, or replaces a live incompatible client.
- **Zero-Rate-Limit Static CDN Paginated Registry (`registry/page-N.json`) + `[⬇ Load 10 More]` + Sub-Issues SemVer Resolver (`v2.3`)**:
  - `.github/scripts/build_extension_registry.js` + `extension-gatekeeper.yml` compile verified issues & sub-issues into static 10-per-page `registry/page-N.json` slices served via `raw.githubusercontent.com` Fastly CDN, with executor disk cache (`VSRBLX/extensions/cache/`) and live API fallback.
  - Same-author + Malware-Scan-verified GitHub Sub-Issues automatically resolve to the highest clean Semantic Version (`resolveSubIssueFamily`), with `ExtSearchInput`, template filters, `⬆ Update` button, and `LoadMoreExtensionsBtn` (`[⬇ Load 10 More]`).
- **Touch Power Workflow, Remote/Property Inspector & Local Snapshots (`v2.4`)**:
  - 1-tap `📋 Copy`, `📥 Paste`, `✦ AI`, and `⚡ Autoexec` on mobile Quick-Keys (`mobile_bar.lua`), `Ctrl+D` (`selectNextOccurrence`), offline Workspace Snapshots (`VSRBLX/snapshots/`), RemoteEvent `:FireServer`/`:InvokeServer` snippet generator, and Live Explorer Property Tweaker (`ExplorerPropTweakerModal`).

---

## 4. Active Roadmap (v3 — UI Stability First)

### [>] Sprint v3.0 — **Workbench UI Stabilization (CURRENT PRIORITY)**

No feature sprint should start until the interface is predictable and usable across desktop, phone portrait/landscape, touch, and the on-screen keyboard. Current work uses truthful viewport bounds, preserves an editor lane in narrow windows, overlays the AI/sidebar on compact touch screens, and keeps Desktop Mode usable on mobile without switching the user into Acode Mode.

- **Touch-aware Desktop Mode (implementation in progress)**: On compact touch viewports, preserve Desktop Mode styling while collapsing the Activity Bar, making workspace navigation a dismissible overlay drawer, enlarging tab targets, keeping split/preview panes from squeezing the code view, and exposing Play-While-Coding from the compact overflow menu. Do not auto-switch users who explicitly chose Desktop Mode into Acode Mode. Continue validating hit targets and play-window placement in Roblox clients.
- **Layout and interaction audit** across `window.lua`, `responsive.lua`, `app.lua`, `titlebar.lua`, `overlay.lua`, `tabs.lua`, `editor.lua`, `terminal.lua`, and every panel. Fix clipping, overlap, unreachable controls, stale reflow, wrong z-order, and stuck drag/focus states before adding UI surface area.
- **Responsive regression matrix**: 320×568 and 360×640 phone portrait, 844×390 landscape, 390×844 tall phone, 768×1024 tablet, and 1366×768 desktop; test normal/maximized/minimized, keyboard shown/hidden, AI open/closed, drawer, bottom panel, split editor, and modal/dropdown states.
- **Touch/readability pass**: minimum practical tap targets, scrollable content, keyboard-safe prompts, clear active/disabled/loading/error states, and no reliance on hover-only feedback.
- **Verification gate**: headless layout assertions for bounds/nonnegative pane sizes plus real Roblox Studio/executor visual smoke checks on at least one phone-sized and one desktop-sized viewport. A green Lua test suite is not a substitute for visual inspection.
- Treat user-reported screenshots/steps as high-priority repros. Keep this sprint focused on repairs and restraint; defer decorative redesign and feature creep.

### [ ] Sprint v3A — Project UAI-Inspired Agent Workflow (AFTER v3.0)

Project UAI's public source shows this is not one magic "complex script" prompt: it assembles a core prompt with environment/permission context and adds tool-family-specific guidance only when those tools are offered. Its script workflow tells the agent to define criteria, inspect, plan, build, validate, review, and report evidence; its scripting docs teach host-specific limits. This branch adopts the initial staged-build rules, current-mode context, and a bounded 10-round tool loop. Project UAI also highlights organized/searchable conversations, persistent technical notes, micro-goals with completion criteria and blockers, cancellable/rate-limited requests, and scoped permissions. Adapt these patterns to VS-RBLX's client-only storage, provider adapters, and Roblox sandbox—not its source code or interface.

- **Saved AI thread core**: bounded local persistence, create/switch/rename/archive/restore/delete, automatic titles, title/transcript search, and local JSON export are implemented and headlessly tested. Roblox-client visual smoke checks remain open; see the v3.0 verification gate above.
- Per-thread micro-goals/checklists with progress, blockers, cancel/resume, and context summaries.
- Searchable local recipes/project notes (vault-encrypted when the Master Vault is enabled), with transparent sources and user-controlled scope.
- Evolve the current prompt into tool-aware sections that match actual schemas/capabilities (script, GUI, workspace, or live context) and read concise, relevant project guidance instead of dumping whole manuals.
- Better provider/model discovery and rate-limit handling, including optional keyed Kilo catalog access and cancellable queued requests.
- Permission UX stays explicit: `Read Only` / `Ask First` remain clear choices; any broader `Allow Everything`-style mode must be an informed opt-in with visible tool scope, path boundaries, and stop controls. Do not prompt the model to ignore its own safety rules or remove safeguards just to reduce refusals.
- Consider subagents only after isolation, parent-permission inheritance, cancellation, and auditability are testable.

### [ ] Sprint v3B — Build, Runtime, and Portability Upgrades (AFTER v3A)

- Visual Roblox `ScreenGui` builder with a constrained component palette and standalone Luau export.
- Named background tasks with owned-resource cleanup, explicit stop/cancel behavior, and bounded resource inspection.
- Encrypted Vault backup/import and portable settings/extensions bundle; never export plaintext secrets.
- Provider key-pool rotation and inline diff-hunk preview, each behind explicit settings and meaningful failure feedback.

### [>] Sprint v3C — Separate AI Workspace & Full Authorized Project Discovery

- [x] Keep executor-managed AI working files, AI session/thread storage, user project workspaces, and live Roblox DataModel as distinct scopes. AI artifacts use per-thread `VSRBLX/ai/workspaces/threads/<id>`; project workspaces remain under `VSRBLX/workspaces/<name>/`; thread transcripts remain under `VSRBLX/ai/threads/`. The live DataModel is separate and read-only in this slice.
- [x] Let the agent recursively list, search, and read the active project; additional named projects can be listed by name and require a thread-scoped explicit approval before read-only content access. Project content tools remain bounded and paged; live DataModel context is a separate read-only tool family.
- [x] First-slice isolation: AI-generated artifacts are stored under a per-thread root at `VSRBLX/ai/workspaces/threads/<thread-id>`, separate from project files and thread storage. Bounded list/read/write tools enforce path/size limits; tests verify the artifact is invisible through the project filesystem and traversal is rejected. Existing project files are not migrated or moved; prior AI default-root files remain preserved.
- [x] Per-thread artifact roots now follow active AI conversation threads; earlier default-root files are retained and stay assigned to the first recorded thread.
- [x] Named-project selection now lists names without content access, then grants read-only list/search/read access per AI thread only after an in-UI approval. Existing active workspace stays unchanged.
- [ ] Follow-up: live DataModel mutation remains unavailable pending a dedicated permission/consent design. Artifact transfer to the active project always pauses for in-UI approval, including Auto Edit; overwrite requires separate consent.

### [>] Sprint v3D — Community Extension Submission, Trust, and Store UX

- [x] Redesigned `.github/ISSUE_TEMPLATE/community_extension.yml` and added `CONTRIBUTING_EXTENSIONS.md` with five-template examples, compatibility expectations, release/version rules, CDN timing, troubleshooting, licensing, and safety policy.
- [x] Kept the supported template set locked to the five implemented formats rather than adding unsupported form-only types; runtime, issue validator, malware checks, and client scanner remain aligned.
- [x] Added an owner-only version issue form and workflow. Actions validates parent author, extension identity, strict increasing SemVer, schema/malware, and links accepted versions as sub-issues. Comments remain normal discussion and are not workflow triggers or releases.
- [x] Added rejection/review labels, scanner findings in bot feedback, canonical manifest SHA-256 plus issue/author/scan provenance in registry version history, and documented a false-positive review route that never bypasses validation.
- [x] Updated issue validation, owner-version validation, workflow, registry compiler, self-tests, and contributor docs together. Existing client update offers remain user-initiated.
- [ ] Open extension details in a named editor tab with README, compatibility, permissions, changelog, version provenance, install/update actions, and community discussion. Validate in-client before closing the sprint.

### [>] Sprint v3E — Official Project UAI Integration (Independent Self-Updater)

- [x] Added user-confirmed Project UAI integration through the documented upstream client loader and public handle/SDK contract; preserved attribution and kept UAI outside community-extension publication.
- [x] UAI retains its updater. VS-RBLX never pins, polls, replaces, or versions UAI; the adapter checks SDK version/features on explicit open and fails closed when the public contract is missing/incompatible. Upstream integration details are documented in `docs/PROJECT_UAI_INTEGRATION.md`.
- [x] Documented the shared executor trust boundary and UAI-owned vault/provider/permissions; no false sandbox guarantee or host permission bypass.
- [ ] Roblox-client testing of the confirmation dialog, UAI's vault/setup flow, compatible reuse, and incompatible-handle feedback remains outstanding. Recheck the live upstream SDK contract before claiming long-term compatibility.

### Deferred / Reassess Before Scheduling

- **Live Remote Spy / packet replay** is not part of v3.0. Executor `__namecall` interception and replay are high-risk, executor-specific, and can enable abuse in live games. Revisit only with a clearly bounded, user-consented private Studio/test-game use case, no stealth or bypass behavior, and a reviewed safety design.
- **Unrestricted executable UI mods** like those supported by some desktop-oriented agent products are not a safe fit for a Roblox executor client. Prefer reviewed declarative extension points or tightly scoped APIs instead.

---

## 5. Completed Sprint Changelog

- **Loadstring parse-error mitigation (current branch)**: Reduced generated loader size from 1,036,160 to 945,677 bytes by lexically stripping code indentation while retaining string/long-string/comment contents and physical newlines; added a 990,000-byte bundle budget and a compactor fixture. LuaJIT checks, all 13 E2E suites, the deterministic bundle check, extension self-tests, YAML parsing, and Luau 0.748 parsing of both bundles pass. This does not prove the user's executor failure is fixed: no Roblox/executor reproduction has been run, and the complete console error/executor remain unknown.
- **Touch-aware Desktop Mode (current branch, v3.0 in progress)**: On compact touch viewports, retain Desktop Mode while collapsing the width-consuming Activity Bar, opening workspace navigation as an overlay drawer, increasing editor-tab hit targets, using a full-width editor when the drawer is closed, suppressing narrow split/preview panes, and narrowing the Play-While-Coding dock to preserve gameplay space. Regression coverage simulates selecting Desktop Mode after the mobile prompt and exercises drawer and play-dock behavior. Roblox-client visual smoke tests remain outstanding.
- **AI scope separation (current branch)**: Added recursive paged active-project listing, search, and UTF-8 source reads; bounded recursive live DataModel inspection and script reads; per-thread AI artifact roots while preserving prior default-root data; and named-project list/search/read scopes that require thread-scoped in-UI approval without switching the editor workspace. Artifact transfer to the active project and overwrite each require dedicated approvals. Regression tests cover isolation, traversal refusal, paging, recursive game discovery, authorization/reset, per-thread artifacts, and read-only source access. Live-game writes remain unavailable pending an explicit permission design.
- **Community extension submission/trust workflow (current branch)**: Reworked the submission form and added a comprehensive contributor guide; introduced a parent-author-only version form and GitHub Actions validation/linking flow; keeps comments as discussion only; gates registry releases on a verified version label, owner identity, SemVer, schema/malware, and linked sub-issue; records artifact SHA-256 and issue/author/scan provenance; adds rejection and false-positive-review tracking without a validation bypass. Node self-tests cover owner spoofing, unverified versions, malware, comments-as-non-releases, and pagination. Extension detail-tab UI remains open.
- **Saved AI Conversations (current branch, v3A slice)**: Replaced single-transcript history with a bounded local thread index, legacy history migration, create/switch/rename/archive/restore/delete APIs, automatic titles, title/transcript search, and AI sidebar controls for thread selection, search, rename, archive, export, delete, and new chat. Thread persistence keeps visible tool/error events and is regression-tested for lifecycle, search, export, index writing, and header updates. Roblox-client visual testing remains outstanding.
- **UI Stabilization + AI Build Workflow starter (current branch)**: Corrected usable viewport bounds for short/keyboard-constrained screens, budgeted narrow desktop sidebars to preserve an editor lane, changed mobile AI to overlay rather than consume editor width, bounded bottom-panel height, and added compact viewport regression assertions. The editor now scrolls its rendered caret into view during typing/navigation (including horizontal reveal), and end-to-end tests exercise actual TextBox smart-pair insertion and long-file caret reveal. Expanded the AI system prompt with acceptance criteria, staged complete implementation, inspection, compile/run/evidence guidance, current permission context, and a bounded 10-round tool loop; invalid caller-provided permission modes now fall back to `ask_first`.
- **v1 Foundation & PRs #1–#3**: Core 100% client-Luau VS Code workbench, 17-language RichText lexer, 8 themes, Executor `writefile`/`readfile` persistence, GitHub REST/Git Data clone/pull/commit/push, draggable/8-way-resizable window, single-file `tools/bundle.lua`.
- **Phase 1 QoL (PR #3)**: Ghost-Coding Opacity (`30%–100%`), Zen Mode (`Ctrl+Shift+Z`), Seti & Codicon icons, inline Explorer create/rename (`F2`), dirty-tab save prompt, `TODO`/`FIXME` scanner.
- **Sprint 2 — Phases 2 + 3 (PR #4)**: Crash-proof session & unsaved draft journal, 15-slot Clipboard Ring (`Ctrl+Shift+V`), visual HSV Color Picker + inline swatches, keymap presets, Monaco smart typing, Rainbow Brackets, Indent Guides, Sticky Scroll, Error Lens.
- **Sprint 3 — Phases 4 + 5 (PR #5 -> `3b655ea`)**: Multi-session Terminal + UNIX/Git/Roblox CLI, live `LogService.MessageOut` console + stack-jump, 3D/GUI Eyedropper (`🎯`), standalone Project Bundler (`📦`), 2-pane side-by-side Diff + Git gutter bars + Gist import/publish, interactive Settings UI + raw `.vsrblx/settings.json` sync.
- **Combined Sprint 4 + 5 — Phases 6 + 7 (PR #6 -> `fb2323d`)**: Language-gated Live Split Preview Engine (`HTML`+`style.css`, `CSS`, `Markdown`, `JSON`/`YAML`, `SQL`, `Python`/`JS`/`TS`) + Mobile "Acode" Mode (Android/touch auto-detect prompt, `☰` drawer, `42px` tabs, Quick-Keys symbol bar, keyboard inset, `🎮 Play+Code` split-peek).
- **Finale 6A + 6B (PR #7 -> `1df37d9` & Hotfix PR #8 -> `e172f99`)**: Deep LSP-style IntelliSense Engine (`roblox_api_db.lua`, live DataModel completion, type inference, cross-file `require` indexing, signature help, hover docs, `F12` Go-to-Definition) + Locked 5-Template Community Extension Hub (`extension_hub.lua`), Client Malware Scanner, locked `.github/ISSUE_TEMPLATE/` (`<= 200` char description fix), `extension-gatekeeper.yml` Action, and top-of-`README.md` `[!WARNING]` banner.
- **Combined Sprint v2A — Sprints v2.1 + v2.2 (`arena/dd9f316f-vs-rblx`, commit `c303927`, build `1.0.0-836b2890e0e29e85`)**: Explicit Topbar Resize-Mode Toggle (`⤢` ON/OFF), movable floating Mobile Mode window, draggable `MinimizedPill` (`VS-RBLX ↗`), Multi-Tab Overflow Bar (`‹ ›` scroll + `▾ N` Open Tabs switcher + `+`), zero-overlap phone-safe Desktop/Compact breakpoints, viewport-clamped Modals, and Zero-Knowledge Master Vault (`crypto_vault.lua` + `vault_modal.lua`: `PBKDF2-HMAC-SHA256` + `Encrypt-then-HMAC-SHA256` in `VSRBLX/vault.enc` with first-boot opt-out).
- **Combined Sprint v2B — Sprints v2.3 + v2.4 + VS-RBLX Integrated VS Code AI Editor (`arena/dd9f316f-vs-rblx`, build `1.0.0-84df0f94070491dc`)**: Clean-room VS Code Secondary Right-Side AI Sidebar (`ai_chat.lua`) + `Ctrl+I` Floating Inline AI Bar (`inline_ai.lua`) + Kilo Code zero-key free cloud LLM gateway (`kilo-auto/free` + `:free` model sync) + Vault-encrypted multi-provider SSE/Agent engine (`sse.lua`, `providers.lua`, `tools.lua`, `agent_loop.lua`) with explicit MIT attribution to `Project UAI` (`Project-Ptolemy/ProjectUAI` © 2026 CarlDV); Zero-Rate-Limit Static CDN 10-per-page Marketplace (`build_extension_registry.js`, `registry/index.json`, `registry/page-1.json`, `[⬇ Load 10 More]`) + automatic same-author GitHub Sub-Issues SemVer resolver; and Touch/Inspector Power Tools (`snapshots.lua`, `autoexec/`, RemoteEvent snippet generator, Live Property Tweaker, `Ctrl+D` multi-occurrence, mobile Copy/Paste/`✦ AI`/`⚡ Autoexec`).


