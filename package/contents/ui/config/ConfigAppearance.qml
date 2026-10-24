// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Settings page "Appearance": font, direction symbols, colours, width and
// sparkline of the panel view. Plasma opens the page with the saved values in
// the cfg_ properties and writes the changed ones back when the user applies.
// Every control shows its cfg_ property and writes it only on a choice of the
// user; a colour only when its dialog is accepted.

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQuickControls
import "../../code/appearance.mjs" as Appearance
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

    property string cfg_fontFamily
    property bool cfg_fontBold
    // Percent.
    property int cfg_fontScale
    property string cfg_iconStyle
    property string cfg_customDownIcon
    property string cfg_customUpIcon
    property string cfg_colorMode
    property string cfg_downloadColor
    property string cfg_uploadColor
    property string cfg_colorThresholds
    property bool cfg_colorUnits
    property bool cfg_fixedWidth
    property string cfg_sparkline

    // The controls, for the smoke scene.
    readonly property alias fontBox: fontFamilyBox
    readonly property alias boldBox: fontBoldBox
    readonly property alias scaleBox: fontScaleBox
    readonly property alias iconBox: iconStyleBox
    readonly property alias downField: customDownField
    readonly property alias upField: customUpField
    readonly property alias colorModeBox: colorModeChoice
    readonly property alias downloadButton: downloadColorButton
    readonly property alias uploadButton: uploadColorButton
    readonly property alias downloadThemeButton: downloadThemeColorButton
    readonly property alias editor: thresholdEditor
    readonly property alias colorUnitsBox: colorUnitsCheck
    readonly property alias fixedWidthBox: fixedWidthCheck
    readonly property alias sparklineBox: sparklineChoice

    // The installed font families, read once.
    readonly property var fontFamilies: Qt.fontFamilies()
    // A saved font family that is not installed. It gets an entry of its own
    // so the list does not show a blank; it stays listed once seen, so that
    // the list keeps its entries while the page is open.
    property string missingFont: ""

    readonly property var fontOptions: {
        const options = [{ text: root.tr("Theme font"), value: "" }];
        if (root.missingFont !== "") {
            options.push({ text: root.tr("%1 (not installed)", root.missingFont), value: root.missingFont });
        }
        return options.concat(root.fontFamilies.map(family => ({ text: family, value: family })));
    }

    function noteMissingFont() {
        if (root.cfg_fontFamily !== "" && root.fontFamilies.indexOf(root.cfg_fontFamily) < 0) {
            root.missingFont = root.cfg_fontFamily;
        }
    }

    onCfg_fontFamilyChanged: root.noteMissingFont()
    Component.onCompleted: root.noteMissingFont()

    // The colour a button shows for a setting; "" is the theme's text colour.
    function shownColor(value: string): color {
        return value !== "" ? value : Kirigami.Theme.textColor;
    }

    function hexColor(chosen: color): string {
        return Appearance.toHexColor(chosen.r, chosen.g, chosen.b);
    }

    Kirigami.FormLayout {
        ConfigComboBox {
            id: fontFamilyBox

            Kirigami.FormData.label: root.tr("Font:")
            options: root.fontOptions
            configValue: root.cfg_fontFamily
            onPicked: value => root.cfg_fontFamily = value
        }

        QQC2.CheckBox {
            id: fontBoldBox

            text: root.tr("Bold")
            checked: root.cfg_fontBold
            onToggled: root.cfg_fontBold = fontBoldBox.checked
        }

        QQC2.SpinBox {
            id: fontScaleBox

            Kirigami.FormData.label: root.tr("Text size:")
            from: 50
            to: 200
            stepSize: 10
            value: root.cfg_fontScale
            valueFromText: (text, locale) => TextTools.parseSpinText(text, locale, 0, fontScaleBox.value)
            textFromValue: (value, locale) => root.trc("@item:valuesuffix %1 is a percentage", "%1 %", Number(value).toLocaleString(locale, "f", 0))
            onValueModified: root.cfg_fontScale = fontScaleBox.value
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ConfigComboBox {
            id: iconStyleBox

            Kirigami.FormData.label: root.tr("Symbols:")
            options: [
                { text: root.tr("Arrows"), value: "arrows" },
                { text: root.tr("Triangles"), value: "triangles" },
                { text: root.tr("Icons"), value: "icons" },
                { text: root.tr("None"), value: "none" },
                { text: root.tr("Custom"), value: "custom" }
            ]
            configValue: root.cfg_iconStyle
            onPicked: value => root.cfg_iconStyle = value
        }

        QQC2.TextField {
            id: customDownField

            Kirigami.FormData.label: root.tr("Download symbol:")
            enabled: root.cfg_iconStyle === "custom"
            maximumLength: 3
            text: root.cfg_customDownIcon
            onTextEdited: root.cfg_customDownIcon = text
        }

        QQC2.TextField {
            id: customUpField

            Kirigami.FormData.label: root.tr("Upload symbol:")
            enabled: root.cfg_iconStyle === "custom"
            maximumLength: 3
            text: root.cfg_customUpIcon
            onTextEdited: root.cfg_customUpIcon = text
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ConfigComboBox {
            id: colorModeChoice

            Kirigami.FormData.label: root.tr("Colours:")
            options: [
                { text: root.tr("Theme colour"), value: "theme" },
                { text: root.tr("By direction"), value: "direction" },
                { text: root.tr("By speed"), value: "thresholds" }
            ]
            configValue: root.cfg_colorMode
            onPicked: value => root.cfg_colorMode = value
        }

        RowLayout {
            Kirigami.FormData.label: root.tr("Download colour:")
            enabled: root.cfg_colorMode === "direction"

            KQuickControls.ColorButton {
                id: downloadColorButton

                showAlphaChannel: false
                dialogTitle: root.tr("Choose a colour")
                color: root.shownColor(root.cfg_downloadColor)
                onAccepted: chosen => root.cfg_downloadColor = root.hexColor(chosen)
            }

            QQC2.Button {
                id: downloadThemeColorButton

                text: root.tr("Use theme colour")
                onClicked: root.cfg_downloadColor = ""
            }
        }

        RowLayout {
            Kirigami.FormData.label: root.tr("Upload colour:")
            enabled: root.cfg_colorMode === "direction"

            KQuickControls.ColorButton {
                id: uploadColorButton

                showAlphaChannel: false
                dialogTitle: root.tr("Choose a colour")
                color: root.shownColor(root.cfg_uploadColor)
                onAccepted: chosen => root.cfg_uploadColor = root.hexColor(chosen)
            }

            QQC2.Button {
                text: root.tr("Use theme colour")
                onClicked: root.cfg_uploadColor = ""
            }
        }

        ThresholdEditor {
            id: thresholdEditor

            Kirigami.FormData.label: root.tr("Speed levels:")
            enabled: root.cfg_colorMode === "thresholds"
            value: root.cfg_colorThresholds
            onEdited: json => root.cfg_colorThresholds = json
        }

        QQC2.CheckBox {
            id: colorUnitsCheck

            text: root.tr("Colour units and symbols too")
            enabled: root.cfg_colorMode !== "theme"
            checked: root.cfg_colorUnits
            onToggled: root.cfg_colorUnits = colorUnitsCheck.checked
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: fixedWidthCheck

            text: root.tr("Keep a fixed width")
            checked: root.cfg_fixedWidth
            onToggled: root.cfg_fixedWidth = fixedWidthCheck.checked
        }

        ConfigComboBox {
            id: sparklineChoice

            Kirigami.FormData.label: root.tr("Sparkline:")
            options: [
                { text: root.tr("Off"), value: "off" },
                { text: root.tr("Behind the values"), value: "background" },
                { text: root.tr("Beside the values"), value: "beside" }
            ]
            configValue: root.cfg_sparkline
            onPicked: value => root.cfg_sparkline = value
        }
    }
}
