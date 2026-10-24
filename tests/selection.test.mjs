// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import { test } from "node:test";
import assert from "node:assert/strict";
import { summarize, interfaceList, compareNames } from "../package/contents/code/selection.mjs";

const iface = (o) => ({
  down: 0,
  up: 0,
  totalDown: 0,
  totalUp: 0,
  kind: "physical",
  online: true,
  label: "",
  ipv4: "",
  ipv6: "",
  signal: null,
  ...o,
});
const ifs = {
  lo: iface({ kind: "virtual", down: 999, up: 999 }),
  enp7s0: iface({ down: 100, up: 10 }),
  wlp3s0: iface({ down: 1, up: 1, online: false }),
  docker0: iface({ kind: "virtual", down: 50, up: 50, online: false }),
  WorkVPN: iface({ kind: "virtual", down: 80, up: 8 }),
};

test("auto sums physical only, never lo, no VPN double count", () => {
  assert.deepEqual(summarize(ifs, "auto", []), {
    down: 101,
    up: 11,
    online: true,
    included: ["enp7s0", "wlp3s0"],
    primary: "enp7s0",
  });
});
test("manual uses the selection, virtual allowed, lo still ignored", () => {
  const r = summarize(ifs, "manual", ["WorkVPN", "lo"]);
  assert.deepEqual(r.included, ["WorkVPN"]);
  assert.equal(r.down, 80);
});
test("manual selection of vanished interfaces yields empty, offline result", () => {
  assert.deepEqual(summarize(ifs, "manual", ["eth9"]), { down: 0, up: 0, online: false, included: [], primary: null });
});
test("primary falls back to first online, then first included", () => {
  const idle = { b: iface({}), a: iface({ online: false }) };
  assert.equal(summarize(idle, "auto", []).primary, "b");
  const offline = { b: iface({ online: false }), a: iface({ online: false }) };
  assert.equal(summarize(offline, "auto", []).primary, "a");
});
test("unknown mode behaves like auto", () => {
  assert.deepEqual(summarize(ifs, "bogus", ["WorkVPN"]).included, ["enp7s0", "wlp3s0"]);
});
test("interfaceList orders included first and drops lo", () => {
  const list = interfaceList(ifs, ["enp7s0", "wlp3s0"]);
  assert.deepEqual(
    list.map((i) => [i.name, i.included]),
    [
      ["enp7s0", true],
      ["wlp3s0", true],
      ["docker0", false],
      ["WorkVPN", false],
    ],
  );
  assert.equal(list[0].down, 100);
});
test("compareNames is case-insensitive with deterministic tie-break", () => {
  assert.deepEqual(["WorkVPN", "docker0", "b", "A", "a"].sort(compareNames), ["A", "a", "b", "docker0", "WorkVPN"]);
});
test("non-finite rates count as zero in the sums", () => {
  const r = summarize({ a: iface({ down: NaN, up: undefined }), b: iface({ down: 2, up: 3 }) }, "auto", []);
  assert.deepEqual([r.down, r.up, r.primary], [2, 3, "b"]);
});
test("manual accepts an array-like selection and treats junk as empty", () => {
  const arrayLike = { length: 1, 0: "enp7s0" };
  assert.deepEqual(summarize(ifs, "manual", arrayLike).included, ["enp7s0"]);
  assert.deepEqual(summarize(ifs, "manual", "enp7s0").included, []);
  assert.deepEqual(summarize(ifs, "manual", undefined).included, []);
});
test("summarize and interfaceList cope with an empty interface map", () => {
  assert.deepEqual(summarize({}, "auto", []), { down: 0, up: 0, online: false, included: [], primary: null });
  assert.deepEqual(interfaceList({}, []), []);
});
test("interfaceList keeps every sample field and adds name and included", () => {
  const [row] = interfaceList({ eth0: iface({ label: "Home", ipv4: "10.0.0.2" }) }, ["eth0"]);
  assert.deepEqual(row, {
    name: "eth0",
    included: true,
    down: 0,
    up: 0,
    totalDown: 0,
    totalUp: 0,
    kind: "physical",
    online: true,
    label: "Home",
    ipv4: "10.0.0.2",
    ipv6: "",
    signal: null,
  });
});
