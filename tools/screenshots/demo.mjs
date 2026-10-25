// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Fixed demo data for the screenshots: a provider with every output the views read, five minutes of traffic
// history and a month of data usage at 85 % of the data cap. Only documentation names and addresses are used
// (192.0.2.0/24, 2001:db8::/32). Every run gives the same data. The QML engine imports this module too, so the
// syntax stays conservative (no object spread).

import { createHistory, pushSample } from "../../package/contents/code/history.mjs";
import { addDays, capState, usageSummary } from "../../package/contents/code/usage.mjs";

const MIB = 1024 * 1024;
const GIB = 1024 * MIB;
const SECONDS = 300;
// 2026-10-24 16:00 UTC; only the distance between the samples matters.
const START_MS = Date.UTC(2026, 9, 24, 16, 0, 0);
const TODAY = { year: 2026, month: 10, day: 24 };
const CAP_GIB = 100;
const WARN_PERCENT = 80;
const CAP_SHARE = 0.85;

// The fonts the screenshots use, the first one available wins.
export const DEMO_FONTS = ["Noto Sans", "DejaVu Sans"];
// The interfaces of the demo, in the order of the list.
export const DEMO_NAMES = ["eth0", "wlan0", "docker0", "tun0"];
// The files the scene writes, in this order.
export const SHOTS = [
  "panel-rows.png",
  "panel-single.png",
  "panel-vertical.png",
  "panel-colors.png",
  "panel-sparkline.png",
  "popup.png",
  "settings-appearance.png",
];

// The first of DEMO_FONTS that is in `families`; "" when none is.
export function pickFont(families) {
  const found = DEMO_FONTS.filter((name) => families.indexOf(name) >= 0);
  return found.length > 0 ? found[0] : "";
}

// A bump of height 1 around `center`, `width` seconds wide.
function bump(i, center, width) {
  const d = (i - center) / width;
  return Math.exp(-d * d);
}

// A fixed sequence of numbers in [-1, 1) (a linear congruential generator).
function noise(count, seed) {
  const out = [];
  let state = seed;
  for (let i = 0; i < count; i++) {
    state = (state * 1103515245 + 12345) % 2147483648;
    out.push((state / 2147483648) * 2 - 1);
  }
  return out;
}

// Download and upload end at speeds with as many digits (about 123 and 12.3 MiB/s), so the panel shows no gap
// between them, and in different bands of the color thresholds.
function downRate(i, jitter) {
  const base = 14 + 7 * Math.sin(i / 23) + 4.5 * Math.sin(i / 7.3) + 2.5 * jitter;
  const spikes = 176 * bump(i, 95, 9) + 80 * bump(i, 190, 14) + 106 * bump(i, SECONDS - 1, 18);
  return Math.round(Math.max(0.5, base + spikes) * MIB);
}

function upRate(i, jitter) {
  const base = 1.9 + 0.8 * Math.sin(i / 17) + 0.4 * jitter;
  const spikes = 20 * bump(i, 140, 10) + 10.9 * bump(i, SECONDS - 1, 20);
  return Math.round(Math.max(0.1, base + spikes) * MIB);
}

// Five minutes at one sample a second, with the counters of eth0 for the session totals.
export function demoHistory() {
  const downJitter = noise(SECONDS, 7);
  const upJitter = noise(SECONDS, 11);
  let history = createHistory(900);
  let counterDown = 18 * GIB;
  let counterUp = 2 * GIB;
  for (let i = 0; i < SECONDS; i++) {
    const down = downRate(i, downJitter[i]);
    const up = upRate(i, upJitter[i]);
    counterDown += down;
    counterUp += up;
    history = pushSample(history, {
      timestamp: START_MS + i * 1000,
      down: down,
      up: up,
      totals: { eth0: { down: counterDown, up: counterUp, known: true } },
    });
  }
  return history;
}

function row(name, fields) {
  const entry = {
    name: name,
    label: "",
    kind: "physical",
    included: true,
    online: true,
    down: 0,
    up: 0,
    totalDown: 0,
    totalUp: 0,
    totalsKnown: true,
    ipv4: "",
    ipv6: "",
    signal: null,
  };
  for (const key of Object.keys(fields)) entry[key] = fields[key];
  return entry;
}

// The rows of the interface list; the two physical ones share the current speed.
function demoInterfaces(down, up) {
  const ethDown = Math.round(down * 0.9);
  const ethUp = Math.round(up * 0.9);
  return [
    row("eth0", {
      label: "Wired connection",
      down: ethDown,
      up: ethUp,
      totalDown: 18.4 * GIB,
      totalUp: 2.1 * GIB,
      ipv4: "192.0.2.10",
      ipv6: "2001:db8::10",
    }),
    row("wlan0", {
      label: "Wireless connection",
      down: down - ethDown,
      up: up - ethUp,
      totalDown: 1.2 * GIB,
      totalUp: 0.3 * GIB,
      ipv4: "192.0.2.20",
      signal: 74,
    }),
    row("docker0", {
      kind: "virtual",
      included: false,
      down: 2400,
      up: 1800,
      totalDown: 310 * MIB,
      totalUp: 95 * MIB,
      ipv4: "192.0.2.65",
    }),
    row("tun0", {
      kind: "virtual",
      included: false,
      down: Math.round(down * 0.2),
      up: Math.round(up * 0.3),
      totalDown: 2.6 * GIB,
      totalUp: 0.8 * GIB,
      ipv4: "192.0.2.97",
      ipv6: "2001:db8:0:1::97",
    }),
  ];
}

// Every output of the network provider (see NetworkProvider.qml).
export function demoProvider() {
  const history = demoHistory();
  const down = history.down[history.down.length - 1];
  const up = history.up[history.up.length - 1];
  return {
    hasData: true,
    down: down,
    up: up,
    online: true,
    stale: false,
    activeSource: "sensors",
    primaryLabel: "Wired connection",
    primaryIp: "192.0.2.10",
    interfaces: demoInterfaces(down, up),
    includedCount: 2,
    history: history,
    errorCode: "",
    errorDetail: "",
    fallbackNote: "",
  };
}

// Daily traffic of one interface from `first` to today: `share` of a day's total, which varies by weekday.
function demoDays(first, share, dailyBytes) {
  const days = [];
  let n = 0;
  for (let key = first; key <= "2026-10-24"; key = addDays(key, 1)) {
    const weight = [1.1, 0.9, 1.0, 0.8, 1.2, 1.3, 0.7][n % 7];
    const total = Math.round(dailyBytes * share * weight);
    days.push({ date: key, rx: Math.round(total * 0.88), tx: total - Math.round(total * 0.88) });
    n++;
  }
  return days;
}

// The days of this period of all interfaces add up to exactly `target`: the difference goes to today on eth0.
function settle(interfaces, target) {
  let sum = 0;
  for (const name of Object.keys(interfaces)) {
    for (const day of interfaces[name].days) {
      if (day.date >= "2026-10-01") sum += day.rx + day.tx;
    }
  }
  const eth = interfaces.eth0.days;
  eth[eth.length - 1].rx += target - sum;
}

// The usage input of the popup (see UsageModel.view): billing day 1, a cap of 100 GiB, 85 % of it used.
export function demoUsage() {
  const target = Math.round(CAP_SHARE * CAP_GIB * GIB);
  const daily = target / 24;
  const interfaces = {
    eth0: { created: "2026-08-01", updated: "2026-10-24T18:00", days: demoDays("2026-09-01", 0.85, daily) },
    wlan0: { created: "2026-08-01", updated: "2026-10-24T18:00", days: demoDays("2026-09-01", 0.15, daily) },
  };
  settle(interfaces, target);
  const summary = usageSummary({ status: "ok", version: "2", interfaces: interfaces }, ["eth0", "wlan0"], TODAY, 1);
  const state = capState(summary.current.total, CAP_GIB, WARN_PERCENT);
  return {
    summary: summary,
    status: "ok",
    detail: "",
    cap: { enabled: true, percent: state.percent, level: state.level, capBytes: CAP_GIB * GIB },
    lastUpdated: "2026-10-24T18:00",
    outdated: false,
  };
}
