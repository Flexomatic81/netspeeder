// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import { test } from "node:test";
import assert from "node:assert/strict";
import { headerDetails, parseSpinText, pluralFallback, substitute } from "../package/contents/code/text.mjs";

test("a missing argument leaves its placeholder", () => {
  assert.equal(substitute("a %1 %2", ["x"]), "a x %2");
});

test("a number is followed by a literal percent sign", () => {
  assert.equal(substitute("%1%", [50]), "50%");
});

test("%9 is replaced when nine arguments are given", () => {
  const args = ["1", "2", "3", "4", "5", "6", "7", "8", "nine"];
  assert.equal(substitute("%9 %1 %5", args), "nine 1 5");
});

test("an empty argument list leaves the text unchanged", () => {
  assert.equal(substitute("Download: %1", []), "Download: %1");
  assert.equal(substitute("plain", []), "plain");
});

test("a placeholder is replaced everywhere it occurs", () => {
  assert.equal(substitute("%1-%1", ["a"]), "a-a");
});

test("values are converted with String", () => {
  assert.equal(substitute("%1 %2", [0, false]), "0 false");
});

test("pluralFallback uses the singular for exactly one", () => {
  assert.equal(pluralFallback("%1 file", "%1 files", 1, []), "1 file");
});

test("pluralFallback uses the plural for zero and for more than one", () => {
  assert.equal(pluralFallback("%1 file", "%1 files", 0, []), "0 files");
  assert.equal(pluralFallback("%1 file", "%1 files", 2, []), "2 files");
});

test("pluralFallback passes the count as %1 and shifts the other arguments", () => {
  assert.equal(pluralFallback("%1 file in %2", "%1 files in %2", 3, ["dir"]), "3 files in dir");
});

test("headerDetails joins address and status with one separator", () => {
  assert.equal(headerDetails("192.168.1.121", "Online"), "192.168.1.121 · Online");
  assert.equal(headerDetails("", "Online"), "Online");
  assert.equal(headerDetails("192.168.1.121", ""), "192.168.1.121");
  assert.equal(headerDetails("", ""), "");
  assert.equal(headerDetails(undefined, "Offline"), "Offline");
});

const de = { decimalPoint: ",", groupSeparator: "." };
const en = { decimalPoint: ".", groupSeparator: "," };
const fr = { decimalPoint: ",", groupSeparator: "\u202f" };

test("parseSpinText ignores the group separator and the unit", () => {
  assert.equal(parseSpinText("1.024 KiB/s", de, 0, 7), 1024);
  assert.equal(parseSpinText("1,024 KiB/s", en, 0, 7), 1024);
  assert.equal(parseSpinText("1\u202f024 s", fr, 0, 7), 1024);
  assert.equal(parseSpinText("1 024 s", fr, 0, 7), 1024);
  assert.equal(parseSpinText("  42", en, 0, 7), 42);
});

test("parseSpinText reads the decimal point only with decimals", () => {
  assert.equal(parseSpinText("2,5 s", de, 1, 7), 2.5);
  assert.equal(parseSpinText("2.5 s", en, 1, 7), 2.5);
  assert.equal(parseSpinText("2,5 s", de, 0, 7), 2);
});

test("parseSpinText gives the fallback without a leading number", () => {
  assert.equal(parseSpinText("", en, 0, 7), 7);
  assert.equal(parseSpinText("KiB/s", en, 0, 7), 7);
  assert.equal(parseSpinText("-5", en, 0, 7), 7);
  assert.equal(parseSpinText("abc", en, 0, 7), 7);
  assert.equal(parseSpinText(",", en, 0, 7), 7);
});
