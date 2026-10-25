<!--
SPDX-License-Identifier: GPL-2.0-or-later
SPDX-FileCopyrightText: 2026 Flexomatic81
-->

# KDE Store entry

The text for the entry in the KDE Store. Copy each block into the matching
field of the store form.

## Name

Netspeeder

## Category

Plasma 6 Monitoring

## Version

The version in `package/metadata.json`, for example `1.0.0`.

## License

GPLv2 or later (GPL-2.0-or-later). Not an original product: Netspeeder builds
on the Netspeed Widget by Daniel Faust. The entry uses no CC-BY material, so
the credits field stays empty.

## Tags

```
netspeed, network-speed, network, bandwidth, traffic, monitor, vnstat, data-usage, data-cap, panel, plasmoid, widget, plasma6, kde, linux
```

The store adds `plasma##majorversion=6` and the license tag (`gplv2-later`)
itself.

## Links

- Source code: https://github.com/Flexomatic81/netspeeder
- File: `netspeeder-<version>.plasmoid` from the GitHub release of that version

## Short description

**English**

> Network speed in the Plasma 6 panel: counts real devices once, no VPN or Docker double-counting, no jumping. Popup with graph, optional vnStat usage and data cap.

**German**

> Netzwerktempo in der Plasma-6-Leiste: zählt echte Geräte einmal, ohne VPN- oder Docker-Doppelzählung, ohne Springen. Popup mit Diagramm, optional vnStat-Verbrauch und Datenlimit.

## Long description

### English

Netspeeder shows the current download and upload speed in the Plasma 6 panel.
It is the successor of the Netspeed Widget by Daniel Faust.

- **Correct totals:** by default only physical network devices count, so VPN
  tunnels, Docker bridges and other virtual interfaces are not counted twice.
  You can also pick the interfaces by hand.
- **A calm panel:** digits have a fixed width and the widget reserves the width
  of the widest value. Two rows or side by side, automatic in vertical panels.
- **Units:** KiB/s, kB/s or Mbit/s, short unit names, decimal places, update
  interval from 0.5 to 10 seconds.
- **Appearance:** font, bold, text size, arrows, triangles, icons or your own
  symbols, colors by direction or by speed (up to six levels), an optional
  sparkline.
- **Popup and desktop view:** live speeds, a traffic graph over 1, 5 or 15
  minutes, peaks, session totals, and the interface list with IPv4 addresses to
  copy.
- **Data usage (optional, with vnStat):** today, yesterday, this and the last
  billing period; a monthly data cap with a warning level, a dot in the panel
  and one notification per level.
- **Behavior:** left and middle click open the popup or start an application
  or command; the widget can hide itself when offline or idle.
- **Data sources:** the system sensors of Plasma (`ksystemstats`) by default,
  the kernel counters (`/proc/net/dev`) as an automatic fallback.
- English and German.

Requires Plasma 6.3 or newer (tested on Plasma 6.8, older versions checked
against their source code). Coming from the Netspeed Widget? The README has
a table that maps every old setting to its new place; settings are not taken
over automatically, and both widgets can run side by side.

Source code, issues and translations: https://github.com/Flexomatic81/netspeeder

### German

Netspeeder zeigt die aktuelle Download- und Upload-Geschwindigkeit in der
Plasma-6-Leiste. Es ist der Nachfolger des Netspeed Widget von Daniel Faust.

- **Richtige Summen:** standardmäßig zählen nur physische Netzwerkgeräte, VPN-
  Tunnel, Docker-Brücken und andere virtuelle Schnittstellen werden also nicht
  doppelt gezählt. Die Schnittstellen lassen sich auch von Hand wählen.
- **Ruhige Leiste:** Ziffern haben eine feste Breite, und das Widget hält die
  Breite des breitesten Werts frei. Zwei Zeilen oder nebeneinander, in
  senkrechten Leisten automatisch untereinander.
- **Einheiten:** KiB/s, kB/s oder Mbit/s, kurze Einheitennamen,
  Nachkommastellen, Aktualisierung alle 0,5 bis 10 Sekunden.
- **Darstellung:** Schriftart, fett, Textgröße, Pfeile, Dreiecke, Symbole oder
  eigene Zeichen, Farben je Richtung oder nach Geschwindigkeit (bis zu sechs
  Stufen), ein optionales Mini-Diagramm.
- **Popup und Desktop-Ansicht:** aktuelle Geschwindigkeit, ein
  Verlaufsdiagramm über 1, 5 oder 15 Minuten, Spitzenwerte, Summen der
  Sitzung und die Liste der Schnittstellen mit kopierbaren IPv4-Adressen.
- **Datenverbrauch (optional, mit vnStat):** heute, gestern, dieser und der
  letzte Abrechnungszeitraum; ein monatliches Datenlimit mit Warnstufe, einem
  Punkt in der Leiste und einer Benachrichtigung je Stufe.
- **Verhalten:** Links- und Mittelklick öffnen das Popup oder starten eine
  Anwendung oder einen Befehl; das Widget kann sich offline oder bei Leerlauf
  ausblenden.
- **Datenquellen:** standardmäßig die Systemsensoren von Plasma
  (`ksystemstats`), die Kernel-Zähler (`/proc/net/dev`) als automatischer
  Ausweichweg.
- Englisch und Deutsch.

Benötigt Plasma 6.3 oder neuer (getestet mit Plasma 6.8, ältere Versionen
am Quellcode geprüft). Umstieg vom Netspeed Widget? Die README
enthält eine Tabelle, die jede alte Einstellung ihrem neuen Platz zuordnet;
Einstellungen werden nicht automatisch übernommen, und beide Widgets können
nebeneinander laufen.

Quellcode, Fehlermeldungen und Übersetzungen: https://github.com/Flexomatic81/netspeeder

## Images

The store takes at most five images. Upload in this order; the files are in
[`images/`](images/) and are made with `scripts/screenshots.sh` in the stock
Breeze Dark color scheme.

1. `panel-rows.png`: download and upload in two rows
2. `panel-single.png`: both values side by side in one row
3. `panel-vertical.png`: a vertical panel
4. `panel-colors.png`: colors by speed
5. `popup.png`: the popup with graph, interfaces and usage

`panel-sparkline.png` (the sparkline behind the values) and
`settings-appearance.png` (the settings page Appearance) are used in the README
only.

The project logo for the store page is `logo.png` (512 × 512), rendered from
`logo.svg` with `rsvg-convert -w 512 -h 512 logo.svg -o logo.png`. The widget
itself keeps the theme icon `network-connect`.

## Changelog 1.0.0

First stable release.

- Panel view with download and upload speed in two rows or side by side,
  fixed width, units in KiB/s, kB/s or Mbit/s.
- Correct totals: only physical devices count by default, with manual
  selection as an alternative.
- Popup and desktop view with a traffic graph, peaks, session totals and the
  interface list.
- Appearance page: font, text size, symbols, colors by direction or by speed,
  sparkline.
- Behavior page: click actions, launch target, auto-hide when offline or idle.
- Data usage, billing period and data cap with notifications through vnStat
  (optional).
- The sensor data recovers when the system sensor service starts late or
  restarts.
- Launch targets in subfolders of the applications directory are found.
- Checked against the APIs of Plasma 6.3, KDE Frameworks 6.10 and Qt 6.8;
  tested on Plasma 6.8.
- English and German.
