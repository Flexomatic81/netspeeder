// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Renders the panel view and the popup with the demo data of DemoProvider and
// saves them as PNG files, then quits. Run it through scripts/screenshots.sh:
//
//   qml6 tools/screenshots/Screenshots.qml -- <output directory>
//
// The panel views: two rows at 44 px, one combined value, a vertical panel
// 48 px wide, the colors by speed ("thresholds") and the mini chart behind
// the text, each on the background color of the theme. The popup has its
// preferred size. The text uses the first available of the fonts in demo.mjs;
// the colors come from the current color scheme.
//
// Output: "SCREENSHOT saved <file> <width>x<height>" per image, the chart area
// of the popup as "SCREENSHOT chart popup.png <x> <y> <width> <height> of
// <width> <height>" (for check-images.mjs), and "SCREENSHOTS OK" or
// "SCREENSHOTS FAIL <reason>" at the end.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.quickcharts as Charts
import "../../package/contents/ui/compact"
import "../../package/contents/ui/full"
import "../../package/contents/code/format.mjs" as Format
import "demo.mjs" as Demo

QQC2.ApplicationWindow {
    id: scene

    // The panel thickness and the width of the vertical panel.
    readonly property int panelHeight: 44
    readonly property int verticalWidth: 48
    // Room around the views on their panel background.
    readonly property int padding: 6
    // The text sizes of a stock Plasma at 96 dpi (as in the smoke scenes), so
    // the panel views do not depend on the font settings of this machine.
    readonly property int defaultPx: 13
    readonly property int smallPx: 10
    readonly property string family: Demo.pickFont(Qt.fontFamilies())
    // The output directory: the argument after "--".
    readonly property string outDir: {
        const args = Qt.application.arguments;
        const at = args.indexOf("--");
        return at >= 0 && at + 1 < args.length ? args[at + 1] : "";
    }
    property int next: 0
    property bool done: false
    readonly property var shots: [rowsShot, singleShot, verticalShot, colorsShot, sparklineShot, popupShot]

    width: 1000
    height: 860
    visible: true
    title: "Netspeeder screenshots"
    color: Kirigami.Theme.backgroundColor
    font.family: scene.family

    function finish(ok: bool, message: string) {
        if (scene.done) {
            return;
        }
        scene.done = true;
        console.log(ok ? "SCREENSHOTS OK" : "SCREENSHOTS FAIL " + message);
        Qt.exit(ok ? 0 : 1);
    }

    // The LineChart below `item`; null if there is none.
    function findChart(item: Item): Item {
        for (let i = 0; i < item.children.length; i++) {
            const child = item.children[i];
            if (child instanceof Charts.LineChart) {
                return child;
            }
            const inner = scene.findChart(child);
            if (inner !== null) {
                return inner;
            }
        }
        return null;
    }

    function reportChart(): bool {
        const chart = popup.graphItem === null ? null : scene.findChart(popup.graphItem);
        if (chart === null) {
            return false;
        }
        const pos = chart.mapToItem(popupShot, 0, 0);
        console.log("SCREENSHOT chart popup.png " + pos.x.toFixed(1) + " " + pos.y.toFixed(1) + " " + chart.width.toFixed(1) + " " + chart.height.toFixed(1) + " of " + popupShot.width + " " + popupShot.height);
        return true;
    }

    // Saves the shot `scene.next` and goes on with the following one.
    function grabNext() {
        if (scene.next >= scene.shots.length) {
            scene.finish(true, "");
            return;
        }
        const item = scene.shots[scene.next];
        const name = Demo.SHOTS[scene.next];
        const started = item.grabToImage(result => {
            const file = scene.outDir + "/" + name;
            if (!result.saveToFile(file)) {
                scene.finish(false, "could not write " + name);
                return;
            }
            console.log("SCREENSHOT saved " + name + " " + item.width + "x" + item.height);
            scene.next++;
            scene.grabNext();
        });
        if (!started) {
            scene.finish(false, "could not grab " + name);
        }
    }

    function start() {
        if (scene.outDir === "") {
            scene.finish(false, "no output directory: pass it after --");
        } else if (scene.family === "") {
            scene.finish(false, "none of the fonts " + Demo.DEMO_FONTS.join(", ") + " is installed");
        } else if (!scene.reportChart()) {
            scene.finish(false, "the popup has no chart");
        } else {
            scene.grabNext();
        }
    }

    // A horizontal panel of panelHeight with one panel view.
    component PanelShot: Rectangle {
        id: shot

        property alias view: panelView

        width: host.width + scene.padding * 2
        height: scene.panelHeight
        color: Kirigami.Theme.backgroundColor

        RowLayout {
            id: host

            x: scene.padding
            height: shot.height
            spacing: 0

            CompactRepresentation {
                id: panelView

                provider: demo
                history: demo.history
                formatOptions: Format.DEFAULT_FORMAT
                fontFamily: scene.family
                minReadablePx: scene.smallPx
                baseFontPx: scene.defaultPx
                Layout.fillHeight: true
            }
        }
    }

    DemoProvider {
        id: demo
    }

    Column {
        x: 20
        y: 20
        spacing: 20

        PanelShot {
            id: rowsShot

            view.layoutMode: "rows"
        }

        PanelShot {
            id: singleShot

            view.combined: true
        }

        PanelShot {
            id: colorsShot

            view.layoutMode: "rows"
            view.colorMode: "thresholds"
        }

        PanelShot {
            id: sparklineShot

            view.layoutMode: "rows"
            view.sparkline: "background"
        }

        Rectangle {
            id: verticalShot

            width: scene.verticalWidth
            height: verticalHost.height + scene.padding * 2
            color: Kirigami.Theme.backgroundColor

            ColumnLayout {
                id: verticalHost

                y: scene.padding
                width: verticalShot.width
                spacing: 0

                CompactRepresentation {
                    provider: demo
                    formatOptions: Format.DEFAULT_FORMAT
                    vertical: true
                    fontFamily: scene.family
                    minReadablePx: scene.smallPx
                    baseFontPx: scene.defaultPx
                    Layout.fillWidth: true
                }
            }
        }
    }

    Rectangle {
        id: popupShot

        x: 420
        y: 20
        width: popup.width
        height: popup.height
        color: Kirigami.Theme.backgroundColor

        FullRepresentation {
            id: popup

            provider: demo
            formatOptions: Format.DEFAULT_FORMAT
            usage: demo.usage
            graphMinutes: 5
            width: Layout.preferredWidth
            height: Layout.preferredHeight
        }
    }

    // The views need a moment to lay out and the graph to load.
    Timer {
        interval: 1500
        running: true
        onTriggered: scene.start()
    }

    Timer {
        interval: 30000
        running: true
        onTriggered: scene.finish(false, "timed out")
    }
}
