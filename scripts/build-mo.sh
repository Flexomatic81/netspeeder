#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 Flexomatic81

# Compiles every po/<lang>/<domain>.po into the package, where Plasma looks
# for the translations of an installed plasmoid:
# package/contents/locale/<lang>/LC_MESSAGES/<domain>.mo
# The .mo files are build output (gitignored). scripts/dev-install.sh calls
# this script before installing. Translations of languages whose .po file no
# longer exists are removed from the package.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

domain="plasma_applet_io.github.flexomatic81.netspeeder"

if [ ! -d po ]; then
  echo "build-mo: directory po/ not found" >&2
  exit 1
fi
if ! command -v msgfmt > /dev/null; then
  echo "build-mo: msgfmt not found (package gettext)" >&2
  exit 1
fi

# Outdated build output: a .mo whose language has no .po any more.
locale_root="package/contents/locale"
if [ -d "$locale_root" ]; then
  while IFS= read -r mo; do
    lang="$(basename "$(dirname "$(dirname "$mo")")")"
    if [ ! -f "po/${lang}/${domain}.po" ]; then
      rm -f "$mo"
      rmdir --ignore-fail-on-non-empty -p "$(dirname "$mo")" 2> /dev/null || true
      echo "build-mo: removed outdated $mo"
    fi
  done < <(find "$locale_root" -mindepth 3 -maxdepth 3 -name "${domain}.mo" | LC_ALL=C sort)
fi

count=0
while IFS= read -r po; do
  lang="$(basename "$(dirname "$po")")"
  out="package/contents/locale/${lang}/LC_MESSAGES/${domain}.mo"
  mkdir -p "$(dirname "$out")"
  msgfmt --check -o "$out" "$po"
  echo "build-mo: $po -> $out"
  count=$((count + 1))
done < <(find po -mindepth 2 -maxdepth 2 -name "${domain}.po" | LC_ALL=C sort)

echo "build-mo: $count translation(s) compiled"
