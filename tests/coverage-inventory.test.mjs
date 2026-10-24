// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Imports every module under package/contents/code, so that a module without tests of its own still counts in
// the denominator of the coverage the check runner enforces.

import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { pathToFileURL } from "node:url";

const codeDir = new URL("../package/contents/code/", import.meta.url);

test("every code module can be imported", async () => {
  const modules = fs.readdirSync(codeDir).filter((f) => f.endsWith(".mjs"));
  assert.ok(modules.length > 0);
  for (const file of modules) {
    const imported = await import(pathToFileURL(new URL(file, codeDir).pathname).href);
    assert.ok(Object.keys(imported).length > 0, `${file} exports nothing`);
  }
});
