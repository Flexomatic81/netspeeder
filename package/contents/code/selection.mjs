// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Interface selection and summing. Pure functions without Qt or
// Plasma dependencies, so the module runs inside QML as well as under Node.
// Interfaces are the { [name]: { down, up, kind, online, ... } } map of a
// sample; rates are bytes per second.

const LOOPBACK = "lo";

// Orders names case-insensitively and breaks ties by the original spelling.
// Deliberately not localeCompare: that sorts differently in the QML engine
// and in Node, which would make the displayed order depend on the runtime.
export function compareNames(a, b) {
  const lowerA = a.toLowerCase();
  const lowerB = b.toLowerCase();
  if (lowerA < lowerB) return -1;
  if (lowerA > lowerB) return 1;
  if (a < b) return -1;
  if (a > b) return 1;
  return 0;
}

// Config values reach the QML side as array-like sequence objects; this
// copies anything list-shaped into a plain array and everything else to [].
function toList(value) {
  if (value === null || value === undefined || typeof value === "string") return [];
  if (typeof value.length !== "number") return [];
  const list = [];
  for (let i = 0; i < value.length; i++) list.push(value[i]);
  return list;
}

function finiteOrZero(value) {
  return typeof value === "number" && isFinite(value) ? value : 0;
}

// Names of all interfaces that may take part in a sum, in display order.
// The loopback device never does.
function candidateNames(interfaces) {
  return Object.keys(interfaces)
    .filter((name) => name !== LOOPBACK)
    .sort(compareNames);
}

// The interface that stands for the sum in the UI: the busiest one, else the
// first one that is online, else the first one. `included` is sorted.
function pickPrimary(interfaces, included) {
  let busiest = null;
  let busiestRate = 0;
  for (const name of included) {
    const rate = finiteOrZero(interfaces[name].down) + finiteOrZero(interfaces[name].up);
    if (rate > busiestRate) {
      busiest = name;
      busiestRate = rate;
    }
  }
  if (busiest !== null) return busiest;
  for (const name of included) {
    if (interfaces[name].online === true) return name;
  }
  return included.length > 0 ? included[0] : null;
}

// Sums the interfaces chosen by `mode`:
//   "manual"  the names in `selected`, whatever their kind
//   otherwise all "physical" interfaces (so VPN traffic is not counted twice)
// Names in `selected` that are not in `interfaces` are ignored; if none is
// left the result is an empty, offline sum. `included` is sorted by
// compareNames.
export function summarize(interfaces, mode, selected) {
  const all = interfaces || {};
  const chosen = toList(selected);
  const manual = mode === "manual";
  const included = candidateNames(all).filter((name) =>
    manual ? chosen.indexOf(name) >= 0 : all[name].kind === "physical",
  );

  let down = 0;
  let up = 0;
  let online = false;
  for (const name of included) {
    down += finiteOrZero(all[name].down);
    up += finiteOrZero(all[name].up);
    if (all[name].online === true) online = true;
  }
  return { down: down, up: up, online: online, included: included, primary: pickPrimary(all, included) };
}

// The interfaces for the popup list: every interface but the loopback, each
// with its sample fields plus `name` and `included`. Interfaces that are part
// of the sum come first; both groups are sorted by compareNames.
export function interfaceList(interfaces, included) {
  const all = interfaces || {};
  const members = toList(included);
  const rows = [];
  for (const name of candidateNames(all)) {
    const row = {};
    for (const field of Object.keys(all[name])) row[field] = all[name][field];
    row.name = name;
    row.included = members.indexOf(name) >= 0;
    rows.push(row);
  }
  // Array.prototype.sort is not guaranteed stable on every engine; the name
  // comparison makes the order total, so stability does not matter.
  rows.sort((x, y) => {
    if (x.included !== y.included) return x.included ? -1 : 1;
    return compareNames(x.name, y.name);
  });
  return rows;
}
