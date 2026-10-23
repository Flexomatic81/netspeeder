// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Smoke scene for ConfigComboBox, in plain qml6 (no Plasma, no i18n). Checks
// that the shown entry follows the bound setting:
//   - at creation, also when the setting equals the first entry (the default
//     case where a binding `currentIndex: indexOfValue(...)` fails) and when it
//     is a later entry
//   - after the setting changes from outside (the "Defaults" button)
//   - a value that is not in the list selects nothing
// and that a choice of the user is reported as `picked` with a value of the
// type of the option (boolean, number, string), never as text or index.

import QtQuick
import "../../package/contents/ui/config"

Item {
    id: scene

    // Stand-ins for the cfg_ properties Plasma puts on a settings page.
    property bool cfg_uploadFirst: false
    property int cfg_decimals: -1
    property string cfg_layout: "columns"

    property var failures: []
    property var pickedBool: []
    property var pickedNumber: []
    property var pickedText: []
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

    // One check per timer tick, so that every change has been delivered
    // through the event loop the way it is in the settings dialog.
    function runStep() {
        switch (scene.step) {
        case 0:
            // Setting equals the first entry.
            scene.expect("bool at start", boolBox.currentIndex, 0);
            scene.expect("number at start (default -1)", numberBox.currentIndex, 0);
            // Setting is a later entry.
            scene.expect("text at start", textBox.currentIndex, 2);
            scene.cfg_uploadFirst = true;
            scene.cfg_decimals = 2;
            scene.cfg_layout = "rows";
            break;
        case 1:
            scene.expect("bool after change", boolBox.currentIndex, 1);
            scene.expect("number after change", numberBox.currentIndex, 3);
            scene.expect("text after change", textBox.currentIndex, 1);
            // Back to the defaults; 0 must not be mistaken for "no value".
            scene.cfg_uploadFirst = false;
            scene.cfg_decimals = 0;
            scene.cfg_layout = "bogus";
            break;
        case 2:
            scene.expect("bool after reset", boolBox.currentIndex, 0);
            scene.expect("number 0", numberBox.currentIndex, 1);
            scene.expect("unknown text", textBox.currentIndex, -1);
            // The user picks the entry at index 0, 2 and 1.
            boolBox.currentIndex = 0;
            boolBox.activated(0);
            numberBox.currentIndex = 2;
            numberBox.activated(2);
            textBox.currentIndex = 1;
            textBox.activated(1);
            break;
        case 3:
            scene.expect("picked bool count", scene.pickedBool.length, 1);
            scene.expect("picked bool", scene.pickedBool[0], false);
            scene.expect("picked bool type", typeof scene.pickedBool[0], "boolean");
            scene.expect("picked number count", scene.pickedNumber.length, 1);
            scene.expect("picked number", scene.pickedNumber[0], 1);
            scene.expect("picked number type", typeof scene.pickedNumber[0], "number");
            scene.expect("picked text count", scene.pickedText.length, 1);
            scene.expect("picked text", scene.pickedText[0], "rows");
            scene.expect("picked text type", typeof scene.pickedText[0], "string");
            // Choosing writes nothing by itself: the cfg_ properties stay
            // until the page assigns them.
            scene.expect("cfg_uploadFirst untouched", scene.cfg_uploadFirst, false);
            scene.expect("cfg_decimals untouched", scene.cfg_decimals, 0);
            if (scene.failures.length === 0) {
                scene.finish(true, "SMOKE OK combobox");
            } else {
                scene.finish(false, "SMOKE FAIL combobox: " + scene.failures.join("; "));
            }
            return;
        }
        scene.step++;
        stepTimer.restart();
    }

    ConfigComboBox {
        id: boolBox

        options: [{ text: "Download first", value: false }, { text: "Upload first", value: true }]
        configValue: scene.cfg_uploadFirst
        onPicked: value => scene.pickedBool = scene.pickedBool.concat([value])
    }

    ConfigComboBox {
        id: numberBox

        y: 40
        options: [{ text: "Automatic", value: -1 }, { text: "0", value: 0 }, { text: "1", value: 1 }, { text: "2", value: 2 }]
        configValue: scene.cfg_decimals
        onPicked: value => scene.pickedNumber = scene.pickedNumber.concat([value])
    }

    ConfigComboBox {
        id: textBox

        y: 80
        options: [{ text: "Automatic", value: "auto" }, { text: "Two rows", value: "rows" }, { text: "Side by side", value: "columns" }]
        configValue: scene.cfg_layout
        onPicked: value => scene.pickedText = scene.pickedText.concat([value])
    }

    Timer {
        id: stepTimer

        interval: 100
        running: true
        onTriggered: scene.runStep()
    }

    Timer {
        interval: 5000
        running: true
        onTriggered: scene.finish(false, "SMOKE FAIL combobox: timeout at step " + scene.step)
    }
}
