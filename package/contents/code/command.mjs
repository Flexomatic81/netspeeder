// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Builds the command lines that start programs from the widget. Pure functions
// without Qt or Plasma dependencies, so the module runs inside QML as well as
// under Node.
//
// "kstart --application <unknown>" never exits and "kstart -- sh -c <missing>"
// reports success, so a short sh script first checks the target and then
// starts it detached (setsid -f returns at once). The script's exit code is
// therefore the result of the check: 0 started, 127 target not found.

const DESKTOP_ID = /^[A-Za-z0-9._-]+$/;
const PLAIN_WORD = /^[A-Za-z0-9._+/-]+$/;
const NOT_FOUND = 127;
const TIMED_OUT = -2;

// $1 is the desktop id. In every data directory it first looks for
// $d/applications/$1.desktop; when that is missing, it applies the desktop
// entry naming rule to every .desktop file below $d/applications (the id is
// the path relative to that folder with "/" replaced by "-", at any depth).
// "tr" turns the whole path into dashes, so only the prefix needs the same
// treatment before the comparison.
const APP_SCRIPT = [
  "IFS=:",
  "set -f",
  'for d in "${XDG_DATA_HOME:-$HOME/.local/share}" ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do',
  '  a="$d/applications"',
  '  if [ -f "$a/$1.desktop" ]; then',
  '    setsid -f kstart --application "$1" >/dev/null 2>&1; exit 0',
  "  fi",
  '  [ -d "$a" ] || continue',
  "  p=$(printf '%s' \"$a/\" | tr / -)",
  "  hit=$(find -L \"$a\" -name '*.desktop' 2>/dev/null | tr / - | while IFS= read -r f; do",
  '    if [ "${f#"$p"}" = "$1.desktop" ]; then echo y; break; fi',
  "  done)",
  '  if [ -n "$hit" ]; then',
  '    setsid -f kstart --application "$1" >/dev/null 2>&1; exit 0',
  "  fi",
  "done",
  "exit 127",
].join("\n");

// $1 is the whole command, $2 the program to check ("" = no check).
const CMD_SCRIPT = [
  '[ -z "$2" ] || command -v -- "$2" >/dev/null || exit 127',
  'setsid -f sh -c "$1" >/dev/null 2>&1; exit 0',
].join("\n");

export function shellQuote(text) {
  return "'" + String(text).replace(/'/g, "'\\''") + "'";
}

// The first word, when it is a plain command name or path that the shell
// would look up unchanged. Anything else (variables, quotes, "~", operators,
// escapes, assignments, subshells) may expand to something different, so it
// is not checked ("" = launch without a pre-check).
function programToCheck(command) {
  const word = command.split(/\s/)[0];
  return PLAIN_WORD.test(word) ? word : "";
}

function appLine(app) {
  if (typeof app !== "string" || !DESKTOP_ID.test(app) || app.startsWith(".")) {
    return null;
  }
  return `sh -c ${shellQuote(APP_SCRIPT)} netspeeder ${shellQuote(app)}`;
}

function commandLine(command) {
  const text = typeof command === "string" ? command.trim() : "";
  if (text === "") {
    return null;
  }
  return `sh -c ${shellQuote(CMD_SCRIPT)} netspeeder ${shellQuote(text)} ${shellQuote(programToCheck(text))}`;
}

// Returns the shell command line for a launch target, or null when the target
// is invalid. kind: "app" (desktop id in app) or "command" (shell text).
export function launchCommandLine({ kind, app, command } = {}) {
  if (kind === "app") {
    return appLine(app);
  }
  if (kind === "command") {
    return commandLine(command);
  }
  return null;
}

// Classifies the exit code of a launch line: null on success, otherwise
// "not-found", "timeout" or "failed".
export function launchFailure(exitCode) {
  if (exitCode === 0) {
    return null;
  }
  if (exitCode === NOT_FOUND) {
    return "not-found";
  }
  return exitCode === TIMED_OUT ? "timeout" : "failed";
}
