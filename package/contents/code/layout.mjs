// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Layout decisions for the panel view: which arrangement to use and which font
// size fits. Pure functions without Qt or Plasma dependencies, so the module
// runs inside QML as well as under Node. The view measures text widths in QML
// (TextMetrics); this module only turns those measurements into decisions.

// Pixel size at which the view measures text widths. Widths scale linearly
// with the pixel size, so one measurement per candidate is enough.
export const REFERENCE_PX = 100;

// Share of the row height a font of scale 100 % fills, and the cap for larger
// scales when the line height of the font is not known.
const ROW_FILL = 0.72;
const ROW_CAP = 0.95;

// A number that is finite, otherwise the fallback (a size that has not been
// laid out yet is 0 or NaN, a config value that has not loaded is undefined).
function finiteOr(value, fallback) {
  const n = Number(value);
  return isFinite(n) ? n : fallback;
}

// Font pixel size for a row of the given height. `fontScale` is a percentage.
// `lineRatio` is the height of a text line divided by the pixel size of its
// font; the line must fit the row, however large the scale.
export function fontPixelSize(rowHeight, fontScale, lineRatio) {
  const height = Math.max(0, finiteOr(rowHeight, 0));
  const scale = finiteOr(fontScale, 100);
  const ratio = finiteOr(lineRatio, 0);
  const cap = ratio > 0 ? height / ratio : height * ROW_CAP;
  const size = Math.min((height * ROW_FILL * scale) / 100, cap);
  return Math.max(1, Math.floor(size));
}

// "single" (one combined value), "rows" (download above upload) or "columns"
// (side by side). `mode` is the layout setting: "rows", "columns" or "auto";
// anything else counts as "auto". In auto mode a vertical panel always stacks
// and a horizontal one uses two rows as long as each row can hold readable text
// (`lineRatio` as for fontPixelSize).
export function resolveLayout({ mode, vertical, combined, thickness, fontScale, minReadablePx, lineRatio }) {
  if (combined) return "single";
  if (mode === "rows" || mode === "columns") return mode;
  if (vertical) return "rows";
  const rowPx = fontPixelSize(finiteOr(thickness, 0) / 2, fontScale, lineRatio);
  return rowPx >= finiteOr(minReadablePx, 0) ? "rows" : "columns";
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

// Width at `px` of text that measures `measured` at REFERENCE_PX, plus what
// the layout adds by rounding each of the `rounded` parts (widths at
// REFERENCE_PX that are part of the text) up to whole pixels.
function roundedWidth(px, measured, rounded) {
  let width = (measured * px) / REFERENCE_PX;
  for (const part of rounded) {
    const scaled = (finiteOr(part, 0) * px) / REFERENCE_PX;
    width += Math.ceil(scaled) - scaled;
  }
  return width;
}

// fitPixelSize(), made smaller until the rounded parts fit as well.
function fitRounded(available, measured, maxPx, rounded) {
  const room = Math.max(0, finiteOr(available, 0));
  let size = fitPixelSize(room, measured, maxPx);
  while (size > 1 && roundedWidth(size, finiteOr(measured, 0), rounded) > room) {
    size -= 1;
  }
  return size;
}

// Picks the first candidate that fits `available` at a readable size.
// `candidates` are widths at REFERENCE_PX, ordered from the most to the least
// space-hungry variant. If none is readable, the last (most compact) variant
// is used at the size it gets, which is too small but the best possible.
// `rounded` lists parts of every candidate (widths at REFERENCE_PX) that the
// layout rounds up to whole pixels, such as the symbol column.
export function fitVertical(available, candidates, maxPx, minReadablePx, rounded) {
  const minimum = finiteOr(minReadablePx, 1);
  const parts = Array.isArray(rounded) ? rounded : [];
  let result = { index: 0, pixelSize: fitPixelSize(available, 0, maxPx) };
  for (let i = 0; i < candidates.length; i++) {
    result = { index: i, pixelSize: fitRounded(available, candidates[i], maxPx, parts) };
    if (result.pixelSize >= minimum) break;
  }
  return result;
}

// The length unit of the popup: the grid unit, or the line height of the
// default font when that is larger. Kirigami's grid unit is fixed in Plasma 6,
// so without the line height a larger font would not widen the popup and its
// texts would elide.
export function popupUnit(gridUnit, lineHeight) {
  const line = finiteOr(lineHeight, 0);
  return Math.max(gridUnit, Math.floor(line));
}

// The height the interface list asks for: its content, but at most `rows`
// rows with the `spacing` between them, and at least one row (0 while there
// is none).
export function listRoom(contentHeight, rowHeight, rows, spacing) {
  const row = Math.max(0, finiteOr(rowHeight, 0));
  const content = Math.max(0, finiteOr(contentHeight, 0));
  const gap = Math.max(0, finiteOr(spacing, 0));
  return Math.max(row, Math.min(content, row * rows + gap * (rows - 1)));
}
