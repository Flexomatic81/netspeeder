// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import { test } from "node:test";
import assert from "node:assert/strict";
import {
  axisLabelIndices,
  axisScale,
  graphWindow,
  lastSamples,
  pickDistinct,
  validMinutes,
} from "../package/contents/code/graph.mjs";
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

test("axisScale picks a nice limit in the displayed unit with round steps", () => {
  assert.deepEqual(axisScale(1500), { max: 2 * KiB, step: KiB / 2, steps: 4 });
  assert.deepEqual(axisScale(2 * KiB), { max: 2 * KiB, step: KiB / 2, steps: 4 });
  assert.deepEqual(axisScale(977 * KiB), { max: MiB, step: MiB / 4, steps: 4 });
  assert.deepEqual(axisScale(7 * MiB), { max: 10 * MiB, step: 2 * MiB, steps: 5 });
  assert.deepEqual(axisScale(600 * KiB), { max: MiB, step: MiB / 4, steps: 4 });
  assert.deepEqual(axisScale(1.5 * MiB, { unitSystem: "iec" }), { max: 2 * MiB, step: MiB / 2, steps: 4 });
  assert.deepEqual(axisScale(3.5 * MiB), { max: 5 * MiB, step: MiB, steps: 5 });
  assert.deepEqual(axisScale(30 * MiB), { max: 50 * MiB, step: 10 * MiB, steps: 5 });
  assert.deepEqual(axisScale(150 * MiB), { max: 200 * MiB, step: 50 * MiB, steps: 4 });
});

test("axisScale in si and bits works on the factor and the bit scale", () => {
  assert.deepEqual(axisScale(1500, SI), { max: 2000, step: 500, steps: 4 });
  assert.deepEqual(axisScale(1e6, SI), { max: 1e6, step: 250000, steps: 4 });
  assert.deepEqual(axisScale(1.2e6, SI), { max: 2e6, step: 500000, steps: 4 });
  // 1 MB/s is 8 Mbit/s, so the limit is 10 Mbit/s = 1.25 MB/s
  assert.deepEqual(axisScale(1e6, BITS), { max: 1.25e6, step: 250000, steps: 5 });
  assert.deepEqual(axisScale(100, BITS), { max: 125, step: 31.25, steps: 4 });
});

test("axisScale returns the smallest axis for invalid input and small values", () => {
  assert.deepEqual(axisScale(0), { max: 1024, step: 256, steps: 4 });
  assert.deepEqual(axisScale(900), { max: 1024, step: 256, steps: 4 });
  assert.deepEqual(axisScale(1024), { max: 1024, step: 256, steps: 4 });
  assert.deepEqual(axisScale(NaN), { max: 1024, step: 256, steps: 4 });
  assert.deepEqual(axisScale(Infinity), { max: 1024, step: 256, steps: 4 });
  assert.deepEqual(axisScale("5"), { max: 1024, step: 256, steps: 4 });
  assert.deepEqual(axisScale(999, SI), { max: 1000, step: 250, steps: 4 });
  assert.deepEqual(axisScale(100, BITS), { max: 125, step: 31.25, steps: 4 });
  assert.deepEqual(axisScale(10, BITS), { max: 125, step: 31.25, steps: 4 });
});

test("every grid label is a round value that covers 0 to the limit", () => {
  const options = [{ unitSystem: "iec" }, SI, BITS, { unitSystem: "iec", decimals: 2 }];
  for (const opts of options) {
    for (let v = 1100; v < 4e9; v *= 1.37) {
      const { max, step, steps } = axisScale(v, opts);
      assert.ok(steps === 4 || steps === 5, `${steps} steps`);
      assert.ok(Math.abs(step * steps - max) < 1e-6 * max, `${step} x ${steps} is not ${max}`);
      for (let i = 0; i <= steps; i++) {
        const label = formatSpeed(step * i, Object.assign({}, opts, { lowSpeedThreshold: 0 }));
        // at most one decimal, and that one is a five (0.5, 1.5), never 3.8
        assert.match(
          label.value,
          /^\d+(\.[05]0?)?$/,
          `${opts.unitSystem}: ${v} step ${i} -> ${label.value} ${label.unit}`,
        );
      }
    }
  }
});

test("pickDistinct returns the first candidate that is clearly away from the base", () => {
  const orange = { r: 1, g: 0.5, b: 0.1 };
  const nearOrange = { r: 0.95, g: 0.55, b: 0.1 };
  const green = { r: 0.4, g: 0.6, b: 0.4 };
  const teal = { r: 0, g: 0.67, b: 0.5 };
  assert.equal(pickDistinct(orange, [green, teal]), 0);
  assert.equal(pickDistinct(orange, [nearOrange, teal, green]), 1);
  assert.equal(pickDistinct(orange, [nearOrange, orange, orange]), 2);
  assert.equal(pickDistinct(orange, [nearOrange]), 0);
  assert.equal(pickDistinct(orange, []), -1);
});

test("axisLabelIndices keeps every label when there is room", () => {
  assert.deepEqual(axisLabelIndices(4, 200, 14), [0, 1, 2, 3, 4]);
  assert.deepEqual(axisLabelIndices(5, 5 * 14 * 1.6, 14), [0, 1, 2, 3, 4, 5]);
});

test("axisLabelIndices keeps only 0 and the top when the labels do not all fit", () => {
  assert.deepEqual(axisLabelIndices(4, 80, 14), [0, 4]);
  assert.deepEqual(axisLabelIndices(5, 80, 14), [0, 5]);
  assert.deepEqual(axisLabelIndices(5, 0, 14), [0, 5]);
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

test("lastSamples gives the newest points, fewer when there are not enough", () => {
  const h = { down: [1, 2, 3, 4, 5], up: [10, 20, 30, 40, 50], times: [1, 2, 3, 4, 5] };
  assert.deepEqual(lastSamples(h, 2), { down: [4, 5], up: [40, 50] });
  assert.deepEqual(lastSamples(h, 5), { down: [1, 2, 3, 4, 5], up: [10, 20, 30, 40, 50] });
  assert.deepEqual(lastSamples(h, 9), { down: [1, 2, 3, 4, 5], up: [10, 20, 30, 40, 50] });
  assert.deepEqual(lastSamples({ down: [], up: [], times: [] }, 3), { down: [], up: [] });
  assert.deepEqual(lastSamples(null, 3), { down: [], up: [] });
});

test("lastSamples takes 60 for an invalid count", () => {
  const down = Array.from({ length: 80 }, (_, i) => i);
  const h = { down, up: down.map((v) => v * 2), times: down };
  for (const count of [0, -1, NaN, undefined, "x", 2.5]) {
    const r = lastSamples(h, count);
    assert.equal(r.down.length, 60, String(count));
    assert.equal(r.down[0], 20);
    assert.equal(r.up[59], 158);
  }
});
