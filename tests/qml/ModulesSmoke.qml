// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Smoke scene that loads every code module in the QML engine and calls one
// cheap function of each. Node accepts syntax that the QML JavaScript engine
// rejects, so the Node tests alone cannot prove a module is usable in QML.
// Every file in package/contents/code must be imported here (a Node test
// checks that).

import QtQuick
import "../../package/contents/code/appearance.mjs" as Appearance
import "../../package/contents/code/clicks.mjs" as Clicks
import "../../package/contents/code/command.mjs" as Command
import "../../package/contents/code/format.mjs" as Format
import "../../package/contents/code/graph.mjs" as Graph
import "../../package/contents/code/history.mjs" as History
import "../../package/contents/code/launchtext.mjs" as LaunchText
import "../../package/contents/code/layout.mjs" as Layout
import "../../package/contents/code/listsync.mjs" as ListSync
import "../../package/contents/code/procnetdev.mjs" as ProcNetDev
import "../../package/contents/code/providerstate.mjs" as ProviderState
import "../../package/contents/code/rates.mjs" as Rates
import "../../package/contents/code/selection.mjs" as Selection
import "../../package/contents/code/sensors.mjs" as Sensors
import "../../package/contents/code/text.mjs" as Text
import "../../package/contents/code/tooltip.mjs" as Tooltip
import "../../package/contents/code/usage.mjs" as Usage
import "../../package/contents/code/visibility.mjs" as Visibility
import "../../package/contents/code/vnstat.mjs" as Vnstat

Item {
    id: scene

    function check() {
        const results = [
            Appearance.parseThresholds("").length === 4,
            // The cut works by code points in the QML engine, too.
            Appearance.symbols("custom", { down: "a\u{1F600}bc" }).down === "a\u{1F600}b",
            Appearance.symbols("custom", { down: "ab\u{1F600}c" }).down === "ab\u{1F600}",
            Clicks.popupReachable({}) !== undefined,
            Command.shellQuote("a") === "'a'",
            Format.formatTotal(0, Format.DEFAULT_FORMAT).value === "0",
            Graph.validMinutes(5) === 5,
            History.capacityFor(1000) > 0,
            LaunchText.launchFailureText(127, "x", "command", { tr: function (s) { return s; }, trc: function (c, s) { return s; } }).length > 0,
            Layout.REFERENCE_PX > 0,
            Array.isArray(ListSync.syncOps([], [], null)),
            ProcNetDev.PROC_COMMAND.length > 0,
            ProviderState.initialState() !== null,
            Rates.computeRates(null, { timestamp: 0, counters: {} }, 1000).valid,
            Selection.compareNames("a", "b") < 0,
            Sensors.HEARTBEAT_SENSOR.length > 0,
            Text.substitute("%1", ["x"]) === "x",
            Tooltip.escapeHtml("<") === "&lt;",
            Usage.addDays("2028-02-28", 1) === "2028-02-29",
            Usage.usageSummary(null, [], { year: 2026, month: 10, day: 24 }, 25).current.start === "2026-09-25",
            !Usage.isOutdated("2026-10-31T23:45", { year: 2026, month: 11, day: 1, hour: 0, minute: 15 }),
            Visibility.autoHideState("never", { hasData: true, online: true, idle: false }, { editMode: false, expanded: false }) === "shown",
            Vnstat.parseVnstat("{}").status === "invalid"
        ];
        const bad = results.indexOf(false);
        if (bad >= 0) {
            console.log("failed check " + bad);
        }
        return bad < 0;
    }

    Component.onCompleted: {
        if (scene.check()) {
            console.log("SMOKE OK modules");
            Qt.exit(0);
        } else {
            console.log("SMOKE FAIL modules");
            Qt.exit(1);
        }
    }
}
