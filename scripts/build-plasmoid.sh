#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 Flexomatic81

# Builds the installable package dist/netspeeder-<version>.plasmoid: a zip of
# package/metadata.json and package/contents, including the compiled
# translations. kpackagetool6 --install, the "Install Widget From Local File"
# dialog and the KDE Store all take this file.
# Usage: scripts/build-plasmoid.sh <version>
# <version> has to match the Version field of package/metadata.json (without a
# leading "v"), so a release tag can never ship a package of another version.
# Needs msgfmt (gettext) and bsdtar (libarchive); there is no zip tool in the
# minimal build container, and bsdtar writes zip archives.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  echo "usage: scripts/build-plasmoid.sh <version>" >&2
  exit 2
fi
version="$1"

# Reads the version without a JSON tool: the minimal build container has no
# python or jq. metadata.json carries exactly one "Version" key.
metadata_version="$(sed -n 's/^[[:space:]]*"Version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*$/\1/p' package/metadata.json | head -n 1)"
if [ -z "$metadata_version" ]; then
  echo "build-plasmoid: no Version field found in package/metadata.json" >&2
  exit 1
fi
if [ "$version" != "$metadata_version" ]; then
  echo "build-plasmoid: version '$version' does not match package/metadata.json ('$metadata_version')" >&2
  exit 1
fi

if ! command -v bsdtar > /dev/null; then
  echo "build-plasmoid: bsdtar not found (package libarchive)" >&2
  exit 1
fi

# The locale directory is pure build output. Starting from an empty one keeps
# the translation of a removed language out of the package.
rm -rf package/contents/locale
scripts/build-mo.sh

mkdir -p dist
out="$PWD/dist/netspeeder-${version}.plasmoid"
rm -f "$out"
(cd package && bsdtar --format zip -cf "$out" metadata.json contents)

echo "build-plasmoid: wrote ${out#"$PWD"/}"
