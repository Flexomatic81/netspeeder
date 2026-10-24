// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// scripts/release-check.sh against a temporary tree: it passes only when the
// version, the changelog heading, the screenshots and the release record are
// all in place, and it names every gate that is not.
import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync, chmodSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { SHOTS as SCREENSHOT_FILES } from "../tools/screenshots/demo.mjs";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const SCRIPT = path.join(ROOT, "scripts", "release-check.sh");
const SHOTS = ["panel-rows", "panel-single", "panel-vertical", "panel-colors", "panel-sparkline", "popup"];
const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 13]);

const METADATA = (version) =>
  `{\n    "KPlugin": {\n        "Id": "example",\n        "Version": "${version}"\n    }\n}\n`;
const CHANGELOG = (heading) => `# Changelog\n\n${heading}\n\nFirst stable release.\n\n## 0.9.0 – 2026-01-01\n`;
const RECORD = (rows) =>
  [
    "# Manual tests",
    "",
    "## Release record 2.0.0",
    "",
    "| Gate | Date | Result |",
    "|---|---|---|",
    ...rows,
    "",
    "## Other section",
    "",
    "| Check | Stage | Result |",
    "|---|---|---|",
    "| something | 0.1 | |",
    "",
  ].join("\n");
const FULL_ROWS = ["| (a) Manual checklist | 2026-11-01 | OK |", "| (b) Plasma 6.3 VM | 2026-11-02 | OK |"];

/** A tree in which version 2.0.0 passes every gate; `change` breaks one of them. */
function makeTree(change = () => {}) {
  const dir = mkdtempSync(path.join(os.tmpdir(), "release-check-"));
  mkdirSync(path.join(dir, "scripts"));
  mkdirSync(path.join(dir, "package"));
  mkdirSync(path.join(dir, "docs", "images"), { recursive: true });
  copyFileSync(SCRIPT, path.join(dir, "scripts", "release-check.sh"));
  chmodSync(path.join(dir, "scripts", "release-check.sh"), 0o755);
  writeFileSync(path.join(dir, "package", "metadata.json"), METADATA("2.0.0"));
  writeFileSync(path.join(dir, "CHANGELOG.md"), CHANGELOG("## 2.0.0 – 2026-11-03"));
  for (const shot of SHOTS) writeFileSync(path.join(dir, "docs", "images", `${shot}.png`), PNG);
  writeFileSync(path.join(dir, "docs", "testing.md"), RECORD(FULL_ROWS));
  change(dir);
  return dir;
}

function run(dir, args = ["2.0.0"]) {
  const result = spawnSync("bash", [path.join(dir, "scripts", "release-check.sh"), ...args], {
    cwd: os.tmpdir(),
    encoding: "utf8",
  });
  rmSync(dir, { recursive: true, force: true });
  return result;
}

function assertFails(change, pattern) {
  const result = run(makeTree(change));
  assert.equal(result.status, 1, result.stderr);
  assert.match(result.stderr, pattern);
  assert.match(result.stderr, /is not ready for release/);
}

test("the script checks exactly the screenshots the screenshot tool writes", () => {
  const line = /^SCREENSHOTS="([^"]*)"$/m.exec(readFileSync(SCRIPT, "utf8"));
  assert.ok(line, "no SCREENSHOTS line in the script");
  assert.deepEqual(
    line[1].split(" ").map((name) => `${name}.png`),
    SCREENSHOT_FILES,
  );
  assert.deepEqual(
    SHOTS.map((name) => `${name}.png`),
    SCREENSHOT_FILES,
  );
});

test("a tree that meets every gate passes", () => {
  const result = run(makeTree());
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /2\.0\.0 passes all release gates/);
  assert.equal(result.stderr, "");
});

test("a missing or empty version argument is a usage error", () => {
  assert.equal(run(makeTree(), []).status, 2);
  assert.equal(run(makeTree(), [""]).status, 2);
});

test("a version that differs from metadata.json fails", () => {
  assertFails(
    (dir) => writeFileSync(path.join(dir, "package", "metadata.json"), METADATA("1.9.0")),
    /metadata\.json has Version '1\.9\.0', expected '2\.0\.0'/,
  );
});

test("missing files fail with a message instead of aborting", () => {
  const result = run(
    makeTree((dir) => {
      rmSync(path.join(dir, "package", "metadata.json"));
      rmSync(path.join(dir, "CHANGELOG.md"));
      rmSync(path.join(dir, "docs", "testing.md"));
    }),
  );
  assert.equal(result.status, 1, result.stderr);
  assert.match(result.stderr, /metadata\.json has Version 'none', expected '2\.0\.0'/);
  assert.match(result.stderr, /CHANGELOG\.md is missing/);
  assert.match(result.stderr, /docs\/testing\.md is missing/);
  assert.match(result.stderr, /\(3 problems\)/);
});

test("a changelog without a heading for the version fails", () => {
  assertFails(
    (dir) => writeFileSync(path.join(dir, "CHANGELOG.md"), CHANGELOG("## 2.0.1 – 2026-11-03")),
    /CHANGELOG\.md has no heading '## 2\.0\.0'/,
  );
});

test("a changelog heading that says unreleased fails", () => {
  assertFails(
    (dir) => writeFileSync(path.join(dir, "CHANGELOG.md"), CHANGELOG("## 2.0.0 – unreleased")),
    /still marks 2\.0\.0 as unreleased/,
  );
  assertFails(
    (dir) => writeFileSync(path.join(dir, "CHANGELOG.md"), CHANGELOG("## 2.0.0 (Unreleased)")),
    /still marks 2\.0\.0 as unreleased/,
  );
});

test("a changelog heading without a date fails", () => {
  assertFails(
    (dir) => writeFileSync(path.join(dir, "CHANGELOG.md"), CHANGELOG("## 2.0.0")),
    /heading for 2\.0\.0 has no release date/,
  );
});

test("a missing, empty or non-PNG screenshot fails", () => {
  assertFails((dir) => rmSync(path.join(dir, "docs", "images", "popup.png")), /docs\/images\/popup\.png is missing/);
  assertFails(
    (dir) => writeFileSync(path.join(dir, "docs", "images", "panel-rows.png"), ""),
    /docs\/images\/panel-rows\.png is missing or empty/,
  );
  assertFails(
    (dir) => writeFileSync(path.join(dir, "docs", "images", "panel-sparkline.png"), "<svg/>"),
    /docs\/images\/panel-sparkline\.png is not a PNG file/,
  );
});

test("a release record row without a date or a result fails and is named", () => {
  assertFails(
    (dir) => writeFileSync(path.join(dir, "docs", "testing.md"), RECORD([FULL_ROWS[0], "| (b) Plasma 6.3 VM | | |"])),
    /no date or result for gate \(b\) Plasma 6\.3 VM/,
  );
  assertFails(
    (dir) =>
      writeFileSync(
        path.join(dir, "docs", "testing.md"),
        RECORD([FULL_ROWS[0], "| (b) Plasma 6.3 VM | 2026-11-02 | |"]),
      ),
    /no date or result for gate \(b\)/,
  );
  assertFails(
    (dir) =>
      writeFileSync(path.join(dir, "docs", "testing.md"), RECORD(["| (a) Manual checklist | | OK |", FULL_ROWS[1]])),
    /no date or result for gate \(a\)/,
  );
});

test("a missing or empty release record table fails", () => {
  assertFails(
    (dir) =>
      writeFileSync(
        path.join(dir, "docs", "testing.md"),
        RECORD(FULL_ROWS).replace("Release record 2.0.0", "Release record 1.0.0"),
      ),
    /no table 'Release record 2\.0\.0'/,
  );
  assertFails(
    (dir) => writeFileSync(path.join(dir, "docs", "testing.md"), RECORD([])),
    /no table 'Release record 2\.0\.0'/,
  );
});

test("every failing gate is reported in one run", () => {
  const result = run(
    makeTree((dir) => {
      writeFileSync(path.join(dir, "CHANGELOG.md"), CHANGELOG("## 2.0.0 – unreleased"));
      rmSync(path.join(dir, "docs", "images"), { recursive: true });
      writeFileSync(path.join(dir, "docs", "testing.md"), RECORD(["| (a) Manual checklist | | |"]));
    }),
  );
  assert.equal(result.status, 1);
  assert.match(result.stderr, /unreleased/);
  assert.equal(result.stderr.match(/is missing or empty/g)?.length, SHOTS.length);
  assert.match(result.stderr, /gate \(a\)/);
  assert.match(result.stderr, /\(8 problems\)/);
});
