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
    }

    QtObject {
        id: internals

        property string activeSource: ""
        property bool rerunPending: false
        property int runCount: 0
        // Keeps the source names of several CommandRunner instances apart.
        readonly property string instanceId: Math.random().toString(36).slice(2, 10)
    }

    Plasma5Support.DataSource {
        id: executor

        engine: "executable"

        onNewData: (sourceName, data) => {
            if (sourceName !== internals.activeSource) {
                return;
            }
            // Disconnect at once so the engine does not run the command again.
            executor.disconnectSource(sourceName);
            const again = internals.rerunPending;
            internals.rerunPending = false;
            internals.activeSource = "";

            let exitCode = Number(data["exit code"]);
            if (isNaN(exitCode)) {
                exitCode = -1;
            }
            const stdout = data["stdout"] === undefined ? "" : String(data["stdout"]);
            const stderr = data["stderr"] === undefined ? "" : String(data["stderr"]);
            root.finished(exitCode, stdout, stderr);

            // A handler of finished() may already have started a run; that run
            // is newer than the request, so it covers it.
            if (again && !root.busy) {
                root.run();
            }
        }
    }

    Component.onDestruction: {
        if (internals.activeSource !== "") {
            executor.disconnectSource(internals.activeSource);
        }
    }
}
