// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Smoke scene for UsageModel: the summary, the cap and the popup input are
// rebuilt only when the usage data changes, not on every network sample
// (each sample is a new interfaces array) or clock tick. Disabled, nothing
// runs and the objects stay the same. It never runs vnstat: the command reads
// the hand-built fixture.

import QtQuick
import "../../package/contents/ui/data"

Item {
    id: scene

    property bool done: false
    property int step: 0
    property bool applied: false
    property double stepStart: 0
    property var saved: ({})
    // The freshResult signals so far, and the summary status seen in the last.
    property int fresh: 0
    property string freshStatus: ""
    readonly property string v2: Qt.resolvedUrl("../fixtures/vnstat-v2.json").toString().replace("file://", "")

    function finish(ok, message) {
        if (scene.done) {
            return;
        }
        scene.done = true;
        console.log(message);
        Qt.exit(ok ? 0 : 1);
    }

    function fail(message) {
        scene.finish(false, "SMOKE FAIL usage model: " + message);
    }

    // A network sample: a new array of included physical interfaces.
    function sample(names: var): var {
        return names.map(name => ({ name: name, kind: "physical", included: true }));
    }

    function save() {
        scene.saved = { summary: model.summary, cap: model.cap, view: model.view };
    }

    // "" when summary, cap and view are the saved objects.
    function sameProblem(where: string): string {
        for (const key of ["summary", "cap", "view"]) {
            if (model[key] !== scene.saved[key]) {
                return where + ": " + key + " was rebuilt";
            }
        }
        return "";
    }

    // A check returns "" when it passes, "wait" to look again later.
    readonly property var steps: [
        {
            name: "disabled",
            apply: () => {},
            check: () => {
                if (model.status !== "disabled" || model.runs !== 0 || model.view.status !== "disabled") {
                    return "disabled: status " + model.status + ", runs " + model.runs + ", view " + model.view.status;
                }
                scene.save();
                return "";
            }
        },
        {
            name: "samples while disabled",
            apply: () => {
                model.interfaces = scene.sample(["eth0"]);
                model.interfaces = scene.sample(["eth0", "wlan7"]);
                model.tick();
            },
            check: () => model.namesKey === "" ? scene.sameProblem("disabled samples") : "disabled samples: names key '" + model.namesKey + "'"
        },
        {
            name: "enabled",
            apply: () => {
                model.interfaces = scene.sample(["eth0"]);
                model.enabled = true;
            },
            check: () => {
                if (model.status !== "ok") {
                    return "wait";
                }
                if (model.summary.status !== "ok" || model.view.summary !== model.summary || model.view.status !== "ok") {
                    return "enabled: no ok summary in the view";
                }
                if (scene.fresh !== 1 || scene.freshStatus !== "ok") {
                    return "enabled: " + scene.fresh + " fresh results, summary " + scene.freshStatus;
                }
                scene.save();
                return "";
            }
        },
        {
            name: "equal samples and a clock tick",
            apply: () => {
                model.interfaces = scene.sample(["eth0"]);
                model.interfaces = scene.sample(["eth0"]);
                model.tick();
            },
            check: () => scene.fresh !== 1 ? "equal samples: " + scene.fresh + " fresh results" : scene.sameProblem("equal samples")
        },
        {
            name: "a new interface",
            apply: () => {
                model.interfaces = scene.sample(["eth0", "wlan7"]);
            },
            check: () => {
                if (model.summary === scene.saved.summary || model.view === scene.saved.view) {
                    return "new interface: the summary was not rebuilt";
                }
                return model.summary.untracked.indexOf("wlan7") >= 0 && scene.fresh === 1 ? "" : "new interface: wlan7 untracked or " + scene.fresh + " fresh results";
            }
        },
        {
            name: "cap settings",
            apply: () => {
                scene.save();
                model.capEnabled = true;
            },
            check: () => {
                if (model.cap === scene.saved.cap || !model.cap.enabled || model.view.cap !== model.cap) {
                    return "cap: the cap did not follow its setting";
                }
                return model.summary === scene.saved.summary && scene.fresh === 1 ? "" : "cap: the summary was rebuilt or a fresh result came for a cap setting";
            }
        },
        {
            name: "a system virtual interface",
            apply: () => {
                model.systemVirtual = ["wlan0"];
            },
            check: () => {
                const names = model.namesKey.split("\n");
                return names.indexOf("wlan0") < 0 && names.indexOf("eth0") >= 0 ? "" : "system virtual: names key '" + model.namesKey + "'";
            }
        },
        {
            name: "a new vnStat run",
            apply: () => model.refresh(),
            check: () => scene.fresh >= 2 ? "" : "wait"
        }
    ]

    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            if (scene.done) {
                return;
            }
            if (scene.step >= scene.steps.length) {
                scene.finish(true, "SMOKE OK usage model");
                return;
            }
            const current = scene.steps[scene.step];
            if (!scene.applied) {
                scene.applied = true;
                scene.stepStart = Date.now();
                current.apply();
                return;
            }
            const problem = current.check();
            if (problem === "wait") {
                if (Date.now() - scene.stepStart > 5000) {
                    scene.fail(current.name + ": timed out");
                }
                return;
            }
            if (problem !== "") {
                scene.fail(problem);
                return;
            }
            scene.applied = false;
            scene.step++;
        }
    }

    UsageModel {
        id: model

        enabled: false
        command: "cat '" + scene.v2 + "'"
        interfaces: scene.sample(["eth0"])
        providerReady: true
        onFreshResult: {
            scene.fresh++;
            scene.freshStatus = model.summary.status;
        }
    }
}
