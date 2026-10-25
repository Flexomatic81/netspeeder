// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Helpers for the traffic graph: the part of the history inside the chosen
// time window, the allowed window lengths and the scale of the value axis.
// Pure functions without Qt or Plasma dependencies, so the module runs inside
// QML as well as under Node.

import { speedScaling } from "./format.mjs";

const MS_PER_MINUTE = 60 * 1000;
const DEFAULT_MINUTES = 5;
const MINUTE_CHOICES = [1, 5, 15];
const GRID_STEPS = 4;
const LABEL_ROOM = 1.6;
// Two colors are distinct when their perceived distance (the CIE76 color
// difference in CIELAB) is at least this.
const MIN_DELTA_E = 40;
// The D65 white point of sRGB in XYZ.
const WHITE_X = 0.95047;
const WHITE_Z = 1.08883;
const SPARKLINE_FLOOR = 1024;

// How many of the newest samples the panel sparkline shows.
export const SPARKLINE_SAMPLES = 60;

// The points of `history` that are at most `minutes` older than the newest
// one. Selected by time, not by count, so a changed interval or a pause does
// not distort the window.
export function graphWindow(history, minutes) {
  const times = history && history.times ? history.times : [];
  if (times.length === 0) {
    return { down: [], up: [] };
  }
  const from = times[times.length - 1] - minutes * MS_PER_MINUTE;
  const down = [];
  const up = [];
  for (let i = 0; i < times.length; i++) {
    if (times[i] >= from) {
      down.push(history.down[i]);
      up.push(history.up[i]);
    }
  }
  return { down, up };
}

// The newest `count` points of the history (fewer when there are fewer); a
// count that is not a positive whole number means 60.
export function lastSamples(history, count) {
  const down = history && history.down ? history.down : [];
  const up = history && history.up ? history.up : [];
  const n = Number.isInteger(count) && count > 0 ? count : SPARKLINE_SAMPLES;
  return { down: down.slice(-n), up: up.slice(-n) };
}

// The upper end of the sparkline's value axis (bytes per second): the largest
// value of the shown series (the sums when `combined`), at least 1024 so a
// quiet link stays near the bottom. Values that are not finite count as 0.
export function sparklineMax(down, up, combined) {
  const clean = (v) => (typeof v === "number" && isFinite(v) && v > 0 ? v : 0);
  let max = SPARKLINE_FLOOR;
  for (let i = 0; i < down.length; i++) {
    const value = combined ? clean(down[i]) + clean(up[i]) : Math.max(clean(down[i]), clean(up[i]));
    max = Math.max(max, value);
  }
  if (!combined) {
    for (let i = down.length; i < up.length; i++) {
      max = Math.max(max, clean(up[i]));
    }
  }
  return max;
}

// 1, 5 or 15; anything else (also a string) becomes 5.
export function validMinutes(value) {
  return MINUTE_CHOICES.indexOf(value) >= 0 ? value : DEFAULT_MINUTES;
}

// The nice values of the mantissa: 1, 2 and 5 times a power of ten up to 500;
// the unit factor itself stands for 1 of the next unit.
const NICE = [1, 2, 5, 10, 20, 50, 100, 200, 500];

// Mantissas whose limit is split into four steps (0.5, 5, 50 ... of the unit);
// the other nice values give five (1, 2, 10 ... of the unit), so every step is
// itself 1, 2 or 5 times a power of ten. 1 of a unit (also the "factor"
// entry) takes four steps of a quarter, which are whole numbers of the unit
// below (256 KiB/s, 250 kB/s).
const FOUR_STEPS = [1, 2, 20, 200];

// The upper limit of the value axis (bytes per second) for the largest value,
// the distance of the grid intervals and their number (4 or 5). The limit is
// chosen in the displayed unit system (1, 2, 5, 10 ... 500 of a unit, so
// "1 MiB/s" and not "977 KiB/s"). The smallest axis is one step of the first
// non-base unit: 1024 B/s (iec), 1000 B/s (si) or 125 B/s = 1 kbit/s (bits).
// Invalid input and values up to that minimum give the smallest axis.
export function axisScale(maxValue, formatOptions) {
  const { factor, speedScale } = speedScaling(formatOptions);
  const minimum = factor / speedScale;
  const smallest = { max: minimum, step: minimum / GRID_STEPS, steps: GRID_STEPS };
  if (typeof maxValue !== "number" || !isFinite(maxValue) || maxValue <= minimum) {
    return smallest;
  }
  const shown = maxValue * speedScale;
  let unit = 1;
  while (unit * factor <= shown) {
    unit *= factor;
  }
  const mantissa = NICE.concat([factor]).find((m) => m * unit >= shown);
  const max = (mantissa * unit) / speedScale;
  const steps = FOUR_STEPS.includes(mantissa) || mantissa === factor ? 4 : 5;
  return { max, step: max / steps, steps };
}

// The indices (0 = bottom ... steps = top) of the axis labels that fit into
// `availableHeight` when each label is `labelHeight` high. With little room
// only the bottom (0) and the top stay, so the labels never read unevenly.
export function axisLabelIndices(steps, availableHeight, labelHeight) {
  const all = [];
  for (let i = 0; i <= steps; i++) {
    all.push(i);
  }
  if (availableHeight >= steps * labelHeight * LABEL_ROOM) {
    return all;
  }
  return [0, steps];
}

// An sRGB channel (0..1) without the gamma curve.
function linear(channel) {
  return channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4);
}

// The cube-root curve of CIELAB, linear near black.
function labCurve(t) {
  const edge = 6 / 29;
  return t > edge * edge * edge ? Math.cbrt(t) : t / (3 * edge * edge) + 4 / 29;
}

// `{ r, g, b }` (sRGB, each 0..1) in CIELAB, as [L, a, b].
function toLab(color) {
  const r = linear(color.r);
  const g = linear(color.g);
  const b = linear(color.b);
  const x = labCurve((0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / WHITE_X);
  const y = labCurve(0.2126729 * r + 0.7151522 * g + 0.072175 * b);
  const z = labCurve((0.0193339 * r + 0.119192 * g + 0.9503041 * b) / WHITE_Z);
  return [116 * y - 16, 500 * (x - y), 200 * (y - z)];
}

// Whether two colors are told apart at a glance: their perceived distance
// (CIE76) reaches MIN_DELTA_E.
function isDistinct(first, second) {
  const a = toLab(first);
  const b = toLab(second);
  return Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]) >= MIN_DELTA_E;
}

// The index of the first of `candidates` (`{ r, g, b }`, each 0..1) that is
// clearly distinct from `base` (see isDistinct); the last index when none is,
// -1 for no candidates.
export function pickDistinct(base, candidates) {
  const distinct = candidates.findIndex((c) => isDistinct(base, c));
  return distinct >= 0 ? distinct : candidates.length - 1;
}
