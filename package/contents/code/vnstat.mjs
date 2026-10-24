// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Parser for the daily traffic that vnStat keeps (`vnstat --json d`). Pure
// functions without Qt or Plasma dependencies, so the module runs inside QML
// as well as under Node. Traffic values are bytes.

// 62 days cover the current and the previous month in full.
export const VNSTAT_COMMAND = "vnstat --json d 62";

// Only this JSON layout is understood.
const SUPPORTED_JSON_VERSION = "2";

function pad(n, width) {
  let s = String(n);
  while (s.length < width) {
    s = "0" + s;
  }
  return s;
}

function isInt(v) {
  return typeof v === "number" && Number.isInteger(v);
}

function inRange(v, min, max) {
  return isInt(v) && v >= min && v <= max;
}

// { year, month, day } -> "YYYY-MM-DD", or "" when a part is missing or out
// of range.
export function dateKey(date) {
  if (!date || !inRange(date.year, 1, 9999) || !inRange(date.month, 1, 12) || !inRange(date.day, 1, 31)) {
    return "";
  }
  return pad(date.year, 4) + "-" + pad(date.month, 2) + "-" + pad(date.day, 2);
}

function bytes(v) {
  return typeof v === "number" && Number.isFinite(v) && v >= 0 ? v : 0;
}

function parseDays(traffic) {
  const list = traffic && Array.isArray(traffic.day) ? traffic.day : [];
  const days = [];
  for (const entry of list) {
    const date = entry ? dateKey(entry.date) : "";
    if (date !== "") {
      days.push({ date: date, rx: bytes(entry.rx), tx: bytes(entry.tx) });
    }
  }
  days.sort((a, b) => (a.date < b.date ? -1 : a.date > b.date ? 1 : 0));
  return days;
}

// "YYYY-MM-DDTHH:MM" from { date, time: { hour, minute } }, "" when absent.
function updatedKey(updated) {
  const date = updated ? dateKey(updated.date) : "";
  const time = updated ? updated.time : null;
  if (date === "" || !time || !inRange(time.hour, 0, 23) || !inRange(time.minute, 0, 59)) {
    return "";
  }
  return date + "T" + pad(time.hour, 2) + ":" + pad(time.minute, 2);
}

function parseInterface(iface) {
  return {
    created: iface.created ? dateKey(iface.created.date) : "",
    updated: updatedKey(iface.updated),
    days: parseDays(iface.traffic),
  };
}

function parseJson(text) {
  try {
    const data = JSON.parse(String(text));
    return data !== null && typeof data === "object" && !Array.isArray(data) ? data : null;
  } catch (error) {
    // Not JSON (vnstat missing, database error text); anything else is a real fault.
    if (error instanceof SyntaxError) {
      return null;
    }
    throw error;
  }
}

// Returns { status, version, interfaces: { [name]: { created, updated, days } } }
// with status "ok", "unsupported" (other JSON version) or "invalid".
export function parseVnstat(stdout) {
  const data = parseJson(stdout);
  if (data === null || !Array.isArray(data.interfaces)) {
    return { status: "invalid", version: "", interfaces: {} };
  }
  const version = data.jsonversion === undefined ? "" : String(data.jsonversion);
  if (version !== SUPPORTED_JSON_VERSION) {
    return { status: "unsupported", version: version, interfaces: {} };
  }
  const interfaces = {};
  for (const iface of data.interfaces) {
    if (iface && typeof iface.name === "string" && iface.name !== "") {
      interfaces[iface.name] = parseInterface(iface);
    }
  }
  return { status: "ok", version: version, interfaces: interfaces };
}
