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
//   - auto-hide starts at "never" with both idle fields inactive; "idle"
//     activates them
//   - the threshold is shown in whole KiB/s (2048 as 2, 1 MiB/s as 1024,
//     1500 as 1 and kept as 1500 until the user enters a value) and a value
//     entered is saved times 1024
//   - the seconds are limited to 5-3600; the values keep the type number

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
            page.cfg_autoHide = "never";
            page.cfg_idleThreshold = 1024;
            page.cfg_idleSeconds = 30;
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
            scene.expect("auto-hide at start", autoHideBox.currentValue, "never");
            scene.expect("threshold at start", thresholdBox.value, 1);
            scene.expect("seconds at start", secondsBox.value, 30);
            scene.expect("threshold disabled for never", thresholdBox.enabled, false);
            scene.expect("seconds disabled for never", secondsBox.enabled, false);
            scene.expect("threshold range", thresholdBox.from + "-" + thresholdBox.to, "1-1024");
            scene.expect("seconds range", secondsBox.from + "-" + secondsBox.to, "5-3600");
            page.cfg_autoHide = "offline";
            break;
        case 7:
            scene.expect("auto-hide offline", autoHideBox.currentValue, "offline");
            scene.expect("threshold disabled for offline", thresholdBox.enabled, false);
            scene.expect("seconds disabled for offline", secondsBox.enabled, false);
            page.cfg_autoHide = "idle";
            page.cfg_idleThreshold = 2048;
            break;
        case 8:
            scene.expect("auto-hide idle", autoHideBox.currentValue, "idle");
            scene.expect("threshold enabled for idle", thresholdBox.enabled, true);
            scene.expect("seconds enabled for idle", secondsBox.enabled, true);
            scene.expect("2048 shown as 2", thresholdBox.value, 2);
            page.cfg_idleThreshold = 1048576;
            break;
        case 9:
            scene.expect("1 MiB/s shown as 1024", thresholdBox.value, 1024);
            page.cfg_idleThreshold = 1500;
            break;
        case 10:
            scene.expect("1500 shown as 1", thresholdBox.value, 1);
            scene.expect("1500 kept without input", page.cfg_idleThreshold, 1500);
            thresholdBox.value = 4;
            thresholdBox.valueModified();
            secondsBox.value = 120;
            secondsBox.valueModified();
            break;
        case 11:
            scene.expect("input 4 saved as 4096", page.cfg_idleThreshold, 4096);
            scene.expect("seconds saved", page.cfg_idleSeconds, 120);
            secondsBox.value = 1;
            scene.expect("seconds clamped low", secondsBox.value, 5);
            secondsBox.value = 99999;
            scene.expect("seconds clamped high", secondsBox.value, 3600);
            // The displayed text of a value read back must give the value.
            page.cfg_idleThreshold = 1048576;
            page.cfg_idleSeconds = 1500;
            break;
        case 12:
            scene.expect("threshold text read back", thresholdBox.valueFromText(thresholdBox.textFromValue(1024, Qt.locale()), Qt.locale()), 1024);
            scene.expect("seconds text read back", secondsBox.valueFromText(secondsBox.textFromValue(1500, Qt.locale()), Qt.locale()), 1500);
            scene.expect("threshold text with grouping", thresholdBox.valueFromText("1.024 KiB/s", Qt.locale("de_DE")), 1024);
            scene.expect("seconds text with grouping", secondsBox.valueFromText("1,500 s", Qt.locale("en_US")), 1500);
            // Entering a value earlier replaced the binding of the box, so
            // set the value the user would see.
            thresholdBox.value = 1024;
            thresholdBox.contentItem.text = thresholdBox.textFromValue(1024, Qt.locale());
            thresholdBox.valueModified();
            scene.expect("threshold stays at 1024", thresholdBox.value, 1024);
            scene.expect("threshold setting stays", page.cfg_idleThreshold, 1048576);
            scene.expect("auto-hide type", typeof page.cfg_autoHide, "string");
            scene.expect("threshold type", typeof page.cfg_idleThreshold, "number");
            scene.expect("seconds type", typeof page.cfg_idleSeconds, "number");
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
    readonly property var autoHideBox: page.autoHideBox
    readonly property var thresholdBox: page.thresholdBox
    readonly property var secondsBox: page.secondsBox

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
