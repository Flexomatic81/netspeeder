// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81
// SPDX-FileCopyrightText: 2016 Daniel Faust <hessijames@gmail.com>

// Parser for the /proc/net/dev fallback source. Pure functions
// without Qt or Plasma dependencies, so the module runs inside QML as well as
// under Node. Counters are cumulative bytes since boot.

// One shell run that prints everything the fallback needs, in three sections:
// /proc/net/dev, then "#operstate" followed by one "path:state" line per
// interface, then "#devices" followed by the names of interfaces that are
// backed by hardware (those have a "device" entry in sysfs). The trailing
// `true` keeps the exit status 0 when one of the optional parts fails.
export const PROC_COMMAND =
  "cat /proc/net/dev && echo '#operstate' && grep -H . /sys/class/net/*/operstate; " +
  "echo '#devices'; for d in /sys/class/net/*; do [ -e \"$d/device\" ] && echo \"${d##*/}\"; done; true";

// Only the hardware part of PROC_COMMAND, for refreshing the physical-device
// list on its own.
export const DEVICES_COMMAND =
  "for d in /sys/class/net/*; do [ -e \"$d/device\" ] && echo \"${d##*/}\"; done; true";

const OPERSTATE_MARKER = "#operstate";
const DEVICES_MARKER = "#devices";

// "name:" directly followed by the counters, with or without a space after the
// colon (large counters fill the column and leave none).
const COUNTER_LINE = /^\s*([^:\s]+):\s*(.*)$/;
const OPERSTATE_LINE = /^\/sys\/class\/net\/([^/]+)\/operstate:(.*)$/;
const HEADER_LINE = /^\s*Inter-\|/;

// Receive bytes are the first counter field, transmit bytes the ninth.
const RX_FIELD = 0;
const TX_FIELD = 8;
const MIN_FIELDS = TX_FIELD + 1;

function splitLines(text) {
  return String(text).split(/\r?\n/);
}

// Returns { [name]: { rx, tx } } for every interface line of /proc/net/dev.
// Lines that are not interface lines (the two header lines, anything else) are
// skipped.
export function parseProcNetDev(text) {
  const counters = {};
  for (const line of splitLines(text)) {
    const match = COUNTER_LINE.exec(line);
    if (!match) continue;
    const fields = match[2].trim().split(/\s+/);
    if (fields.length < MIN_FIELDS) continue;
    const rx = Number(fields[RX_FIELD]);
    const tx = Number(fields[TX_FIELD]);
    if (!isFinite(rx) || !isFinite(tx)) continue;
    counters[match[1]] = { rx: rx, tx: tx };
  }
  return counters;
}

// Returns { [name]: state } from the "path:state" lines printed by grep -H.
export function parseOperstate(text) {
  const states = {};
  for (const line of splitLines(text)) {
    const match = OPERSTATE_LINE.exec(line.trim());
    if (match) states[match[1]] = match[2].trim();
  }
  return states;
}

// One interface name per line; trimmed, empty lines dropped, order kept.
export function parseDeviceList(text) {
  const names = [];
  for (const line of splitLines(text)) {
    const name = line.trim();
    if (name !== "") names.push(name);
  }
  return names;
}

// Splits the output of PROC_COMMAND into its three sections and parses them.
// Returns null when no /proc/net/dev header line is found, i.e. when the
// output is not what the command is supposed to print (cat failed, empty
// output).
export function parseProcOutput(text) {
  const sections = { proc: [], operstate: [], devices: [] };
  let current = "proc";
  let sawHeader = false;
  for (const line of splitLines(text)) {
    const trimmed = line.trim();
    if (trimmed === OPERSTATE_MARKER) {
      current = "operstate";
    } else if (trimmed === DEVICES_MARKER) {
      current = "devices";
    } else {
      if (current === "proc" && HEADER_LINE.test(line)) sawHeader = true;
      sections[current].push(line);
    }
  }
  if (!sawHeader) return null;
  return {
    counters: parseProcNetDev(sections.proc.join("\n")),
    operstate: parseOperstate(sections.operstate.join("\n")),
    physical: parseDeviceList(sections.devices.join("\n")),
  };
}

// An interface counts as online when the kernel reports it up. VPN and tunnel
// devices usually report "unknown"; those count as online once they have moved
// any traffic.
function isOnline(state, counter) {
  if (state === "up") return true;
  return state === "unknown" && counter.rx + counter.tx > 0;
}

// Builds a sample (the common source contract) from a parsed snapshot and the
// rates computed for it. Interfaces without an entry in `rates` get 0.
export function toProcSample(timestamp, parsed, rates) {
  const interfaces = {};
  for (const name of Object.keys(parsed.counters)) {
    const counter = parsed.counters[name];
    const rate = rates && Object.prototype.hasOwnProperty.call(rates, name)
      ? rates[name]
      : { down: 0, up: 0 };
    const state = Object.prototype.hasOwnProperty.call(parsed.operstate, name)
      ? parsed.operstate[name]
      : "";
    interfaces[name] = {
      down: rate.down,
      up: rate.up,
      totalDown: counter.rx,
      totalUp: counter.tx,
      kind: parsed.physical.indexOf(name) >= 0 ? "physical" : "virtual",
      online: isOnline(state, counter),
      label: "",
      ipv4: "",
      ipv6: "",
      signal: null,
    };
  }
  return { timestamp: timestamp, source: "proc", interfaces: interfaces };
}
