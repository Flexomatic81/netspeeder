<!--
SPDX-License-Identifier: GPL-2.0-or-later
SPDX-FileCopyrightText: 2026 Flexomatic81
-->

# Manuelle Tests

Diese Checkliste wird vor jeder Veröffentlichung abgearbeitet. Die
automatischen Tests (`npm test`, `scripts/lint.sh`, `scripts/smoke.sh`)
ersetzen sie nicht: Sie prüfen Logik und einzelne Szenen, nicht das Verhalten
in einem echten Panel.

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
