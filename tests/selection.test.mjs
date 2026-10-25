// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import { test } from "node:test";
import assert from "node:assert/strict";
import { summarize, interfaceList, compareNames, listOrder, toList } from "../package/contents/code/selection.mjs";

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
test("compareNames breaks case-insensitive ties by spelling, in both directions", () => {
  assert.equal(compareNames("A", "a"), -1);
  assert.equal(compareNames("a", "A"), 1);
  assert.equal(compareNames("eth0", "eth0"), 0);
  assert.equal(compareNames("a", "B"), -1);
  assert.equal(compareNames("B", "a"), 1);
});
test("objects without a numeric length count as an empty selection", () => {
  assert.deepEqual(summarize(ifs, "manual", { enp7s0: true }).included, []);
  assert.deepEqual(summarize(ifs, "manual", { length: "1", 0: "enp7s0" }).included, []);
  assert.deepEqual(summarize(ifs, "manual", null).included, []);
  assert.deepEqual(
    interfaceList({ eth0: iface({}) }, { eth0: true }).map((r) => r.included),
    [false],
  );
});
test("null and undefined interface maps behave like an empty map", () => {
  const empty = { down: 0, up: 0, online: false, included: [], primary: null };
  assert.deepEqual(summarize(null, "auto", []), empty);
  assert.deepEqual(summarize(undefined, "manual", ["eth0"]), empty);
  assert.deepEqual(interfaceList(null, []), []);
  assert.deepEqual(interfaceList(undefined, ["eth0"]), []);
});

test("toList copies array-like values and turns everything else into an empty list", () => {
  assert.deepEqual(toList(["a", 1]), ["a", 1]);
  assert.deepEqual(toList({ length: 1, 0: 7 }), [7], "elements are copied without conversion");
  assert.deepEqual(toList({ length: 0 }), []);
  assert.deepEqual(toList("abc"), []);
  assert.deepEqual(toList(null), []);
  assert.deepEqual(toList(undefined), []);
  assert.deepEqual(toList({}), []);
  assert.deepEqual(toList(42), []);
  assert.deepEqual(toList({ length: 1, 0: 7 }).map(String), ["7"]);
});

test("listOrder puts the counted interfaces first, each group by name", () => {
  const rows = [
    { name: "docker0", included: false },
    { name: "wlan0", included: true },
    { name: "Tun0", included: false },
    { name: "eth0", included: true },
  ];
  assert.deepEqual(listOrder(rows), ["eth0", "wlan0", "docker0", "Tun0"]);
  assert.deepEqual(rows[0].name, "docker0", "the input stays as it is");
  // Only true counts as counted.
  assert.deepEqual(listOrder([{ name: "b" }, { name: "a", included: "yes" }, { name: "c", included: true }]), [
    "c",
    "a",
    "b",
  ]);
  assert.deepEqual(listOrder([]), []);
  assert.deepEqual(listOrder(null), []);
});

test("listOrder gives the order of interfaceList", () => {
  const list = interfaceList(ifs, ["enp7s0", "wlp3s0"]);
  assert.deepEqual(
    listOrder(list.slice().reverse()),
    list.map((row) => row.name),
  );
});
