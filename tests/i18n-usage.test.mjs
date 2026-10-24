// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Keeps the translation setup intact: Plasma's i18n functions are called only
// from the per-file helpers tr/trc/trp, and the message catalog still holds
// exactly the recorded messages.

import { test } from "node:test";
import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

const root = new URL("..", import.meta.url).pathname;

function qmlFiles(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) {
      return qmlFiles(path);
    }
    return entry.name.endsWith(".qml") ? [path] : [];
  });
}

// Replaces comments with blanks of the same length (offsets stay valid) and
// leaves string literals alone.
function blankComments(source) {
  return source.replace(/"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*'|\/\/[^\n]*|\/\*[\s\S]*?\*\//g, (match) =>
    match.startsWith("//") || match.startsWith("/*") ? match.replace(/[^\n]/g, " ") : match,
  );
}

// The index just after the brace that closes the block opened at `open`.
// Braces inside string literals do not count.
function blockEnd(code, open) {
  let depth = 0;
  for (let i = open; i < code.length; i++) {
    const c = code[i];
    if (c === '"' || c === "'") {
      i = skipString(code, i);
    } else if (c === "{") {
      depth++;
    } else if (c === "}" && --depth === 0) {
      return i + 1;
    }
  }
  return code.length;
}

function skipString(code, start) {
  const quote = code[start];
  let i = start + 1;
  while (i < code.length && code[i] !== quote) {
    i += code[i] === "\\" ? 2 : 1;
  }
  return i;
}

function helperBodies(code) {
  const bodies = [];
  for (const head of code.matchAll(/\bfunction\s+(?:tr|trc|trp)\s*\([^)]*\)[^{]*\{/g)) {
    const open = head.index + head[0].length - 1;
    bodies.push([open, blockEnd(code, open)]);
  }
  return bodies;
}

test("Plasma i18n functions are called only inside the tr/trc/trp helpers", () => {
  const stray = [];
  for (const file of qmlFiles(join(root, "package"))) {
    const code = blankComments(readFileSync(file, "utf8"));
    const bodies = helperBodies(code);
    for (const call of code.matchAll(/(?<![\w.])i18n[cnp]*\s*\(/g)) {
      if (!bodies.some(([from, to]) => call.index > from && call.index < to)) {
        const line = code.slice(0, call.index).split("\n").length;
        stray.push(`${file.slice(root.length)}:${line}`);
      }
    }
  }
  assert.deepEqual(stray, []);
});

function unescapePo(text) {
  return text.replace(/\\(["\\nt])/g, (_, c) => ({ n: "\n", t: "\t" })[c] ?? c);
}

// The text of one field ("msgid", "msgctxt", …) of a catalog entry; the
// value may continue on the quoted lines that follow.
function field(block, name) {
  const lines = block.split("\n");
  const start = lines.findIndex((line) => line.startsWith(`${name} "`));
  if (start < 0) {
    return "";
  }
  const parts = [lines[start].slice(name.length + 2, -1)];
  for (const line of lines.slice(start + 1)) {
    if (!line.startsWith('"')) {
      break;
    }
    parts.push(line.slice(1, -1));
  }
  return unescapePo(parts.join(""));
}

// The keys of a .pot file as "context<TAB>id<TAB>plural" lines.
function catalogKeys(text) {
  return text
    .split(/\n\n+/)
    .map((block) => [field(block, "msgctxt"), field(block, "msgid"), field(block, "msgid_plural")])
    .filter(([, id]) => id !== "")
    .map((key) => key.join("\t"));
}

test("the message catalog holds exactly the recorded messages", () => {
  const pot = readFileSync(join(root, "po/plasma_applet_io.github.flexomatic81.netspeeder.pot"), "utf8");
  const recorded = new Set(
    readFileSync(join(root, "tests/fixtures/catalog-keys.txt"), "utf8").split("\n").filter(Boolean),
  );
  const actual = new Set(catalogKeys(pot));
  const show = (keys) => [...keys].map((key) => key.replaceAll("\t", " | "));
  assert.deepEqual(show([...recorded].filter((key) => !actual.has(key))), [], "missing from the catalog");
  assert.deepEqual(show([...actual].filter((key) => !recorded.has(key))), [], "not in the recorded set");
  assert.equal(actual.size, recorded.size);
});
