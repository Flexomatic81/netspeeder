// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Rolling traffic history with peaks and session totals. Pure functions
// without Qt or Plasma dependencies, so the module runs inside QML as well as
// under Node. Every function returns a new object and leaves its input alone.
// Conservative syntax on purpose (no object spread): the QML engine imports
// this module too.

const HISTORY_MINUTES = 15;
const MS_PER_MINUTE = 60 * 1000;
// Capacity for an unusable interval: 15 minutes at one sample per second.
const FALLBACK_CAPACITY = 900;

// Number of samples that cover 15 minutes at the given interval.
export function capacityFor(intervalMs) {
  const interval = Number(intervalMs);
  if (!isFinite(interval) || interval <= 0) return FALLBACK_CAPACITY;
  return Math.max(1, Math.ceil((HISTORY_MINUTES * MS_PER_MINUTE) / interval));
}

function normalizeCapacity(capacity) {
  const n = Math.floor(Number(capacity));
  return isFinite(n) && n >= 1 ? n : 1;
}

export function createHistory(capacity) {
  return {
    capacity: normalizeCapacity(capacity),
    down: [],
    up: [],
    times: [],
    peakDown: 0,
    peakUp: 0,
    sessionDown: 0,
    sessionUp: 0,
    baselines: {},
  };
}

function copyHistory(history, changes) {
  const next = {};
  for (const key of Object.keys(history)) next[key] = history[key];
  for (const key of Object.keys(changes)) next[key] = changes[key];
  return next;
}

// The most recent `capacity` entries of a list.
function tail(list, capacity) {
  return list.length > capacity ? list.slice(list.length - capacity) : list.slice();
}

// A copy of the list with the value appended, trimmed to the most recent
// `capacity` entries; the list itself is copied once and left alone.
function appended(list, value, capacity) {
  const drop = Math.max(0, list.length + 1 - capacity);
  const next = drop > 0 ? list.slice(drop) : list.slice();
  next.push(value);
  return next;
}

function isCount(value) {
  return typeof value === "number" && isFinite(value) && value >= 0;
}

function isKnown(entry) {
  return Boolean(entry) && entry.known === true && isCount(entry.down) && isCount(entry.up);
}

// Bytes counted in one direction since the previous reading. A counter that
// went backwards was reset; what it shows now has been counted since then.
function counted(before, after) {
  return after >= before ? after - before : after;
}

// Folds the per-interface counters into the baselines and the session sums.
// Returns { baselines, addedDown, addedUp }.
function foldTotals(previous, totals) {
  const baselines = {};
  let addedDown = 0;
  let addedUp = 0;
  for (const name of Object.keys(totals || {})) {
    const entry = totals[name];
    if (isKnown(entry)) {
      const base = Object.prototype.hasOwnProperty.call(previous, name) ? previous[name] : null;
      if (base !== null) {
        addedDown += counted(base.down, entry.down);
        addedUp += counted(base.up, entry.up);
      }
      baselines[name] = { down: entry.down, up: entry.up };
    } else if (Object.prototype.hasOwnProperty.call(previous, name)) {
      // Not known right now: the baseline stays for when it is again.
      baselines[name] = previous[name];
    }
  }
  return { baselines: baselines, addedDown: addedDown, addedUp: addedUp };
}

// sample: { timestamp, down, up, totals: { [name]: { down, up, known } } }
export function pushSample(history, sample) {
  const earlier = history.times.length > 0 && sample.timestamp < history.times[history.times.length - 1];
  // A clock set back makes the old points unusable for the time axis.
  const cap = history.capacity;
  const down = appended(earlier ? [] : history.down, sample.down, cap);
  const up = appended(earlier ? [] : history.up, sample.up, cap);
  const times = appended(earlier ? [] : history.times, sample.timestamp, cap);
  const folded = foldTotals(history.baselines, sample.totals);
  return copyHistory(history, {
    down: down,
    up: up,
    times: times,
    peakDown: Math.max(history.peakDown, sample.down),
    peakUp: Math.max(history.peakUp, sample.up),
    sessionDown: history.sessionDown + folded.addedDown,
    sessionUp: history.sessionUp + folded.addedUp,
    baselines: folded.baselines,
  });
}

// Forgets the counter baselines (the source changed); everything else stays.
export function resetBaselines(history) {
  return copyHistory(history, { baselines: {} });
}

// Changes the capacity and keeps the most recent points.
export function resize(history, capacity) {
  const size = normalizeCapacity(capacity);
  return copyHistory(history, {
    capacity: size,
    down: tail(history.down, size),
    up: tail(history.up, size),
    times: tail(history.times, size),
  });
}
