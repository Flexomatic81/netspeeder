// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import { test } from "node:test";
import assert from "node:assert/strict";
import { autoHideState, nextIdle } from "../package/contents/code/visibility.mjs";

const START = { belowSince: null, lastNow: null };
const quiet = (now, extra) => Object.assign({ total: 0, now, threshold: 1024, seconds: 30 }, extra || {});

function run(state, inputs) {
  return inputs.reduce(
    (acc, input) => {
      const s = nextIdle(acc.state, input);
      return { state: s, trace: acc.trace.concat([s.idle]) };
    },
    { state, trace: [] },
  );
}

test("idle after the configured quiet time, not before", () => {
  const a = nextIdle(START, quiet(1000));
  assert.equal(a.belowSince, 1000);
  assert.equal(nextIdle(a, quiet(30999)).idle, false);
  assert.equal(nextIdle(a, quiet(31000)).idle, true);
});

test("a value at or above the threshold resets", () => {
  let s = nextIdle(START, quiet(0));
  s = nextIdle(s, quiet(20000, { total: 1024 }));
  assert.deepEqual(s, { belowSince: null, lastNow: 20000, idle: false });
  s = nextIdle(s, quiet(21000));
  assert.equal(nextIdle(s, quiet(50999)).idle, false);
  assert.equal(nextIdle(s, quiet(51000)).idle, true);
});

test("a clock that goes back restarts the quiet period", () => {
  const start = { belowSince: 100000, lastNow: 100000 };
  const r = run(start, [quiet(129000), quiet(120000), quiet(130000)]);
  assert.deepEqual(r.trace, [false, false, false]);
  assert.equal(r.state.belowSince, 120000);
  assert.equal(nextIdle(r.state, quiet(149999)).idle, false);
  assert.equal(nextIdle(r.state, quiet(150000)).idle, true);
});

test("only timestamps matter, not how often they come", () => {
  const dense = run(
    START,
    [0, 5000, 10000, 20000, 29000, 30000].map((t) => quiet(t)),
  );
  assert.equal(dense.trace[5], true);
  assert.equal(dense.trace[4], false);
  assert.equal(nextIdle({ belowSince: 0, lastNow: 0 }, quiet(30000)).idle, true);
});

test("threshold 0 is never idle", () => {
  const r = run(
    START,
    [0, 40000, 80000].map((t) => quiet(t, { threshold: 0 })),
  );
  assert.deepEqual(r.trace, [false, false, false]);
});

test("invalid total counts as activity", () => {
  for (const total of [NaN, Infinity, undefined, null, "5"]) {
    const s = nextIdle({ belowSince: 0, lastNow: 0 }, quiet(60000, { total }));
    assert.deepEqual(s, { belowSince: null, lastNow: 60000, idle: false });
  }
});

test("invalid threshold falls back to 1024", () => {
  for (const threshold of [-1, 1.5, NaN, "x", undefined, null]) {
    assert.equal(nextIdle(START, quiet(0, { threshold, total: 1023 })).belowSince, 0);
    assert.equal(nextIdle(START, quiet(0, { threshold, total: 1024 })).belowSince, null);
  }
});

test("invalid seconds fall back to 30, valid range is 5 to 3600", () => {
  const base = { belowSince: 0, lastNow: 0 };
  for (const seconds of [4, 3601, 7.5, NaN, "9", undefined]) {
    assert.equal(nextIdle(base, quiet(29999, { seconds })).idle, false);
    assert.equal(nextIdle(base, quiet(30000, { seconds })).idle, true);
  }
  assert.equal(nextIdle(base, quiet(5000, { seconds: 5 })).idle, true);
  assert.equal(nextIdle(base, quiet(3600000, { seconds: 3600 })).idle, true);
  assert.equal(nextIdle(base, quiet(3599999, { seconds: 3600 })).idle, false);
});

test("an invalid time is no idleness and keeps the last good time", () => {
  const s = nextIdle({ belowSince: 0, lastNow: 500 }, quiet(NaN));
  assert.deepEqual(s, { belowSince: null, lastNow: 500, idle: false });
  assert.deepEqual(nextIdle(START, quiet(undefined)), { belowSince: null, lastNow: 0, idle: false });
});

function expected(mode, v, c) {
  let reason = false;
  const live = v.hasData && !v.stale;
  if (mode === "offline") reason = live && !v.online;
  if (mode === "idle") reason = live && (!v.online || v.idle);
  if (!reason || c.expanded) return "shown";
  return c.editMode ? "placeholder" : "hidden";
}

function* combinations() {
  for (const mode of ["never", "offline", "idle", "bogus", "", undefined]) {
    for (let bits = 0; bits < 64; bits++) {
      const on = (n) => (bits & (1 << n)) !== 0;
      yield [mode, { hasData: on(0), online: on(1), idle: on(2), stale: on(5) }, { editMode: on(3), expanded: on(4) }];
    }
  }
}

test("autoHideState over the whole table", () => {
  let count = 0;
  for (const [mode, v, c] of combinations()) {
    assert.equal(autoHideState(mode, v, c), expected(mode, v, c), JSON.stringify([mode, v, c]));
    count++;
  }
  assert.equal(count, 384);
});

test("stale data is never hidden, in every mode", () => {
  const c = { editMode: false, expanded: false };
  for (const mode of ["offline", "idle"]) {
    const v = { hasData: true, online: false, idle: true, stale: true };
    assert.equal(autoHideState(mode, v, c), "shown", mode);
    assert.equal(autoHideState(mode, { ...v, stale: false }, c), "hidden", mode);
    assert.equal(autoHideState(mode, v, { editMode: true, expanded: false }), "shown", mode);
  }
});

test("known cases and never hidden before the first data", () => {
  const c = { editMode: false, expanded: false };
  assert.equal(autoHideState("offline", { hasData: true, online: false, idle: false }, c), "hidden");
  assert.equal(
    autoHideState("idle", { hasData: true, online: true, idle: true }, { editMode: true, expanded: false }),
    "placeholder",
  );
  assert.equal(
    autoHideState("idle", { hasData: true, online: true, idle: true }, { editMode: false, expanded: true }),
    "shown",
  );
  for (const mode of ["offline", "idle", "never"]) {
    assert.equal(autoHideState(mode, { hasData: false, online: false, idle: true }, c), "shown");
  }
});
