// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import { test } from "node:test";
import assert from "node:assert/strict";
import { computeRates } from "../package/contents/code/rates.mjs";

const snap = (timestamp, counters) => ({ timestamp, counters });

test("rate from counter delta", () => {
  const r = computeRates(snap(0, { eth0: { rx: 0, tx: 0 } }), snap(1000, { eth0: { rx: 2048, tx: 1024 } }), 1000);
  assert.deepEqual(r, { valid: true, rates: { eth0: { down: 2048, up: 1024 } } });
});
test("rate scales with elapsed time", () => {
  const r = computeRates(snap(0, { eth0: { rx: 0, tx: 0 } }), snap(500, { eth0: { rx: 1024, tx: 0 } }), 1000);
  assert.equal(r.rates.eth0.down, 2048);
});
test("first sample yields zero rates", () => {
  assert.deepEqual(computeRates(null, snap(1000, { eth0: { rx: 5, tx: 5 } }), 1000),
    { valid: true, rates: { eth0: { down: 0, up: 0 } } });
});
test("counter reset yields zero for that direction only", () => {
  const r = computeRates(snap(0, { eth0: { rx: 5000, tx: 0 } }), snap(1000, { eth0: { rx: 100, tx: 300 } }), 1000);
  assert.deepEqual(r.rates.eth0, { down: 0, up: 300 });
});
test("interface reappearing after reconnect does not spike", () => {
  const r = computeRates(snap(0, { eth0: { rx: 0, tx: 0 } }),
    snap(1000, { eth0: { rx: 10, tx: 10 }, wg0: { rx: 1e9, tx: 1e9 } }), 1000);
  assert.deepEqual(r.rates.wg0, { down: 0, up: 0 });
});
test("non-positive elapsed time invalidates sample", () => {
  const prev = snap(1000, { eth0: { rx: 0, tx: 0 } });
  assert.deepEqual(computeRates(prev, snap(1000, { eth0: { rx: 9, tx: 9 } }), 1000), { valid: false, rates: {} });
  assert.deepEqual(computeRates(prev, snap(900, { eth0: { rx: 9, tx: 9 } }), 1000), { valid: false, rates: {} });
});
test("gap above five intervals invalidates sample, exactly five is valid", () => {
  const prev = snap(0, { eth0: { rx: 0, tx: 0 } });
  assert.equal(computeRates(prev, snap(5001, { eth0: { rx: 9, tx: 9 } }), 1000).valid, false);
  assert.equal(computeRates(prev, snap(5000, { eth0: { rx: 9, tx: 9 } }), 1000).valid, true);
});

// Beyond the brief: non-finite counters (undefined/NaN before the first sample)
// and timestamps must never produce NaN, negative or spiking rates.
test("non-finite previous counter gives no baseline, so the tick yields 0", () => {
  const r = computeRates(snap(0, { eth0: { rx: NaN, tx: undefined } }),
    snap(1000, { eth0: { rx: 5000000, tx: 5000000 } }), 1000);
  assert.deepEqual(r, { valid: true, rates: { eth0: { down: 0, up: 0 } } });
});
test("non-finite or negative new counter counts as 0 and never yields a negative rate", () => {
  const r = computeRates(snap(0, { eth0: { rx: 100, tx: 100 } }),
    snap(1000, { eth0: { rx: NaN, tx: -5 } }), 1000);
  assert.deepEqual(r, { valid: true, rates: { eth0: { down: 0, up: 0 } } });
});
test("non-finite timestamp invalidates sample", () => {
  assert.deepEqual(computeRates(snap(0, { eth0: { rx: 0, tx: 0 } }), snap(NaN, { eth0: { rx: 9, tx: 9 } }), 1000),
    { valid: false, rates: {} });
  assert.deepEqual(computeRates(snap(NaN, { eth0: { rx: 0, tx: 0 } }), snap(1000, { eth0: { rx: 9, tx: 9 } }), 1000),
    { valid: false, rates: {} });
});
