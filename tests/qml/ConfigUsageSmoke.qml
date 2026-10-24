// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Smoke scene for ConfigUsage, in plain qml6 (English fallback for the
// translation helpers). It never runs vnstat: the status command is replaced
// by a shell line that fails or reads the hand-built fixture. Checks that
//   - the page starts with the defaults of main.xml
//   - the cap fields are active only with the cap switched on, and every
//     field except the main switch only with usage switched on
//   - the cap is shown in whole GiB (100 as "100 GiB", 1536.4 as 1536, kept
//     as it is until the user enters a value), a grouped entry "1.000 GiB"
//     (de) gives 1000, and a value entered is saved
//   - the status line follows the result of the replaced command
//   - the values keep the type number or bool

import QtQuick
import "../../package/contents/ui/config"

Item {
    id: scene

    width: 600
    height: 600

    property var failures: []
    property int step: 0
    property bool done: false
    readonly property string v2: Qt.resolvedUrl("../fixtures/vnstat-v2.json").toString().replace("file://", "")

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
            // Plasma fills the cfg_ properties; set the defaults of main.xml.
            page.cfg_usageEnabled = true;
            page.cfg_dataCapEnabled = false;
            page.cfg_dataCapGiB = 100;
            page.cfg_billingDay = 1;
            page.cfg_capWarnPercent = 80;
            page.cfg_capNotify = true;
            break;
        case 1:
            scene.expect("usage switch at start", usageBox.checked, true);
            scene.expect("cap switch at start", capBox.checked, false);
            scene.expect("cap size at start", sizeBox.value, 100);
            scene.expect("billing day at start", dayBox.value, 1);
            scene.expect("warn level at start", warnBox.value, 80);
            scene.expect("notify at start", notifyBox.checked, true);
            scene.expect("size text", sizeBox.textFromValue(100, Qt.locale("en_US")), "100 GiB");
            scene.expect("warn text", warnBox.textFromValue(80, Qt.locale("en_US")), "80 %");
            scene.expect("cap switch active", capBox.enabled, true);
            scene.expect("billing day active", dayBox.enabled, true);
            scene.expect("notify active", notifyBox.enabled, true);
            scene.expect("size inactive without cap", sizeBox.enabled, false);
            scene.expect("warn inactive without cap", warnBox.enabled, false);
            scene.expect("size range", sizeBox.from + "-" + sizeBox.to, "1-100000");
            scene.expect("day range", dayBox.from + "-" + dayBox.to, "1-28");
            scene.expect("warn range", warnBox.from + "-" + warnBox.to, "1-99");
            page.cfg_dataCapEnabled = true;
            break;
        case 2:
            scene.expect("size active with cap", sizeBox.enabled, true);
            scene.expect("warn active with cap", warnBox.enabled, true);
            page.cfg_usageEnabled = false;
            break;
        case 3:
            scene.expect("usage switch stays active", usageBox.enabled, true);
            scene.expect("cap switch inactive without usage", capBox.enabled, false);
            scene.expect("size inactive without usage", sizeBox.enabled, false);
            scene.expect("billing day inactive without usage", dayBox.enabled, false);
            scene.expect("warn inactive without usage", warnBox.enabled, false);
            scene.expect("notify inactive without usage", notifyBox.enabled, false);
            page.cfg_usageEnabled = true;
            page.cfg_dataCapGiB = 1536.4;
            break;
        case 4:
            scene.expect("active again", sizeBox.enabled, true);
            scene.expect("fraction shown rounded", sizeBox.value, 1536);
            scene.expect("fraction kept without input", page.cfg_dataCapGiB, 1536.4);
            sizeBox.value = 250;
            sizeBox.valueModified();
            dayBox.value = 15;
            dayBox.valueModified();
            warnBox.value = 90;
            warnBox.valueModified();
            break;
        case 5:
            scene.expect("size saved", page.cfg_dataCapGiB, 250);
            scene.expect("day saved", page.cfg_billingDay, 15);
            scene.expect("warn saved", page.cfg_capWarnPercent, 90);
            sizeBox.value = 0;
            scene.expect("size clamped low", sizeBox.value, 1);
            sizeBox.value = 999999;
            scene.expect("size clamped high", sizeBox.value, 100000);
            scene.expect("grouped input (de)", sizeBox.valueFromText("1.000 GiB", Qt.locale("de_DE")), 1000);
            scene.expect("grouped input (en)", sizeBox.valueFromText("1,000 GiB", Qt.locale("en_US")), 1000);
            scene.expect("garbage keeps the value", sizeBox.valueFromText("abc", Qt.locale("en_US")), sizeBox.value);
            scene.expect("percent read back", warnBox.valueFromText(warnBox.textFromValue(75, Qt.locale()), Qt.locale()), 75);
            scene.expect("size read back", sizeBox.valueFromText(sizeBox.textFromValue(1234, Qt.locale()), Qt.locale()), 1234);
            break;
        case 6:
            // Waits for the first run of the replaced command, which the page
            // started when it opened; it reported exit 127.
            if (usageSource.status === "loading" || usageSource.busy) {
                scene.step--;
                break;
            }
            scene.expect("status missing", page.statusText, "vnstat is not installed");
            scene.expect("status label shows it", statusLabel.text, "vnstat is not installed");
            page.statusCommand = "cat '" + scene.v2 + "'";
            usageSource.refresh();
            break;
        case 7:
            if (usageSource.status === "loading" || usageSource.busy) {
                scene.step--;
                break;
            }
            scene.expect("status ok", page.statusText, "vnstat found");
            page.statusCommand = "sh -c 'echo boom >&2; exit 3'";
            usageSource.refresh();
            break;
        case 8:
            if (usageSource.busy) {
                scene.step--;
                break;
            }
            scene.expect("status error", page.statusText, "Reading vnstat failed: boom");
            page.statusCommand = "printf '{\"vnstatversion\":\"1.18\"}'";
            usageSource.refresh();
            break;
        case 9:
            if (usageSource.busy) {
                scene.step--;
                break;
            }
            scene.expect("status unsupported or error", page.statusText.length > 0, true);
            scene.expect("usage type", typeof page.cfg_usageEnabled, "boolean");
            scene.expect("cap type", typeof page.cfg_dataCapEnabled, "boolean");
            scene.expect("notify type", typeof page.cfg_capNotify, "boolean");
            scene.expect("size type", typeof page.cfg_dataCapGiB, "number");
            scene.expect("day type", typeof page.cfg_billingDay, "number");
            scene.expect("warn type", typeof page.cfg_capWarnPercent, "number");
            if (scene.failures.length === 0) {
                scene.finish(true, "SMOKE OK config usage");
            } else {
                scene.finish(false, "SMOKE FAIL config usage: " + scene.failures.join("; "));
            }
            return;
        }
        scene.step++;
        stepTimer.restart();
    }

    ConfigUsage {
        id: page

        anchors.fill: parent
        statusCommand: "exit 127"
    }

    // The controls of the page, by id through the page.
    readonly property var usageBox: page.usageBox
    readonly property var capBox: page.capBox
    readonly property var sizeBox: page.sizeBox
    readonly property var dayBox: page.dayBox
    readonly property var warnBox: page.warnBox
    readonly property var notifyBox: page.notifyBox
    readonly property var statusLabel: page.statusLabel
    readonly property var usageSource: page.usageSource

    Timer {
        id: stepTimer

        interval: 200
        running: true
        onTriggered: scene.runStep()
    }

    Timer {
        interval: 15000
        running: true
        onTriggered: scene.finish(false, "SMOKE FAIL config usage: timeout at step " + scene.step)
    }
}
