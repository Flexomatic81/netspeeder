<!--
SPDX-License-Identifier: GPL-2.0-or-later
SPDX-FileCopyrightText: 2026 Flexomatic81
-->

# Manual tests

This checklist is worked through before every release. The
automatic tests (`node tools/check.mjs`; CI runs the steps of the group `fast`,
`shellcheck` and `qmllint`) do not replace it: they check logic and single
scenes, not the behavior in a real panel.

Procedure: install the current version (`scripts/dev-install.sh`), restart
plasmashell (`systemctl --user restart plasma-plasmashell`), go through the
items of the respective stage and enter the result in the "Result" column:
"OK", "Fail" with a reference to the observation, or "n/a" with the reason.
Note version, date and Plasma version at the top for each run, or copy the
table; empty cells count as not checked.

Where a check names a text of the interface, the German wording is given too,
because the checker compares it against the German interface.

- Version:
- Date:
- Plasma version:

## Panel appearance

| Check | Stage | Result |
|---|---|---|
| Horizontal panel at default height: download and upload readable, the values change without the panel jumping or text overlapping (upstream #11, #27) | 0.1 | |
| Vertical panel: directions stacked, value and unit readable, no overlap | 0.1 | |
| Panel sizes: horizontal 20 px, 44 px and 96 px and vertical about 32 px wide: display readable, no overlap, nothing cut off | 0.1 | |
| Desktop placement (planar, widget directly on the desktop): shows something sensible in 0.1; the popup view for the desktop belongs to 0.2 (see below) | 0.1 | |
| Light and dark theme: text easy to read in both | 0.1 | |
| Font scaling 150 %: panel view and settings pages stay readable and are not cut off | 0.1 | |
| Tooltip in a real panel: connection name, download line, upload line and IP address appear | 0.1 | |

## Network situations

| Check | Stage | Result |
|---|---|---|
| VPN active: the traffic inside the tunnel is not counted twice in the automatic total | 0.1 | |
| Docker active (docker0, veth, bridges): container traffic is not in the automatic total | 0.1 | |
| Data source "Kernel counters" (`proc`) forced (German: “Kernel-Zähler”): values plausible, VPN and Docker marked as virtual and not in the total; switching back to "Automatic" (German: “Automatisch”) works | 0.1 | |
| Suspend/resume: no speed spike after waking up, no stale old values | 0.1 | |
| Plug and unplug USB tethering, also as the last interface: the display goes to 0 or "Offline" and returns without a spike | 0.1 | |
| Special case device kind: an interface without `/sys/class/net/<name>/device` (e.g. a ppp modem) counts as virtual and is missing from the automatic total; the manual selection can include it | 0.1 | |

## Settings

| Check | Stage | Result |
|---|---|---|
| Settings → Data (German: “Einstellungen → Daten”): with the page open, switch the data source from "Automatic" to "Kernel counters" and on to "System sensors" (German: “Systemsensoren”); the interface rows come and go, plasmashell does not crash | 0.1 | |
| Switch the manual interface selection on and off, Apply/OK, reopen the settings: selection and mode are kept (upstream #36) | 0.1 | |
| Page "Display" (German: “Anzeige”): all options are unchanged after Apply/OK (layout, order, sum only, units, short forms, decimal places, threshold, interval) | 0.1 | |
| Upstream #47: deselect an option and save: no crash, the value stays deselected | 0.1 | |
| Upstream #24: scroll over the widget with the mouse wheel: no empty window | 0.1 | |

## Popup and click behavior

| Check | Stage | Result |
|---|---|---|
| Left click on the widget opens the popup; another click on the widget while the popup is open closes it and does not reopen it right away; a click outside closes it as well | 0.2 | |
| Set the middle click to "Open the popup" (German: “Popup öffnen”) on the page "Behavior" (German: “Verhalten”): it opens and closes the popup, and with the popup open it closes it without reopening | 0.2 | |
| The popup shows the header with live values, the status and, on a data source problem, an error hint | 0.2 | |
| Switch the graph window between 1, 5 and 15 minutes; after a plasmashell restart the chosen window is kept | 0.2 | |
| Peaks and session totals appear and rise under load (e.g. a download) | 0.2 | |
| Restart ksystemstats while the popup is open: the session totals do not jump | 0.2 | |
| Copy an IP address in the interface list: "Copied" (German: “Kopiert”) appears and the address is on the clipboard | 0.2 | |
| "Open System Monitor" (German: “Systemmonitor öffnen”) starts the system monitor | 0.2 | |
| Popup with 12 or more interfaces in a real session (e.g. with Docker, VPN, virtual bridges): the list scrolls, nothing is cut off, the popup stays usable | 0.2 | |
| Page "Behavior", launch target "Application" (chosen through the file dialog) and click action "Start the application or command" (German: “Anwendung oder Befehl starten”): the application really starts | 0.2 | |
| Launch target "Command" (e.g. `konsole`): the command really starts | 0.2 | |
| Unknown desktop ID or missing command (e.g. `doesnotexist`): a notification instead of a silent failure | 0.2 | |
| Neither left nor middle click set to "Open the popup": the page "Behavior" shows the warning | 0.2 | |
| Desktop view: the widget on the desktop shows the same view directly, without a popup | 0.2 | |
| Popup with a German system language: all texts German, nothing cut off (also on the page "Behavior") | 0.2 | |
| Without Qt Quick Charts (if it can be arranged): only the graph is missing, with a note, the rest of the popup works | 0.2 | |

## Appearance and auto-hide

| Check | Stage | Result |
|---|---|---|
| Every option on the page "Appearance" (German: “Darstellung”) shows in the panel after Apply: font, bold, text size, symbol style (arrows, triangles, icons, none, custom), color mode, coloring of units, sparkline | 0.3 | |
| Fixed width: the panel does not jump when the values change, also with bold text and with a different font | 0.3 | |
| Color mode "Theme color", "By direction" and "By speed": the values take the expected colors under load and at rest | 0.3 | |
| Real color dialog for the download and upload color: accepting sets the color, cancelling keeps the old one, "Use theme color" (German: “Designfarbe verwenden”) resets it | 0.3 | |
| Threshold editor: add, change and remove levels (up to six); Apply/OK saves them; after a plasmashell restart the levels are unchanged | 0.3 | |
| Sparkline "Behind the values" and "Beside the values": both draw, the values stay readable; in a vertical panel "beside" looks like "behind" | 0.3 | |
| Auto-hide "When offline": disconnect the network (e.g. `nmcli networking off`): the widget disappears from the panel; reconnecting brings it back | 0.3 | |
| Auto-hide "When offline or idle": with traffic below the threshold for the set time the widget disappears; traffic above it brings it back | 0.3 | |
| A hidden widget leaves no gap in the panel | 0.3 | |
| In panel edit mode a hidden widget shows the dimmed network icon placeholder and can be selected | 0.3 | |
| A hidden widget never hides on the desktop, while its popup is open, before the first data has arrived, or while the data is stale | 0.3 | |
| German system language: all texts of the pages "Appearance" and "Behavior" are German and nothing is cut off | 0.3 | |
| Restart with the symbol style "Icons" after at least 30 minutes of uptime, using the restart command that detects a hang: `bash -c 'systemctl --user stop --no-block plasma-plasmashell; sleep 5; p=$(pgrep -x plasmashell) && { kill -ABRT $p; sleep 5; }; systemctl --user start plasma-plasmashell'` | 0.3 | |

## Usage and data cap

For these checks vnstat 2.0 or newer is installed and its service enabled
(`systemctl enable --now vnstat`), unless the item says otherwise. Page
"Usage" (German: “Verbrauch”).

| Check | Stage | Result |
|---|---|---|
| vnstat present: the popup section "Usage" (German: “Verbrauch”) shows today, yesterday, this period and last period with download, upload and total, and "vnstat last updated" (German: “vnstat zuletzt aktualisiert”); the page "Usage" says "vnstat found" | 0.4 | |
| vnstat missing (uninstall it or hide it from `PATH` for the session): the popup shows a hint and a "vnstat website" button instead of an error, and the rest of the popup works; the page "Usage" says "vnstat is not installed" | 0.4 | |
| vnstat service stopped (`systemctl stop vnstat`): after an hour the popup shows that the data is not current (German: “nicht aktuell”); starting the service removes the hint after the next update | 0.4 | |
| Billing day: change it on the page "Usage"; "This period" and "Last period" change accordingly and the totals follow the new start day | 0.4 | |
| Incomplete period right after installing vnstat: "This period" carries an asterisk and the footnote "incomplete" is shown; a period fully covered has none | 0.4 | |
| An interface that counts but is not tracked by vnstat: the popup names it in a hint | 0.4 | |
| Data cap with a small value (e.g. 1 GiB) and the warning level at a low value: the bar appears; at the warning level it takes the neutral color, at 100 % the negative color | 0.4 | |
| Notification delivery in a real session: the warning level and 100 % each produce one desktop notification with the expected text, not two | 0.4 | |
| Restart (use the restart command that detects a hang, see above) with the cap still exceeded: no notification is reported again; the configuration keeps `capNotifiedCycle` and `capNotifiedLevel` across the restart | 0.4 | |
| Notifications switched off, level reached, notifications switched on again: the earlier level is not reported | 0.4 | |
| Cap set so that usage is already past 100 %: only the 100 % notification appears, not the warning too | 0.4 | |
| Panel dot: appears from the warning level on, not before; a screen reader (or the accessibility inspector) reads the cap sentence in the widget's name | 0.4 | |
| Tooltip in a real panel: a "Today" line (German: “Heute”) with download and upload | 0.4 | |
| Manual interface selection with an absent interface in the list: its recorded traffic stays in the totals; automatic mode counts the interfaces vnstat knows, without `lo` and without those currently virtual | 0.4 | |
| Popup that has been resized before (a stored small size): after the update the "Usage" section may not fit; enlarging the popup once is enough and the size is kept | 0.4 | |
| German system language: all texts of the section "Usage" and the settings page are German and nothing is cut off | 0.4 | |

## Later stages and release candidates

| Check | Stage | Result |
|---|---|---|
| Run through all items on Plasma 6.3 (Debian 13, VM) | before 1.0 | |

## Automatic acceptance 0.1

Date: 2026-10-24, state `f4846c5`, on the development machine (Node 24.22,
Qt/qmllint 6.12, Plasma 6.8). These runs do not replace the manual checks
above. There the "Result" column stays empty until they have been worked
through by hand.

Command (npm is not installed on this machine; `pnpm test` runs the same
script `test` from `package.json`):

```
pnpm test && scripts/lint.sh && scripts/smoke.sh && scripts/dev-install.sh \
  && scripts/load-check.sh && scripts/build-plasmoid.sh 0.1.0
```

| Check | Result |
|---|---|
| `pnpm test` | 86 tests, 86 passed, 0 failed |
| `scripts/lint.sh` | `lint: 20 QML files OK`, no warnings |
| `scripts/smoke.sh` | `SMOKE OK` for runner, compact, combobox, parity, proc, provider, sensors, vertical |
| `LC_ALL=C scripts/smoke.sh tests/qml/ParitySmoke.qml` | `SMOKE OK parity` |
| `scripts/dev-install.sh` | package updated, translation compiled |
| `scripts/load-check.sh` | `LOAD OK` |
| `LANGUAGE=de scripts/load-check.sh` | `LOAD OK` |
| `scripts/build-plasmoid.sh 0.1.0` | `dist/netspeeder-0.1.0.plasmoid` created (31 entries, with the German `.mo`) |

Unfiltered runs, because in that state `smoke.sh` hid warnings as long as
`SMOKE OK` appeared (the runs are strict by now):

```
QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen timeout 40 qml6 tests/qml/<scene>.qml
QT_FORCE_STDERR_LOGGING=1 QT_LOGGING_RULES="qml.debug=true" QT_QPA_PLATFORM=offscreen \
  timeout 10 plasmawindowed io.github.flexomatic81.netspeeder
```

- Smoke scenes: each of the eight scenes on its own. No unexpected QML warning
  (no TypeError, ReferenceError, binding loop, "Cannot assign" or deprecation
  notice). Only the expected messages of the `ProviderSmoke` scene appear: the
  error when loading the deliberately missing `Missing.qml` and `netspeeder:`
  warnings about the switch to `/proc`, plus the diagnostic lines of the
  scenes themselves.
- `plasmawindowed` (ends after 10 s through `timeout`, status 124, so the
  widget was running until then) showed, among others: `kf.windowsystem`,
  `kf.svg` and `kf.plasma.core` messages from the system (offscreen platform,
  theme "GruvboxPlusDark" with an outdated `metadata.desktop`), the load line
  `qml: netspeeder: loaded`, a line `qml: 0` and three times the line
  `This plugin does not support propagateSizeHints()`. The package itself
  contains no `console.log`; checked with `grep -rn "console.log" package/`
  (no hits, also not in state `f4846c5`). The same calls with
  `org.kde.plasma.digitalclock` and `org.kde.plasma.systemmonitor.net` also
  print `qml: 0` and the `propagateSizeHints()` line (five and two times), so
  the two lines do not come from Netspeeder.

Not checked automatically:

- The real CMake build and the installation through `cmake --install`:
  `extra-cmake-modules` is missing on the development machine. The CMake files
  were checked against a stub of ECM only. The real build is to be done before
  release.
- Everything in the tables above (panel, network situations, settings).
