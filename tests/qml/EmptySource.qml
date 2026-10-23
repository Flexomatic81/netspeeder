// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Test double for a data source that finds no network interface: it emits an
// empty sample every interval and reports itself as unavailable until
// addInterface() is called, from then on every sample carries one interface.
// Implements the source interface shared with ProcSource and SensorSource.

import QtQuick

Item {
    id: root

    // Sampling interval in milliseconds.
    property int interval: 1000
    property bool running: true
    readonly property bool available: internals.hasInterface
    // Number of samples emitted so far, for tests that compare it with what
    // the provider made of them.
    property int emitted: 0

    signal sampleReady(var sample)
    // Part of the source interface; never emitted by this double.
    signal failed(string message)

    // Makes the following samples contain the interface "fake0".
    function addInterface() {
        internals.hasInterface = true;
    }

    QtObject {
        id: internals

        property bool hasInterface: false
    }

    Timer {
        interval: root.interval
        repeat: true
        running: root.running
        onTriggered: {
            const interfaces = {};
            if (internals.hasInterface) {
                interfaces["fake0"] = {
                    down: 2048,
                    up: 1024,
                    totalDown: 1000000,
                    totalUp: 500000,
                    kind: "physical",
                    online: true,
                    label: "",
                    ipv4: "192.0.2.1",
                    ipv6: "",
                    signal: null
                };
            }
            root.emitted += 1;
            root.sampleReady({ timestamp: Date.now(), source: "sensors", interfaces: interfaces });
        }
    }
}
