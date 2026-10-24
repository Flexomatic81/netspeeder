// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import { test } from "node:test";
import assert from "node:assert/strict";
import {
  SENSOR_FIELDS,
  HEARTBEAT_SENSOR,
  heartbeatWindowMs,
  isHeartbeatFresh,
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
  assert.deepEqual(buildSensorSample(3, {}, []), { timestamp: 3, source: "sensors", interfaces: {} });
});
test("heartbeat window", () => {
  assert.equal(heartbeatWindowMs(500), 3000);
  assert.equal(heartbeatWindowMs(2000), 6000);
  assert.equal(isHeartbeatFresh(10000, 13000, 1000), true);
  assert.equal(isHeartbeatFresh(10000, 13001, 1000), false);
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
