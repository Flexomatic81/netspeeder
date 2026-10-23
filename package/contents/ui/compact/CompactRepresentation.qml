// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81
// SPDX-FileCopyrightText: 2016 Daniel Faust <hessijames@gmail.com>

// The panel view: download and upload speed, adapted to the panel. A horizontal
// panel shows two rows or two columns, depending on its height. A vertical panel
// stacks the directions and puts each on two lines (symbol and value, then the
// unit); when that is too wide for the panel, the display degrades step by step
// until the text is still readable. The view reads nothing from Plasmoid, so it
// also runs in plain qml6 (see tests/qml/CompactSmoke.qml).

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../code/format.mjs" as Format
import "../../code/layout.mjs" as LayoutLogic

Item {
    id: root

    // The NetworkProvider whose down, up, hasData and stale values are shown.
    required property var provider
    // Options for formatSpeed(): unitSystem, shortUnits, decimals,
    // lowSpeedThreshold and decimalPoint.
    required property var formatOptions
    // Whether the panel is vertical.
    property bool vertical: false
    // The layout setting: "auto", "rows" or "columns".
    property string layoutMode: "auto"
    property bool uploadFirst: false
    // One value (download plus upload) instead of two.
    property bool combined: false
    // Reserves the width of the widest value and unit, so the panel does not
    // change its width while the numbers change.
    property bool fixedWidth: true
    // Text size in percent of the size that fits the panel.
    property int fontScale: 100
    // The smallest text size that is still readable, and the text size of a
    // vertical panel at fontScale 100. They follow the theme; only the smoke
    // scenes set them, because plain qml6 reports odd theme fonts.
    property int minReadablePx: Kirigami.Theme.smallFont.pixelSize
    property int baseFontPx: Kirigami.Theme.defaultFont.pixelSize

    // "single", "rows" or "columns"
    readonly property string resolvedLayout: LayoutLogic.resolveLayout({
            mode: root.layoutMode,
            vertical: root.vertical,
            combined: root.combined,
            thickness: root.vertical ? root.width : root.height,
            fontScale: root.fontScale,
            minReadablePx: root.minReadablePx
        })
    readonly property bool single: root.resolvedLayout === "single"
    readonly property string family: Kirigami.Theme.defaultFont.family

    // Text size and, in a vertical panel, the chosen display variant.
    readonly property real rowHeight: root.resolvedLayout === "rows" ? root.height / 2 : root.height
    readonly property var verticalFit: root.vertical ? LayoutLogic.fitVertical(root.width, root.variantWidths, root.baseFontPx * root.fontScale / 100, root.minReadablePx) : ({
            index: 0,
            pixelSize: 0
        })
    readonly property int pixelSize: root.vertical ? root.verticalFit.pixelSize : LayoutLogic.fontPixelSize(root.rowHeight, root.fontScale)
    // The index is clamped: while the settings change, the variants may be
    // replaced a moment before the fit has been recalculated.
    readonly property var activeVariant: root.variants[Math.min(root.vertical ? root.verticalFit.index : 0, root.variants.length - 1)]

    // What the display shows. Before the first data there is no number to show.
    readonly property var downSpeed: root.speedFor(root.provider.down, root.activeVariant.options)
    readonly property var upSpeed: root.speedFor(root.provider.up, root.activeVariant.options)
    readonly property var totalSpeed: root.speedFor(root.provider.down + root.provider.up, root.activeVariant.options)
    readonly property var firstSpeed: root.single ? root.totalSpeed : (root.uploadFirst ? root.upSpeed : root.downSpeed)
    readonly property var secondSpeed: root.uploadFirst ? root.downSpeed : root.upSpeed
    readonly property string firstSymbol: root.single ? "↓↑" : (root.uploadFirst ? "↑" : "↓")
    readonly property string secondSymbol: root.uploadFirst ? "↓" : "↑"

    // The width of the slots for value and unit, in pixels at the current size;
    // 0 lets the texts take their natural width.
    readonly property real valueSlot: root.fixedWidth ? root.activeVariant.valueWidth * root.pixelSize / LayoutLogic.REFERENCE_PX : 0
    readonly property real unitSlot: root.fixedWidth ? root.activeVariant.unitWidth * root.pixelSize / LayoutLogic.REFERENCE_PX : 0

    readonly property string accessibleName: {
        const down = root.plainSpeed(root.provider.down);
        const up = root.plainSpeed(root.provider.up);
        // i18nc exists only inside Plasma; plain qml6 (the smoke scenes) gets English.
        return typeof i18nc === "function" ? i18nc("@info accessible", "Download %1, upload %2", down, up) : "Download " + down + ", upload " + up;
    }

    // Value and unit for a rate; "–" without a unit before the first data.
    function speedFor(bytesPerSecond: real, options: var): var {
        if (!root.provider.hasData) {
            return {
                value: "–",
                unit: ""
            };
        }
        return Format.formatSpeed(bytesPerSecond, options);
    }

    // "1.5 MiB/s" in the settings of the user, for screen readers.
    function plainSpeed(bytesPerSecond: real): string {
        const speed = root.speedFor(bytesPerSecond, root.formatOptions);
        return speed.unit !== "" ? speed.value + " " + speed.unit : speed.value;
    }

    // --- Measuring ---------------------------------------------------------
    // All texts are measured once at LayoutLogic.REFERENCE_PX with the font and
    // the tabular digits of SpeedLabel, and scaled linearly to the size in use.
    // advanceWidth is the width a text needs; boundingRect would underestimate it.

    readonly property bool autoDecimals: [0, 1, 2].indexOf(root.formatOptions.decimals) < 0
    // The settings with no decimals (only if they are chosen automatically).
    readonly property var compactOptions: Object.assign({}, root.formatOptions, {
            decimals: root.autoDecimals ? 0 : root.formatOptions.decimals
        })
    readonly property var longUnits: Format.speedUnits(Object.assign({}, root.formatOptions, {
            shortUnits: false
        }))
    readonly property var shortUnits: Format.speedUnits(Object.assign({}, root.formatOptions, {
            shortUnits: true
        }))
    readonly property real longUnitWidth: Math.max(longUnit0.advanceWidth, longUnit1.advanceWidth, longUnit2.advanceWidth, longUnit3.advanceWidth)
    readonly property real shortUnitWidth: Math.max(shortUnit0.advanceWidth, shortUnit1.advanceWidth, shortUnit2.advanceWidth, shortUnit3.advanceWidth)
    readonly property real symbolWidth: root.single ? symbolBoth.advanceWidth : Math.max(symbolDown.advanceWidth, symbolUp.advanceWidth)

    // The ways a vertical panel can show the speeds, from the most to the least
    // space-hungry: as chosen; no decimals; no decimals and short units; the
    // same with the symbol moved to the unit line. The slot widths of value and
    // unit are at the reference size.
    readonly property var variants: {
        const unitWidth = options => (options.shortUnits ? root.shortUnitWidth : root.longUnitWidth);
        const shortOptions = Object.assign({}, root.compactOptions, {
            shortUnits: true
        });
        const list = [
            {
                options: root.formatOptions,
                symbolBelow: false,
                valueWidth: valueFull.advanceWidth,
                unitWidth: unitWidth(root.formatOptions)
            }
        ];
        if (root.autoDecimals) {
            list.push({
                options: root.compactOptions,
                symbolBelow: false,
                valueWidth: valueCompact.advanceWidth,
                unitWidth: unitWidth(root.compactOptions)
            });
        }
        list.push({
            options: shortOptions,
            symbolBelow: false,
            valueWidth: valueCompact.advanceWidth,
            unitWidth: root.shortUnitWidth
        }, {
            options: shortOptions,
            symbolBelow: true,
            valueWidth: valueCompact.advanceWidth,
            unitWidth: root.shortUnitWidth
        });
        return list;
    }

    // Width at the reference size that the panel needs for each variant.
    readonly property var variantWidths: root.variants.map(variant => {
        const gap = 0.25 * LayoutLogic.REFERENCE_PX;
        const label = variant.symbolBelow ? Math.max(variant.valueWidth, root.symbolWidth + gap + variant.unitWidth) : Math.max(root.symbolWidth + gap + variant.valueWidth, variant.unitWidth);
        return root.resolvedLayout === "columns" ? 2 * label + 0.6 * LayoutLogic.REFERENCE_PX : label;
    })

    implicitWidth: grid.implicitWidth
    implicitHeight: grid.implicitHeight
    // The panel sizes the view along its own direction by what it needs.
    Layout.minimumWidth: root.vertical ? -1 : root.implicitWidth
    Layout.preferredWidth: root.vertical ? -1 : root.implicitWidth
    Layout.minimumHeight: root.vertical ? root.implicitHeight : -1
    Layout.preferredHeight: root.vertical ? root.implicitHeight : -1

    opacity: root.provider.stale ? 0.5 : 1
    Accessible.role: Accessible.StaticText
    Accessible.name: root.accessibleName

    // Carries the font that the measuring below uses.
    Text {
        id: referenceFont

        visible: false
        font.family: root.family
        font.pixelSize: LayoutLogic.REFERENCE_PX
        font.features: { "tnum": 1 }
    }

    TextMetrics {
        id: valueFull

        font: referenceFont.font
        text: Format.widestValue(root.formatOptions)
    }

    TextMetrics {
        id: valueCompact

        font: referenceFont.font
        text: Format.widestValue(root.compactOptions)
    }

    TextMetrics {
        id: longUnit0

        font: referenceFont.font
        text: root.longUnits[0] || ""
    }

    TextMetrics {
        id: longUnit1

        font: referenceFont.font
        text: root.longUnits[1] || ""
    }

    TextMetrics {
        id: longUnit2

        font: referenceFont.font
        text: root.longUnits[2] || ""
    }

    TextMetrics {
        id: longUnit3

        font: referenceFont.font
        text: root.longUnits[3] || ""
    }

    TextMetrics {
        id: shortUnit0

        font: referenceFont.font
        text: root.shortUnits[0] || ""
    }

    TextMetrics {
        id: shortUnit1

        font: referenceFont.font
        text: root.shortUnits[1] || ""
    }

    TextMetrics {
        id: shortUnit2

        font: referenceFont.font
        text: root.shortUnits[2] || ""
    }

    TextMetrics {
        id: shortUnit3

        font: referenceFont.font
        text: root.shortUnits[3] || ""
    }

    TextMetrics {
        id: symbolDown

        font: referenceFont.font
        text: "↓"
    }

    TextMetrics {
        id: symbolUp

        font: referenceFont.font
        text: "↑"
    }

    TextMetrics {
        id: symbolBoth

        font: referenceFont.font
        text: "↓↑"
    }

    GridLayout {
        id: grid

        // Centered, but never pushed out at the left when the view is narrower
        // than the content.
        x: Math.max(0, Math.round((root.width - grid.implicitWidth) / 2))
        anchors.verticalCenter: parent.verticalCenter
        columns: root.resolvedLayout === "columns" ? 2 : 1
        columnSpacing: 0.6 * root.pixelSize
        // A little air between the directions of a vertical panel, whose four
        // lines would otherwise look like one block.
        rowSpacing: root.vertical ? Math.round(0.3 * root.pixelSize) : 0

        SpeedLabel {
            id: firstLabel

            symbol: root.firstSymbol
            valueText: root.firstSpeed.value
            unitText: root.firstSpeed.unit
            valueWidth: root.valueSlot
            unitWidth: root.unitSlot
            pixelSize: root.pixelSize
            stacked: root.vertical
            symbolBelow: root.activeVariant.symbolBelow
            Layout.fillWidth: false
            Layout.preferredHeight: root.vertical ? -1 : root.rowHeight
        }

        SpeedLabel {
            id: secondLabel

            visible: !root.single
            symbol: root.secondSymbol
            valueText: root.secondSpeed.value
            unitText: root.secondSpeed.unit
            valueWidth: root.valueSlot
            unitWidth: root.unitSlot
            pixelSize: root.pixelSize
            stacked: root.vertical
            symbolBelow: root.activeVariant.symbolBelow
            Layout.fillWidth: false
            Layout.preferredHeight: root.vertical ? -1 : root.rowHeight
        }
    }
}
