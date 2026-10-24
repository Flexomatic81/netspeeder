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

const ROOTS = ["/usr/share/applications", "/home/user/.local/share/applications"];

test("the desktop ID of a launcher in a subfolder joins the relative path with dashes", () => {
  assert.equal(desktopIdFromUrl("file:///usr/share/applications/kde4/foo.desktop", ROOTS), "kde4-foo");
  assert.equal(desktopIdFromUrl("file:///usr/share/applications/a/b/c/d.desktop", ROOTS), "a-b-c-d");
  assert.equal(desktopIdFromUrl("file:///usr/share/applications/a/b-c.desktop", ROOTS), "a-b-c");
  assert.equal(
    desktopIdFromUrl("file:///home/user/.local/share/applications/kde4/foo%20x.desktop", ROOTS),
    "kde4-foo x",
  );
  assert.equal(desktopIdFromUrl("file:///usr/share/applications/org.kde.konsole.desktop", ROOTS), "org.kde.konsole");
});

test("the longest matching root is the prefix of the desktop ID", () => {
  const roots = ["/usr/share/applications", "/usr/share/applications/vendor/applications"];
  assert.equal(desktopIdFromUrl("file:///usr/share/applications/vendor/applications/foo.desktop", roots), "foo");
  assert.equal(
    desktopIdFromUrl("file:///usr/share/applications/vendor/applications/foo.desktop", ["/usr/share/applications"]),
    "vendor-applications-foo",
  );
  assert.equal(
    desktopIdFromUrl("file:///usr/share/applications/vendor/applications/foo.desktop", ["/usr/share/applications/"]),
    "vendor-applications-foo",
  );
});

test("roots and paths match in encoded and decoded form, with spaces and accents", () => {
  const file = "/.local/share/applications/kde4/foo.desktop";
  const dirs = [
    ["/home/user%20name", "/home/user name"],
    ["/home/caf%C3%A9", "/home/caf\u00e9"],
  ];
  for (const [encoded, decoded] of dirs) {
    for (const root of [`file://${encoded}/.local/share/applications`, `${decoded}/.local/share/applications`]) {
      assert.equal(desktopIdFromUrl(`file://${encoded}${file}`, [root]), "kde4-foo", root);
      assert.equal(desktopIdFromUrl(`${decoded}${file}`, [root]), "kde4-foo", root);
    }
  }
});

test("dot segments are resolved in roots and paths", () => {
  const root = "/usr/share/./x/../applications/";
  assert.equal(desktopIdFromUrl("file:///usr/share/applications/a/../kde4/foo.desktop", [root]), "kde4-foo");
});

test("a launcher outside every root gives its file name", () => {
  assert.equal(desktopIdFromUrl("file:///opt/tools/x/foo.desktop", ROOTS), "foo");
  assert.equal(desktopIdFromUrl("file:///usr/share/applicationsx/foo.desktop", ROOTS), "foo");
  assert.equal(desktopIdFromUrl("file:///usr/share/applications/sub/foo.desktop"), "foo");
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
