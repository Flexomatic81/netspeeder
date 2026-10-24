// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Helpers for the traffic graph: the part of the history inside the chosen
// time window, the allowed window lengths and the scale of the value axis.
// Pure functions without Qt or Plasma dependencies, so the module runs inside
// QML as well as under Node.

const MS_PER_MINUTE = 60 * 1000;
const DEFAULT_MINUTES = 5;
const MINUTE_CHOICES = [1, 5, 15];
// The smallest axis: 1 KiB/s in four steps.
const MIN_AXIS = 1024;
const GRID_STEPS = 4;

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

// 1, 5 or 15; anything else (also a string) becomes 5.
export function validMinutes(value) {
  return MINUTE_CHOICES.indexOf(value) >= 0 ? value : DEFAULT_MINUTES;
}

// The smallest 1, 2 or 5 times a power of ten that is not below `value`.
function niceCeiling(value) {
  const magnitude = Math.pow(10, Math.floor(Math.log10(value)));
  const mantissa = [1, 2, 5, 10].find((m) => m * magnitude >= value);
  return mantissa * magnitude;
}

// The upper limit of the value axis (bytes per second) for the largest
// value, and the distance of the four grid intervals. Invalid input and
// values up to 1 KiB/s give the smallest axis.
export function axisScale(maxValue) {
  if (typeof maxValue !== "number" || !isFinite(maxValue) || maxValue <= MIN_AXIS) {
    return { max: MIN_AXIS, step: MIN_AXIS / GRID_STEPS };
  }
  const max = niceCeiling(maxValue);
  return { max, step: max / GRID_STEPS };
}
