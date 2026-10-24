// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Settings page "Usage": the switch for the traffic that vnStat keeps, a line
// that says whether vnStat can be read, and the optional monthly data cap with
// its billing day, warning level and notification. Plasma opens the page with
// the saved values in the cfg_ properties and writes the changed ones back
// when the user applies. Every control shows its cfg_ property and writes it
// only on a choice of the user.

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "../data"
import "../../code/text.mjs" as TextTools
import "../../code/vnstat.mjs" as Vnstat

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

    property bool cfg_usageEnabled
    property bool cfg_dataCapEnabled
    property double cfg_dataCapGiB
    property int cfg_billingDay
    property int cfg_capWarnPercent
    property bool cfg_capNotify

    // Shell line of the status check; replaceable so tests never run vnstat.
    property string statusCommand: Vnstat.VNSTAT_COMMAND
    // What the status line says for the state of the check.
    readonly property string statusText: root.describe(usageSource.status, usageSource.detail)

    // The controls, for the smoke scene.
    readonly property alias usageBox: usageCheck
    readonly property alias capBox: capCheck
    readonly property alias sizeBox: capSizeBox
    readonly property alias dayBox: billingDayBox
    readonly property alias warnBox: warnPercentBox
    readonly property alias notifyBox: notifyCheck
    readonly property alias statusLabel: statusLine
    readonly property alias usageSource: statusSource

    function describe(status: string, detail: string): string {
        switch (status) {
        case "ok":
            return root.tr("vnstat found");
        case "missing":
            return root.tr("vnstat is not installed");
        case "unsupported":
            return root.tr("This vnstat version is not supported");
        case "error":
            return root.tr("Reading vnstat failed: %1", detail);
        default:
            return root.tr("Checking vnstat…");
        }
    }

    // One read when the page opens; the page has no use for repeats.
    UsageSource {
        id: statusSource

        command: root.statusCommand
        intervalMs: 3600000
    }

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: usageCheck

            text: root.tr("Show usage from vnstat")
            checked: root.cfg_usageEnabled
            onToggled: root.cfg_usageEnabled = usageCheck.checked
        }

        QQC2.Label {
            id: statusLine

            Layout.fillWidth: true
            opacity: 0.7
            text: root.statusText
            wrapMode: Text.WordWrap
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: capCheck

            enabled: root.cfg_usageEnabled
            text: root.tr("Data cap")
            checked: root.cfg_dataCapEnabled
            onToggled: root.cfg_dataCapEnabled = capCheck.checked
        }

        // The cap is stored as a fraction of GiB but entered in whole GiB; a
        // stored fraction is shown rounded and stays as it is until the user
        // enters a number.
        QQC2.SpinBox {
            id: capSizeBox

            Kirigami.FormData.label: root.tr("Monthly cap:")
            editable: true
            enabled: root.cfg_usageEnabled && root.cfg_dataCapEnabled
            from: 1
            to: 100000
            value: Math.round(root.cfg_dataCapGiB)
            valueFromText: (text, locale) => TextTools.parseSpinText(text, locale, 0, capSizeBox.value)
            textFromValue: (value, locale) => root.trc("@item:valuesuffix %1 is a number of gibibytes", "%1 GiB", Number(value).toLocaleString(locale, "f", 0))
            onValueModified: root.cfg_dataCapGiB = capSizeBox.value
        }

        QQC2.SpinBox {
            id: billingDayBox

            Kirigami.FormData.label: root.tr("Billing period starts on day:")
            editable: true
            enabled: root.cfg_usageEnabled
            from: 1
            to: 28
            value: root.cfg_billingDay
            onValueModified: root.cfg_billingDay = billingDayBox.value
        }

        QQC2.SpinBox {
            id: warnPercentBox

            Kirigami.FormData.label: root.tr("Warn at:")
            editable: true
            enabled: root.cfg_usageEnabled && root.cfg_dataCapEnabled
            from: 1
            to: 99
            value: root.cfg_capWarnPercent
            valueFromText: (text, locale) => TextTools.parseSpinText(text, locale, 0, warnPercentBox.value)
            textFromValue: (value, locale) => root.trc("@item:valuesuffix %1 is a percentage", "%1 %", Number(value).toLocaleString(locale, "f", 0))
            onValueModified: root.cfg_capWarnPercent = warnPercentBox.value
        }

        QQC2.CheckBox {
            id: notifyCheck

            enabled: root.cfg_usageEnabled
            text: root.tr("Notify when the warning level or the cap is reached")
            checked: root.cfg_capNotify
            onToggled: root.cfg_capNotify = notifyCheck.checked
        }
    }
}
