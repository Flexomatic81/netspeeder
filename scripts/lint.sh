#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 Flexomatic81

# Lints every QML file under package/ and tests/qml/ with the Qt 6 qmllint.
# Names that exist only at Plasma runtime must be silenced on the one affected
# line with a `// qmllint disable <category>` comment that says why.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# /usr/bin/qmllint is the Qt 5 tool; the Qt 6 one lives in the Qt libexec dir.
qmllint="${QMLLINT:-/usr/lib/qt6/bin/qmllint}"

dirs=()
for dir in package tests/qml; do
  if [ -d "$dir" ]; then
    dirs+=("$dir")
  fi
done

files=()
if [ "${#dirs[@]}" -gt 0 ]; then
  while IFS= read -r file; do
    files+=("$file")
  done < <(find "${dirs[@]}" -name '*.qml' | sort)
fi

if [ "${#files[@]}" -eq 0 ]; then
  echo "lint: no QML files found"
  exit 0
fi

"$qmllint" --unqualified disable --max-warnings 0 "${files[@]}"
echo "lint: ${#files[@]} QML files OK"
