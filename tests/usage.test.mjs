// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { parseVnstat } from "../package/contents/code/vnstat.mjs";
import {
  addDays,
  periodFor,
  previousPeriod,
  usageSummary,
  emptySummary,
  usageNames,
  capState,
  capNotification,
  capAction,
  isOutdated,
} from "../package/contents/code/usage.mjs";

const fixture = parseVnstat(readFileSync(new URL("./fixtures/vnstat-v2.json", import.meta.url), "utf8"));
const TODAY = { year: 2026, month: 10, day: 24 };
const GIB = 1024 * 1024 * 1024;

function day(date, rx, tx) {
  return { date, rx, tx };
}

function parsedWith(interfaces) {
  return { status: "ok", version: "2", interfaces };
}

// --- addDays ---------------------------------------------------------------

test("addDays moves across months, years and leap days", () => {
  assert.equal(addDays("2028-02-28", 1), "2028-02-29");
  assert.equal(addDays("2027-02-28", 1), "2027-03-01");
  assert.equal(addDays("2028-03-01", -1), "2028-02-29");
  assert.equal(addDays("2026-12-31", 1), "2027-01-01");
  assert.equal(addDays("2027-01-01", -1), "2026-12-31");
  assert.equal(addDays("2026-10-24", 0), "2026-10-24");
  assert.equal(addDays("2026-10-24", -365), "2025-10-24");
  assert.equal(addDays("2000-02-28", 1), "2000-02-29");
  assert.equal(addDays("1900-02-28", 1), "1900-03-01");
});

test("addDays rejects invalid keys and steps", () => {
  assert.equal(addDays("2026-02-30", 1), "");
  assert.equal(addDays("2026-13-01", 1), "");
  assert.equal(addDays("x", 1), "");
  assert.equal(addDays(null, 1), "");
  assert.equal(addDays("2026-10-24", 1.5), "");
});

// --- periodFor / previousPeriod ---------------------------------------------

test("periodFor with billing day 1 is the calendar month", () => {
  assert.deepEqual(periodFor(TODAY, 1), { start: "2026-10-01", end: "2026-10-31" });
});

test("periodFor before the billing day starts in the previous month", () => {
  assert.deepEqual(periodFor(TODAY, 25), { start: "2026-09-25", end: "2026-10-24" });
});

test("periodFor on the billing day starts a new period", () => {
  assert.deepEqual(periodFor({ year: 2026, month: 10, day: 25 }, 25), { start: "2026-10-25", end: "2026-11-24" });
});

test("periodFor crosses the year boundary", () => {
  assert.deepEqual(periodFor({ year: 2027, month: 1, day: 5 }, 20), { start: "2026-12-20", end: "2027-01-19" });
  assert.deepEqual(periodFor({ year: 2026, month: 12, day: 20 }, 20), { start: "2026-12-20", end: "2027-01-19" });
});

test("periodFor with day 28 in a leap year", () => {
  assert.deepEqual(periodFor({ year: 2028, month: 3, day: 1 }, 28), { start: "2028-02-28", end: "2028-03-27" });
  assert.deepEqual(periodFor({ year: 2028, month: 2, day: 28 }, 28), { start: "2028-02-28", end: "2028-03-27" });
});

test("periodFor falls back to billing day 1 for invalid values", () => {
  const month = { start: "2026-10-01", end: "2026-10-31" };
  assert.deepEqual(periodFor(TODAY, 0), month);
  assert.deepEqual(periodFor(TODAY, 29), month);
  assert.deepEqual(periodFor(TODAY, "x"), month);
  assert.deepEqual(periodFor(TODAY, 2.5), month);
  assert.deepEqual(periodFor(TODAY, undefined), month);
});

test("previousPeriod is the period right before", () => {
  assert.deepEqual(previousPeriod({ start: "2026-10-01", end: "2026-10-31" }), {
    start: "2026-09-01",
    end: "2026-09-30",
  });
  assert.deepEqual(previousPeriod({ start: "2026-09-25", end: "2026-10-24" }), {
    start: "2026-08-25",
    end: "2026-09-24",
  });
});

test("previousPeriod crosses the year boundary", () => {
  assert.deepEqual(previousPeriod({ start: "2027-01-01", end: "2027-01-31" }), {
    start: "2026-12-01",
    end: "2026-12-31",
  });
  assert.deepEqual(previousPeriod({ start: "2027-01-20", end: "2027-02-19" }), {
    start: "2026-12-20",
    end: "2027-01-19",
  });
});

test("previousPeriod of an invalid period is empty", () => {
  assert.deepEqual(previousPeriod({ start: "nope", end: "" }), { start: "", end: "" });
  assert.deepEqual(previousPeriod(null), { start: "", end: "" });
});

// --- usageSummary -----------------------------------------------------------

const ZERO = { down: 0, up: 0, total: 0 };

test("usageSummary without a result is status none with zeros", () => {
  const r = usageSummary(null, ["eth0"], TODAY, 1);
  assert.deepEqual(r, {
    status: "none",
    today: ZERO,
    yesterday: ZERO,
    current: { ...ZERO, start: "2026-10-01", end: "2026-10-31", complete: false },
    previous: { ...ZERO, start: "2026-09-01", end: "2026-09-30", complete: false },
    untracked: [],
  });
  assert.deepEqual(emptySummary(TODAY, 1), r);
});

test("usageSummary keeps a non-ok status with zeros and computed periods", () => {
  const r = usageSummary({ status: "unsupported", version: "1", interfaces: {} }, ["eth0"], TODAY, 25);
  assert.equal(r.status, "unsupported");
  assert.deepEqual(r.today, ZERO);
  assert.deepEqual(r.current, { ...ZERO, start: "2026-09-25", end: "2026-10-24", complete: false });
  assert.deepEqual(r.previous, { ...ZERO, start: "2026-08-25", end: "2026-09-24", complete: false });
  assert.deepEqual(r.untracked, []);
  assert.equal(usageSummary({ status: "invalid", version: "", interfaces: {} }, [], TODAY, 1).status, "invalid");
});

// Expected values worked out by hand from tests/fixtures/vnstat-v2.json.
test("usageSummary sums the fixture exactly", () => {
  const r = usageSummary(fixture, ["eth0", "wlan0"], TODAY, 1);
  assert.equal(r.status, "ok");
  // 10-24: eth0 640M/75M + wlan0 120M/18M
  assert.deepEqual(r.today, { down: 760000000, up: 93000000, total: 853000000 });
  // 10-23: eth0 only
  assert.deepEqual(r.yesterday, { down: 950000000, up: 120000000, total: 1070000000 });
  // October: eth0 2100M+950M+640M / 260M+120M+75M, wlan0 300M+700M+120M / 30M+64M+18M
  assert.deepEqual(r.current, {
    down: 4810000000,
    up: 567000000,
    total: 5377000000,
    start: "2026-10-01",
    end: "2026-10-31",
    complete: false,
  });
  // September: eth0 5400M+310M / 420M+40M
  assert.deepEqual(r.previous, {
    down: 5710000000,
    up: 460000000,
    total: 6170000000,
    start: "2026-09-01",
    end: "2026-09-30",
    complete: false,
  });
  assert.deepEqual(r.untracked, []);
});

test("usageSummary with eth0 only is complete", () => {
  const r = usageSummary(fixture, ["eth0"], TODAY, 1);
  assert.equal(r.current.complete, true);
  assert.equal(r.previous.complete, true);
  assert.deepEqual(r.current, {
    down: 3690000000,
    up: 455000000,
    total: 4145000000,
    start: "2026-10-01",
    end: "2026-10-31",
    complete: true,
  });
});

test("usageSummary with billing day 25 splits at the 25th", () => {
  const r = usageSummary(fixture, ["eth0"], TODAY, 25);
  // 09-25 .. 10-24: eth0 09-30, 10-01, 10-23, 10-24
  assert.deepEqual(
    { down: r.current.down, up: r.current.up },
    { down: 310000000 + 2100000000 + 950000000 + 640000000, up: 40000000 + 260000000 + 120000000 + 75000000 },
  );
  // 08-25 .. 09-24: eth0 09-03; the oldest day 08-20 lies before the start
  assert.deepEqual({ down: r.previous.down, complete: r.previous.complete }, { down: 5400000000, complete: true });
});

test("usageSummary lists unknown names sorted in untracked", () => {
  const r = usageSummary(fixture, ["wlan0", "tun0", "docker0", "eth0", "docker0"], TODAY, 1);
  assert.deepEqual(r.untracked, ["docker0", "tun0"]);
  assert.equal(r.today.down, 760000000);
});

test("usageSummary counts a name listed twice once", () => {
  const r = usageSummary(fixture, ["eth0", "eth0"], TODAY, 1);
  assert.equal(r.today.down, 640000000);
});

test("usageSummary with no counted interface is never complete", () => {
  const r = usageSummary(fixture, ["docker0"], TODAY, 1);
  assert.deepEqual(r.current, { ...ZERO, start: "2026-10-01", end: "2026-10-31", complete: false });
  assert.deepEqual(r.untracked, ["docker0"]);
  assert.equal(usageSummary(fixture, [], TODAY, 1).current.complete, false);
  assert.equal(usageSummary(fixture, null, TODAY, 1).current.complete, false);
});

test("shorter retention makes the period incomplete", () => {
  // Interface known since August, but only the last ten days are delivered.
  const days = [];
  for (let i = 9; i >= 0; i--) days.push(day(addDays("2026-10-24", -i), 1, 1));
  const parsed = parsedWith({ eth0: { created: "2026-08-01", updated: "", days } });
  const r = usageSummary(parsed, ["eth0"], TODAY, 1);
  assert.equal(r.current.complete, false);
  assert.equal(r.current.down, 10);
});

test("an empty day list is incomplete", () => {
  const parsed = parsedWith({ eth0: { created: "2026-08-01", updated: "", days: [] } });
  assert.equal(usageSummary(parsed, ["eth0"], TODAY, 1).current.complete, false);
});

test("a missing created date is incomplete", () => {
  const parsed = parsedWith({ eth0: { created: "", updated: "", days: [day("2026-09-01", 1, 1)] } });
  assert.equal(usageSummary(parsed, ["eth0"], TODAY, 1).current.complete, false);
});

test("a gap without a day up to the start is incomplete", () => {
  const parsed = parsedWith({
    eth0: { created: "2026-08-01", updated: "", days: [day("2026-10-02", 1, 1), day("2026-10-20", 1, 1)] },
  });
  assert.equal(usageSummary(parsed, ["eth0"], TODAY, 1).current.complete, false);
});

test("a day exactly on the start is complete", () => {
  const parsed = parsedWith({ eth0: { created: "2026-10-01", updated: "", days: [day("2026-10-01", 5, 7)] } });
  const r = usageSummary(parsed, ["eth0"], TODAY, 1);
  assert.equal(r.current.complete, true);
  assert.deepEqual({ down: r.current.down, up: r.current.up, total: r.current.total }, { down: 5, up: 7, total: 12 });
});

test("an interface without a day list counts as empty", () => {
  const parsed = parsedWith({ eth0: { created: "2026-08-01", updated: "" } });
  const r = usageSummary(parsed, ["eth0"], TODAY, 1);
  assert.equal(r.current.complete, false);
  assert.equal(r.current.total, 0);
});

// --- usageNames -------------------------------------------------------------

test("manual mode keeps configured names that are absent", () => {
  assert.deepEqual(
    usageNames("manual", ["tun0", "eth0"], [{ name: "eth0", kind: "physical", included: true }], ["eth0"]),
    ["eth0", "tun0"],
  );
});

test("manual mode drops the loopback device and duplicates", () => {
  assert.deepEqual(usageNames("manual", ["lo", "eth0", "eth0"], [], ["lo", "eth0"]), ["eth0"]);
});

test("auto mode leaves out interfaces the provider reports as virtual", () => {
  const live = [
    { name: "eth0", kind: "physical", included: true },
    { name: "docker0", kind: "virtual", included: false },
  ];
  assert.deepEqual(usageNames("auto", [], live, ["eth0", "docker0", "lo"]), ["eth0"]);
});

test("auto mode keeps absent interfaces vnstat knows", () => {
  const live = [{ name: "eth0", kind: "physical", included: true }];
  assert.deepEqual(usageNames("auto", [], live, ["eth1", "eth0"]), ["eth0", "eth1"]);
});

test("auto mode adds included live interfaces vnstat does not know", () => {
  const live = [
    { name: "WLAN0", kind: "physical", included: true },
    { name: "wlan0", kind: "physical", included: true },
    { name: "tun0", kind: "virtual", included: false },
    { name: "eth0", kind: "physical", included: true },
  ];
  assert.deepEqual(usageNames("auto", ["tun0"], live, ["eth0", "eth0"]), ["eth0", "WLAN0", "wlan0"]);
});

test("usageNames copes with missing lists", () => {
  assert.deepEqual(usageNames("auto", null, null, null), []);
  assert.deepEqual(usageNames("manual", null, null, null), []);
  assert.deepEqual(usageNames("auto", [], [null, { kind: "physical", included: true }], ["eth0"]), ["eth0"]);
});

// --- capState ---------------------------------------------------------------

test("capState computes percent and level", () => {
  assert.deepEqual(capState(0, 100, 80), { percent: 0, level: 0 });
  assert.deepEqual(capState(79.9 * GIB, 100, 80), { percent: 79.9, level: 0 });
  assert.deepEqual(capState(80 * GIB, 100, 80), { percent: 80, level: 1 });
  assert.deepEqual(capState(100 * GIB, 100, 80), { percent: 100, level: 2 });
  assert.deepEqual(capState(150 * GIB, 100, 80), { percent: 150, level: 2 });
});

test("capState rounds the percent to one decimal", () => {
  assert.equal(capState(GIB / 3, 1, 80).percent, 33.3);
});

test("capState rounds the percent down, so it never shows a level not reached", () => {
  assert.deepEqual(capState(99.95 * GIB, 100, 80), { percent: 99.9, level: 1 });
  assert.deepEqual(capState(99.96 * GIB, 100, 80), { percent: 99.9, level: 1 });
  assert.deepEqual(capState(99.999 * GIB, 100, 80), { percent: 99.9, level: 1 });
  assert.deepEqual(capState(79.96 * GIB, 100, 80), { percent: 79.9, level: 0 });
});

test("capState with an invalid cap is zero", () => {
  assert.deepEqual(capState(GIB, 0, 80), { percent: 0, level: 0 });
  assert.deepEqual(capState(GIB, -1, 80), { percent: 0, level: 0 });
  assert.deepEqual(capState(GIB, NaN, 80), { percent: 0, level: 0 });
  assert.deepEqual(capState(GIB, Infinity, 80), { percent: 0, level: 0 });
  assert.deepEqual(capState(GIB, "10", 80), { percent: 0, level: 0 });
});

test("capState with an invalid total counts zero", () => {
  assert.deepEqual(capState(NaN, 10, 80), { percent: 0, level: 0 });
  assert.deepEqual(capState(-5, 10, 80), { percent: 0, level: 0 });
});

test("capState falls back to warning at 80 percent", () => {
  for (const warn of [0, 100, 50.5, "x", undefined]) {
    assert.equal(capState(80 * GIB, 100, warn).level, 1, String(warn));
    assert.equal(capState(79 * GIB, 100, warn).level, 0, String(warn));
  }
  assert.equal(capState(50 * GIB, 100, 50).level, 1);
});

// --- capNotification --------------------------------------------------------

const NONE = { cycle: "", level: 0 };

test("capNotification reports the first warning", () => {
  assert.deepEqual(capNotification(1, "2026-10-01", NONE, true), {
    notify: 1,
    store: { cycle: "2026-10-01", level: 1 },
  });
});

test("capNotification stays quiet for the same level in the same period", () => {
  const stored = { cycle: "2026-10-01", level: 1 };
  assert.deepEqual(capNotification(1, "2026-10-01", stored, true), { notify: 0, store: stored });
});

test("capNotification reports only the highest new level", () => {
  assert.deepEqual(capNotification(2, "2026-10-01", NONE, true), {
    notify: 2,
    store: { cycle: "2026-10-01", level: 2 },
  });
  assert.deepEqual(capNotification(2, "2026-10-01", { cycle: "2026-10-01", level: 1 }, true), {
    notify: 2,
    store: { cycle: "2026-10-01", level: 2 },
  });
});

test("capNotification reports again in a new period", () => {
  assert.deepEqual(capNotification(1, "2026-11-01", { cycle: "2026-10-01", level: 2 }, true), {
    notify: 1,
    store: { cycle: "2026-11-01", level: 1 },
  });
  assert.deepEqual(capNotification(0, "2026-11-01", { cycle: "2026-10-01", level: 2 }, true), {
    notify: 0,
    store: { cycle: "2026-11-01", level: 0 },
  });
});

test("capNotification does not repeat after a raised cap in the same period", () => {
  const stored = { cycle: "2026-10-01", level: 2 };
  const lowered = capNotification(1, "2026-10-01", stored, true);
  assert.deepEqual(lowered, { notify: 0, store: stored });
  assert.deepEqual(capNotification(2, "2026-10-01", lowered.store, true), { notify: 0, store: stored });
});

test("capNotification never reports or stores while inactive", () => {
  const stored = { cycle: "2026-09-01", level: 1 };
  assert.deepEqual(capNotification(2, "2026-10-01", stored, false), { notify: 0, store: stored });
});

test("capNotification returns a normalized store while inactive", () => {
  const off = { notify: 0, store: { cycle: "", level: 0 } };
  assert.deepEqual(capNotification(2, "2026-10-01", null, false), off);
  assert.deepEqual(capNotification(2, "2026-10-01", undefined, false), off);
  assert.deepEqual(capNotification(2, "2026-10-01", { level: 7 }, false), off);
  assert.deepEqual(capNotification(2, "2026-10-01", { cycle: 5, level: 1.5 }, false), {
    notify: 0,
    store: { cycle: "5", level: 0 },
  });
  assert.deepEqual(capNotification(2, "2026-10-01", { cycle: "2026-09-01", level: 2, extra: true }, false), {
    notify: 0,
    store: { cycle: "2026-09-01", level: 2 },
  });
});

test("capNotification treats a malformed store as nothing reported", () => {
  assert.deepEqual(capNotification(1, "2026-10-01", null, true), {
    notify: 1,
    store: { cycle: "2026-10-01", level: 1 },
  });
  assert.deepEqual(capNotification(1, "2026-10-01", { cycle: 5, level: "x" }, true), {
    notify: 1,
    store: { cycle: "2026-10-01", level: 1 },
  });
});

// --- capAction --------------------------------------------------------------

function action(overrides) {
  return {
    usageEnabled: true,
    dataCapEnabled: true,
    capNotify: true,
    freshOk: true,
    level: 1,
    cycle: "2026-10-01",
    notified: NONE,
    ...overrides,
  };
}

test("capAction notifies when everything is on", () => {
  assert.deepEqual(capAction(action({})), { notify: 1, store: { cycle: "2026-10-01", level: 1 } });
});

test("capAction does nothing with the cap off", () => {
  assert.deepEqual(capAction(action({ dataCapEnabled: false })), { notify: 0, store: NONE });
});

test("capAction does nothing with usage off", () => {
  assert.deepEqual(capAction(action({ usageEnabled: false })), { notify: 0, store: NONE });
});

test("capAction does nothing after an error that follows a success", () => {
  const stored = { cycle: "2026-10-01", level: 1 };
  assert.deepEqual(capAction(action({ freshOk: false, level: 2, notified: stored })), { notify: 0, store: stored });
});

test("capAction with notifications off stores the level without notifying", () => {
  const r = capAction(action({ capNotify: false, level: 2 }));
  assert.deepEqual(r, { notify: 0, store: { cycle: "2026-10-01", level: 2 } });
  // Turning notifications on later does not report the old level.
  assert.deepEqual(capAction(action({ level: 2, notified: r.store })), { notify: 0, store: r.store });
});

// --- isOutdated -------------------------------------------------------------

function at(year, month, dayOfMonth, hour, minute) {
  return { year, month, day: dayOfMonth, hour, minute };
}

test("isOutdated at exactly the limit is still fresh", () => {
  assert.equal(isOutdated("2026-10-24T17:30", at(2026, 10, 24, 18, 30)), false);
  assert.equal(isOutdated("2026-10-24T17:29", at(2026, 10, 24, 18, 30)), true);
});

test("isOutdated across midnight", () => {
  assert.equal(isOutdated("2026-10-24T23:50", at(2026, 10, 25, 0, 40)), false);
  assert.equal(isOutdated("2026-10-24T23:30", at(2026, 10, 25, 0, 40)), true);
});

test("isOutdated across a month and year boundary", () => {
  assert.equal(isOutdated("2026-10-31T23:45", at(2026, 11, 1, 0, 15)), false);
  assert.equal(isOutdated("2026-12-31T23:45", at(2027, 1, 1, 0, 45)), false);
  assert.equal(isOutdated("2026-12-31T23:44", at(2027, 1, 1, 0, 45)), true);
  assert.equal(isOutdated("2028-02-29T23:30", at(2028, 3, 1, 0, 10)), false);
});

test("isOutdated honors a custom limit", () => {
  assert.equal(isOutdated("2026-10-24T18:00", at(2026, 10, 24, 18, 30), 15), true);
  assert.equal(isOutdated("2026-10-24T18:20", at(2026, 10, 24, 18, 30), 15), false);
  assert.equal(isOutdated("2026-10-24T17:00", at(2026, 10, 24, 18, 30), -1), true);
  assert.equal(isOutdated("2026-10-24T17:40", at(2026, 10, 24, 18, 30), "x"), false);
});

test("isOutdated treats a future timestamp as fresh", () => {
  assert.equal(isOutdated("2026-10-25T09:00", at(2026, 10, 24, 18, 30)), false);
});

test("isOutdated treats an empty or invalid timestamp as outdated", () => {
  const now = at(2026, 10, 24, 18, 30);
  for (const value of [
    "",
    "garbage",
    "2026-10-24 18:30",
    "2026-02-30T10:00",
    "2026-10-24T24:00",
    "2026-10-24T18:60",
    null,
  ]) {
    assert.equal(isOutdated(value, now), true, String(value));
  }
});

test("isOutdated with an invalid now is outdated", () => {
  assert.equal(isOutdated("2026-10-24T18:30", null), true);
  assert.equal(isOutdated("2026-10-24T18:30", at(2026, 10, 24, 25, 0)), true);
  assert.equal(isOutdated("2026-10-24T18:30", at(2026, 2, 30, 1, 0)), true);
});
