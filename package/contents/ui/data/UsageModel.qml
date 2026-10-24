// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// The data usage for the views: reads vnStat through a UsageSource and sums
// the interfaces that count for the current billing period, with the share
// of the data cap. Everything is rebuilt only when the usage data changes:
// the names that count, the vnStat result or status, the calendar day, the
// billing day or the cap settings. A network sample (a new interfaces array
// with the same names) or a clock tick within the same day rebuilds nothing.
// Disabled, nothing runs and the outputs are constant.

import QtQuick
import "../../code/usage.mjs" as Usage
import "../../code/vnstat.mjs" as Vnstat

Item {
    id: root

    // enabled is the Item property; false stops vnStat and all sums.
    property string interfaceSelection: "auto"
    property var selectedInterfaces: []
    // The live interfaces of the NetworkProvider.
    property var interfaces: []
    property int billingDay: 1
    property bool capEnabled: false
    property real capGiB: 100
    property int warnPercent: 80
    // The shell line of the UsageSource. Replaceable for tests.
    property alias command: source.command

    readonly property string status: source.status
    // Number of vnStat runs started (for the smoke scene).
    readonly property int runs: source.runs
    // The names that count, as one string (see namesKey() in usage.mjs).
    readonly property string namesKey: root.enabled ? Usage.namesKey(root.interfaceSelection, root.selectedInterfaces, root.interfaces, Object.keys(source.parsed?.interfaces ?? {})) : ""
    // The local calendar day, "YYYY-MM-DD".
    readonly property string todayKey: Vnstat.dateKey(clock.now)
    // Whether the vnStat data is more than an hour old.
    readonly property bool outdated: root.enabled && Usage.isOutdated(source.lastUpdated, clock.now, 60)
    // The result of usageSummary().
    readonly property var summary: root.enabled ? Usage.usageSummary(source.parsed, Usage.namesFromKey(root.namesKey), Usage.dateParts(root.todayKey), root.billingDay) : internals.idleSummary
    // The share of the data cap: { enabled, capBytes, percent, level }.
    readonly property var cap: root.enabled ? Object.assign({
            enabled: root.capEnabled,
            capBytes: root.capGiB * 1024 * 1024 * 1024
        }, Usage.capState(root.summary.current.total, root.capGiB, root.warnPercent)) : internals.idleCap
    // The input of the popup (see UsagePanel).
    readonly property var view: root.enabled ? ({
            summary: root.summary,
            status: source.status,
            detail: source.detail,
            cap: root.cap,
            lastUpdated: source.lastUpdated,
            outdated: root.outdated
        }) : internals.idleView

    // A new vnStat result arrived (a successful run). Not emitted for the data
    // kept after a failed run, nor for settings or clock changes; summary and
    // cap are up to date when it comes.
    signal freshResult

    // Reads vnStat again (ignored while disabled or busy).
    function refresh() {
        source.refresh();
    }

    // Takes the local time again; called every minute and on every result.
    function tick() {
        clock.now = Usage.localNow(new Date());
    }

    // The constant outputs while disabled.
    QtObject {
        id: internals

        readonly property var idleSummary: Usage.emptySummary(Usage.localNow(new Date()), 1)
        readonly property var idleCap: ({
                enabled: false,
                capBytes: 0,
                percent: 0,
                level: 0
            })
        readonly property var idleView: ({
                summary: internals.idleSummary,
                status: "disabled",
                detail: "",
                cap: internals.idleCap,
                lastUpdated: "",
                outdated: false
            })
    }

    // The local day and time. Only the derived day key and the outdated flag
    // read it, so a tick within the same day changes no summary.
    QtObject {
        id: clock

        property var now: Usage.localNow(new Date())
    }

    UsageSource {
        id: source

        enabled: root.enabled
        // A new result may come after midnight: the day is taken again.
        onParsedChanged: {
            root.tick();
            // The first change at creation has no result yet. The signal comes
            // after the bindings that depend on the new result have run.
            if (source.parsed !== null) {
                Qt.callLater(() => root.freshResult());
            }
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: root.enabled
        onTriggered: root.tick()
    }
}
