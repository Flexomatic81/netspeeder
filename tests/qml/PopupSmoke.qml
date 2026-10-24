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
// after it becomes active again both are current at once. The usage section:
// hidden while disabled (the minimum height stays), the hints per status, the
// table with complete and incomplete periods, the data cap bar per level, the
// untracked interfaces, the vnstat update time and its outdated hint, the
// minimum size with everything shown, the snapshot while inactive and the
// refresh request on activation.
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
import "../../package/contents/code/usage.mjs" as Usage

Item {
    id: scene

    width: 600
    height: 700

    property bool done: false
    property int step: 0
    property int opened: 0
    property int picked: 0
    property int usageRequests: 0
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
        const glued = texts.find(t => t.startsWith("·") || t.endsWith("·"));
        if (glued !== undefined) {
            return where + ": '" + glued + "' starts or ends with a separator";
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

    // "" when the popup at its preferred size gives the graph at least seven
    // grid units, shows the row of `name` completely (second line included)
    // at the top of the list, and every label of the speed axis is round.
    function roomProblem(where: string, name: string): string {
        const unit = Kirigami.Units.gridUnit;
        const graph = view.graphItem;
        if (graph === null) {
            return where + ": the graph is not loaded";
        }
        if (graph.height < unit * 7) {
            return where + ": the graph is " + graph.height + " px high, expected at least " + unit * 7;
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
            check: () => scene.textProblem("selection", ["Ethernet", "192.168.1.5 · Online"], [])
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
            name: "a stored popup height of 361 px",
            apply: () => {
                // Plasma keeps a stored size, but never goes below the minimum.
                view.width = 560;
                view.height = Math.max(361, view.Layout.minimumHeight);
            },
            check: () => {
                if (view.height < view.Layout.minimumHeight) {
                    return "361 px: the popup is " + view.height + " px high, below its minimum " + view.Layout.minimumHeight;
                }
                return scene.layoutProblem("361 px");
            }
        },
        {
            name: "back to the preferred size again",
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

    // --- usage -----------------------------------------------------------

    readonly property var usageToday: ({ year: 2026, month: 10, day: 24 })
    readonly property real gib: 1024 * 1024 * 1024
    readonly property var noCap: ({ enabled: false, percent: 0, level: 0, capBytes: 0 })
    readonly property string missingText: "Install vnstat and enable its service to see daily and monthly usage."
    readonly property string outdatedText: "The vnstat data is not current. Is the vnstat service running?"
    // The minimum height of the popup with the usage section disabled.
    property real minimumWithoutUsage: 0

    // vnStat data of eth0 (1 GB down, 0.1 GB up a day) known since `created`.
    function usageParsed(created: string): var {
        const days = [];
        for (let key = created; key <= "2026-10-24"; key = Usage.addDays(key, 1)) {
            days.push({ date: key, rx: 1000000000, tx: 100000000 });
        }
        return {
            status: "ok",
            version: "2",
            interfaces: { eth0: { created: created, updated: "2026-10-24T18:00", days: days } }
        };
    }

    function usageSummaryOf(created: string, names: var): var {
        return Usage.usageSummary(scene.usageParsed(created), names, scene.usageToday, 1);
    }

    // The usage input of the view; `extra` overrides single fields.
    function usageOf(status: string, summary: var, extra: var): var {
        return Object.assign({
            summary: summary !== null ? summary : Usage.emptySummary(scene.usageToday, 1),
            status: status,
            detail: "",
            cap: scene.noCap,
            lastUpdated: "",
            outdated: false
        }, extra);
    }

    function capOf(percent: real, level: int): var {
        return { enabled: true, percent: percent, level: level, capBytes: 100 * scene.gib };
    }

    // "" when the section is visible and shows `expected` but none of
    // `absent` (nor any other status hint).
    function usageProblem(where: string, expected: var, absent: var): string {
        if (!view.usagePanel.visible || view.usagePanel.height <= 0) {
            return where + ": the usage section is hidden";
        }
        const hints = [scene.missingText, "This vnstat version is not supported.", "Reading vnstat failed", "Loading usage…", scene.outdatedText, "vnstat does not track"];
        const others = hints.filter(h => !expected.some(e => e.indexOf(h) === 0));
        return scene.textProblem(where, expected, absent.concat(others));
    }

    // "" when the cap bar shows `value` in `color` with `text`.
    function capProblem(where: string, value: real, color: color, text: string): string {
        const panel = view.usagePanel;
        if (!panel.capBar.visible) {
            return where + ": the cap bar is hidden";
        }
        if (panel.capBar.from !== 0 || panel.capBar.to !== 100 || panel.capBar.value !== value) {
            return where + ": the bar shows " + panel.capBar.value + " of " + panel.capBar.from + "…" + panel.capBar.to + ", expected " + value;
        }
        if (panel.capColor.toString() !== color.toString()) {
            return where + ": the cap color is " + panel.capColor + ", expected " + color;
        }
        return scene.usageProblem(where, [text], []);
    }

    readonly property var usageSteps: [
        {
            name: "usage disabled",
            apply: () => {},
            check: () => {
                if (view.usagePanel.visible) {
                    return "usage disabled: the section is visible";
                }
                scene.minimumWithoutUsage = view.Layout.minimumHeight;
                return scene.textProblem("usage disabled", [], ["Today", "vnstat", "Loading usage"]);
            }
        },
        {
            name: "usage loading",
            apply: () => {
                view.usage = scene.usageOf("loading", null, {});
            },
            check: () => scene.usageProblem("usage loading", ["Loading usage…"], ["Today"])
        },
        {
            name: "usage of complete periods",
            apply: () => {
                view.usage = scene.usageOf("ok", scene.usageSummaryOf("2026-08-20", ["eth0"]), { lastUpdated: "2026-10-24T18:00" });
            },
            check: () => {
                const problem = scene.usageProblem("usage complete", [
                    "Today", "Yesterday", "This period", "Last period",
                    "↓ " + scene.totalText(1000000000), "↑ " + scene.totalText(100000000), "Σ " + scene.totalText(1100000000),
                    "↓ " + scene.totalText(24 * 1000000000), "Σ " + scene.totalText(30 * 1100000000)
                ], ["(incomplete)", "Loading usage"]);
                if (problem !== "") {
                    return problem;
                }
                const texts = scene.shownTexts(view, []);
                const updated = texts.find(t => t.indexOf("vnstat last updated: ") === 0);
                if (updated === undefined || updated.indexOf("2026-10-24T") >= 0) {
                    return "usage complete: no formatted update time in [" + texts.join(" | ") + "]";
                }
                return view.usagePanel.capBar.visible ? "usage complete: the cap bar is shown without a cap" : "";
            }
        },
        {
            name: "usage of incomplete periods",
            apply: () => {
                view.usage = scene.usageOf("ok", scene.usageSummaryOf("2026-10-05", ["eth0"]), {});
            },
            check: () => scene.usageProblem("usage incomplete", ["Today", "This period (incomplete)", "Last period (incomplete)"], ["vnstat last updated"])
        },
        {
            name: "cap at 50 %",
            apply: () => {
                view.usage = scene.usageOf("ok", scene.usageSummaryOf("2026-08-20", ["eth0"]), { cap: scene.capOf(50, 0) });
            },
            check: () => scene.capProblem("cap 50", 50, Kirigami.Theme.highlightColor, scene.totalText(24 * 1100000000) + " of " + scene.totalText(100 * scene.gib) + " (50 %)")
        },
        {
            name: "cap at 85.5 %",
            apply: () => {
                view.usage = scene.usageOf("ok", scene.usageSummaryOf("2026-08-20", ["eth0"]), { cap: scene.capOf(85.5, 1) });
            },
            check: () => scene.capProblem("cap 85", 85.5, Kirigami.Theme.neutralTextColor, scene.totalText(24 * 1100000000) + " of " + scene.totalText(100 * scene.gib) + " (85.5 %)")
        },
        {
            name: "cap at 120 %",
            apply: () => {
                view.usage = scene.usageOf("ok", scene.usageSummaryOf("2026-08-20", ["eth0"]), { cap: scene.capOf(120, 2) });
            },
            check: () => scene.capProblem("cap 120", 100, Kirigami.Theme.negativeTextColor, scene.totalText(24 * 1100000000) + " of " + scene.totalText(100 * scene.gib) + " (120 %)")
        },
        {
            name: "untracked interface",
            apply: () => {
                view.usage = scene.usageOf("ok", scene.usageSummaryOf("2026-08-20", ["docker0", "eth0"]), {});
            },
            check: () => scene.usageProblem("untracked", ["Today", "vnstat does not track docker0"], [])
        },
        {
            name: "outdated data",
            apply: () => {
                view.usage = scene.usageOf("ok", scene.usageSummaryOf("2026-08-20", ["eth0"]), { lastUpdated: "2026-10-20T18:00", outdated: true });
            },
            check: () => scene.usageProblem("outdated", ["Today", scene.outdatedText], [])
        },
        {
            name: "vnstat missing",
            apply: () => {
                view.usage = scene.usageOf("missing", null, {});
            },
            check: () => scene.usageProblem("missing", [scene.missingText, "vnstat website"], ["Today", "vnstat last updated"])
        },
        {
            name: "vnstat unsupported",
            apply: () => {
                view.usage = scene.usageOf("unsupported", null, {});
            },
            check: () => scene.usageProblem("unsupported", ["This vnstat version is not supported."], ["Today", "vnstat website"])
        },
        {
            name: "vnstat failed",
            apply: () => {
                view.usage = scene.usageOf("error", null, { detail: "boom2" });
            },
            check: () => scene.usageProblem("error", ["Reading vnstat failed: boom2"], ["Today"])
        },
        {
            name: "everything in the usage section",
            apply: () => {
                stub.errorCode = "source-failed";
                view.usage = scene.usageOf("ok", scene.usageSummaryOf("2026-10-05", ["docker0", "eth0"]), {
                    cap: scene.capOf(85.5, 1),
                    lastUpdated: "2026-10-20T18:00",
                    outdated: true
                });
            },
            check: () => scene.usageProblem("full usage", ["Today", "This period (incomplete)", scene.outdatedText, "vnstat does not track docker0", "Reading network data failed: boom"], [])
        },
        {
            name: "preferred size with the usage section",
            apply: () => {},
            check: () => view.height >= view.Layout.minimumHeight ? scene.layoutProblem("preferred with usage") : "preferred with usage: the popup is " + view.height + " px high, below its minimum " + view.Layout.minimumHeight
        },
        {
            name: "minimum size with the usage section",
            apply: () => {
                const problem = scene.minimumProblem("minimum with usage");
                if (problem !== "") {
                    scene.fail(problem);
                }
            },
            check: () => ""
        },
        {
            // The hints wrap into more lines at the narrower width, which
            // raises the minimum; Plasma follows it, so the scene does too.
            name: "minimum size with the usage section after wrapping",
            apply: () => {
                view.height = view.Layout.minimumHeight;
            },
            check: () => {
                if (view.height !== view.Layout.minimumHeight) {
                    return "minimum with usage: the minimum moved again to " + view.Layout.minimumHeight + " at " + view.height;
                }
                return scene.layoutProblem("minimum with usage");
            }
        },
        {
            name: "back to the preferred size with usage",
            apply: () => {
                stub.errorCode = "";
                view.width = Qt.binding(() => view.Layout.preferredWidth);
                view.height = Qt.binding(() => view.Layout.preferredHeight);
            },
            check: () => scene.layoutProblem("restore with usage")
        },
        {
            name: "usage while inactive",
            apply: () => {
                scene.before = {
                    usage: view.shown.usage,
                    text: scene.shownTexts(view, []).join("|")
                };
                view.active = false;
                view.usage = scene.usageOf("error", null, { detail: "late" });
            },
            check: () => {
                if (view.shown.usage !== scene.before.usage) {
                    return "usage inactive: shown.usage changed while inactive";
                }
                const now = scene.shownTexts(view, []).join("|");
                return now === scene.before.text ? "" : "usage inactive: the displayed text changed while inactive: " + now;
            }
        },
        {
            name: "usage after activation",
            apply: () => {
                scene.usageRequests = 0;
                view.active = true;
            },
            check: () => {
                if (scene.usageRequests !== 1) {
                    return "usage active: usageRefreshRequested was sent " + scene.usageRequests + " times, expected 1";
                }
                return scene.usageProblem("usage active", ["Reading vnstat failed: late"], []);
            }
        },
        {
            name: "usage disabled again",
            apply: () => {
                view.usage = scene.usageOf("disabled", null, {});
            },
            check: () => {
                if (view.usagePanel.visible) {
                    return "usage disabled again: the section is visible";
                }
                if (view.Layout.minimumHeight !== scene.minimumWithoutUsage) {
                    return "usage disabled again: the minimum height is " + view.Layout.minimumHeight + ", expected " + scene.minimumWithoutUsage;
                }
                return scene.textProblem("usage disabled again", [], ["Today", "vnstat"]);
            }
        }
    ]

    property var before: ({})
    readonly property var allSteps: scene.steps.concat(scene.usageSteps)

    // "" when the view, sized to its own minimum, keeps the graph and the list
    // at their minimum and the footer completely inside, nothing overlapping.
    function minimumProblem(where: string): string {
        const unit = Kirigami.Units.gridUnit;
        const graph = view.graphItem;
        if (graph === null || view.Layout.minimumHeight < unit * 24 || view.Layout.minimumWidth < unit * 18) {
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
        if (graph.height < unit * 7 - 0.5) {
            return where + ": the graph is " + graph.height + " px high at the minimum size";
        }
        const tallest = scene.tallestRow();
        if (list.oneRowHeight < tallest - 0.5 || list.height < tallest - 0.5) {
            return where + ": the list is " + list.height + " px high (minimum " + list.oneRowHeight + "), below one full row of " + tallest;
        }
        const usage = view.usagePanel;
        const items = usage.visible ? [graph, usage, list, footer] : [graph, list, footer];
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

    // The implicit height of the tallest row of the list.
    function tallestRow(): real {
        let tallest = 0;
        for (const name of ["eth0", "wlan0", "veth0"]) {
            const row = view.interfaceList.rowFor(name);
            if (row !== null) {
                tallest = Math.max(tallest, row.implicitHeight);
            }
        }
        return tallest;
    }

    function sizeProblem(): string {
        const unit = Kirigami.Units.gridUnit;
        if (view.Layout.minimumWidth < unit * 18 || view.Layout.minimumHeight < unit * 24) {
            return "size: minimum is " + view.Layout.minimumWidth + "x" + view.Layout.minimumHeight + ", expected at least " + unit * 18 + "x" + unit * 24;
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
            if (scene.step >= scene.allSteps.length) {
                stepper.running = false;
                return;
            }
            const current = scene.allSteps[scene.step];
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
        when: scene.step >= scene.allSteps.length && !scene.done

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
        onUsageRefreshRequested: scene.usageRequests++
    }
}
