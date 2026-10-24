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
  } catch {
    return null;
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
