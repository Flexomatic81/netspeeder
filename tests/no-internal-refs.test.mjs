// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// The shipped files and the documentation stand on their own: they do not
// point readers to numbered sections of documents outside the repository.
// Public specifications such as the XDG Desktop Entry Specification may be
// named. The sample lines below are assembled from parts so that a plain text
// search of the repository does not find them either.
import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const SCANNED = ["package/", "docs/", "README.md", "CHANGELOG.md", "CONTRIBUTING.md"];

const SPEC = "spec";

const PATTERNS = [/\bdesign (spec|doc|document)\b/i, /\bspec\b/i, /\bsection [0-9]+(\.[0-9]+)* of the\b/i];

/** The patterns that match the line. */
function internalRefs(line) {
  return PATTERNS.filter((re) => re.test(line)).map(String);
}

function trackedFiles() {
  return execFileSync("git", ["ls-files", "-z", "--", ...SCANNED], { cwd: ROOT, encoding: "utf8" })
    .split("\0")
    .filter(Boolean);
}

function isText(buffer) {
  return !buffer.subarray(0, 8000).includes(0);
}

test("references to documents outside the repository are recognized", () => {
  for (const line of [
    `// Parser for the /proc/net/dev fallback source (${SPEC} 5.2).`,
    `  // An unusable new value counts as 0 (${SPEC} 5.5), which is then a reset.`,
    `Configuration keys; the table in section ${"11.2"} of the design ${SPEC} is the`,
    `Configuration keys; the table in section ${11} of the manual is the`,
    `This checklist is worked through before every release (${SPEC} 14.4).`,
    `see the design ${"doc"}`,
    `the ${SPEC.toUpperCase()} says so`,
  ]) {
    assert.notDeepEqual(internalRefs(line), [], line);
  }
});

test("public specifications and ordinary words are not flagged", () => {
  for (const line of [
    "The desktop ID follows the XDG Desktop Entry Specification.",
    "the Desktop Menu Specification",
    "a special case of the respective setting",
    "see the section Usage of the README",
  ]) {
    assert.deepEqual(internalRefs(line), [], line);
  }
});

test("no tracked file under package/, docs/ or the top-level documents points to an internal document", () => {
  const files = trackedFiles();
  assert.ok(
    files.some((f) => f.startsWith("package/")),
    "git ls-files found no package files",
  );
  const hits = [];
  for (const file of files) {
    const buffer = readFileSync(path.join(ROOT, file));
    if (!isText(buffer)) continue;
    buffer
      .toString("utf8")
      .split("\n")
      .forEach((line, i) => {
        if (internalRefs(line).length > 0) hits.push(`${file}:${i + 1}: ${line.trim()}`);
      });
  }
  assert.deepEqual(hits, []);
});
