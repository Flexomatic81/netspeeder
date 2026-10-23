#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 Flexomatic81

# Compiles every po/<lang>/<domain>.po into the package, where Plasma looks
# for the translations of an installed plasmoid:
# package/contents/locale/<lang>/LC_MESSAGES/<domain>.mo
# The .mo files are build output (gitignored). scripts/dev-install.sh calls
# this script before installing.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

domain="plasma_applet_io.github.flexomatic81.netspeeder"

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
