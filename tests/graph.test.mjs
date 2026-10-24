// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import { test } from "node:test";
import assert from "node:assert/strict";
import { axisScale, graphWindow, validMinutes } from "../package/contents/code/graph.mjs";
import { formatSpeed } from "../package/contents/code/format.mjs";

const MIN = 60000;
const hist = (times) => ({ times, down: times.map((t) => t / 10), up: times.map((t) => t / 100) });

test("an empty history gives empty arrays", () => {
  assert.deepEqual(graphWindow(hist([]), 5), { down: [], up: [] });
  assert.deepEqual(graphWindow(null, 5), { down: [], up: [] });
});

test("all points inside the window are kept", () => {
  const w = graphWindow(hist([0, 1000, 2000]), 1);
  assert.deepEqual(w.down, [0, 100, 200]);
  assert.deepEqual(w.up, [0, 10, 20]);
});

test("older points fall out, the boundary stays", () => {
  const w = graphWindow(hist([0, 1, MIN, 2 * MIN]), 1);
  assert.deepEqual(w.down, [MIN / 10, (2 * MIN) / 10]);
  assert.deepEqual(w.up, [MIN / 100, (2 * MIN) / 100]);
});

test("the window is chosen by time, not by count, after an interval change", () => {
  const times = [];
  for (let t = 0; t < 4 * MIN; t += 1000) {
    times.push(t);
  }
  for (let t = 4 * MIN; t <= 6 * MIN; t += 500) {
    times.push(t);
  }
  const w = graphWindow(hist(times), 1);
  const expected = times.filter((t) => t >= 5 * MIN);
  assert.equal(w.down.length, expected.length);
  assert.equal(w.down[0], expected[0] / 10);
});

test("a gap of ten minutes leaves only the points after it", () => {
  const w = graphWindow(hist([0, 1000, 2000, 10 * MIN + 2000, 10 * MIN + 3000]), 5);
  assert.deepEqual(w.down, [(10 * MIN + 2000) / 10, (10 * MIN + 3000) / 10]);
});

test("validMinutes accepts 1, 5 and 15 only", () => {
  assert.equal(validMinutes(1), 1);
  assert.equal(validMinutes(5), 5);
  assert.equal(validMinutes(15), 15);
  for (const bad of [0, 7, "5", undefined, null, NaN]) {
    assert.equal(validMinutes(bad), 5);
  }
});

const SI = { unitSystem: "si" };
const BITS = { unitSystem: "bits" };
const KiB = 1024;
const MiB = 1024 * 1024;

test("axisScale picks a nice limit in the displayed unit, in four steps", () => {
  assert.deepEqual(axisScale(1500), { max: 2 * KiB, step: KiB / 2 });
  assert.deepEqual(axisScale(2 * KiB), { max: 2 * KiB, step: KiB / 2 });
  assert.deepEqual(axisScale(977 * KiB), { max: MiB, step: MiB / 4 });
  assert.deepEqual(axisScale(7 * MiB), { max: 10 * MiB, step: (10 * MiB) / 4 });
  assert.deepEqual(axisScale(600 * KiB), { max: MiB, step: MiB / 4 });
  assert.deepEqual(axisScale(1.5 * MiB, { unitSystem: "iec" }), { max: 2 * MiB, step: MiB / 2 });
});

test("axisScale in si and bits works on the factor and the bit scale", () => {
  assert.deepEqual(axisScale(1500, SI), { max: 2000, step: 500 });
  assert.deepEqual(axisScale(1e6, SI), { max: 1e6, step: 250000 });
  assert.deepEqual(axisScale(1.2e6, SI), { max: 2e6, step: 500000 });
  // 1 MB/s is 8 Mbit/s, so the limit is 10 Mbit/s = 1.25 MB/s
  assert.deepEqual(axisScale(1e6, BITS), { max: 1.25e6, step: 312500 });
  assert.deepEqual(axisScale(100, BITS), { max: 125, step: 31.25 });
});

test("axisScale returns the smallest axis for invalid input and small values", () => {
  assert.deepEqual(axisScale(0), { max: 1024, step: 256 });
  assert.deepEqual(axisScale(900), { max: 1024, step: 256 });
  assert.deepEqual(axisScale(1024), { max: 1024, step: 256 });
  assert.deepEqual(axisScale(NaN), { max: 1024, step: 256 });
  assert.deepEqual(axisScale(Infinity), { max: 1024, step: 256 });
  assert.deepEqual(axisScale("5"), { max: 1024, step: 256 });
  assert.deepEqual(axisScale(999, SI), { max: 1000, step: 250 });
  assert.deepEqual(axisScale(100, BITS), { max: 125, step: 31.25 });
  assert.deepEqual(axisScale(10, BITS), { max: 125, step: 31.25 });
});

test("the label of the limit is a round number in every unit system", () => {
  const round = ["1", "2", "5", "10", "20", "50", "100", "200", "500"];
  const options = [{ unitSystem: "iec" }, SI, BITS, { unitSystem: "iec", decimals: 0 }];
  for (const opts of options) {
    for (let v = 1100; v < 4e9; v *= 1.37) {
      const { max } = axisScale(v, opts);
      assert.ok(max >= v, `limit ${max} is below ${v}`);
      const label = formatSpeed(max, Object.assign({}, opts, { lowSpeedThreshold: 0 }));
      assert.ok(
        round.includes(String(Number(label.value))),
        `${opts.unitSystem}: ${v} -> ${label.value} ${label.unit}`,
      );
    }
  }
});

test("axis labels do not use the low-speed threshold", () => {
  assert.deepEqual(formatSpeed(256, { lowSpeedThreshold: 0 }), { value: "256", unit: "B/s" });
});
