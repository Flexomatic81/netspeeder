// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import { test } from "node:test";
import assert from "node:assert/strict";
import { formatSpeed, formatTotal, speedUnits, widestValue } from "../package/contents/code/format.mjs";

const cases = [
  // [name, bytes/s, opts, expected]
  ["iec default", 1536, {}, { value: "1.5", unit: "KiB/s" }],
  ["stays below 1000 of unit", 999 * 1024, {}, { value: "999", unit: "KiB/s" }],
  ["switch at 1000 of unit, 2 decimals", 1000 * 1024, { decimals: 2 }, { value: "0.98", unit: "MiB/s" }],
  ["rounding never yields 1000", 999.97 * 1024, {}, { value: "1.0", unit: "MiB/s" }],
  ["auto decimals decided after rounding", 99.96 * 1024, {}, { value: "100", unit: "KiB/s" }],
  ["auto decimals below 100", 51.2 * 1024, {}, { value: "51.2", unit: "KiB/s" }],
  ["base unit has no decimals", 512, { lowSpeedThreshold: 0, decimals: 2 }, { value: "512", unit: "B/s" }],
  ["fixed 0 decimals", 1600, { decimals: 0 }, { value: "2", unit: "KiB/s" }],
  ["si", 1500, { unitSystem: "si" }, { value: "1.5", unit: "kB/s" }],
  ["bits", 125000, { unitSystem: "bits" }, { value: "1.0", unit: "Mbit/s" }],
  ["bits without 1.024 factor", 12_500_000, { unitSystem: "bits" }, { value: "100", unit: "Mbit/s" }],
  ["short bytes", 1536, { shortUnits: true }, { value: "1.5", unit: "K" }],
  ["short bits", 125000, { unitSystem: "bits", shortUnits: true }, { value: "1.0", unit: "m" }],
  ["low speed hidden by default", 1000, {}, { value: "0", unit: "B/s" }],
  ["low speed threshold off", 1000, { lowSpeedThreshold: 0 }, { value: "1.0", unit: "KiB/s" }],
  ["threshold compares bytes in bits mode", 1000, { unitSystem: "bits" }, { value: "0", unit: "bit/s" }],
  ["decimal comma", 1536, { decimalPoint: "," }, { value: "1,5", unit: "KiB/s" }],
  ["largest unit is not exceeded", 5000 * 1024 ** 3, {}, { value: "5000", unit: "GiB/s" }],
  ["invalid options fall back", 1536, { unitSystem: "foo", decimals: 7 }, { value: "1.5", unit: "KiB/s" }],
];
for (const [name, input, opts, expected] of cases) {
  test(`formatSpeed: ${name}`, () => assert.deepEqual(formatSpeed(input, opts), expected));
}

test("formatSpeed: non-finite or negative input shows 0", () => {
  for (const v of [NaN, undefined, null, -5, Infinity, "abc"]) {
    assert.deepEqual(formatSpeed(v, {}), { value: "0", unit: "B/s" });
  }
});

test("formatTotal", () => {
  assert.deepEqual(formatTotal(3284461921, {}), { value: "3.1", unit: "GiB" });
  assert.deepEqual(formatTotal(2 * 1024 ** 4, {}), { value: "2.0", unit: "TiB" });
  assert.deepEqual(formatTotal(1500, { unitSystem: "bits" }), { value: "1.5", unit: "kB" });
  assert.deepEqual(formatTotal(500, {}), { value: "500", unit: "B" });
  assert.deepEqual(formatTotal(NaN, {}), { value: "0", unit: "B" });
});

test("speedUnits", () => {
  assert.deepEqual(speedUnits({}), ["B/s", "KiB/s", "MiB/s", "GiB/s"]);
  assert.deepEqual(speedUnits({ unitSystem: "si" }), ["B/s", "kB/s", "MB/s", "GB/s"]);
  assert.deepEqual(speedUnits({ unitSystem: "bits" }), ["bit/s", "kbit/s", "Mbit/s", "Gbit/s"]);
  assert.deepEqual(speedUnits({ shortUnits: true }), ["B", "K", "M", "G"]);
  assert.deepEqual(speedUnits({ unitSystem: "bits", shortUnits: true }), ["b", "k", "m", "g"]);
});

test("widestValue", () => {
  assert.equal(widestValue({}), "888.8");
  assert.equal(widestValue({ decimals: 0 }), "888");
  assert.equal(widestValue({ decimals: 2, decimalPoint: "," }), "888,88");
});
