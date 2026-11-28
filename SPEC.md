# VS-RBLX Technical Specification

**VS-RBLX** is a Visual Studio Code clone built in **100% client-side Luau** for Roblox Executors and LocalScripts.

## 1. Execution & Bundling Model

- **Source Modules (`src/**/*.lua`)**: Each module exports `return function(env) ... end` and resolves sibling modules exclusively via `env.require("layer/module")`.
- **Entrypoint (`init.lua`)**: Probes Roblox services and executor globals (`getgenv`, `gethui`, `writefile`, `readfile`, `listfiles`, `makefolder`, `delfile`, `delfolder`, `request`, `http_request`, `syn.request`, `loadstring`, `setclipboard`, `decompile`), constructs `env`, mounts the workbench UI, and registers the public SDK handle on `getgenv().VSRBLX`.
- **Bundled Distribution (`dist/vsrblx.lua`)**: `tools/bundle.lua` packs all 93 `src/` modules + `init.lua` into a single deterministic Luau script (`__VSRBLX_MODULES` + FNV-1a build stamp `__VSRBLX_BUILD`) designed to run directly from `loadstring(game:HttpGet(...))()`.
- **LocalScript Distribution (`dist/vsrblx.localscript.lua`)**: Identical single-file bundle usable inside Roblox Studio `StarterPlayerScripts` with automatic in-memory fallback when executor filesystem/HTTP globals are absent.

## 2. Local Disk Persistence (`src/runtime/fsx.lua` & `src/runtime/workspace_fs.lua`)

- Uses executor filesystem APIs (`writefile`, `readfile`, `appendfile`, `isfile`, `isfolder`, `makefolder`, `listfiles`, `delfile`, `delfolder`).
- Stores configuration, Git metadata, and isolated workspaces under `VSRBLX/workspaces/<name>/` on the player's local disk, and also supports mounting any raw executor folder directly (`workspace.mountRaw`).
- Sanitises relative paths to block `..` traversal outside workspace scope unless raw folder mode is explicitly chosen by the user.
- The AI agent stores saved conversations in `VSRBLX/ai/threads/index.json` (legacy `ai/history.json` is migrated), with a 30-thread cap and 30 retained transcript entries per thread. Threads support create, switch, rename, archive/restore, delete, title/transcript search, and JSON export to `VSRBLX/ai/exports/`; this storage is local and unencrypted unless the user separately protects the executor storage.

## 3. GitHub HTTP Sync (`src/net/http.lua`, `src/net/github.lua`, `src/tools/github_sync.lua`)

- Routes HTTP traffic through `request` -> `http_request` -> `syn.request` -> `http.request` -> `fluxus.request` -> `game:HttpGet` -> `HttpService:RequestAsync`.
- Supports public & private repository cloning (`GET /repos/{owner}/{repo}/git/trees/{branch}?recursive=1` + `raw.githubusercontent.com` / Base64 Git Blob fallback), branch switching/creation, pull, unified working-tree diffs, and atomic multi-file commit + push via the GitHub Git Data API (`/git/blobs`, `/git/trees`, `/git/commits`, `/git/refs/heads/{branch}`) with Contents API fallback.

## 4. Community extensions and release authority

- The community submission form and client/runtime remain aligned on the same five data-only templates. New formats are not advertised until their runtime, validator, scanner, tests, and docs land together. `CONTRIBUTING_EXTENSIONS.md` is the canonical contributor guide.
- Extension version issues require a valid parent issue number, the parent issue creator's GitHub identity, matching extension ID/template, and strict increasing SemVer. GitHub Actions validates and links passing issues as sub-issues. Registry compilation only considers linked sub-issues carrying the gatekeeper's `community-extension-version` label; same-author checks and malware/schema checks run again.
- Ordinary `issue_comment` events do not trigger the release workflow and comments are not registry inputs. Registry version history records issue number, author, stable SHA-256 of the canonical manifest, and scan-policy/verdict metadata. Rejected issues get audit labels and findings; false-positive review does not bypass scanner policy.
- Extension installation/update remains user initiated. Store detail-tab redesign and live Roblox-client marketplace checks remain outstanding.

## 5. Windowing & Workbench (`src/ui/window.lua` & `src/ui/app.lua`)

- **Draggable**: Drag via the Title Bar; double-click Title Bar to toggle Maximize/Restore; drag to screen edges for Aero-Snap (top = full maximize, left/right = 50% split).
- **Viewport Auto-Resized**: Observes `Workspace.CurrentCamera.ViewportSize` (`src/ui/responsive.lua`) and automatically scales/clamps the window within usable screen bounds.
- **8-Direction Player Resizable**: Interactive edge and corner handles (`ResizeLeft`, `ResizeRight`, `ResizeTop`, `ResizeBottom`, `ResizeTopLeft`, `ResizeTopRight`, `ResizeBottomLeft`, `ResizeBottomRight`) plus a bottom-right corner grip allow players to resize the IDE freely.
- **Compact Layout Guardrails**: The usable rectangle reflects the real viewport and virtual-keyboard inset (it does not invent a minimum screen size). Narrow touch Desktop Mode keeps Desktop styling while collapsing the Activity Bar, using a temporary workspace drawer, enlarging tab targets, and preserving a full-width editor when the drawer is closed; compact split/preview panes are suppressed, and Play-While-Coding uses a narrower right dock to leave gameplay space. Acode Mode remains a separate explicit choice. The mobile AI sidebar overlays instead of permanently reducing editor width. The editor scrolls its rendered caret into view during typing and cursor navigation. Headless tests cover compact touch Desktop and keyboard bounds, live TextBox smart-pair input, and caret reveal in long files; visual smoke checks are still required on actual Roblox clients.

### AI context and filesystem scopes

- AI project tools recursively inspect and search the active project workspace; listing and large text reads are paged/bounded. Other project names are discoverable without exposing their contents. Reading/listing/searching a non-active project requires a thread-scoped `workspace_authorize_project` call that always pauses for explicit in-UI user approval; the grant is read-only and resets when changing AI threads. It does not change the active editor workspace.
- Live DataModel inspection is a distinct read-only scope: recursive tree traversal is capped to depth 4 / 120 instances per call, and script source reads are capped to 64 KiB. Executor capabilities may prevent Source access; decompilation is used only when the host exposes it.
- Generated artifacts use a distinct executor-backed per-thread scope under `ai/workspaces/threads/<thread-id>`, separate from project workspaces and `ai/threads` conversation data. A prior `ai/workspaces/default` artifact directory is preserved and assigned to the first recorded thread rather than migrated or deleted. AI workspace tools can list/read/write only in the active thread's scope, with path traversal and 8 MiB file-size bounds. Transfers into a project remain explicit `ai_workspace_transfer_to_project` actions that always require a dedicated in-UI approval (including Auto Edit); existing destinations require separate overwrite approval. No live DataModel mutation or implicit promotion is provided.
- Existing project write/edit tools continue to act only on the active workspace and retain the agent's configured permission mode. Live-game mutation is not added as an AI tool in this slice.
