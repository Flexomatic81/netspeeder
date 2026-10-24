// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// The only gateway to the Plasma5Support "executable" engine. Runs one shell
// command at a time and reports the result through finished().

import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

Item {
    id: root

    // Shell command to run. Read when run() starts a run.
    property string command: ""
    // True while a run is in progress. Already false inside a finished()
    // handler, so a handler may call run() to start the next run itself.
    readonly property bool busy: internals.activeSource !== ""
    // Longest time a run may take in milliseconds; 0 means no limit. A run
    // that exceeds it is abandoned and reports exit code -2. The process
    // itself is not killed; only its result is dropped.
    property int timeoutMs: 0

    signal finished(int exitCode, string stdout, string stderr)

    // Starts the command. While a run is in progress, any number of calls
    // merge into one further run that starts right after the current one.
    function run() {
        if (root.busy) {
            internals.rerunPending = true;
            return;
        }
        internals.runCount += 1;
        // The engine caches the result of a source name for a while after it
        // was disconnected, so a repeated name would return the old output.
        // Every run therefore gets a unique name. The suffix is a shell
        // comment and does not change what runs.
        const sourceName = root.command + " # netspeeder-" + internals.instanceId + "-" + internals.runCount;
        internals.activeSource = sourceName;
        executor.connectSource(sourceName);
        if (root.timeoutMs > 0) {
            internals.activeTimeoutMs = root.timeoutMs;
            limit.interval = root.timeoutMs;
            limit.restart();
        }
    }

    QtObject {
        id: internals

        property string activeSource: ""
        property bool rerunPending: false
        property int runCount: 0
        // timeoutMs as it was when the active run started.
        property int activeTimeoutMs: 0
        // Keeps the source names of several CommandRunner instances apart.
        readonly property string instanceId: Math.random().toString(36).slice(2, 10)

        // Ends the active run: disconnects the source (so the engine does not
        // run the command again), reports the result and starts a merged
        // follow-up run if one was requested.
        function complete(exitCode, stdout, stderr) {
            executor.disconnectSource(internals.activeSource);
            limit.stop();
            const again = internals.rerunPending;
            internals.rerunPending = false;
            internals.activeSource = "";
            root.finished(exitCode, stdout, stderr);
            // A handler of finished() may already have started a run; that run
            // is newer than the request, so it covers it.
            if (again && !root.busy) {
                root.run();
            }
        }
    }

    // Abandons a run that takes too long. A result that still arrives later
    // is dropped by the source name check in onNewData.
    Timer {
        id: limit

        onTriggered: {
            if (internals.activeSource === "") {
                return;
            }
            internals.complete(-2, "", "timed out after " + internals.activeTimeoutMs + " ms");
        }
    }

    Plasma5Support.DataSource {
        id: executor

        engine: "executable"

        onNewData: (sourceName, data) => {
            if (sourceName !== internals.activeSource) {
                return;
            }
            let exitCode = Number(data["exit code"]);
            if (isNaN(exitCode)) {
                exitCode = -1;
            }
            const stdout = data["stdout"] === undefined ? "" : String(data["stdout"]);
            const stderr = data["stderr"] === undefined ? "" : String(data["stderr"]);
            internals.complete(exitCode, stdout, stderr);
        }
    }

    Component.onDestruction: {
        if (internals.activeSource !== "") {
            executor.disconnectSource(internals.activeSource);
        }
    }
}
