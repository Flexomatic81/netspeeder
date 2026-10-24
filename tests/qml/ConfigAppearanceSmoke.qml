// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Smoke scene for ConfigAppearance and its threshold editor, in plain qml6
// (English fallback for the translation helpers). Checks that
//   - the page starts with the defaults and the controls show them
//   - the symbol fields are active only for the style "custom", the direction
//     colours only for "direction" and the level editor only for "thresholds"
//   - the editor shows the default levels, adds up to six, removes any but
//     the first and always writes valid JSON, also after a broken setting
//   - a level that is no whole number of a larger unit stays exact
//   - no number or unit change can push a level out of range and lose it
//   - a chosen colour is written as #rrggbb without alpha, and only when the
//     dialog is accepted
//   - the values keep their types

import QtQuick
import "../../package/contents/ui/config"
import "../../package/contents/code/appearance.mjs" as Appearance

Item {
    id: scene

    width: 800
    height: 1000

    readonly property string defaultLevels: Appearance.serializeThresholds(Appearance.DEFAULT_THRESHOLDS)
    readonly property int mib: 1048576

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

    // The saved levels as a list; the setting must always be valid JSON in
    // its serialized form.
    function saved(what) {
        const text = page.cfg_colorThresholds;
        scene.expect(what + ": setting is serialized", Appearance.serializeThresholds(text), text);
        return JSON.parse(text);
    }

    function mins(list) {
        return list.map(level => level.min).join(",");
    }

    function row(index) {
        return editor.row(index);
    }

    // A choice of the user in a unit list.
    function pickUnit(index, unit) {
        const box = scene.row(index).unitBox;
        box.currentIndex = unit;
        box.activated(unit);
    }

    // A number typed by the user and committed.
    function typeNumber(index, value) {
        const box = scene.row(index).numberBox;
        box.value = value;
        box.valueModified();
    }

    function checkStart() {
        scene.expect("font at start", fontBox.currentValue, "");
        scene.expect("font list has the theme entry first", fontBox.options[0].value, "");
        scene.expect("bold at start", boldBox.checked, false);
        scene.expect("scale at start", scaleBox.value, 100);
        scene.expect("scale range", scaleBox.from + "-" + scaleBox.to, "50-200");
        scene.expect("scale text", scaleBox.textFromValue(120, Qt.locale("en_US")), "120 %");
        scene.expect("icon style at start", iconBox.currentValue, "arrows");
        scene.expect("down symbol text", downField.text, "↓");
        scene.expect("up symbol text", upField.text, "↑");
        scene.expect("down symbol disabled", downField.enabled, false);
        scene.expect("up symbol disabled", upField.enabled, false);
        scene.expect("color mode at start", colorModeBox.currentValue, "theme");
        scene.expect("download colour disabled", downloadButton.enabled, false);
        scene.expect("upload colour disabled", uploadButton.enabled, false);
        scene.expect("download theme button disabled", downloadThemeButton.enabled, false);
        scene.expect("editor disabled", editor.enabled, false);
        scene.expect("colour units at start", colorUnitsBox.checked, false);
        scene.expect("fixed width at start", fixedWidthBox.checked, true);
        scene.expect("sparkline at start", sparklineBox.currentValue, "off");
        scene.expect("default rows", editor.rowCount, 4);
        scene.expect("first row not removable", scene.row(0).removeButton.enabled, false);
        scene.expect("first row number locked", scene.row(0).numberBox.enabled, false);
        scene.expect("second row number", scene.row(1).numberBox.value, 1);
        scene.expect("second row unit", scene.row(1).unitBox.currentValue, 2);
        scene.expect("fourth row number", scene.row(3).numberBox.value, 100);
        scene.expect("no write at start", page.cfg_colorThresholds, scene.defaultLevels);
    }

    function checkTypes() {
        const kinds = {
            fontFamily: "string", fontBold: "boolean", fontScale: "number", iconStyle: "string",
            customDownIcon: "string", customUpIcon: "string", colorMode: "string",
            downloadColor: "string", uploadColor: "string", colorThresholds: "string",
            colorUnits: "boolean", fixedWidth: "boolean", sparkline: "string"
        };
        for (const name in kinds) {
            scene.expect(name + " type", typeof page["cfg_" + name], kinds[name]);
        }
        scene.expect("scale is whole", Number.isInteger(page.cfg_fontScale), true);
    }

    // One check per timer tick, so that every change has been delivered
    // through the event loop the way it is in the settings dialog.
    function runStep() {
        let list;
        switch (scene.step) {
        case 0:
            // The page holds no values of its own: Plasma fills the cfg_
            // properties. Set the defaults of main.xml the way it does.
            page.cfg_fontFamily = "";
            page.cfg_fontBold = false;
            page.cfg_fontScale = 100;
            page.cfg_iconStyle = "arrows";
            page.cfg_customDownIcon = "↓";
            page.cfg_customUpIcon = "↑";
            page.cfg_colorMode = "theme";
            page.cfg_downloadColor = "";
            page.cfg_uploadColor = "";
            page.cfg_colorThresholds = scene.defaultLevels;
            page.cfg_colorUnits = false;
            page.cfg_fixedWidth = true;
            page.cfg_sparkline = "off";
            break;
        case 1:
            scene.checkStart();
            page.cfg_iconStyle = "custom";
            page.cfg_colorMode = "direction";
            break;
        case 2:
            scene.expect("icon style custom", iconBox.currentValue, "custom");
            scene.expect("down symbol enabled", downField.enabled, true);
            scene.expect("up symbol enabled", upField.enabled, true);
            scene.expect("symbol length", downField.maximumLength, 3);
            scene.expect("download colour enabled", downloadButton.enabled, true);
            scene.expect("upload colour enabled", uploadButton.enabled, true);
            scene.expect("download theme button enabled", downloadThemeButton.enabled, true);
            scene.expect("editor disabled for direction", editor.enabled, false);
            downField.text = "▼";
            downField.textEdited();
            // The dialog accepted a half transparent colour.
            downloadButton.accepted(Qt.rgba(0.5, 0, 1, 0.3));
            // The dialog shows a colour, but the user cancels: no accepted.
            uploadButton.color = "#123456";
            break;
        case 3:
            scene.expect("down symbol written", page.cfg_customDownIcon, "▼");
            scene.expect("download colour without alpha", page.cfg_downloadColor, "#8000ff");
            scene.expect("cancel leaves upload colour", page.cfg_uploadColor, "");
            downloadThemeButton.clicked();
            page.cfg_colorMode = "thresholds";
            break;
        case 4:
            scene.expect("download back to theme", page.cfg_downloadColor, "");
            scene.expect("download colour disabled for thresholds", downloadButton.enabled, false);
            scene.expect("editor enabled", editor.enabled, true);
            scene.expect("second row removable", scene.row(1).removeButton.enabled, true);
            scene.expect("first row still not removable", scene.row(0).removeButton.enabled, false);
            scene.expect("first row number still locked", scene.row(0).numberBox.enabled, false);
            scene.expect("add enabled", editor.addButton.enabled, true);
            editor.addButton.clicked();
            break;
        case 5:
            scene.expect("rows after one add", editor.rowCount, 5);
            scene.expect("saved after one add", scene.saved("one add").length, 5);
            editor.addButton.clicked();
            break;
        case 6:
            scene.expect("rows after two adds", editor.rowCount, 6);
            scene.expect("saved after two adds", scene.saved("two adds").length, 6);
            scene.expect("add disabled at six", editor.addButton.enabled, false);
            page.cfg_colorThresholds = scene.defaultLevels;
            break;
        case 7:
            scene.expect("rows after reset", editor.rowCount, 4);
            scene.expect("add enabled again", editor.addButton.enabled, true);
            scene.row(1).removeButton.clicked();
            break;
        case 8:
            list = scene.saved("remove");
            scene.expect("remove writes three levels", page.cfg_colorThresholds,
                '[{"min":0,"color":""},{"min":10485760,"color":"#f67400"},{"min":104857600,"color":"#da4453"}]');
            scene.expect("rows after remove", editor.rowCount, 3);
            scene.expect("first row still locked", scene.row(0).removeButton.enabled, false);
            page.cfg_colorThresholds = "kaputt";
            break;
        case 9:
            scene.expect("broken setting shows defaults", editor.rowCount, 4);
            scene.expect("broken setting not written yet", page.cfg_colorThresholds, "kaputt");
            scene.row(3).themeButton.clicked();
            break;
        case 10:
            list = scene.saved("after broken");
            scene.expect("first edit after broken", page.cfg_colorThresholds,
                '[{"min":0,"color":""},{"min":1048576,"color":"#1d99f3"},{"min":10485760,"color":"#f67400"},{"min":104857600,"color":""}]');
            page.cfg_colorThresholds = '[{"min":0,"color":""},{"min":1048577,"color":"#112233"},{"min":10485760,"color":"#f67400"}]';
            break;
        case 11:
            scene.expect("odd level number", scene.row(1).numberBox.value, 1048577);
            scene.expect("odd level unit", scene.row(1).unitBox.currentValue, 0);
            // A colour accepted with alpha in another row.
            scene.row(2).colorButton.accepted(Qt.rgba(0, 1, 0, 0.5));
            break;
        case 12:
            scene.expect("odd level kept exactly", page.cfg_colorThresholds,
                '[{"min":0,"color":""},{"min":1048577,"color":"#112233"},{"min":10485760,"color":"#00ff00"}]');
            // A cancelled dialog in a row changes nothing.
            scene.row(2).colorButton.color = "#abcdef";
            break;
        case 13:
            scene.expect("cancel in a row", page.cfg_colorThresholds,
                '[{"min":0,"color":""},{"min":1048577,"color":"#112233"},{"min":10485760,"color":"#00ff00"}]');
            page.cfg_colorThresholds = scene.defaultLevels;
            break;
        case 14:
            // 1 MiB/s in GiB/s is 1 GiB/s; 2048 GiB/s is beyond the limit.
            scene.pickUnit(1, 3);
            break;
        case 15:
            // The list is sorted again: the GiB level is now the last row.
            scene.expect("rows after switch to GiB", editor.rowCount, 4);
            scene.expect("saved after switch to GiB", scene.mins(scene.saved("GiB")), "0,10485760,104857600," + 1024 * scene.mib);
            scene.expect("GiB row unit", scene.row(3).unitBox.currentValue, 3);
            scene.expect("GiB row limit", scene.row(3).numberBox.to, 1);
            scene.expect("MiB row limit", scene.row(2).numberBox.to, 2047);
            scene.typeNumber(3, 2048);
            break;
        case 16:
            scene.expect("rows after 2048 GiB", editor.rowCount, 4);
            scene.expect("2048 GiB set to the limit", scene.row(3).numberBox.value, 1);
            scene.expect("saved after 2048 GiB", scene.mins(scene.saved("2048 GiB")), "0,10485760,104857600," + 1024 * scene.mib);
            page.cfg_colorThresholds = scene.defaultLevels;
            break;
        case 17:
            scene.expect("rows after second reset", editor.rowCount, 4);
            break;
        case 18:
            // 3000 MiB/s is beyond the MiB/s limit already.
            scene.typeNumber(2, 3000);
            break;
        case 19:
            scene.expect("rows after 3000 MiB", editor.rowCount, 4);
            // Sorted again: the 2047 MiB level is now the last row.
            scene.expect("3000 MiB set to the limit", scene.row(3).numberBox.value, 2047);
            scene.expect("saved after 3000 MiB", scene.mins(scene.saved("3000 MiB")), "0,1048576,104857600," + 2047 * scene.mib);
            // 2047 MiB/s switched to GiB/s would be 2047 GiB/s.
            scene.pickUnit(3, 3);
            break;
        case 20:
            scene.expect("rows after switch to GiB", editor.rowCount, 4);
            scene.expect("switch set to the limit", scene.row(3).numberBox.value, 1);
            scene.expect("switch unit", scene.row(3).unitBox.currentValue, 3);
            scene.expect("saved after switch", scene.mins(scene.saved("switch")), "0,1048576,104857600," + 1024 * scene.mib);
            // 100 MiB/s switched to GiB/s would be 1 GiB/s, which the last
            // level has, and there is no free GiB/s value above it.
            scene.pickUnit(2, 3);
            break;
        case 21:
            scene.expect("rows after blocked switch", editor.rowCount, 4);
            scene.expect("blocked switch keeps the unit", scene.row(2).unitBox.currentValue, 2);
            scene.expect("blocked switch keeps the number", scene.row(2).numberBox.value, 100);
            scene.expect("saved after blocked switch", scene.mins(scene.saved("blocked")), "0,1048576,104857600," + 1024 * scene.mib);
            page.cfg_colorThresholds = scene.defaultLevels;
            break;
        case 22:
            // Arrows up from 1 MiB/s: 9 MiB/s first, then the step onto the
            // 10 MiB/s level jumps over it.
            scene.typeNumber(1, 9);
            break;
        case 23:
            scene.expect("saved at 9 MiB", scene.mins(scene.saved("9 MiB")), "0," + 9 * scene.mib + ",10485760,104857600");
            scene.row(1).numberBox.increase();
            scene.row(1).numberBox.valueModified();
            break;
        case 24:
            scene.expect("rows after arrow onto a level", editor.rowCount, 4);
            scene.expect("arrow onto a level keeps both", page.cfg_colorThresholds,
                '[{"min":0,"color":""},{"min":10485760,"color":"#f67400"},{"min":11534336,"color":"#1d99f3"},{"min":104857600,"color":"#da4453"}]');
            scene.expect("jumped row shows its number", scene.row(2).numberBox.value, 11);
            // A number beyond the unit's limit, past the box's own range check.
            editor.setAmount(1, 5000);
            break;
        case 25:
            scene.expect("rows after 5000 MiB", editor.rowCount, 4);
            scene.expect("5000 MiB set to the limit", scene.mins(scene.saved("5000 MiB")), "0,11534336,104857600," + 2047 * scene.mib);
            page.cfg_fontFamily = "No Such Font 4711";
            break;
        case 26:
            scene.expect("missing font shown", fontBox.currentText, "No Such Font 4711 (not installed)");
            scene.expect("missing font value", fontBox.currentValue, "No Such Font 4711");
            scene.expect("missing font kept", page.cfg_fontFamily, "No Such Font 4711");
            scene.expect("theme font still first", fontBox.options[0].value, "");
            scene.checkTypes();
            if (scene.failures.length === 0) {
                scene.finish(true, "SMOKE OK config appearance");
            } else {
                scene.finish(false, "SMOKE FAIL config appearance: " + scene.failures.join("; "));
            }
            return;
        }
        scene.step++;
        stepTimer.restart();
    }

    ConfigAppearance {
        id: page

        anchors.fill: parent
    }

    // The controls of the page, by id through the page.
    readonly property var fontBox: page.fontBox
    readonly property var boldBox: page.boldBox
    readonly property var scaleBox: page.scaleBox
    readonly property var iconBox: page.iconBox
    readonly property var downField: page.downField
    readonly property var upField: page.upField
    readonly property var colorModeBox: page.colorModeBox
    readonly property var downloadButton: page.downloadButton
    readonly property var uploadButton: page.uploadButton
    readonly property var downloadThemeButton: page.downloadThemeButton
    readonly property var editor: page.editor
    readonly property var colorUnitsBox: page.colorUnitsBox
    readonly property var fixedWidthBox: page.fixedWidthBox
    readonly property var sparklineBox: page.sparklineBox

    Timer {
        id: stepTimer

        interval: 200
        running: true
        onTriggered: scene.runStep()
    }

    Timer {
        interval: 15000
        running: true
        onTriggered: scene.finish(false, "SMOKE FAIL config appearance: timeout at step " + scene.step)
    }
}
