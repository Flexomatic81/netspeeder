// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81
// SPDX-FileCopyrightText: 2016 Daniel Faust <hessijames@gmail.com>

// The panel view: download and upload speed on one row. Preliminary; the
// adaptive layout for other panel sizes and orientations follows later.

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../code/format.mjs" as Format

RowLayout {
    id: root

    // The NetworkProvider whose down and up values are shown.
    required property var provider
    // Options for formatSpeed(): unitSystem, shortUnits, decimals,
    // lowSpeedThreshold and decimalPoint.
    required property var formatOptions

    readonly property var downSpeed: Format.formatSpeed(root.provider.down, root.formatOptions)
    readonly property var upSpeed: Format.formatSpeed(root.provider.up, root.formatOptions)

    Layout.preferredWidth: root.implicitWidth
    spacing: Kirigami.Units.largeSpacing

    SpeedLabel {
        id: downLabel

        symbol: "↓"
        valueText: root.downSpeed.value
        unitText: root.downSpeed.unit
        pixelSize: Kirigami.Theme.defaultFont.pixelSize
        textColor: Kirigami.Theme.textColor
        Layout.preferredWidth: downLabel.implicitWidth
    }

    SpeedLabel {
        id: upLabel

        symbol: "↑"
        valueText: root.upSpeed.value
        unitText: root.upSpeed.unit
        pixelSize: Kirigami.Theme.defaultFont.pixelSize
        textColor: Kirigami.Theme.textColor
        Layout.preferredWidth: upLabel.implicitWidth
    }
}
