// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Rules for how speeds look: the colour thresholds, the colour modes, the
// direction symbols and fallbacks for stored settings. Pure functions without
// Qt or Plasma dependencies, so the module runs inside QML as well as under
// Node. An empty colour string always means "use the theme's colour".

const MIB = 1048576;
const MAX_MIN = 2147483647; // 2 GiB/s, the most a number input can hold
const MAX_STEPS = 6;
const MAX_SYMBOL_LENGTH = 3;
const COLOR_PATTERN = /^#[0-9a-fA-F]{6}$/;

// The most levels a threshold list holds.
export const MAX_LEVELS = MAX_STEPS;

export const SPARKLINE_MODES = ["off", "background", "beside"];
export const COLOR_MODES = ["theme", "direction", "thresholds"];
export const ICON_STYLES = ["arrows", "triangles", "icons", "none", "custom"];

export const DEFAULT_THRESHOLDS = Object.freeze([
  Object.freeze({ min: 0, color: "" }),
  Object.freeze({ min: MIB, color: "#1d99f3" }),
  Object.freeze({ min: 10 * MIB, color: "#f67400" }),
  Object.freeze({ min: 100 * MIB, color: "#da4453" }),
]);

const SYMBOL_SETS = {
  arrows: { down: "↓", up: "↑", icons: false },
  triangles: { down: "▼", up: "▲", icons: false },
  icons: { down: "go-down", up: "go-up", icons: true },
  none: { down: "", up: "", icons: false },
};

// "" or a #rrggbb colour in lower case; anything else is "".
function cleanColor(value) {
  if (value === "") {
    return "";
  }
  return typeof value === "string" && COLOR_PATTERN.test(value) ? value.toLowerCase() : null;
}

// The cleaned step, or null when its minimum or colour is unusable.
function cleanStep(step) {
  if (!step || typeof step !== "object") {
    return null;
  }
  const color = cleanColor(step.color);
  const ok = Number.isInteger(step.min) && step.min >= 0 && step.min <= MAX_MIN;
  return ok && color !== null ? { min: step.min, color } : null;
}

function defaultSteps() {
  return DEFAULT_THRESHOLDS.map((step) => ({ min: step.min, color: step.color }));
}

function parseJson(text) {
  try {
    return JSON.parse(text);
  } catch (error) {
    // Text that is not JSON; anything else is a real fault.
    if (error instanceof SyntaxError) {
      return null;
    }
    throw error;
  }
}

// The steps from a JSON array: invalid ones dropped, a repeated minimum keeps
// the last, ascending, a step at 0 guaranteed, at most six. Without a usable
// step the defaults are returned (always as a new list).
export function parseThresholds(text) {
  const parsed = typeof text === "string" ? parseJson(text) : null;
  if (!Array.isArray(parsed)) {
    return defaultSteps();
  }
  const byMin = new Map();
  for (const step of parsed.map(cleanStep)) {
    if (step) {
      byMin.set(step.min, step);
    }
  }
  if (byMin.size === 0) {
    return defaultSteps();
  }
  const sorted = [...byMin.values()].sort((a, b) => a.min - b.min);
  if (sorted[0].min !== 0) {
    sorted.unshift({ min: 0, color: "" });
  }
  return sorted.slice(0, MAX_STEPS);
}

// Compact JSON of the cleaned steps; parsing it again changes nothing.
export function serializeThresholds(list) {
  const text = typeof list === "string" ? list : JSON.stringify(list);
  return JSON.stringify(parseThresholds(text));
}

// The colour of the highest step whose minimum `rate` reaches; an invalid
// rate counts as 0.
export function thresholdColor(rate, list) {
  const value = Number.isFinite(rate) && rate > 0 ? rate : 0;
  let color = "";
  let best = -1;
  for (const step of Array.isArray(list) ? list : []) {
    if (step.min <= value && step.min > best) {
      best = step.min;
      color = step.color;
    }
  }
  return color;
}

function validColor(value) {
  return cleanColor(value) || "";
}

// The colours of download, upload and sum for a colour mode. Unknown modes
// behave like "theme". In "direction" the sum takes the download colour.
export function speedColors(mode, rates, cfg) {
  const settings = cfg || {};
  if (mode === "direction") {
    const down = validColor(settings.downloadColor);
    return { down, up: validColor(settings.uploadColor), total: down };
  }
  if (mode === "thresholds") {
    const list = settings.thresholds;
    return {
      down: validColor(thresholdColor(rates.down, list)),
      up: validColor(thresholdColor(rates.up, list)),
      total: validColor(thresholdColor(rates.total, list)),
    };
  }
  return { down: "", up: "", total: "" };
}

// A custom symbol cut to three characters; empty or not a string gives the fallback.
function customSymbol(value, fallback) {
  const text = typeof value === "string" ? Array.from(value).slice(0, MAX_SYMBOL_LENGTH).join("") : "";
  return text === "" ? fallback : text;
}

// The direction symbols of an icon style. `icons` tells QML to show theme
// icons (named in down/up) instead of text. Unknown styles use arrows.
export function symbols(style, custom) {
  if (style === "custom") {
    const own = custom || {};
    return {
      down: customSymbol(own.down, SYMBOL_SETS.arrows.down),
      up: customSymbol(own.up, SYMBOL_SETS.arrows.up),
      icons: false,
    };
  }
  const set = SYMBOL_SETS[style] || SYMBOL_SETS.arrows;
  return { down: set.down, up: set.up, icons: set.icons };
}

// `value` when it is one of `allowed`, otherwise `fallback`.
export function validChoice(value, allowed, fallback) {
  return allowed.indexOf(value) >= 0 ? value : fallback;
}

// `value` when it is an integer within min..max, otherwise `fallback`.
export function validInt(value, min, max, fallback) {
  return Number.isInteger(value) && value >= min && value <= max ? value : fallback;
}

// The units of the threshold editor; each is 1024 times the one before.
export const BYTE_UNITS = ["B/s", "KiB/s", "MiB/s", "GiB/s"];
const UNIT_FACTOR = 1024;

function unitFactor(unitIndex) {
  return Number.isInteger(unitIndex) && unitIndex >= 0 && unitIndex < BYTE_UNITS.length ? UNIT_FACTOR ** unitIndex : 1;
}

// Bytes per second as a number in the largest unit in which it is whole, so
// that every valid threshold is shown exactly. Fractions are rounded to whole
// bytes; anything unusable is 0 B/s.
export function splitBytes(bytes) {
  const whole = Number.isFinite(bytes) && bytes > 0 ? Math.round(bytes) : 0;
  let unitIndex = 0;
  while (whole > 0 && unitIndex < BYTE_UNITS.length - 1 && whole % unitFactor(unitIndex + 1) === 0) {
    unitIndex++;
  }
  return { value: whole / unitFactor(unitIndex), unitIndex };
}

// A number in a unit of BYTE_UNITS as bytes per second; an unknown unit counts
// as B/s, the number is rounded and at least 0.
export function joinBytes(value, unitIndex) {
  const whole = Number.isFinite(value) && value > 0 ? Math.round(value) : 0;
  return whole * unitFactor(unitIndex);
}

// The largest number a unit can hold without leaving the valid minimums.
export function unitLimit(unitIndex) {
  return Math.floor(MAX_MIN / unitFactor(unitIndex));
}

// The middle of the widest gap between the sorted minimums.
function widestGapMiddle(mins) {
  let best = { width: 0, middle: 0 };
  for (let i = 1; i < mins.length; i++) {
    const width = mins[i] - mins[i - 1];
    if (width > best.width) {
      best = { width, middle: Math.ceil((mins[i - 1] + mins[i]) / 2) };
    }
  }
  return best.middle;
}

// A minimum for a new level that no step of `list` has, above the others when
// there is room: twice the highest one while that stays valid (1 MiB/s above
// a lone 0), else halfway to the limit; at the limit, the middle of the widest
// gap below it.
export function newLevelMin(list) {
  const mins = (Array.isArray(list) ? list : []).map((step) => step.min).sort((a, b) => a - b);
  const highest = mins.length > 0 ? mins[mins.length - 1] : 0;
  if (highest === 0) {
    return MIB;
  }
  if (highest * 2 <= MAX_MIN) {
    return highest * 2;
  }
  return highest < MAX_MIN ? Math.ceil((highest + MAX_MIN) / 2) : widestGapMiddle(mins);
}

function hexChannel(value) {
  const level = Number.isFinite(value) ? Math.min(Math.max(value, 0), 1) : 0;
  return Math.round(level * 255)
    .toString(16)
    .padStart(2, "0");
}

// "#rrggbb" from colour channels between 0 and 1 (Qt's color.r/g/b); values
// outside are limited, unusable ones count as 0. Alpha is left out.
export function toHexColor(r, g, b) {
  return "#" + hexChannel(r) + hexChannel(g) + hexChannel(b);
}
