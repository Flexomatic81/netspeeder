// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// One direction of the speed display: a symbol, the value and its unit on one
// row. The value is right-aligned and the unit left-aligned, so the decimal
// point and the unit start stay put while the numbers change.

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

RowLayout {
    id: root

    // Direction symbol, for example an arrow.
    property string symbol: ""
    property string valueText: ""
    property string unitText: ""
    // Width of the value and unit slots; 0 uses the natural width of the text.
    property real valueWidth: 0
    property real unitWidth: 0
    // Empty uses the font of the Plasma theme.
    property string fontFamily: ""
    property int pixelSize: Kirigami.Theme.defaultFont.pixelSize
    property bool bold: false
    property color textColor: Kirigami.Theme.textColor

    readonly property string family: root.fontFamily !== "" ? root.fontFamily : Kirigami.Theme.defaultFont.family

    spacing: Kirigami.Units.smallSpacing

    Text {
        id: symbolText

        text: root.symbol
        font.family: root.family
        font.pixelSize: root.pixelSize
        font.bold: root.bold
        font.features: { "tnum": 1 }
        color: root.textColor
        renderType: Text.NativeRendering
    }

    Text {
        id: valueLabel

        text: root.valueText
        font.family: root.family
        font.pixelSize: root.pixelSize
        font.bold: root.bold
        font.features: { "tnum": 1 }
        color: root.textColor
        renderType: Text.NativeRendering
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: root.valueWidth > 0 ? root.valueWidth : valueLabel.implicitWidth
    }

    Text {
        id: unitLabel

        text: root.unitText
        font.family: root.family
        font.pixelSize: root.pixelSize
        font.bold: root.bold
        font.features: { "tnum": 1 }
        color: root.textColor
        renderType: Text.NativeRendering
        horizontalAlignment: Text.AlignLeft
        Layout.preferredWidth: root.unitWidth > 0 ? root.unitWidth : unitLabel.implicitWidth
    }
}
