#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 Flexomatic81

# Checks that the screenshot scene runs, without opening a window: renders it
# on the offscreen platform into the directory in NETSPEEDER_SCREENSHOT_DIR
# (created if missing). It passes when qml6 exits with 0, the scene reports
# "SCREENSHOTS OK", prints no warning, and all six files are readable PNG files
# without metadata. This is no review of the images: offscreen, Qt Quick
# Charts draws nothing, so the graph and the mini chart stay empty and the
# chart check of check-images.mjs is skipped. The real images come from
# scripts/screenshots.sh.
#
#   NETSPEEDER_SCREENSHOT_DIR=$(mktemp -d) tools/screenshots/offscreen-check.sh
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/screenshots/scene.sh
. "$here/scene.sh"

dir="${NETSPEEDER_SCREENSHOT_DIR:-}"
if [ -z "$dir" ]; then
  echo "offscreen-check: set NETSPEEDER_SCREENSHOT_DIR to the directory for the images" >&2
  exit 2
fi
mkdir -p "$dir" || exit 1
dir="$(cd "$dir" && pwd)"

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

QT_QPA_PLATFORM=offscreen LANGUAGE=en LC_ALL=C.UTF-8 LANG=C.UTF-8 QT_SCALE_FACTOR=1 run_scene "$dir" "$log"
rc=$?
output="$(cat "$log")"
unexpected="$(other_lines "$output")$(qml_problems "$output")"

status=0
if [ "$rc" -ne 0 ] || ! grep -q '^qml: SCREENSHOTS OK$' <<<"$output"; then
  echo "offscreen-check: the scene failed (exit $rc)" >&2
  status=1
fi
if [ -n "$unexpected" ]; then
  echo "offscreen-check: unexpected output:" >&2
  echo "$unexpected" >&2
  status=1
fi
node "$here/check-images.mjs" "$dir" --offscreen || status=1
exit "$status"
