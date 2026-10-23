#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 Flexomatic81

# Opens the installed plasmoid in its own window, without touching the panel.
# Install the current state first with scripts/dev-install.sh.
set -euo pipefail

exec plasmawindowed io.github.flexomatic81.netspeeder
