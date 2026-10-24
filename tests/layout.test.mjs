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
test("auto: thin 20px panel falls back to columns", () =>
  assert.equal(resolveLayout({ ...base, thickness: 20 }), "columns"));
test("auto: thick 96px panel uses rows", () => assert.equal(resolveLayout({ ...base, thickness: 96 }), "rows"));
test("unknown mode behaves like auto", () =>
  assert.equal(resolveLayout({ ...base, mode: "x", thickness: 20 }), "columns"));

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

// The layout rounds the symbol column up to whole pixels: a symbol 125.5 px wide
// at the reference size takes 17 px instead of 16.3 at 13 px.
test("fitVertical leaves room for parts the layout rounds up", () => {
  const widths = [348.8, 322, 322, 241.2];
  assert.deepEqual(fitVertical(32, widths, 13, 10), { index: 3, pixelSize: 13 });
  assert.deepEqual(fitVertical(32, widths, 13, 10, [125.5]), { index: 3, pixelSize: 12 });
});
test("fitVertical keeps the size when the rounding still fits", () => {
  assert.deepEqual(fitVertical(32, [307.1, 280.3, 280.3, 199.5], 13, 10, [83.75]), { index: 0, pixelSize: 10 });
});
test("fitVertical adds up several rounded parts and ignores whole pixels", () => {
  assert.deepEqual(fitVertical(32, [300], 13, 1, [100]), { index: 0, pixelSize: 10 });
  assert.deepEqual(fitVertical(32, [300], 13, 1, [103, 103]), { index: 0, pixelSize: 10 });
  assert.deepEqual(fitVertical(32, [300], 13, 1, [103, 103, 103]), { index: 0, pixelSize: 9 });
});
test("fitVertical never goes below 1 px for rounded parts", () => {
  assert.deepEqual(fitVertical(1, [300], 13, 1, [150]), { index: 0, pixelSize: 1 });
});

test("values that have not loaded yet fall back to safe defaults", () => {
  assert.equal(fontPixelSize(NaN, 100), 1); // row height 0
  assert.equal(fontPixelSize(undefined, undefined), 1);
  assert.equal(fontPixelSize(22, NaN), 15); // scale 100 %
  assert.equal(fontPixelSize(22, undefined), 15);
  // thickness 0 gives a 1 px font, which is below the readable minimum
  assert.equal(resolveLayout({ ...base, thickness: undefined }), "columns");
  // an unknown minimum counts as 0, so any size is readable
  assert.equal(resolveLayout({ ...base, thickness: 20, minReadablePx: undefined }), "rows");
  assert.equal(fitPixelSize(NaN, 160, 14), 1); // no space available
  assert.equal(fitPixelSize(32, 160, NaN), 1); // no usable maximum
  assert.equal(fitPixelSize(32, undefined, 14), 14); // nothing measured
  assert.deepEqual(fitVertical(64, [400], 14, undefined), { index: 0, pixelSize: 14 });
  assert.deepEqual(fitVertical(64, [400], 14, 1, undefined), { index: 0, pixelSize: 14 });
  assert.deepEqual(fitVertical(64, [400], 14, 1, [Number.NaN]), { index: 0, pixelSize: 14 });
});
