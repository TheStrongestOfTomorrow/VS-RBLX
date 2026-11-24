# VS-RBLX — Visual Studio Code for Roblox (100% Luau)

**VS-RBLX** is a full-featured **Visual Studio Code clone** built in **100% client-side Luau** for Roblox Executors and LocalScripts. It brings a multi-tab syntax-highlighted IDE, **local disk persistence** (`writefile` / `readfile`), **GitHub repository sync** (`request` / `http_request`), an integrated terminal, unified Git diffs, IntelliSense, and a draggable, viewport-auto-resized, 8-direction player-resizable workbench directly inside Roblox.

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
- **Title Bar**: VS-RBLX emblem, top dropdown menus (`File`, `Edit`, `View`, `Run`, `GitHub`), centered Command Center search pill (`Ctrl+P`), layout toggles, and Minimize / Maximize / Close controls.
- **Activity Bar & Side Bar Viewlets**:
  - **Explorer (`Ctrl+Shift+E`)**: Open Editors, Local Disk File Tree (`writefile`/`readfile`/`makefolder`/`delfile`), and live **Roblox DataModel Explorer** (`Workspace`, `ReplicatedStorage`, `Players`, etc.) to inspect or import in-game `LocalScript`/`ModuleScript` sources onto disk.
  - **Search (`Ctrl+Shift+F`)**: Workspace-wide text search & multi-file replace (`Aa` case-sensitive & `[ab]` whole-word toggles).
  - **Source Control · GitHub (`Ctrl+Shift+G`)**: Clone repos, authenticate PATs, browse your GitHub repos, switch/create branches, stage/unstage/discard changes, inspect colorized **Unified Diffs**, and **Commit & Push** directly to GitHub.
  - **Run & Debug (`Ctrl+Shift+D`)**: Run active Luau buffers (`F5`), stop active tasks, and inspect live Luau Watch Expressions.
  - **Extensions & Capabilities (`Ctrl+Shift+X`)**: Live Executor Capability Matrix, 8 VS Code Color Themes, and 17 built-in language modes.
  - **Settings (`Ctrl+,`)**: Interactive settings editor persisted to `VSRBLX/settings.json`.
- **Multi-Tab & Split Code Editor (`Ctrl+\`)**:
  - Virtualized **RichText syntax highlighting**, Gutter line numbers, active-line highlight, error/warning gutter markers, **Minimap**, **Breadcrumbs** with symbol jump (`ƒ`), inline **Find & Replace (`Ctrl+F` / `Ctrl+H`)**, and **IntelliSense** completions.
- **Integrated Bottom Panel (`Ctrl+J` / `` Ctrl+` ``)**:
  - **PROBLEMS** (live Luau & JSON diagnostics), **OUTPUT** (`print`/`warn` streams), **TERMINAL** (`ls`, `cd`, `cat`, `touch`, `mkdir`, `rm`, `run`, `luau`, `git status`, `git clone`, `git pull`, `git push`, `gh auth`, `http get`), and **HTTP / GIT** network inspector.

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
# 1. Static syntax & require-graph check across all 69 modules
luajit test/check.lua init.lua src

# 2. Bundle all modules into dist/vsrblx.lua & dist/vsrblx.localscript.lua
luajit tools/bundle.lua

# 3. Run the end-to-end headless UI, Disk FS, GitHub HTTP & Window resize test suite
luajit test/run.lua
```
