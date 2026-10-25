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

# run_scene <output directory> <log file> <config directory>: runs the scene
# with the environment of the caller, but with the configuration in the
# config directory only (see setup_theme), writes its output to the log file
# and shows it. Returns the exit status of qml6.
run_scene() {
  local dir="$1" log="$2" config="$3" root rc
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  # Qt logs to journald unless stderr is a terminal; force it to stderr so
  # console.log output reaches the log. The user's own configuration and the
  # defaults of the desktop theme (in XDG_CONFIG_DIRS) are left out; the
  # Plasma style reads the colors from kdeglobals in XDG_CONFIG_HOME.
  XDG_CONFIG_HOME="$config" XDG_CONFIG_DIRS=/etc/xdg QT_QUICK_CONTROLS_STYLE=org.kde.desktop \
    QT_FORCE_STDERR_LOGGING=1 timeout 60 qml6 "$root/tools/screenshots/Screenshots.qml" -- "$dir" >"$log" 2>&1
  rc=$?
  cat "$log"
  return "$rc"
}

# The stock color schemes the screenshots use.
color_schemes_dir="/usr/share/color-schemes"

# breeze_colors <Light|Dark>: the file of the stock Breeze color scheme.
breeze_colors() {
  echo "$color_schemes_dir/Breeze$1.colors"
}

# setup_theme <Light|Dark> <config directory>: writes a kdeglobals with the
# stock Breeze color scheme and icons into the directory, so the scene reads
# neither the colors nor any other setting of the user. Fails with a hint when
# the scheme is not installed.
setup_theme() {
  local variant="$1" config="$2" colors icons="breeze"
  colors="$(breeze_colors "$variant")"
  if [ ! -r "$colors" ]; then
    echo "the stock color scheme $colors is missing; install the Breeze theme of the distribution (it brings BreezeLight.colors and BreezeDark.colors)" >&2
    return 1
  fi
  if [ "$variant" = "Dark" ]; then
    icons="breeze-dark"
  fi
  {
    cat "$colors"
    printf '\n[General]\nColorScheme=Breeze%s\n\n[Icons]\nTheme=%s\n' "$variant" "$icons"
  } >"$config/kdeglobals"
}

# window_background <color scheme file>: the window background of the scheme
# ([Colors:Window] BackgroundNormal) as "#rrggbb".
window_background() {
  awk -F= '
    /^\[/ { inside = ($0 == "[Colors:Window]") }
    inside && $1 == "BackgroundNormal" { split($2, c, ","); printf "#%02x%02x%02x\n", c[1], c[2], c[3]; exit }
  ' "$1"
}

# theme_problem <output> <expected color>: prints why the scene in the output
# did not use the background color of the stock scheme; nothing when it did.
theme_problem() {
  local shown
  shown="$(sed -n 's/^qml: SCREENSHOT theme \(#[0-9a-f]*\)$/\1/p' <<<"$1" | head -n 1)"
  if [ "$shown" != "$2" ]; then
    echo "the scene used the background color ${shown:-(none reported)}, not $2 of the stock color scheme"
  fi
}
