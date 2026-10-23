// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import { test } from "node:test";
import assert from "node:assert/strict";
import { fontPixelSize, resolveLayout, fitPixelSize, fitVertical } from "../package/contents/code/layout.mjs";

const base = { mode: "auto", vertical: false, combined: false, thickness: 44, fontScale: 100, minReadablePx: 10 };

test("combined is always single", () => {
  assert.equal(resolveLayout({ ...base, combined: true, mode: "rows" }), "single");
});
test("explicit modes are honored, also in vertical panels", () => {
  assert.equal(resolveLayout({ ...base, mode: "columns" }), "columns");
  assert.equal(resolveLayout({ ...base, mode: "rows", thickness: 20 }), "rows");
  assert.equal(resolveLayout({ ...base, mode: "columns", vertical: true }), "columns");
});
test("auto: vertical stacks", () => assert.equal(resolveLayout({ ...base, vertical: true, thickness: 32 }), "rows"));
test("auto: normal panel uses two rows", () => assert.equal(resolveLayout(base), "rows"));
test("auto: thin 20px panel falls back to columns", () => assert.equal(resolveLayout({ ...base, thickness: 20 }), "columns"));
test("auto: thick 96px panel uses rows", () => assert.equal(resolveLayout({ ...base, thickness: 96 }), "rows"));
test("unknown mode behaves like auto", () => assert.equal(resolveLayout({ ...base, mode: "x", thickness: 20 }), "columns"));

test("fontPixelSize", () => {
  assert.equal(fontPixelSize(22, 100), 15);
  assert.equal(fontPixelSize(48, 100), 34);
  assert.equal(fontPixelSize(20, 200), 19); // capped at 95 % of row height
  assert.equal(fontPixelSize(0, 100), 1);
});
test("fitPixelSize", () => {
  assert.equal(fitPixelSize(32, 160, 14), 14);
  assert.equal(fitPixelSize(32, 400, 14), 8);
  assert.equal(fitPixelSize(32, 0, 14), 14);
  assert.equal(fitPixelSize(1, 1000, 14), 1);
});
test("fitVertical degrades until readable (32px panel)", () => {
  assert.deepEqual(fitVertical(32, [631, 400, 230], 14, 12), { index: 2, pixelSize: 13 });
});
test("fitVertical keeps the first candidate when it fits", () => {
  assert.deepEqual(fitVertical(64, [400, 300, 230], 14, 12), { index: 0, pixelSize: 14 });
});
test("fitVertical falls back to the last candidate when nothing is readable", () => {
  assert.deepEqual(fitVertical(10, [631, 400, 230], 14, 12), { index: 2, pixelSize: 4 });
});
