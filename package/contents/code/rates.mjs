// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81
// SPDX-FileCopyrightText: 2016 Daniel Faust <hessijames@gmail.com>

// Byte rates from two counter snapshots. Pure functions without Qt
// or Plasma dependencies, so the module runs inside QML as well as under Node.
// Rates are always bytes per second.

// A gap longer than this many intervals (clock jump, suspend/resume) makes the
// sample unusable for rates.
const MAX_GAP_INTERVALS = 5;

// A counter is usable when it is a finite, non-negative number. undefined and
// NaN occur before the first sample arrives.
function isCounter(value) {
  const n = Number(value);
  return isFinite(n) && n >= 0;
}

// Rate of one direction over one tick, in bytes per second, never negative.
function directionRate(before, after, dtMs) {
  // Without a usable previous value there is no baseline, so the tick yields 0,
  // the same as a first sample. Otherwise a cumulative counter since boot would
  // show up as one huge spike.
  if (!isCounter(before)) return 0;
  const previous = Number(before);
  // An unusable new value counts as 0, which is then a reset.
  const current = isCounter(after) ? Number(after) : 0;
  // Counter went backwards: reset or re-created interface.
  if (current < previous) return 0;
  return ((current - previous) * 1000) / dtMs;
}

// prev: previous snapshot or null; next: current snapshot; intervalMs: nominal
// sampling interval. Returns { valid, rates }. For an invalid sample, rates is
// empty. The caller still uses `next` as the base for the following tick.
// Interfaces missing from `next` are absent from `rates`; consumers treat them
// as 0.
export function computeRates(prev, next, intervalMs) {
  let dtMs = 0;
  if (prev) {
    dtMs = next.timestamp - prev.timestamp;
    // Written as "not ok" so that a NaN timestamp also invalidates the sample.
    if (!(dtMs > 0 && dtMs <= MAX_GAP_INTERVALS * intervalMs)) {
      return { valid: false, rates: {} };
    }
  }
  const rates = {};
  for (const name of Object.keys(next.counters)) {
    const now = next.counters[name];
    const was = prev && Object.prototype.hasOwnProperty.call(prev.counters, name) ? prev.counters[name] : null;
    // First sample of an interface (or of the whole series) yields 0.
    rates[name] = was
      ? { down: directionRate(was.rx, now.rx, dtMs), up: directionRate(was.tx, now.tx, dtMs) }
      : { down: 0, up: 0 };
  }
  return { valid: true, rates: rates };
}
