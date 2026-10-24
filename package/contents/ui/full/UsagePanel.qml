// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// The usage section of the popup: down, up and the sum for today, yesterday,
// the current and the last billing period from vnStat (a period vnStat does
// not cover completely is marked with "*" and a footnote), the share of the data
// cap as a bar, when vnStat last wrote its data, and a hint when vnStat is
// missing, unsupported, failed or still loading. Hidden while disabled.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../code/format.mjs" as Format
import "../../code/text.mjs" as TextTools
import "../../code/usage.mjs" as Usage

ColumnLayout {
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

    // The result of usageSummary() (or emptySummary() before any data).
    property var summary: Usage.emptySummary(Usage.localNow(new Date()), 1)
    // The status of the UsageSource: "disabled", "loading", "missing",
    // "unsupported", "error" or "ok".
    property string status: "loading"
    // The reason of an "error".
    property string detail: ""
    // The data cap: { enabled, percent, level, capBytes }.
    property var cap: ({
            enabled: false,
            percent: 0,
            level: 0,
            capBytes: 0
        })
    // When vnStat last wrote its data ("YYYY-MM-DDTHH:MM"), or "".
    property string lastUpdated: ""
    // Whether lastUpdated is too old (see isOutdated() in usage.mjs).
    property bool outdated: false
    // Options for formatTotal().
    property var formatOptions: Format.DEFAULT_FORMAT

    // The bar of the data cap and its color (for the smoke scene).
    readonly property Item capBar: bar
    readonly property color capColor: root.cap.level >= 2 ? Kirigami.Theme.negativeTextColor : root.cap.level === 1 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.highlightColor

    // Whether there are figures to show; a failure after a success keeps them.
    readonly property bool hasData: root.summary.status === "ok"

    // The number of table cells and one of them (for the smoke scene).
    readonly property int cellCount: cellRepeater.count
    function cellAt(index: int): Item {
        return cellRepeater.itemAt(index);
    }

    // The rows of the table: name, figures and, for a billing period, its
    // span and whether vnStat covers it completely.
    readonly property var rows: [
        { name: root.trc("@label", "Today"), usage: root.summary.today, period: null },
        { name: root.trc("@label", "Yesterday"), usage: root.summary.yesterday, period: null },
        { name: root.trc("@label", "This period"), usage: root.summary.current, period: root.summary.current },
        { name: root.trc("@label", "Last period"), usage: root.summary.previous, period: root.summary.previous }
    ]
    // Whether a period is marked as incomplete (shows the footnote).
    readonly property bool anyIncomplete: !root.summary.current.complete || !root.summary.previous.complete
    // The cells as { row, column }: name, mark, down, up and sum. A constant
    // model, so the cells (and an open tooltip) stay while the figures change.
    readonly property var cellModel: {
        const cells = [];
        for (let row = 0; row < 4; row++) {
            for (let column = 0; column < 5; column++) {
                cells.push({ row: row, column: column });
            }
        }
        return cells;
    }

    function cellText(rowIndex: int, column: int): string {
        const row = root.rows[rowIndex];
        switch (column) {
        case 0:
            return row.name;
        case 1:
            return row.period !== null && !row.period.complete ? "*" : "";
        case 2:
            return "↓ " + root.totalText(row.usage.down);
        case 3:
            return "↑ " + root.totalText(row.usage.up);
        default:
            return "Σ " + root.totalText(row.usage.total);
        }
    }

    // The name and the span of a billing period; "" for the other cells.
    function cellTip(rowIndex: int, column: int): string {
        const row = root.rows[rowIndex];
        if (row.period === null || column > 1) {
            return "";
        }
        return row.name + "\n" + root.dayText(row.period.start) + " – " + root.dayText(row.period.end);
    }

    function totalText(bytes: real): string {
        const total = Format.formatTotal(bytes, root.formatOptions);
        return total.value + " " + total.unit;
    }

    // A local Date for a day key or an update stamp; null when invalid.
    function localDate(text: string): var {
        const p = Usage.dateParts(text);
        return p === null ? null : new Date(p.year, p.month - 1, p.day, p.hour, p.minute);
    }

    // "10/24/26" in the format of the locale.
    function dayText(key: string): string {
        const date = root.localDate(key);
        return date === null ? key : date.toLocaleDateString(Qt.locale(), Locale.ShortFormat);
    }

    // "10/24/26 6:00 PM" in the format of the locale.
    function stampText(stamp: string): string {
        const date = root.localDate(stamp);
        return date === null ? stamp : date.toLocaleString(Qt.locale(), Locale.ShortFormat);
    }

    // "85.5" with the decimal point of the locale.
    function percentText(percent: real): string {
        return String(percent).replace(".", root.formatOptions.decimalPoint ?? ".");
    }

    // The hint for a status without figures; "" when there is none.
    function statusHint(): string {
        switch (root.status) {
        case "missing":
            return root.tr("Install vnstat and enable its service to see daily and monthly usage.");
        case "unsupported":
            return root.tr("This vnstat version is not supported.");
        case "error":
            return root.tr("Reading vnstat failed: %1", root.detail);
        case "loading":
            return root.hasData ? "" : root.tr("Loading usage…");
        default:
            return "";
        }
    }

    visible: root.status !== "disabled"
    spacing: Kirigami.Units.smallSpacing

    Kirigami.Heading {
        Layout.fillWidth: true
        level: 5
        text: root.trc("@title:group", "Usage")
        elide: Text.ElideRight
    }

    GridLayout {
        Layout.fillWidth: true
        visible: root.hasData
        columns: 5
        columnSpacing: Kirigami.Units.smallSpacing
        rowSpacing: 0

        Repeater {
            id: cellRepeater

            model: root.cellModel

            delegate: QQC2.Label {
                id: cell

                required property var modelData
                readonly property string tip: root.cellTip(cell.modelData.row, cell.modelData.column)

                // The names give way to the figures on a narrow popup; the
                // mark keeps its width.
                Layout.fillWidth: cell.modelData.column === 0
                Layout.minimumWidth: cell.modelData.column === 0 ? 0 : implicitWidth
                Layout.leftMargin: cell.modelData.column > 1 ? Kirigami.Units.smallSpacing : 0
                text: root.cellText(cell.modelData.row, cell.modelData.column)
                opacity: cell.modelData.column <= 1 ? 0.7 : 1
                elide: Text.ElideRight
                font.features: { "tnum": 1 }

                HoverHandler {
                    id: hover

                    enabled: cell.tip !== ""
                }

                QQC2.ToolTip.text: cell.tip
                QQC2.ToolTip.visible: hover.hovered && cell.tip !== ""
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }
    }

    QQC2.Label {
        Layout.fillWidth: true
        visible: root.hasData && root.anyIncomplete
        text: root.tr("* incomplete: vnstat lacks some days of this period")
        font: Kirigami.Theme.smallFont
        opacity: 0.7
        wrapMode: Text.WordWrap
    }

    QQC2.Label {
        Layout.fillWidth: true
        visible: root.hasData && root.cap.enabled
        text: root.tr("%1 of %2 (%3 %)", root.totalText(root.summary.current.total), root.totalText(root.cap.capBytes), root.percentText(root.cap.percent))
        color: root.cap.level > 0 ? root.capColor : Kirigami.Theme.textColor
        elide: Text.ElideRight
        font.features: { "tnum": 1 }
    }

    QQC2.ProgressBar {
        id: bar

        Layout.fillWidth: true
        visible: root.hasData && root.cap.enabled
        from: 0
        to: 100
        value: Math.min(Math.max(root.cap.percent, 0), 100)
        palette.highlight: root.capColor
        Kirigami.Theme.highlightColor: root.capColor
    }

    QQC2.Label {
        Layout.fillWidth: true
        visible: root.hasData && root.lastUpdated !== ""
        text: root.tr("vnstat last updated: %1", root.stampText(root.lastUpdated))
        font: Kirigami.Theme.smallFont
        opacity: 0.7
        elide: Text.ElideRight
    }

    QQC2.Label {
        Layout.fillWidth: true
        visible: root.hasData && root.outdated
        text: root.tr("The vnstat data is not current. Is the vnstat service running?")
        color: Kirigami.Theme.neutralTextColor
        wrapMode: Text.WordWrap
    }

    QQC2.Label {
        Layout.fillWidth: true
        visible: root.hasData && root.summary.untracked.length > 0
        text: root.tr("vnstat does not track %1", root.summary.untracked.join(", "))
        textFormat: Text.PlainText
        opacity: 0.7
        wrapMode: Text.WordWrap
    }

    QQC2.Label {
        Layout.fillWidth: true
        visible: text !== ""
        text: root.statusHint()
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        opacity: 0.7
    }

    QQC2.Button {
        visible: root.status === "missing"
        flat: true
        icon.name: "internet-web-browser"
        text: root.tr("vnstat website")
        onClicked: Qt.openUrlExternally("https://humdi.net/vnstat/")
    }
}
