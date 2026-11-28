#!/usr/bin/env node
/** Validate an owner-authored community-extension version issue against its parent. */
"use strict";

const { validateIssue, parseIssueMarkdown } = require("./validate_extension_issue.js");

function parseVersionIssueNumber(body) {
  const match = String(body || "").match(/^###\s+Parent Extension Issue\s*\n+(?:#|https:\/\/github\.com\/[^\s/]+\/[^\s/]+\/issues\/)?(\d+)\s*$/im);
  return match ? Number(match[1]) : null;
}

function parseSemver(version) {
  const match = String(version || "").match(/^(\d+)\.(\d+)\.(\d+)$/);
  return match ? match.slice(1).map(Number) : null;
}

function compareSemver(a, b) {
  const left = parseSemver(a);
  const right = parseSemver(b);
  if (!left || !right) return null;
  for (let i = 0; i < 3; i++) if (left[i] !== right[i]) return left[i] > right[i] ? 1 : -1;
  return 0;
}

function validateExtensionVersion(input) {
  const findings = [];
  const childTitle = String(input.title || "");
  if (!/^\[EXT-VERSION\]\s+/i.test(childTitle)) findings.push("Version issue title must begin with [EXT-VERSION].");
  const body = String(input.body || "");
  const parentNumber = parseVersionIssueNumber(body);
  if (!parentNumber || parentNumber !== Number(input.parentNumber)) findings.push("Parent Extension Issue must contain a valid issue number matching the fetched parent.");

  const childAuthor = String(input.author || "").trim().toLowerCase();
  const parentAuthor = String(input.parentAuthor || "").trim().toLowerCase();
  if (!childAuthor || !parentAuthor || childAuthor !== parentAuthor) {
    findings.push("Only the author of the parent extension issue may publish a version sub-issue.");
  }

  const parentScan = validateIssue(input.parentTitle || "", input.parentBody || "");
  if (!parentScan.ok || !parentScan.manifest) findings.push("Parent extension issue is not a currently valid community extension.");
  const childScan = validateIssue(childTitle, body);
  if (!childScan.ok || !childScan.manifest) findings.push(...childScan.findings.map((item) => `Version manifest: ${item}`));

  if (parentScan.manifest && childScan.manifest) {
    if (parentScan.manifest.id !== childScan.manifest.id) findings.push("Version manifest ID must match the parent extension ID.");
    if (parentScan.manifest.template !== childScan.manifest.template) findings.push("Version manifest template must match the parent extension template.");
    if (String(childScan.manifest.author || "").trim().toLowerCase() !== parentAuthor) findings.push("Version manifest author must match the GitHub author of the parent issue.");
    const order = compareSemver(childScan.manifest.version, parentScan.manifest.version);
    if (order === null || order <= 0) findings.push("Version must be a strict SemVer greater than the parent issue's original version.");
  }

  return {
    ok: findings.length === 0,
    malicious: childScan.malicious === true,
    findings,
    parentNumber,
    manifest: findings.length === 0 ? childScan.manifest : null,
  };
}

function selfTest() {
  const parentManifest = {
    id: "test-owned-extension", name: "Test Owned Extension", version: "1.0.0", author: "parent-owner",
    summary: "Test declarative extension.", template: "theme-pack", theme: { colors: { editor: "#101010" } },
  };
  const childManifest = { ...parentManifest, version: "1.1.0" };
  const issueBody = (manifest, extra = "") => [
    "### Parent Extension Issue", "#41", "", "### Extension Template", manifest.template,
    "", "### Extension ID", manifest.id, "", "### Display Name", manifest.name,
    "", "### Version", manifest.version, "", "### Summary", manifest.summary,
    "", "### Manifest JSON", "```json", JSON.stringify(manifest), "```",
    "", "### Security Attestations",
    "- [X] I am the GitHub author of the parent extension issue.",
    "- [X] This is a complete supported declarative manifest with no executable code.",
    "- [X] I have preserved original attribution and licensing.", "", extra,
  ].join("\n");
  const baseBody = [
    "### Extension Template", parentManifest.template, "", "### Extension ID", parentManifest.id,
    "", "### Display Name", parentManifest.name, "", "### Version", parentManifest.version,
    "", "### Summary", parentManifest.summary, "", "### Manifest JSON", "```json",
    JSON.stringify(parentManifest), "```", "", "### Security Attestations",
    "- [X] I selected one of the five supported declarative templates.",
    "- [X] This submission contains no outbound requests or credential access.",
    "- [X] I created this work or have permission to distribute it.",
    "- [X] I understand comments are discussion, not releases.",
  ].join("\n");
  const common = {
    title: "[EXT-VERSION] Test Owned Extension v1.1.0", body: issueBody(childManifest), author: "Parent-Owner",
    parentNumber: 41, parentAuthor: "parent-owner", parentTitle: "[EXT] Test Owned Extension", parentBody: baseBody,
  };
  if (!validateExtensionVersion(common).ok) throw new Error("valid parent-owner version rejected");
  if (validateExtensionVersion({ ...common, author: "unrelated-user" }).ok) throw new Error("non-owner version issue accepted");
  if (validateExtensionVersion({ ...common, body: issueBody({ ...childManifest, version: "1.0.0" }) }).ok) throw new Error("non-incrementing SemVer accepted");
  if (validateExtensionVersion({ ...common, body: issueBody({ ...childManifest, id: "different-id" }) }).ok) throw new Error("cross-extension version accepted");
  console.log("PASS validate_extension_version.js self-test (owner=ALLOW, non-owner=BLOCK, SemVer/id mismatch=BLOCK)");
}

if (require.main === module) {
  if (process.argv.includes("--self-test")) selfTest();
  else process.stdout.write(JSON.stringify(validateExtensionVersion({
    title: process.env.ISSUE_TITLE, body: process.env.ISSUE_BODY, author: process.env.ISSUE_AUTHOR,
    parentNumber: process.env.PARENT_NUMBER, parentAuthor: process.env.PARENT_AUTHOR,
    parentTitle: process.env.PARENT_TITLE, parentBody: process.env.PARENT_BODY,
  }), null, 2) + "\n");
}

module.exports = { validateExtensionVersion, parseVersionIssueNumber, parseSemver, compareSemver };
