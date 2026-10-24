// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// The popup (and the desktop view): header with the current speeds, the
// status and a note about the data source, a footer with the button for the
// system monitor and the active source. The view reads nothing from Plasmoid,
// so it also runs in plain qml6 (see tests/qml/PopupSmoke.qml).
//
// Everything below the header reads `shown`, a snapshot of the provider that
// is only refreshed while the popup is active: a closed popup does not
// compute anything.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../../code/format.mjs" as Format
import "../../code/text.mjs" as TextTools
import "../../code/tooltip.mjs" as Tooltip

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

    // The NetworkProvider whose outputs are shown (through `shown`).
    required property var provider
    // Options for formatSpeed(): unitSystem, shortUnits, decimals,
    // lowSpeedThreshold and decimalPoint.
    required property var formatOptions
    // Whether the popup is visible; only then `shown` follows the provider.
    property bool active: true
    // The time span of the graph in minutes.
    property int graphMinutes: 5

    // The user picked another time span in the graph.
    signal graphMinutesPicked(int minutes)
    // The button for the system monitor was pressed.
    signal openSystemMonitor

    // The provider values as of the last refresh. Never write it elsewhere.
    readonly property var shown: internals.shown
    // The height the content asks for (for the smoke scene).
    readonly property real contentHeight: column.implicitHeight

    Layout.preferredWidth: Kirigami.Units.gridUnit * 22
    Layout.preferredHeight: Kirigami.Units.gridUnit * 26
    Layout.minimumWidth: Kirigami.Units.gridUnit * 18
    Layout.minimumHeight: Kirigami.Units.gridUnit * 20

    // Copies the provider values into `shown`; does nothing while inactive.
    function refresh() {
        if (!root.active) {
            return;
        }
        internals.shown = {
            hasData: root.provider.hasData,
            down: root.provider.down,
            up: root.provider.up,
            online: root.provider.online,
            stale: root.provider.stale,
            activeSource: root.provider.activeSource,
            primaryLabel: root.provider.primaryLabel,
            primaryIp: root.provider.primaryIp,
            interfaces: root.provider.interfaces,
            history: root.provider.history,
            errorCode: root.provider.errorCode,
            errorDetail: root.provider.errorDetail,
            fallbackNote: root.provider.fallbackNote
        };
    }

    // "↓ 1.5 MiB/s"; "↓ –" before the first data.
    function speedLine(symbol: string, bytesPerSecond: real): string {
        if (!root.shown.hasData) {
            return symbol + " –";
        }
        const speed = Format.formatSpeed(bytesPerSecond, root.formatOptions);
        return symbol + " " + speed.value + " " + speed.unit;
    }

    function statusText(state: var): string {
        if (!state.hasData) {
            return root.tr("Waiting for network data…");
        }
        if (state.stale) {
            return root.tr("No current data");
        }
        return state.online ? root.tr("Online") : root.tr("Offline");
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

    onActiveChanged: {
        if (root.active) {
            root.refresh();
        }
    }
    Component.onCompleted: root.refresh()

    QtObject {
        id: internals

        // A snapshot, replaced as a whole by refresh().
        property var shown: ({
                hasData: false,
                down: 0,
                up: 0,
                online: false,
                stale: false,
                activeSource: "",
                primaryLabel: "",
                primaryIp: "",
                interfaces: [],
                history: null,
                errorCode: "",
                errorDetail: "",
                fallbackNote: ""
            })
    }

    // Any change of a shown value asks for one refresh once all bindings of
    // the change are in: a sample or a selection change touches several
    // properties.
    Connections {
        target: root.provider
        enabled: root.active

        function onHasDataChanged() {
            Qt.callLater(root.refresh);
        }
        function onDownChanged() {
            Qt.callLater(root.refresh);
        }
        function onUpChanged() {
            Qt.callLater(root.refresh);
        }
        function onOnlineChanged() {
            Qt.callLater(root.refresh);
        }
        function onStaleChanged() {
            Qt.callLater(root.refresh);
        }
        function onActiveSourceChanged() {
            Qt.callLater(root.refresh);
        }
        function onPrimaryLabelChanged() {
            Qt.callLater(root.refresh);
        }
        function onPrimaryIpChanged() {
            Qt.callLater(root.refresh);
        }
        function onInterfacesChanged() {
            Qt.callLater(root.refresh);
        }
        function onHistoryChanged() {
            Qt.callLater(root.refresh);
        }
        function onErrorCodeChanged() {
            Qt.callLater(root.refresh);
        }
        function onErrorDetailChanged() {
            Qt.callLater(root.refresh);
        }
        function onFallbackNoteChanged() {
            Qt.callLater(root.refresh);
        }
    }

    ColumnLayout {
        id: column

        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Heading {
                Layout.fillWidth: true
                level: 2
                text: root.speedLine("↓", root.shown.down)
                elide: Text.ElideRight
            }

            Kirigami.Heading {
                Layout.fillWidth: true
                level: 2
                text: root.speedLine("↑", root.shown.up)
                elide: Text.ElideRight
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.shown.primaryLabel
            elide: Text.ElideRight
        }

        QQC2.Label {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.shown.primaryIp
            opacity: 0.7
            elide: Text.ElideRight
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: root.statusText(root.shown)
            opacity: 0.7
            elide: Text.ElideRight
        }

        // The note about the data source. Not a Kirigami.InlineMessage: its
        // label cannot be told to read StyledText, and the lines from
        // hintLines() are escaped for it.
        Rectangle {
            Layout.fillWidth: true
            visible: hint.text !== ""
            implicitHeight: hint.implicitHeight + Kirigami.Units.smallSpacing * 2
            radius: Kirigami.Units.cornerRadius
            color: Qt.alpha(Kirigami.Theme.neutralTextColor, 0.15)
            border.color: Kirigami.Theme.neutralTextColor
            border.width: 1

            QQC2.Label {
                id: hint

                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                text: Tooltip.hintLines(root.shown, {
                    tr: root.tr,
                    trc: root.trc
                }).join("<br>")
                textFormat: Text.StyledText
                wrapMode: Text.WordWrap
            }
        }

        // Placeholder for the graph.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Kirigami.Units.gridUnit * 3
        }

        // Placeholder for the figures and the list of interfaces.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Kirigami.Units.gridUnit * 3
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            QQC2.Button {
                text: root.tr("Open System Monitor")
                onClicked: root.openSystemMonitor()
            }

            QQC2.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: root.trc("@info", "Source: %1", root.sourceText(root.shown.activeSource))
                opacity: 0.7
                elide: Text.ElideRight
            }
        }
    }
}
