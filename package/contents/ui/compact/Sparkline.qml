// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// The small line chart of the panel view: the most recent samples of download
// and upload (or of their sum), without axes or grid. It only shows what it is
// given.
//
// Loaded through a Loader (see CompactRepresentation): without Qt Quick Charts
// only the chart is missing.

import QtQuick
import org.kde.quickcharts as Charts
import "../../code/graph.mjs" as Graph

Item {
    id: root

    // The history object of the provider (null before the first sample).
    property var history: null
    property color downColor: "white"
    property color upColor: "white"
    // One line with the sum of both directions instead of two.
    property bool combined: false
    // Fill below the lines (the chart behind the text).
    property bool filled: false

    readonly property var samples: Graph.lastSamples(root.history, Graph.SPARKLINE_SAMPLES)
    // The values as drawn (for the smoke scene); with `combined` only
    // downSeries, holding the sums.
    readonly property var downSeries: root.combined ? root.samples.down.map((v, i) => v + root.samples.up[i]) : root.samples.down
    readonly property var upSeries: root.combined ? [] : root.samples.up

    // The fill opacity as drawn (for the smoke scene).
    readonly property real fillOpacity: chart.fillOpacity

    Charts.LineChart {
        id: chart

        anchors.fill: parent
        // From zero, so the height tells the magnitude and a flat line sits at
        // the bottom edge.
        yRange {
            from: 0
            to: Graph.sparklineMax(root.samples.down, root.samples.up, root.combined)
            automatic: false
        }
        // A fixed window of the newest samples: while fewer exist the line
        // fills from the right instead of stretching.
        xRange {
            from: root.downSeries.length - Graph.SPARKLINE_SAMPLES
            to: Math.max(root.downSeries.length, 2) - 1
            automatic: false
        }
        smooth: true
        lineWidth: 1
        // Full inside the layer that the view dims to 35 %
        fillOpacity: root.filled ? 1 : 0
        colorSource: Charts.ArraySource {
            array: root.combined ? [root.downColor] : [root.downColor, root.upColor]
        }
        valueSources: root.combined ? [downSource] : [downSource, upSource]
    }

    Charts.ArraySource {
        id: downSource

        array: root.downSeries
    }

    Charts.ArraySource {
        id: upSource

        array: root.upSeries
    }
}
