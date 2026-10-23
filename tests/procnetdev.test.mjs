// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { parseProcNetDev, parseOperstate, parseDeviceList, parseProcOutput, toProcSample } from "../package/contents/code/procnetdev.mjs";

const full = readFileSync(new URL("./fixtures/proc-output.txt", import.meta.url), "utf8");
const procPart = full.split("#operstate")[0];

test("parses counters incl. unusual names and missing space after colon", () => {
  const c = parseProcNetDev(procPart);
  assert.deepEqual(c.enp7s0, { rx: 1315645898, tx: 51368610 });
  assert.deepEqual(c.eth1, { rx: 123456789, tx: 98765432 });
  assert.deepEqual(c["wlan0.100"], { rx: 1000, tx: 2000 });
  assert.deepEqual(c["br-1a2b3c4d5e6f"], { rx: 0, tx: 0 });
  assert.equal(Object.keys(c).length, 7);
});
test("parses operstate", () => {
  const s = parseOperstate(full.split("#operstate")[1].split("#devices")[0]);
  assert.equal(s.enp7s0, "up");
  assert.equal(s.WorkVPN, "unknown");
  assert.equal(s.docker0, "down");
});
test("parses device list", () => {
  assert.deepEqual(parseDeviceList("enp7s0\n\n  wlan0 \n"), ["enp7s0", "wlan0"]);
});
test("parseProcOutput splits sections", () => {
  const p = parseProcOutput(full);
  assert.deepEqual(p.physical, ["enp7s0", "eth1"]);
  assert.equal(p.operstate.lo, "unknown");
  assert.equal(p.counters.docker0.tx, 7000000);
});
test("parseProcOutput rejects garbage", () => {
  assert.equal(parseProcOutput(""), null);
  assert.equal(parseProcOutput("cat: /proc/net/dev: No such file"), null);
});
test("toProcSample classifies and maps fields", () => {
  const p = parseProcOutput(full);
  const s = toProcSample(42, p, { enp7s0: { down: 10, up: 20 } });
  assert.equal(s.source, "proc");
  assert.equal(s.timestamp, 42);
  assert.deepEqual(s.interfaces.enp7s0, { down: 10, up: 20, totalDown: 1315645898, totalUp: 51368610,
    kind: "physical", online: true, label: "", ipv4: "", ipv6: "", signal: null });
  assert.equal(s.interfaces.docker0.kind, "virtual");
  assert.equal(s.interfaces.docker0.online, false);
  assert.equal(s.interfaces.WorkVPN.online, true);           // unknown + counters > 0
  assert.equal(s.interfaces["br-1a2b3c4d5e6f"].online, false); // down
  assert.equal(s.interfaces.eth1.down, 0);                     // missing rate → 0
});
