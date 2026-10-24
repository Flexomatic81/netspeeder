#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 Flexomatic81

# Runs QML smoke scenes with qml6. A scene passes when its output contains a
# line with "SMOKE OK"; the output of a failing scene is shown in full.
# Usage: scripts/smoke.sh [scene.qml ...]   (default: tests/qml/*Smoke.qml)
# Runs locally only: the scenes need ksystemstats and /sys.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

scenes=("$@")
if [ "${#scenes[@]}" -eq 0 ]; then
  scenes=(tests/qml/*Smoke.qml)
fi

status=0
for scene in "${scenes[@]}"; do
  # Qt logs to journald unless stderr is a terminal; force it to stderr so
  # console.log output reaches the capture.
  output="$(QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen timeout 40 qml6 "$scene" 2>&1)"
  if grep -q 'SMOKE OK' <<<"$output" && ! grep -q 'SMOKE FAIL' <<<"$output"; then
    grep 'SMOKE OK' <<<"$output"
  else
    echo "smoke: FAILED $scene" >&2
    echo "$output" >&2
    status=1
  fi
done
exit "$status"
