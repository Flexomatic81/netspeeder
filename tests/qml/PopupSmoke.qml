// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Smoke scene for FullRepresentation: the header values ("–" without data,
// formatted with data), the status text per state, the source hint (also
// without a following sample), a selection change without a new sample, the
// button, the minimum size, the figures (peaks and session totals), the list
// of interfaces (12 rows scroll, the popup keeps its preferred size with the
// error hint shown, rows that stay keep their delegate, a click on an address
// copies it) and the snapshot: while the popup is not active a
// new provider value changes neither `shown` nor the displayed text, and
// after it becomes active again both are current at once.
// It cannot see QML warnings itself: read the output of qml6 for the scene as
// well, it must be free of warnings (scripts/smoke.sh checks that).

import QtQuick
import QtQuick.Layouts
import QtTest
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrolsaddons
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
    property int picked: 0
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

    // A history of `count` samples, one second apart.
    function historyOf(count: int): var {
        let history = History.createHistory(20);
        for (let i = 0; i < count; i++) {
            history = History.pushSample(history, {
                timestamp: 1000 * (i + 1),
                down: 1000 * (i + 1),
                up: 100 * (i + 1),
                totals: {}
            });
        }
        return history;
    }

    // "" when the graph is loaded and both series have `count` values.
    function graphProblem(where: string, count: int): string {
        const graph = view.graphItem;
        if (graph === null) {
            return where + ": the graph is not loaded";
        }
        if (graph.downSeries.length !== count || graph.upSeries.length !== count) {
            return where + ": the series have " + graph.downSeries.length + " and " + graph.upSeries.length + " values, expected " + count;
        }
        return "";
    }

    // The interfaces of the list steps: a wired and a wireless one that count,
    // and ten virtual ones that do not.
    function interfaceRows(ethDown: real): var {
        const rows = [
            {
                name: "eth0", label: "Ethernet", kind: "physical", included: true, online: true,
                down: ethDown, up: 200, totalDown: 5 * 1024 * 1024, totalUp: 2048, totalsKnown: true,
                ipv4: "192.168.1.5", ipv6: "", signal: null
            },
            {
                name: "wlan0", label: "Home WiFi", kind: "physical", included: true, online: true,
                down: 10, up: 20, totalDown: 100, totalUp: 200, totalsKnown: true,
                ipv4: "", ipv6: "fe80::1", signal: 71
            }
        ];
        for (let i = 0; i < 10; i++) {
            rows.push({
                name: "veth" + i, label: "", kind: "virtual", included: false, online: false,
                down: 0, up: 0, totalDown: 0, totalUp: 0, totalsKnown: false,
                ipv4: "", ipv6: "", signal: null
            });
        }
        return rows;
    }

    // A history whose peaks and session totals are not zero.
    function totalsHistory(): var {
        let history = History.createHistory(20);
        for (let i = 0; i < 3; i++) {
            history = History.pushSample(history, {
                timestamp: 1000 * (i + 1),
                down: 50000 * (i + 1),
                up: 7000 * (i + 1),
                totals: { eth0: { down: 4000000 * i, up: 900000 * i, known: true } }
            });
        }
        return history;
    }

    function totalText(bytes: real): string {
        const total = Format.formatTotal(bytes, Format.DEFAULT_FORMAT);
        return total.value + " " + total.unit;
    }

    // "" when the figures, the hint and the list of the "interfaces" step are
    // all there and the popup kept its preferred size.
    function interfaceProblem(): string {
        const list = view.interfaceList;
        if (list === null || list === undefined) {
            return "interfaces: there is no list";
        }
        const h = stub.history;
        if (h.sessionDown <= 0 || h.peakDown <= 0) {
            return "interfaces: the test history has no figures";
        }
        const problem = scene.textProblem("interfaces", [
            "Peak",
            "This session",
            "↓ " + scene.speedText(h.peakDown),
            "↑ " + scene.speedText(h.peakUp),
            "↓ " + scene.totalText(h.sessionDown),
            "↑ " + scene.totalText(h.sessionUp),
            "Ethernet",
            "Home WiFi",
            "Reading network data failed: boom"
        ], []);
        if (problem !== "") {
            return problem;
        }
        const texts = scene.shownTexts(list, []);
        for (const wanted of ["Signal 71%", "Total ↓ " + scene.totalText(5 * 1024 * 1024) + "   ↑ " + scene.totalText(2048)]) {
            if (!texts.some(t => t.indexOf(wanted) >= 0)) {
                return "interfaces: missing '" + wanted + "' in [" + texts.join(" | ") + "]";
            }
        }
        if (!texts.some(t => t.indexOf("virtual") >= 0 && t.indexOf("not counted") >= 0)) {
            return "interfaces: no row is marked virtual and not counted in [" + texts.join(" | ") + "]";
        }
        if (list.rowFor("veth9") === null) {
            return "interfaces: there is no row for veth9";
        }
        if (list.contentHeight <= list.viewportHeight) {
            return "interfaces: the list does not scroll (content " + list.contentHeight + ", view " + list.viewportHeight + ")";
        }
        const size = scene.sizeProblem();
        if (size !== "") {
            return size;
        }
        const room = scene.roomProblem("interfaces", "eth0");
        if (room !== "") {
            return room;
        }
        return view.height === view.Layout.preferredHeight ? "" : "interfaces: the popup is " + view.height + " px high";
    }

    // "" when the popup at its preferred size gives the graph at least six
    // grid units, shows the row of `name` completely (second line included)
    // at the top of the list, and every label of the speed axis is round.
    function roomProblem(where: string, name: string): string {
        const unit = Kirigami.Units.gridUnit;
        const graph = view.graphItem;
        if (graph === null) {
            return where + ": the graph is not loaded";
        }
        if (graph.height < unit * 6) {
            return where + ": the graph is " + graph.height + " px high, expected at least " + unit * 6;
        }
        const list = view.interfaceList;
        const row = list.rowFor(name);
        if (row === null) {
            return where + ": there is no row for " + name;
        }
        const top = row.mapToItem(list, 0, 0).y;
        const bottom = row.mapToItem(list, 0, row.height).y;
        if (top < 0 || bottom > list.viewportHeight || row.height < row.implicitHeight) {
            return where + ": the row of " + name + " is cut (top " + top + ", bottom " + bottom + ", view " + list.viewportHeight + ", row " + row.height + " of " + row.implicitHeight + ")";
        }
        const labels = graph.axisLabels.filter(label => label !== "");
        if (labels.length < 3 || labels[0].indexOf("0") !== 0) {
            return where + ": the axis shows " + labels.length + " labels [" + labels.join(" | ") + "]";
        }
        for (const label of labels) {
            if (!/^\d+(\.[05]0?)?( \S+)?$/.test(label)) {
                return where + ": the axis label '" + label + "' is not round in [" + labels.join(" | ") + "]";
            }
        }
        return "";
    }

    // "" when the row of `name` is the object it was before.
    function sameRow(name: string): string {
        const row = view.interfaceList.rowFor(name);
        return row !== null && row === scene.rowsBefore[name] ? "" : "rows: the row of " + name + " was rebuilt";
    }

    property var rowsBefore: ({})

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
            name: "graph with ten values",
            apply: () => {
                stub.history = scene.historyOf(10);
            },
            check: () => scene.graphProblem("graph", 10)
        },
        {
            name: "graph minutes reach the graph",
            apply: () => {
                view.graphMinutes = 1;
            },
            check: () => view.graphItem !== null && view.graphItem.minutes === 1 ? "" : "graph: graphMinutes 1 did not reach the graph"
        },
        {
            name: "graph while inactive",
            apply: () => {
                view.active = false;
                stub.history = scene.historyOf(11);
            },
            check: () => scene.graphProblem("graph inactive", 10)
        },
        {
            name: "graph after activation",
            apply: () => {
                view.active = true;
            },
            check: () => scene.graphProblem("graph active again", 11)
        },
        {
            name: "snapshot while inactive",
            apply: () => {
                scene.before = {
                    shownDown: view.shown.down,
                    text: scene.shownTexts(view, []).join("|")
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
        },
        {
            name: "one interface at the preferred size",
            apply: () => {
                stub.interfaces = scene.interfaceRows(1000).slice(0, 1);
            },
            check: () => view.height === view.Layout.preferredHeight ? scene.roomProblem("one interface", "eth0") : "one interface: the popup is " + view.height + " px high"
        },
        {
            name: "interfaces, figures and hint",
            apply: () => {
                stub.history = scene.totalsHistory();
                stub.interfaces = scene.interfaceRows(1000);
                stub.errorDetail = "boom";
                stub.errorCode = "source-failed";
            },
            check: scene.interfaceProblem
        },
        {
            name: "rows survive a change",
            apply: () => {
                const list = view.interfaceList;
                scene.rowsBefore = { eth0: list.rowFor("eth0"), wlan0: list.rowFor("wlan0"), veth7: list.rowFor("veth7") };
                const rows = scene.interfaceRows(3 * 1024 * 1024).filter(r => r.name !== "veth3");
                stub.interfaces = rows;
            },
            check: () => {
                const list = view.interfaceList;
                for (const name of ["eth0", "wlan0", "veth7"]) {
                    const problem = scene.sameRow(name);
                    if (problem !== "") {
                        return problem;
                    }
                }
                if (list.rowFor("veth3") !== null) {
                    return "rows: veth3 is still listed";
                }
                const texts = scene.shownTexts(list, []);
                const wanted = "↓ " + scene.speedText(3 * 1024 * 1024);
                return texts.some(t => t.indexOf(wanted) >= 0) ? "" : "rows: eth0 does not show '" + wanted + "' in [" + texts.join(" | ") + "]";
            }
        },
        {
            name: "two interfaces and the hint",
            apply: () => {
                stub.interfaces = scene.interfaceRows(1000).slice(0, 2);
                stub.errorCode = "source-failed";
            },
            check: () => scene.textProblem("minimum data", ["Reading network data failed: boom"], [])
        },
        {
            name: "minimum size with the hint",
            apply: () => {
                const problem = scene.minimumProblem("minimum with hint");
                if (problem !== "") {
                    scene.fail(problem);
                }
            },
            check: () => scene.layoutProblem("minimum with hint")
        },
        {
            name: "the hint goes",
            apply: () => {
                stub.errorCode = "";
            },
            check: () => scene.textProblem("minimum data", [], ["Reading network data failed"])
        },
        {
            name: "minimum size without the hint",
            apply: () => {
                const problem = scene.minimumProblem("minimum without hint");
                if (problem !== "") {
                    scene.fail(problem);
                }
            },
            check: () => scene.layoutProblem("minimum without hint")
        },
        {
            name: "back to the preferred size",
            apply: () => {
                view.width = Qt.binding(() => view.Layout.preferredWidth);
                view.height = Qt.binding(() => view.Layout.preferredHeight);
            },
            check: () => view.height === view.Layout.preferredHeight ? "" : "restore: the popup is " + view.height + " px high"
        },
        {
            name: "a very long name",
            apply: () => {
                stub.primaryLabel = "N".repeat(120);
                stub.primaryIp = "fe80::" + "abcd:".repeat(6) + "1";
            },
            check: () => {
                const unit = Kirigami.Units.gridUnit;
                if (view.Layout.minimumWidth !== unit * 18) {
                    return "long name: the minimum width is " + view.Layout.minimumWidth + ", expected " + unit * 18;
                }
                const label = scene.itemWithText(view, stub.primaryLabel);
                if (label === null || !label.truncated) {
                    return "long name: the name is not elided at the preferred width";
                }
                return label.x + label.width <= view.width ? "" : "long name: the name reaches past the popup";
            }
        },
        {
            name: "the long name goes",
            apply: () => {
                stub.primaryLabel = "Ethernet";
                stub.primaryIp = "192.168.1.5";
            },
            check: () => scene.textProblem("long name gone", ["Ethernet"], [])
        },
        {
            name: "a row comes back",
            apply: () => {
                stub.interfaces = scene.interfaceRows(1000);
            },
            check: () => view.interfaceList.rowFor("veth3") !== null ? scene.sameRow("eth0") : "rows: veth3 is not back"
        }
    ]

    property var before: ({})

    // "" when the view, sized to its own minimum, keeps the graph and the list
    // at their minimum and the footer completely inside, nothing overlapping.
    function minimumProblem(where: string): string {
        const unit = Kirigami.Units.gridUnit;
        const graph = view.graphItem;
        if (graph === null || view.Layout.minimumHeight < unit * 20 || view.Layout.minimumWidth < unit * 18) {
            return where + ": no graph or the minimum is " + view.Layout.minimumWidth + "x" + view.Layout.minimumHeight;
        }
        view.width = view.Layout.minimumWidth;
        view.height = view.Layout.minimumHeight;
        return "";
    }

    function layoutProblem(where: string): string {
        const unit = Kirigami.Units.gridUnit;
        const graph = view.graphItem;
        const list = view.interfaceList;
        const footer = view.footer;
        if (graph.height < unit * 6 - 0.5) {
            return where + ": the graph is " + graph.height + " px high at the minimum size";
        }
        if (list.height < list.twoRowsHeight - 0.5) {
            return where + ": the list is " + list.height + " px high, below " + list.twoRowsHeight;
        }
        const items = [graph, list, footer];
        let previousBottom = 0;
        for (const item of items) {
            const top = item.mapToItem(view, 0, 0).y;
            if (top < previousBottom - 0.5) {
                return where + ": an item starts at " + top + ", above the end of the previous one at " + previousBottom;
            }
            previousBottom = top + item.height;
        }
        if (previousBottom > view.height + 0.5 || footer.height < footer.implicitHeight - 0.5) {
            return where + ": the footer ends at " + previousBottom + " of " + view.height + " (height " + footer.height + " of " + footer.implicitHeight + ")";
        }
        return "";
    }

    function sizeProblem(): string {
        const unit = Kirigami.Units.gridUnit;
        if (view.Layout.minimumWidth < unit * 18 || view.Layout.minimumHeight < unit * 20) {
            return "size: minimum is " + view.Layout.minimumWidth + "x" + view.Layout.minimumHeight + ", expected at least " + unit * 18 + "x" + unit * 20;
        }
        if (view.Layout.preferredWidth !== unit * 22 || view.Layout.preferredHeight !== unit * 30) {
            return "size: preferred is " + view.Layout.preferredWidth + "x" + view.Layout.preferredHeight;
        }
        if (view.width < view.Layout.minimumWidth || view.height < view.Layout.minimumHeight) {
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
            input.pressButton();
            input.pressGraphSwitch();
            input.pressActiveSwitch();
            input.pressAddress();
            scene.finish(true, "SMOKE OK popup");
        }

        function pressButton() {
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
        }

        // A click on the switch of the span that is already shown keeps it
        // checked and changes nothing else.
        function pressActiveSwitch() {
            const minutes = view.graphMinutes;
            const button = scene.itemWithText(view, minutes + " min");
            if (button === null) {
                scene.fail("graph: there is no '" + minutes + " min' switch");
                return;
            }
            scene.picked = 0;
            input.mouseClick(button);
            if (!button.checked || view.graphItem.minutes !== minutes) {
                scene.fail("graph: the active switch lost its check (checked " + button.checked + ", minutes " + view.graphItem.minutes + ")");
            }
        }

        // A click on an address copies it and says so.
        function pressAddress() {
            const button = view.interfaceList.rowFor("eth0").ipButton;
            probe.content = "";
            input.mouseClick(button);
            if (probe.content !== "192.168.1.5") {
                scene.fail("copy: the clipboard holds '" + probe.content + "', expected 192.168.1.5");
                return;
            }
            if (scene.itemWithText(view, "Copied") === null) {
                scene.fail("copy: there is no 'Copied' note after the click");
            }
        }

        function pressGraphSwitch() {
            const button = scene.itemWithText(view, "15 min");
            if (button === null) {
                scene.fail("graph: there is no '15 min' switch");
                return;
            }
            input.mouseClick(button);
            if (scene.picked !== 15) {
                scene.fail("graph: graphMinutesPicked gave " + scene.picked + ", expected 15");
            }
        }
    }

    // Reads the system clipboard the list writes to.
    Clipboard {
        id: probe
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
        onGraphMinutesPicked: minutes => scene.picked = minutes
    }
}
