// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import { test } from "node:test";
import assert from "node:assert/strict";
import { syncOps } from "../package/contents/code/listsync.mjs";
import { compareNames } from "../package/contents/code/selection.mjs";

// The two procedures as they stood in the QML files before they shared this
// module; they serve as the reference for the behaviour that must not change.
// Both work on a plain array in place of the ListModel.

// SensorSource.syncModel: remove vanished rows from the end, append new names.
function oldAppendSync(rows, names) {
  const present = [];
  for (let row = rows.length - 1; row >= 0; row--) {
    if (names.indexOf(rows[row]) < 0) {
      rows.splice(row, 1);
    } else {
      present.push(rows[row]);
    }
  }
  for (const name of names) {
    if (present.indexOf(name) < 0) rows.push(name);
  }
}

// ConfigData.syncRows: remove vanished rows from the end, insert new names
// before the first row that sorts after them.
function oldSortedSync(rows, wanted) {
  for (let row = rows.length - 1; row >= 0; row--) {
    if (wanted.indexOf(rows[row]) < 0) rows.splice(row, 1);
  }
  for (const name of wanted) {
    let at = 0;
    let present = false;
    for (; at < rows.length; at++) {
      if (rows[at] === name) {
        present = true;
        break;
      }
      if (compareNames(rows[at], name) > 0) break;
    }
    if (!present) rows.splice(at, 0, name);
  }
}

function apply(rows, ops) {
  const result = rows.slice();
  for (const op of ops) {
    if (op.op === "remove") result.splice(op.index, 1);
    else result.splice(op.index, 0, op.name);
  }
  return result;
}

test("a vanished row is removed, the others stay", () => {
  assert.deepEqual(syncOps(["a", "b", "c"], ["a", "c"]), [{ op: "remove", index: 1 }]);
});

test("nothing to do gives no operations", () => {
  assert.deepEqual(syncOps(["a", "b"], ["a", "b"]), []);
  assert.deepEqual(syncOps([], []), []);
  assert.deepEqual(syncOps(["a", "b"], ["b", "a"]), [], "the order of kept rows is not changed");
});

test("without compare new names are appended in the order wanted", () => {
  assert.deepEqual(syncOps(["b"], ["c", "b", "a"]), [
    { op: "insert", index: 1, name: "c" },
    { op: "insert", index: 2, name: "a" },
  ]);
});

test("with compare new names go to their sorted place, indexes after earlier operations", () => {
  assert.deepEqual(syncOps(["b"], ["a", "b", "c"], compareNames), [
    { op: "insert", index: 0, name: "a" },
    { op: "insert", index: 2, name: "c" },
  ]);
  assert.deepEqual(syncOps(["b", "d"], ["c", "a", "b", "d"], compareNames), [
    { op: "insert", index: 1, name: "c" },
    { op: "insert", index: 0, name: "a" },
  ]);
});

test("a name wanted twice is handled once", () => {
  assert.deepEqual(syncOps([], ["x", "x"]), [{ op: "insert", index: 0, name: "x" }]);
  assert.deepEqual(syncOps(["x"], ["x", "x"]), []);
  assert.deepEqual(syncOps([], ["y", "x", "y"], compareNames), [
    { op: "insert", index: 0, name: "y" },
    { op: "insert", index: 0, name: "x" },
  ]);
});

test("removals come first and from the highest index down", () => {
  assert.deepEqual(syncOps(["a", "b", "c", "d"], ["b", "e"]), [
    { op: "remove", index: 3 },
    { op: "remove", index: 2 },
    { op: "remove", index: 0 },
    { op: "insert", index: 1, name: "e" },
  ]);
});

test("everything vanishing and everything new", () => {
  assert.deepEqual(syncOps(["a", "b"], []), [
    { op: "remove", index: 1 },
    { op: "remove", index: 0 },
  ]);
  assert.deepEqual(syncOps([], ["b", "a"], compareNames), [
    { op: "insert", index: 0, name: "b" },
    { op: "insert", index: 0, name: "a" },
  ]);
});

// Small deterministic generator (mulberry32), so the cases are fixed.
function generator(seed) {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const POOL = ["lo", "enp7s0", "wlp3s0", "docker0", "WorkVPN", "workvpn", "br-1", "tun0", "Ghost"];

function pick(next, max) {
  const list = [];
  const count = Math.floor(next() * (max + 1));
  for (let i = 0; i < count; i++) list.push(POOL[Math.floor(next() * POOL.length)]);
  return list;
}

test("fixed random cases: same result as the procedures they replace, survivors are never removed", () => {
  const next = generator(20261024);
  for (let n = 0; n < 500; n++) {
    const unique = [...new Set(pick(next, 7))];
    const wanted = pick(next, 8);

    // Unsorted current list, appended behaviour.
    const appended = apply(unique, syncOps(unique, wanted));
    const expectedAppended = unique.slice();
    // The old procedure appended a repeated name twice; names are unique in
    // practice and the shared one handles a repeat once, so compare on unique names.
    oldAppendSync(expectedAppended, [...new Set(wanted)]);
    assert.deepEqual(appended, expectedAppended, `append ${JSON.stringify([unique, wanted])}`);
    const keptInOrder = unique.filter((name) => wanted.includes(name));
    assert.deepEqual(appended.slice(0, keptInOrder.length), keptInOrder);

    // Sorted current list, sorted behaviour.
    const sorted = unique.slice().sort(compareNames);
    const ops = syncOps(sorted, wanted, compareNames);
    const result = apply(sorted, ops);
    const expectedSorted = sorted.slice();
    oldSortedSync(expectedSorted, wanted);
    assert.deepEqual(result, expectedSorted, `sorted ${JSON.stringify([sorted, wanted])}`);
    assert.deepEqual(result, [...new Set(wanted)].sort(compareNames));

    // Rows that stay are neither removed nor inserted again.
    for (const name of sorted.filter((entry) => wanted.includes(entry))) {
      assert.ok(!ops.some((op) => op.op === "insert" && op.name === name));
    }
    const removedNames = ops.filter((op) => op.op === "remove").map((op) => sorted[op.index]);
    assert.ok(removedNames.every((name) => !wanted.includes(name)));
    const firstInsert = ops.findIndex((op) => op.op === "insert");
    assert.ok(firstInsert < 0 || ops.slice(firstInsert).every((op) => op.op === "insert"));
  }
});
