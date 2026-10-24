// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// A stand-in for NetworkProvider with fixed demo data (see demo.mjs): every
// output the panel view and the popup read, and the usage input of the popup.

import QtQml
import "demo.mjs" as Demo

QtObject {
    id: root

    readonly property var data: Demo.demoProvider()

    readonly property bool hasData: root.data.hasData
    readonly property real down: root.data.down
    readonly property real up: root.data.up
    readonly property bool online: root.data.online
    readonly property bool stale: root.data.stale
    readonly property string activeSource: root.data.activeSource
    readonly property string primaryLabel: root.data.primaryLabel
    readonly property string primaryIp: root.data.primaryIp
    readonly property var interfaces: root.data.interfaces
    readonly property int includedCount: root.data.includedCount
    readonly property var history: root.data.history
    readonly property string errorCode: root.data.errorCode
    readonly property string errorDetail: root.data.errorDetail
    readonly property string fallbackNote: root.data.fallbackNote

    // The usage input of the popup (the shape of UsageModel.view), 85 % of
    // the data cap used.
    readonly property var usage: Demo.demoUsage()
}
