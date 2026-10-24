// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// The scrollable list of the network interfaces in the popup: name, speeds,
// totals since the interface became active, the IPv4 address (a click copies
// it) and, for Wi-Fi, the signal. The rows are a name-keyed ListModel brought
// in line with `interfaces` by single removals and insertions, so a row keeps
// its delegate (and the "Copied" note) while the values change.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrolsaddons
import "../../code/format.mjs" as Format
import "../../code/listsync.mjs" as ListSync
import "../../code/selection.mjs" as Selection
import "../../code/text.mjs" as TextTools

Item {
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

    // The interfaces of the snapshot (see interfaceList() in selection.mjs).
    property var interfaces: []
    // Options for formatSpeed() and formatTotal().
    property var formatOptions: Format.DEFAULT_FORMAT
    // Puts a text on the clipboard. Tests replace it.
    property var copyText: text => clipboard.content = text

    // The height of all rows and of the visible part (for the smoke scene).
    readonly property real contentHeight: column.implicitHeight
    readonly property real viewportHeight: scroll.availableHeight
    // The height of the tallest row, so the list never shows less than one
    // full row; it scrolls for the rest. Kept current by measure().
    property real oneRowHeight: 0

    // Recomputes oneRowHeight from the rows that exist.
    function measure() {
        let tallest = 0;
        for (let i = 0; i < rowModel.count; i++) {
            const item = repeater.itemAt(i);
            if (item !== null) {
                tallest = Math.max(tallest, item.implicitHeight);
            }
        }
        root.oneRowHeight = tallest;
    }

    // The row item of `name`; null if there is none.
    function rowFor(name: string): var {
        for (let i = 0; i < rowModel.count; i++) {
            if (rowModel.get(i).interfaceName === name) {
                return repeater.itemAt(i);
            }
        }
        return null;
    }

    // The current sample of every interface, by name. The rows look their
    // values up here and so stay alive between samples.
    readonly property var entryByName: {
        const map = Object.create(null);
        for (const entry of root.interfaces) {
            map[entry.name] = entry;
        }
        return map;
    }

    function syncRows() {
        const current = [];
        for (let row = 0; row < rowModel.count; row++) {
            current.push(rowModel.get(row).interfaceName);
        }
        const wanted = root.interfaces.map(entry => entry.name);
        for (const step of ListSync.syncOps(current, wanted, Selection.compareNames)) {
            if (step.op === "remove") {
                rowModel.remove(step.index);
            } else {
                rowModel.insert(step.index, { "interfaceName": step.name });
            }
        }
    }

    function speedText(bytesPerSecond: real): string {
        const speed = Format.formatSpeed(bytesPerSecond, root.formatOptions);
        return speed.value + " " + speed.unit;
    }

    function totalText(bytes: real): string {
        const total = Format.formatTotal(bytes, root.formatOptions);
        return total.value + " " + total.unit;
    }

    onInterfacesChanged: root.syncRows()
    Component.onCompleted: root.syncRows()

    ListModel {
        id: rowModel
    }

    Clipboard {
        id: clipboard
    }

    QQC2.ScrollView {
        id: scroll

        anchors.fill: parent
        contentWidth: availableWidth

        // A Column, not a ColumnLayout: removing rows from a ColumnLayout
        // crashed in the size hint (see the settings page).
        Column {
            id: column

            width: scroll.availableWidth
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                id: repeater

                model: rowModel

                onItemAdded: Qt.callLater(root.measure)
                onItemRemoved: Qt.callLater(root.measure)

                delegate: ColumnLayout {
                    id: row

                    required property string interfaceName
                    readonly property var entry: root.entryByName[row.interfaceName]
                    readonly property bool known: row.entry !== undefined
                    readonly property bool hasLabel: row.known && typeof row.entry.label === "string" && row.entry.label !== "" && row.entry.label !== row.interfaceName
                    readonly property string ipv4: row.known && row.entry.ipv4 ? row.entry.ipv4 : ""
                    // The Copy button, for the smoke scene.
                    readonly property Item ipButton: ipv4Button

                    // Name, kind, counted or not, signal; each only when it applies.
                    readonly property string details: {
                        if (!row.known) {
                            return row.interfaceName;
                        }
                        const parts = [];
                        if (row.hasLabel) {
                            parts.push(row.interfaceName);
                        }
                        if (row.entry.kind !== "physical") {
                            parts.push(root.trc("@info interface kind", "virtual"));
                        }
                        if (row.entry.included !== true) {
                            parts.push(root.trc("@info interface kind", "not counted"));
                        }
                        if (typeof row.entry.signal === "number") {
                            parts.push(root.trc("@info Wi-Fi signal strength in percent", "Signal %1%", row.entry.signal));
                        }
                        return parts.join(" · ");
                    }
                    readonly property string totals: row.known && row.entry.totalsKnown === true ? root.trc("@info download and upload total since the interface became active", "Total ↓ %1   ↑ %2", root.totalText(row.entry.totalDown), root.totalText(row.entry.totalUp)) : ""

                    width: column.width
                    spacing: 0
                    onImplicitHeightChanged: Qt.callLater(root.measure)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.largeSpacing

                        QQC2.Label {
                            Layout.fillWidth: true
                            text: row.hasLabel ? row.entry.label : row.interfaceName
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        QQC2.Label {
                            visible: row.known
                            text: row.known ? "↓ " + root.speedText(row.entry.down) + "   ↑ " + root.speedText(row.entry.up) : ""
                            font.features: { "tnum": 1 }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        QQC2.Label {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: row.hasLabel || row.known ? row.details : ""
                            elide: Text.ElideRight
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                        }

                        QQC2.Label {
                            visible: copiedTimer.running
                            text: root.trc("@info", "Copied")
                            font: Kirigami.Theme.smallFont
                            color: Kirigami.Theme.positiveTextColor

                            Timer {
                                id: copiedTimer

                                interval: 1500
                            }
                        }

                        QQC2.ToolButton {
                            id: ipv4Button

                            visible: row.ipv4 !== ""
                            text: row.ipv4
                            font: Kirigami.Theme.smallFont
                            QQC2.ToolTip.text: root.trc("@info:tooltip", "Copy IP address")
                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                            onClicked: {
                                root.copyText(row.ipv4);
                                copiedTimer.restart();
                            }
                        }
                    }

                    QQC2.Label {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: row.totals
                        elide: Text.ElideRight
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                    }
                }
            }
        }
    }
}
