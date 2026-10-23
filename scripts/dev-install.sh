#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 Flexomatic81

# Installs the plasmoid from package/ into ~/.local/share/plasma/plasmoids for
# development (upgrades an existing installation).
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Compiles the translations if the script for it exists.
if [ -x scripts/build-mo.sh ]; then
  scripts/build-mo.sh
fi

kpackagetool6 --type Plasma/Applet --upgrade package \
  || kpackagetool6 --type Plasma/Applet --install package

cat <<'MSG'

Installed. A running panel keeps the old version until plasmashell restarts:
  systemctl --user restart plasma-plasmashell
This script does not do that for you. To try the new version in a window
without touching the panel, run scripts/run.sh.
MSG
