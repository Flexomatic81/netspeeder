// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Settings page "Data": data source, which interfaces make up the total, and a
// live list of all interfaces. The page runs its own NetworkProvider on the
// settings that are being edited, so a change shows at once, before it is
// applied. Plasma opens the page with the saved values in the cfg_ properties
// and writes the changed ones back when the user applies.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "../data"
import "../../code/format.mjs" as Format
import "../../code/listsync.mjs" as ListSync
import "../../code/selection.mjs" as Selection
import "../../code/text.mjs" as TextTools

KCM.SimpleKCM {
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

    property string cfg_dataSource
    property string cfg_interfaceSelection
    property var cfg_selectedInterfaces: []
    // The number format of the other pages. Plasma hands every saved value to
    // every page as a cfg_ property (see open() in AppletConfiguration.qml)
    // and writes back only the keys whose value differs, so declaring them
    // here only reads them.
    property string cfg_unitSystem: "iec"
    property bool cfg_shortUnits: false
    property int cfg_decimals: -1
    property int cfg_lowSpeedThreshold: 1024

    // Options for formatSpeed(); a smoke scene can replace them.
    property var formatOptions: ({
            unitSystem: root.cfg_unitSystem,
            shortUnits: root.cfg_shortUnits,
            decimals: root.cfg_decimals,
            lowSpeedThreshold: root.cfg_lowSpeedThreshold
        })
    // A smoke scene sets this to replace the page's own provider.
    property var providerOverride: null
    readonly property var source: root.providerOverride ?? provider

    readonly property bool manual: root.cfg_interfaceSelection === "manual"

    // The selected interface names as a plain array. The saved value arrives
    // as an array-like list object of the configuration.
    readonly property var selectedNames: Selection.toList(root.cfg_selectedInterfaces).map(String)

    // The current sample of every interface, by name. The provider hands out
    // a new list with every sample; the rows below look their values up here
    // and so stay alive between samples.
    readonly property var entryByName: {
        const map = Object.create(null);
        for (const entry of root.source.interfaces) {
            map[entry.name] = entry;
        }
        return map;
    }

    // The names that get a row: every interface the provider knows. In manual
    // mode also the selected ones that are gone (a VPN that is down), so that
    // they can be taken out of the selection.
    readonly property var listedNames: {
        const names = [];
        for (const entry of root.source.interfaces) {
            names.push(entry.name);
        }
        if (root.manual) {
            for (const name of root.selectedNames) {
                if (names.indexOf(name) < 0) {
                    names.push(name);
                }
            }
        }
        return names;
    }

    // Brings the rows in line with listedNames by removing and inserting single
    // rows, at the place that keeps the list sorted by name. A rebuild with
    // every sample (about once a second) would lose clicks and focus; the
    // order does not depend on the interface state either, so a row does not
    // jump when it is checked.
    function syncRows() {
        const current = [];
        for (let row = 0; row < rowModel.count; row++) {
            current.push(rowModel.get(row).interfaceName);
        }
        for (const step of ListSync.syncOps(current, root.listedNames, Selection.compareNames)) {
            if (step.op === "remove") {
                rowModel.remove(step.index);
            } else {
                rowModel.insert(step.index, { "interfaceName": step.name });
            }
        }
    }

    // Writes the selection with `name` switched on or off. Always a new array,
    // so that Plasma notices the change; names that are not listed stay.
    function setSelected(name: string, selected: bool) {
        const names = root.selectedNames.filter(entry => entry !== name);
        if (selected) {
            names.push(name);
        }
        names.sort(Selection.compareNames);
        root.cfg_selectedInterfaces = names;
    }

    // A speed as shown in the list: in the saved unit system, and small
    // values are not hidden.
    function speedText(bytesPerSecond: real): string {
        const speed = Format.formatSpeed(bytesPerSecond, Object.assign({}, root.formatOptions, {
            lowSpeedThreshold: 0,
            decimalPoint: Qt.locale().decimalPoint
        }));
        return speed.value + " " + speed.unit;
    }

    function sourceText(source: string): string {
        switch (source) {
        case "sensors":
            return root.tr("System sensors");
        case "proc":
            return root.tr("Kernel counters");
        default:
            return "–";
        }
    }

    // The explanation for a provider error, "" when there is none. The detail
    // is the output of a failed command: cut it, and keep it to one line.
    function errorText(code: string, detail: string): string {
        switch (code) {
        case "sensors-unavailable":
            return root.tr("System sensors are not available.");
        case "no-interfaces":
            return root.tr("System sensors report no network interfaces.");
        case "source-failed":
            return root.tr("Reading network data failed: %1", detail.replace(/[\r\n]+/g, " ").slice(0, 200));
        default:
            return "";
        }
    }

    onListedNamesChanged: root.syncRows()
    Component.onCompleted: root.syncRows()

    ListModel {
        id: rowModel
    }

    NetworkProvider {
        id: provider

        visible: false
        dataSource: root.cfg_dataSource
        interfaceSelection: root.cfg_interfaceSelection
        selectedInterfaces: root.selectedNames
        updateInterval: 1
    }

    QQC2.ButtonGroup {
        id: selectionGroup
    }

    Kirigami.FormLayout {
        ConfigComboBox {
            id: sourceBox

            Kirigami.FormData.label: root.tr("Data source:")
            options: [
                { text: root.tr("Automatic (recommended)"), value: "auto" },
                { text: root.tr("System sensors (ksystemstats)"), value: "sensors" },
                { text: root.tr("Kernel counters (/proc/net/dev)"), value: "proc" }
            ]
            configValue: root.cfg_dataSource
            onPicked: value => root.cfg_dataSource = value
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 25
            text: root.tr("Kernel counters also show VPN and container interfaces, but start a small process at every update.")
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.RadioButton {
            id: automaticButton

            Kirigami.FormData.label: root.tr("Interfaces counted in the total:")
            QQC2.ButtonGroup.group: selectionGroup
            text: root.tr("Automatic (physical network devices)")
            checked: root.cfg_interfaceSelection !== "manual"
            onToggled: {
                if (automaticButton.checked) {
                    root.cfg_interfaceSelection = "auto";
                }
            }
        }

        QQC2.RadioButton {
            id: manualButton

            QQC2.ButtonGroup.group: selectionGroup
            text: root.tr("Selected interfaces only")
            checked: root.manual
            onToggled: {
                if (manualButton.checked) {
                    root.cfg_interfaceSelection = "manual";
                }
            }
        }

        // A Column, not a ColumnLayout: with a ColumnLayout in the FormLayout,
        // removing a row crashed the process (measured on 2026-10-24, Qt 6.12,
        // in the size hint of the layout, which the FormLayout reads).
        Column {
            id: rowColumn

            Layout.fillWidth: true

            QQC2.Label {
                // An error explains the empty list; it takes precedence.
                visible: rowModel.count === 0 && root.errorText(root.source.errorCode, root.source.errorDetail) === ""
                text: root.source.hasData ? root.tr("No network interfaces found.") : root.tr("Waiting for network data…")
                opacity: 0.7
            }

            Repeater {
                model: rowModel

                // Two lines per interface: the check box with the name, and below
                // it, in line with the name, kind and speeds. One line would not
                // fit in the narrow column of the form.
                delegate: ColumnLayout {
                    id: row

                    required property string interfaceName
                    // The current sample of this interface; undefined while
                    // the provider does not know it.
                    readonly property var entry: root.entryByName[row.interfaceName]
                    readonly property bool known: row.entry !== undefined
                    readonly property bool hasLabel: row.known && typeof row.entry.label === "string" && row.entry.label !== "" && row.entry.label !== row.interfaceName
                    readonly property string kindText: {
                        if (row.known) {
                            return row.entry.kind === "physical" ? root.trc("@info interface kind", "physical") : root.trc("@info interface kind", "virtual");
                        }
                        // Before the first sample nothing is known yet.
                        return root.source.hasData ? root.trc("@info interface kind", "not available") : "";
                    }

                    width: rowColumn.width
                    spacing: 0

                    QQC2.CheckBox {
                        id: check

                        Layout.fillWidth: true
                        text: row.hasLabel ? row.entry.label + " (" + row.interfaceName + ")" : row.interfaceName
                        enabled: root.manual
                        checked: root.selectedNames.indexOf(row.interfaceName) >= 0
                        onToggled: root.setSelected(row.interfaceName, check.checked)
                    }

                    QQC2.Label {
                        Layout.fillWidth: true
                        Layout.leftMargin: check.leftPadding + check.indicator.width + check.spacing
                        text: row.known ? root.trc("@info interface kind, download and upload speed", "%1 – ↓ %2   ↑ %3", row.kindText, root.speedText(row.entry.down), root.speedText(row.entry.up)) : row.kindText
                        elide: Text.ElideRight
                        font.features: { "tnum": 1 }
                        opacity: 0.7
                    }
                }
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: root.tr("Active source: %1", root.sourceText(root.source.activeSource))
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 25
            visible: text !== ""
            text: root.errorText(root.source.errorCode, root.source.errorDetail)
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.neutralTextColor
        }
    }
}
