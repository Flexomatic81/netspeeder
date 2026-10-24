// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { VNSTAT_COMMAND, parseVnstat, dateKey } from "../package/contents/code/vnstat.mjs";

const v2 = readFileSync(new URL("./fixtures/vnstat-v2.json", import.meta.url), "utf8");
const v1 = readFileSync(new URL("./fixtures/vnstat-v1.json", import.meta.url), "utf8");

function withDays(days, name = "eth0") {
  return JSON.stringify({ jsonversion: "2", interfaces: [{ name, traffic: { day: days } }] });
}

test("command asks for 62 days of JSON", () => {
  assert.equal(VNSTAT_COMMAND, "vnstat --json d 62");
});
test("parses the v2 fixture", () => {
  const r = parseVnstat(v2);
  assert.equal(r.status, "ok");
  assert.equal(r.version, "2");
  assert.deepEqual(Object.keys(r.interfaces).sort(), ["eth0", "wlan0"]);
  const eth = r.interfaces.eth0;
  assert.equal(eth.created, "2026-08-01");
  assert.equal(eth.updated, "2026-10-24T18:30");
  assert.equal(eth.days[0].date, "2026-08-20");
  assert.equal(eth.days.at(-1).date, "2026-10-24");
  assert.deepEqual(eth.days[0], { date: "2026-08-20", rx: 1200000000, tx: 150000000 });
  assert.equal(r.interfaces.wlan0.created, "2026-10-10");
  assert.equal(r.interfaces.wlan0.days.length, 3);
});
test("days without traffic have no entry", () => {
  const dates = parseVnstat(v2).interfaces.eth0.days.map((d) => d.date);
  assert.ok(!dates.includes("2026-08-22"));
  assert.deepEqual(dates, [...dates].sort());
});
test("sorts days ascending", () => {
  const day = (d) => ({ date: { year: 2026, month: 10, day: d }, rx: 1, tx: 2 });
  const r = parseVnstat(withDays([day(5), day(3), day(4)]));
  assert.deepEqual(
    r.interfaces.eth0.days.map((d) => d.date),
    ["2026-10-03", "2026-10-04", "2026-10-05"],
  );
});
test("v1 is unsupported and reports its version", () => {
  const r = parseVnstat(v1);
  assert.equal(r.status, "unsupported");
  assert.equal(r.version, "1");
});
test("garbage is invalid", () => {
  for (const s of ["", "not json", "[]", "{}", "null", '{"jsonversion":"2"}', '{"jsonversion":"2","interfaces":{}}']) {
    assert.equal(parseVnstat(s).status, "invalid", s);
  }
  assert.equal(parseVnstat(undefined).status, "invalid");
});
test("drops a day with a missing date part", () => {
  const r = parseVnstat(
    withDays([
      { date: { year: 2026, month: 10 }, rx: 1, tx: 1 },
      { date: { year: 2026, month: 10, day: 2 }, rx: 1, tx: 1 },
      { rx: 1, tx: 1 },
    ]),
  );
  assert.deepEqual(
    r.interfaces.eth0.days.map((d) => d.date),
    ["2026-10-02"],
  );
});
test("clamps negative or non-finite counters to 0", () => {
  const d = { year: 2026, month: 10, day: 2 };
  const r = parseVnstat(withDays([{ date: d, rx: -5, tx: "x" }]));
  assert.deepEqual(r.interfaces.eth0.days[0], { date: "2026-10-02", rx: 0, tx: 0 });
});
test("drops interfaces without a name", () => {
  const s = JSON.stringify({
    jsonversion: "2",
    interfaces: [{ traffic: { day: [] } }, { name: "", traffic: {} }, { name: "tun0" }],
  });
  const r = parseVnstat(s);
  assert.deepEqual(Object.keys(r.interfaces), ["tun0"]);
  assert.deepEqual(r.interfaces.tun0, { created: "", updated: "", days: [] });
});
test("dateKey pads and rejects invalid values", () => {
  assert.equal(dateKey({ year: 2026, month: 3, day: 7 }), "2026-03-07");
  assert.equal(dateKey({ year: 2026, month: 12, day: 31 }), "2026-12-31");
  for (const bad of [
    null,
    {},
    { year: 2026, month: 0, day: 1 },
    { year: 2026, month: 13, day: 1 },
    { year: 2026, month: 1, day: 32 },
    { year: "a", month: 1, day: 1 },
    { year: 2026, month: 1.5, day: 1 },
  ]) {
    assert.equal(dateKey(bad), "");
  }
});
