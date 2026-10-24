// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  COLOR_MODES,
  DEFAULT_THRESHOLDS,
  freeThreshold,
  ICON_STYLES,
  MAX_LEVELS,
  BYTE_UNITS,
  SPARKLINE_MODES,
  joinBytes,
  newLevelMin,
  parseThresholds,
  serializeThresholds,
  speedColors,
  splitBytes,
  symbols,
  thresholdColor,
  toHexColor,
  unitLimit,
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

test("splitBytes picks the largest unit that keeps the value whole", () => {
  assert.deepEqual(splitBytes(0), { value: 0, unitIndex: 0 });
  assert.deepEqual(splitBytes(1024), { value: 1, unitIndex: 1 });
  assert.deepEqual(splitBytes(MIB), { value: 1, unitIndex: 2 });
  assert.deepEqual(splitBytes(1024 * MIB), { value: 1, unitIndex: 3 });
  assert.deepEqual(splitBytes(1536), { value: 1536, unitIndex: 0 });
  assert.deepEqual(splitBytes(10001), { value: 10001, unitIndex: 0 });
  assert.deepEqual(splitBytes(MIB + 1), { value: MIB + 1, unitIndex: 0 });
  assert.deepEqual(splitBytes(10 * MIB), { value: 10, unitIndex: 2 });
  assert.deepEqual(splitBytes(3 * 1024), { value: 3, unitIndex: 1 });
});

test("splitBytes rounds to whole bytes, unusable input gives 0 B/s", () => {
  assert.deepEqual(splitBytes(1500.4), { value: 1500, unitIndex: 0 });
  assert.deepEqual(splitBytes(1023.6), { value: 1, unitIndex: 1 });
  for (const bad of [-5, NaN, Infinity, "1024", undefined]) {
    assert.deepEqual(splitBytes(bad), { value: 0, unitIndex: 0 }, String(bad));
  }
});

test("joinBytes multiplies by the unit and round-trips with splitBytes", () => {
  assert.equal(joinBytes(0, 0), 0);
  assert.equal(joinBytes(1, 1), 1024);
  assert.equal(joinBytes(10, 2), 10 * MIB);
  assert.equal(joinBytes(1, 3), 1024 * MIB);
  assert.equal(joinBytes(2.6, 1), 3072);
  assert.equal(joinBytes(5, 9), 5);
  assert.equal(joinBytes(5, -1), 5);
  assert.equal(joinBytes(-3, 2), 0);
  assert.equal(joinBytes(NaN, 2), 0);
  for (const bytes of [0, 1, 1023, 1024, 1536, 10001, MIB, MIB + 1, 10 * MIB, 100 * MIB, 2147483647, 1024 * MIB]) {
    const { value, unitIndex } = splitBytes(bytes);
    assert.equal(joinBytes(value, unitIndex), bytes, String(bytes));
  }
});

test("unitLimit is the largest number a unit can hold", () => {
  assert.deepEqual(BYTE_UNITS, ["B/s", "KiB/s", "MiB/s", "GiB/s"]);
  assert.equal(MAX_LEVELS, 6);
  assert.equal(unitLimit(0), 2147483647);
  assert.equal(unitLimit(1), 2097151);
  assert.equal(unitLimit(2), 2047);
  assert.equal(unitLimit(3), 1);
  assert.equal(unitLimit(7), 2147483647);
  for (let unit = 0; unit < 4; unit++) {
    assert.ok(joinBytes(unitLimit(unit), unit) <= 2147483647);
  }
});

test("newLevelMin finds a free minimum above the others", () => {
  assert.equal(newLevelMin([{ min: 0, color: "" }]), MIB);
  assert.equal(newLevelMin(DEFAULT_THRESHOLDS), 200 * MIB);
  assert.equal(newLevelMin([{ min: 0 }, { min: 1500 * MIB }]), Math.ceil((1500 * MIB + 2147483647) / 2));
  assert.equal(newLevelMin([{ min: 0 }, { min: 10 }, { min: 2147483647 }]), Math.ceil((10 + 2147483647) / 2));
  assert.equal(newLevelMin([]), MIB);
  for (const list of [
    [{ min: 0 }, { min: 1 }, { min: 2147483647 }],
    [{ min: 0 }, { min: 2147483646 }, { min: 2147483647 }],
  ]) {
    const min = newLevelMin(list);
    assert.ok(Number.isInteger(min) && min >= 0 && min <= 2147483647);
    assert.ok(!list.some((step) => step.min === min), String(min));
  }
});

const levels = (...mins) => mins.map((min) => ({ min, color: "" }));

test("freeThreshold keeps a value that no other level has", () => {
  assert.equal(freeThreshold(levels(0, MIB, 10 * MIB), 1, 5 * MIB, MIB, MIB), 5 * MIB);
  assert.equal(freeThreshold(levels(0, MIB, 10 * MIB), 1, MIB, MIB, MIB), MIB);
});

test("freeThreshold steps over a level when moving up into it", () => {
  assert.equal(freeThreshold(levels(0, 9 * MIB, 10 * MIB, 100 * MIB), 1, 10 * MIB, 9 * MIB, MIB), 11 * MIB);
});

test("freeThreshold steps over a level when moving down into it", () => {
  assert.equal(freeThreshold(levels(0, 9 * MIB, 10 * MIB), 2, 9 * MIB, 10 * MIB, MIB), 8 * MIB);
});

test("freeThreshold moves a typed duplicate on in the direction of the change", () => {
  assert.equal(freeThreshold(levels(0, MIB, 10 * MIB, 100 * MIB), 1, 100 * MIB, MIB, MIB), 101 * MIB);
  assert.equal(freeThreshold(levels(0, MIB, 10 * MIB, 100 * MIB), 3, MIB, 100 * MIB, 1024), MIB - 1024);
});

test("freeThreshold steps over several levels in a row", () => {
  assert.equal(freeThreshold(levels(0, MIB, 2 * MIB, 3 * MIB, 4 * MIB), 1, 2 * MIB, MIB, MIB), 5 * MIB);
  assert.equal(freeThreshold(levels(0, 2 * MIB, 3 * MIB, 4 * MIB), 3, 3 * MIB, 4 * MIB, MIB), MIB);
});

test("freeThreshold keeps the previous value when the way is blocked", () => {
  const gib = 1024 * MIB;
  // Up: the next free GiB step is beyond the limit.
  assert.equal(freeThreshold(levels(0, 100 * MIB, gib), 1, gib, 100 * MIB, gib), 100 * MIB);
  // Down: only 0 is left, which belongs to the first level.
  assert.equal(freeThreshold(levels(0, MIB, 2 * MIB), 2, MIB, 2 * MIB, MIB), 2 * MIB);
  // A wanted value outside 1..limit is never returned.
  assert.equal(freeThreshold(levels(0, 5), 1, 2147483648, 5, 1), 5);
  assert.equal(freeThreshold(levels(0, 5), 1, 0, 5, 1), 5);
});

test("freeThreshold leaves the first level at 0 and copes with odd input", () => {
  assert.equal(freeThreshold(levels(0, MIB), 0, 0, 0, 1), 0);
  assert.equal(freeThreshold(levels(0, 3, 4), 1, 4, 3, 0), 5);
  assert.equal(freeThreshold(undefined, 1, 7, 3, 1), 7);
});

test("toHexColor writes #rrggbb from channels 0..1", () => {
  assert.equal(toHexColor(0, 0, 0), "#000000");
  assert.equal(toHexColor(1, 1, 1), "#ffffff");
  assert.equal(toHexColor(0.5, 0, 1), "#8000ff");
  assert.equal(toHexColor(1, 0.5, 0), "#ff8000");
  assert.equal(toHexColor(-1, 2, 0.2), "#00ff33");
  assert.equal(toHexColor(NaN, undefined, "x"), "#000000");
});

// The stored defaults in main.xml agree with the rules above.
const mainXml = readFileSync(new URL("../package/contents/config/main.xml", import.meta.url), "utf8");
function xmlDefault(name) {
  const match = mainXml.match(new RegExp(`<entry name="${name}" type="[A-Za-z]+">\\s*<default>([^<]*)</default>`));
  assert.ok(match, `no default for ${name}`);
  return match[1];
}

test("main.xml stores the default thresholds in their serialized form", () => {
  assert.equal(xmlDefault("colorThresholds"), serializeThresholds(DEFAULT_THRESHOLDS));
});

test("main.xml defaults are valid choices and symbols", () => {
  assert.equal(validChoice(xmlDefault("iconStyle"), ICON_STYLES, ""), "arrows");
  assert.equal(validChoice(xmlDefault("colorMode"), COLOR_MODES, ""), "theme");
  assert.equal(validChoice(xmlDefault("sparkline"), SPARKLINE_MODES, ""), "off");
  assert.deepEqual(
    symbols("custom", { down: xmlDefault("customDownIcon"), up: xmlDefault("customUpIcon") }),
    symbols("arrows"),
  );
  assert.equal(validInt(Number(xmlDefault("fontScale")), 50, 200, 0), 100);
});
