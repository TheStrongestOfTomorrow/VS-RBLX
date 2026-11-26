# VS-RBLX — Visual Studio Code for Roblox (100% Luau)

> [!WARNING]
> **GitHub Issues on this repository are strictly locked to the 5 Verified VS-RBLX Community Extension Templates (`theme-pack`, `snippet-pack`, `command-macro`, `keymap-preset`, `toolbar-tool`).**
> - Blank, free-form, and off-topic issues are **disabled** (`blank_issues_enabled: false`).
> - Every opened or edited issue is **automatically scanned by GitHub Actions** (`.github/workflows/extension-gatekeeper.yml`) and **re-scanned client-side by the VS-RBLX Malware Scanner** before installation.
> - Any issue that deviates from the 5 declarative JSON schemas or contains executable code (`loadstring`, `HttpGet`, `request`), webhooks (`discord.com/api/webhooks`, Slack, Telegram), obfuscators, or credential access is **immediately rejected and closed** (`not_planned`).
> - **Comments on verified open extension issues remain open** so the community can review, discuss, and rate extensions!

**VS-RBLX** is a full-featured **Visual Studio Code clone** built in **100% client-side Luau** for Roblox Executors and LocalScripts. It brings a multi-tab syntax-highlighted IDE, **local disk persistence** (`writefile` / `readfile`), **GitHub repository sync** (`request` / `http_request`), an integrated terminal, unified & 2-pane Git diffs, **LSP-style IntelliSense**, a **Locked 5-Template Community Extension Hub**, **Live Split Preview**, **Acode Mobile Mode**, and a draggable, viewport-auto-resized, 8-direction player-resizable workbench directly inside Roblox.

---

## Quick Start

Paste and execute in any Roblox executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/TheStrongestOfTomorrow/VS-RBLX/main/dist/vsrblx.lua"))()
```

### Programmatic SDK (`getgenv().VSRBLX`)

Executing the loader also returns the IDE handle and stores it on `getgenv().VSRBLX`:

```lua
local ide = loadstring(game:HttpGet("https://raw.githubusercontent.com/TheStrongestOfTomorrow/VS-RBLX/main/dist/vsrblx.lua"))()

-- Read & write files on local executor disk (VSRBLX/workspaces/default/...)
ide.writeFile("src/combat.luau", "print('Hello from local disk!')\n")
ide.openFile("src/combat.luau")

-- Clone any GitHub repository onto local disk via Executor HTTP
ide.cloneRepo("TheStrongestOfTomorrow/VS-RBLX")

-- Authenticate with a Personal Access Token & push commits straight back to GitHub
ide.github.authenticate("ghp_your_personal_access_token")
ide.commitAndPush("Update combat script from VS-RBLX")
```

### Roblox Studio (`LocalScript`)

For Roblox Studio testing (without executor globals), paste the contents of [`dist/vsrblx.localscript.lua`](dist/vsrblx.localscript.lua) into a `LocalScript` inside `StarterPlayerScripts`. When `writefile` / `readfile` are unavailable, VS-RBLX automatically falls back to an in-memory virtual filesystem.

---

## Core Features

### Authentic VS Code Workbench
- **Title Bar**: VS-RBLX emblem, top dropdown menus (`File`, `Edit`, `View`, `Run`, `GitHub` — auto-collapsing into phone-safe `≡ Menu` & `⋯` on narrow viewports), centered Command Center search pill (`Ctrl+P`), **`✦ AI` Integrated AI Sidebar toggle (`Ctrl+Alt+I`)**, **`🔐` Zero-Knowledge Master Vault**, **`⤢` Explicit Resize-Mode Toggle (`ON` / `OFF`)**, **Ghost-Coding Opacity Slider (`30%–100%`)**, **Acode Mobile Mode (`📱` / `☰` Drawer)**, **Zen Mode (`Ctrl+Shift+Z`)**, layout toggles, and Minimize / Maximize / Close controls.
- **VS Code-Style Integrated AI Assistant & `Ctrl+I` Inline Code Editor (`✦ AI`)**:
  - **Secondary AI Sidebar (`Ctrl+Alt+I`)**: Docked on the right side of the workbench just like VS Code's built-in AI Chat, defaulting out-of-the-box to **Kilo Code (`kilo-auto/free` & `:free` cloud LLMs — zero API key, zero sign-up required, plus 1-click live `:free` model pool sync)** alongside **OpenAI**, **Anthropic Claude**, **OpenRouter**, **DeepSeek**, **Custom OpenAI-Compatible / Ollama Endpoints**, and **Offline Smart Luau Mode**; includes buffered **SSE stream replay**, `#file` / `#problems` / `#remotes` context pills, **3-Mode Permission Gate (`🛡 Ask First` · `⚡ Auto Edit` · `👁 Read Only`)**, native IDE/Roblox agent tools (`workspace_edit_file`, non-executing `check_luau_syntax`, deadline-guarded `run_luau_bounded`, live `inspect_roblox_tree` & `discover_remotes`), and 1-click **`✓ Apply`** / **`◫ Diff`**.
  - **Floating `Ctrl+I` Inline Editor Bar**: Trigger inline code generation or selection refactoring directly inside the active code editor with `[✓ Accept]`, `[◫ Diff]`, and `[✕ Discard]`.
- **Zero-Knowledge Master Vault (`VSRBLX/vault.enc` — `🔐`)**:
  - Optional first-boot Master Vault Key (`PBKDF2-HMAC-SHA256` + `Encrypt-then-HMAC-SHA256` stream cipher) encrypting GitHub PATs and AI API keys on disk while scrubbing plaintext `settings.json` — unrecoverable without your Master Key, with a 1-click **"Leave Unencrypted"** opt-out if you prefer plain storage.
- **Live Split Preview Engine (`◫ Preview` — Previewable Languages Only)**:
  - Automatically surfaces **`◫ Preview` (`Open Preview to the Side`)** for previewable languages (`HTML` + live workspace `style.css`, `CSS`, `Markdown`, `JSON`, `YAML`/`TOML`, `SQL`, `Python`, `JavaScript`, and `TypeScript`) and cleanly omits preview UI on non-preview languages (`Luau`, `Rust`, `Go`, `C/C++`, `C#`, `Java`, `Shell`, `Plain Text`).
- **Mobile "Acode" Mode (Android / Touch Auto-Detect + Floating Movable Window + Play-While-Coding)**:
  - Floating, movable Mobile Mode window (with draggable `VS-RBLX ↗` minimized pill and `⤢` push/pull resize), `☰` slide-over Viewlet drawer, `42px` touch tabs with `‹ ›` scroll & `▾ N` Open Tabs picker, **Acode Quick-Keys bar** (including 1-tap `📋 Copy`, `📥 Paste`, `✦ AI`, `⚡ Autoexec`, symbols, and `▶ Run`), keyboard-aware scaling, and **`🎮 Play+Code`** split-peek docking.
- **Activity Bar & Side Bar Viewlets**:
  - **Explorer (`Ctrl+Shift+E`)**: Open Editors, inline file/folder creation & `F2` rename on Local Disk, **1-Click Standalone Project Bundler (`📦`)**, **Offline Workspace Snapshots (`VSRBLX/snapshots/`)**, **1-Click `autoexec/` Saver**, and live **Roblox DataModel Explorer** with **3D/GUI Eyedropper (`🎯`)**, **Live Property Tweaker**, **RemoteEvent `:FireServer` Snippet Generator**, and `decompile()` to disk.
  - **Search (`Ctrl+Shift+F`)**: Workspace-wide text search & multi-file replace (`Aa` case-sensitive & `[ab]` whole-word toggles).
  - **Source Control · GitHub (`Ctrl+Shift+G`)**: Clone repos, authenticate PATs, switch/create branches (including interactive Status Bar `⎇` branch picker), Stage/Unstage/Discard changes, **2-Pane Side-by-Side & Unified Diff Viewer**, **GitHub Gist Import & Publish**, Commit History, and **Commit & Push** directly to GitHub.
  - **Run & Debug (`Ctrl+Shift+D`)**: Run active Luau buffers (`F5`), stop active tasks, and inspect live Luau Watch Expressions.
  - **Extensions & Security Hub (`Ctrl+Shift+X`)**:
    - **Zero-Rate-Limit Static CDN Marketplace (`10/page` + `[⬇ Load 10 More]` + Sub-Issue SemVer)**: Compiles verified issues into static `registry/page-N.json` slices served via `raw.githubusercontent.com` Fastly CDN (avoiding GitHub's 60/hr IP rate limit) with search, template filters, and **automatic GitHub Sub-Issue newest-SemVer resolution** (strictly locked to the same GitHub author + `🛡 CLEAN` Malware Scan).
    - **Built-in Client Malware & Schema Scanner (`🛡 Scanner`)**: Blocks `loadstring`, webhooks, `HttpGet`/`request`, `getgenv`/`hookfunction`, obfuscators, escaped bytecode, and `github.*`/`vault.*`/`ai.*` credential settings.
    - **Host Capabilities, Themes & Languages**: Live Executor Capability Matrix, VS Code Color Themes (+ installed community Theme Packs), and 17 built-in language modes.
  - **Settings (`Ctrl+,`)**: Category filter pills, dropdown option menus, custom toggle-hotkey capture, `Reset`, and live raw `.vsrblx/settings.json` sync.
- **Monaco-Grade Multi-Tab & Split Code Editor (`Ctrl+\`) + Deep LSP-Style IntelliSense**:
  - **Deep LSP-Style IntelliSense (`Ctrl+Space` / `F12` / `Ctrl+Shift+I`)**: Live Roblox API & DataModel child Instance completion (`game`, `workspace`, `GetService("...")`, `Instance.new("...")`, `Enum.*`), local variable type inference, cross-file `require("...")` workspace module symbol indexing, floating **Parameter Signature Help**, **Hover Documentation Cards**, **`F12` Cross-File Go-to-Definition**, and expandable `$0` cursor-stop snippets.
  - Virtualized **RichText syntax highlighting**, **Rainbow Bracket Pair Colorization**, **Vertical Indent Guides**, **Sticky Scroll** scope header, **Live Git Gutter Diff Bars** (added/modified/deleted), **Inline Error Squiggles & Error Lens**, **Inline Color Swatches + HSV Color Picker**, smart auto-closing pairs & auto-indent, **15-Slot Clipboard Ring (`Ctrl+Shift+V`)**, **Crash-Proof Session & Unsaved Draft Auto-Recovery**, **Minimap**, and **Breadcrumbs**.
- **Integrated Bottom Panel (`Ctrl+J` / `` Ctrl+` ``)**:
  - **PROBLEMS** (live Luau & JSON diagnostics), **TODOS (`Ctrl+Shift+M`)** (`TODO`/`FIXME`/`BUG`/`HACK`/`NOTE` scanner), **OUTPUT** (live **Roblox `LogService.MessageOut`** stream with channel filters & clickable stack-trace file:line jump), **Multi-Session TERMINAL** (`+` new session, `Up`/`Down` history, `Tab` autocomplete, `ls -l`, `tree`, `cd`, `cat`, `head`, `tail`, `wc`, `cp`, `mv`, `echo >`/`>>`, `grep`, `find`, `git diff/stage/unstage/discard/log/branch/checkout/clone/pull/commit/push`, `gist import/publish`, `rblx services/tree/props/path/decompile`, `bundle`, `run`, `luau`), and **HTTP / GIT** network inspector.

### Draggable, Auto-Resized & Player-Resizable Window
- **Draggable**: Drag anywhere on the Title Bar; double-click the Title Bar to Maximize/Restore; drag to the top/left/right screen edges for **Aero-Snap** (full-screen or 50% split).
- **Auto-Resized**: Automatically adapts and clamps to `Workspace.CurrentCamera.ViewportSize` changes across desktop, compact, and mobile viewports.
- **Player-Resizable (8 Directions)**: Drag any of the 4 edges (`Left`, `Right`, `Top`, `Bottom`) or 4 corners (`TopLeft`, `TopRight`, `BottomLeft`, `BottomRight`) + bottom-right resize grip to resize freely, or minimize into the floating `VS-RBLX ↗` pill (`RightShift` toggles visibility).

### Local Disk Persistence (`writefile` / `readfile`)
- Automatically detects `writefile`, `readfile`, `appendfile`, `isfile`, `isfolder`, `makefolder`, `listfiles`, `delfile`, and `delfolder`.
- Persists workspaces cleanly under `VSRBLX/workspaces/<workspace>/` on your local disk, and supports mounting any existing folder inside your executor workspace (`File -> Mount Executor Folder...`).

### GitHub Sync via Executor HTTP
- Uses `request`, `http_request`, `syn.request`, `http.request`, `fluxus.request`, `game:HttpGet`, or `HttpService:RequestAsync`.
- Clones public or private GitHub repositories directly onto your executor's local disk, tracks dirty/staged changes against the remote tree, and pushes atomic commits via the GitHub Git Data REST API (with automatic Contents API fallback).

### 17 Built-in Languages & 8 Color Themes
- **Languages**: Luau / Lua, TypeScript, JavaScript, Python, JSON, HTML, CSS, Rust, Go, C / C++, C#, Java, SQL, Markdown, YAML / TOML, Shell (`sh`/`bash`), and Plain Text.
- **Themes**: Dark+ (Default), One Dark Pro, GitHub Dark, Monokai Classic, Dracula Official, Catppuccin Mocha, Solarized Dark, and Light+.

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `RightShift` | Show / Hide VS-RBLX Window |
| `F11` | Toggle Maximize / Restore Window |
| `Ctrl+Shift+P` / `F1` | Open Command Palette (`>`) |
| `Ctrl+P` | Quick Open File by Name |
| `Ctrl+S` / `Ctrl+Shift+S` | Save Active File / Save All to Disk (`writefile`) |
| `Ctrl+N` / `Ctrl+W` | New Scratch Buffer / Close Active Tab |
| `Ctrl+F` / `Ctrl+H` | Find / Find & Replace in Active File |
| `Ctrl+G` | Go to Line (`:`) |
| `Ctrl+Space` | Trigger LSP Autocomplete / Snippets |
| `F12` | Go to Definition (Local or Cross-File Module) |
| `Ctrl+Shift+I` | Show Hover Symbol Documentation |
| `Shift+Alt+F` | Format Document |
| `Ctrl+\` | Split Editor Right / Close Split |
| `Ctrl+B` | Toggle Primary Side Bar |
| `Ctrl+J` / `` Ctrl+` `` | Toggle Bottom Terminal & Output Panel |
| `F5` | Execute Active Luau Script |

---

## Repository Structure

```text
VS-RBLX/
├── init.lua                    # LocalScript / Executor entrypoint & env loader
├── README.md                   # Quick Start & feature overview
├── SPEC.md                     # Technical specification
├── AGENTS.md                   # Module authoring & verification guide
├── src/
│   ├── runtime/                # Signals, FS, 17-lang lexer, buffers, diff, search, git, runner
│   ├── net/                    # Executor HTTP transport, Base64, GitHub REST/Git Data API, Gist
│   ├── tools/                  # Formatter, GitHub sync, Disk sync, Decompiler, Terminal shell
│   ├── embedding/              # Scope isolation & getgenv().VSRBLX SDK
│   └── ui/
│       ├── code/               # Editor, Tabs, Breadcrumbs, Minimap, Diff View, Splitters, Terminal
│       └── panels/             # Explorer, Search, Source Control, GitHub Modal, Debug, Extensions, Settings
├── ui-lib/                     # Standalone lightweight draggable/resizable window library
├── tools/                      # Deterministic single-file bundler (bundle.lua) & FNV-1a build_id.lua
├── dist/
│   ├── vsrblx.lua              # Single-file Executor bundle (loaded via game:HttpGet)
│   ├── vsrblx.localscript.lua  # Single-file Studio LocalScript bundle
│   └── vsrblx.manifest.json    # Build metadata, SHA/FNV-1a stamp & module list
├── test/                       # Static checker (check.lua), Roblox/Executor mocks & test suite (run.lua)
├── docs/                       # Architecture documentation
└── assets/                     # Vector logo emblem
```

---

## Building & Testing Offline

```bash
# 1. Static syntax & require-graph check across init.lua + all 91 modules
luajit test/check.lua

# 2. Bundle all modules into dist/vsrblx.lua & dist/vsrblx.localscript.lua
luajit tools/bundle.lua

# 3. Run the end-to-end headless UI, Disk FS, Vault, AI Agent, CDN Hub & Window test suite
luajit test/run.lua
```

---

## Credits & Open-Source Acknowledgments

- **VS-RBLX Integrated AI Agent Engineering**: Clean-room VS Code Secondary Sidebar & `Ctrl+I` Inline Editor built natively for VS-RBLX, with architectural inspiration (buffered executor SSE replay, smallest-complete-change `workspace_edit_file`, 3-tier `Read Only / Ask First / Auto` permission gating, and cooperative loop-deadline Luau execution checkpoints) credited to **[Project UAI (`Project-Ptolemy/ProjectUAI`)](https://github.com/Project-Ptolemy/ProjectUAI)** by **CarlDV / Project-Ptolemy** *(MIT License)*.

