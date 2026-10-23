// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Settings page "Display": layout, order, units and update interval.
// Plasma opens the page with the saved values in the cfg_ properties and
// writes the changed ones back when the user applies. Every control shows its
// cfg_ property and writes it only on a choice of the user.

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "../../code/format.mjs" as Format

KCM.SimpleKCM {
    id: root

    property string cfg_layout
    property bool cfg_uploadFirst
    property bool cfg_combined
    property string cfg_unitSystem
    property bool cfg_shortUnits
    property int cfg_decimals
    property int cfg_lowSpeedThreshold
    // Seconds.
    property real cfg_updateInterval

    // A fixed speed, 1.5 million bytes per second, as the display would show
    // it with the options chosen so far.
    readonly property string previewText: {
        const speed = Format.formatSpeed(1536000, {
            unitSystem: root.cfg_unitSystem,
            shortUnits: root.cfg_shortUnits,
            decimals: root.cfg_decimals,
            lowSpeedThreshold: root.cfg_lowSpeedThreshold,
            decimalPoint: Qt.locale().decimalPoint
        });
        return speed.value + " " + speed.unit;
    }

    // A whole number in the notation of the locale, for the list of decimal places.
    function numberText(value: int): string {
        return Number(value).toLocaleString(Qt.locale(), "f", 0);
    }

    Kirigami.FormLayout {
        ConfigComboBox {
            id: layoutBox

            Kirigami.FormData.label: i18n("Layout:")
            options: [
                { text: i18n("Automatic"), value: "auto" },
                { text: i18n("Two rows"), value: "rows" },
                { text: i18n("Side by side"), value: "columns" }
            ]
            configValue: root.cfg_layout
            onPicked: value => root.cfg_layout = value
        }

        ConfigComboBox {
            id: orderBox

            Kirigami.FormData.label: i18n("Order:")
            options: [
                { text: i18n("Download first"), value: false },
                { text: i18n("Upload first"), value: true }
            ]
            configValue: root.cfg_uploadFirst
            onPicked: value => root.cfg_uploadFirst = value
        }

        QQC2.CheckBox {
            id: combinedBox

            text: i18n("Show only the combined speed")
            checked: root.cfg_combined
            onToggled: root.cfg_combined = combinedBox.checked
        }

        ConfigComboBox {
            id: unitsBox

            Kirigami.FormData.label: i18n("Units:")
            options: [
                { text: i18n("Bytes, binary (KiB/s)"), value: "iec" },
                { text: i18n("Bytes, decimal (kB/s)"), value: "si" },
                { text: i18n("Bits (Mbit/s)"), value: "bits" }
            ]
            configValue: root.cfg_unitSystem
            onPicked: value => root.cfg_unitSystem = value
        }

        QQC2.CheckBox {
            id: shortUnitsBox

            text: i18n("Use short unit names")
            checked: root.cfg_shortUnits
            onToggled: root.cfg_shortUnits = shortUnitsBox.checked
        }

        ConfigComboBox {
            id: decimalsBox

            Kirigami.FormData.label: i18n("Decimal places:")
            options: [
                { text: i18n("Automatic"), value: -1 },
                { text: root.numberText(0), value: 0 },
                { text: root.numberText(1), value: 1 },
                { text: root.numberText(2), value: 2 }
            ]
            configValue: root.cfg_decimals
            onPicked: value => root.cfg_decimals = value
        }

        // The values are bytes per second, whatever the unit system.
        ConfigComboBox {
            id: thresholdBox

            Kirigami.FormData.label: i18n("Show as 0 below:")
            options: [
                { text: i18n("Off"), value: 0 },
                { text: i18n("512 B/s"), value: 512 },
                { text: i18n("1 KiB/s"), value: 1024 },
                { text: i18n("10 KiB/s"), value: 10240 },
                { text: i18n("100 KiB/s"), value: 102400 }
            ]
            configValue: root.cfg_lowSpeedThreshold
            onPicked: value => root.cfg_lowSpeedThreshold = value
        }

        // In tenths of a second, from 0.5 s to 10 s; the setting is in seconds.
        QQC2.SpinBox {
            id: intervalBox

            Kirigami.FormData.label: i18n("Update interval:")
            from: 5
            to: 100
            stepSize: 5
            value: Math.round(root.cfg_updateInterval * 10)
            textFromValue: (value, locale) => i18nc("@item:valuesuffix %1 is a number of seconds", "%1 s", Number(value / 10).toLocaleString(locale, "f", 1))
            onValueModified: root.cfg_updateInterval = intervalBox.value / 10
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Preview:")
            text: root.previewText
            font.features: { "tnum": 1 }
        }
    }
}
