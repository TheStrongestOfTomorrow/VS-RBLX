# VS-RBLX Community Extensions: Contributor Guide

This guide explains how to propose, test, review, and update a community extension. Community extensions are **data-only declarative manifests**. They are not arbitrary Lua plugins and do not run code from GitHub.

## 1. Supported formats and boundaries

The form, client runtime, issue validator, malware scanner, and static registry currently support exactly these five template IDs:

| Template | What it can provide | Manifest payload |
|---|---|---|
| `theme-pack` | Theme color and syntax-token overrides | `theme.colors` and optional `theme.syntax` maps of six-digit hex colors |
| `snippet-pack` | Text snippets inserted by a trigger | `snippets`: 1–25 `{trigger,label,detail,body}` entries; `trigger` uses letters, digits, `_`, or `-`; `body` is inserted as text |
| `command-macro` | A short sequence of built-in safe editor/workbench actions | `macros`: 1–10 entries, each with 1–8 allow-listed declarative steps |
| `keymap-preset` | Keyboard shortcuts mapped to existing non-execution commands | `keymap.bindings`: 1–30 `{key,command}` entries; commands beginning with `run.` are not allowed |
| `toolbar-tool` | Built-in, bounded text transformations | `tools`: 1–6 entries using a supported transform such as `uppercase`, `lowercase`, `sortLines`, `trimLines`, `wrapPcall`, or `insertHeader` |

Do not submit a new template ID unless its data model, runtime behavior, validation rules, malware checks, issue form, tests, docs, and registry compatibility are implemented together. A form dropdown alone does not make a template supported.

Community manifests must not contain executable Luau, serialized bytecode, dynamic code loading, outbound requests, external callbacks, credential access, executor APIs, direct filesystem operations, hooks, obfuscated content, or instructions to evade Roblox/VS-RBLX security. The extension trust boundary is intentionally narrow: data is validated and interpreted only by the matching built-in VS-RBLX feature.

## 2. Before opening an issue

1. **Check for duplicates.** Search open and closed issues for the same purpose and extension ID. Discuss substantial changes on the parent issue before proposing them.
2. **Choose one existing template.** If the desired capability cannot be expressed by one of the five formats above, it is not currently an eligible community extension.
3. **Use a stable ID.** Use lowercase kebab-case, 2–48 characters. IDs identify an extension across releases; do not change the ID when updating it.
4. **Test in VS-RBLX first.** Use the in-client Extensions scanner/template preview, inspect validation feedback, and verify the behavior using a safe workspace or a private Roblox Studio place. Never test by invoking an untrusted executable payload.
5. **Respect licensing.** Submit original work or work you are authorized to distribute. Include attribution and license details in the description when required. Do not upload private source, secrets, player data, or assets you do not have rights to share.

## 3. Initial submission

Use **Issues → Community Extension Submission**. Fill in every required field and paste pure JSON in the manifest field. The form's template, ID, name, version, and summary must agree with the JSON manifest. The initial release normally starts at `1.0.0`; choose another version only when the project genuinely has a pre-release history and explain it in the summary.

The manifest root includes `id`, `name`, `version`, `author`, `summary`, and `template`, followed by exactly the payload relevant to the chosen template. Keep the manifest small and readable. Do not add custom root keys, scripts, links, or hidden data. A minimal example for each type follows.

### Theme pack

```json
{
  "id": "aurora-midnight",
  "name": "Aurora Midnight",
  "version": "1.0.0",
  "author": "your-github-username",
  "summary": "A calm dark palette for focused editing.",
  "template": "theme-pack",
  "theme": {
    "isLight": false,
    "colors": { "editor": "#10131c", "sideBar": "#151a26", "accent": "#7dd3c7" },
    "syntax": { "keyword": "#c4a7e7", "string": "#a8d5a2", "comment": "#778092" }
  }
}
```

Every color must be a six-digit hex value. Check contrast in both editor and surrounding workbench surfaces. Do not assume a color works equally well for light and dark UI.

### Snippet pack

```json
{
  "id": "luau-guard-snippets",
  "name": "Luau Guard Snippets",
  "version": "1.0.0",
  "author": "your-github-username",
  "summary": "Small text-only Luau error-handling patterns.",
  "template": "snippet-pack",
  "snippets": [
    { "trigger": "pcallx", "label": "Protected call", "detail": "Wrap a call in pcall", "body": "local ok, result = pcall(function()\n\t$0\nend)" }
  ]
}
```

Snippet bodies are inserted as text; they are not executed by the marketplace. Keep snippets short, explain placeholders, and avoid patterns that silently perform destructive or privileged actions.

### Command macro

```json
{
  "id": "module-header-macro",
  "name": "Module Header Macro",
  "version": "1.0.0",
  "author": "your-github-username",
  "summary": "Adds a documented header using built-in editor actions.",
  "template": "command-macro",
  "macros": [
    { "id": "insertHeader", "title": "Insert Module Header", "steps": [
      { "op": "insertText", "text": "-- Module description\n-- Maintainer: $0\n\n" },
      { "op": "toast", "text": "Header inserted" }
    ] }
  ]
}
```

Only runtime allow-listed operations are accepted. A macro cannot define its own operation, invoke arbitrary commands, or access protected settings/files.

### Keymap preset

```json
{
  "id": "focused-luau-keymap",
  "name": "Focused Luau Keymap",
  "version": "1.0.0",
  "author": "your-github-username",
  "summary": "Convenience bindings for existing editor commands.",
  "template": "keymap-preset",
  "keymap": { "bindings": [
    { "key": "F9", "command": "view.problems" },
    { "key": "F10", "command": "ai.toggleChat" }
  ] }
}
```

Use existing commands only and avoid surprising conflicts with common Roblox, operating-system, or VS-RBLX shortcuts. No binding may start arbitrary execution.

### Toolbar tool

```json
{
  "id": "text-cleanup-tools",
  "name": "Text Cleanup Tools",
  "version": "1.0.0",
  "author": "your-github-username",
  "summary": "A few predictable built-in text transforms.",
  "template": "toolbar-tool",
  "tools": [
    { "id": "sortLines", "label": "Sort Lines", "transform": "sortLines" },
    { "id": "trimLines", "label": "Trim Trailing Spaces", "transform": "trimLines" }
  ]
}
```

Only the runtime's fixed transform list is supported. A custom transform name is not an extension point.

## 4. Review and publication

On issue open, edit, or reopen, GitHub Actions checks the form/manifest schema and scans submitted content. A clean issue is labeled and becomes eligible for the static registry. Invalid submissions receive findings and may be closed; clearly malicious submissions may also be locked. Fix the reported issue by editing the original parent issue and wait for the gatekeeper to run again.

The review process is not an endorsement of every design choice. Maintainers and community members may review the extension in comments. Comments remain available for ordinary feedback, support, and discussion; **a comment is never a version release** and does not change the registry.

The marketplace registry is compiled into small static CDN pages (currently 10 entries per page). Publication happens when the repository's Actions workflow successfully rebuilds and commits the registry. CDN/cache propagation may add a delay. The client may also cache registry pages locally; use the extension hub's refresh/sync control if an accepted item does not appear immediately. Do not repeatedly submit duplicate issues to force a refresh.

## 5. Publishing a version update

Only the GitHub account that authored the parent `[EXT]` issue may publish a version update. Open **Community Extension Version Update** as a new issue and:

1. Enter the parent issue number.
2. Keep the original extension ID, display name, and template unchanged.
3. Increment the strict `X.Y.Z` version and provide the complete new manifest.
4. Explain user-visible changes and compatibility risks in the changelog.
5. Complete all ownership, safety, attribution, and licensing attestations.

Actions compare the submitter with the parent author, rescan the manifest, and validate identity/template/version consistency before linking the version issue as a sub-issue. A version issue from another account is rejected; do not ask a maintainer to treat a comment as a release. Only verified linked version sub-issues participate in SemVer resolution. The highest valid clean version is offered to installed users as an update; installing the update remains a player action.

Do not edit an accepted parent issue's manifest or original version to publish an update; the accepted parent manifest is immutable and an attempted manifest change is rejected. Preserve its initial release record and use a new owner-authored version issue for every release. Contact maintainers through normal discussion if ownership or accessibility of the original account has changed; staff must not silently manufacture an owner release.

## 6. Troubleshooting

- **Template/manifest mismatch:** Ensure the selected dropdown, `manifest.template`, form ID, manifest ID, form version, manifest version, display name, and manifest name match exactly.
- **Invalid JSON:** Remove comments and trailing commas; use double-quoted keys/strings and valid JSON escapes. Do not wrap the JSON in a second JSON string.
- **Unsupported field or operation:** Remove custom keys and use only fields and operations documented for that template. The schema is deliberately allow-listed.
- **Security finding:** Read the gatekeeper's exact field/reason. Remove the unsafe content; do not disguise, split, or encode it. If you believe a clean sample is a false positive, ask in the issue's ordinary comments for maintainer review. Failed issues receive a `extension-review-needed` or `extension-malware-flagged` audit label and exact findings; maintainers review scanner-rule changes through normal code review. No label or comment bypasses validation.
- **Version issue rejected:** Confirm that the parent issue number is correct, you are the parent issue author, the extension is still valid, the ID and template are unchanged, and SemVer is strictly increasing.
- **Accepted issue missing in the client:** Check Actions completion, verify the parent has the `verified-template` label, wait for registry/CDN propagation, and refresh the extension hub.
- **Compatibility report:** Provide VS-RBLX version/build, Roblox client/platform, exact steps, and a sanitized screenshot or manifest excerpt. Never include account tokens, private project source, or player identifiers.

## 7. Security, moderation, and reporting

The issue form and CI scanner are defensive layers, not a promise that remote user content is risk-free. VS-RBLX validates a limited data schema and uses built-in handlers. Report a suspected malicious extension with its parent/version issue number and a concise explanation. Keep reports factual; false positives can be reviewed, and ordinary comments do not become registry metadata.

Project UAI has a separate upstream ownership and self-update lifecycle. It is not a community extension release family and must not be versioned, pinned, or replaced through this issue workflow.
