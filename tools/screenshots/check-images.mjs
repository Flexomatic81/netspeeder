// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Checks the images of the screenshot scene: all six exist and are readable 8-bit PNG files, none carries
// metadata (text, time stamps, Exif), and neither the chart area nor the data cap bar of the popup is one
// plain color. Only the Node standard library is used.
//
//   node tools/screenshots/check-images.mjs <dir> --log <scene output>         after a run on a real display
//   node tools/screenshots/check-images.mjs <dir> --offscreen <scene output>   without the chart check:
//                                                                              offscreen, Qt Quick Charts
//                                                                              draws nothing

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import zlib from "node:zlib";
import { SHOTS } from "./demo.mjs";

const SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
// Channels per color type: gray, RGB, gray with alpha, RGBA (8 bits each).
const CHANNELS = { 0: 1, 2: 3, 4: 2, 6: 4 };
const METADATA = ["tEXt", "zTXt", "iTXt", "tIME", "eXIf"];
// Less than this share of pixels apart from the most common color counts as one color.
const MIN_DRAWN_SHARE = 0.005;
const NUMBER = "(-?[\\d.]+)";

function chunksOf(buffer) {
  const chunks = [];
  let offset = SIGNATURE.length;
  while (offset + 8 <= buffer.length) {
    const length = buffer.readUInt32BE(offset);
    const type = buffer.toString("latin1", offset + 4, offset + 8);
    chunks.push({ type: type, data: buffer.subarray(offset + 8, offset + 8 + length) });
    offset += 12 + length;
  }
  return chunks;
}

function paeth(a, b, c) {
  const p = a + b - c;
  const pa = Math.abs(p - a);
  const pb = Math.abs(p - b);
  const pc = Math.abs(p - c);
  if (pa <= pb && pa <= pc) return a;
  return pb <= pc ? b : c;
}

function predictor(filter, a, b, c) {
  switch (filter) {
    case 0:
      return 0;
    case 1:
      return a;
    case 2:
      return b;
    case 3:
      return Math.floor((a + b) / 2);
    case 4:
      return paeth(a, b, c);
    default:
      throw new Error(`unknown filter type ${filter}`);
  }
}

// Undoes the per-line filters; returns the raw samples, `stride` bytes per line.
function unfilter(data, height, stride, bpp) {
  const out = Buffer.alloc(height * stride);
  for (let y = 0; y < height; y++) {
    const filter = data[y * (stride + 1)];
    const line = y * stride;
    for (let i = 0; i < stride; i++) {
      const a = i >= bpp ? out[line + i - bpp] : 0;
      const b = y > 0 ? out[line - stride + i] : 0;
      const c = i >= bpp && y > 0 ? out[line - stride + i - bpp] : 0;
      out[line + i] = (data[y * (stride + 1) + 1 + i] + predictor(filter, a, b, c)) & 0xff;
    }
  }
  return out;
}

function header(chunks) {
  const ihdr = chunks.find((c) => c.type === "IHDR");
  if (!ihdr) throw new Error("not a PNG: no header");
  const h = ihdr.data;
  const info = { width: h.readUInt32BE(0), height: h.readUInt32BE(4), depth: h[8], colorType: h[9], interlace: h[12] };
  if (info.depth !== 8 || !(info.colorType in CHANNELS) || info.interlace !== 0) {
    throw new Error(
      `unsupported PNG: bit depth ${info.depth}, color type ${info.colorType}, interlace ${info.interlace}`,
    );
  }
  return info;
}

/** Reads an 8-bit, non-interlaced gray, RGB or RGBA PNG; pixel(x, y) gives [r, g, b, a]. */
export function readPng(buffer) {
  if (buffer.length < SIGNATURE.length || !buffer.subarray(0, SIGNATURE.length).equals(SIGNATURE)) {
    throw new Error("not a PNG file");
  }
  const chunks = chunksOf(buffer);
  const info = header(chunks);
  const bpp = CHANNELS[info.colorType];
  const stride = info.width * bpp;
  const data = zlib.inflateSync(Buffer.concat(chunks.filter((c) => c.type === "IDAT").map((c) => c.data)));
  const samples = unfilter(data, info.height, stride, bpp);
  const pixel = (x, y) => {
    const at = y * stride + x * bpp;
    const s = samples.subarray(at, at + bpp);
    if (bpp >= 3) return [s[0], s[1], s[2], bpp === 4 ? s[3] : 255];
    return [s[0], s[0], s[0], bpp === 2 ? s[1] : 255];
  };
  return { width: info.width, height: info.height, chunks: chunks, pixel: pixel };
}

/** One entry per metadata chunk (text, time stamp, Exif): a grab must carry none, so no path can leak. */
export function metadataProblems(png) {
  return png.chunks.filter((c) => METADATA.includes(c.type)).map((c) => `metadata chunk ${c.type}`);
}

/** The area of `kind` ("chart" or "bar") in popup.png that the scene reports in its output, or null. */
export function parseArea(text, kind) {
  const n = NUMBER;
  const m = new RegExp(`SCREENSHOT ${kind} popup\\.png ${n} ${n} ${n} ${n} of ${n} ${n}`).exec(text);
  if (m === null) return null;
  const [x, y, width, height, sceneWidth, sceneHeight] = m.slice(1).map(Number);
  return { x, y, width, height, sceneWidth, sceneHeight };
}

/** The chart area the scene reports in its output, or null. */
export function parseChartLine(text) {
  return parseArea(text, "chart");
}

// The area in image pixels: the image may be a multiple of the scene size (a scaled display).
function pixelRect(png, area) {
  const scale = area.sceneWidth > 0 ? png.width / area.sceneWidth : 1;
  const x0 = Math.max(0, Math.round(area.x * scale));
  const y0 = Math.max(0, Math.round(area.y * scale));
  const x1 = Math.min(png.width, Math.round((area.x + area.width) * scale));
  const y1 = Math.min(png.height, Math.round((area.y + area.height) * scale));
  return { x0, y0, x1, y1 };
}

/** "" when the area (by default the chart area) of the popup shows more than one color, else the reason. */
export function chartProblem(png, area, what = "the chart area") {
  const r = pixelRect(png, area);
  if (r.x1 <= r.x0 || r.y1 <= r.y0) return `${what} is empty`;
  const counts = new Map();
  for (let y = r.y0; y < r.y1; y++) {
    for (let x = r.x0; x < r.x1; x++) {
      const key = png.pixel(x, y).join(",");
      counts.set(key, (counts.get(key) ?? 0) + 1);
    }
  }
  const total = (r.x1 - r.x0) * (r.y1 - r.y0);
  const drawn = (total - Math.max(...counts.values())) / total;
  return drawn < MIN_DRAWN_SHARE ? `${what} is one color (${(drawn * 100).toFixed(2)} % drawn)` : "";
}

// Checks one area of popup.png; null skips it.
function checkArea(png, area, what, result) {
  if (area === null || area === undefined) return;
  const problem = chartProblem(png, area, what);
  if (problem !== "") result.problems.push(`popup.png: ${problem}`);
  else result.notes.push(`popup.png: ${what} shows a drawing`);
}

function checkOne(dir, name, areas, result) {
  const file = path.join(dir, name);
  if (!fs.existsSync(file)) {
    result.problems.push(`${name}: missing`);
    return;
  }
  let png;
  try {
    png = readPng(fs.readFileSync(file));
  } catch (e) {
    result.problems.push(`${name}: ${e.message}`);
    return;
  }
  result.notes.push(`${name}: ${png.width}x${png.height}`);
  result.problems.push(...metadataProblems(png).map((p) => `${name}: ${p}`));
  if (name === "popup.png") {
    checkArea(png, areas.chart, "the chart area", result);
    checkArea(png, areas.bar, "the usage bar area", result);
  }
}

/** Checks the six images in `dir`; `chart` and `bar` are the chart area and the data cap bar of the popup,
 *  null (or a missing `bar`) skips that check. */
export function checkImages(dir, { chart, bar = null }) {
  const result = { problems: [], notes: [] };
  for (const name of SHOTS) checkOne(dir, name, { chart, bar }, result);
  if (chart === null) {
    result.notes.push("chart area check skipped: offscreen, Qt Quick Charts draws nothing");
  }
  return result;
}

function usage() {
  console.error("usage: check-images.mjs <dir> (--log | --offscreen) <scene output>");
  return 2;
}

// The areas of popup.png in the scene output: the usage bar always, the chart only with `withChart`. A string
// names the missing line.
function areasOf(text, withChart) {
  const bar = parseArea(text, "bar");
  if (bar === null) return "usage bar";
  const chart = withChart ? parseArea(text, "chart") : null;
  if (withChart && chart === null) return "chart area";
  return { bar, chart };
}

export function main(argv) {
  const [dir, mode, logFile] = argv;
  if (!dir || !logFile || (mode !== "--offscreen" && mode !== "--log")) return usage();
  const areas = areasOf(fs.readFileSync(logFile, "utf8"), mode === "--log");
  if (typeof areas === "string") {
    console.error(`check-images: the scene output has no ${areas} line`);
    return 1;
  }
  const { problems, notes } = checkImages(dir, areas);
  notes.forEach((n) => console.log(`  ${n}`));
  problems.forEach((p) => console.error(`  PROBLEM ${p}`));
  console.log(problems.length === 0 ? "IMAGES OK" : "IMAGES FAIL");
  return problems.length === 0 ? 0 : 1;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = main(process.argv.slice(2));
}
