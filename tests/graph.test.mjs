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
  assert.deepEqual(graphWindow(hist([0, 1, MIN, 2 * MIN]), 1).up, [MIN / 100, (2 * MIN) / 100]);
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

test("axisScale picks a nice limit of at least 1 KiB/s in four steps", () => {
  assert.deepEqual(axisScale(0), { max: 1024, step: 256 });
  assert.deepEqual(axisScale(900), { max: 1024, step: 256 });
  assert.deepEqual(axisScale(1024), { max: 1024, step: 256 });
  assert.deepEqual(axisScale(1500), { max: 2000, step: 500 });
  assert.deepEqual(axisScale(2000), { max: 2000, step: 500 });
  assert.deepEqual(axisScale(7 * 1024 * 1024), { max: 10000000, step: 2500000 });
  assert.deepEqual(axisScale(NaN), { max: 1024, step: 256 });
  assert.deepEqual(axisScale(Infinity), { max: 1024, step: 256 });
  assert.deepEqual(axisScale("5"), { max: 1024, step: 256 });
});

test("axis labels do not use the low-speed threshold", () => {
  assert.deepEqual(formatSpeed(256, { lowSpeedThreshold: 0 }), { value: "256", unit: "B/s" });
});
