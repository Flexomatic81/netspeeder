// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import { test } from "node:test";
import assert from "node:assert/strict";
import {
  COLOR_MODES,
  DEFAULT_THRESHOLDS,
  ICON_STYLES,
  SPARKLINE_MODES,
  parseThresholds,
  serializeThresholds,
  speedColors,
  symbols,
  thresholdColor,
  validChoice,
  validInt,
} from "../package/contents/code/appearance.mjs";

const MIB = 1048576;
const parse = (value) => parseThresholds(JSON.stringify(value));
const defaults = () => DEFAULT_THRESHOLDS.map((s) => ({ ...s }));

test("the defaults are frozen", () => {
  assert.ok(Object.isFrozen(DEFAULT_THRESHOLDS));
  assert.ok(DEFAULT_THRESHOLDS.every((s) => Object.isFrozen(s)));
  assert.equal(DEFAULT_THRESHOLDS.length, 4);
});

test("unusable text gives a copy of the defaults", () => {
  for (const text of ["", "{}", "[]", "kaputt", "null", "[1,2]", '[{"min":-1}]']) {
    const list = parseThresholds(text);
    assert.deepEqual(list, defaults(), text);
    assert.notEqual(list, DEFAULT_THRESHOLDS);
  }
  assert.deepEqual(parseThresholds(undefined), defaults());
  const copy = parseThresholds("");
  copy[0].color = "#000000";
  assert.equal(DEFAULT_THRESHOLDS[0].color, "");
});

test("steps are sorted ascending", () => {
  const list = parse([
    { min: 500, color: "#00ff00" },
    { min: 0, color: "" },
    { min: 100, color: "#ff0000" },
  ]);
  assert.deepEqual(
    list.map((s) => s.min),
    [0, 100, 500],
  );
});

test("invalid minimums are dropped, the limits are valid", () => {
  const list = parse([
    { min: -1, color: "#111111" },
    { min: NaN, color: "#111111" },
    { min: "5", color: "#111111" },
    { min: 1.5, color: "#111111" },
    { min: 2147483648, color: "#111111" },
    { min: 2147483647, color: "#222222" },
    { color: "#111111" },
    null,
    "x",
  ]);
  assert.deepEqual(list, [
    { min: 0, color: "" },
    { min: 2147483647, color: "#222222" },
  ]);
});

test("colours are checked and lower-cased", () => {
  const list = parse([
    { min: 0, color: "red" },
    { min: 1, color: "#12345" },
    { min: 2, color: "#ABCDEF" },
    { min: 3, color: 5 },
    { min: 4 },
    { min: 5, color: "" },
  ]);
  assert.deepEqual(list, [
    { min: 0, color: "" },
    { min: 2, color: "#abcdef" },
    { min: 5, color: "" },
  ]);
});

test("at most six steps remain, the first six after sorting", () => {
  const eight = [];
  for (let i = 8; i >= 1; i--) eight.push({ min: i * 10, color: "#aaaaaa" });
  const list = parse(eight);
  assert.equal(list.length, 6);
  assert.deepEqual(
    list.map((s) => s.min),
    [0, 10, 20, 30, 40, 50],
  );
});

test("a missing zero step is added and counts towards six", () => {
  assert.deepEqual(parse([{ min: 5, color: "#aaaaaa" }]), [
    { min: 0, color: "" },
    { min: 5, color: "#aaaaaa" },
  ]);
  const seven = [];
  for (let i = 1; i <= 7; i++) seven.push({ min: i, color: "#aaaaaa" });
  const list = parse(seven);
  assert.equal(list.length, 6);
  assert.deepEqual(list[0], { min: 0, color: "" });
  assert.equal(list[5].min, 5);
});

test("a repeated minimum keeps the last one", () => {
  const list = parse([
    { min: 0, color: "" },
    { min: 7, color: "#111111" },
    { min: 7, color: "#222222" },
  ]);
  assert.deepEqual(list, [
    { min: 0, color: "" },
    { min: 7, color: "#222222" },
  ]);
});

test("serializing round-trips", () => {
  const text = serializeThresholds(DEFAULT_THRESHOLDS);
  assert.ok(!text.includes(" "));
  assert.deepEqual(parseThresholds(text), defaults());
  const messy = [
    { min: 9, color: "#ABCDEF" },
    { min: 9, color: "nope" },
    { min: 2, color: "#010203" },
  ];
  const once = serializeThresholds(messy);
  assert.equal(serializeThresholds(parseThresholds(once)), once);
  assert.equal(serializeThresholds("garbage"), serializeThresholds(DEFAULT_THRESHOLDS));
});

test("thresholdColor picks the highest step reached", () => {
  const list = DEFAULT_THRESHOLDS;
  assert.equal(thresholdColor(MIB, list), "#1d99f3");
  assert.equal(thresholdColor(MIB - 1, list), "");
  assert.equal(thresholdColor(10 * MIB, list), "#f67400");
  assert.equal(thresholdColor(1e12, list), "#da4453");
  assert.equal(thresholdColor(NaN, list), "");
  assert.equal(thresholdColor(-5, list), "");
  assert.equal(thresholdColor("12", list), "");
  assert.equal(thresholdColor(5, []), "");
});

const cfg = { downloadColor: "#00ff00", uploadColor: "#0000ff", thresholds: DEFAULT_THRESHOLDS };
const rates = { down: 2 * MIB, up: 20 * MIB, total: 200 * MIB };

test("theme mode and unknown modes give theme colours", () => {
  const none = { down: "", up: "", total: "" };
  assert.deepEqual(speedColors("theme", rates, cfg), none);
  assert.deepEqual(speedColors("rainbow", rates, cfg), none);
  assert.deepEqual(speedColors(undefined, rates, cfg), none);
});

test("direction mode colours the sum like the download", () => {
  assert.deepEqual(speedColors("direction", rates, cfg), {
    down: "#00ff00",
    up: "#0000ff",
    total: "#00ff00",
  });
});

test("threshold mode colours each value by its own rate", () => {
  assert.deepEqual(speedColors("thresholds", rates, cfg), {
    down: "#1d99f3",
    up: "#f67400",
    total: "#da4453",
  });
});

test("invalid colours count as theme", () => {
  const bad = { downloadColor: "green", uploadColor: undefined, thresholds: DEFAULT_THRESHOLDS };
  assert.deepEqual(speedColors("direction", rates, bad), { down: "", up: "", total: "" });
  const badStep = { thresholds: [{ min: 0, color: "red" }] };
  assert.equal(speedColors("thresholds", rates, badStep).down, "");
});

test("symbols for every style", () => {
  const custom = { down: "", up: "" };
  assert.deepEqual(symbols("arrows", custom), { down: "↓", up: "↑", icons: false });
  assert.deepEqual(symbols("triangles", custom), { down: "▼", up: "▲", icons: false });
  assert.deepEqual(symbols("icons", custom), { down: "go-down", up: "go-up", icons: true });
  assert.deepEqual(symbols("none", custom), { down: "", up: "", icons: false });
  assert.deepEqual(symbols("bogus", custom), { down: "↓", up: "↑", icons: false });
});

test("custom symbols are cut to three characters, empty falls back to arrows", () => {
  assert.deepEqual(symbols("custom", { down: "abcde", up: "x" }), { down: "abc", up: "x", icons: false });
  assert.deepEqual(symbols("custom", { down: "", up: "" }), { down: "↓", up: "↑", icons: false });
  assert.deepEqual(symbols("custom", undefined), { down: "↓", up: "↑", icons: false });
  assert.deepEqual(symbols("custom", { down: 5, up: null }), { down: "↓", up: "↑", icons: false });
});

test("validInt accepts integers in range and falls back to the default", () => {
  assert.equal(validInt(100, 50, 200, 100), 100);
  assert.equal(validInt(50, 50, 200, 80), 50);
  assert.equal(validInt(200, 50, 200, 80), 200);
  assert.equal(validInt(30, 50, 200, 100), 100);
  assert.equal(validInt(201, 50, 200, 100), 100);
  assert.equal(validInt(150.5, 50, 200, 100), 100);
  assert.equal(validInt("150", 50, 200, 100), 100);
  assert.equal(validInt(NaN, 50, 200, 100), 100);
  assert.equal(validInt(undefined, 50, 200, 100), 100);
});

test("validChoice accepts listed values and falls back to the default", () => {
  assert.equal(validChoice("direction", COLOR_MODES, "theme"), "direction");
  assert.equal(validChoice("pink", COLOR_MODES, "theme"), "theme");
  assert.equal(validChoice(undefined, SPARKLINE_MODES, "off"), "off");
});

test("the choice lists are as specified", () => {
  assert.deepEqual(SPARKLINE_MODES, ["off", "background", "beside"]);
  assert.deepEqual(COLOR_MODES, ["theme", "direction", "thresholds"]);
  assert.deepEqual(ICON_STYLES, ["arrows", "triangles", "icons", "none", "custom"]);
});
