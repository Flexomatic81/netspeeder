// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Idleness tracking and the auto-hide decision. Pure functions without Qt or
// Plasma dependencies, so the module runs inside QML as well as under Node.
// Conservative syntax on purpose: the QML engine imports this module too.

const DEFAULT_THRESHOLD = 1024;
const DEFAULT_SECONDS = 30;
const MIN_SECONDS = 5;
const MAX_SECONDS = 3600;

function validThreshold(value) {
  const n = Number(value);
  return typeof value === "number" && isFinite(n) && n >= 0 && Math.floor(n) === n ? n : DEFAULT_THRESHOLD;
}

function validSeconds(value) {
  const ok = typeof value === "number" && Math.floor(value) === value && value >= MIN_SECONDS && value <= MAX_SECONDS;
  return ok ? value : DEFAULT_SECONDS;
}

function validNumber(value) {
  return typeof value === "number" && isFinite(value);
}

// Where the quiet period began: the old start, a fresh one after a clock that
// went back, or `now` when there was none.
function quietStart(state, now) {
  const since = state ? state.belowSince : null;
  const last = state ? state.lastNow : null;
  if (!validNumber(since) || (validNumber(last) && now < last)) return now;
  return since;
}

// Advances the idle tracker. `total` is the current traffic in bytes per
// second; an invalid total (no data) counts as activity. The widget is idle
// once the traffic stayed below `threshold` for `seconds`. Only timestamps
// matter, so the sampling interval has no influence.
export function nextIdle(state, input) {
  const now = input.now;
  const threshold = validThreshold(input.threshold);
  const seconds = validSeconds(input.seconds);
  const active = !validNumber(input.total) || input.total >= threshold;
  if (!validNumber(now)) {
    return { belowSince: null, lastNow: state && validNumber(state.lastNow) ? state.lastNow : 0, idle: false };
  }
  if (active) return { belowSince: null, lastNow: now, idle: false };
  const belowSince = quietStart(state, now);
  return { belowSince: belowSince, lastNow: now, idle: now - belowSince >= seconds * 1000 };
}

// Stale data is no reason to hide: a frozen source keeps showing its dimmed
// values instead of vanishing like quiet traffic.
function hideReason(mode, view) {
  if (!view.hasData || view.stale) return false;
  if (mode === "offline") return !view.online;
  if (mode === "idle") return !view.online || view.idle;
  return false;
}

// "shown", "hidden" or "placeholder" (a visible stand-in while editing).
export function autoHideState(mode, view, context) {
  if (!hideReason(mode, view)) return "shown";
  if (context.expanded) return "shown";
  return context.editMode ? "placeholder" : "hidden";
}
