// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Fallback data source: polls /proc/net/dev (plus sysfs) through a shell
// command. Implements the source interface shared with SensorSource.qml.

import QtQuick
import "../../code/procnetdev.mjs" as Procnetdev
import "../../code/rates.mjs" as Rates

Item {
    id: root

    // Polling interval in milliseconds.
    property int interval: 1000
    property bool running: true
    // True once a sample with at least one interface has been delivered.
    readonly property bool available: internals.delivered

    // sample: { timestamp, source, interfaces } as built by toProcSample().
    signal sampleReady(var sample)
    signal failed(string message)

    QtObject {
        id: internals

        property bool delivered: false
        // Previous snapshot { timestamp, counters }, null before the first run.
        property var previous: null
    }

    CommandRunner {
        id: runner

        command: Procnetdev.PROC_COMMAND

        onFinished: (exitCode, stdout, stderr) => {
            const parsed = Procnetdev.parseProcOutput(stdout);
            if (parsed === null) {
                root.failed("proc output unreadable: " + stderr);
                return;
            }
            const now = Date.now();
            const next = { timestamp: now, counters: parsed.counters };
            const result = Rates.computeRates(internals.previous, next, root.interval);
            // The new snapshot is the baseline even when the sample was invalid.
            internals.previous = next;
            if (!result.valid) {
                return;
            }
            const sample = Procnetdev.toProcSample(now, parsed, result.rates);
            if (Object.keys(sample.interfaces).length > 0) {
                internals.delivered = true;
            }
            root.sampleReady(sample);
        }
    }

    Timer {
        interval: root.interval
        repeat: true
        running: root.running
        // The first run takes the baseline snapshot right away.
        triggeredOnStart: true
        // A tick that finds the previous run still going is skipped, not caught up.
        onTriggered: {
            if (!runner.busy) {
                runner.run();
            }
        }
    }
}
