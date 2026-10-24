// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Settings page "Behavior": what a left and a middle click on the panel view
// do, what "start" means (an application or a command), and when the widget
// hides itself (never, when offline, when offline or idle). Plasma opens the
// page with the saved values in the cfg_ properties and writes the changed
// ones back when the user applies. Every control shows its cfg_ property and
// writes it only on a choice of the user.

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "../../code/clicks.mjs" as Clicks
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

    property string cfg_leftClick
    property string cfg_middleClick
    property string cfg_launchKind
    property string cfg_launchApp
    property string cfg_launchCommand
    property string cfg_autoHide
    property int cfg_idleThreshold
    property int cfg_idleSeconds

    // The controls, for the smoke scene.
    readonly property alias leftBox: leftClickBox
    readonly property alias middleBox: middleClickBox
    readonly property alias kindBox: launchKindBox
    readonly property alias appField: launchAppField
    readonly property alias commandField: launchCommandField
    readonly property alias chooseButton: launchChooseButton
    readonly property alias warning: popupWarning
    readonly property alias autoHideBox: autoHideChoice
    readonly property alias thresholdBox: idleThresholdBox
    readonly property alias secondsBox: idleSecondsBox

    Kirigami.FormLayout {
        Kirigami.InlineMessage {
            id: popupWarning

            Layout.fillWidth: true
            type: Kirigami.MessageType.Warning
            text: root.tr("Neither click opens the popup. It stays reachable on the desktop only.")
            visible: !Clicks.popupReachable({ leftClick: root.cfg_leftClick, middleClick: root.cfg_middleClick })
        }

        ConfigComboBox {
            id: leftClickBox

            Kirigami.FormData.label: root.tr("Left click:")
            options: [
                { text: root.tr("Open the popup"), value: "popup" },
                { text: root.tr("Start the application or command"), value: "launch" }
            ]
            configValue: root.cfg_leftClick
            onPicked: value => root.cfg_leftClick = value
        }

        ConfigComboBox {
            id: middleClickBox

            Kirigami.FormData.label: root.tr("Middle click:")
            options: [
                { text: root.tr("Do nothing"), value: "none" },
                { text: root.tr("Open the popup"), value: "popup" },
                { text: root.tr("Start the application or command"), value: "launch" }
            ]
            configValue: root.cfg_middleClick
            onPicked: value => root.cfg_middleClick = value
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ConfigComboBox {
            id: launchKindBox

            Kirigami.FormData.label: root.tr("Start:")
            options: [
                { text: root.tr("Application"), value: "app" },
                { text: root.tr("Command"), value: "command" }
            ]
            configValue: root.cfg_launchKind
            onPicked: value => root.cfg_launchKind = value
        }

        RowLayout {
            Kirigami.FormData.label: root.tr("Application:")

            QQC2.TextField {
                id: launchAppField

                Layout.fillWidth: true
                enabled: root.cfg_launchKind === "app"
                placeholderText: "org.kde.plasma-systemmonitor"
                text: root.cfg_launchApp
                onTextEdited: root.cfg_launchApp = text
            }

            QQC2.Button {
                id: launchChooseButton

                enabled: root.cfg_launchKind === "app"
                text: root.tr("Choose…")
                icon.name: "document-open"
                onClicked: appDialog.open()
            }
        }

        QQC2.TextField {
            id: launchCommandField

            Kirigami.FormData.label: root.tr("Command:")
            Layout.fillWidth: true
            enabled: root.cfg_launchKind === "command"
            placeholderText: "konsole -e nethogs"
            text: root.cfg_launchCommand
            onTextEdited: root.cfg_launchCommand = text
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ConfigComboBox {
            id: autoHideChoice

            Kirigami.FormData.label: root.tr("Hide the widget:")
            options: [
                { text: root.tr("Never"), value: "never" },
                { text: root.tr("When offline"), value: "offline" },
                { text: root.tr("When offline or idle"), value: "idle" }
            ]
            configValue: root.cfg_autoHide
            onPicked: value => root.cfg_autoHide = value
        }

        QQC2.Label {
            Layout.fillWidth: true
            opacity: 0.7
            text: root.tr("In edit mode the widget stays visible so it can be configured.")
            wrapMode: Text.WordWrap
        }

        // The threshold is stored in bytes per second and shown in a fixed
        // unit, KiB/s; a stored value that is no multiple of 1024 is shown
        // rounded and stays as it is until the user enters a number.
        QQC2.SpinBox {
            id: idleThresholdBox

            Kirigami.FormData.label: root.tr("Idle below:")
            editable: true
            enabled: root.cfg_autoHide === "idle"
            from: 0
            to: 1024
            value: Math.round(root.cfg_idleThreshold / 1024)
            valueFromText: (text, locale) => TextTools.parseSpinText(text, locale, 0, idleThresholdBox.value)
            textFromValue: (value, locale) => root.trc("@item:valuesuffix %1 is a number", "%1 KiB/s", Number(value).toLocaleString(locale, "f", 0))
            onValueModified: root.cfg_idleThreshold = idleThresholdBox.value * 1024
        }

        QQC2.SpinBox {
            id: idleSecondsBox

            Kirigami.FormData.label: root.tr("For at least:")
            editable: true
            enabled: root.cfg_autoHide === "idle"
            from: 5
            to: 3600
            value: root.cfg_idleSeconds
            valueFromText: (text, locale) => TextTools.parseSpinText(text, locale, 0, idleSecondsBox.value)
            textFromValue: (value, locale) => root.trc("@item:valuesuffix %1 is a number of seconds", "%1 s", Number(value).toLocaleString(locale, "f", 0))
            onValueModified: root.cfg_idleSeconds = idleSecondsBox.value
        }
    }

    Dialogs.FileDialog {
        id: appDialog

        title: root.tr("Choose an application")
        currentFolder: "file:///usr/share/applications"
        nameFilters: [root.tr("Applications (*.desktop)")]
        onAccepted: {
            const id = Clicks.desktopIdFromUrl(appDialog.selectedFile);
            // A file that is no launcher leaves the setting as it is.
            if (id !== "") {
                root.cfg_launchApp = id;
            }
        }
    }
}
