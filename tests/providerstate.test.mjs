// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import { test } from "node:test";
import assert from "node:assert/strict";
import { initialState, reduce, derive } from "../package/contents/code/providerstate.mjs";

const iface = (o) => ({ down: 0, up: 0, totalDown: 0, totalUp: 0, kind: "physical", online: true,
  label: "", ipv4: "", ipv6: "", signal: null, ...o });
const sample = (source, interfaces) => ({ timestamp: 0, source, interfaces });
const at = (now) => ({ mode: "auto", selected: [], now, intervalMs: 1000 });
const feed = (state, s, now) => reduce(state, { type: "sample", sample: s, now });

test("no data before the first sample", () => {
  const v = derive(initialState(), at(0));
  assert.deepEqual([v.hasData, v.activeSource, v.down, v.stale, v.includedCount], [false, "", 0, false, 0]);
});
test("sample populates the view", () => {
  const v = derive(feed(initialState(), sample("proc", { eth0: iface({ down: 5, up: 6, ipv4: "10.0.0.2" }) }), 100), at(100));
  assert.deepEqual([v.hasData, v.down, v.up, v.activeSource, v.includedCount, v.primaryLabel, v.primaryIp, v.stale],
    [true, 5, 6, "proc", 1, "eth0", "10.0.0.2", false]);
});
test("source change clears retained data and errors", () => {
  let s = feed(initialState(), sample("proc", { eth0: iface({ down: 5 }) }), 0);
  s = reduce(s, { type: "failed", message: "x" });
  s = reduce(s, { type: "source-changed" });
  const v = derive(s, at(10));
  assert.deepEqual([v.hasData, v.activeSource, v.errorCode, v.down], [false, "", "", 0]);
});
test("failure keeps values, the next sample recovers", () => {
  let s = feed(initialState(), sample("proc", { eth0: iface({ down: 5 }) }), 0);
  s = reduce(s, { type: "failed", message: "boom" });
  let v = derive(s, at(500));
  assert.deepEqual([v.errorCode, v.errorDetail, v.down], ["source-failed", "boom", 5]);
  v = derive(feed(s, sample("proc", { eth0: iface({ down: 7 }) }), 1000), at(1000));
  assert.deepEqual([v.errorCode, v.down], ["", 7]);
});
test("auto-fallback note persists across samples until the source changes", () => {
  let s = reduce(initialState(), { type: "fallback", reason: "sensors-unavailable" });
  assert.deepEqual([derive(s, at(0)).hasData, derive(s, at(0)).errorCode], [false, "sensors-unavailable"]);
  s = feed(s, sample("proc", { eth0: iface({}) }), 0);
  assert.deepEqual([derive(s, at(0)).errorCode, derive(s, at(0)).fallbackNote], ["sensors-unavailable", "sensors-unavailable"]);
  assert.equal(derive(reduce(s, { type: "source-changed" }), at(0)).errorCode, "");
});
test("forced source: empty startup stays without data, recovers when interfaces appear", () => {
  let s = feed(initialState(), sample("sensors", {}), 0);
  s = reduce(s, { type: "unavailable", reason: "no-interfaces" });
  s = feed(s, sample("sensors", {}), 1000);
  let v = derive(s, at(1000));
  assert.deepEqual([v.hasData, v.errorCode, v.stale], [false, "no-interfaces", false]);
  s = feed(s, sample("sensors", { eth0: iface({ down: 4 }) }), 2000);
  v = derive(s, at(2000));
  assert.deepEqual([v.hasData, v.errorCode, v.down], [true, "", 4]);
});
test("stale after more than three intervals without a sample", () => {
  const s = feed(initialState(), sample("sensors", { eth0: iface({}) }), 0);
  assert.equal(derive(s, at(3000)).stale, false);
  assert.equal(derive(s, at(3001)).stale, true);
});
test("last interface vanishing clears sums and primary, reappearing restores", () => {
  let s = feed(initialState(), sample("sensors", { eth0: iface({ down: 9, ipv4: "1.2.3.4" }) }), 0);
  s = feed(s, sample("sensors", {}), 1000);
  const v = derive(s, at(1000));
  assert.deepEqual([v.down, v.up, v.online, v.includedCount, v.primaryLabel, v.primaryIp, v.interfaces.length],
    [0, 0, false, 0, "", "", 0]);
  assert.equal(derive(feed(s, sample("sensors", { eth0: iface({ down: 3 }) }), 2000), at(2000)).down, 3);
});
test("reduce does not mutate its input", () => {
  const a = initialState();
  const b = reduce(a, { type: "failed", message: "m" });
  assert.equal(a.errorCode, "");
  assert.notEqual(a, b);
});
test("primary label falls back to the name, primary ip to ipv6", () => {
  const view = (o) => derive(feed(initialState(), sample("sensors", { eth0: iface(o) }), 0), at(0));
  assert.deepEqual([view({ label: "Home", ipv4: "10.0.0.2" }).primaryLabel, view({ label: "Home" }).primaryIp], ["Home", ""]);
  assert.deepEqual([view({}).primaryLabel, view({ ipv6: "fe80::1" }).primaryIp], ["eth0", "fe80::1"]);
});
test("manual mode with a vanished selection shows zero, not an error", () => {
  const s = feed(initialState(), sample("sensors", { eth0: iface({ down: 5 }) }), 0);
  const v = derive(s, { mode: "manual", selected: ["eth9"], now: 0, intervalMs: 1000 });
  assert.deepEqual([v.hasData, v.down, v.online, v.includedCount, v.errorCode, v.interfaces.length], [true, 0, false, 0, "", 1]);
});
test("unavailable keeps retained values and detail stays empty", () => {
  let s = feed(initialState(), sample("sensors", { eth0: iface({ down: 5 }) }), 0);
  s = reduce(s, { type: "failed", message: "x" });
  s = reduce(s, { type: "unavailable", reason: "no-interfaces" });
  const v = derive(s, at(0));
  assert.deepEqual([v.errorCode, v.errorDetail, v.down], ["no-interfaces", "", 5]);
});
test("a failure before any data keeps the display empty and unknown events change nothing", () => {
  const s = reduce(initialState(), { type: "failed", message: "boom" });
  assert.deepEqual([derive(s, at(0)).hasData, derive(s, at(0)).errorCode], [false, "source-failed"]);
  assert.equal(reduce(s, { type: "bogus" }), s);
});
test("a failure after the fallback is replaced by the note again on the next sample", () => {
  let s = reduce(initialState(), { type: "fallback", reason: "no-interfaces" });
  s = reduce(s, { type: "failed", message: "boom" });
  assert.equal(derive(s, at(0)).errorCode, "source-failed");
  s = feed(s, sample("proc", { eth0: iface({}) }), 0);
  assert.deepEqual([derive(s, at(0)).errorCode, derive(s, at(0)).errorDetail], ["no-interfaces", ""]);
});
