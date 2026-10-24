// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Smoke scene for UsageSource. It never runs vnstat: command is replaced by
// shell lines that read the hand-built fixtures or fail on purpose.

import QtQuick
import "../../package/contents/ui/data"

Item {
    id: scene

    property bool done: false
    property int step: 0
    property double stepStart: 0
    readonly property string v2: scene.localPath("../fixtures/vnstat-v2.json")
    readonly property string v1: scene.localPath("../fixtures/vnstat-v1.json")

    // command, timeout and the expected state; detail and hasEth0 are
    // checked when given.
    readonly property var cases: [
        { line: "cat '" + scene.v2 + "'", timeoutMs: 5000, status: "ok", hasEth0: true },
        { line: "cat '" + scene.v1 + "'", timeoutMs: 5000, status: "unsupported" },
        { line: "exit 127", timeoutMs: 5000, status: "missing" },
        { line: "sh -c 'echo boom >&2; exit 3'", timeoutMs: 5000, status: "error", detail: "boom" },
        { line: "printf 'kaputt'", timeoutMs: 5000, status: "error" },
        { line: "sleep 30", timeoutMs: 500, status: "error", detail: "timeout" }
    ]

    function localPath(relative) {
        return Qt.resolvedUrl(relative).toString().replace("file://", "");
    }

    function finish(ok, message) {
        if (scene.done) {
            return;
        }
        scene.done = true;
        console.log(message);
        Qt.exit(ok ? 0 : 1);
    }

    function fail(message) {
        scene.finish(false, "SMOKE FAIL usage source: " + message);
    }

    function startCase() {
        if (scene.step >= scene.cases.length) {
            scene.startSurvival();
            return;
        }
        const current = scene.cases[scene.step];
        scene.stepStart = Date.now();
        source.timeoutMs = current.timeoutMs;
        source.command = current.line;
        // Enabling starts the first run; later cases start theirs by hand.
        source.enabled = true;
        // Several calls in a row start exactly one run.
        source.refresh();
        source.refresh();
        poll.restart();
    }

    function caseResult(current) {
        if (source.status !== current.status) {
            return "'" + current.line + "' gave status " + source.status + ", expected " + current.status;
        }
        if (current.hasEth0 && (!source.parsed || !source.parsed.interfaces.eth0)) {
            return "parsed has no eth0";
        }
        if (current.detail !== undefined && source.detail.indexOf(current.detail) < 0) {
            return "detail '" + source.detail + "' lacks '" + current.detail + "'";
        }
        return "";
    }

    function judgeCase() {
        const current = scene.cases[scene.step];
        if (source.busy) {
            if (Date.now() - scene.stepStart > 5000) {
                poll.stop();
                scene.fail("'" + current.line + "' still running after 5 s");
            }
            return;
        }
        poll.stop();
        const problem = scene.caseResult(current);
        if (problem !== "") {
            scene.fail(problem);
            return;
        }
        if (source.runs !== scene.step + 1) {
            scene.fail("runs is " + source.runs + " after case " + (scene.step + 1));
            return;
        }
        scene.step += 1;
        scene.startCase();
    }

    // A late result after enabled went false must be dropped.
    function startSurvival() {
        source.timeoutMs = 5000;
        source.command = "sleep 1; cat '" + scene.v2 + "'";
        source.refresh();
        source.enabled = false;
        if (source.status !== "disabled") {
            scene.fail("status after disabling is " + source.status);
            return;
        }
        late.restart();
    }

    function checkLate() {
        if (source.status !== "disabled") {
            scene.fail("late result changed the status to " + source.status);
            return;
        }
        if (off.runs !== 0 || off.status !== "disabled") {
            scene.fail("disabled source ran or is " + off.status);
            return;
        }
        scene.finish(true, "SMOKE OK usage source");
    }

    // Starts disabled, so nothing runs before the first case sets a command.
    UsageSource {
        id: source

        enabled: false
        intervalMs: 600000
    }

    UsageSource {
        id: off

        enabled: false
        command: "echo nope"
    }

    Timer {
        id: poll

        interval: 50
        repeat: true
        onTriggered: scene.judgeCase()
    }

    Timer {
        id: late

        interval: 2000
        onTriggered: scene.checkLate()
    }

    Timer {
        interval: 25000
        running: true
        onTriggered: scene.fail("timeout after 25 s at step " + scene.step)
    }

    Component.onCompleted: scene.startCase()
}
