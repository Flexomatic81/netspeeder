// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81
// SPDX-FileCopyrightText: 2016 Daniel Faust <hessijames@gmail.com>

// Unit formatting for speeds and traffic totals. Pure functions without Qt or
// Plasma dependencies, so the module runs inside QML as well as under Node.
// Rates are always bytes per second and totals always bytes; the unit system
// only decides how they are displayed.

export const DEFAULT_FORMAT = Object.freeze({
  unitSystem: "iec",
  shortUnits: false,
  decimals: -1,
  lowSpeedThreshold: 1024,
  decimalPoint: ".",
});

// factor: step between two units. speedScale: multiplier applied to bytes/s
// before scaling (bits mode shows bits). Totals are always shown in bytes.
const SYSTEMS = {
  iec: {
    factor: 1024,
    speedScale: 1,
    speed: ["B/s", "KiB/s", "MiB/s", "GiB/s"],
    speedShort: ["B", "K", "M", "G"],
    total: ["B", "KiB", "MiB", "GiB", "TiB"],
  },
  si: {
    factor: 1000,
    speedScale: 1,
    speed: ["B/s", "kB/s", "MB/s", "GB/s"],
    speedShort: ["B", "K", "M", "G"],
    total: ["B", "kB", "MB", "GB", "TB"],
  },
  bits: {
    factor: 1000,
    speedScale: 8,
    speed: ["bit/s", "kbit/s", "Mbit/s", "Gbit/s"],
    speedShort: ["b", "k", "m", "g"],
    total: ["B", "kB", "MB", "GB", "TB"],
  },
};

const VALID_DECIMALS = [-1, 0, 1, 2];

// Merges partial options with DEFAULT_FORMAT. Anything missing, undefined or
// invalid (for example a config value that has not loaded yet) falls back to
// the default instead of leaking into the display.
function normalize(opts) {
  const o = opts || {};
  const threshold = o.lowSpeedThreshold;
  return {
    unitSystem: Object.prototype.hasOwnProperty.call(SYSTEMS, o.unitSystem)
      ? o.unitSystem
      : DEFAULT_FORMAT.unitSystem,
    shortUnits: o.shortUnits === undefined ? DEFAULT_FORMAT.shortUnits : Boolean(o.shortUnits),
    decimals: VALID_DECIMALS.indexOf(o.decimals) >= 0 ? o.decimals : DEFAULT_FORMAT.decimals,
    lowSpeedThreshold:
      typeof threshold === "number" && isFinite(threshold) && threshold >= 0
        ? threshold
        : DEFAULT_FORMAT.lowSpeedThreshold,
    decimalPoint:
      typeof o.decimalPoint === "string" && o.decimalPoint.length > 0
        ? o.decimalPoint
        : DEFAULT_FORMAT.decimalPoint,
  };
}

// Sensor values are undefined/NaN before the first sample arrives; those and
// negative values must show as 0, never as "NaN".
function toNonNegative(input) {
  const n = Number(input);
  return isFinite(n) && n >= 0 ? n : 0;
}

function decimalPlaces(index, value, decimals) {
  if (index === 0) return 0; // the base unit (B, bit) is never fractional
  if (decimals !== -1) return decimals;
  // Auto: decided on the rounded value, so 99.96 becomes "100", not "100.0".
  return Number(value.toFixed(1)) < 100 ? 1 : 0;
}

// Divides `value` down to the first unit where it is below 1000 and renders it.
function scale(value, factor, lastIndex, o) {
  let v = value;
  let i = 0;
  while (v >= 1000 && i < lastIndex) {
    v /= factor;
    i++;
  }
  let text = v.toFixed(decimalPlaces(i, v, o.decimals));
  // Rounding may land on 1000 (999.97 -> "1000"); move to the next unit then.
  if (Number(text) >= 1000 && i < lastIndex) {
    v /= factor;
    i++;
    text = v.toFixed(decimalPlaces(i, v, o.decimals));
  }
  // Function replacer: a decimalPoint like "$&" must not be interpreted.
  return { index: i, text: text.replace(".", () => o.decimalPoint) };
}

export function speedUnits(opts) {
  const o = normalize(opts);
  const system = SYSTEMS[o.unitSystem];
  return (o.shortUnits ? system.speedShort : system.speed).slice();
}

export function formatSpeed(bytesPerSecond, opts) {
  const o = normalize(opts);
  const system = SYSTEMS[o.unitSystem];
  const units = o.shortUnits ? system.speedShort : system.speed;
  let v = toNonNegative(bytesPerSecond);
  // The threshold is compared in bytes, before any conversion to bits.
  if (v < o.lowSpeedThreshold) v = 0;
  const r = scale(v * system.speedScale, system.factor, units.length - 1, o);
  return { value: r.text, unit: units[r.index] };
}

export function formatTotal(bytes, opts) {
  const o = normalize(opts);
  const system = SYSTEMS[o.unitSystem];
  const r = scale(toNonNegative(bytes), system.factor, system.total.length - 1, o);
  return { value: r.text, unit: system.total[r.index] };
}

// Widest value the display can show; used to size the text slot so the layout
// does not jump while the numbers change. "-1" (auto) shows one decimal at most.
export function widestValue(opts) {
  const o = normalize(opts);
  const count = o.decimals === -1 ? 1 : o.decimals;
  return count === 0 ? "888" : "888" + o.decimalPoint + "8".repeat(count);
}
