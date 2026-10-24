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
    property string firstUpdated: ""
    property int stage: 0
    readonly property string v2: scene.localPath("../fixtures/vnstat-v2.json")
    readonly property string v1: scene.localPath("../fixtures/vnstat-v1.json")

    // command, timeout and the expected status; detail is checked when
    // given. warnings is the expected total so far (each state logs once,
    // missing never). After the first case the v2 data must always stay.
    readonly property var cases: [
        { line: "cat '" + scene.v2 + "'", timeoutMs: 5000, status: "ok", warnings: 0 },
        { line: "cat '" + scene.v1 + "'", timeoutMs: 5000, status: "unsupported", warnings: 1 },
        { line: "exit 127", timeoutMs: 5000, status: "missing", warnings: 1 },
        { line: "sh -c 'echo boom >&2; exit 3'", timeoutMs: 5000, status: "error", detail: "boom", warnings: 2 },
        { line: "sh -c 'echo boom >&2; exit 3'", timeoutMs: 5000, status: "error", detail: "boom", warnings: 2 },
        { line: "printf 'kaputt'", timeoutMs: 5000, status: "error", warnings: 3 },
        { line: "sleep 30", timeoutMs: 500, status: "error", detail: "timeout", warnings: 4 }
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
        if (!source.parsed || !source.parsed.interfaces.eth0) {
            return "parsed lost the v2 data";
        }
        if (source.lastUpdated === "" || (scene.step > 0 && source.lastUpdated !== scene.firstUpdated)) {
            return "lastUpdated is '" + source.lastUpdated + "'";
        }
        if (source.warnings !== current.warnings) {
            return "warnings is " + source.warnings + ", expected " + current.warnings;
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
        if (scene.step === 0) {
            scene.firstUpdated = source.lastUpdated;
        }
        scene.step += 1;
        scene.startCase();
    }

    // Two fresh sources (no data yet) make a dropped result visible: a run
    // that is disabled meanwhile, and one that is disabled and enabled again.
    function startSurvival() {
        const line = "sleep 1; cat '" + scene.v2 + "'";
        gone.command = line;
        flip.command = line;
        gone.enabled = true;
        flip.enabled = true;
        gone.enabled = false;
        flip.enabled = false;
        flip.enabled = true;
        if (gone.status !== "disabled" || gone.runs !== 1 || flip.runs !== 1) {
            scene.fail("unexpected start: " + gone.status + " " + gone.runs + " " + flip.runs);
            return;
        }
        survival.restart();
    }

    function checkSurvival() {
        if (scene.stage === 0) {
            // The stale runs have finished by now.
            if (gone.parsed !== null || gone.lastUpdated !== "" || gone.warnings !== 0) {
                scene.fail("late result after disabling was not dropped");
                return;
            }
            if (flip.parsed !== null || flip.runs !== 2) {
                scene.fail("stale run was kept or not restarted: runs " + flip.runs);
                return;
            }
            scene.stage = 1;
            survival.interval = 1500;
            survival.restart();
            return;
        }
        if (flip.status !== "ok" || !flip.parsed || off.runs !== 0 || off.status !== "disabled") {
            scene.fail("restarted run gave " + flip.status + ", or the disabled source ran");
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
        id: gone

        enabled: false
        intervalMs: 600000
    }

    UsageSource {
        id: flip

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
        id: survival

        interval: 1500
        onTriggered: scene.checkSurvival()
    }

    Timer {
        interval: 25000
        running: true
        onTriggered: scene.fail("timeout after 25 s at step " + scene.step)
    }

    Component.onCompleted: scene.startCase()
}
