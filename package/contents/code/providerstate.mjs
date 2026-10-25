// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// State machine of the network provider: a reducer that folds
// source events into a state, and a derive function that turns state plus
// settings into everything the views show. Pure functions without Qt or
// Plasma dependencies, so the module runs inside QML as well as under Node.
// Conservative syntax on purpose (no object spread): the QML engine imports
// this module too.

import { summarize, interfaceList, toList } from "./selection.mjs";

// How many sample intervals without a sample make the data stale.
const STALE_INTERVALS = 3;

// State fields:
//   sample          last accepted sample, null before the first
//   lastSampleAt    time (ms) of the last sample, even an ignored empty one
//   seenInterfaces  true once a sample with at least one interface arrived
//   errorCode       what the UI should explain: "", "sensors-unavailable",
//                   "no-interfaces" or "source-failed"
//   errorDetail     message of the last "source-failed"
//   fallbackNote    why auto mode switched to /proc; outlives samples
export function initialState() {
  return {
    sample: null,
    lastSampleAt: 0,
    seenInterfaces: false,
    errorCode: "",
    errorDetail: "",
    fallbackNote: "",
  };
}

// A copy of `state` with `changes` applied; the input stays untouched.
function withChanges(state, changes) {
  const next = {};
  for (const key of Object.keys(state)) next[key] = state[key];
  for (const key of Object.keys(changes)) next[key] = changes[key];
  return next;
}

function interfacesOf(sample) {
  return sample && sample.interfaces ? sample.interfaces : {};
}

// Events:
//   { type: "source-changed" }          the effective source changed
//   { type: "fallback", reason }        auto mode switches to /proc
//   { type: "unavailable", reason }     a fixed source cannot deliver (yet)
//   { type: "sample", sample, now }     the source delivered a sample
//   { type: "failed", message }         the source reported a read error
// Anything else leaves the state as it is.
export function reduce(state, event) {
  switch (event.type) {
    case "source-changed":
      return initialState();
    case "fallback":
      // The note stays until the next source-changed.
      return withChanges(initialState(), { fallbackNote: event.reason, errorCode: event.reason });
    case "unavailable":
      return withChanges(state, { errorCode: event.reason, errorDetail: "" });
    case "sample": {
      const empty = Object.keys(interfacesOf(event.sample)).length === 0;
      // Empty samples before the first non-empty one mean "no data yet"; the
      // display stays at "-" and an "unavailable" error stays up.
      if (empty && !state.seenInterfaces) {
        return withChanges(state, { lastSampleAt: event.now });
      }
      // A sample ends "failed" and "unavailable" but not the fallback note.
      return withChanges(state, {
        sample: event.sample,
        lastSampleAt: event.now,
        seenInterfaces: state.seenInterfaces || !empty,
        errorCode: state.fallbackNote,
        errorDetail: "",
      });
    }
    case "failed":
      return withChanges(state, { errorCode: "source-failed", errorDetail: String(event.message) });
    default:
      return state;
  }
}

// settings: { mode, selected, now, intervalMs } -> the values for the views.
// Without a sample all numbers are 0 and all texts empty; the error fields
// are passed through either way.
export function derive(state, settings) {
  const view = {
    hasData: state.sample !== null,
    down: 0,
    up: 0,
    online: false,
    stale: false,
    activeSource: "",
    interfaces: [],
    // Present interfaces without hardware that the sample lists besides its
    // interfaces (sensor source only), for the usage totals.
    systemVirtual: [],
    includedCount: 0,
    primaryLabel: "",
    primaryIp: "",
    errorCode: state.errorCode,
    errorDetail: state.errorDetail,
    fallbackNote: state.fallbackNote,
  };
  if (state.sample === null) return view;

  const interfaces = interfacesOf(state.sample);
  const summary = summarize(interfaces, settings.mode, settings.selected);
  view.down = summary.down;
  view.up = summary.up;
  view.online = summary.online;
  view.stale = settings.now - state.lastSampleAt > STALE_INTERVALS * settings.intervalMs;
  view.activeSource = state.sample.source;
  view.interfaces = interfaceList(interfaces, summary.included);
  view.systemVirtual = toList(state.sample.systemVirtual);
  view.includedCount = summary.included.length;
  if (summary.primary !== null) {
    const primary = interfaces[summary.primary];
    view.primaryLabel = primary.label ? primary.label : summary.primary;
    view.primaryIp = primary.ipv4 ? primary.ipv4 : primary.ipv6 ? primary.ipv6 : "";
  }
  return view;
}
