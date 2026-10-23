// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81
// SPDX-FileCopyrightText: 2016 Daniel Faust <hessijames@gmail.com>

// The applet: wires the settings to the NetworkProvider, shows the compact
// view in the panel and builds the tooltip.

import QtQuick
import org.kde.plasma.plasmoid
import "compact"
import "data"
import "../code/format.mjs" as Format

PlasmoidItem {
    id: root

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
            return [i18n("Waiting for network data…")];
        }
        if (p.stale) {
            return [i18n("No current data")];
        }
        if (p.includedCount === 0 && p.interfaceSelection === "manual") {
            return [i18n("No selected network interface available")];
        }
        if (p.includedCount === 0 || !p.online) {
            return [i18n("Offline")];
        }
        const lines = [i18nc("@info:tooltip download and upload speed", "Download: %1   Upload: %2", root.speedText(p.down), root.speedText(p.up))];
        if (p.primaryIp !== "") {
            lines.push(i18nc("@info:tooltip", "IP address: %1", root.escapeHtml(p.primaryIp)));
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
            return [fellBack ? i18n("Using kernel counters because system sensors are not available.") : i18n("System sensors are not available. Choose another data source in the settings.")];
        case "no-interfaces":
            return [fellBack ? i18n("Using kernel counters because system sensors report no network interfaces.") : i18n("System sensors report no network interfaces.")];
        case "source-failed":
            // Cut first, escape second: a cut must not split an entity.
            return [i18n("Reading network data failed: %1", root.escapeHtml(p.errorDetail.replace(/[\r\n]+/g, " ").slice(0, 120)))];
        default:
            return [];
        }
    }

    preferredRepresentation: compactRepresentation
    compactRepresentation: CompactRepresentation {
        provider: root.provider
        formatOptions: root.formatOptions
    }

    toolTipMainText: root.provider.primaryLabel || i18n("Network")
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
