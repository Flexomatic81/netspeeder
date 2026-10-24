#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 Flexomatic81

# Refuses a release whose gates are not met. The tag job of the CI workflow
# runs it before anything is built or published.
# Usage: scripts/release-check.sh <version>
# Checks, all of them, and reports every problem before it fails:
# - package/metadata.json has the Version <version>;
# - CHANGELOG.md has a heading "## <version> – <date>" (date as YYYY-MM-DD)
#   that does not say "unreleased";
# - the screenshots in docs/images exist and are PNG files;
# - the table "Release record <version>" in docs/testing.md exists and every
#   row has a date and a result.
# Needs only bash and the base tools (sed, awk, od), like the build container.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  echo "usage: scripts/release-check.sh <version>" >&2
  exit 2
fi
version="$1"

SCREENSHOTS="panel-rows panel-single panel-vertical panel-colors panel-sparkline popup"
PNG_SIGNATURE="89504e470d0a1a0a"
problems=0

fail() {
  echo "release-check: $*" >&2
  problems=$((problems + 1))
}

check_metadata() {
  local found
  found="$(sed -n 's/^[[:space:]]*"Version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*$/\1/p' package/metadata.json 2> /dev/null | head -n 1 || true)"
  if [ "$found" != "$version" ]; then
    fail "package/metadata.json has Version '${found:-none}', expected '$version'"
  fi
}

check_changelog() {
  local heading
  if [ ! -f CHANGELOG.md ]; then
    fail "CHANGELOG.md is missing"
    return
  fi
  heading="$(awk -v v="$version" '$1 == "##" && $2 == v { print; exit }' CHANGELOG.md)"
  if [ -z "$heading" ]; then
    fail "CHANGELOG.md has no heading '## $version'"
  elif printf '%s\n' "$heading" | grep -qi 'unreleased'; then
    fail "CHANGELOG.md still marks $version as unreleased: $heading"
  elif ! printf '%s\n' "$heading" | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}'; then
    fail "CHANGELOG.md heading for $version has no release date (YYYY-MM-DD): $heading"
  fi
}

check_screenshots() {
  local name file signature
  for name in $SCREENSHOTS; do
    file="docs/images/$name.png"
    if [ ! -s "$file" ]; then
      fail "$file is missing or empty"
      continue
    fi
    signature="$(head -c 8 "$file" | od -An -tx1 | tr -d ' \n')"
    if [ "$signature" != "$PNG_SIGNATURE" ]; then
      fail "$file is not a PNG file"
    fi
  done
}

# Prints one line per row of the release record table that lacks a date or a
# result, or "missing" when there is no table with at least one row.
incomplete_record_rows() {
  awk -v title="## Release record $version" '
    $0 == title { inside = 1; next }
    inside && /^## / { inside = 0 }
    !inside || !/^\|/ { next }
    {
      rows++
      if (rows <= 2) next  # header and separator
      n = split($0, cell, "|")
      for (i = 1; i <= n; i++) gsub(/^[[:space:]]+|[[:space:]]+$/, "", cell[i])
      if (cell[3] == "" || cell[4] == "") print cell[2]
    }
    END { if (rows < 3) print "missing" }
  ' docs/testing.md
}

check_record() {
  local rows row
  if [ ! -f docs/testing.md ]; then
    fail "docs/testing.md is missing"
    return
  fi
  rows="$(incomplete_record_rows)"
  if [ "$rows" = "missing" ]; then
    fail "docs/testing.md has no table 'Release record $version' with gate rows"
    return
  fi
  while IFS= read -r row; do
    if [ -n "$row" ]; then
      fail "release record $version: no date or result for gate $row"
    fi
  done <<< "$rows"
}

check_metadata
check_changelog
check_screenshots
check_record

if [ "$problems" -gt 0 ]; then
  echo "release-check: $version is not ready for release ($problems problems)" >&2
  exit 1
fi
echo "release-check: $version passes all release gates"
