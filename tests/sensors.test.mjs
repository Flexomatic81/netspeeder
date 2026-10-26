// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import { test } from "node:test";
import assert from "node:assert/strict";
import {
  SENSOR_FIELDS,
  HEARTBEAT_SENSOR,
  heartbeatWindowMs,
  isHeartbeatFresh,
  initialHeartbeatGate,
  heartbeatGate,
  heartbeatAllows,
  interfaceFromSensorId,
  interfacesFromSensorIds,
  buildSensorSample,
} from "../package/contents/code/sensors.mjs";

test("constants", () => {
  assert.deepEqual(SENSOR_FIELDS, [
    "download",
    "upload",
    "totalDownload",
    "totalUpload",
    "network",
    "ipv4address",
    "ipv6address",
    "signal",
  ]);
  assert.equal(HEARTBEAT_SENSOR, "os/system/uptime");
});
test("interfaceFromSensorId", () => {
  assert.equal(interfaceFromSensorId("network/enp7s0/download"), "enp7s0");
  assert.equal(interfaceFromSensorId("network/wlan0.100/upload"), "wlan0.100");
  assert.equal(interfaceFromSensorId("network/all/download"), null);
  assert.equal(interfaceFromSensorId("network/(?!all).*/download"), null);
  assert.equal(interfaceFromSensorId("network/enp7s0"), null);
  assert.equal(interfaceFromSensorId("cpu/all/usage"), null);
  assert.equal(interfaceFromSensorId(undefined), null);
});
test("interfacesFromSensorIds dedupes in first-seen order", () => {
  assert.deepEqual(
    interfacesFromSensorIds([
      "network/wlp3s0/download",
      "network/enp7s0/download",
      "network/enp7s0/upload",
      "network/all/download",
      "network/(?!all).*/download",
      "memory/physical/used",
    ]),
    ["wlp3s0", "enp7s0"],
  );
});
test("buildSensorSample coerces raw values", () => {
  const s = buildSensorSample(
    7,
    {
      enp7s0: {
        download: "1024",
        upload: undefined,
        totalDownload: 5000,
        totalUpload: NaN,
        network: "Wired 1",
        ipv4address: "192.168.1.121",
        ipv6address: undefined,
        signal: 0,
      },
      wlp3s0: {
        download: -3,
        upload: 10,
        totalDownload: 1,
        totalUpload: 2,
        network: undefined,
        ipv4address: "",
        ipv6address: "",
        signal: 73,
      },
    },
    ["enp7s0"],
  );
  assert.equal(s.source, "sensors");
  assert.equal(s.timestamp, 7);
  assert.deepEqual(s.interfaces.enp7s0, {
    down: 1024,
    up: 0,
    totalDown: 5000,
    totalUp: 0,
    totalsKnown: false,
    kind: "physical",
    online: true,
    label: "Wired 1",
    ipv4: "192.168.1.121",
    ipv6: "",
    signal: null,
  });
  assert.deepEqual(s.interfaces.wlp3s0, {
    down: 0,
    up: 10,
    totalDown: 1,
    totalUp: 2,
    totalsKnown: true,
    kind: "virtual",
    online: false,
    label: "",
    ipv4: "",
    ipv6: "",
    signal: 73,
  });
});
test("buildSensorSample without device info treats all as physical", () => {
  const s = buildSensorSample(1, { eth0: {} }, null);
  assert.equal(s.interfaces.eth0.kind, "physical");
  assert.equal(s.interfaces.eth0.down, 0);
});
test("buildSensorSample with no interfaces is a valid empty sample", () => {
  assert.deepEqual(buildSensorSample(3, {}, []), {
    timestamp: 3,
    source: "sensors",
    interfaces: {},
    systemVirtual: [],
  });
});
test("buildSensorSample carries the present interfaces without hardware", () => {
  const s = buildSensorSample(1, { enp7s0: {} }, ["enp7s0"], ["WorkVPN", "docker0"]);
  assert.deepEqual(s.systemVirtual, ["WorkVPN", "docker0"]);
  assert.equal(s.interfaces.enp7s0.kind, "physical");
  assert.equal(s.interfaces.WorkVPN, undefined);
});
test("buildSensorSample counts a name the system does not list as physical", () => {
  // A USB adapter appears as eth0 and is renamed a moment later; the sensors
  // keep the first name, which then exists neither with nor without hardware.
  const s = buildSensorSample(1, { eth0: {}, tun0: {} }, ["enx4467520e0481"], ["tun0"]);
  assert.equal(s.interfaces.eth0.kind, "physical");
  assert.equal(s.interfaces.tun0.kind, "virtual");
});
test("buildSensorSample copies a virtual list that arrives as a sequence object", () => {
  assert.deepEqual(buildSensorSample(1, {}, ["eth0"], { length: 1, 0: "WorkVPN" }).systemVirtual, ["WorkVPN"]);
});
test("buildSensorSample without a virtual list knows no system virtual interfaces", () => {
  assert.deepEqual(buildSensorSample(1, {}, ["eth0"]).systemVirtual, []);
  assert.deepEqual(buildSensorSample(1, {}, null, null).systemVirtual, []);
});
test("heartbeat window", () => {
  assert.equal(heartbeatWindowMs(500), 3000);
  assert.equal(heartbeatWindowMs(2000), 6000);
  assert.equal(isHeartbeatFresh(10000, 13000, 1000), true);
  assert.equal(isHeartbeatFresh(10000, 13001, 1000), false);
});
// Feeds heartbeat values to the gate: pairs of [now, value].
function beats(state, pairs) {
  let gate = state;
  for (const [now, value] of pairs) gate = heartbeatGate(gate, { type: "heartbeat", now: now, value: value });
  return gate;
}
test("heartbeat gate starts out requiring a heartbeat", () => {
  const gate = initialHeartbeatGate();
  assert.deepEqual(gate, { required: true, lastHeartbeatAt: 0, hasValue: false, lastValue: undefined });
  assert.equal(heartbeatAllows(gate, 1700000000000, 1000), false);
});
test("heartbeat gate does not arm on a single value, so the probe still switches it off", () => {
  const one = beats(initialHeartbeatGate(), [[2000, 0]]);
  assert.equal(one.lastHeartbeatAt, 0);
  const off = heartbeatGate(one, { type: "probe-expired", sensorReady: false });
  assert.equal(off.required, false);
  assert.equal(heartbeatAllows(off, 99999, 1000), true);
});
test("heartbeat gate does not arm on the same value repeated", () => {
  const same = beats(initialHeartbeatGate(), [
    [2000, 7],
    [3000, 7],
    [4000, 7],
  ]);
  assert.equal(same.lastHeartbeatAt, 0);
  assert.equal(heartbeatGate(same, { type: "heartbeat", now: 5000, value: 7 }), same);
  assert.equal(heartbeatGate(same, { type: "probe-expired", sensorReady: false }).required, false);
});
test("heartbeat gate treats a repeated NaN as the same value", () => {
  const nan = beats(initialHeartbeatGate(), [
    [2000, NaN],
    [3000, NaN],
  ]);
  assert.equal(nan.lastHeartbeatAt, 0);
});
test("heartbeat gate arms once the value changes, and records each change", () => {
  const gate = beats(initialHeartbeatGate(), [
    [4000, 10],
    [5000, 11],
  ]);
  assert.deepEqual(gate, { required: true, lastHeartbeatAt: 5000, hasValue: true, lastValue: 11 });
  assert.equal(heartbeatAllows(gate, 8000, 1000), true);
  assert.equal(heartbeatAllows(gate, 8001, 1000), false);
  // A repeat of the last value is no sign of life.
  assert.equal(beats(gate, [[6000, 11]]), gate);
});
test("heartbeat gate switches off when the probe finds no heartbeat sensor", () => {
  const gate = heartbeatGate(initialHeartbeatGate(), { type: "probe-expired", sensorReady: false });
  assert.equal(gate.required, false);
  assert.equal(gate.lastHeartbeatAt, 0);
  assert.equal(heartbeatAllows(gate, 99999, 1000), true);
});
test("heartbeat gate stays on when the probe finds the sensor", () => {
  const start = initialHeartbeatGate();
  assert.equal(heartbeatGate(start, { type: "probe-expired", sensorReady: true }), start);
});
test("heartbeat gate stays on after the probe once the heartbeat changed", () => {
  const seen = beats(initialHeartbeatGate(), [
    [1000, 1],
    [2000, 2],
  ]);
  assert.equal(heartbeatGate(seen, { type: "probe-expired", sensorReady: false }), seen);
  assert.equal(heartbeatAllows(seen, 20000, 1000), false);
});
test("heartbeat gate switches back on with a late heartbeat", () => {
  const off = heartbeatGate(initialHeartbeatGate(), { type: "probe-expired", sensorReady: false });
  const first = beats(off, [[29000, 100]]);
  assert.equal(first.required, false);
  const late = beats(first, [[30000, 101]]);
  assert.deepEqual(late, { required: true, lastHeartbeatAt: 30000, hasValue: true, lastValue: 101 });
  assert.equal(heartbeatAllows(late, 33000, 1000), true);
  // The heartbeat stops again: samples are held back after the window.
  assert.equal(heartbeatAllows(late, 33001, 1000), false);
  // It comes back: samples pass again.
  const back = beats(late, [[40000, 111]]);
  assert.equal(heartbeatAllows(back, 40500, 1000), true);
});
test("heartbeat gate ignores unknown events", () => {
  const start = initialHeartbeatGate();
  assert.equal(heartbeatGate(start, { type: "other" }), start);
});
test("buildSensorSample keeps NaN and undefined out of every field", () => {
  const s = buildSensorSample(
    2,
    {
      a: {
        download: NaN,
        upload: Infinity,
        totalDownload: null,
        totalUpload: "abc",
        network: NaN,
        ipv4address: null,
        ipv6address: 5,
        signal: NaN,
      },
      b: undefined,
    },
    null,
  );
  for (const name of ["a", "b"]) {
    assert.deepEqual(s.interfaces[name], {
      down: 0,
      up: 0,
      totalDown: 0,
      totalUp: 0,
      totalsKnown: false,
      kind: "physical",
      online: false,
      label: "",
      ipv4: "",
      ipv6: "",
      signal: null,
    });
  }
});
test("buildSensorSample marks an interface online by either address", () => {
  const s = buildSensorSample(
    2,
    {
      v4: { ipv4address: "10.0.0.2" },
      v6: { ipv6address: "fe80::1" },
      none: {},
    },
    [],
  );
  assert.equal(s.interfaces.v4.online, true);
  assert.equal(s.interfaces.v6.online, true);
  assert.equal(s.interfaces.none.online, false);
});
test("interfaceFromSensorId rejects aggregate and regex group names only", () => {
  assert.equal(interfaceFromSensorId("network/br-1a2b3c4d5e6f/totalDownload"), "br-1a2b3c4d5e6f");
  assert.equal(interfaceFromSensorId("network/all/"), null);
  assert.equal(interfaceFromSensorId("network//download"), null);
  assert.equal(interfaceFromSensorId("network/a|b/download"), null);
  assert.equal(interfaceFromSensorId("network/en[p]/download"), null);
  assert.equal(interfaceFromSensorId("network/enp7s0/download/extra"), null);
});
test("buildSensorSample tells a counter at 0 from no reading", () => {
  const s = buildSensorSample(
    1,
    {
      zero: { totalDownload: 0, totalUpload: 0 },
      missing: { totalDownload: undefined, totalUpload: 5 },
      nan: { totalDownload: 5, totalUpload: NaN },
    },
    null,
  );
  assert.equal(s.interfaces.zero.totalsKnown, true);
  assert.equal(s.interfaces.missing.totalsKnown, false);
  assert.equal(s.interfaces.nan.totalsKnown, false);
});
