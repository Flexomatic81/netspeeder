// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Smoke scene for ConfigBehavior, in plain qml6 (English fallback for the
// translation helpers). Checks that
//   - the page starts with the defaults and the choice lists show them
//   - the warning appears when neither click opens the popup and goes away
//     again when one does
//   - the application field is active only for the kind "app", the command
//     field only for "command"
//   - the values keep the type string

import QtQuick
import "../../package/contents/ui/config"

Item {
    id: scene

    width: 600
    height: 600

    property var failures: []
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
            // The page holds no values of its own: Plasma fills the cfg_
            // properties. Set the defaults of main.xml the way it does.
            page.cfg_leftClick = "popup";
            page.cfg_middleClick = "none";
            page.cfg_launchKind = "app";
            page.cfg_launchApp = "org.kde.plasma-systemmonitor";
            page.cfg_launchCommand = "";
            break;
        case 1:
            scene.expect("left box at start", leftBox.currentValue, "popup");
            scene.expect("middle box at start", middleBox.currentValue, "none");
            scene.expect("kind box at start", kindBox.currentValue, "app");
            scene.expect("app text at start", appField.text, "org.kde.plasma-systemmonitor");
            scene.expect("command text at start", commandField.text, "");
            scene.expect("warning at start", warning.visible, false);
            scene.expect("app field enabled for app", appField.enabled, true);
            scene.expect("choose button enabled for app", chooseButton.enabled, true);
            scene.expect("command field disabled for app", commandField.enabled, false);
            page.cfg_leftClick = "launch";
            break;
        case 2:
            scene.expect("left box after change", leftBox.currentValue, "launch");
            scene.expect("warning with launch and none", warning.visible, true);
            page.cfg_middleClick = "popup";
            break;
        case 3:
            scene.expect("warning with launch and popup", warning.visible, false);
            page.cfg_middleClick = "none";
            page.cfg_launchKind = "command";
            break;
        case 4:
            scene.expect("warning again", warning.visible, true);
            scene.expect("kind box after change", kindBox.currentValue, "command");
            scene.expect("app field disabled for command", appField.enabled, false);
            scene.expect("choose button disabled for command", chooseButton.enabled, false);
            scene.expect("command field enabled for command", commandField.enabled, true);
            page.cfg_leftClick = "popup";
            break;
        case 5:
            scene.expect("warning gone", warning.visible, false);
            // Typing writes the setting as a string.
            commandField.text = "konsole -e nethogs";
            commandField.textEdited();
            appField.text = "org.kde.konsole";
            appField.textEdited();
            break;
        case 6:
            scene.expect("command setting", page.cfg_launchCommand, "konsole -e nethogs");
            scene.expect("app setting", page.cfg_launchApp, "org.kde.konsole");
            scene.expect("left type", typeof page.cfg_leftClick, "string");
            scene.expect("middle type", typeof page.cfg_middleClick, "string");
            scene.expect("kind type", typeof page.cfg_launchKind, "string");
            scene.expect("app type", typeof page.cfg_launchApp, "string");
            scene.expect("command type", typeof page.cfg_launchCommand, "string");
            if (scene.failures.length === 0) {
                scene.finish(true, "SMOKE OK config behavior");
            } else {
                scene.finish(false, "SMOKE FAIL config behavior: " + scene.failures.join("; "));
            }
            return;
        }
        scene.step++;
        stepTimer.restart();
    }

    ConfigBehavior {
        id: page

        anchors.fill: parent
    }

    // The controls of the page, by id through the page.
    readonly property var leftBox: page.leftBox
    readonly property var middleBox: page.middleBox
    readonly property var kindBox: page.kindBox
    readonly property var appField: page.appField
    readonly property var commandField: page.commandField
    readonly property var chooseButton: page.chooseButton
    readonly property var warning: page.warning

    Timer {
        id: stepTimer

        interval: 200
        running: true
        onTriggered: scene.runStep()
    }

    Timer {
        interval: 8000
        running: true
        onTriggered: scene.finish(false, "SMOKE FAIL config behavior: timeout at step " + scene.step)
    }
}
