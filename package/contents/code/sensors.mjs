// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Helpers for the ksystemstats source. Pure functions without Qt or
// Plasma dependencies, so the module runs inside QML as well as under Node.

// Per-interface sensors read for every interface, by the last part of the
// sensor ID "network/<interface>/<field>".
export const SENSOR_FIELDS = [
  "download",
  "upload",
  "totalDownload",
  "totalUpload",
  "network",
  "ipv4address",
  "ipv6address",
  "signal",
];

// Changes about once a second. libksysguard does not re-emit unchanged values,
// so network values alone cannot tell "idle" from "stopped"; the system
// uptime can.
export const HEARTBEAT_SENSOR = "os/system/uptime";

const MIN_HEARTBEAT_WINDOW_MS = 3000;
const HEARTBEAT_WINDOW_FACTOR = 3;

// How old the last heartbeat may be before the sensors count as stalled.
export function heartbeatWindowMs(intervalMs) {
  return Math.max(HEARTBEAT_WINDOW_FACTOR * intervalMs, MIN_HEARTBEAT_WINDOW_MS);
}

export function isHeartbeatFresh(lastHeartbeatAt, now, intervalMs) {
  return now - lastHeartbeatAt <= heartbeatWindowMs(intervalMs);
}

const SENSOR_ID = /^network\/([^/]+)\/[^/]+$/;
// Sensor IDs with regex syntax stand for a group of interfaces, not for one.
const REGEX_CHARS = /[()*?[\]|\\]/;
const AGGREGATE_NAME = "all";

// Returns the interface name of a per-interface sensor ID such as
// "network/enp7s0/download", or null for anything else: other categories,
// the "all" aggregate, regex group IDs, IDs without a field part.
export function interfaceFromSensorId(id) {
  if (typeof id !== "string") return null;
  const match = SENSOR_ID.exec(id);
  if (!match) return null;
  const name = match[1];
  if (name === AGGREGATE_NAME || REGEX_CHARS.test(name)) return null;
  return name;
}

// Unique interface names in order of first appearance.
export function interfacesFromSensorIds(ids) {
  const names = [];
  for (const id of ids) {
    const name = interfaceFromSensorId(id);
    if (name !== null && names.indexOf(name) < 0) names.push(name);
  }
  return names;
}

// Sensor values are undefined or NaN until the first reading; anything that is
// not a finite number >= 0 counts as 0.
function toCount(value) {
  const number = Number(value);
  return isFinite(number) && number >= 0 ? number : 0;
}

// True only for a real counter reading, so that a counter at 0 (after a
// reset) can be told from "no reading yet".
function isCounter(value) {
  if (value === null || value === "") return false;
  const number = Number(value);
  return isFinite(number) && number >= 0;
}

function toText(value) {
  return typeof value === "string" ? value : "";
}

// Signal strength in percent; null when absent or not meaningful (wired
// connections report 0).
function toSignal(value) {
  const number = Number(value);
  return isFinite(number) && number > 0 ? number : null;
}

// Builds a sample (the common source contract) from raw sensor values.
// `values` is { [name]: { <SENSOR_FIELDS>: any } }. `physical` lists the
// interfaces backed by hardware; null means that list is unknown, which makes
// every interface count as physical.
export function buildSensorSample(timestamp, values, physical) {
  const interfaces = {};
  for (const name of Object.keys(values)) {
    const raw = values[name] || {};
    const ipv4 = toText(raw.ipv4address);
    const ipv6 = toText(raw.ipv6address);
    const isPhysical = !Array.isArray(physical) || physical.indexOf(name) >= 0;
    interfaces[name] = {
      down: toCount(raw.download),
      up: toCount(raw.upload),
      totalDown: toCount(raw.totalDownload),
      totalUp: toCount(raw.totalUpload),
      totalsKnown: isCounter(raw.totalDownload) && isCounter(raw.totalUpload),
      kind: isPhysical ? "physical" : "virtual",
      online: ipv4 !== "" || ipv6 !== "",
      label: toText(raw.network),
      ipv4: ipv4,
      ipv6: ipv6,
      signal: toSignal(raw.signal),
    };
  }
  return { timestamp: timestamp, source: "sensors", interfaces: interfaces };
}
