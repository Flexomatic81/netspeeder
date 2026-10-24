// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Smoke scene for the load isolation of the graph: when the graph file cannot
// be loaded (as without Qt Quick Charts), the popup shows a note in its place
// and the header values stay correct.
// It cannot see QML warnings itself: scripts/smoke.sh checks the output of
// qml6 and allows only the load error of the missing file.

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../package/contents/ui/full"
import "../../package/contents/code/format.mjs" as Format
import "../../package/contents/code/history.mjs" as History

Item {
    id: scene

    width: 600
    height: 700

    property bool done: false
    readonly property string note: "The traffic graph is not available because Qt Quick Charts is missing."

    function finish(ok, message) {
        if (scene.done) {
            return;
        }
        scene.done = true;
        console.log(message);
        Qt.exit(ok ? 0 : 1);
    }

    // The visible texts below `item`.
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

    function check() {
        const texts = scene.shownTexts(view, []);
        const down = Format.formatSpeed(2048, Format.DEFAULT_FORMAT);
        const wanted = [scene.note, "↓ " + down.value + " " + down.unit];
        for (const text of wanted) {
            if (texts.indexOf(text) < 0) {
                scene.finish(false, "SMOKE FAIL popup graph: missing '" + text + "' in [" + texts.join(" | ") + "]");
                return;
            }
        }
        if (view.graphItem !== null) {
            scene.finish(false, "SMOKE FAIL popup graph: an item was loaded from the missing file");
            return;
        }
        scene.finish(true, "SMOKE OK popup graph failure");
    }

    Timer {
        interval: 200
        running: true
        onTriggered: scene.check()
    }

    QtObject {
        id: stub

        property bool hasData: true
        property real down: 2048
        property real up: 0
        property bool online: true
        property bool stale: false
        property string activeSource: "sensors"
        property string primaryLabel: ""
        property string primaryIp: ""
        property var interfaces: []
        property var history: History.createHistory(10)
        property string errorCode: ""
        property string errorDetail: ""
        property string fallbackNote: ""
    }

    FullRepresentation {
        id: view

        provider: stub
        formatOptions: Format.DEFAULT_FORMAT
        graphSource: Qt.resolvedUrl("MissingGraph.qml")
        width: Layout.preferredWidth
        height: Layout.preferredHeight
    }
}
