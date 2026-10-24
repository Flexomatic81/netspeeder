// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Keeps README.md and docs/store.md in step with the package: the migration
// table covers every setting of the Netspeed Widget and names only options
// that exist on the settings pages, the screenshots are the ones the
// screenshot tool writes, and the store's short descriptions fit the form.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { SHOTS } from "../tools/screenshots/demo.mjs";

const readme = readFileSync(new URL("../README.md", import.meta.url), "utf8");
const store = readFileSync(new URL("../docs/store.md", import.meta.url), "utf8");
const configDir = new URL("../package/contents/ui/config/", import.meta.url);

// The configuration keys of the Netspeed Widget (its main.xml).
const UPSTREAM_KEYS = [
  "showSeparately",
  "showLowSpeeds",
  "speedLayout",
  "swapDownUp",
  "showIcons",
  "showUnits",
  "speedUnits",
  "shortUnits",
  "fontSize",
  "updateInterval",
  "customColors",
  "byteColor",
  "kilobyteColor",
  "megabyteColor",
  "gigabyteColor",
  "launchApplicationEnabled",
  "launchApplication",
  "interfacesWhitelistEnabled",
  "interfacesWhitelist",
];

// The text of a "## " section up to the next one; "" when it is missing.
function section(text, heading) {
  const start = text.indexOf("\n## " + heading + "\n");
  if (start < 0) return "";
  const end = text.indexOf("\n## ", start + 1);
  return text.slice(start, end < 0 ? text.length : end);
}

// Every text the settings pages pass to tr() or trc().
function configTexts() {
  const texts = new Set();
  for (const file of readdirSync(configDir).filter((f) => f.endsWith(".qml"))) {
    const qml = readFileSync(new URL(file, configDir), "utf8");
    for (const match of qml.matchAll(/\btr\("([^"]+)"|\btrc\("[^"]*",\s*"([^"]+)"/g)) {
      texts.add(match[1] ?? match[2]);
    }
  }
  return texts;
}

test("the README maps every setting of the Netspeed Widget", () => {
  const table = section(readme, "Coming from Netspeed Widget");
  const missing = UPSTREAM_KEYS.filter((key) => !table.includes("`" + key + "`"));
  assert.deepEqual(missing, []);
});

test("the migration table quotes only options of the settings pages", () => {
  const rows = section(readme, "Coming from Netspeed Widget")
    .split("\n")
    .filter((line) => line.startsWith("| `"));
  const known = configTexts();
  const quoted = rows.flatMap((row) => [...row.matchAll(/"([^"]+)"/g)].map((m) => m[1]));
  assert.ok(quoted.length > 0);
  assert.deepEqual(
    quoted.filter((text) => !known.has(text)),
    [],
  );
});

test("the README states the supported minimum", () => {
  const text = readme.replace(/\s+/g, " ");
  assert.match(text, /Plasma 6\.3 or newer, with KDE Frameworks 6\.10 and Qt 6\.8 or newer/);
});

test("the README and the store text list every screenshot", () => {
  for (const name of SHOTS) {
    assert.ok(readme.includes("docs/images/" + name), name + " in README.md");
    assert.ok(store.includes("`" + name + "`"), name + " in docs/store.md");
  }
});

test("the store's short descriptions fit in 200 characters", () => {
  const lines = section(store, "Short description")
    .split("\n")
    .filter((line) => line.startsWith("> "));
  assert.equal(lines.length, 2);
  for (const line of lines) {
    assert.ok([...line.slice(2)].length <= 200, line);
  }
});
