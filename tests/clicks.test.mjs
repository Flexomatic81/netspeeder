// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import { test } from "node:test";
import assert from "node:assert/strict";
import { actionFor, desktopIdFromUrl, nextExpanded, popupReachable } from "../package/contents/code/clicks.mjs";

const actions = ["popup", "launch", "none"];

test("each button follows its configured action", () => {
  for (const left of actions) {
    for (const middle of actions) {
      const config = { leftClick: left, middleClick: middle };
      assert.equal(actionFor("left", config), left);
      assert.equal(actionFor("middle", config), middle);
    }
  }
});

test("unknown or missing values fall back to the defaults", () => {
  assert.equal(actionFor("left", { leftClick: "bogus", middleClick: "popup" }), "popup");
  assert.equal(actionFor("middle", { leftClick: "launch", middleClick: "bogus" }), "none");
  assert.equal(actionFor("left", {}), "popup");
  assert.equal(actionFor("middle", {}), "none");
  assert.equal(actionFor("left", undefined), "popup");
});

test("an unknown button does nothing", () => {
  assert.equal(actionFor("right", { leftClick: "popup", middleClick: "popup" }), "none");
});

test("the popup is reachable when at least one button opens it", () => {
  for (const left of actions) {
    for (const middle of actions) {
      assert.equal(popupReachable({ leftClick: left, middleClick: middle }), left === "popup" || middle === "popup");
    }
  }
  assert.equal(popupReachable({ leftClick: "bogus", middleClick: "none" }), true);
  assert.equal(popupReachable({ leftClick: "launch", middleClick: "bogus" }), false);
  assert.equal(popupReachable({}), true);
});

test("the popup toggles against the state seen at the press", () => {
  assert.equal(nextExpanded(false), true);
  assert.equal(nextExpanded(true), false);
});

test("the desktop ID is the file name of a chosen launcher without .desktop", () => {
  assert.equal(desktopIdFromUrl("file:///usr/share/applications/org.kde.konsole.desktop"), "org.kde.konsole");
  assert.equal(desktopIdFromUrl("file:///usr/share/applications/my%20app.desktop"), "my app");
  assert.equal(desktopIdFromUrl("file:///usr/share/applications/caf%C3%A9.desktop"), "café");
  assert.equal(desktopIdFromUrl("/usr/share/applications/firefox.desktop"), "firefox");
});

test("anything that is not a .desktop file gives an empty ID", () => {
  assert.equal(desktopIdFromUrl("file:///usr/bin/konsole"), "");
  assert.equal(desktopIdFromUrl("file:///usr/share/applications/"), "");
  assert.equal(desktopIdFromUrl("file:///usr/share/applications/.desktop"), "");
  assert.equal(desktopIdFromUrl("file:///usr/share/applications/a.desktop.bak"), "");
  assert.equal(desktopIdFromUrl("https://example.org/a.desktop"), "");
  assert.equal(desktopIdFromUrl("file:///usr/share/applications/%E0%A4%A.desktop"), "");
  assert.equal(desktopIdFromUrl("file:///usr/share/applications/%FF%FF.desktop"), "");
  assert.equal(desktopIdFromUrl(""), "");
  assert.equal(desktopIdFromUrl(undefined), "");
});
