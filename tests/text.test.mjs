// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import { test } from "node:test";
import assert from "node:assert/strict";
import { pluralFallback, substitute } from "../package/contents/code/text.mjs";

test("a missing argument leaves its placeholder", () => {
  assert.equal(substitute("a %1 %2", ["x"]), "a x %2");
});

test("a number is followed by a literal percent sign", () => {
  assert.equal(substitute("%1%", [50]), "50%");
});

test("%9 is replaced when nine arguments are given", () => {
  const args = ["1", "2", "3", "4", "5", "6", "7", "8", "nine"];
  assert.equal(substitute("%9 %1 %5", args), "nine 1 5");
});

test("an empty argument list leaves the text unchanged", () => {
  assert.equal(substitute("Download: %1", []), "Download: %1");
  assert.equal(substitute("plain", []), "plain");
});

test("a placeholder is replaced everywhere it occurs", () => {
  assert.equal(substitute("%1-%1", ["a"]), "a-a");
});

test("values are converted with String", () => {
  assert.equal(substitute("%1 %2", [0, false]), "0 false");
});

test("pluralFallback uses the singular for exactly one", () => {
  assert.equal(pluralFallback("%1 file", "%1 files", 1, []), "1 file");
});

test("pluralFallback uses the plural for zero and for more than one", () => {
  assert.equal(pluralFallback("%1 file", "%1 files", 0, []), "0 files");
  assert.equal(pluralFallback("%1 file", "%1 files", 2, []), "2 files");
});

test("pluralFallback passes the count as %1 and shifts the other arguments", () => {
  assert.equal(pluralFallback("%1 file in %2", "%1 files in %2", 3, ["dir"]), "3 files in dir");
});
