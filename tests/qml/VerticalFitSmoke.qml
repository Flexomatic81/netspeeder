// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Smoke scene for the vertical fit: measures the four display variants of a
// vertical panel (as chosen; no decimals; short units; symbol on the unit line)
// for the units "iec" and "bits" with automatic decimals, lets fitVertical()
// pick one for a panel that is 32 px wide, and checks the pick. The pick must
// reach the smallest readable text size, and the widest line of the chosen
// variant, measured again at the chosen size with a real Text, must fit in 32 px.
//
// The text sizes are those of a stock Plasma at 96 dpi: 10 pt is 13 px and the
// small font of 8 pt is 10 px (measured with the KDE platform theme). The
// theme fonts of plain qml6 are not usable for this: Kirigami reports 12 px for
// the small font until the window exists and 16 px afterwards, bigger than the
// default font of 12 px.

import QtQuick
import org.kde.kirigami as Kirigami
import "../../package/contents/code/format.mjs" as Format
import "../../package/contents/code/layout.mjs" as LayoutLogic

Item {
    id: scene

    readonly property real panelWidth: 32
    readonly property int defaultPx: 13
    readonly property int smallPx: 10
    readonly property real refPx: LayoutLogic.REFERENCE_PX
    property bool done: false

    function finish(ok, message) {
        if (scene.done) {
            return;
        }
        scene.done = true;
        console.log(message);
        Qt.exit(ok ? 0 : 1);
    }

    // Width of a text in the font of the panel: advanceWidth at the reference
    // size (what the panel measures with), scaled to `px`.
    function advance(text, px) {
        reference.text = text;
        return reference.advanceWidth * px / scene.refPx;
    }

    // Width of a text at `px`, laid out by a Text as the panel draws it.
    function laidOut(text, px) {
        probe.font.pixelSize = px;
        probe.text = text;
        return probe.implicitWidth;
    }

    function widest(texts, measure) {
        return Math.max(...texts.map(measure));
    }

    // The four variants in the order of degradation.
    function variants(system) {
        const asChosen = Object.assign({}, Format.DEFAULT_FORMAT, {
            unitSystem: system,
            decimals: -1
        });
        const noDecimals = Object.assign({}, asChosen, {
            decimals: 0
        });
        const shortUnits = Object.assign({}, noDecimals, {
            shortUnits: true
        });
        return [
            {
                options: asChosen,
                symbolBelow: false
            },
            {
                options: noDecimals,
                symbolBelow: false
            },
            {
                options: shortUnits,
                symbolBelow: false
            },
            {
                options: shortUnits,
                symbolBelow: true
            }
        ];
    }

    // The widest line of a variant at `px`, with `measure(text, px)`.
    function widestLine(variant, px, measure) {
        const symbol = Math.max(measure("↓", px), measure("↑", px));
        const gap = 0.25 * px;
        const value = measure(Format.widestValue(variant.options), px);
        const unit = scene.widest(Format.speedUnits(variant.options), text => measure(text, px));
        return variant.symbolBelow ? Math.max(value, symbol + gap + unit) : Math.max(symbol + gap + value, unit);
    }

    function check(system) {
        const list = scene.variants(system);
        const widths = list.map(variant => scene.widestLine(variant, scene.refPx, scene.advance));
        const fit = LayoutLogic.fitVertical(scene.panelWidth, widths, scene.defaultPx, scene.smallPx);
        const chosen = list[fit.index];
        // The same line again, laid out at the chosen size.
        const real = scene.widestLine(chosen, fit.pixelSize, scene.laidOut);
        const unitsText = Format.speedUnits(chosen.options).join(" ");
        console.log("vertical " + system + ": candidate widths at " + scene.refPx + " px = " + widths.map(w => w.toFixed(1)).join(", ") + "; chosen index " + fit.index + " at " + fit.pixelSize + " px (readable from " + scene.smallPx + ", at most " + scene.defaultPx + "), units '" + unitsText + "', symbol below " + chosen.symbolBelow + ", widest line laid out " + real.toFixed(2) + " px of " + scene.panelWidth);
        if (fit.pixelSize < scene.smallPx) {
            return system + ": " + fit.pixelSize + " px is below the readable " + scene.smallPx + " px";
        }
        if (real > scene.panelWidth + 0.01) {
            return system + ": the widest line is " + real.toFixed(2) + " px at " + fit.pixelSize + " px, wider than " + scene.panelWidth;
        }
        return "";
    }

    TextMetrics {
        id: reference

        font.family: Kirigami.Theme.defaultFont.family
        font.pixelSize: scene.refPx
        font.features: { "tnum": 1 }
    }

    Text {
        id: probe

        visible: false
        font.family: Kirigami.Theme.defaultFont.family
        font.features: { "tnum": 1 }
        renderType: Text.NativeRendering
    }

    Component.onCompleted: {
        for (const system of ["iec", "bits"]) {
            const problem = scene.check(system);
            if (problem !== "") {
                scene.finish(false, "SMOKE FAIL vertical: " + problem);
                return;
            }
        }
        scene.finish(true, "SMOKE OK vertical");
    }
}
