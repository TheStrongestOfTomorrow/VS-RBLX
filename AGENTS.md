# AGENTS.md — Contributor & Authoring Rules for VS-RBLX

## Module Contract
1. Every module under `src/` must return a factory function: `return function(env) ... end`.
2. Resolve internal dependencies strictly with `env.require("category/name")` (no `script.Parent` chains).
3. Keep all Luau code compatible with both Roblox Luau and offline LuaJIT verification (`test/check.lua` and `test/run.lua`): avoid Luau type annotations (`x: number`), backtick string interpolation, `continue`, floor division `//`, and compound assignments (`+=`, `..=`).

## Verification Pipeline
Before committing changes to `init.lua` or `src/**`, run:
```bash
luajit test/check.lua init.lua src
luajit tools/bundle.lua
luajit test/run.lua
```
Ensure `dist/vsrblx.lua`, `dist/vsrblx.localscript.lua`, and `dist/vsrblx.manifest.json` stay up to date whenever `src/**` or `init.lua` changes.
