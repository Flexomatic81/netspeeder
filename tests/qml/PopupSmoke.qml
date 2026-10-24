// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Smoke scene for FullRepresentation: the header values ("–" without data,
// formatted with data), the status text per state, the source hint (also
// without a following sample), a selection change without a new sample, the
// button, the minimum size and the snapshot: while the popup is not active a
// new provider value changes neither `shown` nor the displayed text, and
// after it becomes active again both are current at once.
// It cannot see QML warnings itself: read the output of qml6 for the scene as
// well, it must be free of warnings (scripts/smoke.sh checks that).

import QtQuick
import QtQuick.Layouts
import QtTest
import org.kde.kirigami as Kirigami
import "../../package/contents/ui/full"
import "../../package/contents/code/format.mjs" as Format
import "../../package/contents/code/history.mjs" as History

Item {
    id: scene

    width: 600
    height: 700

    property bool done: false
    property int step: 0
    property int opened: 0
    // The time the popup gets to settle after a change (Qt.callLater runs in
    // the next event loop pass).
    readonly property int settleMs: 60

    function finish(ok, message) {
        if (scene.done) {
            return;
        }
        scene.done = true;
        console.log(message);
        Qt.exit(ok ? 0 : 1);
    }

    function fail(message) {
        scene.finish(false, "SMOKE FAIL popup: " + message);
    }

    // The texts that are shown (visible), anywhere below `item`.
    function shownTexts(item, found) {
        for (let i = 0; i < item.children.length; i++) {
            const child = item.children[i];
            if (!child.visible) {
                continue;
            }
            if (typeof child.text === "string" && child.text !== "" && child.width > 0) {
                found.push(child.text);
            }
            scene.shownTexts(child, found);
        }
        return found;
    }

    // The visible item below `item` whose text is exactly `text`; null if none.
    function itemWithText(item, text) {
        for (let i = 0; i < item.children.length; i++) {
            const child = item.children[i];
            if (child.visible && child.text === text) {
                return child;
            }
            const inner = scene.itemWithText(child, text);
            if (inner !== null) {
                return inner;
            }
        }
        return null;
    }

    function speedText(bytes: real): string {
        const speed = Format.formatSpeed(bytes, Format.DEFAULT_FORMAT);
        return speed.value + " " + speed.unit;
    }

    // "" when the view shows every text in `expected` and, for each text in
    // `absent`, no text that contains it.
    function textProblem(where: string, expected: var, absent: var): string {
        const texts = scene.shownTexts(view, []);
        for (const wanted of expected) {
            if (texts.indexOf(wanted) < 0) {
                return where + ": missing '" + wanted + "' in [" + texts.join(" | ") + "]";
            }
        }
        for (const unwanted of absent) {
            if (texts.some(t => t.indexOf(unwanted) >= 0)) {
                return where + ": unexpected '" + unwanted + "' in [" + texts.join(" | ") + "]";
            }
        }
        return "";
    }

    readonly property var waitingTexts: ["↓ –", "↑ –", "Waiting for network data…"]
    readonly property var statuses: ["Waiting for network data…", "No current data", "Offline", "Online"]

    function others(status: string): var {
        return scene.statuses.filter(s => s !== status);
    }

    // Each step changes the stub (or the view); the check runs after the
    // popup has settled. A check returns "" when it passes.
    readonly property var steps: [
        {
            name: "no data",
            apply: () => {},
            check: () => scene.textProblem("no data", scene.waitingTexts, ["Online", "Offline", "failed"])
        },
        {
            name: "live data",
            apply: () => {
                stub.down = 1.5 * 1024 * 1024;
                stub.up = 130 * 1024;
                stub.online = true;
                stub.activeSource = "sensors";
                stub.hasData = true;
            },
            check: () => scene.textProblem("live data", ["↓ " + scene.speedText(stub.down), "↑ " + scene.speedText(stub.up), "Online", "Source: System sensors"], scene.others("Online"))
        },
        {
            name: "kernel counters",
            apply: () => {
                stub.activeSource = "proc";
            },
            check: () => scene.textProblem("kernel counters", ["Source: Kernel counters"], ["System sensors"])
        },
        {
            name: "stale",
            apply: () => {
                stub.stale = true;
            },
            check: () => scene.textProblem("stale", ["No current data"], scene.others("No current data"))
        },
        {
            name: "offline",
            apply: () => {
                stub.stale = false;
                stub.online = false;
            },
            check: () => scene.textProblem("offline", ["Offline"], scene.others("Offline"))
        },
        {
            name: "hint without a sample",
            apply: () => {
                stub.online = true;
                stub.errorDetail = "boom";
                stub.errorCode = "source-failed";
            },
            check: () => scene.textProblem("hint", ["Reading network data failed: boom"], [])
        },
        {
            name: "hint gone",
            apply: () => {
                stub.errorCode = "";
            },
            check: () => scene.textProblem("hint gone", [], ["Reading network data failed"])
        },
        {
            name: "selection change without a sample",
            apply: () => {
                stub.primaryLabel = "Ethernet";
                stub.primaryIp = "192.168.1.5";
            },
            check: () => scene.textProblem("selection", ["Ethernet", "192.168.1.5"], [])
        },
        {
            name: "size",
            apply: () => {},
            check: scene.sizeProblem
        },
        {
            name: "snapshot while inactive",
            apply: () => {
                scene.before = {
                    shownDown: view.shown.down,
                    text: scene.textProblem("x", [], []) === "" ? scene.shownTexts(view, []).join("|") : ""
                };
                view.active = false;
                stub.down = 9 * 1024 * 1024;
                stub.history = History.createHistory(7);
            },
            check: () => {
                if (view.shown.down !== scene.before.shownDown) {
                    return "snapshot: shown.down changed while inactive to " + view.shown.down;
                }
                if (view.shown.history === stub.history) {
                    return "snapshot: shown.history followed the provider while inactive";
                }
                const now = scene.shownTexts(view, []).join("|");
                return now === scene.before.text ? "" : "snapshot: the displayed text changed while inactive: " + now;
            }
        },
        {
            name: "snapshot after activation",
            apply: () => {
                view.active = true;
            },
            check: () => {
                if (view.shown.down !== stub.down || view.shown.history !== stub.history) {
                    return "snapshot: shown is not current after activation";
                }
                return scene.textProblem("after activation", ["↓ " + scene.speedText(stub.down)], []);
            }
        }
    ]

    property var before: ({})

    function sizeProblem(): string {
        const unit = Kirigami.Units.gridUnit;
        const column = view;
        if (column.Layout.minimumWidth < unit * 18 || column.Layout.minimumHeight < unit * 20) {
            return "size: minimum is " + column.Layout.minimumWidth + "x" + column.Layout.minimumHeight + ", expected at least " + unit * 18 + "x" + unit * 20;
        }
        if (column.Layout.preferredWidth !== unit * 22 || column.Layout.preferredHeight !== unit * 26) {
            return "size: preferred is " + column.Layout.preferredWidth + "x" + column.Layout.preferredHeight;
        }
        if (view.width < column.Layout.minimumWidth || view.height < column.Layout.minimumHeight) {
            return "size: the view is " + view.width + "x" + view.height + ", below its minimum";
        }
        if (view.contentHeight > view.height) {
            return "size: the content needs " + view.contentHeight + " px, the view has " + view.height;
        }
        return "";
    }

    // The test steps run after the popup has settled; a Timer gives the event
    // loop its pass in between.
    Timer {
        id: stepper

        interval: scene.settleMs
        repeat: true
        running: true
        property bool applied: false
        onTriggered: {
            if (scene.done) {
                return;
            }
            if (scene.step >= scene.steps.length) {
                stepper.running = false;
                return;
            }
            const current = scene.steps[scene.step];
            if (!stepper.applied) {
                current.apply();
                stepper.applied = true;
                return;
            }
            const problem = current.check();
            if (problem !== "") {
                scene.fail(problem);
                return;
            }
            stepper.applied = false;
            scene.step++;
        }
    }

    // plain qml6 can only synthesize mouse events through a TestCase; it runs
    // its test functions once the steps are through and then quits.
    TestCase {
        id: input

        name: "input"
        when: scene.step >= scene.steps.length && !scene.done

        function test_button() {
            const button = scene.itemWithText(view, "Open System Monitor");
            if (button === null) {
                scene.fail("button: there is no 'Open System Monitor' button");
                return;
            }
            scene.opened = 0;
            input.mouseClick(button);
            if (scene.opened !== 1) {
                scene.fail("button: openSystemMonitor was sent " + scene.opened + " times, expected 1");
                return;
            }
            scene.finish(true, "SMOKE OK popup");
        }
    }

    QtObject {
        id: stub

        property bool hasData: false
        property real down: 0
        property real up: 0
        property bool online: false
        property bool stale: false
        property string activeSource: ""
        property string primaryLabel: ""
        property string primaryIp: ""
        property var interfaces: []
        property int includedCount: 0
        property var history: History.createHistory(10)
        property string errorCode: ""
        property string errorDetail: ""
        property string fallbackNote: ""
    }

    FullRepresentation {
        id: view

        provider: stub
        formatOptions: Format.DEFAULT_FORMAT
        width: Layout.preferredWidth
        height: Layout.preferredHeight
        onOpenSystemMonitor: scene.opened++
    }
}
