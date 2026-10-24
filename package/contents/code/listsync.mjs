// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Brings a list model in line with a list of wanted names by single removals
// and insertions. Rows that stay are never touched, so the delegates behind
// them keep their state; a wholesale rebuild would lose it. Pure function
// without Qt or Plasma dependencies: the caller applies the operations to its
// ListModel in the order given.

// The operations that turn `current` (names, one per row) into the names in
// `wanted`:
//   { op: "remove", index }        remove the row at `index`
//   { op: "insert", index, name }  insert a row for `name` at `index`
// Indexes refer to the list as it is after the operations before. All
// removals come first, from the highest index down, so the indexes of the
// rows still to remove do not move.
//
// Without `compare`, the rows that stay keep their order and new names are
// appended in the order of `wanted`. With `compare` (a sort order like
// compareNames), `current` must be sorted already; every new name goes to the
// place that keeps the list sorted. A name that is wanted several times is
// handled once.
export function syncOps(current, wanted, compare) {
  const ops = [];
  const wantedSet = new Set(wanted);
  const rows = [];
  for (let index = current.length - 1; index >= 0; index--) {
    if (wantedSet.has(current[index])) continue;
    ops.push({ op: "remove", index: index });
  }
  for (const name of current) {
    if (wantedSet.has(name)) rows.push(name);
  }
  for (const name of wantedSet) {
    if (rows.indexOf(name) >= 0) continue;
    const index = compare ? insertionIndex(rows, name, compare) : rows.length;
    rows.splice(index, 0, name);
    ops.push({ op: "insert", index: index, name: name });
  }
  return ops;
}

// The first place whose row sorts after `name`, or the end of the list.
function insertionIndex(rows, name, compare) {
  let index = 0;
  while (index < rows.length && compare(rows[index], name) <= 0) index++;
  return index;
}
