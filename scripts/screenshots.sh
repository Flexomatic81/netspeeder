#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 Flexomatic81

# Renders the screenshots for the documentation from fixed demo data
# (tools/screenshots/Screenshots.qml) and saves them to docs/images/, or to
# NETSPEEDER_SCREENSHOT_DIR when that is set. Opens a window for a few seconds:
# the scene runs on the real display, because Qt Quick Charts draws nothing on
# the offscreen platform. Needs a Plasma session, qml6, the locale en_US.UTF-8
# and the stock Breeze color schemes (/usr/share/color-schemes). Language,
# locale, scale factor, window size, font and colors are fixed: the scene runs
# with a temporary configuration that holds only the stock Breeze Dark scheme,
# so it neither reads nor changes the settings of the desktop.
#
#   scripts/screenshots.sh           Breeze Dark, into docs/images/ (the published images)
#   scripts/screenshots.sh --light   Breeze Light, the same files into docs/images/light/
#   scripts/screenshots.sh --store   at twice the size, into docs/store/shots/ (the parts of
#                                    the store images, see docs/store.md); combines with --light
#
# Afterwards check-images.mjs checks the files: all are there, carry no
# metadata, and the chart area of the popup is not one plain color. Look at
# every image before committing it: an image can show text no search finds.
# To only check that the scene runs, without a window, use
# tools/screenshots/offscreen-check.sh.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tools/screenshots/scene.sh
. "$root/tools/screenshots/scene.sh"

variant="Dark"
scale=1
for arg in "$@"; do
  case "$arg" in
    --light) variant="Light" ;;
    --store) scale=2 ;;
    *)
      echo "usage: scripts/screenshots.sh [--light] [--store]" >&2
      exit 2
      ;;
  esac
done

if [ "${QT_QPA_PLATFORM:-}" = "offscreen" ]; then
  echo "screenshots: QT_QPA_PLATFORM=offscreen draws no charts; unset it and run on the real display" >&2
  exit 1
fi
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -z "${DISPLAY:-}" ]; then
  echo "screenshots: no display found; run this inside the Plasma session" >&2
  exit 1
fi
if ! locale -a 2>/dev/null | grep -Eqx 'en_US\.(utf8|UTF-8)'; then
  echo "screenshots: the locale en_US.UTF-8 is missing; enable it (e.g. in /etc/locale.gen, then locale-gen) and run again" >&2
  exit 1
fi
for tool in qml6 node; do
  if ! command -v "$tool" >/dev/null; then
    echo "screenshots: $tool not found" >&2
    exit 1
  fi
done

default_dir="$root/docs/images"
if [ "$scale" -ne 1 ]; then
  default_dir="$root/docs/store/shots"
fi
dir="${NETSPEEDER_SCREENSHOT_DIR:-$default_dir}"
if [ "$variant" = "Light" ]; then
  dir="$dir/light"
fi
mkdir -p "$dir" || exit 1
dir="$(cd "$dir" && pwd)"
# The directory as shown: relative to the repository when it is inside it, so
# pasted output carries no home path.
shown="${dir#"$root"/}"

log="$(mktemp)" || exit 1
trap 'rm -f "$log"' EXIT
config="$(mktemp -d)" || exit 1
trap 'rm -rf "$log" "$config"' EXIT
if ! setup_theme "$variant" "$config"; then
  echo "screenshots: no stock color scheme, nothing rendered" >&2
  exit 1
fi
echo "screenshots: theme: Breeze $variant (the stock color scheme, not the one of this desktop), scale $scale"
echo "screenshots: writing to $shown"

LANGUAGE=en LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 QT_SCALE_FACTOR="$scale" run_scene "$dir" "$log" "$config"
rc=$?
output="$(cat "$log")"
problems="$(qml_problems "$output")"
others="$(other_lines "$output")"

status=0
if [ "$rc" -ne 0 ] || ! grep -q '^qml: SCREENSHOTS OK$' <<<"$output"; then
  echo "screenshots: the scene failed (exit $rc)" >&2
  status=1
fi
if [ -n "$problems" ]; then
  echo "screenshots: QML problems:" >&2
  echo "$problems" >&2
  status=1
fi
theme="$(theme_problem "$output" "$(window_background "$(breeze_colors "$variant")")")"
if [ -n "$theme" ]; then
  echo "screenshots: $theme" >&2
  status=1
fi
if [ -n "$others" ]; then
  echo "screenshots: note, other output of qml6 (platform messages; check that none matters):" >&2
  echo "$others" >&2
fi
node "$root/tools/screenshots/check-images.mjs" "$dir" --log "$log" || status=1
if [ "$status" -eq 0 ]; then
  echo "screenshots: done. Look at every image in $shown before committing it."
fi
exit "$status"
