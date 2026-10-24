// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81
// SPDX-FileCopyrightText: 2016 Daniel Faust <hessijames@gmail.com>

// The applet: wires the settings to the NetworkProvider, shows the compact
// view in the panel and builds the tooltip.

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "compact"
import "data"
import "../code/format.mjs" as Format
import "../code/text.mjs" as TextTools

PlasmoidItem {
    id: root

    // Translation helpers: the only place that calls Plasma's i18n functions.
    // Plain qml6 (the smoke scenes) has none and gets the English text.
    function tr(text: string, ...args): string {
        // Plasma context function, not declared for qmllint
        return typeof i18n === "function" ? i18n(text, ...args) : TextTools.substitute(text, args); // qmllint disable unqualified
    }
    function trc(context: string, text: string, ...args): string {
        // Plasma context function, not declared for qmllint
        return typeof i18nc === "function" ? i18nc(context, text, ...args) : TextTools.substitute(text, args); // qmllint disable unqualified
    }
    function trp(singular: string, plural: string, n: int, ...args): string {
        // Plasma context function, not declared for qmllint
        return typeof i18np === "function" ? i18np(singular, plural, n, ...args) : TextTools.substitute(n === 1 ? singular : plural, [n, ...args]); // qmllint disable unqualified
    }

    property alias provider: provider
    // Options for formatSpeed(); the views format their numbers with them.
    readonly property var formatOptions: ({
            // qmllint disable missing-property
            // (configuration is created from main.xml at Plasma runtime)
            unitSystem: Plasmoid.configuration.unitSystem,
            shortUnits: Plasmoid.configuration.shortUnits,
            decimals: Plasmoid.configuration.decimals,
            lowSpeedThreshold: Plasmoid.configuration.lowSpeedThreshold,
            // qmllint enable missing-property
            decimalPoint: Qt.locale().decimalPoint
        })

    // "1.5 KiB/s" for a rate in bytes per second.
    function speedText(bytesPerSecond: real): string {
        const speed = Format.formatSpeed(bytesPerSecond, root.formatOptions);
        return speed.value + " " + speed.unit;
    }

    // Escapes what StyledText would read as markup. Only the sub text of the
    // tooltip is styled; the main text is plain text and must stay unescaped.
    function escapeHtml(text: string): string {
        return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    // The first line that applies describes the state; with live data the
    // speeds follow, and the IP address if there is one.
    function statusLines(): var {
        const p = root.provider;
        if (!p.hasData) {
            return [root.tr("Waiting for network data…")];
        }
        if (p.stale) {
            return [root.tr("No current data")];
        }
        if (p.includedCount === 0 && p.interfaceSelection === "manual") {
            return [root.tr("No selected network interface available")];
        }
        if (p.includedCount === 0 || !p.online) {
            return [root.tr("Offline")];
        }
        const lines = [root.trc("@info:tooltip", "Download: %1", root.speedText(p.down)), root.trc("@info:tooltip", "Upload: %1", root.speedText(p.up))];
        if (p.primaryIp !== "") {
            lines.push(root.trc("@info:tooltip", "IP address: %1", root.escapeHtml(p.primaryIp)));
        }
        return lines;
    }

    // A note about the data source, independent of the status above; empty
    // when the source works as chosen.
    function hintLines(): var {
        const p = root.provider;
        const fellBack = p.fallbackNote !== "";
        switch (p.errorCode) {
        case "sensors-unavailable":
            return [fellBack ? root.tr("Using kernel counters because system sensors are not available.") : root.tr("System sensors are not available. Choose another data source in the settings.")];
        case "no-interfaces":
            return [fellBack ? root.tr("Using kernel counters because system sensors report no network interfaces.") : root.tr("System sensors report no network interfaces.")];
        case "source-failed":
            // Cut first, escape second: a cut must not split an entity.
            return [root.tr("Reading network data failed: %1", root.escapeHtml(p.errorDetail.replace(/[\r\n]+/g, " ").slice(0, 120)))];
        default:
            return [];
        }
    }

    preferredRepresentation: compactRepresentation
    // Plasma 6 only instantiates compactRepresentation when a
    // fullRepresentation exists. The real popup arrives in 0.3; until then an
    // empty placeholder keeps the panel view alive.
    fullRepresentation: Item {}
    compactRepresentation: CompactRepresentation {
        provider: root.provider
        formatOptions: root.formatOptions
        vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        // qmllint disable missing-property
        // (configuration is created from main.xml at Plasma runtime)
        layoutMode: Plasmoid.configuration.layout
        uploadFirst: Plasmoid.configuration.uploadFirst
        combined: Plasmoid.configuration.combined
        fixedWidth: Plasmoid.configuration.fixedWidth
        // qmllint enable missing-property
    }

    toolTipMainText: root.provider.primaryLabel || root.tr("Network")
    toolTipSubText: root.statusLines().concat(root.hintLines()).join("<br>")
    toolTipTextFormat: Text.StyledText

    NetworkProvider {
        id: provider

        // qmllint disable missing-property
        // (configuration is created from main.xml at Plasma runtime)
        dataSource: Plasmoid.configuration.dataSource
        interfaceSelection: Plasmoid.configuration.interfaceSelection
        selectedInterfaces: Plasmoid.configuration.selectedInterfaces
        updateInterval: Plasmoid.configuration.updateInterval
        // qmllint enable missing-property
    }

    Component.onCompleted: console.debug("netspeeder: loaded")
}
