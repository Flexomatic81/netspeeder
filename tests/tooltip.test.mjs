// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import { test } from "node:test";
import assert from "node:assert/strict";
import { escapeHtml, tooltipLines } from "../package/contents/code/tooltip.mjs";

// Identity translators with %n replacement, like the English fallback.
const fill = (text, args) => text.replace(/%([1-9])/g, (_, d) => String(args[Number(d) - 1]));
const t = {
  tr: (text, ...args) => fill(text, args),
  trc: (_context, text, ...args) => fill(text, args),
};
const speedText = (bytes) => `${bytes} B/s`;

const live = {
  hasData: true,
  stale: false,
  includedCount: 2,
  interfaceSelection: "auto",
  online: true,
  down: 1500,
  up: 20,
  primaryIp: "192.168.1.5",
  errorCode: "",
  errorDetail: "",
  fallbackNote: "",
};
const lines = (overrides) => tooltipLines({ ...live, ...overrides }, t, speedText);

test("without data the tooltip waits", () => {
  assert.deepEqual(lines({ hasData: false }), ["Waiting for network data…"]);
});

test("stale data is reported as such", () => {
  assert.deepEqual(lines({ stale: true }), ["No current data"]);
});

test("a manual selection without a usable interface says so", () => {
  assert.deepEqual(lines({ includedCount: 0, interfaceSelection: "manual" }), [
    "No selected network interface available",
  ]);
});

test("no interface in automatic mode means offline", () => {
  assert.deepEqual(lines({ includedCount: 0 }), ["Offline"]);
});

test("being offline with interfaces present means offline", () => {
  assert.deepEqual(lines({ online: false }), ["Offline"]);
});

test("live data shows both speeds and the IP address", () => {
  assert.deepEqual(lines({}), ["Download: 1500 B/s", "Upload: 20 B/s", "IP address: 192.168.1.5"]);
});

test("without an IP address the line is left out", () => {
  assert.deepEqual(lines({ primaryIp: "" }), ["Download: 1500 B/s", "Upload: 20 B/s"]);
});

test("the IP address is escaped", () => {
  assert.equal(lines({ primaryIp: "<x>&" })[2], "IP address: &lt;x&gt;&amp;");
});

test("the contexts are passed on to trc", () => {
  const seen = [];
  tooltipLines(live, { tr: t.tr, trc: (context, text, ...args) => (seen.push(context), fill(text, args)) }, speedText);
  assert.deepEqual(seen, ["@info:tooltip", "@info:tooltip", "@info:tooltip"]);
});

test("unavailable sensors: choose another source", () => {
  assert.deepEqual(lines({ errorCode: "sensors-unavailable" }).slice(3), [
    "System sensors are not available. Choose another data source in the settings.",
  ]);
});

test("unavailable sensors with a fallback note", () => {
  assert.deepEqual(lines({ errorCode: "sensors-unavailable", fallbackNote: "x" }).slice(3), [
    "Using kernel counters because system sensors are not available.",
  ]);
});

test("sensors without interfaces", () => {
  assert.deepEqual(lines({ errorCode: "no-interfaces" }).slice(3), ["System sensors report no network interfaces."]);
});

test("sensors without interfaces with a fallback note", () => {
  assert.deepEqual(lines({ errorCode: "no-interfaces", fallbackNote: "x" }).slice(3), [
    "Using kernel counters because system sensors report no network interfaces.",
  ]);
});

test("a failing source shows its detail", () => {
  assert.deepEqual(lines({ errorCode: "source-failed", errorDetail: "boom" }).slice(3), [
    "Reading network data failed: boom",
  ]);
});

test("the detail is escaped after it is cut", () => {
  assert.equal(escapeHtml("<b>&"), "&lt;b&gt;&amp;");
  assert.deepEqual(lines({ errorCode: "source-failed", errorDetail: "<b>&" }).slice(3), [
    "Reading network data failed: &lt;b&gt;&amp;",
  ]);
  const cut = lines({ errorCode: "source-failed", errorDetail: "a".repeat(119) + "<" + "b".repeat(10) }).at(-1);
  assert.equal(cut, `Reading network data failed: ${"a".repeat(119)}&lt;`);
});

test("the detail is cut to 120 characters", () => {
  const detail = lines({ errorCode: "source-failed", errorDetail: "x".repeat(130) }).at(-1);
  assert.equal(detail, `Reading network data failed: ${"x".repeat(120)}`);
});

test("line breaks in the detail become one space", () => {
  assert.equal(
    lines({ errorCode: "source-failed", errorDetail: "a\r\n\nb\nc" }).at(-1),
    "Reading network data failed: a b c",
  );
});

test("an unknown error code adds no hint", () => {
  assert.deepEqual(lines({ errorCode: "other" }), lines({}));
});
