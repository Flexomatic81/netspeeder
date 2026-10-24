// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import { test } from "node:test";
import assert from "node:assert/strict";
import { capacityFor, createHistory, pushSample, resetBaselines, resize } from "../package/contents/code/history.mjs";

const GB = 1e9;
const at = (timestamp, down, up, totals) => ({ timestamp, down, up, totals: totals || {} });
const known = (down, up) => ({ down, up, known: true });
const eth = (down, up) => ({ eth0: known(down, up) });

function run(history, samples) {
  return samples.reduce((h, s) => pushSample(h, s), history);
}

test("capacity keeps the most recent samples with their times", () => {
  const h = run(createHistory(3), [at(1, 1, 10), at(2, 2, 20), at(3, 3, 30), at(4, 4, 40)]);
  assert.deepEqual(h.down, [2, 3, 4]);
  assert.deepEqual(h.up, [20, 30, 40]);
  assert.deepEqual(h.times, [2, 3, 4]);
});

test("peaks are the maximum since start, even after points fall out", () => {
  const h = run(createHistory(2), [at(1, 5, 1), at(2, 9, 7), at(3, 2, 3), at(4, 1, 1)]);
  assert.equal(h.peakDown, 9);
  assert.equal(h.peakUp, 7);
});

test("session totals add the counter difference", () => {
  const h = run(createHistory(10), [at(1, 0, 0, eth(1000, 100)), at(2, 0, 0, eth(4000, 400))]);
  assert.equal(h.sessionDown, 3000);
  assert.equal(h.sessionUp, 300);
});

test("a new interface does not count its whole counter at the first known value", () => {
  const h = run(createHistory(10), [
    at(1, 0, 0, eth(1000, 0)),
    at(2, 0, 0, { eth0: known(1000, 0), wg0: { down: 0, up: 0, known: false } }),
    at(3, 0, 0, { eth0: known(1000, 0), wg0: known(5 * GB, 5 * GB) }),
  ]);
  assert.equal(h.sessionDown, 0);
  const next = pushSample(h, at(4, 0, 0, { eth0: known(1000, 0), wg0: known(5 * GB + 10, 5 * GB + 20) }));
  assert.equal(next.sessionDown, 10);
  assert.equal(next.sessionUp, 20);
});

test("counter reset to 0 then growth loses nothing and never goes negative", () => {
  let h = run(createHistory(10), [at(1, 0, 0, eth(5000, 0)), at(2, 0, 0, eth(0, 0))]);
  assert.equal(h.sessionDown, 0);
  h = pushSample(h, at(3, 0, 0, eth(100, 0)));
  assert.equal(h.sessionDown, 100);
});

test("counter reset to a value counts that value", () => {
  const h = run(createHistory(10), [at(1, 0, 0, eth(5000, 0)), at(2, 0, 0, eth(300, 0))]);
  assert.equal(h.sessionDown, 300);
});

test("a long gap keeps both points and counts the counter difference", () => {
  const hour = 3600 * 1000;
  const h = run(createHistory(10), [at(1000, 1, 1, eth(0, 0)), at(1000 + hour, 1, 1, eth(GB, 0))]);
  assert.equal(h.sessionDown, GB);
  assert.deepEqual(h.times, [1000, 1000 + hour]);
});

test("a clock set back clears the points but keeps peaks and sums", () => {
  const before = run(createHistory(10), [at(5000, 9, 8, eth(0, 0)), at(6000, 3, 2, eth(100, 0))]);
  const h = pushSample(before, at(1000, 1, 1, eth(150, 0)));
  assert.deepEqual(h.times, [1000]);
  assert.deepEqual(h.down, [1]);
  assert.equal(h.peakDown, 9);
  assert.equal(h.peakUp, 8);
  assert.equal(h.sessionDown, 150);
});

test("a missing interface loses its baseline and counts again from the second value", () => {
  let h = run(createHistory(10), [at(1, 0, 0, eth(100, 0)), at(2, 0, 0, {})]);
  h = pushSample(h, at(3, 0, 0, eth(900, 0)));
  assert.equal(h.sessionDown, 0);
  h = pushSample(h, at(4, 0, 0, eth(950, 0)));
  assert.equal(h.sessionDown, 50);
});

test("an interface that is not known keeps its baseline", () => {
  const h = run(createHistory(10), [
    at(1, 0, 0, eth(100, 0)),
    at(2, 0, 0, { eth0: { down: 0, up: 0, known: false } }),
    at(3, 0, 0, eth(130, 0)),
  ]);
  assert.equal(h.sessionDown, 30);
});

test("non-finite counter values count as unknown", () => {
  const h = run(createHistory(10), [
    at(1, 0, 0, eth(100, 0)),
    at(2, 0, 0, { eth0: known(NaN, 0) }),
    at(3, 0, 0, eth(Infinity, 0)),
    at(4, 0, 0, eth(110, 0)),
  ]);
  assert.equal(h.sessionDown, 10);
});

test("resetBaselines keeps history, peaks and sums", () => {
  const before = run(createHistory(10), [at(1, 4, 2, eth(0, 0)), at(2, 6, 3, eth(500, 0))]);
  const h = resetBaselines(before);
  assert.deepEqual(h.baselines, {});
  assert.equal(h.sessionDown, 500);
  assert.equal(h.peakDown, 6);
  assert.deepEqual(h.down, [4, 6]);
  // The next reading is a new baseline, not a difference to the old source.
  assert.equal(pushSample(h, at(3, 0, 0, eth(9000, 0))).sessionDown, 500);
});

test("resize keeps the most recent points", () => {
  const h = run(createHistory(5), [at(1, 1, 1), at(2, 2, 2), at(3, 3, 3), at(4, 4, 4)]);
  const small = resize(h, 2);
  assert.equal(small.capacity, 2);
  assert.deepEqual(small.down, [3, 4]);
  assert.deepEqual(small.times, [3, 4]);
  const big = resize(small, 10);
  assert.equal(big.capacity, 10);
  assert.deepEqual(big.down, [3, 4]);
});

test("capacityFor covers 15 minutes", () => {
  assert.equal(capacityFor(1000), 900);
  assert.equal(capacityFor(500), 1800);
  assert.equal(capacityFor(700), 1286);
  for (const bad of [0, -5, NaN, Infinity, undefined]) assert.equal(capacityFor(bad), 900);
});

test("input objects stay unchanged", () => {
  const h = run(createHistory(3), [at(1, 1, 1, eth(10, 10)), at(2, 2, 2, eth(20, 20))]);
  const sample = at(3, 3, 3, eth(30, 30));
  const historyBefore = structuredClone(h);
  const sampleBefore = structuredClone(sample);
  pushSample(h, sample);
  resetBaselines(h);
  resize(h, 1);
  assert.deepEqual(h, historyBefore);
  assert.deepEqual(sample, sampleBefore);
});
