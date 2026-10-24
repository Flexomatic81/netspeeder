// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// One direction of the speed display: a symbol, the value and its unit. The
// value is right-aligned and the unit left-aligned, so the decimal point and the
// unit start stay put while the numbers change. Normally everything sits on one
// row; in a narrow vertical panel the label can be stacked on two lines.
//
// Every part gets an exact preferred width. A Layout rounds up the size of a
// part that has none, which adds up to a pixel per part: too much for a panel
// that is only 32 pixels wide.

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

GridLayout {
    id: root

    // Direction symbol, for example an arrow; with iconSymbol the name of a
    // theme icon, shown as high as the text.
    property string symbol: ""
    // A second symbol right after the first, for the sum of both directions.
    property string secondSymbol: ""
    property bool iconSymbol: false
    property string valueText: ""
    property string unitText: ""
    // Width of the value and unit slots; 0 uses the natural width of the text.
    property real valueWidth: 0
    property real unitWidth: 0
    // Empty uses the font of the Plasma theme.
    property string fontFamily: ""
    property int pixelSize: Kirigami.Theme.defaultFont.pixelSize
    property bool bold: false
    // The colour of the value, and of the symbol and unit.
    property color valueColor: Kirigami.Theme.textColor
    property color unitColor: Kirigami.Theme.textColor
    // Two lines instead of one: symbol and value on top, the unit below them.
    property bool stacked: false
    // Only when stacked: the value stands alone on top, and the symbol moves to
    // the second line in front of the unit.
    property bool symbolBelow: false

    readonly property string family: root.fontFamily !== "" ? root.fontFamily : Kirigami.Theme.defaultFont.family
    readonly property bool valueAlone: root.stacked && root.symbolBelow
    // Gaps between the parts, relative to the text size.
    readonly property real symbolGap: root.symbol !== "" ? 0.25 * root.pixelSize : 0
    readonly property real unitGap: 0.2 * root.pixelSize

    // The widths the parts ask for.
    readonly property real symbolSlot: root.iconSymbol ? iconBox.implicitWidth : symbolText.implicitWidth
    readonly property real valueSlot: root.valueWidth > 0 ? root.valueWidth : valueLabel.implicitWidth
    readonly property real unitSlot: root.unitWidth > 0 ? root.unitWidth : unitLabel.implicitWidth

    columns: root.stacked ? 2 : 3
    columnSpacing: 0
    rowSpacing: 0

    Text {
        id: symbolText

        visible: !root.iconSymbol
        text: root.symbol + root.secondSymbol
        font.family: root.family
        font.pixelSize: root.pixelSize
        font.bold: root.bold
        font.features: { "tnum": 1 }
        color: root.unitColor
        renderType: Text.NativeRendering
        Layout.row: root.valueAlone ? 1 : 0
        Layout.column: 0
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        Layout.preferredWidth: root.symbolSlot
    }

    // The symbols as icons, in the same place as the text above.
    Row {
        id: iconBox

        visible: root.iconSymbol
        Layout.row: root.valueAlone ? 1 : 0
        Layout.column: 0
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        Layout.preferredWidth: root.symbolSlot

        Kirigami.Icon {
            source: root.iconSymbol ? root.symbol : ""
            // Tints symbolic icons; others keep their own colours.
            color: root.unitColor
            implicitWidth: root.pixelSize
            implicitHeight: root.pixelSize
        }

        Kirigami.Icon {
            visible: root.secondSymbol !== ""
            source: root.iconSymbol ? root.secondSymbol : ""
            color: root.unitColor
            implicitWidth: root.pixelSize
            implicitHeight: root.pixelSize
        }
    }

    Text {
        id: valueLabel

        text: root.valueText
        font.family: root.family
        font.pixelSize: root.pixelSize
        font.bold: root.bold
        font.features: { "tnum": 1 }
        color: root.valueColor
        renderType: Text.NativeRendering
        horizontalAlignment: Text.AlignRight
        Layout.row: 0
        Layout.column: root.valueAlone ? 0 : 1
        Layout.columnSpan: root.valueAlone ? 2 : 1
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: root.valueAlone ? 0 : root.symbolGap
        // As wide as the line below if that is wider: the value stays flush right.
        Layout.preferredWidth: {
            if (!root.stacked) {
                return root.valueSlot;
            }
            return root.valueAlone ? Math.max(root.valueSlot, root.symbolSlot + root.symbolGap + root.unitSlot) : Math.max(root.valueSlot, root.unitSlot - root.symbolSlot - root.symbolGap);
        }
    }

    Text {
        id: unitLabel

        text: root.unitText
        font.family: root.family
        font.pixelSize: root.pixelSize
        font.bold: root.bold
        font.features: { "tnum": 1 }
        color: root.unitColor
        renderType: Text.NativeRendering
        horizontalAlignment: Text.AlignLeft
        // One row: after the value. Stacked: below the symbol and the value, or
        // after the symbol when that moved down as well.
        Layout.row: root.stacked ? 1 : 0
        Layout.column: root.stacked ? (root.valueAlone ? 1 : 0) : 2
        Layout.columnSpan: root.stacked && !root.valueAlone ? 2 : 1
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        Layout.leftMargin: root.stacked ? (root.valueAlone ? root.symbolGap : 0) : root.unitGap
        // As wide as the value above if that is wider, so the columns add up.
        Layout.preferredWidth: root.valueAlone ? Math.max(root.unitSlot, root.valueSlot - root.symbolSlot - root.symbolGap) : root.unitSlot
    }
}
