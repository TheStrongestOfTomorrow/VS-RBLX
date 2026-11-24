# VS-RBLX Architecture Guide

## Layer Breakdown

| Directory | Responsibility |
|---|---|
| `init.lua` | Root LocalScript/Executor loader, `env` factory, hot-reload teardown, and `getgenv().VSRBLX` registration |
| `src/runtime/` | Signals, disposables, capability probing (`caps`), local disk I/O (`fsx`, `workspace_fs`), 17-language registry & incremental RichText lexer (`languages`, `code_lexer`), multi-tab buffer store (`code_store`), Myers/LCS diff (`code_diff`), workspace search (`code_search`), IntelliSense (`intellisense`), diagnostics (`diagnostics`), local Git index (`git_state`), Luau sandbox runner (`runner`), commands & shortcuts |
| `src/net/` | Pure-Luau Base64 (`base64`), URL parser (`url`), HTTP client (`http`), GitHub REST + Git Data API client (`github`), and raw URL / Gist importer (`gist`) |
| `src/tools/` | Multi-language code formatter (`formatter`), GitHub <-> Disk sync (`github_sync`), disk workspace switcher (`fs_sync`), script runner (`execution`), DataModel script importer (`decompiler`), and integrated terminal shell (`terminal_cmds`) |
| `src/ui/` | 8 VS Code color themes (`theme`), viewport observer (`responsive`), UI primitives (`primitives`), procedural vector Codicons (`icons`), draggable + auto-resized + 8-way player-resizable window (`window`), Title Bar (`titlebar`), Activity Bar (`activitybar`), Status Bar (`statusbar`), Command Palette (`command_palette`), and Workbench orchestrator (`app`) |
| `src/ui/code/` | Editor Tab Bar (`tabs`), Breadcrumbs (`breadcrumbs`), virtualized RichText Code Editor + Gutter + Find/Replace + IntelliSense (`editor`), Minimap (`minimap`), Unified Diff Viewer (`diff_view`), Welcome Screen (`welcome`), Splitters (`splitter`), File Tree (`explorer`), and Bottom Panel (`terminal`) |
| `src/ui/panels/` | Explorer (`explorer`), Workspace Search (`search`), Source Control / GitHub (`scm`), GitHub Connect Modal (`github_connect`), Run & Debug (`debug`), Extensions & Capabilities (`extensions`), and Settings (`settings`) |
| `src/embedding/` | Namespace isolation (`scope`) and public `getgenv().VSRBLX` programmatic SDK (`sdk`) |
| `tools/` | Single-file deterministic Luau bundler (`bundle.lua`) and 64-bit FNV-1a build ID generator (`build_id.lua`) |
| `test/` | Static syntax & require-graph verifier (`check.lua`), headless Roblox + Executor FS/HTTP mock (`mock/*`), and end-to-end test suite (`run.lua`) |
