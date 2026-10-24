// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// The text of the notification for a failed launch. The texts come from the
// translation helpers passed in (named tr/trc as in the QML files so the
// catalog extraction finds them). The notification renders rich text and the
// target is user text, so it is escaped before it goes into a message.

import { escapeHtml } from "./tooltip.mjs";

// code: "invalid", "not-found", "timeout" or anything else for a failed start;
// kind: "app" or "command", which says what an empty target was meant to be.
export function launchFailureText(code, target, kind, t) {
  if (code === "invalid" && target.trim() === "") {
    return kind === "app"
      ? t.trc("@info", "No application is set. Choose one in the widget settings.")
      : t.trc("@info", "No command is set. Choose one in the widget settings.");
  }
  const shown = escapeHtml(target);
  switch (code) {
    case "invalid":
      return t.trc("@info", "The launch target “%1” is not valid.", shown);
    case "not-found":
      return t.trc("@info", "Could not find “%1”.", shown);
    case "timeout":
      return t.trc("@info", "Starting “%1” did not respond.", shown);
    default:
      return t.trc("@info", "Could not start “%1”.", shown);
  }
}
