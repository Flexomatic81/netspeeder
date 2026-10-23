#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 Flexomatic81

# Starts the installed plasmoid offscreen for ten seconds and checks that it
# loads: it must run until `timeout` ends it, log "netspeeder: loaded" and
# produce no QML errors. Needs a running desktop session (D-Bus).
# Usage: scripts/load-check.sh [plugin-id]
# Prints LOAD OK and exits 0 when everything holds, otherwise shows the output
# and exits 1; exits 2 when there is no desktop session.
set -euo pipefail

plugin="${1:-io.github.flexomatic81.netspeeder}"

if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
  echo "load-check: DBUS_SESSION_BUS_ADDRESS is not set; run this inside a running desktop session" >&2
  exit 2
fi

# Qt logs to journald unless stderr is a terminal; force it to stderr so the
# QML log lines reach the capture.
status=0
output="$(QT_FORCE_STDERR_LOGGING=1 QT_LOGGING_RULES="qml.debug=true" QT_QPA_PLATFORM=offscreen \
  timeout 10 plasmawindowed "$plugin" 2>&1)" || status=$?

problems=()

# 124 means `timeout` ended a plasmawindowed that was still running; any other
# status means it crashed or never started.
if [ "$status" -ne 124 ]; then
  problems+=("plasmawindowed ended with status $status instead of running until timeout (124)")
fi

if ! grep -qF 'netspeeder: loaded' <<<"$output"; then
  problems+=("no 'netspeeder: loaded' line: main.qml did not complete")
fi

# QML errors always name the file and line. Besides the loaded line, the
# plasmoid logs nothing but console.warn("netspeeder: ...") messages.
errors="$(grep -E '\.qml:[0-9]+|TypeError|ReferenceError|is not a type|is not installed|netspeeder:' <<<"$output" \
  | grep -vF 'netspeeder: loaded' || true)"
if [ -n "$errors" ]; then
  problems+=("QML errors or netspeeder warnings in the output:"$'\n'"$errors")
fi

if [ "${#problems[@]}" -eq 0 ]; then
  echo "LOAD OK"
  exit 0
fi

echo "load-check: FAILED for $plugin" >&2
printf '  - %s\n' "${problems[@]}" >&2
echo "--- output of plasmawindowed ---" >&2
echo "$output" >&2
exit 1
