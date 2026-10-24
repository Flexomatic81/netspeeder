// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Smoke scene for Launcher. It never starts a real program: commandLineFor is
// replaced by fixed shell lines, except for the invalid target, which is
// rejected before any run. Each case checks the failed() signal (or its
// absence) and that busy is released.

import QtQuick
import "../../package/contents/ui/data"

Item {
    id: scene

    property bool done: false
    property int step: 0
    property var failures: []
    property double stepStart: 0

    // line, timeout and the expected failure code ("" = no failure).
    readonly property var cases: [
        { line: "exit 0", timeoutMs: 5000, expect: "" },
        { line: "exit 127", timeoutMs: 5000, expect: "not-found" },
        { line: "exit 3", timeoutMs: 5000, expect: "failed" },
        { line: "sleep 30", timeoutMs: 500, expect: "timeout" }
    ]

    function finish(ok, message) {
        if (scene.done) {
            return;
        }
        scene.done = true;
        console.log(message);
        Qt.exit(ok ? 0 : 1);
    }

    function fail(message) {
        scene.finish(false, "SMOKE FAIL launcher: " + message);
    }

    function startCase() {
        if (scene.step >= scene.cases.length) {
            scene.startInvalid();
            return;
        }
        const current = scene.cases[scene.step];
        scene.failures = [];
        scene.stepStart = Date.now();
        launcher.timeoutMs = current.timeoutMs;
        launcher.commandLineFor = () => current.line;
        launcher.launch();
        // A second call while running must be ignored.
        launcher.launch();
        // Failures arrive on failed(); give a case time to settle.
        judge.restart();
    }

    function judgeCase() {
        const current = scene.cases[scene.step];
        const codes = scene.failures.map(f => f.code);
        const want = current.expect === "" ? [] : [current.expect];
        if (JSON.stringify(codes) !== JSON.stringify(want)) {
            scene.fail("'" + current.line + "' gave failures " + JSON.stringify(codes)
                + ", expected " + JSON.stringify(want));
            return;
        }
        if (launcher.busy) {
            scene.fail("'" + current.line + "' left the launcher busy");
            return;
        }
        scene.step += 1;
        scene.startCase();
    }

    function startInvalid() {
        scene.failures = [];
        // A second launcher keeps the real commandLineFor.
        plain.launch();
        // The rejection is synchronous.
        if (scene.failures.length !== 1 || scene.failures[0].code !== "invalid"
                || scene.failures[0].target !== "a;b" || plain.busy) {
            scene.fail("invalid target gave " + JSON.stringify(scene.failures));
            return;
        }
        scene.finish(true, "SMOKE OK launcher");
    }

    Launcher {
        id: launcher

        onFailed: (code, target) => {
            scene.failures = scene.failures.concat([{ code: code, target: target }]);
        }
    }

    Launcher {
        id: plain

        kind: "app"
        app: "a;b"
        onFailed: (code, target) => {
            scene.failures = scene.failures.concat([{ code: code, target: target }]);
        }
    }

    // Judges a case once it has had time to finish: 2 s covers the 500 ms
    // timeout and the instant exits.
    Timer {
        id: judge

        interval: 2000
        onTriggered: scene.judgeCase()
    }

    Timer {
        interval: 20000
        running: true
        onTriggered: scene.fail("timeout after 20 s at step " + scene.step)
    }

    Component.onCompleted: {
        launcher.kind = "command";
        launcher.command = "x";
        scene.startCase();
    }
}
