// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Data usage from the vnStat daily traffic: billing periods, totals, whether a
// period is fully covered, which interfaces count, data cap levels and when a
// cap notification is due. Pure functions without Qt or Plasma dependencies,
// so the module runs inside QML as well as under Node. Dates are plain
// "YYYY-MM-DD" keys and all calendar arithmetic is done by hand, so no time
// zone can shift a day. Traffic values are bytes.

import { compareNames, toList } from "./selection.mjs";
import { dateKey } from "./vnstat.mjs";

const LOOPBACK = "lo";
const DEFAULT_BILLING_DAY = 1;
const MAX_BILLING_DAY = 28;
const DEFAULT_WARN_PERCENT = 80;
const DEFAULT_MAX_MINUTES = 60;
const GIB = 1024 * 1024 * 1024;
const MINUTES_PER_DAY = 24 * 60;

const KEY_PATTERN = /^(\d{4})-(\d{2})-(\d{2})$/;
const STAMP_PATTERN = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$/;

function isIntIn(v, min, max) {
  return typeof v === "number" && Number.isInteger(v) && v >= min && v <= max;
}

function isLeapYear(year) {
  return (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0;
}

function daysInMonth(year, month) {
  const lengths = [31, isLeapYear(year) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  return lengths[month - 1];
}

function isValidDate(date) {
  return (
    date !== null &&
    typeof date === "object" &&
    isIntIn(date.year, 1, 9999) &&
    isIntIn(date.month, 1, 12) &&
    isIntIn(date.day, 1, daysInMonth(date.year, date.month))
  );
}

// "YYYY-MM-DD" -> { year, month, day }, or null when it is not a real date.
function parseKey(key) {
  const m = KEY_PATTERN.exec(String(key));
  if (m === null) return null;
  const date = { year: Number(m[1]), month: Number(m[2]), day: Number(m[3]) };
  return isValidDate(date) ? date : null;
}

// Days since 0000-03-01 in the proleptic Gregorian calendar, and back.
function dayNumber(date) {
  const y = date.month <= 2 ? date.year - 1 : date.year;
  const era = Math.floor(y / 400);
  const yoe = y - era * 400;
  const mp = (date.month + 9) % 12;
  const doy = Math.floor((153 * mp + 2) / 5) + date.day - 1;
  const doe = yoe * 365 + Math.floor(yoe / 4) - Math.floor(yoe / 100) + doy;
  return era * 146097 + doe;
}

function fromDayNumber(n) {
  const era = Math.floor(n / 146097);
  const doe = n - era * 146097;
  const yoe = Math.floor((doe - Math.floor(doe / 1460) + Math.floor(doe / 36524) - Math.floor(doe / 146096)) / 365);
  const doy = doe - (365 * yoe + Math.floor(yoe / 4) - Math.floor(yoe / 100));
  const mp = Math.floor((5 * doy + 2) / 153);
  const day = doy - Math.floor((153 * mp + 2) / 5) + 1;
  const month = mp < 10 ? mp + 3 : mp - 9;
  return { year: era * 400 + yoe + (month <= 2 ? 1 : 0), month: month, day: day };
}

// Shifts a "YYYY-MM-DD" key by n days; "" for an invalid key or step.
export function addDays(key, n) {
  const date = parseKey(key);
  if (date === null || !Number.isInteger(n)) return "";
  return dateKey(fromDayNumber(dayNumber(date) + n));
}

function billingDayOrDefault(billingDay) {
  return isIntIn(billingDay, 1, MAX_BILLING_DAY) ? billingDay : DEFAULT_BILLING_DAY;
}

// The month before (delta -1) or after (delta 1) { year, month }.
function shiftMonth(year, month, delta) {
  const index = year * 12 + (month - 1) + delta;
  return { year: Math.floor(index / 12), month: (index % 12) + 1 };
}

// The billing period that contains `today`: it starts on the last billing day
// up to today and ends the day before the next one starts (inclusive).
export function periodFor(today, billingDay) {
  const day = billingDayOrDefault(billingDay);
  const first = today.day >= day ? { year: today.year, month: today.month } : shiftMonth(today.year, today.month, -1);
  const next = shiftMonth(first.year, first.month, 1);
  return {
    start: dateKey({ year: first.year, month: first.month, day: day }),
    end: addDays(dateKey({ year: next.year, month: next.month, day: day }), -1),
  };
}

// The period right before `period`. Billing days never exceed 28, so the
// same day exists in every month.
export function previousPeriod(period) {
  const start = period ? parseKey(period.start) : null;
  if (start === null) return { start: "", end: "" };
  const before = shiftMonth(start.year, start.month, -1);
  return {
    start: dateKey({ year: before.year, month: before.month, day: start.day }),
    end: addDays(period.start, -1),
  };
}

function usage(down, up) {
  return { down: down, up: up, total: down + up };
}

function periodUsage(sums, period, complete) {
  return {
    down: sums.down,
    up: sums.up,
    total: sums.down + sums.up,
    start: period.start,
    end: period.end,
    complete: complete,
  };
}

function summaryOf(status, periods, sums, counted, untracked) {
  return {
    status: status,
    today: usage(sums.today.down, sums.today.up),
    yesterday: usage(sums.yesterday.down, sums.yesterday.up),
    current: periodUsage(sums.current, periods.current, periods.currentComplete),
    previous: periodUsage(sums.previous, periods.previous, periods.previousComplete),
    counted: counted,
    untracked: untracked,
  };
}

function zeroSums() {
  return {
    today: { down: 0, up: 0 },
    yesterday: { down: 0, up: 0 },
    current: { down: 0, up: 0 },
    previous: { down: 0, up: 0 },
  };
}

function periodsFor(today, billingDay) {
  const current = periodFor(today, billingDay);
  return { current: current, previous: previousPeriod(current), currentComplete: false, previousComplete: false };
}

function emptyResult(status, today, billingDay) {
  return summaryOf(status, periodsFor(today, billingDay), zeroSums(), [], []);
}

// The summary shown before the first vnStat result arrived.
export function emptySummary(today, billingDay) {
  return emptyResult("none", today, billingDay);
}

function inPeriod(date, period) {
  return date >= period.start && date <= period.end;
}

function addTo(sum, entry) {
  sum.down += entry.rx;
  sum.up += entry.tx;
}

function addDay(sums, entry, keys) {
  if (entry.date === keys.today) addTo(sums.today, entry);
  if (entry.date === keys.yesterday) addTo(sums.yesterday, entry);
  if (inPeriod(entry.date, keys.current)) addTo(sums.current, entry);
  if (inPeriod(entry.date, keys.previous)) addTo(sums.previous, entry);
}

function daysOf(iface) {
  return Array.isArray(iface.days) ? iface.days : [];
}

// Deliberately cautious: the start is covered only when vnStat knew the
// interface by then and still delivers a day up to the start. Otherwise a
// shorter retention or a cut list may have dropped the beginning. An
// interface without any traffic before the period is reported incomplete.
function coversStart(iface, start) {
  if (!iface.created || iface.created > start) return false;
  return daysOf(iface).some((entry) => entry.date <= start);
}

function isComplete(ifaces, start) {
  return ifaces.length > 0 && ifaces.every((iface) => coversStart(iface, start));
}

function uniqueSorted(names) {
  return names.filter((name, i) => names.indexOf(name) === i).sort(compareNames);
}

// Sums the daily traffic of the `names` vnStat knows, returned in `counted`;
// the other names are returned in `untracked`. `parsed` is the parseVnstat result or null before
// the first run.
export function usageSummary(parsed, names, today, billingDay) {
  if (parsed === null || parsed === undefined) return emptyResult("none", today, billingDay);
  if (parsed.status !== "ok") return emptyResult(parsed.status, today, billingDay);
  const wanted = uniqueSorted(toList(names));
  const counted = wanted.filter((name) => Object.prototype.hasOwnProperty.call(parsed.interfaces, name));
  const untracked = wanted.filter((name) => counted.indexOf(name) < 0);
  const ifaces = counted.map((name) => parsed.interfaces[name]);
  const periods = periodsFor(today, billingDay);
  const todayKey = dateKey(today);
  const keys = {
    today: todayKey,
    yesterday: addDays(todayKey, -1),
    current: periods.current,
    previous: periods.previous,
  };
  const sums = zeroSums();
  for (const iface of ifaces) {
    for (const entry of daysOf(iface)) addDay(sums, entry, keys);
  }
  periods.currentComplete = isComplete(ifaces, periods.current.start);
  periods.previousComplete = isComplete(ifaces, periods.previous.start);
  return summaryOf("ok", periods, sums, counted, untracked);
}

// The usage of today for the tooltip: null unless the usage is current (`ok`)
// and vnStat tracks at least one of the interfaces that count, so an empty
// selection does not read as a day without traffic.
export function todayUsage(ok, summary) {
  if (!ok || !summary || summary.status !== "ok") return null;
  return toList(summary.counted).length > 0 ? summary.today : null;
}

function liveRows(live) {
  return toList(live).filter((row) => row && typeof row.name === "string");
}

function liveVirtual(live) {
  return liveRows(live)
    .filter((row) => row.kind === "virtual")
    .map((row) => row.name);
}

// The interfaces whose usage counts. "manual": the configured names, present
// or not. "auto": every name vnStat knows except those the provider currently
// reports as virtual and those once seen as virtual (`knownVirtual`, see
// nextKnownVirtual), plus the live interfaces in the sum. The loopback device
// never counts. Sorted by compareNames, without duplicates.
export function usageNames(mode, selected, live, known, knownVirtual) {
  let names;
  if (mode === "manual") {
    names = toList(selected);
  } else {
    const excluded = liveVirtual(live).concat(toList(knownVirtual));
    const included = liveRows(live)
      .filter((row) => row.included)
      .map((row) => row.name);
    names = toList(known)
      .filter((name) => excluded.indexOf(name) < 0)
      .concat(included);
  }
  return uniqueSorted(names.filter((name) => name !== LOOPBACK));
}

function sameNames(a, b) {
  return a.length === b.length && a.every((name, i) => name === b[i]);
}

// The interfaces once seen as virtual, so that automatic mode leaves them out
// even while they are absent (a VPN tunnel after a disconnect). Adds the
// names the provider reports as virtual now and drops absent names vnStat no
// longer knows (`vnstatKnown`; null before the first vnStat result, then
// nothing is dropped), so the list cannot grow forever. Returns the new
// sorted list, or null when it is the same set as `previous`.
export function nextKnownVirtual(previous, live, vnstatKnown) {
  const before = uniqueSorted(toList(previous).filter((name) => typeof name === "string" && name !== ""));
  const current = liveVirtual(live);
  const kept =
    vnstatKnown === null || vnstatKnown === undefined
      ? before
      : before.filter((name) => toList(vnstatKnown).indexOf(name) >= 0);
  const next = uniqueSorted(kept.concat(current).filter((name) => name !== LOOPBACK));
  const stored = uniqueSorted(toList(previous));
  return sameNames(next, stored) ? null : next;
}

const KEY_SEPARATOR = "\n";

// usageNames as one string ("eth0\nwlan0"). A string only counts as changed
// when its value changes, so a new interfaces array per sample with the same
// names leaves the usage sums alone.
export function namesKey(mode, selected, live, known, knownVirtual) {
  return usageNames(mode, selected, live, known, knownVirtual).join(KEY_SEPARATOR);
}

// The names of a namesKey; [] for an empty key.
export function namesFromKey(key) {
  return typeof key === "string" && key !== "" ? key.split(KEY_SEPARATOR) : [];
}

function isPositiveFinite(v) {
  return typeof v === "number" && Number.isFinite(v) && v > 0;
}

// Share of the data cap used. level 2 from 100 %, 1 from `warnPercent`
// (whole number 1..99, else 80), else 0. The level follows the exact share;
// `percent` is rounded down to one decimal for display, so it never shows a
// threshold the level has not reached (99.96 % reads 99.9, not 100).
export function capState(totalBytes, capGiB, warnPercent) {
  if (!isPositiveFinite(capGiB)) return { percent: 0, level: 0 };
  const total = isPositiveFinite(totalBytes) ? totalBytes : 0;
  const warn = isIntIn(warnPercent, 1, 99) ? warnPercent : DEFAULT_WARN_PERCENT;
  const exact = (total / (capGiB * GIB)) * 100;
  const level = exact >= 100 ? 2 : exact >= warn ? 1 : 0;
  return { percent: Math.floor(exact * 10) / 10, level: level };
}

// The stored { cycle, level } in a clean shape: the cycle as a string, the
// level as a whole number 0..2, else 0.
function storedLevel(notified) {
  const known = notified !== null && typeof notified === "object";
  const cycle = known && notified.cycle !== null && notified.cycle !== undefined ? String(notified.cycle) : "";
  const level = known && isIntIn(notified.level, 0, 2) ? notified.level : 0;
  return { cycle: cycle, level: level };
}

// Whether a cap notification is due. `cycle` is the start of the current
// period and `notified` the last stored { cycle, level }. Only the highest
// newly reached level is reported, once per period; a level that drops in
// the same period (cap raised) keeps the stored one, so a renewed rise is
// not reported again. While inactive nothing is reported and the stored
// value is kept as it was.
export function capNotification(level, cycle, notified, active) {
  const stored = storedLevel(notified);
  if (!active) return { notify: 0, store: stored };
  const before = stored.cycle === cycle ? stored.level : 0;
  const store = { cycle: cycle, level: Math.max(before, level) };
  return { notify: level > before ? level : 0, store: store };
}

// capNotification for the widget's settings and state. Nothing is decided
// before the interfaces that count are known (`namesReady`): until then
// automatic mode cannot leave out the virtual ones. With notifications off
// the level is still stored, so turning them on later does not report a
// level reached before.
export function capAction(input) {
  const active = Boolean(input.usageEnabled && input.dataCapEnabled && input.freshOk && input.namesReady);
  const result = capNotification(input.level, input.cycle, input.notified, active);
  return input.capNotify ? result : { notify: 0, store: result.store };
}

function minuteOf(date, hour, minute) {
  return dayNumber(date) * MINUTES_PER_DAY + hour * 60 + minute;
}

// "YYYY-MM-DDTHH:MM" -> { year, month, day, hour, minute }, or null.
function parseStamp(stamp) {
  const m = STAMP_PATTERN.exec(String(stamp));
  if (m === null) return null;
  const parts = {
    year: Number(m[1]),
    month: Number(m[2]),
    day: Number(m[3]),
    hour: Number(m[4]),
    minute: Number(m[5]),
  };
  return isValidDate(parts) && parts.hour <= 23 && parts.minute <= 59 ? parts : null;
}

function stampMinutes(stamp) {
  const parts = parseStamp(stamp);
  return parts === null ? null : minuteOf(parts, parts.hour, parts.minute);
}

// A day key ("YYYY-MM-DD", at 00:00) or an update stamp
// ("YYYY-MM-DDTHH:MM") as { year, month, day, hour, minute }, so the views
// can build a local Date for display; null for anything else.
export function dateParts(text) {
  const day = parseKey(text);
  return day !== null ? { year: day.year, month: day.month, day: day.day, hour: 0, minute: 0 } : parseStamp(text);
}

// The local calendar day and time of a Date as { year, month, day, hour,
// minute } (what usageSummary takes as today and isOutdated as now); null
// for anything but a valid Date.
export function localNow(date) {
  if (!(date instanceof Date) || Number.isNaN(date.getTime())) return null;
  return {
    year: date.getFullYear(),
    month: date.getMonth() + 1,
    day: date.getDate(),
    hour: date.getHours(),
    minute: date.getMinutes(),
  };
}

function nowMinutes(now) {
  if (!isValidDate(now) || !isIntIn(now.hour, 0, 23) || !isIntIn(now.minute, 0, 59)) return null;
  return minuteOf(now, now.hour, now.minute);
}

// True when `lastUpdated` ("YYYY-MM-DDTHH:MM", local time) lies more than
// `maxMinutes` before `now`. An empty or invalid stamp is outdated; one in
// the future is not. Both are local wall-clock times, so around a daylight
// saving switch the result can be off by up to an hour; that is acceptable
// for a one-hour freshness hint.
export function isOutdated(lastUpdated, now, maxMinutes) {
  const limit = isIntIn(maxMinutes, 0, Number.MAX_SAFE_INTEGER) ? maxMinutes : DEFAULT_MAX_MINUTES;
  const last = stampMinutes(lastUpdated);
  const current = nowMinutes(now);
  if (last === null || current === null) return true;
  return current - last > limit;
}
