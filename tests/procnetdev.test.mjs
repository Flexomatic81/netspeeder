// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import {
  parseProcNetDev,
  parseOperstate,
  parseDeviceList,
  parseDeviceKinds,
  parseProcOutput,
  DEVICES_COMMAND,
  toProcSample,
} from "../package/contents/code/procnetdev.mjs";

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
test("parseDeviceKinds splits hardware-backed from other present interfaces", () => {
  assert.deepEqual(parseDeviceKinds("enp7s0\n wlan0 \n#virtual\nWorkVPN\n\ndocker0\n"), {
    physical: ["enp7s0", "wlan0"],
    virtual: ["WorkVPN", "docker0"],
  });
});
test("parseDeviceKinds without the virtual section knows no virtual interfaces", () => {
  assert.deepEqual(parseDeviceKinds("enp7s0\n"), { physical: ["enp7s0"], virtual: [] });
  assert.deepEqual(parseDeviceKinds(""), { physical: [], virtual: [] });
});
test("DEVICES_COMMAND lists the loopback device as present without hardware", () => {
  const kinds = parseDeviceKinds(execFileSync("sh", ["-c", DEVICES_COMMAND], { encoding: "utf8" }));
  assert.ok(kinds.virtual.includes("lo"));
  assert.equal(kinds.physical.filter((name) => kinds.virtual.includes(name)).length, 0);
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
  assert.deepEqual(s.interfaces.enp7s0, {
    down: 10,
    up: 20,
    totalDown: 1315645898,
    totalUp: 51368610,
    totalsKnown: true,
    kind: "physical",
    online: true,
    label: "",
    ipv4: "",
    ipv6: "",
    signal: null,
  });
  assert.equal(s.interfaces.docker0.kind, "virtual");
  assert.equal(s.interfaces.docker0.online, false);
  assert.equal(s.interfaces.WorkVPN.online, true); // unknown + counters > 0
  assert.equal(s.interfaces["br-1a2b3c4d5e6f"].online, false); // down
  assert.equal(s.interfaces.eth1.down, 0); // missing rate → 0
});

const HEADER = "Inter-|   Receive    |  Transmit\n face |bytes packets|bytes packets\n";
const counterLine = (name, rx, tx) => `${name}: ${rx} 1 0 0 0 0 0 0 ${tx} 1 0 0 0 0 0 0`;

test("parseProcNetDev skips short lines and non-numeric counters", () => {
  const text = [
    HEADER.trim(),
    "short: 1 2 3",
    `bad: abc 1 0 0 0 0 0 0 5 1 0 0 0 0 0 0`,
    `bad2: 7 1 0 0 0 0 0 0 xyz 1 0 0 0 0 0 0`,
    counterLine("eth0", 100, 200),
  ].join("\n");
  assert.deepEqual(parseProcNetDev(text), { eth0: { rx: 100, tx: 200 } });
});
test("a header without interface lines parses to an empty result", () => {
  assert.deepEqual(parseProcNetDev(HEADER), {});
  const parsed = parseProcOutput(`${HEADER}#operstate\n#devices\n`);
  assert.deepEqual(parsed, { counters: {}, operstate: {}, physical: [] });
});
test("CRLF input parses like LF input", () => {
  const lf = `${HEADER}${counterLine("eth0", 100, 200)}\n#operstate\n/sys/class/net/eth0/operstate:up\n#devices\neth0\n`;
  const crlf = lf.replace(/\n/g, "\r\n");
  assert.deepEqual(parseProcOutput(crlf), parseProcOutput(lf));
  assert.deepEqual(parseProcOutput(crlf), {
    counters: { eth0: { rx: 100, tx: 200 } },
    operstate: { eth0: "up" },
    physical: ["eth0"],
  });
});
test("toProcSample: missing operstate counts as offline, even with traffic", () => {
  const parsed = { counters: { tun0: { rx: 10, tx: 10 } }, operstate: {}, physical: [] };
  assert.equal(toProcSample(1, parsed, {}).interfaces.tun0.online, false);
});
test("toProcSample: unknown state is online only with traffic", () => {
  const parsed = {
    counters: { idle0: { rx: 0, tx: 0 }, busy0: { rx: 0, tx: 1 } },
    operstate: { idle0: "unknown", busy0: "unknown" },
    physical: [],
  };
  const { interfaces } = toProcSample(1, parsed, {});
  assert.equal(interfaces.idle0.online, false);
  assert.equal(interfaces.busy0.online, true);
});
test("toProcSample: rates = null gives every interface 0", () => {
  const parsed = { counters: { eth0: { rx: 5, tx: 6 } }, operstate: { eth0: "up" }, physical: ["eth0"] };
  const { interfaces } = toProcSample(1, parsed, null);
  assert.deepEqual([interfaces.eth0.down, interfaces.eth0.up], [0, 0]);
  assert.deepEqual([interfaces.eth0.totalDown, interfaces.eth0.totalUp], [5, 6]);
});
