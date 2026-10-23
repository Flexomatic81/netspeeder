// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Layout decisions for the panel view: which arrangement to use and which font
// size fits. Pure functions without Qt or Plasma dependencies, so the module
// runs inside QML as well as under Node. The view measures text widths in QML
// (TextMetrics); this module only turns those measurements into decisions.

// Pixel size at which the view measures text widths. Widths scale linearly
// with the pixel size, so one measurement per candidate is enough.
export const REFERENCE_PX = 100;

// Share of the row height a font of scale 100 % fills, and the hard cap that
// keeps larger scales from overflowing the row.
const ROW_FILL = 0.72;
const ROW_CAP = 0.95;

// A number that is finite, otherwise the fallback (a size that has not been
// laid out yet is 0 or NaN, a config value that has not loaded is undefined).
function finiteOr(value, fallback) {
  const n = Number(value);
  return isFinite(n) ? n : fallback;
}

// Font pixel size for a row of the given height. `fontScale` is a percentage.
export function fontPixelSize(rowHeight, fontScale) {
  const height = Math.max(0, finiteOr(rowHeight, 0));
  const scale = finiteOr(fontScale, 100);
  const size = Math.min((height * ROW_FILL * scale) / 100, height * ROW_CAP);
  return Math.max(1, Math.floor(size));
}

// "single" (one combined value), "rows" (download above upload) or "columns"
// (side by side). `mode` is the layout setting: "rows", "columns" or "auto";
// anything else counts as "auto". In auto mode a vertical panel always stacks
// and a horizontal one uses two rows as long as each row can hold readable text.
export function resolveLayout({ mode, vertical, combined, thickness, fontScale, minReadablePx }) {
  if (combined) return "single";
  if (mode === "rows" || mode === "columns") return mode;
  if (vertical) return "rows";
  return fontPixelSize(finiteOr(thickness, 0) / 2, fontScale) >= finiteOr(minReadablePx, 0)
    ? "rows"
    : "columns";
}

// Largest pixel size (at most `maxPx`, at least 1) at which text that measures
// `measuredAtReference` pixels wide at REFERENCE_PX still fits `available`.
export function fitPixelSize(available, measuredAtReference, maxPx) {
  const max = Math.max(1, Math.floor(finiteOr(maxPx, 1)));
  const measured = finiteOr(measuredAtReference, 0);
  if (measured <= 0) return max;
  const size = Math.floor((Math.max(0, finiteOr(available, 0)) * REFERENCE_PX) / measured);
  return Math.min(max, Math.max(1, size));
}

// Picks the first candidate that fits `available` at a readable size.
// `candidates` are widths at REFERENCE_PX, ordered from the most to the least
// space-hungry variant. If none is readable, the last (most compact) variant
// is used at the size it gets, which is too small but the best possible.
export function fitVertical(available, candidates, maxPx, minReadablePx) {
  const minimum = finiteOr(minReadablePx, 1);
  let result = { index: 0, pixelSize: fitPixelSize(available, 0, maxPx) };
  for (let i = 0; i < candidates.length; i++) {
    result = { index: i, pixelSize: fitPixelSize(available, candidates[i], maxPx) };
    if (result.pixelSize >= minimum) break;
  }
  return result;
}
