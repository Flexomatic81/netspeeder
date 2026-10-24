// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Smoke scene for UsageBookkeeping: a vnStat result that arrives before the
// network provider knows the interfaces decides nothing, the cap is decided
// once they are known, and a level reached is reported once. A plain
// object stands in for the configuration and records every write. It never
// runs vnstat: the command prints a hand-built result with today's date.

import QtQuick
import "../../package/contents/ui/data"

Item {
    id: scene

    property bool done: false
    property int step: 0
    property bool applied: false
    property double stepStart: 0
    // The freshResult signals so far and the levels reported.
    property int fresh: 0
    property var reported: []
    readonly property real gib: 1024 * 1024 * 1024

    function finish(ok, message) {
        if (scene.done) {
            return;
        }
        scene.done = true;
        console.log(message);
        Qt.exit(ok ? 0 : 1);
    }

    function fail(message) {
        scene.finish(false, "SMOKE FAIL usage bookkeeping: " + message);
    }

    // vnStat JSON with today's traffic: eth0 half the cap, tun0 a bit more.
    function vnstatJson(): string {
        const now = new Date();
        const date = {
            year: now.getFullYear(),
            month: now.getMonth() + 1,
            day: now.getDate()
        };
        const iface = (name, rx) => ({
                name: name,
                alias: "",
                created: {
                    date: {
                        year: 2000,
                        month: 1,
                        day: 1
                    }
                },
                updated: {
                    date: date,
                    time: {
                        hour: 0,
                        minute: 0
                    }
                },
                traffic: {
                    day: [
                        {
                            date: date,
                            rx: rx,
                            tx: 0
                        }
                    ]
                }
            });
        return JSON.stringify({
            vnstatversion: "2.13",
            jsonversion: "2",
            interfaces: [iface("eth0", 0.5 * scene.gib), iface("tun0", 0.6 * scene.gib)]
        });
    }

    function writes(): string {
        return "cycle " + config.cycleWrites + ", level " + config.levelWrites;
    }

    // A check returns "" when it passes, "wait" to look again later.
    readonly property var steps: [
        {
            name: "a result before the interfaces are known",
            // Counts from here: a var property can report its initial value.
            apply: () => {
                config.cycleWrites = 0;
                config.levelWrites = 0;
            },
            check: () => {
                if (model.status !== "ok" || Date.now() - scene.stepStart < 500) {
                    return "wait";
                }
                // Counted now, tun0 would put the usage past the cap.
                if (model.cap.level !== 2) {
                    return "early: level " + model.cap.level + " instead of 2 with tun0 counted";
                }
                if (scene.fresh !== 0 || scene.reported.length !== 0) {
                    return "early: " + scene.fresh + " fresh results, reported " + scene.reported;
                }
                return config.cycleWrites + config.levelWrites === 0 ? "" : "early: " + scene.writes();
            }
        },
        {
            name: "the provider knows the interfaces",
            apply: () => {
                model.interfaces = [
                    {
                        name: "eth0",
                        kind: "physical",
                        included: true
                    },
                    {
                        name: "tun0",
                        kind: "virtual",
                        included: false
                    }
                ];
                model.providerReady = true;
            },
            check: () => {
                if (scene.fresh < 1) {
                    return "wait";
                }
                if (scene.fresh !== 1 || scene.reported.length !== 0 || model.cap.level !== 0) {
                    return "ready: " + scene.fresh + " fresh results, reported " + scene.reported + ", level " + model.cap.level;
                }
                if (config.capNotifiedCycle !== model.summary.current.start || config.capNotifiedLevel !== 0) {
                    return "ready: stored " + config.capNotifiedCycle + "/" + config.capNotifiedLevel;
                }
                return config.cycleWrites === 1 && config.levelWrites === 0 ? "" : "ready: " + scene.writes();
            }
        },
        {
            name: "manual selection with the tunnel",
            apply: () => {
                model.selectedInterfaces = ["eth0", "tun0"];
                model.interfaceSelection = "manual";
                model.refresh();
            },
            check: () => {
                if (scene.fresh < 2) {
                    return "wait";
                }
                if (scene.reported.join(",") !== "2" || config.capNotifiedLevel !== 2 || config.levelWrites !== 1) {
                    return "manual: reported " + scene.reported + ", " + scene.writes() + ", stored level " + config.capNotifiedLevel;
                }
                return "";
            }
        },
        {
            name: "the same level again",
            apply: () => model.refresh(),
            check: () => {
                if (scene.fresh < 3) {
                    return "wait";
                }
                return scene.reported.join(",") === "2" && config.levelWrites === 1 ? "" : "again: reported " + scene.reported + ", " + scene.writes();
            }
        }
    ]

    // Stands in for Plasmoid.configuration and counts the writes.
    QtObject {
        id: config

        property bool capNotify: true
        property string capNotifiedCycle: ""
        property int capNotifiedLevel: 0
        property int cycleWrites: 0
        property int levelWrites: 0

        onCapNotifiedCycleChanged: config.cycleWrites++
        onCapNotifiedLevelChanged: config.levelWrites++
    }

    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            if (scene.done) {
                return;
            }
            if (scene.step >= scene.steps.length) {
                scene.finish(true, "SMOKE OK usage bookkeeping");
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

        command: "printf '%s' '" + scene.vnstatJson() + "'"
        interfaces: []
        providerReady: false
        capEnabled: true
        capGiB: 1
        warnPercent: 80
        onFreshResult: scene.fresh++
    }

    UsageBookkeeping {
        usage: model
        configuration: config
        onCapReached: level => scene.reported = scene.reported.concat([level])
    }
}
