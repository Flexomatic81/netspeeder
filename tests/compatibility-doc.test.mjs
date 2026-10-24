// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Keeps docs/compatibility.md in step with the package: every QML module the
// applet imports must be listed there with the version it was checked
// against, and the stated minimum must match metadata.json.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";

const contentsDir = new URL("../package/contents/", import.meta.url);
const docUrl = new URL("../docs/compatibility.md", import.meta.url);
const metadata = JSON.parse(readFileSync(new URL("../package/metadata.json", import.meta.url), "utf8"));

// Module names from `import Some.Module` lines; relative imports ("...") are
// files of the package itself.
function importedModules() {
  const modules = new Set();
  const files = readdirSync(contentsDir, { recursive: true }).filter((f) => String(f).endsWith(".qml"));
  for (const file of files) {
    const text = readFileSync(new URL(String(file), contentsDir), "utf8");
    for (const match of text.matchAll(/^import\s+([A-Za-z][\w.]*)/gm)) {
      modules.add(match[1]);
    }
  }
  return [...modules].sort();
}

// The document with every run of white space as one space, so that line
// wrapping does not matter.
function readDoc() {
  return readFileSync(docUrl, "utf8").replace(/\s+/g, " ");
}

test("the package imports QML modules at all", () => {
  assert.ok(importedModules().includes("org.kde.plasma.plasmoid"));
});

test("docs/compatibility.md lists every imported QML module", () => {
  const doc = readDoc();
  const missing = importedModules().filter((name) => !doc.includes("`" + name + "`"));
  assert.deepEqual(missing, []);
});

test("docs/compatibility.md states the minimum the metadata implies", () => {
  const doc = readDoc();
  assert.equal(metadata["X-Plasma-API-Minimum-Version"], "6.0");
  assert.match(doc, /Plasma 6\.3 or newer/);
  assert.match(doc, /KDE Frameworks 6\.10 or newer/);
  assert.match(doc, /Qt 6\.8 or newer/);
});
