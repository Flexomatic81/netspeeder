<!--
SPDX-License-Identifier: GPL-2.0-or-later
SPDX-FileCopyrightText: 2026 Flexomatic81
-->

# Manuelle Tests

Diese Checkliste wird vor jeder Veröffentlichung abgearbeitet. Die
automatischen Tests (`node tools/check.mjs`, in CI laufen davon die Schritte der Gruppe `fast`,
`shellcheck` und `qmllint`) ersetzen sie
nicht: Sie prüfen Logik und einzelne Szenen, nicht das Verhalten in einem
echten Panel.

Vorgehen: die aktuelle Fassung installieren (`scripts/dev-install.sh`),
plasmashell neu starten (`systemctl --user restart plasma-plasmashell`), die
Punkte der jeweiligen Etappe durchgehen und in der Spalte „Ergebnis" eintragen:
„OK", „Fehler" mit Verweis auf die Beobachtung, oder „entfällt" mit Grund. Pro
Durchlauf oben Version, Datum und Plasma-Version notieren oder die Tabelle
kopieren; leere Spalten gelten als nicht geprüft.

- Version:
- Datum:
- Plasma-Version:

## Darstellung im Panel

| Prüfpunkt | Etappe | Ergebnis |
|---|---|---|
| Horizontales Panel in Standardhöhe: Download und Upload lesbar, die Werte wechseln, ohne dass das Panel springt oder Text überlappt (Upstream #11, #27) | 0.1 | |
| Vertikales Panel: Richtungen untereinander, Wert und Einheit lesbar, keine Überlappung | 0.1 | |
| Panelmaße: horizontal 20 px, 44 px und 96 px sowie vertikal ca. 32 px Breite – Anzeige lesbar, keine Überlappung, nichts abgeschnitten | 0.1 | |
| Desktop-Platzierung (Planar, Widget direkt auf der Arbeitsfläche): zeigt in 0.1 etwas Sinnvolles; die eigene Popup-Ansicht für den Desktop folgt erst mit 0.3 | 0.1 | |
| Helles und dunkles Theme: Text in beiden gut lesbar | 0.1 | |
| Schriftskalierung 150 %: Panelanzeige und Einstellungsseiten bleiben lesbar und werden nicht abgeschnitten | 0.1 | |
| Tooltip in einem echten Panel: Verbindungsname, Download-Zeile, Upload-Zeile und IP-Adresse erscheinen | 0.1 | |

## Netzwerk-Situationen

| Prüfpunkt | Etappe | Ergebnis |
|---|---|---|
| VPN aktiv: der Verkehr im Tunnel wird in der automatischen Summe nicht doppelt gezählt | 0.1 | |
| Docker aktiv (docker0, veth, Bridges): Containerverkehr steht nicht in der automatischen Summe | 0.1 | |
| Datenquelle „Kernel-Zähler" (`proc`) erzwungen: Werte plausibel, VPN und Docker als virtuell gekennzeichnet, nicht in der Summe; Rückwechsel auf „Automatisch" funktioniert | 0.1 | |
| Suspend/Resume: nach dem Aufwachen kein Geschwindigkeits-Ausschlag, keine stehengebliebenen Altwerte | 0.1 | |
| USB-Tethering ein- und ausstecken, auch als letztes Interface: Anzeige geht auf 0 bzw. „Offline" und kehrt ohne Ausschlag zurück | 0.1 | |
| Sonderfall Geräteart: ein Interface ohne `/sys/class/net/<name>/device` (z. B. ppp-Modem) gilt als virtuell und fehlt in der automatischen Summe; über die manuelle Auswahl lässt es sich aufnehmen | 0.1 | |

## Einstellungen

| Prüfpunkt | Etappe | Ergebnis |
|---|---|---|
| Einstellungen → Daten: bei geöffneter Seite die Datenquelle von „Automatisch" auf „Kernel-Zähler" und weiter auf „Systemsensoren" umschalten; die Interface-Zeilen kommen und gehen, plasmashell stürzt nicht ab | 0.1 | |
| Manuelle Interface-Auswahl ein- und ausschalten, Anwenden/OK, Einstellungen erneut öffnen: Auswahl und Modus sind erhalten (Upstream #36) | 0.1 | |
| Seite „Anzeige": alle Optionen nach Anwenden/OK unverändert wieder da (Layout, Reihenfolge, nur Summe, Einheiten, Kurzformen, Nachkommastellen, Schwelle, Intervall) | 0.1 | |
| Upstream #47: eine Option abwählen und speichern – kein Absturz, Wert bleibt abgewählt | 0.1 | |
| Upstream #24: mit dem Mausrad über dem Widget scrollen – kein leeres Fenster | 0.1 | |

## Spätere Etappen und Release-Kandidaten

| Prüfpunkt | Etappe | Ergebnis |
|---|---|---|
| vnstat vorhanden: Tages- und Monatsverbrauch erscheinen | 0.4 | |
| vnstat fehlend: Hinweis statt Fehler | 0.4 | |
| Datenlimit-Benachrichtigung: je Stufe einmal pro Abrechnungszeitraum, nicht erneut nach einem Neustart | 0.4 | |
| Durchlauf aller Punkte auf Plasma 6.3 (Debian 13, VM) | vor 1.0 | |

## Automatische Abnahme 0.1

Datum: 2026-10-24, Stand `f4846c5`, auf dem Entwicklungsrechner (Node 24.22,
Qt/qmllint 6.12, Plasma 6.8). Diese Läufe ersetzen die manuellen Prüfpunkte
oben nicht. Dort bleibt „Ergebnis" leer, bis sie von Hand durchgegangen sind.

Befehl (npm ist auf diesem Rechner nicht installiert, `pnpm test` führt dasselbe
Skript `test` aus `package.json` aus):

```
pnpm test && scripts/lint.sh && scripts/smoke.sh && scripts/dev-install.sh \
  && scripts/load-check.sh && scripts/build-plasmoid.sh 0.1.0
```

| Prüfung | Ergebnis |
|---|---|
| `pnpm test` | 86 Tests, 86 bestanden, 0 fehlgeschlagen |
| `scripts/lint.sh` | `lint: 20 QML files OK`, keine Warnungen |
| `scripts/smoke.sh` | `SMOKE OK` für runner, compact, combobox, parity, proc, provider, sensors, vertical |
| `LC_ALL=C scripts/smoke.sh tests/qml/ParitySmoke.qml` | `SMOKE OK parity` |
| `scripts/dev-install.sh` | Paket aktualisiert, Übersetzung kompiliert |
| `scripts/load-check.sh` | `LOAD OK` |
| `LANGUAGE=de scripts/load-check.sh` | `LOAD OK` |
| `scripts/build-plasmoid.sh 0.1.0` | `dist/netspeeder-0.1.0.plasmoid` erzeugt (31 Einträge, mit deutscher `.mo`) |

Ungefilterte Läufe, weil `smoke.sh` in diesem Stand Warnungen ausblendete,
solange `SMOKE OK` erschien (inzwischen sind die Läufe strikt):

```
QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen timeout 40 qml6 tests/qml/<Szene>.qml
QT_FORCE_STDERR_LOGGING=1 QT_LOGGING_RULES="qml.debug=true" QT_QPA_PLATFORM=offscreen \
  timeout 10 plasmawindowed io.github.flexomatic81.netspeeder
```

- Smoke-Szenen: jede der acht Szenen einzeln. Keine unerwartete QML-Warnung
  (kein TypeError, ReferenceError, Bindungsschleife, „Cannot assign" oder
  Veraltet-Hinweis). Zu sehen sind nur die erwarteten Meldungen der
  `ProviderSmoke`-Szene: der Fehler beim Laden der absichtlich fehlenden
  `Missing.qml` sowie `netspeeder:`-Warnungen zum Wechsel auf `/proc`, dazu die
  Diagnosezeilen der Szenen selbst.
- `plasmawindowed` (endet nach 10 s durch `timeout`, Status 124, das Widget
  lief also bis dahin) zeigte unter anderem: `kf.windowsystem`-,
  `kf.svg`- und `kf.plasma.core`-Meldungen des Systems (offscreen-Plattform,
  Theme „GruvboxPlusDark" mit veralteter `metadata.desktop`), die Ladezeile
  `qml: netspeeder: loaded`, eine Zeile `qml: 0` und dreimal die Zeile
  `This plugin does not support propagateSizeHints()`. Das Paket selbst
  enthält kein `console.log`; geprüft mit `grep -rn "console.log" package/`
  (keine Treffer, auch nicht im Stand `f4846c5`). Dieselben Aufrufe mit
  `org.kde.plasma.digitalclock` und `org.kde.plasma.systemmonitor.net` geben
  ebenfalls `qml: 0` und die `propagateSizeHints()`-Zeile (fünfmal bzw.
  zweimal) aus, die beiden Zeilen stammen also nicht vom Netspeeder.

Nicht automatisch geprüft:

- Der echte CMake-Bau und die Installation per `cmake --install`: auf dem
  Entwicklungsrechner fehlt `extra-cmake-modules`. Die CMake-Dateien sind nur
  gegen eine Attrappe von ECM geprüft. Der echte Bau ist vor der Veröffentlichung
  nachzuholen.
- Alles aus den Tabellen oben (Panel, Netzwerk-Situationen, Einstellungen).
