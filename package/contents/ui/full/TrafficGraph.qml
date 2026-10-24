// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// The traffic graph of the popup: download and upload over the chosen time
// window with a speed axis, and the switches for the window. It only shows
// what it is given (a snapshot of the history), so it never runs while the
// popup is closed.
//
// Loaded through a Loader (see FullRepresentation): without Qt Quick Charts
// only the graph is missing.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.quickcharts as Charts
import org.kde.quickcharts.controls as ChartControls
import "../../code/format.mjs" as Format
import "../../code/graph.mjs" as Graph
import "../../code/text.mjs" as TextTools

Item {
    id: root

    // Translation helper: the only place that calls Plasma's i18n functions.
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

    // The history object of the provider (null before the first sample).
    property var history: null
    // The time span in minutes: 1, 5 or 15.
    property int minutes: 5
    // Options for formatSpeed() (see FullRepresentation).
    property var formatOptions: Format.DEFAULT_FORMAT

    // The user picked another time span.
    signal minutesPicked(int minutes)

    // The values of the two series as drawn (for the smoke scene).
    readonly property var downSeries: downSource.array
    readonly property var upSeries: upSource.array

    readonly property var windowed: Graph.graphWindow(root.history, root.minutes)
    readonly property var axis: Graph.axisScale(Math.max(0, ...root.windowed.down, ...root.windowed.up), root.formatOptions)
    readonly property int gridSteps: root.axis.steps

    // The download keeps the highlight colour. The upload takes the first of
    // these that is clearly distinct from it: some themes colour the highlight
    // and the neutral colour alike.
    readonly property color downColor: Kirigami.Theme.highlightColor
    readonly property var upCandidates: [Kirigami.Theme.positiveTextColor, Kirigami.Theme.linkColor, Kirigami.Theme.textColor]
    readonly property color upColor: root.upCandidates[Graph.pickDistinct(root.downColor, root.upCandidates.map(c => ({
                r: c.r,
                g: c.g,
                b: c.b
            })))]

    // "256 B/s" for an axis value; no low-speed threshold, or small values
    // would read "0 B/s".
    function axisLabel(bytesPerSecond: real): string {
        const speed = Format.formatSpeed(bytesPerSecond, Object.assign({}, root.formatOptions, {
            lowSpeedThreshold: 0
        }));
        return speed.value + " " + speed.unit;
    }

    // The labels of the speed axis from the bottom to the top. Labels that do
    // not fit the height are empty, so the others keep their grid line.
    readonly property var axisLabels: {
        const keep = Graph.axisLabelIndices(root.gridSteps, plot.height, labelMetrics.height);
        const labels = [];
        for (let i = 0; i <= root.gridSteps; i++) {
            labels.push(keep.indexOf(i) >= 0 ? root.axisLabel(root.axis.step * i) : "");
        }
        return labels;
    }

    TextMetrics {
        id: labelMetrics

        font: Kirigami.Theme.smallFont
        text: "0"
    }

    implicitHeight: Kirigami.Units.gridUnit * 6

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        // The legend on the left, the time span switches on the right.
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: [
                    {
                        symbol: "↓",
                        up: false
                    },
                    {
                        symbol: "↑",
                        up: true
                    }
                ]

                RowLayout {
                    id: legendEntry

                    required property var modelData

                    spacing: Kirigami.Units.smallSpacing

                    Rectangle {
                        implicitWidth: Kirigami.Units.gridUnit * 0.8
                        implicitHeight: Kirigami.Units.smallSpacing
                        radius: height / 2
                        color: legendEntry.modelData.up ? root.upColor : root.downColor
                    }

                    QQC2.Label {
                        text: legendEntry.modelData.symbol
                        font: Kirigami.Theme.smallFont
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Repeater {
                model: [1, 5, 15]

                QQC2.ToolButton {
                    required property int modelData

                    text: root.trc("@option:radio time span of the graph", "%1 min", modelData)
                    font: Kirigami.Theme.smallFont
                    checkable: true
                    checked: root.minutes === modelData
                    // A click toggles `checked` and breaks its binding; the
                    // chosen span (not the click) decides, so bind it again.
                    onClicked: {
                        checked = Qt.binding(() => root.minutes === modelData);
                        root.minutesPicked(modelData);
                    }
                }
            }
        }

        Item {
            id: plot

            Layout.fillWidth: true
            Layout.fillHeight: true

            ChartControls.AxisLabels {
                id: speedLabels

                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
                direction: ChartControls.AxisLabels.VerticalBottomTop
                constrainToBounds: true
                delegate: QQC2.Label {
                    text: ChartControls.AxisLabels.label
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                }
                source: Charts.ArraySource {
                    array: root.axisLabels
                }
            }

            ChartControls.GridLines {
                anchors.fill: lineChart
                chart: lineChart
                // Lines across the chart, one per axis label.
                direction: ChartControls.GridLines.Vertical
                // One major span cut into gridSteps parts, all drawn alike.
                major.count: 1
                major.lineWidth: 1
                major.color: Qt.alpha(Kirigami.Theme.textColor, 0.2)
                minor.count: root.gridSteps - 1
                minor.lineWidth: 1
                minor.color: Qt.alpha(Kirigami.Theme.textColor, 0.2)
            }

            Charts.LineChart {
                id: lineChart

                anchors {
                    left: speedLabels.right
                    leftMargin: Kirigami.Units.smallSpacing
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                }
                yRange {
                    from: 0
                    to: root.axis.max
                    automatic: false
                }
                // The x axis is by sample; only the selection is by time.
                xRange.automatic: true
                lineWidth: 2
                fillOpacity: 0.15
                colorSource: Charts.ArraySource {
                    array: [root.downColor, root.upColor]
                }
                valueSources: [
                    Charts.ArraySource {
                        id: downSource

                        array: root.windowed.down
                    },
                    Charts.ArraySource {
                        id: upSource

                        array: root.windowed.up
                    }
                ]
            }
        }
    }
}
