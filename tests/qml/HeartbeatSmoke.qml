// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Smoke scene for the heartbeat check of SensorSource, through NetworkProvider
// with the real ksystemstats and a heartbeat the scene drives
// (ScriptedHeartbeatSource.qml), in four steps:
//   1  the heartbeat sensor reports one value that never changes (a
//      placeholder) and the start-up probe ends: that value is no heartbeat,
//      the check is off and the values stay fresh for longer than the
//      heartbeat window plus the provider's three intervals
//   2  a late heartbeat arrives and keeps coming: the values stay fresh
//   3  the heartbeat stops: samples still pass for the heartbeat window, then
//      none, and the provider turns stale after its three intervals
//   4  the heartbeat comes back: the values are fresh again

import QtQuick
import "../../package/contents/ui/data"
import "../../package/contents/code/sensors.mjs" as SensorCode

Item {
    id: scene

    readonly property int intervalMs: 500
    readonly property int windowMs: SensorCode.heartbeatWindowMs(scene.intervalMs)
    // Three source intervals: the values count as settled once they have
    // been fresh this long.
    readonly property int settleMs: 3 * scene.intervalMs
    // Without a heartbeat the provider turns stale within the window plus its
    // three intervals; this much on top covers its clock tick and the
    // scene's.
    readonly property int staleSlackMs: scene.intervalMs + 1000
    readonly property int stepTimeoutMs: 12000
    // Timer jitter allowed around the expected moments.
    readonly property int slackMs: 150

    property int step: 0
    property double stepStart: 0
    property double freshSince: 0
    property var source: null
    property bool beating: false
    property double lastBeatAt: 0
    property double lastSampleAt: 0
    property double holdAt: 0
    property double freshAt: 0
    property bool done: false

    function finish(ok, message) {
        if (scene.done) {
            return;
        }
        scene.done = true;
        console.log(message);
        Qt.exit(ok ? 0 : 1);
    }

    function fail(message) {
        scene.finish(false, "SMOKE FAIL heartbeat: step " + scene.step + ": " + message);
    }

    function describe() {
        return "hasData=" + provider.hasData + " stale=" + provider.stale + " errorCode='"
            + provider.errorCode + "' activeSource='" + provider.activeSource + "'";
    }

    function enter(step) {
        scene.step = step;
        scene.stepStart = Date.now();
        scene.freshSince = 0;
        console.log("heartbeat: step " + step);
    }

    // The test double sits in the loader of the provider, which has no public
    // handle on it; find it among the provider's visual children.
    function findSource() {
        const children = provider.children;
        for (let i = 0; i < children.length; i++) {
            const item = children[i].item;
            if (item !== undefined && item !== null && typeof item.beat === "function") {
                return item;
            }
        }
        return null;
    }

    // True once the provider has shown fresh sensor values for settleMs;
    // fails the scene after the step timeout.
    function settledFresh(now) {
        const fresh = provider.hasData && !provider.stale && provider.activeSource === "sensors";
        if (!fresh) {
            scene.freshSince = 0;
        } else if (scene.freshSince === 0) {
            scene.freshSince = now;
        }
        if (scene.freshSince !== 0 && now - scene.freshSince >= scene.settleMs) {
            return true;
        }
        if (now - scene.stepStart > scene.stepTimeoutMs) {
            scene.fail("no fresh values (" + scene.describe() + ")");
        }
        return false;
    }

    function beat() {
        scene.lastBeatAt = Date.now();
        scene.source.beat();
    }

    // Step 3: the heartbeat stopped at lastBeatAt.
    function tickStopped(now) {
        const windowEnd = scene.lastBeatAt + scene.windowMs;
        if (!provider.stale) {
            const deadline = windowEnd + 3 * scene.intervalMs + scene.staleSlackMs;
            if (now > deadline) {
                scene.fail("not stale " + (now - scene.lastBeatAt) + " ms after the last heartbeat ("
                    + scene.describe() + ")");
            }
            return;
        }
        if (now < windowEnd) {
            scene.fail("stale " + (now - scene.lastBeatAt) + " ms after the last heartbeat, before the "
                + scene.windowMs + " ms window ran out");
            return;
        }
        const late = scene.lastSampleAt - windowEnd;
        if (late > scene.slackMs) {
            scene.fail("a sample passed " + late + " ms after the heartbeat window");
            return;
        }
        if (late < -(scene.intervalMs + scene.slackMs)) {
            scene.fail("samples stopped " + (-late) + " ms before the heartbeat window ran out");
            return;
        }
        console.log("heartbeat: last sample " + (scene.lastSampleAt - scene.lastBeatAt)
            + " ms, stale " + (now - scene.lastBeatAt) + " ms after the last heartbeat");
        scene.enter(4);
        scene.beating = true;
        scene.beat();
    }

    // Step 1: one constant value since holdAt. True once the values have
    // stayed fresh for longer than it takes to turn stale without a heartbeat.
    function tickHeld(now) {
        if (scene.freshAt === 0) {
            if (provider.hasData && !provider.stale) {
                scene.freshAt = now;
            } else if (now - scene.stepStart > scene.stepTimeoutMs) {
                scene.fail("no fresh values (" + scene.describe() + ")");
            }
            return false;
        }
        if (provider.stale || !provider.hasData) {
            scene.fail("stale " + (now - scene.holdAt) + " ms after a single constant heartbeat value ("
                + scene.describe() + ")");
            return false;
        }
        return now - scene.freshAt > scene.windowMs + 3 * scene.intervalMs + scene.staleSlackMs;
    }

    function tick() {
        if (scene.done) {
            return;
        }
        const now = Date.now();
        switch (scene.step) {
        case 0:
            scene.source = scene.findSource();
            if (scene.source !== null) {
                scene.enter(1);
                scene.holdAt = Date.now();
                scene.source.hold();
            } else if (now - scene.stepStart > 2000) {
                scene.fail("test double not found in the provider");
            }
            break;
        case 1:
            if (scene.tickHeld(now)) {
                scene.enter(2);
                scene.beating = true;
                scene.beat();
            }
            break;
        case 2:
            if (scene.settledFresh(now)) {
                scene.enter(3);
                scene.beating = false;
            }
            break;
        case 3:
            scene.tickStopped(now);
            break;
        case 4:
            if (scene.lastSampleAt > scene.stepStart && provider.hasData && !provider.stale) {
                scene.finish(true, "SMOKE OK heartbeat");
            } else if (now - scene.stepStart > 3000) {
                scene.fail("not fresh 3 s after the heartbeat came back (" + scene.describe() + ")");
            }
            break;
        }
    }

    Component.onCompleted: scene.stepStart = Date.now()

    // A url property keeps a relative value as it is and the loader inside
    // the provider would resolve it against NetworkProvider.qml, so the path
    // of the test file is made absolute here.
    NetworkProvider {
        id: provider

        dataSource: "sensors"
        updateInterval: scene.intervalMs / 1000
        sensorSourceUrl: Qt.resolvedUrl("ScriptedHeartbeatSource.qml")
    }

    Connections {
        target: scene.source

        function onSampleReady(sample) {
            scene.lastSampleAt = sample.timestamp;
        }
    }

    Timer {
        interval: scene.intervalMs
        repeat: true
        running: scene.beating
        onTriggered: scene.beat()
    }

    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: scene.tick()
    }

    Timer {
        interval: 35000
        running: true
        onTriggered: scene.fail("overall timeout after 35 s")
    }
}
