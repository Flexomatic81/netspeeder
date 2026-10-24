// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// The QML JavaScript engine rejects syntax that Node accepts, so the smoke scene ModulesSmoke.qml loads every
// code module. This test makes sure no module is left out of it.

import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";

const codeDir = new URL("../package/contents/code/", import.meta.url);
const scene = fs.readFileSync(new URL("../tests/qml/ModulesSmoke.qml", import.meta.url), "utf8");

test("ModulesSmoke.qml imports every code module", () => {
  const modules = fs.readdirSync(codeDir).filter((f) => f.endsWith(".mjs"));
  assert.ok(modules.length > 0);
  const imported = [...scene.matchAll(/^import "\.\.\/\.\.\/package\/contents\/code\/([^"]+\.mjs)" as /gm)].map(
    (m) => m[1],
  );
  assert.deepEqual([...imported].sort(), modules.sort());
});
