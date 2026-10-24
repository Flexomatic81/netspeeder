# shellcheck shell=bash
# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 Flexomatic81

# Shared part of scripts/screenshots.sh and tools/screenshots/offscreen-check.sh:
# runs the screenshot scene with qml6 and judges its output. Meant to be
# sourced, not run.

# Console output of the scene is prefixed with "qml: ". These patterns flag a
# problem even then (the same as in scripts/smoke.sh).
problem_pattern='TypeError|ReferenceError|Binding loop|Cannot assign|is not a type|Unable to assign|\.qml:[0-9]+|SCREENSHOTS FAIL'

# Prints the lines of the output in $1 that are QML problems.
qml_problems() {
  local line
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if grep -Eq "$problem_pattern" <<<"$line"; then
      echo "$line"
    fi
  done <<<"$1"
}

# Prints the lines of the output in $1 that are not plain console output of
# the scene: anything the Qt engine or the platform reports itself.
other_lines() {
  local line
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    [[ "$line" == "qml: "* ]] || echo "$line"
  done <<<"$1"
}

# run_scene <output directory> <log file>: runs the scene with the environment
# of the caller, writes its output to the log file and shows it. Returns the
# exit status of qml6.
run_scene() {
  local dir="$1" log="$2" root rc
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  # Qt logs to journald unless stderr is a terminal; force it to stderr so
  # console.log output reaches the log.
  QT_FORCE_STDERR_LOGGING=1 timeout 60 qml6 "$root/tools/screenshots/Screenshots.qml" -- "$dir" >"$log" 2>&1
  rc=$?
  cat "$log"
  return "$rc"
}
