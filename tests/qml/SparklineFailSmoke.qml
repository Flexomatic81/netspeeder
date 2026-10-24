// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Smoke scene for the load isolation of the mini chart: when the chart cannot
// be loaded (BrokenGraph.qml imports a missing module, as without Qt Quick
// Charts), the values stay shown and the view is as wide as without a chart.
// It cannot see QML warnings itself: scripts/smoke.sh checks the output of
// qml6 and allows only the load error of the missing module.

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../package/contents/ui/compact"
import "../../package/contents/code/format.mjs" as Format

Item {
    id: scene

    width: 600
    height: 200

    property bool done: false

    function finish(ok, message) {
        if (scene.done) {
            return;
        }
        scene.done = true;
        console.log(message);
        Qt.exit(ok ? 0 : 1);
    }

    function fail(message) {
        scene.finish(false, "SMOKE FAIL sparkline failure: " + message);
    }

    // The visible texts below `item`.
    function shownTexts(item, found) {
        for (let i = 0; i < item.children.length; i++) {
            const child = item.children[i];
            if (!child.visible) {
                continue;
            }
            if (child instanceof Text && child.text !== "" && child.width > 0) {
                found.push(child.text);
            }
            scene.shownTexts(child, found);
        }
        return found;
    }

    function check() {
        for (const mode of ["beside", "background"]) {
            const view = mode === "beside" ? broken : brokenBackground;
            const loader = view.sparkLoaderItem;
            if (loader.status !== Loader.Error || loader.item !== null) {
                return mode + ": the broken file loaded (status " + loader.status + ")";
            }
            if (Math.abs(view.implicitWidth - plain.implicitWidth) > 0.01) {
                return mode + ": width " + view.implicitWidth + " instead of " + plain.implicitWidth;
            }
            const texts = scene.shownTexts(view, []).join("|");
            const wanted = scene.shownTexts(plain, []).join("|");
            if (texts !== wanted || !/\d/.test(texts)) {
                return mode + ": texts '" + texts + "', expected '" + wanted + "'";
            }
        }
        return "";
    }

    Timer {
        interval: 300
        running: true
        onTriggered: {
            const problem = scene.check();
            if (problem !== "") {
                scene.fail(problem);
            } else {
                scene.finish(true, "SMOKE OK sparkline failure");
            }
        }
    }

    QtObject {
        id: stub

        property bool hasData: true
        property real down: 2048
        property real up: 100
        property bool stale: false
    }

    Column {
        spacing: 10

        RowLayout {
            width: 300
            height: 44
            spacing: 0

            CompactRepresentation {
                id: plain

                provider: stub
                formatOptions: Format.DEFAULT_FORMAT
                Layout.fillHeight: true
            }
        }

        RowLayout {
            width: 300
            height: 44
            spacing: 0

            CompactRepresentation {
                id: broken

                provider: stub
                formatOptions: Format.DEFAULT_FORMAT
                sparkline: "beside"
                sparklineSource: Qt.resolvedUrl("BrokenGraph.qml")
                Layout.fillHeight: true
            }
        }

        RowLayout {
            width: 300
            height: 44
            spacing: 0

            CompactRepresentation {
                id: brokenBackground

                provider: stub
                formatOptions: Format.DEFAULT_FORMAT
                sparkline: "background"
                sparklineSource: Qt.resolvedUrl("BrokenGraph.qml")
                Layout.fillHeight: true
            }
        }
    }
}
