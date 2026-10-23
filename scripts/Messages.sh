#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 Flexomatic81

# Extracts the translatable strings of the plasmoid into the message template
# and merges the template into every existing translation
# (po/<lang>/<domain>.po). Run it after every change to a visible string and
# commit the result.
#
# QML is read as JavaScript: the i18n calls are plain call expressions, also
# inside the `typeof i18nc === "function" ? ... : ...` guards, so xgettext's
# JavaScript parser finds them without preprocessing.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

domain="plasma_applet_io.github.flexomatic81.netspeeder"
pot="po/${domain}.pot"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The sorted file list keeps the template identical across file systems.
find package -name '*.qml' | LC_ALL=C sort > "$work/files"

xgettext --from-code=UTF-8 --language=JavaScript \
  --keyword=i18n:1 --keyword=i18nc:1c,2 --keyword=i18np:1,2 --keyword=i18ncp:1c,2,3 \
  --package-name=netspeeder \
  --msgid-bugs-address=https://github.com/Flexomatic81/netspeeder/issues \
  --files-from="$work/files" \
  --output="$work/raw.pot"

# xgettext writes a placeholder comment block above the header entry; replace
# it with the SPDX lines every file of the project starts with.
{
  printf '%s\n' \
    '# SPDX-License-Identifier: GPL-2.0-or-later' \
    '# SPDX-FileCopyrightText: 2026 Flexomatic81' \
    '#'
  sed -n '/^msgid ""$/,$p' "$work/raw.pot"
} > "$work/new.pot"

# Rewrite the template only when a message changed: the creation date alone
# must not turn every run into a diff (and a merge of every translation).
without_date() {
  grep -v '^"POT-Creation-Date:' "$1"
}
mkdir -p po
if [ ! -f "$pot" ] || ! diff -q <(without_date "$pot") <(without_date "$work/new.pot") > /dev/null; then
  cp "$work/new.pot" "$pot"
  echo "Messages: updated $pot"
else
  echo "Messages: $pot is up to date"
fi

while IFS= read -r po; do
  msgmerge --update --backup=none --quiet "$po" "$pot"
  echo "Messages: merged into $po"
  # Shows how many messages the merge left untranslated or fuzzy.
  msgfmt --statistics -o /dev/null "$po"
done < <(find po -mindepth 2 -maxdepth 2 -name "${domain}.po" | LC_ALL=C sort)
