// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import { test } from "node:test";
import assert from "node:assert/strict";
import { launchFailureText } from "../package/contents/code/launchtext.mjs";

const fill = (text, args) => text.replace(/%([1-9])/g, (_, d) => String(args[Number(d) - 1]));
const t = {
  tr: (text, ...args) => fill(text, args),
  trc: (_context, text, ...args) => fill(text, args),
};

test("launchFailureText names the target for every code", () => {
  assert.equal(launchFailureText("invalid", "x", "app", t), "The launch target “x” is not valid.");
  assert.equal(launchFailureText("not-found", "x", "app", t), "Could not find “x”.");
  assert.equal(launchFailureText("timeout", "x", "command", t), "Starting “x” did not respond.");
  assert.equal(launchFailureText("failed", "x", "command", t), "Could not start “x”.");
  assert.equal(launchFailureText("other", "x", "command", t), "Could not start “x”.");
});

test("launchFailureText escapes markup in the target", () => {
  const text = launchFailureText("not-found", 'a<b>&"c"', "command", t);
  assert.equal(text, 'Could not find “a&lt;b&gt;&amp;"c"”.');
});

test("launchFailureText explains an empty target by kind", () => {
  assert.equal(launchFailureText("invalid", "", "command", t), "No command is set. Choose one in the widget settings.");
  assert.equal(
    launchFailureText("invalid", "  ", "command", t),
    "No command is set. Choose one in the widget settings.",
  );
  assert.equal(launchFailureText("invalid", "", "app", t), "No application is set. Choose one in the widget settings.");
});
