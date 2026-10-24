// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// The screenshot tool: its demo data stays generic and consistent, and the image check reads PNG files and finds
// missing images, path metadata and a chart area of one color.

import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import zlib from "node:zlib";
import {
  DEMO_FONTS,
  DEMO_NAMES,
  SHOTS,
  demoHistory,
  demoProvider,
  demoUsage,
  pickFont,
} from "../tools/screenshots/demo.mjs";
import {
  checkImages,
  chartProblem,
  metadataProblems,
  parseChartLine,
  readPng,
} from "../tools/screenshots/check-images.mjs";

// Every string inside a value, also in nested arrays and objects.
function strings(value, found = []) {
  if (typeof value === "string") found.push(value);
  else if (value !== null && typeof value === "object") Object.values(value).forEach((v) => strings(v, found));
  return found;
}

test("the demo data names only documentation interfaces and addresses", () => {
  const provider = demoProvider();
  assert.deepEqual(
    provider.interfaces.map((i) => i.name),
    DEMO_NAMES,
  );
  assert.deepEqual(DEMO_NAMES, ["eth0", "wlan0", "docker0", "tun0"]);
  for (const entry of provider.interfaces) {
    assert.ok(entry.ipv4 === "" || entry.ipv4.startsWith("192.0.2."), entry.ipv4);
    assert.ok(entry.ipv6 === "" || entry.ipv6.startsWith("2001:db8:"), entry.ipv6);
  }
  assert.equal(provider.primaryLabel, "Wired connection");
  assert.equal(provider.primaryIp, "192.0.2.10");
  const all = strings([provider, demoUsage()]);
  assert.ok(!all.some((s) => s.startsWith("/")), "no paths");
  assert.doesNotMatch(all.join(" "), /veth|enp|wlp|192\.168\.|10\.\d+\.|fe80:/);
});

test("the demo provider has every output of the provider, with data", () => {
  const provider = demoProvider();
  for (const key of [
    "hasData",
    "down",
    "up",
    "online",
    "stale",
    "activeSource",
    "primaryLabel",
    "primaryIp",
    "interfaces",
    "includedCount",
    "history",
    "errorCode",
    "errorDetail",
    "fallbackNote",
  ]) {
    assert.ok(Object.prototype.hasOwnProperty.call(provider, key), key);
  }
  assert.equal(provider.hasData, true);
  assert.equal(provider.online, true);
  assert.equal(provider.stale, false);
  assert.equal(provider.errorCode, "");
  assert.equal(provider.includedCount, 2);
  const wlan = provider.interfaces.find((i) => i.name === "wlan0");
  assert.equal(typeof wlan.signal, "number");
  assert.deepEqual(
    provider.interfaces.filter((i) => i.kind === "virtual").map((i) => i.name),
    ["docker0", "tun0"],
  );
});

test("the demo history covers five minutes and ends at the shown speeds", () => {
  const history = demoHistory();
  const provider = demoProvider();
  assert.equal(history.times.length, 300);
  assert.equal(history.times[299] - history.times[0], 299000);
  assert.equal(provider.down, history.down[299]);
  assert.equal(provider.up, history.up[299]);
  // A curve with spikes: the peak is well above the median, and the session totals are counted.
  const sorted = [...history.down].sort((a, b) => a - b);
  assert.ok(history.peakDown > 3 * sorted[150]);
  assert.ok(history.peakUp > 0);
  assert.ok(history.sessionDown > 512 * 1024 ** 2);
  assert.ok(history.sessionUp > 0);
  // The thresholds of the color mode: download orange (10 MiB/s), upload blue (1 MiB/s).
  assert.ok(provider.down >= 10 * 1024 ** 2 && provider.down < 100 * 1024 ** 2);
  assert.ok(provider.up >= 1024 ** 2 && provider.up < 10 * 1024 ** 2);
  assert.deepEqual(demoHistory(), history, "the data is the same on every run");
});

test("the demo usage is current and at 85 % of the data cap", () => {
  const usage = demoUsage();
  assert.equal(usage.status, "ok");
  assert.equal(usage.outdated, false);
  assert.equal(usage.cap.enabled, true);
  assert.equal(usage.cap.percent, 85);
  assert.equal(usage.cap.level, 1);
  assert.equal(usage.summary.current.total, 0.85 * usage.cap.capBytes);
  assert.equal(usage.summary.current.complete, true);
  assert.equal(usage.summary.previous.complete, true);
  assert.deepEqual(usage.summary.counted, ["eth0", "wlan0"]);
  assert.ok(usage.summary.today.total > 0 && usage.summary.yesterday.total > 0);
});

test("the font is the first available of the fixed list", () => {
  assert.deepEqual(DEMO_FONTS, ["Noto Sans", "DejaVu Sans"]);
  assert.equal(pickFont(["DejaVu Sans", "Noto Sans", "Other"]), "Noto Sans");
  assert.equal(pickFont(["Other", "DejaVu Sans"]), "DejaVu Sans");
  assert.equal(pickFont(["Other"]), "");
});

test("the shots have fixed file names", () => {
  assert.deepEqual(SHOTS, [
    "panel-rows.png",
    "panel-single.png",
    "panel-vertical.png",
    "panel-colors.png",
    "panel-sparkline.png",
    "popup.png",
  ]);
});

// --- the image check ----------------------------------------------------------

function chunk(type, data) {
  const out = Buffer.alloc(12 + data.length);
  out.writeUInt32BE(data.length, 0);
  out.write(type, 4, "latin1");
  data.copy(out, 8);
  out.writeUInt32BE(zlib.crc32(out.subarray(4, 8 + data.length)), 8 + data.length);
  return out;
}

// A PNG of `rows` (arrays of [r, g, b, a]), each row with the given filter type.
function makePng(rows, { filters = [], extra = [], colorType = 6 } = {}) {
  const width = rows[0].length;
  const channels = colorType === 6 ? 4 : 3;
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(rows.length, 4);
  header[8] = 8;
  header[9] = colorType;
  const raw = [];
  let previous = Buffer.alloc(width * channels);
  rows.forEach((row, y) => {
    const line = Buffer.from(row.flatMap((p) => p.slice(0, channels)));
    const filter = filters[y] ?? 0;
    raw.push(filter, ...encodeLine(filter, line, previous, channels));
    previous = line;
  });
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", header),
    ...extra,
    chunk("IDAT", zlib.deflateSync(Buffer.from(raw))),
    chunk("IEND", Buffer.alloc(0)),
  ]);
}

function paeth(a, b, c) {
  const p = a + b - c;
  const pa = Math.abs(p - a);
  const pb = Math.abs(p - b);
  const pc = Math.abs(p - c);
  return pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
}

function encodeLine(filter, line, previous, bpp) {
  return [...line].map((value, i) => {
    const a = i >= bpp ? line[i - bpp] : 0;
    const b = previous[i];
    const c = i >= bpp ? previous[i - bpp] : 0;
    const predictor = [0, a, b, Math.floor((a + b) / 2), paeth(a, b, c)][filter];
    return (value - predictor + 256) % 256;
  });
}

const RED = [255, 0, 0, 255];
const BLUE = [0, 0, 255, 255];

test("readPng decodes every filter type", () => {
  const rows = [
    [RED, BLUE, RED],
    [BLUE, RED, BLUE],
    [RED, RED, BLUE],
    [BLUE, BLUE, RED],
    [RED, BLUE, BLUE],
  ];
  const png = readPng(makePng(rows, { filters: [0, 1, 2, 3, 4] }));
  assert.equal(png.width, 3);
  assert.equal(png.height, 5);
  assert.deepEqual([...png.pixel(1, 0)], BLUE);
  assert.deepEqual([...png.pixel(2, 4)], BLUE);
  assert.deepEqual([...png.pixel(0, 3)], BLUE);
  const rgb = readPng(makePng(rows, { colorType: 2, filters: [4, 3, 2, 1, 0] }));
  assert.deepEqual([...rgb.pixel(1, 1)], RED);
});

test("readPng refuses what is not an 8-bit PNG", () => {
  assert.throws(() => readPng(Buffer.from("not a png")), /not a PNG/);
  const png = makePng([[RED]]);
  png[24] = 16; // bit depth
  assert.throws(() => readPng(png), /unsupported/);
});

test("metadata with a path or a time stamp is reported", () => {
  const plain = readPng(makePng([[RED]]));
  assert.deepEqual(metadataProblems(plain), []);
  const text = chunk("tEXt", Buffer.from("Source\0/somewhere/file.qml", "latin1"));
  const time = chunk("tIME", Buffer.alloc(7));
  const tagged = readPng(makePng([[RED]], { extra: [text, time] }));
  assert.deepEqual(metadataProblems(tagged), ["metadata chunk tEXt", "metadata chunk tIME"]);
});

test("a chart area of one color is reported, one with lines is not", () => {
  const flat = Array.from({ length: 10 }, () => Array.from({ length: 10 }, () => RED));
  const drawn = flat.map((row, y) => row.map((p, x) => (x === y ? BLUE : p)));
  const area = { x: 0, y: 0, width: 10, height: 10, sceneWidth: 10, sceneHeight: 10 };
  assert.match(chartProblem(readPng(makePng(flat)), area), /one color/);
  assert.equal(chartProblem(readPng(makePng(drawn)), area), "");
  // The area is given in scene units; a grab at twice the size scales it.
  assert.equal(chartProblem(readPng(makePng(drawn)), { ...area, width: 5, height: 5, sceneWidth: 5 }), "");
  assert.match(chartProblem(readPng(makePng(drawn)), { ...area, width: 0 }), /empty/);
});

test("the chart line of the scene is parsed", () => {
  assert.deepEqual(parseChartLine("qml: SCREENSHOT chart popup.png 10 20.5 300 140 of 528 720"), {
    x: 10,
    y: 20.5,
    width: 300,
    height: 140,
    sceneWidth: 528,
    sceneHeight: 720,
  });
  assert.equal(parseChartLine("qml: something else"), null);
});

test("checkImages reports missing files and checks the chart only when asked", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "shots-"));
  try {
    assert.deepEqual(
      checkImages(dir, { chart: null }).problems,
      SHOTS.map((n) => `${n}: missing`),
    );
    const flat = Array.from({ length: 4 }, () => Array.from({ length: 4 }, () => RED));
    for (const name of SHOTS) fs.writeFileSync(path.join(dir, name), makePng(flat));
    const area = { x: 0, y: 0, width: 4, height: 4, sceneWidth: 4, sceneHeight: 4 };
    const skipped = checkImages(dir, { chart: null });
    assert.deepEqual(skipped.problems, []);
    assert.match(skipped.notes.join("\n"), /chart area check skipped/);
    assert.match(checkImages(dir, { chart: area }).problems.join("\n"), /popup\.png: the chart area is one color/);
  } finally {
    fs.rmSync(dir, { recursive: true });
  }
});
