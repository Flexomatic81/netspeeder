// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Smoke scene for ProcSource: polls the real /proc/net/dev and checks the
// third sample against the sample contract.

import QtQuick
import "../../package/contents/ui/data"

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

    function check(sample) {
        if (sample.source !== "proc") {
            scene.finish(false, "SMOKE FAIL proc: source is '" + sample.source + "'");
            return;
        }
        const names = Object.keys(sample.interfaces);
        let physical = 0;
        for (let i = 0; i < names.length; i++) {
            const iface = sample.interfaces[names[i]];
            if (iface.kind === "physical") {
                physical += 1;
            }
            if (!isFinite(iface.down) || iface.down < 0 || !isFinite(iface.up) || iface.up < 0) {
                scene.finish(false, "SMOKE FAIL proc: bad rate on " + names[i]
                    + " down=" + iface.down + " up=" + iface.up);
                return;
            }
        }
        if (physical < 1) {
            scene.finish(false, "SMOKE FAIL proc: no physical interface among " + names.join(", "));
            return;
        }
        scene.finish(true, "SMOKE OK proc " + names.length + " interfaces");
    }

    ProcSource {
        id: source

        interval: 500
        onSampleReady: sample => {
            scene.received += 1;
            if (scene.received === 3) {
                scene.check(sample);
            }
        }
        onFailed: message => scene.finish(false, "SMOKE FAIL proc: " + message)
    }

    Timer {
        interval: 10000
        running: true
        onTriggered: scene.finish(false, "SMOKE FAIL proc: timeout after 10 s ("
            + scene.received + " samples)")
    }
}
