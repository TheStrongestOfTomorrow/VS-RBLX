# VS-RBLX Technical Specification

**VS-RBLX** is a Visual Studio Code clone built in **100% client-side Luau** for Roblox Executors and LocalScripts.

## 1. Execution & Bundling Model

- **Source Modules (`src/**/*.lua`)**: Each module exports `return function(env) ... end` and resolves sibling modules exclusively via `env.require("layer/module")`.
- **Entrypoint (`init.lua`)**: Probes Roblox services and executor globals (`getgenv`, `gethui`, `writefile`, `readfile`, `listfiles`, `makefolder`, `delfile`, `delfolder`, `request`, `http_request`, `syn.request`, `loadstring`, `setclipboard`, `decompile`), constructs `env`, mounts the workbench UI, and registers the public SDK handle on `getgenv().VSRBLX`.
- **Bundled Distribution (`dist/vsrblx.lua`)**: `tools/bundle.lua` packs all 69 `src/` modules + `init.lua` into a single deterministic Luau script (`__VSRBLX_MODULES` + FNV-1a build stamp `__VSRBLX_BUILD`) designed to run directly from `loadstring(game:HttpGet(...))()`.
- **LocalScript Distribution (`dist/vsrblx.localscript.lua`)**: Identical single-file bundle usable inside Roblox Studio `StarterPlayerScripts` with automatic in-memory fallback when executor filesystem/HTTP globals are absent.

## 2. Local Disk Persistence (`src/runtime/fsx.lua` & `src/runtime/workspace_fs.lua`)

- Uses executor filesystem APIs (`writefile`, `readfile`, `appendfile`, `isfile`, `isfolder`, `makefolder`, `listfiles`, `delfile`, `delfolder`).
- Stores configuration, Git metadata, and isolated workspaces under `VSRBLX/workspaces/<name>/` on the player's local disk, and also supports mounting any raw executor folder directly (`workspace.mountRaw`).
- Sanitises relative paths to block `..` traversal outside workspace scope unless raw folder mode is explicitly chosen by the user.

## 3. GitHub HTTP Sync (`src/net/http.lua`, `src/net/github.lua`, `src/tools/github_sync.lua`)

- Routes HTTP traffic through `request` -> `http_request` -> `syn.request` -> `http.request` -> `fluxus.request` -> `game:HttpGet` -> `HttpService:RequestAsync`.
- Supports public & private repository cloning (`GET /repos/{owner}/{repo}/git/trees/{branch}?recursive=1` + `raw.githubusercontent.com` / Base64 Git Blob fallback), branch switching/creation, pull, unified working-tree diffs, and atomic multi-file commit + push via the GitHub Git Data API (`/git/blobs`, `/git/trees`, `/git/commits`, `/git/refs/heads/{branch}`) with Contents API fallback.

## 4. Windowing & Workbench (`src/ui/window.lua` & `src/ui/app.lua`)

- **Draggable**: Drag via the Title Bar; double-click Title Bar to toggle Maximize/Restore; drag to screen edges for Aero-Snap (top = full maximize, left/right = 50% split).
- **Viewport Auto-Resized**: Observes `Workspace.CurrentCamera.ViewportSize` (`src/ui/responsive.lua`) and automatically scales/clamps the window within usable screen bounds.
- **8-Direction Player Resizable**: Interactive edge and corner handles (`ResizeLeft`, `ResizeRight`, `ResizeTop`, `ResizeBottom`, `ResizeTopLeft`, `ResizeTopRight`, `ResizeBottomLeft`, `ResizeBottomRight`) plus a bottom-right corner grip allow players to resize the IDE freely.
