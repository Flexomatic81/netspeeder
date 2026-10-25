// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Smoke scene for SensorSource: reads the real ksystemstats and checks the
// first sample from the third on that lists the loopback device in
// `systemVirtual` (the device query has answered, and the list survived the
// signal) against the sample contract, plus the sensor IDs the delegates
// built (a wrong ID, e.g. "network//download", delivers no values at all).
//
// Live scene: needs ksystemstats and a network interface that has received
// data.

import QtQuick
import "../../package/contents/ui/data"
import "../../package/contents/code/sensors.mjs" as SensorCode

Item {
    id: scene

    property int received: 0
    property bool done: false

    function finish(ok, message) {
        if (scene.done) {
            return;
        }
        scene.done = true;
        console.log(message);
        Qt.exit(ok ? 0 : 1);
    }

    // Returns an error message, or "" when every delegate sensor of every
    // interface in `names` has an ID of the form network/<interface>/<field>.
    function checkSensorIds(names) {
        const ids = source.activeSensorIds();
        const found = {};
        for (let i = 0; i < ids.length; i++) {
            const parts = ids[i].split("/");
            if (parts.length !== 3 || parts[0] !== "network" || parts[1] === "" || parts[2] === "") {
                return "malformed sensor id '" + ids[i] + "'";
            }
            found[ids[i]] = true;
        }
        for (let n = 0; n < names.length; n++) {
            for (const field of SensorCode.SENSOR_FIELDS) {
                const expected = "network/" + names[n] + "/" + field;
                if (found[expected] !== true) {
                    return "missing sensor id '" + expected + "'";
                }
            }
        }
        return "";
    }

    // Whether the sample lists the loopback device as present without
    // hardware. The list crosses a signal and arrives array-like.
    function listsLoopback(sample): bool {
        return Array.prototype.indexOf.call(sample.systemVirtual ?? [], "lo") >= 0;
    }

    function check(sample) {
        if (sample.source !== "sensors") {
            scene.finish(false, "SMOKE FAIL sensors: source is '" + sample.source + "'");
            return;
        }
        const names = Object.keys(sample.interfaces);
        if (names.length < 1) {
            scene.finish(false, "SMOKE FAIL sensors: no interfaces in the third sample");
            return;
        }
        let moved = 0;
        const described = [];
        for (let i = 0; i < names.length; i++) {
            const iface = sample.interfaces[names[i]];
            if (!isFinite(iface.down) || iface.down < 0 || !isFinite(iface.up) || iface.up < 0
                    || !isFinite(iface.totalDown) || !isFinite(iface.totalUp)) {
                scene.finish(false, "SMOKE FAIL sensors: bad value on " + names[i]
                    + " down=" + iface.down + " up=" + iface.up
                    + " totalDown=" + iface.totalDown + " totalUp=" + iface.totalUp);
                return;
            }
            if (iface.totalDown > 0) {
                moved += 1;
            }
            described.push(names[i] + " " + iface.kind);
        }
        if (moved < 1) {
            scene.finish(false, "SMOKE FAIL sensors: no interface with totalDown > 0 among "
                + described.join(", "));
            return;
        }
        const idError = scene.checkSensorIds(names);
        if (idError !== "") {
            scene.finish(false, "SMOKE FAIL sensors: " + idError);
            return;
        }
        scene.finish(true, "SMOKE OK sensors " + described.join(", "));
    }

    SensorSource {
        id: source

        interval: 500
        onSampleReady: sample => {
            scene.received += 1;
            if (scene.received >= 3 && scene.listsLoopback(sample)) {
                scene.check(sample);
            }
        }
        onFailed: message => scene.finish(false, "SMOKE FAIL sensors: " + message)
    }

    Timer {
        interval: 10000
        running: true
        onTriggered: scene.finish(false, "SMOKE FAIL sensors: timeout after 10 s ("
            + scene.received + " samples, none from the third on with lo in systemVirtual)")
    }
}
