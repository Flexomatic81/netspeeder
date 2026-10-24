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
import "../../code/text.mjs" as TextTools

KCM.SimpleKCM {
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

            Kirigami.FormData.label: root.tr("Layout:")
            options: [
                { text: root.tr("Automatic"), value: "auto" },
                { text: root.tr("Two rows"), value: "rows" },
                { text: root.tr("Side by side"), value: "columns" }
            ]
            configValue: root.cfg_layout
            onPicked: value => root.cfg_layout = value
        }

        ConfigComboBox {
            id: orderBox

            Kirigami.FormData.label: root.tr("Order:")
            options: [
                { text: root.tr("Download first"), value: false },
                { text: root.tr("Upload first"), value: true }
            ]
            configValue: root.cfg_uploadFirst
            onPicked: value => root.cfg_uploadFirst = value
        }

        QQC2.CheckBox {
            id: combinedBox

            text: root.tr("Show only the combined speed")
            checked: root.cfg_combined
            onToggled: root.cfg_combined = combinedBox.checked
        }

        ConfigComboBox {
            id: unitsBox

            Kirigami.FormData.label: root.tr("Units:")
            options: [
                { text: root.tr("Bytes, binary (KiB/s)"), value: "iec" },
                { text: root.tr("Bytes, decimal (kB/s)"), value: "si" },
                { text: root.tr("Bits (Mbit/s)"), value: "bits" }
            ]
            configValue: root.cfg_unitSystem
            onPicked: value => root.cfg_unitSystem = value
        }

        QQC2.CheckBox {
            id: shortUnitsBox

            text: root.tr("Use short unit names")
            checked: root.cfg_shortUnits
            onToggled: root.cfg_shortUnits = shortUnitsBox.checked
        }

        ConfigComboBox {
            id: decimalsBox

            Kirigami.FormData.label: root.tr("Decimal places:")
            options: [
                { text: root.tr("Automatic"), value: -1 },
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

            Kirigami.FormData.label: root.tr("Show as 0 below:")
            options: [
                { text: root.tr("Off"), value: 0 },
                { text: root.tr("512 B/s"), value: 512 },
                { text: root.tr("1 KiB/s"), value: 1024 },
                { text: root.tr("10 KiB/s"), value: 10240 },
                { text: root.tr("100 KiB/s"), value: 102400 }
            ]
            configValue: root.cfg_lowSpeedThreshold
            onPicked: value => root.cfg_lowSpeedThreshold = value
        }

        // In tenths of a second, from 0.5 s to 10 s; the setting is in seconds.
        QQC2.SpinBox {
            id: intervalBox

            Kirigami.FormData.label: root.tr("Update interval:")
            from: 5
            to: 100
            stepSize: 5
            value: Math.round(root.cfg_updateInterval * 10)
            // The box counts tenths of a second; the text shows seconds.
            valueFromText: (text, locale) => Math.round(TextTools.parseSpinText(text, locale, 1, intervalBox.value / 10) * 10)
            textFromValue: (value, locale) => root.trc("@item:valuesuffix %1 is a number of seconds", "%1 s", Number(value / 10).toLocaleString(locale, "f", 1))
            onValueModified: root.cfg_updateInterval = intervalBox.value / 10
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.Label {
            Kirigami.FormData.label: root.tr("Preview:")
            text: root.previewText
            font.features: { "tnum": 1 }
        }
    }
}
