# Project UAI integration contract

VS-RBLX offers an optional, user-started bridge to the separately maintained Project UAI client. This integration is not a fork, bundled copy, community-extension release, or update manager.

## Upstream public contract checked

The adapter follows Project UAI's public embedding documentation and client handle rather than inspecting private modules:

- Project: <https://github.com/Project-Ptolemy/ProjectUAI>
- Embedding reference: <https://github.com/Project-Ptolemy/ProjectUAI/blob/main/docs/EMBEDDING.md>
- Published entry point documented upstream: `dist/uai.lua`
- Documented handle fields: `alive`, `version`, `build`, and `sdk`
- Required documented SDK contract: SDK `1.1.0+`, `sdk.features.requests`, `sdk.features.resourceScopes`, `sdk.createScope`, `sdk.request`, `sessions.open`, and `show(panel)`
- Upstream embedding version at the time this adapter was implemented: Project UAI 4.1.1 / SDK 1.1.0. The upstream contract evolves independently; this value is recorded as an observed compatibility baseline, not a pinned release.

The adapter is intentionally narrow. It checks the public handle/capability contract and calls `uai.show("chat")`. It does not patch `env.require`, replace UAI modules, register tools/providers, copy project files, create a conversation, alter permissions, or claim that UAI is sandboxed from the executor.

## User controls and lifecycle

- VS-RBLX performs **no UAI network request or loader execution during startup**.
- Selecting **Project UAI** while no compatible live handle is detected presents an explicit confirmation first. Only then does VS-RBLX fetch the upstream `main/dist/uai.lua` entry point, compile it through host capabilities, and call its documented loader with `ui = false`, `reuse = true`, and a limited host prompt. The user may cancel before any fetch/compile.
- If a live `getgenv().UAI` handle exists, VS-RBLX checks it and uses its public `show("chat")` method. A stopped or incompatible handle is reported; VS-RBLX does not overwrite or replace it.
- The `main` URL is deliberate: **Project UAI owns its own updates**. VS-RBLX does not pin a revision, poll/update UAI, replace its updater, or route UAI releases through community-extension SemVer. The UAI button is user initiated, so upstream changes are surfaced when the user opens the integration rather than silently applied at VS-RBLX startup.
- UAI's own password/vault/provider/permission setup and admission behavior remain UAI-owned. The bridge does not bypass the vault, configure a provider, or silently retry a rejected request.

## Fail-safe compatibility behavior

`src/ai/uai_adapter.lua` reads only the documented global handle. If the handle is absent, explicit user consent is required to load the official distribution. If a detected/loaded handle lacks the required SDK version or feature flags, or `show("chat")` errors/rejects admission, the adapter reports incompatibility and stops. It does not fall back to private APIs or another local copy.

Upstream can change after this compatibility check. If integration breaks, update the adapter only against a newly documented public upstream contract and add regression coverage. Do not claim compatibility solely because a version string exists; the required methods and feature flags must also be present.

## Trust boundary

VS-RBLX and Project UAI execute in the same Roblox executor environment. This bridge cannot isolate UAI from executor capabilities or guarantee that a third-party provider/tool is safe. The confirmation text says so. Users must review UAI's own permission mode, provider settings, and project/game scope before use. No user project data is copied into the bridge prompt.

## Attribution

VS-RBLX credits Project UAI and its maintainer in the AI sidebar and project documentation for permissioned integration and architectural inspiration. Project UAI remains an independently maintained upstream project; its source and self-updater are not copied or controlled here.
