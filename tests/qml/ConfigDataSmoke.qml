// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Smoke scene for ConfigData, in plain qml6 (English fallback for the
// translation helpers). The page runs its own provider on the real sensors.
// Checks that the interface rows follow the saved selection: names in the
// order of compareNames, a selected interface that does not exist shown as
// "not available" only as long as it is selected, and rows that stay keeping
// the very same delegate object (a rebuilt row would lose clicks and focus).

import QtQuick
import "../../package/contents/ui/config"
import "../../package/contents/code/selection.mjs" as Selection

Item {
    id: scene

    width: 600
    height: 800

    // Name of a real interface on the machine (the first listed one the
    // page knows, taken once the provider has delivered) and one that
    // cannot exist.
    property string real: ""
    readonly property string ghost: "ghost0"

    property var failures: []
    property var kept: null
    property int step: 0
    property bool done: false

    function finish(ok, message) {
        if (scene.done) {
            return;
        }
        scene.done = true;
        console.log(message);
        Qt.exit(ok ? 0 : 1);
    }

    function expect(what, actual, expected) {
        if (actual !== expected) {
            const next = scene.failures.slice();
            next.push(what + ": got " + JSON.stringify(actual) + ", expected " + JSON.stringify(expected));
            scene.failures = next;
        }
    }

    // Every row delegate below `item`, in visual order.
    function collectRows(item, rows) {
        for (let i = 0; i < item.children.length; i++) {
            const child = item.children[i];
            if (child.interfaceName !== undefined && child.kindText !== undefined) {
                rows.push(child);
            } else {
                scene.collectRows(child, rows);
            }
        }
    }

    function rows() {
        const found = [];
        scene.collectRows(page, found);
        return found;
    }

    function names(list) {
        return list.map(row => row.interfaceName);
    }

    // Name of the first listed row that is a real interface, or "".
    function firstKnown() {
        const list = scene.rows();
        for (let i = 0; i < list.length; i++) {
            if (list[i].known === true) {
                return list[i].interfaceName;
            }
        }
        return "";
    }

    function rowFor(name) {
        const list = scene.rows();
        for (let i = 0; i < list.length; i++) {
            if (list[i].interfaceName === name) {
                return list[i];
            }
        }
        return null;
    }

    // The rows must be exactly the real interfaces plus the selected ones
    // that do not exist, sorted; checked against what the page itself lists.
    function checkRows(label, selected) {
        const list = scene.rows();
        const shown = scene.names(list);
        const sorted = shown.slice().sort(Selection.compareNames);
        scene.expect(label + ": rows sorted", shown.join(","), sorted.join(","));
        scene.expect(label + ": no duplicate rows", new Set(shown).size, shown.length);
        scene.expect(label + ": real interface listed", shown.indexOf(scene.real) >= 0, true);
        const ghostRow = scene.rowFor(scene.ghost);
        const wantGhost = selected.indexOf(scene.ghost) >= 0;
        scene.expect(label + ": ghost row present", ghostRow !== null, wantGhost);
        if (ghostRow !== null) {
            scene.expect(label + ": ghost row text", ghostRow.kindText, "not available");
        }
        const realRow = scene.rowFor(scene.real);
        scene.expect(label + ": real row known", realRow !== null && realRow.known, true);
        scene.expect(label + ": real row checked", realRow !== null && realRow.children[0].checked,
            selected.indexOf(scene.real) >= 0);
    }

    readonly property string waitingText: "Waiting for network data…"
    readonly property string point: Qt.locale().decimalPoint

    // Whether a visible item below the page shows exactly `text`.
    function textShown(text) {
        const stack = [page];
        while (stack.length > 0) {
            const item = stack.pop();
            if (item.text === text && item.visible) {
                return true;
            }
            for (let i = 0; i < item.children.length; i++) {
                stack.push(item.children[i]);
            }
        }
        return false;
    }

    // The kind and speed line of the row of an interface.
    function rateText(name) {
        const row = scene.rowFor(name);
        return row === null ? "no row" : row.children[1].text;
    }

    function runStep() {
        switch (scene.step) {
        case 0:
            if (scene.rows().length === 0) {
                // The provider has not delivered yet; try again next tick.
                stepTimer.restart();
                return;
            }
            scene.real = scene.firstKnown();
            if (scene.real === "") {
                scene.finish(false, "SMOKE FAIL configdata: no real interface listed");
                return;
            }
            scene.expect("manual before", page.manual, false);
            page.cfg_interfaceSelection = "manual";
            break;
        case 1:
            scene.expect("manual after", page.manual, true);
            scene.checkRows("empty selection", []);
            scene.kept = scene.rowFor(scene.real);
            page.cfg_selectedInterfaces = [scene.real];
            break;
        case 2:
            scene.checkRows("real selected", [scene.real]);
            scene.expect("real delegate kept (1)", scene.rowFor(scene.real) === scene.kept, true);
            page.cfg_selectedInterfaces = [scene.real, scene.ghost];
            break;
        case 3:
            scene.checkRows("real and ghost", [scene.real, scene.ghost]);
            scene.expect("real delegate kept (2)", scene.rowFor(scene.real) === scene.kept, true);
            page.cfg_selectedInterfaces = [scene.ghost];
            break;
        case 4:
            scene.checkRows("ghost only", [scene.ghost]);
            scene.expect("real delegate kept (3)", scene.rowFor(scene.real) === scene.kept, true);
            page.cfg_selectedInterfaces = [];
            break;
        case 5:
            scene.checkRows("cleared", []);
            scene.expect("real delegate kept (4)", scene.rowFor(scene.real) === scene.kept, true);
            // From here on the page reads a stub provider and fixed options.
            stub.hasData = false;
            page.providerOverride = stub;
            break;
        case 6:
            scene.expect("waiting without error", scene.textShown(scene.waitingText), true);
            stub.hasData = true;
            stub.interfaces = [{ name: "eth0", label: "", kind: "physical", down: 2000, up: 0 }];
            page.formatOptions = { unitSystem: "si" };
            break;
        case 7:
            scene.expect("si rate", scene.rateText("eth0"), "physical – ↓ 2" + scene.point + "0 kB/s   ↑ 0 B/s");
            page.formatOptions = { unitSystem: "iec" };
            break;
        case 8:
            scene.expect("iec rate", scene.rateText("eth0"), "physical – ↓ 2" + scene.point + "0 KiB/s   ↑ 0 B/s");
            stub.interfaces = [];
            stub.hasData = false;
            stub.errorCode = "source-failed";
            stub.errorDetail = "boom";
            break;
        case 9:
            scene.expect("no waiting text with an error", scene.textShown(scene.waitingText), false);
            scene.expect("error shown", scene.textShown("Reading network data failed: boom"), true);
            if (scene.failures.length === 0) {
                scene.finish(true, "SMOKE OK configdata");
            } else {
                scene.finish(false, "SMOKE FAIL configdata: " + scene.failures.join("; "));
            }
            return;
        }
        scene.step++;
        stepTimer.restart();
    }

    QtObject {
        id: stub

        property bool hasData: false
        property var interfaces: []
        property string errorCode: ""
        property string errorDetail: ""
        property string activeSource: "proc"
    }

    ConfigData {
        id: page

        anchors.fill: parent
    }

    Timer {
        id: stepTimer

        interval: 300
        running: true
        onTriggered: scene.runStep()
    }

    Timer {
        interval: 15000
        running: true
        onTriggered: scene.finish(false, "SMOKE FAIL configdata: timeout at step " + scene.step
            + " (" + scene.names(scene.rows()).join(",") + ")")
    }
}
