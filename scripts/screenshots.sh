#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 Flexomatic81

# Renders the screenshots for the documentation from fixed demo data
# (tools/screenshots/Screenshots.qml) and saves them to docs/images/, or to
# NETSPEEDER_SCREENSHOT_DIR when that is set. Opens a window for a few seconds:
# the scene runs on the real display, because Qt Quick Charts draws nothing on
# the offscreen platform. Needs a Plasma session (the colors come from the
# current color scheme, which the script names), qml6 and the locale
# en_US.UTF-8. Language, locale, scale factor, window size and font are fixed.
#
# Afterwards check-images.mjs checks the files: all six are there, carry no
# metadata, and the chart area of the popup is not one plain color. Look at
# every image before committing it: an image can show text no search finds.
# To only check that the scene runs, without a window, use
# tools/screenshots/offscreen-check.sh.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tools/screenshots/scene.sh
. "$root/tools/screenshots/scene.sh"

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

dir="${NETSPEEDER_SCREENSHOT_DIR:-$root/docs/images}"
mkdir -p "$dir" || exit 1
dir="$(cd "$dir" && pwd)"

scheme=""
if command -v kreadconfig6 >/dev/null; then
  scheme="$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)"
fi
echo "screenshots: color scheme: ${scheme:-not set (the Plasma default)}"
echo "screenshots: writing to $dir"

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

LANGUAGE=en LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 QT_SCALE_FACTOR=1 run_scene "$dir" "$log"
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
if [ -n "$others" ]; then
  echo "screenshots: note, other output of qml6 (platform messages; check that none matters):" >&2
  echo "$others" >&2
fi
node "$root/tools/screenshots/check-images.mjs" "$dir" --log "$log" || status=1
if [ "$status" -eq 0 ]; then
  echo "screenshots: done. Look at every image in $dir before committing it."
fi
exit "$status"
