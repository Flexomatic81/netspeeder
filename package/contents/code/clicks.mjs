// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Decides what a click on the panel view does. The settings leftClick and
// middleClick hold "popup", "launch" or "none".

const ACTIONS = ["popup", "launch", "none"];
const DEFAULTS = { left: "popup", middle: "none" };

// "popup", "launch" or "none" for a button ("left" or "middle"); an unknown
// value of the setting gives the default of that button.
export function actionFor(button, config) {
  const fallback = DEFAULTS[button];
  if (fallback === undefined) {
    return "none";
  }
  const value = config?.[`${button}Click`];
  return ACTIONS.includes(value) ? value : fallback;
}

// Whether some button opens the popup (otherwise the user cannot reach it).
export function popupReachable(config) {
  return actionFor("left", config) === "popup" || actionFor("middle", config) === "popup";
}

// The popup state after a click. `wasExpanded` is the state seen at the press:
// a click on the widget closes an open popup by itself (focus loss), so the
// release must not open it again.
export function nextExpanded(wasExpanded) {
  return !wasExpanded;
}
