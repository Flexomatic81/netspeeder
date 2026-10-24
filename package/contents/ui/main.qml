// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81
// SPDX-FileCopyrightText: 2016 Daniel Faust <hessijames@gmail.com>

// The applet: wires the settings to the NetworkProvider and the UsageModel,
// shows the compact view in the panel and builds the tooltip.

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.notification
import "compact"
import "data"
import "full"
import "../code/appearance.mjs" as Appearance
import "../code/clicks.mjs" as Clicks
import "../code/format.mjs" as Format
import "../code/graph.mjs" as Graph
import "../code/launchtext.mjs" as LaunchText
import "../code/text.mjs" as TextTools
import "../code/tooltip.mjs" as Tooltip
import "../code/visibility.mjs" as Visibility

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

    // The data usage of the current billing period and the share of the
    // data cap (see UsageModel).
    readonly property var summary: usageModel.summary
    readonly property var cap: usageModel.cap

    // "1.5 KiB/s" for a rate in bytes per second.
    function speedText(bytesPerSecond: real): string {
        const speed = Format.formatSpeed(bytesPerSecond, root.formatOptions);
        return speed.value + " " + speed.unit;
    }

    // Plasma's edit mode, where a hidden widget must stay reachable.
    readonly property bool editMode: Plasmoid.containment !== null && Plasmoid.containment.corona !== null ? Plasmoid.containment.corona.editMode : false
    // "shown", "hidden" or "placeholder" from the auto-hide setting; the
    // desktop view is never hidden. (configuration is created from main.xml at
    // Plasma runtime)
    readonly property string presence: Plasmoid.formFactor === PlasmaCore.Types.Planar ? "shown" : Visibility.autoHideState(Appearance.validChoice(Plasmoid.configuration.autoHide, ["never", "offline", "idle"], "never"), root.provider, { // qmllint disable missing-property
            editMode: root.editMode,
            expanded: root.expanded
        })
    // The panel collapses an applet only on HiddenStatus (PassiveStatus leaves
    // a gap) and shows it again by itself in edit mode.
    Plasmoid.status: root.presence === "hidden" ? PlasmaCore.Types.HiddenStatus : PlasmaCore.Types.ActiveStatus

    // The state of the popup at the last press (see CompactRepresentation).
    property bool wasExpanded: false

    // Reports a failed launch as a notification; kind is "app" or "command".
    function reportLaunchFailure(code: string, target: string, kind: string) {
        console.warn("netspeeder: launch failed (" + code + "): " + target);
        failure.text = LaunchText.launchFailureText(code, target, kind, { tr: root.tr, trc: root.trc });
        failure.sendEvent();
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
    // fullRepresentation exists, so the panel view depends on this one.
    fullRepresentation: FullRepresentation {
        provider: root.provider
        formatOptions: root.formatOptions
        // (configuration is created from main.xml at Plasma runtime)
        graphMinutes: Graph.validMinutes(Plasmoid.configuration.graphMinutes) // qmllint disable missing-property
        onGraphMinutesPicked: minutes => Plasmoid.configuration.graphMinutes = minutes // qmllint disable missing-property
        // Only a visible popup (or the desktop view) follows the provider.
        active: root.expanded || Plasmoid.formFactor === PlasmaCore.Types.Planar
        usage: usageModel.view
        onOpenSystemMonitor: monitorLauncher.launch()
        onUsageRefreshRequested: usageModel.refresh()
    }
    compactRepresentation: CompactRepresentation {
        provider: root.provider
        formatOptions: root.formatOptions
        vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        // (configuration is created from main.xml at Plasma runtime)
        layoutMode: Plasmoid.configuration.layout // qmllint disable missing-property
        uploadFirst: Plasmoid.configuration.uploadFirst // qmllint disable missing-property
        combined: Plasmoid.configuration.combined // qmllint disable missing-property
        fixedWidth: Plasmoid.configuration.fixedWidth // qmllint disable missing-property
        fontFamily: Plasmoid.configuration.fontFamily // qmllint disable missing-property
        fontBold: Plasmoid.configuration.fontBold // qmllint disable missing-property
        fontScale: Appearance.validInt(Plasmoid.configuration.fontScale, 50, 200, 100) // qmllint disable missing-property
        iconStyle: Appearance.validChoice(Plasmoid.configuration.iconStyle, Appearance.ICON_STYLES, "arrows") // qmllint disable missing-property
        customDownIcon: Plasmoid.configuration.customDownIcon // qmllint disable missing-property
        customUpIcon: Plasmoid.configuration.customUpIcon // qmllint disable missing-property
        colorMode: Appearance.validChoice(Plasmoid.configuration.colorMode, Appearance.COLOR_MODES, "theme") // qmllint disable missing-property
        downloadColor: Plasmoid.configuration.downloadColor // qmllint disable missing-property
        uploadColor: Plasmoid.configuration.uploadColor // qmllint disable missing-property
        thresholds: Appearance.parseThresholds(Plasmoid.configuration.colorThresholds) // qmllint disable missing-property
        colorUnits: Plasmoid.configuration.colorUnits // qmllint disable missing-property
        sparkline: Appearance.validChoice(Plasmoid.configuration.sparkline, Appearance.SPARKLINE_MODES, "off") // qmllint disable missing-property
        history: root.provider.history
        presence: root.presence
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
        idleThreshold: Appearance.validInt(Plasmoid.configuration.idleThreshold, 1024, 2147483647, 1024) // qmllint disable missing-property
        idleSeconds: Appearance.validInt(Plasmoid.configuration.idleSeconds, 5, 3600, 30) // qmllint disable missing-property
    }

    UsageModel {
        id: usageModel

        interfaceSelection: root.provider.interfaceSelection
        selectedInterfaces: root.provider.selectedInterfaces
        interfaces: root.provider.interfaces
        // (configuration is created from main.xml at Plasma runtime)
        enabled: Plasmoid.configuration.usageEnabled // qmllint disable missing-property
        billingDay: Appearance.validInt(Plasmoid.configuration.billingDay, 1, 28, 1) // qmllint disable missing-property
        capEnabled: Plasmoid.configuration.dataCapEnabled === true // qmllint disable missing-property
        capGiB: Appearance.validPositive(Plasmoid.configuration.dataCapGiB, 100) // qmllint disable missing-property
        warnPercent: Appearance.validInt(Plasmoid.configuration.capWarnPercent, 1, 99, 80) // qmllint disable missing-property
    }

    Launcher {
        id: launcher

        // (configuration is created from main.xml at Plasma runtime)
        kind: Plasmoid.configuration.launchKind // qmllint disable missing-property
        app: Plasmoid.configuration.launchApp // qmllint disable missing-property
        command: Plasmoid.configuration.launchCommand // qmllint disable missing-property
        onFailed: (code, target) => root.reportLaunchFailure(code, target, launcher.kind)
    }

    // The button in the popup: always the system monitor, whatever the click
    // actions are set to.
    Launcher {
        id: monitorLauncher

        kind: "app"
        app: "org.kde.plasma-systemmonitor"
        onFailed: (code, target) => root.reportLaunchFailure(code, target, "app")
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
