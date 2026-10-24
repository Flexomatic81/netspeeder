#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 Flexomatic81

# Runs QML smoke scenes with qml6. A scene passes only when qml6 exits with 0,
# its output contains a line with "SMOKE OK" and no "SMOKE FAIL", and it prints
# no QML warning. Everything the Qt engine reports itself (TypeError,
# ReferenceError, binding loops, load errors, any line that is not console
# output) counts as a warning, unless the scene lists it in expected_lines.
# The output of a failing scene is shown in full.
# Usage: scripts/smoke.sh [scene.qml ...]   (default: tests/qml/*Smoke.qml)
# Runs locally only: the scenes need ksystemstats and /sys.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

# Messages that are a scene's expected behaviour, as extended regular
# expressions for whole lines (one per output line). Keep them as narrow as
# the message itself.
expected_lines() {
  case "$(basename "$1")" in
    CommandRunnerSmoke.qml)
      # The scene abandons a "sleep" through the time limit; the engine still
      # owns that process when the scene exits.
      echo '^QProcess: Destroyed while process \("/bin/sh"\) is still running\.$'
      ;;
    ConfigAppearanceSmoke.qml)
      # The colour buttons of KQuickControls create a translation context that
      # the offscreen platform reports as living in another thread.
      echo '^QObject::installEventFilter\(\): Cannot filter events for objects in a different thread\.$'
      ;;
    LauncherSmoke.qml)
      # The scene abandons a "sleep" through the time limit; the engine still
      # owns that process when the scene exits.
      echo '^QProcess: Destroyed while process \("/bin/sh"\) is still running\.$'
      ;;
    UsageSourceSmoke.qml)
      # The scene abandons a "sleep" through the time limit; the engine still
      # owns that process when the scene exits.
      echo '^QProcess: Destroyed while process \("/bin/sh"\) is still running\.$'
      ;;
    PopupGraphFailSmoke.qml)
      # The scene loads a graph file that imports a module that does not exist.
      echo '^file://.*/tests/qml/BrokenGraph\.qml:[0-9]+:[0-9]+: module "org\.kde\.netspeeder\.missingcharts" is not installed$'
      ;;
    SparklineFailSmoke.qml)
      # The scene loads a chart file that imports a module that does not exist
      # (once per view that shows a chart).
      echo '^file://.*/tests/qml/BrokenGraph\.qml:[0-9]+:[0-9]+: module "org\.kde\.netspeeder\.missingcharts" is not installed$'
      ;;
    ProviderSmoke.qml)
      # The scene points the provider at a data source that does not exist.
      echo '^file://.*/tests/qml/Missing\.qml: No such file or directory$'
      ;;
  esac
}

# Console output (console.log/warn) is prefixed with "qml: ". These patterns
# flag problems even when they come through console output.
problem_pattern='TypeError|ReferenceError|Binding loop|Cannot assign|is not a type|Unable to assign|\.qml:[0-9]+|SMOKE FAIL'

# Prints the lines of $1 (scene output) that are neither expected for scene $2
# nor plain console output without a problem pattern.
unexpected_lines() {
  local output="$1" scene="$2" line expected skip
  local -a patterns=()
  mapfile -t patterns < <(expected_lines "$scene")
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    skip=0
    for expected in "${patterns[@]}"; do
      if [[ -n "$expected" ]] && grep -Eq "$expected" <<<"$line"; then
        skip=1
        break
      fi
    done
    [ "$skip" -eq 1 ] && continue
    if [[ "$line" == "qml: "* ]]; then
      grep -Eq "$problem_pattern" <<<"$line" && echo "$line"
    else
      echo "$line"
    fi
  done <<<"$output"
}

scenes=("$@")
if [ "${#scenes[@]}" -eq 0 ]; then
  scenes=(tests/qml/*Smoke.qml)
fi

status=0
for scene in "${scenes[@]}"; do
  # Qt logs to journald unless stderr is a terminal; force it to stderr so
  # console.log output reaches the capture.
  output="$(QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen timeout 40 qml6 "$scene" 2>&1)"
  rc=$?
  unexpected="$(unexpected_lines "$output" "$scene")"
  if [ "$rc" -eq 0 ] && grep -q 'SMOKE OK' <<<"$output" && [ -z "$unexpected" ]; then
    grep 'SMOKE OK' <<<"$output"
  else
    echo "smoke: FAILED $scene (exit $rc)" >&2
    if [ -n "$unexpected" ]; then
      echo "smoke: unexpected output:" >&2
      echo "$unexpected" >&2
    fi
    echo "$output" >&2
    status=1
  fi
done
exit "$status"
