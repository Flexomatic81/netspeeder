// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Reads the daily traffic that vnStat keeps, in the background. Runs once at
// start, then every intervalMs and on refresh(), as long as it is enabled.
// A missing vnstat is a normal state and logs nothing; an unsupported
// version, a failed run or a timeout is logged once per status change.

import QtQuick
import "../../code/vnstat.mjs" as Vnstat

Item {
    id: root

    // enabled is the Item property (true by default); false stops all runs.
    // Shell line that prints the vnStat JSON. Replaceable so tests never run
    // the real program.
    property string command: Vnstat.VNSTAT_COMMAND
    property int intervalMs: 300000
    // Longest wait for one run in milliseconds. Replaceable for tests.
    property int timeoutMs: 10000

    // Named status because Item already has a state property.
    // "disabled", "loading" (no result yet), "missing", "unsupported",
    // "error" or "ok".
    readonly property string status: root.enabled ? internals.current : "disabled"
    // Result of parseVnstat for the last readable output, else null. Stays
    // when a later run fails; status then shows the failure.
    readonly property var parsed: internals.parsed
    // First stderr line (or a short reason) while status is "error".
    readonly property string detail: internals.detail
    // Newest "YYYY-MM-DDTHH:MM" update stamp of all interfaces in parsed.
    readonly property string lastUpdated: internals.lastUpdated
    // Number of runs actually started.
    readonly property int runs: internals.runs
    readonly property bool busy: runner.busy

    // Starts a run. Ignored while disabled or while a run is in progress.
    function refresh() {
        if (!root.enabled || runner.busy) {
            return;
        }
        internals.runs += 1;
        runner.command = root.command;
        runner.run();
    }

    QtObject {
        id: internals

        property string current: "loading"
        property var parsed: null
        property string detail: ""
        property string lastUpdated: ""
        property int runs: 0
        // The last state that was logged, so a repeated one is logged once.
        property string warned: ""

        function newest(result) {
            let newest = "";
            for (const name of Object.keys(result.interfaces)) {
                const stamp = result.interfaces[name].updated;
                if (stamp > newest) {
                    newest = stamp;
                }
            }
            return newest;
        }

        function setStatus(status, detail) {
            internals.current = status;
            internals.detail = detail;
            const loud = status === "unsupported" || status === "error";
            if (loud && internals.warned !== status + detail) {
                console.warn("netspeeder: vnstat " + status + (detail !== "" ? " (" + detail + ")" : ""));
            }
            internals.warned = loud ? status + detail : "";
        }

        function failure(exitCode, stdout, stderr) {
            if (exitCode === -2) {
                internals.setStatus("error", "timeout");
            } else if (exitCode === 127 || stderr.indexOf("not found") >= 0) {
                internals.setStatus("missing", "");
            } else {
                const first = stderr.split("\n")[0].trim();
                internals.setStatus("error", first !== "" ? first : "exit " + exitCode);
            }
        }

        function accept(stdout) {
            const result = Vnstat.parseVnstat(stdout);
            if (result.status === "invalid") {
                internals.setStatus("error", "invalid output");
                return;
            }
            internals.parsed = result;
            internals.lastUpdated = internals.newest(result);
            internals.setStatus(result.status, "");
        }

        function handle(exitCode, stdout, stderr) {
            if (exitCode === 0) {
                internals.accept(stdout);
            } else {
                internals.failure(exitCode, stdout, stderr);
            }
        }
    }

    CommandRunner {
        id: runner

        timeoutMs: root.timeoutMs
        onFinished: (exitCode, stdout, stderr) => {
            // A result that arrives after disabling is dropped.
            if (root.enabled) {
                internals.handle(exitCode, stdout, stderr);
            }
        }
    }

    Timer {
        interval: root.intervalMs
        repeat: true
        running: root.enabled
        onTriggered: root.refresh()
    }

    onEnabledChanged: root.refresh()
    Component.onCompleted: root.refresh()
}
