// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Smoke scene for NetworkProvider with the real data sources, in eight phases:
//   1  auto mode takes data from ksystemstats; after three samples the
//      history holds at least three points and its peak covers every one
//   2  the same instance switched to /proc: no old values, virtual interfaces
//      stay out of the sum, the session total did not drop with the switch
//   3  the same instance with an unloadable sensor source and dataSource
//      "sensors": no data, no old values, "sensors-unavailable"
//   4  auto mode with an unloadable sensor source falls back to /proc and
//      keeps the reason
//   5  a fixed sensor source that finds no interface reports "no-interfaces"
//      and recovers when one appears
//   6  auto mode with a sensor source that finds no interface falls back to
//      /proc and keeps the reason "no-interfaces"
//   7  a fixed sensor source that cannot be loaded, switched to auto mode,
//      falls back to /proc although the loader has no new error to report
//   8  steady data: `interfaces` changes once per sample and not on the
//      provider's own clock tick (a popup list bound to it must not be rebuilt
//      between samples), and `stale` still follows the clock
// The phases run one after another; each waits for settled data, at most
// 12 seconds.

import QtQuick
import "../../package/contents/ui/data"

Item {
    id: scene

    // Three source intervals of 500 ms: the data counts as settled once it
    // has been there this long.
    readonly property int settleMs: 1500
    readonly property int phaseTimeoutMs: 12000

    property var provider: null
    property int phase: 0
    property double phaseStart: 0
    property double dataSince: 0
    property string lastProblem: ""
    property bool interfaceAdded: false
    property bool modeSwitched: false
    // Session total at the end of phase 1; a source switch must not lower it.
    property real sessionDownBefore: 0
    // Phase 8: 0 find the test double, 1 wait for settled data, 2 count
    // emissions of `interfaces`, 3 wait for `stale` after the data stopped.
    property int steadyStep: 0
    property bool counting: false
    property int interfaceChanges: 0
    property int emittedAtStart: 0
    property double stepStart: 0
    property var steadySource: null
    property double interfaceAddedAt: 0
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
        scene.finish(false, "SMOKE FAIL provider: phase " + scene.phase + ": " + message);
    }

    function describe() {
        const p = scene.provider;
        return "hasData=" + p.hasData + " activeSource='" + p.activeSource + "' errorCode='"
            + p.errorCode + "' down=" + p.down + " up=" + p.up + " online=" + p.online
            + " includedCount=" + p.includedCount;
    }

    function replaceProvider(component) {
        if (scene.provider !== null) {
            scene.provider.destroy();
        }
        scene.provider = component.createObject(scene);
    }

    // The test double sits in the loader of the provider, which has no public
    // handle on it; find it among the provider's visual children.
    function findSource() {
        const children = scene.provider.children;
        for (let i = 0; i < children.length; i++) {
            const item = children[i].item;
            if (item !== undefined && item !== null && typeof item.addInterface === "function") {
                return item;
            }
        }
        return null;
    }

    // Returns "" when the provider shows settled, plausible data from `source`.
    function dataProblem(source) {
        const p = scene.provider;
        if (!p.hasData) {
            return "no data";
        }
        if (p.activeSource !== source) {
            return "activeSource is '" + p.activeSource + "', expected '" + source + "'";
        }
        if (!isFinite(p.down) || !isFinite(p.up)) {
            return "down/up not finite (" + p.down + ", " + p.up + ")";
        }
        if (!p.online) {
            return "not online";
        }
        return "";
    }

    function virtualProblem() {
        const rows = scene.provider.interfaces;
        if (rows.length < 1) {
            return "empty interface list";
        }
        for (let i = 0; i < rows.length; i++) {
            if (rows[i].kind === "virtual" && rows[i].included) {
                return "virtual interface '" + rows[i].name + "' is part of the sum";
            }
        }
        return "";
    }

    // Phase 1: the history has filled with samples and its peak is real.
    function historyProblem() {
        const h = scene.provider.history;
        if (h.down.length < 3) {
            return "history holds " + h.down.length + " points, expected at least 3";
        }
        for (let i = 0; i < h.down.length; i++) {
            if (h.down[i] > h.peakDown) {
                return "peakDown " + h.peakDown + " is below history value " + h.down[i];
            }
        }
        scene.sessionDownBefore = h.sessionDown;
        return "";
    }

    // Phase 2: the source switch kept the session total.
    function sessionProblem() {
        const total = scene.provider.history.sessionDown;
        if (total < scene.sessionDownBefore) {
            return "sessionDown fell from " + scene.sessionDownBefore + " to " + total + " at the source switch";
        }
        return scene.virtualProblem();
    }

    function fallbackProblem(reason) {
        const p = scene.provider;
        if (p.errorCode !== reason || p.fallbackNote !== reason) {
            return "errorCode '" + p.errorCode + "' fallbackNote '" + p.fallbackNote
                + "', expected '" + reason + "'";
        }
        return "";
    }

    // True once the provider has shown data from `source` for settleMs and
    // `extra` finds nothing wrong; fails the scene after the phase timeout.
    function settled(source, extra) {
        const now = Date.now();
        if (!scene.provider.hasData) {
            scene.dataSince = 0;
        } else if (scene.dataSince === 0) {
            scene.dataSince = now;
        }
        if (scene.dataSince !== 0 && now - scene.dataSince >= scene.settleMs) {
            let problem = scene.dataProblem(source);
            if (problem === "") {
                problem = extra();
            }
            if (problem === "") {
                return true;
            }
            scene.lastProblem = problem;
        }
        if (now - scene.phaseStart > scene.phaseTimeoutMs) {
            scene.fail("timed out, " + (scene.lastProblem !== "" ? scene.lastProblem : "no settled data")
                + " (" + scene.describe() + ")");
        }
        return false;
    }

    // Right after a source switch nothing of the old source may be left.
    function expectCleared() {
        if (scene.provider.hasData || scene.provider.activeSource !== "") {
            scene.fail("values of the old source survived the switch (" + scene.describe() + ")");
        }
    }

    function enter(phase) {
        scene.phase = phase;
        scene.phaseStart = Date.now();
        scene.dataSince = 0;
        scene.lastProblem = "";
        console.log("provider: phase " + phase);
        switch (phase) {
        case 1:
            scene.replaceProvider(autoComponent);
            break;
        case 2:
            scene.provider.dataSource = "proc";
            scene.expectCleared();
            break;
        case 3:
            scene.provider.sensorSourceUrl = Qt.resolvedUrl("Missing.qml");
            scene.provider.dataSource = "sensors";
            scene.expectCleared();
            break;
        case 4:
            scene.replaceProvider(missingAutoComponent);
            break;
        case 5:
            scene.interfaceAdded = false;
            scene.replaceProvider(emptyComponent);
            break;
        case 6:
            scene.replaceProvider(emptyAutoComponent);
            break;
        case 7:
            scene.modeSwitched = false;
            scene.replaceProvider(missingSensorsComponent);
            break;
        case 8:
            scene.steadyStep = 0;
            scene.counting = false;
            scene.replaceProvider(steadyComponent);
            break;
        }
    }

    function tick() {
        if (scene.done) {
            return;
        }
        const p = scene.provider;
        const now = Date.now();
        switch (scene.phase) {
        case 0:
            scene.enter(1);
            break;
        case 1:
            if (scene.settled("sensors", scene.historyProblem)) {
                scene.enter(2);
            }
            break;
        case 2:
            if (scene.settled("proc", scene.sessionProblem)) {
                scene.enter(3);
            }
            break;
        case 3:
            // No data may appear at any time in this phase.
            scene.expectCleared();
            if (p.errorCode === "sensors-unavailable") {
                scene.enter(4);
            } else if (now - scene.phaseStart > 2000) {
                scene.fail("errorCode is '" + p.errorCode + "' after 2 s (" + scene.describe() + ")");
            }
            break;
        case 4:
            if (scene.settled("proc", () => scene.fallbackProblem("sensors-unavailable"))) {
                scene.enter(5);
            }
            break;
        case 5:
            scene.tickEmptySource(now);
            break;
        case 6:
            if (scene.settled("proc", () => scene.fallbackProblem("no-interfaces"))) {
                scene.enter(7);
            }
            break;
        case 7:
            scene.tickModeSwitch(now);
            break;
        case 8:
            scene.tickSteady(now);
            break;
        }
    }

    function tickModeSwitch(now) {
        const p = scene.provider;
        if (!scene.modeSwitched) {
            if (p.errorCode === "sensors-unavailable") {
                p.dataSource = "auto";
                scene.expectCleared();
                scene.modeSwitched = true;
            } else if (now - scene.phaseStart > 2000) {
                scene.fail("errorCode is '" + p.errorCode + "' after 2 s (" + scene.describe() + ")");
            }
        } else if (scene.settled("proc", () => scene.fallbackProblem("sensors-unavailable"))) {
            scene.enter(8);
        }
    }

    // Phase 8. The test double emits one sample per interval, so a provider
    // that recomputes only on samples changes `interfaces` once per sample;
    // one that also recomputes on its clock tick changes it about twice as
    // often.
    function tickSteady(now) {
        const p = scene.provider;
        switch (scene.steadyStep) {
        case 0:
            scene.steadySource = scene.findSource();
            if (scene.steadySource !== null) {
                scene.steadySource.addInterface();
                scene.steadyStep = 1;
            } else if (now - scene.phaseStart > 2000) {
                scene.fail("test double not found in the provider");
            }
            break;
        case 1:
            if (scene.settled("sensors", () => "")) {
                scene.interfaceChanges = 0;
                scene.emittedAtStart = scene.steadySource.emitted;
                scene.counting = true;
                scene.stepStart = now;
                scene.steadyStep = 2;
            }
            break;
        case 2:
            if (p.stale) {
                scene.fail("stale although samples keep coming (" + scene.describe() + ")");
            } else if (now - scene.stepStart >= 3000) {
                scene.counting = false;
                const samples = scene.steadySource.emitted - scene.emittedAtStart;
                if (scene.interfaceChanges < 1 || scene.interfaceChanges > samples) {
                    scene.fail(scene.interfaceChanges + " changes of `interfaces` for " + samples
                        + " samples in 3 s, expected between 1 and " + samples);
                    return;
                }
                console.log("provider: " + scene.interfaceChanges + " changes of `interfaces` for "
                    + samples + " samples");
                // Without samples only the clock can make the data stale.
                scene.steadySource.running = false;
                scene.stepStart = now;
                scene.steadyStep = 3;
            }
            break;
        case 3:
            if (p.stale) {
                scene.finish(true, "SMOKE OK provider");
            } else if (now - scene.stepStart > 3500) {
                scene.fail("not stale 3.5 s after the last sample (" + scene.describe() + ")");
            }
            break;
        }
    }

    function tickEmptySource(now) {
        const p = scene.provider;
        if (!scene.interfaceAdded) {
            if (p.hasData) {
                scene.fail("data without an interface (" + scene.describe() + ")");
            } else if (now - scene.phaseStart >= 2200) {
                if (p.errorCode !== "no-interfaces" || p.activeSource !== "") {
                    scene.fail("expected 'no-interfaces' without data after 2 s (" + scene.describe() + ")");
                    return;
                }
                const source = scene.findSource();
                if (source === null) {
                    scene.fail("test double not found in the provider");
                    return;
                }
                source.addInterface();
                scene.interfaceAdded = true;
                scene.interfaceAddedAt = now;
            }
        } else if (p.hasData && p.errorCode === "" && p.activeSource === "sensors"
                && p.includedCount === 1 && isFinite(p.down) && isFinite(p.up)) {
            scene.enter(6);
        } else if (now - scene.interfaceAddedAt > 2000) {
            scene.fail("no recovery within 2 s of the new interface (" + scene.describe() + ")");
        }
    }

    // A url property keeps a relative value as it is and the loader inside
    // the provider would resolve it against NetworkProvider.qml, so the paths
    // of the test files are made absolute here.
    Component {
        id: autoComponent

        NetworkProvider {
            dataSource: "auto"
            updateInterval: 0.5
        }
    }

    Component {
        id: missingAutoComponent

        NetworkProvider {
            dataSource: "auto"
            updateInterval: 0.5
            sensorSourceUrl: Qt.resolvedUrl("Missing.qml")
        }
    }

    Component {
        id: emptyComponent

        NetworkProvider {
            dataSource: "sensors"
            updateInterval: 0.5
            fallbackDelayMs: 1500
            sensorSourceUrl: Qt.resolvedUrl("EmptySource.qml")
        }
    }

    Component {
        id: emptyAutoComponent

        NetworkProvider {
            dataSource: "auto"
            updateInterval: 0.5
            fallbackDelayMs: 1500
            sensorSourceUrl: Qt.resolvedUrl("EmptySource.qml")
        }
    }

    Component {
        id: steadyComponent

        NetworkProvider {
            dataSource: "sensors"
            updateInterval: 0.5
            sensorSourceUrl: Qt.resolvedUrl("EmptySource.qml")
        }
    }

    // Counts the changes of `interfaces` of whichever provider is current.
    Connections {
        target: scene.provider

        function onInterfacesChanged() {
            if (scene.counting) {
                scene.interfaceChanges += 1;
            }
        }
    }

    Component {
        id: missingSensorsComponent

        NetworkProvider {
            dataSource: "sensors"
            updateInterval: 0.5
            sensorSourceUrl: Qt.resolvedUrl("Missing.qml")
        }
    }

    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: scene.tick()
    }

    Timer {
        interval: 38000
        running: true
        onTriggered: scene.fail("overall timeout after 38 s")
    }
}
