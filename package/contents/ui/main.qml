// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81
// SPDX-FileCopyrightText: 2016 Daniel Faust <hessijames@gmail.com>

// The applet: wires the settings to the NetworkProvider, shows the compact
// view in the panel and builds the tooltip.

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.notification
import "compact"
import "data"
import "../code/clicks.mjs" as Clicks
import "../code/format.mjs" as Format
import "../code/text.mjs" as TextTools
import "../code/tooltip.mjs" as Tooltip

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
        return typeof i18np === "function" ? i18np(singular, plural, n, ...args) : TextTools.pluralFallback(singular, plural, n, args); // qmllint disable unqualified
    }

    property alias provider: provider
    // Options for formatSpeed(); the views format their numbers with them.
    readonly property var formatOptions: ({
            // (configuration is created from main.xml at Plasma runtime)
            unitSystem: Plasmoid.configuration.unitSystem, // qmllint disable missing-property
            shortUnits: Plasmoid.configuration.shortUnits, // qmllint disable missing-property
            decimals: Plasmoid.configuration.decimals, // qmllint disable missing-property
            lowSpeedThreshold: Plasmoid.configuration.lowSpeedThreshold, // qmllint disable missing-property
            decimalPoint: Qt.locale().decimalPoint
        })

    // "1.5 KiB/s" for a rate in bytes per second.
    function speedText(bytesPerSecond: real): string {
        const speed = Format.formatSpeed(bytesPerSecond, root.formatOptions);
        return speed.value + " " + speed.unit;
    }

    // The state of the popup at the last press (see CompactRepresentation).
    property bool wasExpanded: false

    // The text of the notification for a failed launch.
    function launchFailureText(code: string, target: string): string {
        switch (code) {
        case "invalid":
            return root.trc("@info", "The launch target “%1” is not valid.", target);
        case "not-found":
            return root.trc("@info", "Could not find “%1”.", target);
        case "timeout":
            return root.trc("@info", "Starting “%1” did not respond.", target);
        default:
            return root.trc("@info", "Could not start “%1”.", target);
        }
    }

    // What a click with a button does, from the settings.
    function runAction(button: string) {
        // (configuration is created from main.xml at Plasma runtime)
        const action = Clicks.actionFor(button, {
            leftClick: Plasmoid.configuration.leftClick, // qmllint disable missing-property
            middleClick: Plasmoid.configuration.middleClick // qmllint disable missing-property
        });
        if (action === "popup") {
            root.expanded = Clicks.nextExpanded(root.wasExpanded);
        } else if (action === "launch") {
            launcher.launch();
        }
    }

    // On the desktop the view is the full one; in a panel the compact one.
    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : compactRepresentation
    // Plasma 6 only instantiates compactRepresentation when a
    // fullRepresentation exists. The real popup arrives in 0.3; until then an
    // empty placeholder keeps the panel view alive.
    fullRepresentation: Item {}
    compactRepresentation: CompactRepresentation {
        provider: root.provider
        formatOptions: root.formatOptions
        vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        // (configuration is created from main.xml at Plasma runtime)
        layoutMode: Plasmoid.configuration.layout // qmllint disable missing-property
        uploadFirst: Plasmoid.configuration.uploadFirst // qmllint disable missing-property
        combined: Plasmoid.configuration.combined // qmllint disable missing-property
        fixedWidth: Plasmoid.configuration.fixedWidth // qmllint disable missing-property
        onPressed: root.wasExpanded = root.expanded
        onActivated: button => root.runAction(button === Qt.MiddleButton ? "middle" : "left")
    }

    toolTipMainText: root.provider.primaryLabel || root.tr("Network")
    toolTipSubText: Tooltip.tooltipLines(root.provider, { tr: root.tr, trc: root.trc }, root.speedText).join("<br>")
    toolTipTextFormat: Text.StyledText

    NetworkProvider {
        id: provider

        // (configuration is created from main.xml at Plasma runtime)
        dataSource: Plasmoid.configuration.dataSource // qmllint disable missing-property
        interfaceSelection: Plasmoid.configuration.interfaceSelection // qmllint disable missing-property
        selectedInterfaces: Plasmoid.configuration.selectedInterfaces // qmllint disable missing-property
        updateInterval: Plasmoid.configuration.updateInterval // qmllint disable missing-property
    }

    Launcher {
        id: launcher

        // (configuration is created from main.xml at Plasma runtime)
        kind: Plasmoid.configuration.launchKind // qmllint disable missing-property
        app: Plasmoid.configuration.launchApp // qmllint disable missing-property
        command: Plasmoid.configuration.launchCommand // qmllint disable missing-property
        onFailed: (code, target) => {
            failure.text = root.launchFailureText(code, target);
            failure.sendEvent();
        }
    }

    Notification {
        id: failure

        componentName: "plasma_workspace"
        eventId: "notification"
        title: root.tr("Netspeeder")
        iconName: "network-connect"
    }

    Component.onCompleted: console.debug("netspeeder: loaded")
}
