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

// The desktop ID of a launcher file the user chose (a file URL or a plain
// path): the file name without ".desktop". Anything else gives "".
export function desktopIdFromUrl(url) {
  const text = String(url ?? "");
  const path = text.startsWith("file://") ? text.slice("file://".length) : text;
  if (/^[a-z][a-z0-9+.-]*:/i.test(path)) {
    return "";
  }
  const name = path.slice(path.lastIndexOf("/") + 1);
  if (!name.endsWith(".desktop")) {
    return "";
  }
  try {
    return decodeURIComponent(name.slice(0, -".desktop".length));
  } catch (error) {
    // Malformed percent-encoding; anything else is a real fault.
    if (error instanceof URIError) {
      return "";
    }
    throw error;
  }
}
