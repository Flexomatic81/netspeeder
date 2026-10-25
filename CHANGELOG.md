<!--
SPDX-License-Identifier: GPL-2.0-or-later
SPDX-FileCopyrightText: 2026 Flexomatic81
-->

# Changelog

## 1.0.0 – unreleased

First stable release. The date is set in this heading as YYYY-MM-DD when it
is published (`## 1.0.0 – 2026-11-15`).

### Added

- Panel view with download and upload speed: two rows or side by side
  (automatic by panel height, always stacked in a vertical panel), optional
  upload-first order and a combined value. Digits have a fixed width and the
  panel reserves the width of the widest value, so it does not jump.
- Units: bytes with binary prefixes (KiB/s), bytes with decimal prefixes
  (kB/s) or bits (Mbit/s), short unit names, decimal places, a threshold below
  which speeds show as 0, and an update interval from 0.5 to 10 seconds.
- Data source "system sensors" (`ksystemstats`) as the default; it starts no
  process at an update. Data source "kernel counters" (`/proc/net/dev`) as the
  fallback. In automatic mode Netspeeder switches to it when the sensor module
  does not load or reports no network interface for ten seconds. It also
  recovers when the sensor service starts late, and reports a failed fallback.
  The sensor heartbeat is armed only after it changes for the first time.
- Interface detection by device type: the automatic total covers physical
  devices only, so VPN and Docker traffic is not counted twice. Manual
  selection of the interfaces as an alternative. A selection that points to an
  interface that is gone shows 0 and a note in the tooltip.
- Robust rates: interfaces that disappear and return and counter resets cause
  no spikes and no stale values. Suspend/resume is guarded against in the
  `/proc` source; on the sensor path the rates come from `ksystemstats`. To be
  verified by hand before release.
- Tooltip with connection name, download, upload, today's usage and IP address,
  and a note about the data source if there is a problem.
- Popup (also used as the desktop view) with a header showing the live speeds,
  the connection state and a hint on data source errors; a traffic graph with
  1, 5 and 15 minute windows (the selected window is stored); peaks and session
  totals; a scrollable interface list with kind, totals and a copyable IPv4
  address; an "Open System Monitor" button and the active data source. The
  graph is loaded in isolation: without Qt Quick Charts only the graph is
  hidden, with a note, and the rest of the popup works.
- Configurable clicks: the left click opens the popup or starts the launch
  target; the middle click can also do nothing. Launch target: an application
  (desktop ID chosen in a file dialog, including applications in subfolders of
  the applications directories, and roots with spaces or accents) or a command.
  The target is pre-checked; an unknown application or a missing command gives
  a notification, and a start that does not respond times out.
- Settings page "Appearance": font and bold, text size (50 to 200 %), symbol
  style (arrows, triangles, icons, none, custom), color mode (theme, by
  direction, by speed with up to six levels), optional coloring of units and
  symbols, fixed width and a sparkline (off, behind or beside the values). The
  threshold editor keeps the levels distinct; invalid stored levels are
  dropped, and the defaults apply only when no level is usable.
- Auto-hide: never, when offline, or when offline or idle, with a threshold of
  1 to 1024 KiB/s and a duration in seconds. The panel collapses a hidden
  widget; in edit mode it shows a dimmed network icon. It never hides on the
  desktop, while the popup is open, before the first data arrives, or while
  the data is stale.
- Data usage from vnStat (version 2.0 or newer, optional): the popup shows
  today, yesterday, this billing period and the last one, each with download,
  upload and total. An asterisk marks a period that vnStat does not cover
  completely. The popup also shows when vnStat last updated its data, with a
  hint after an hour, and hints when vnStat is missing (with a link), when its
  version is not supported and when an interface is not tracked by vnStat.
- Optional monthly data cap with a billing day (1 to 28) and a warning level.
  The popup shows the share as a bar (neutral color from the warning level,
  negative from 100 %); the panel shows a dot from the warning level on.
  Desktop notifications at the warning level and at 100 %, once per level and
  billing period, kept across restarts. Turning notifications off still
  records the level, so turning them on later does not report old levels; a
  jump straight past 100 % reports only that level.
- Settings pages "Display", "Data", "Appearance", "Behavior" and "Usage". The
  page "Behavior" warns when neither click opens the popup.
- German translation.
- Accessibility: the panel view has an accessible name and description,
  including the data cap state.
- Documentation: a README with a migration guide from the original Netspeed
  Widget and the store text, a compatibility document (Plasma 6.3 and newer)
  and the manual test list in [docs/testing.md](docs/testing.md).
- Tooling: a screenshot tool (`scripts/screenshots.sh`) that renders demo data,
  and an actionlint step for the workflow files.
- Build and release tooling: `scripts/build-plasmoid.sh` for the `.plasmoid`
  file, a continuous integration workflow (tests on Node 22.13 and 24, QML
  lint, shellcheck, actionlint, `.plasmoid` as release asset for version tags)
  and `scripts/release-check.sh`, which stops a release tag while the
  changelog, the screenshots or the release record are not final. The
  changelog heading of a release carries its date as YYYY-MM-DD, for example
  `## 1.0.0 – 2026-11-15`.
- Development checks: ESLint, Prettier, coverage floor (branch coverage of the
  logic modules is 100 %, the floor is 98 %), strict qmllint, shellcheck, one
  check runner (`node tools/check.mjs`) used locally, by the pre-commit hook and
  by the CI workflow.

### Changed

- Manual interface selection counts the configured interfaces even while they
  are absent. Automatic selection counts the interfaces vnStat knows, minus
  `lo` and every interface the widget has seen as virtual, present or not;
  names vnStat no longer knows are forgotten.
- The data cap is checked only once the interfaces are known, so a vnStat
  reading at login cannot count a tunnel. vnStat is read in the background
  only while usage is enabled.
- Text sizes above 100 % are capped so the text line fits its row. In a
  vertical panel the sparkline "beside" behaves like "behind". The sparkline
  scale starts at 0 and covers at least 1 KiB/s.
- The provider keeps a rolling traffic history with peaks and session totals;
  it records all the time, and only the popup redraws while it or the desktop
  view is visible.
- Visible texts go through per-file translation helpers (`tr`, `trc`, `trp`)
  that call Plasma's i18n functions and fall back to English where they are
  not available.
- Build scripts check for `po/` and `msgfmt` before they act, drop outdated
  translations and leave editor leftovers out of the package. The QML smoke
  runs are strict: a scene fails on a non-zero exit or on any engine warning
  outside its per-scene allow-list.

### Fixed

- Settings jumping back to their old values (upstream #36): selection lists
  share one component that sets the index only on creation and on a change of
  the bound value, and writes back only on a user action. List settings are
  replaced as a whole, never changed in place. Smoke-tested; to be verified in
  the real settings dialog before release.
- DataSource error (upstream #46), mitigated: the default path reads
  `ksystemstats` instead of a DataSource engine; Plasma5Support is still used
  for device classification and the `/proc` fallback.
- Build failure with CMake 4 (upstream #48): Netspeeder has no CMake build;
  it is installed from the KDE Store or as a `.plasmoid` file.
- Overlapping text and wrong margins (upstream #11 and #27): the panel view is
  built from Qt layouts with fixed-width slots instead of manual aspect ratio
  calculations. The smoke scenes cover the sizes, not a real panel; to be
  verified in a real panel before release.
- Empty window when scrolling over the widget (upstream #24) and crash when
  deselecting an option (upstream #47) are addressed by the design; to be
  verified by hand before release.
- Remembered virtual interfaces no longer enter the usage totals, data cap
  notifications wait until the interfaces are known, and an empty usage line
  no longer shows in the tooltip.

### Known limitations and open checks

- CI is set up but has never run.
- Suspend/resume (no speed spike and no stale values after waking up) is still
  to be verified by hand before release.
- The x axis of the graph is per sample, not a wall-clock scale.
- A virtual interface that is absent in automatic mode and that the widget has
  never seen cannot be recognized; it counts until it appears once.
- A desktop ID is a path relative to the applications directories with `/`
  replaced by `-`; IDs that do not follow this rule are not found.
- A command is pre-checked only when its first word is a plain name or a path.
- A program that crashes after it started is not detected.
- Tested on Plasma 6.8 only. Plasma 6.3 to 6.7 are checked against their
  source code, not run; see [docs/compatibility.md](docs/compatibility.md).
- The manual checks are listed in [docs/testing.md](docs/testing.md) and are
  still to be done before release.
