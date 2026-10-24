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

    // Name of a real interface on the machine and one that cannot exist.
    readonly property string real: "enp7s0"
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

    function runStep() {
        switch (scene.step) {
        case 0:
            if (scene.rows().length === 0) {
                // The provider has not delivered yet; try again next tick.
                stepTimer.restart();
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
