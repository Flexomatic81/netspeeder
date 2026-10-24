<!--
SPDX-License-Identifier: GPL-2.0-or-later
SPDX-FileCopyrightText: 2026 Flexomatic81
-->

# Changelog

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
- Robust rates: interfaces that disappear and return, counter resets and
  suspend/resume cause no spikes and no stale values.
- Tooltip with connection name, download, upload and IP address, and a note
  about the data source if there is a problem.
- Settings pages "Display" and "Data"; the data page lists all interfaces with
  their kind and current speed.
- German translation.
- Build and release tooling: CMake installation for distribution packages,
  `scripts/build-plasmoid.sh` for the `.plasmoid` file, continuous integration
  (tests on Node 22 and 24, QML lint, `.plasmoid` as release asset for version
  tags).

### Fixed (issues of the original Netspeed Widget)

- #36: settings jump back to their old values. Selection lists share one
  component that sets the index only on creation and on a change of the bound
  value, and writes back only on a user action. List settings are replaced as a
  whole, never changed in place.
- #46: DataSource error. It does not apply to the default data source any more,
  which reads `ksystemstats` instead of a DataSource engine.
- #48: build failure with CMake 4. The new `CMakeLists.txt` requires CMake 3.16
  and extra-cmake-modules 6. The CMake files were verified against a stub of
  extra-cmake-modules only; the real build is to be verified before release.
- #11 and #27: overlapping text and wrong margins. The panel view is built from
  Qt layouts with fixed-width slots instead of manual aspect ratio
  calculations.

Upstream #24 (empty window when scrolling over the widget) and #47 (crash when
deselecting an option) are addressed by the design; to be verified by hand
before release, see [docs/testing.md](docs/testing.md).
