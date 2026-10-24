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

function decodePath(path) {
  const parts = path.split("/").map((part) => decodeURIComponent(part));
  return parts.some((part) => part.includes("/")) ? null : parts.join("/");
}

// A root as a plain path without "file://" and without trailing slashes.
function plainRoot(root) {
  const text = String(root ?? "");
  return (text.startsWith("file://") ? text.slice("file://".length) : text).replace(/\/+$/, "");
}

// The part of the path below the longest root that contains it, or "" when
// no root does.
function relativeToRoot(path, roots) {
  let best = "";
  for (const root of roots.map(plainRoot)) {
    if (root.length > best.length && path.startsWith(`${root}/`)) {
      best = root;
    }
  }
  return best === "" ? "" : path.slice(best.length + 1);
}

// The decoded path of a file URL or plain path, or null for other URLs, a
// malformed percent-encoding or a path that is no .desktop file.
function launcherPath(url) {
  const text = String(url ?? "");
  const raw = text.startsWith("file://") ? text.slice("file://".length) : text;
  if (/^[a-z][a-z0-9+.-]*:/i.test(raw)) {
    return null;
  }
  try {
    const path = decodePath(raw);
    return path !== null && /(^|\/)[^/]+\.desktop$/.test(path) ? path : null;
  } catch (error) {
    // Malformed percent-encoding; anything else is a real fault.
    if (error instanceof URIError) {
      return null;
    }
    throw error;
  }
}

// The desktop ID of a launcher file the user chose (a file URL or a plain
// path), following the desktop entry naming rule: the path below the
// applications folder (one of `roots`, the longest match wins) with "/"
// replaced by "-", without ".desktop". A file outside every root gives its
// file name without ".desktop". Anything else gives "".
export function desktopIdFromUrl(url, roots = []) {
  const path = launcherPath(url);
  if (path === null) {
    return "";
  }
  const relative = relativeToRoot(path, roots) || path.slice(path.lastIndexOf("/") + 1);
  return relative.slice(0, -".desktop".length).replace(/\//g, "-");
}
