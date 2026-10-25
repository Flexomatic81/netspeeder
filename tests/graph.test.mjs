// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import { test } from "node:test";
import assert from "node:assert/strict";
import {
  axisLabelIndices,
  axisScale,
  graphWindow,
  lastSamples,
  sparklineMax,
  SPARKLINE_SAMPLES,
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

// "#rrggbb" to { r, g, b } with each channel in 0..1, as the colors of the theme reach pickDistinct.
const rgb = (hex) => ({
  r: parseInt(hex.slice(1, 3), 16) / 255,
  g: parseInt(hex.slice(3, 5), 16) / 255,
  b: parseInt(hex.slice(5, 7), 16) / 255,
});

test("pickDistinct returns the first candidate that is clearly away from the base", () => {
  const orange = { r: 1, g: 0.5, b: 0.1 };
  const nearOrange = { r: 0.95, g: 0.55, b: 0.1 };
  const green = { r: 0.4, g: 0.6, b: 0.4 };
  const teal = { r: 0, g: 0.67, b: 0.5 };
  // The muted green is barely saturated and about as light as the orange: not distinct.
  assert.equal(pickDistinct(orange, [green, teal]), 1);
  assert.equal(pickDistinct(orange, [teal, green]), 0);
  assert.equal(pickDistinct(orange, [nearOrange, teal, green]), 1);
  assert.equal(pickDistinct(orange, [nearOrange, orange, orange]), 2);
  assert.equal(pickDistinct(orange, [nearOrange]), 0);
  assert.equal(pickDistinct(orange, []), -1);
});

test("pickDistinct does not count two greens or teals of similar lightness as distinct", () => {
  assert.equal(pickDistinct(rgb("#16a085"), [rgb("#27ae60"), rgb("#3daee9")]), 1);
  assert.equal(pickDistinct(rgb("#1abc9c"), [rgb("#2ecc71"), rgb("#3daee9")]), 1);
  // A darker and a lighter green: far enough apart in RGB for the old rule, but the same hue and too close in
  // lightness.
  assert.equal(pickDistinct(rgb("#2e7d32"), [rgb("#66bb6a"), rgb("#3daee9")]), 1);
  assert.equal(pickDistinct(rgb("#1b5e20"), [rgb("#43a047"), rgb("#3daee9")]), 1);
  // A very dark and a very light green are distinct by lightness alone.
  assert.equal(pickDistinct(rgb("#0b3d0b"), [rgb("#9be89b")]), 0);
});

test("pickDistinct counts the stock blue and green as distinct", () => {
  assert.equal(pickDistinct(rgb("#3daee9"), [rgb("#27ae60"), rgb("#fcfcfc")]), 0);
  assert.equal(pickDistinct(rgb("#27ae60"), [rgb("#3daee9")]), 0);
});

test("pickDistinct measures the hue around the circle", () => {
  // 345 degrees and 15 degrees are 30 degrees apart, 345 and 50 are 65 apart.
  const hue350 = rgb("#e6194b");
  assert.equal(pickDistinct(hue350, [rgb("#e64d19"), rgb("#e6c419")]), 1);
});

test("pickDistinct tells grays apart only by lightness", () => {
  const mid = rgb("#808080");
  assert.equal(pickDistinct(mid, [rgb("#909090"), rgb("#303030")]), 1);
  assert.equal(pickDistinct(mid, [rgb("#d8d8d8")]), 0);
  // A gray has no hue to compare: a color of about the same lightness is not distinct from it.
  assert.equal(pickDistinct(mid, [rgb("#a05f5f"), rgb("#fcfcfc")]), 1);
  assert.equal(pickDistinct(rgb("#3daee9"), [rgb("#8a8a8a"), rgb("#232629")]), 1);
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

test("sparklineMax is at least 1024 for empty, zero and quiet series", () => {
  assert.equal(sparklineMax([], [], false), 1024);
  assert.equal(sparklineMax([0, 0, 0], [0, 0, 0], false), 1024);
  assert.equal(sparklineMax([500, 500], [500, 500], false), 1024);
  assert.equal(sparklineMax([500, 500], [500, 500], true), 1024);
});

test("sparklineMax is the largest value of the shown series", () => {
  assert.equal(sparklineMax([10, 5000, 20], [3000, 1, 1], false), 5000);
  assert.equal(sparklineMax([10, 20], [3000, 9000, 4000], false), 9000);
  assert.equal(sparklineMax([10, 5000, 20], [3000, 1, 1], true), 5001);
  assert.equal(sparklineMax([2000, 2000], [1500, 100], true), 3500);
});

test("sparklineMax counts invalid values as 0", () => {
  assert.equal(sparklineMax([NaN, Infinity, -5, undefined, "7"], [null, 3000, NaN], false), 3000);
  assert.equal(sparklineMax([NaN, 4000], [NaN, NaN], true), 4000);
});

test("the sparkline shows 60 samples", () => {
  assert.equal(SPARKLINE_SAMPLES, 60);
});
