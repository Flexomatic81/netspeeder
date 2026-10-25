#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 Flexomatic81

# Checks that the screenshot scene runs, without opening a window: renders it
# on the offscreen platform into the directory in NETSPEEDER_SCREENSHOT_DIR
# (created if missing), with the stock Breeze Dark color scheme as
# scripts/screenshots.sh uses it. It passes when qml6 exits with 0, the scene
# reports "SCREENSHOTS OK" and the background color of that scheme, prints no
# warning, all six files are readable PNG files without metadata, and the data
# cap bar of the popup is drawn. This is no review of the images: offscreen,
# Qt Quick Charts draws nothing, so the graph and the mini chart stay empty and
# the chart check of check-images.mjs is skipped. The real images come from scripts/screenshots.sh.
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

log="$(mktemp)" || exit 1
trap 'rm -f "$log"' EXIT
config="$(mktemp -d)" || exit 1
trap 'rm -rf "$log" "$config"' EXIT
setup_theme Dark "$config" || exit 1

QT_QPA_PLATFORM=offscreen LANGUAGE=en LC_ALL=C.UTF-8 LANG=C.UTF-8 QT_SCALE_FACTOR=1 run_scene "$dir" "$log" "$config"
rc=$?
output="$(cat "$log")"
unexpected="$(other_lines "$output")$(qml_problems "$output")"
theme="$(theme_problem "$output" "$(window_background "$(breeze_colors Dark)")")"

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
if [ -n "$theme" ]; then
  echo "offscreen-check: $theme" >&2
  status=1
fi
node "$here/check-images.mjs" "$dir" --offscreen "$log" || status=1
exit "$status"
