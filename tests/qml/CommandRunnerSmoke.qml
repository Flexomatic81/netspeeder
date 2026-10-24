// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Smoke scene for CommandRunner: two instances run the same command at the
// same time. Requests made while busy must merge into one extra run, and every
// run must return fresh output (no cached result of an equal source name).
// A last phase checks the time limit: a command that outlives timeoutMs must
// report exit code -2 in time, release busy, and the runner must keep working.

import QtQuick
import "../../package/contents/ui/data"

Item {
    id: scene

    // The first instance gets run() three times at once: one run plus one
    // merged follow-up. The second instance gets a single run().
    readonly property int expectedFirst: 2
    readonly property int expectedSecond: 1

    property var firstResults: []
    property var secondResults: []
    property bool done: false
    property double phaseStart: 0
    property int slowStage: 0

    function finish(ok, message) {
        if (scene.done) {
            return;
        }
        scene.done = true;
        console.log(message);
        Qt.exit(ok ? 0 : 1);
    }

    function record(list, exitCode, stdout, stderr) {
        // Assigning a new array keeps the property change notifications honest.
        const next = list.slice();
        next.push({ exitCode: exitCode, out: stdout.trim(), err: stderr });
        return next;
    }

    // Called after the expected number of runs has arrived and a settle period
    // has passed, so surplus finished() signals would be counted too.
    function verify() {
        if (scene.firstResults.length !== scene.expectedFirst) {
            scene.finish(false, "SMOKE FAIL runner: first instance finished "
                + scene.firstResults.length + " times, expected " + scene.expectedFirst);
            return;
        }
        if (scene.secondResults.length !== scene.expectedSecond) {
            scene.finish(false, "SMOKE FAIL runner: second instance finished "
                + scene.secondResults.length + " times, expected " + scene.expectedSecond);
            return;
        }
        const all = scene.firstResults.concat(scene.secondResults);
        const seen = {};
        for (let i = 0; i < all.length; i++) {
            if (all[i].exitCode !== 0) {
                scene.finish(false, "SMOKE FAIL runner: exit code " + all[i].exitCode + " stderr: " + all[i].err);
                return;
            }
            if (all[i].out === "" || seen[all[i].out] === true) {
                scene.finish(false, "SMOKE FAIL runner: empty or repeated output '" + all[i].out + "'");
                return;
            }
            seen[all[i].out] = true;
        }
        if (first.busy || second.busy) {
            scene.finish(false, "SMOKE FAIL runner: still busy after all runs finished");
            return;
        }
        scene.startTimeoutPhase();
    }

    function startTimeoutPhase() {
        scene.phaseStart = Date.now();
        slow.run();
    }

    function onSlowFinished(exitCode, stderr) {
        if (scene.slowStage === 0) {
            const elapsed = Date.now() - scene.phaseStart;
            if (exitCode !== -2 || elapsed > 2000 || stderr.indexOf("timed out") < 0) {
                scene.finish(false, "SMOKE FAIL runner: timeout run gave exit " + exitCode
                    + " after " + elapsed + " ms, stderr '" + stderr + "'");
                return;
            }
            if (slow.busy) {
                scene.finish(false, "SMOKE FAIL runner: still busy after the timeout");
                return;
            }
            scene.slowStage = 1;
            slow.command = "echo again";
            slow.run();
            return;
        }
        if (exitCode !== 0) {
            scene.finish(false, "SMOKE FAIL runner: run after timeout gave exit " + exitCode);
            return;
        }
        scene.finish(true, "SMOKE OK runner");
    }

    function onRunFinished() {
        if (scene.firstResults.length >= scene.expectedFirst
                && scene.secondResults.length >= scene.expectedSecond) {
            settle.restart();
        }
    }

    CommandRunner {
        id: first

        command: "date +%s%N"
        onFinished: (exitCode, stdout, stderr) => {
            scene.firstResults = scene.record(scene.firstResults, exitCode, stdout, stderr);
            scene.onRunFinished();
        }
    }

    CommandRunner {
        id: second

        command: "date +%s%N"
        onFinished: (exitCode, stdout, stderr) => {
            scene.secondResults = scene.record(scene.secondResults, exitCode, stdout, stderr);
            scene.onRunFinished();
        }
    }

    CommandRunner {
        id: slow

        command: "sleep 5"
        timeoutMs: 500
        onFinished: (exitCode, stdout, stderr) => scene.onSlowFinished(exitCode, stderr)
    }

    // Waits for late, unexpected finished() signals before judging.
    Timer {
        id: settle

        interval: 1000
        onTriggered: scene.verify()
    }

    Timer {
        interval: 15000
        running: true
        onTriggered: scene.finish(false, "SMOKE FAIL runner: timeout after 15 s (first "
            + scene.firstResults.length + ", second " + scene.secondResults.length + ")")
    }

    Component.onCompleted: {
        first.run();
        first.run();
        first.run();
        second.run();
    }
}
