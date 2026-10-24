<!--
SPDX-License-Identifier: GPL-2.0-or-later
SPDX-FileCopyrightText: 2026 Flexomatic81
-->

# Changelog

## 0.4.0 (unreleased)

Fourth pre-release, stage "Verbrauch" (usage).

### Added

- Data usage from vnStat (version 2.0 or newer, optional): the popup shows
  today, yesterday, this billing period and the last one, each with download,
  upload and total. An asterisk marks a period that vnStat does not cover
  completely. The popup also shows when vnStat last updated its data, with a
  hint after an hour, and hints when vnStat is missing (with a link), when its
  version is not supported and when an interface is not tracked by vnStat.
- Optional monthly data cap with a billing day (1 to 28) and a warning level.
  The popup shows the share as a bar (neutral color from the warning level,
  negative from 100 %); the panel shows a dot from the warning level on, and
  its accessible name mentions the cap.
- A "Today" line in the tooltip.
- Desktop notifications when the warning level and when 100 % are reached,
  once per level and billing period, kept across restarts. Turning
  notifications off still records the level, so turning them on later does not
  report old levels; a jump straight past 100 % reports only that level.
- Settings page "Usage" with the options above.
- German translation of the new texts.

### Notes

- Manual interface selection counts the configured interfaces even while they
  are absent. Automatic selection counts the interfaces vnStat knows, minus
  `lo` and every interface the widget has seen as virtual, present or not;
  names vnStat no longer knows are forgotten. A virtual interface the widget
  has never seen counts until it appears once.
- The data cap is checked only once the interfaces are known, so a vnStat
  reading at login cannot count a tunnel.
- vnStat is read in the background only while usage is enabled.

## 0.3.0 (unreleased)

Third pre-release, stage "Darstellung" (appearance).

### Added

- Settings page "Appearance": font and bold, text size (50 to 200 %), symbol
  style (arrows, triangles, icons, none, custom), color mode (theme, by
  direction, by speed with up to six levels), optional coloring of units and
  symbols, fixed width and a sparkline (off, behind or beside the values).
- Threshold editor that keeps the levels distinct; invalid stored levels are
  dropped, and the defaults apply only when no level is usable.
- Auto-hide on the page "Behavior": never, when offline, or when offline or
  idle, with a threshold of 1 to 1024 KiB/s and a duration in seconds. The panel
  collapses a hidden widget; in edit mode it shows a dimmed network icon. It
  never hides on the desktop, while the popup is open, before the first
  data arrives, or while the data is stale.
- German translation of the new texts.

### Notes

- Text sizes above 100 % are capped so the text line fits its row.
- In a vertical panel the sparkline "beside" behaves like "behind".
- The sparkline scale starts at 0 and covers at least 1 KiB/s.

## 0.2.0 (unreleased)

Second pre-release, stage "Popup".

### Added

- Popup (also used as the desktop view) with a header showing the live speeds,
  the connection state and a hint on data source errors; a traffic graph with
  1, 5 and 15 minute windows; peaks and session totals; a scrollable interface
  list with kind, totals and a copyable IPv4 address; an "Open System Monitor"
  button and the active data source.
- The selected graph window is stored in the configuration and survives a
  restart.
- The graph is loaded in isolation: without Qt Quick Charts only the graph is
  hidden, with a note, and the rest of the popup works.
- Desktop view: placed on the desktop, the widget shows the popup view
  directly.
- Configurable clicks: the left click opens the popup or starts the launch
  target; the middle click can also do nothing.
- Launch target: an application (desktop ID chosen in a file dialog) or a
  command. The target is pre-checked; an unknown application or a missing
  command gives a notification, and a start that does not respond times out.
- Settings page "Behavior" with a warning when neither click opens the popup.
- The provider keeps a rolling traffic history with peaks and session totals;
  it records all the time, and only the popup redraws while it or the desktop
  view is visible.
- German translation of the new texts.

### Known limitations

- Desktop IDs in subdirectories of the applications folders are not found.
- A command is pre-checked only when its first word is a plain name or a path.
- A program that crashes after it started is not detected.
- The x axis of the graph is per sample, not a wall-clock scale.

## 0.1.0 (unreleased)

First pre-release, stage "Kern" (core).

### Added

- Panel view with download and upload speed: two rows or side by side
  (automatic by panel height, always stacked in a vertical panel), optional
  upload-first order and a combined value. Digits have a fixed width and the
  panel reserves the width of the widest value, so it does not jump.
- Units: bytes with binary prefixes (KiB/s), bytes with decimal prefixes
  (kB/s) or bits (Mbit/s), short unit names, decimal places, a threshold below
  which speeds show as 0, and an update interval from 0.5 to 10 seconds.
- Data source "system sensors" (`ksystemstats`) as the default; it starts no
  process at an update.
- Data source "kernel counters" (`/proc/net/dev`) as the fallback. In
  automatic mode Netspeeder switches to it when the sensor module does not
  load or reports no network interface for ten seconds.
- Interface detection by device type: the automatic total covers physical
  devices only, so VPN and Docker traffic is not counted twice. Manual
  selection of the interfaces as an alternative. A selection that points to an
  interface that is gone shows 0 and a note in the tooltip.
- Robust rates: interfaces that disappear and return and counter resets cause
  no spikes and no stale values. Suspend/resume is guarded against in the
  `/proc` source; on the sensor path the rates come from `ksystemstats`. To be
  verified by hand before release.
- Tooltip with connection name, download, upload and IP address, and a note
  about the data source if there is a problem.
- Settings pages "Display" and "Data"; the data page lists all interfaces with
  their kind and current speed.
- German translation.
- Build and release tooling: CMake installation for distribution packages,
  `scripts/build-plasmoid.sh` for the `.plasmoid` file, a continuous integration
  workflow (tests on Node 22.13 and 24, QML lint, shellcheck, `.plasmoid` as
  release asset for version tags), which has not run yet.

### Development

- Development checks: ESLint, Prettier, coverage floor, strict qmllint,
  shellcheck, one check runner (`node tools/check.mjs`) used locally and by
  the pre-commit hook and wired into the CI workflow.
- Branch coverage of the logic modules is 100 %; the coverage floor for
  branches is 98 %.
- Visible texts go through per-file translation helpers (`tr`, `trc`, `trp`)
  that call Plasma's i18n functions and fall back to English where they are
  not available. The message keys are unchanged, and texts in the `.mjs`
  modules are now extracted as well.
- The list synchronisation shared by the sensor source and the settings page
  lives in one tested module, and the tooltip text selection in another.
- The QML smoke runs are strict: a scene fails on a non-zero exit or on any
  engine warning outside its per-scene allow-list.
- Build scripts check for `po/` and `msgfmt` before they act, drop outdated
  translations and leave editor leftovers out of the package.

### Addressed (issues of the original Netspeed Widget)

- #36: settings jump back to their old values. Selection lists share one
  component that sets the index only on creation and on a change of the bound
  value, and writes back only on a user action. List settings are replaced as a
  whole, never changed in place. Addressed (ConfigComboBox syncs after
  creation, smoke-tested); to be verified in the real settings dialog before
  release.
- #46: DataSource error. Mitigated: the default path reads `ksystemstats`
  instead of a DataSource engine; Plasma5Support is still used for device
  classification and the `/proc` fallback.
- #48: build failure with CMake 4. The new `CMakeLists.txt` requires CMake 3.16
  and extra-cmake-modules 6. The CMake files were verified against a stub of
  extra-cmake-modules only; the real build is to be verified before release.
- #11 and #27: overlapping text and wrong margins. The panel view is built from
  Qt layouts with fixed-width slots instead of manual aspect ratio
  calculations. Addressed by the new layout; to be verified in a real panel
  before release (the automated smoke scenes cover the sizes, not a real
  panel).

Upstream #24 (empty window when scrolling over the widget) and #47 (crash when
deselecting an option) are addressed by the design; to be verified by hand
before release, see [docs/testing.md](docs/testing.md).
