// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Smoke scene for CompactRepresentation: shows the panel view in four panel
// sizes (horizontal 44, 20 and 96 px high, vertical 32 px wide) with a stub
// provider and checks sizes, placement and the "–" shown before the first data;
// then the order, the single value, the natural width and the explicit layouts,
// then the appearance settings (font, size and symbol style), the mini chart
// (off, behind the text, beside it, combined, in a vertical panel), and finally
// the clicks: left and middle report pressed() then activated(), the right button
// reports nothing.
// plasmawindowed does not instantiate the compact view of this plasmoid, so
// this scene is the only runtime check of its bindings. It cannot see QML
// warnings itself: read the output of qml6 for the scene as well, it must be
// free of warnings.

import QtQuick
import QtQuick.Layouts
import QtTest
import org.kde.kirigami as Kirigami
import "../../package/contents/ui/compact"
import "../../package/contents/code/format.mjs" as Format

Item {
    id: scene

    width: 700
    height: 500

    property bool done: false
    // Text sizes of a stock Plasma at 96 dpi (10 pt and 8 pt Noto Sans). Plain
    // qml6 reports other values, and for the small font a different one before
    // and after the window exists, so the views are given these instead.
    readonly property int plasmaDefaultPx: 13
    readonly property int plasmaSmallPx: 10
    // The implicit sizes while the stub has data, for the comparison without.
    property var sizesWithData: ({})

    readonly property var cases: [
        {
            name: "horizontal 44px",
            host: host44,
            view: wide44,
            layout: "rows",
            vertical: false
        },
        {
            name: "horizontal 20px",
            host: host20,
            view: wide20,
            layout: "columns",
            vertical: false
        },
        {
            name: "horizontal 96px",
            host: host96,
            view: wide96,
            layout: "rows",
            vertical: false
        },
        {
            name: "vertical 32px",
            host: host32,
            view: narrow32,
            layout: "rows",
            vertical: true
        }
    ]

    function finish(ok, message) {
        if (scene.done) {
            return;
        }
        scene.done = true;
        console.log(message);
        Qt.exit(ok ? 0 : 1);
    }

    function fail(message) {
        scene.finish(false, "SMOKE FAIL compact: " + message);
    }

    // The Texts that are shown, with their position in the coordinates of `view`.
    function shownTexts(item, view, found) {
        for (let i = 0; i < item.children.length; i++) {
            const child = item.children[i];
            if (!child.visible) {
                continue;
            }
            if (child instanceof Text && child.text !== "") {
                const pos = child.mapToItem(view, 0, 0);
                found.push({
                    text: child.text,
                    x: pos.x,
                    y: pos.y,
                    width: child.width,
                    content: child.contentWidth,
                    height: child.height,
                    right: pos.x + child.width,
                    bottom: pos.y + child.height
                });
            }
            scene.shownTexts(child, view, found);
        }
        return found;
    }

    function describe(texts) {
        return texts.map(t => "'" + t.text + "'@" + t.x.toFixed(1) + "," + t.y.toFixed(1) + " " + t.width.toFixed(1) + "x" + t.height.toFixed(1)).join(" ");
    }

    // Nothing sticks out of the view or the vertical panel, and nothing sits on
    // something else. `limit` is the width of the panel for a vertical view.
    function placementProblem(where, view, texts, vertical, limit) {
        const tolerance = 1.5;
        for (const t of texts) {
            // A text must fit its slot. Text reports up to one pixel more than the
            // advance it is measured with, at 6 and 7 px (a glyph reaching out).
            if (t.content > t.width + 1.05) {
                return where + ": '" + t.text + "' needs " + t.content.toFixed(2) + " px but its slot is " + t.width.toFixed(2) + " px wide: " + scene.describe(texts);
            }
            if (vertical ? (t.x < -0.01 || t.right > limit + 0.01) : (t.x < -tolerance || t.right > view.width + tolerance)) {
                return where + ": '" + t.text + "' sticks out horizontally: " + scene.describe(texts);
            }
            if (!vertical && (t.y < -tolerance || t.bottom > view.height + tolerance)) {
                return where + ": '" + t.text + "' sticks out vertically: " + scene.describe(texts);
            }
        }
        for (let i = 0; i < texts.length; i++) {
            for (let j = i + 1; j < texts.length; j++) {
                const a = texts[i];
                const b = texts[j];
                const overlapX = Math.min(a.right, b.right) - Math.max(a.x, b.x);
                const overlapY = Math.min(a.bottom, b.bottom) - Math.max(a.y, b.y);
                if (overlapX > tolerance && overlapY > tolerance) {
                    return where + ": '" + a.text + "' overlaps '" + b.text + "': " + scene.describe(texts);
                }
            }
        }
        if (vertical && view.implicitWidth > limit + 0.01) {
            return where + ": implicit width " + view.implicitWidth + " exceeds the " + limit + " px panel";
        }
        return "";
    }

    // Placement, sizes and texts of one view; `hasData` says what is shown.
    function checkView(entry, hasData) {
        const view = entry.view;
        const where = entry.name + (hasData ? "" : " without data");
        const texts = scene.shownTexts(view, view, []);

        if (view.resolvedLayout !== entry.layout) {
            return where + ": layout is '" + view.resolvedLayout + "', expected '" + entry.layout + "'";
        }
        if (!(view.implicitWidth > 0) || !(view.implicitHeight > 0)) {
            return where + ": implicit size " + view.implicitWidth + "x" + view.implicitHeight;
        }
        // The size hints along the panel are what the host layout takes over.
        const hint = entry.vertical ? entry.host.implicitHeight : entry.host.implicitWidth;
        const expected = entry.vertical ? view.implicitHeight : view.implicitWidth;
        if (!(hint > 0) || Math.abs(hint - expected) > 1) {
            return where + ": the host layout needs " + hint + ", the view needs " + expected;
        }
        if (!(view.pixelSize >= 1)) {
            return where + ": pixelSize " + view.pixelSize;
        }
        const problem = scene.textProblem(where, texts, 2, hasData);
        if (problem !== "") {
            return problem;
        }
        const placement = scene.placementProblem(where, view, texts, entry.vertical, entry.host.width);
        if (placement !== "") {
            return placement;
        }
        if (entry.vertical && view.pixelSize < view.minReadablePx) {
            return where + ": pixelSize " + view.pixelSize + " is below the readable " + view.minReadablePx;
        }
        console.log("compact " + where + ": layout " + view.resolvedLayout + ", pixelSize " + view.pixelSize + ", implicit " + view.implicitWidth.toFixed(1) + "x" + view.implicitHeight.toFixed(1) + " | " + scene.describe(texts));
        return "";
    }

    // One value text per label: a number, or the dash without data; never "NaN".
    function textProblem(where, texts, labelCount, hasData) {
        const values = texts.filter(t => hasData ? /^\d/.test(t.text) : t.text === "–");
        if (values.length !== labelCount) {
            return where + ": expected " + labelCount + " value texts, got " + values.length + " in: " + scene.describe(texts);
        }
        for (const t of texts) {
            if (/NaN|undefined|null/.test(t.text) || (!hasData && /\d/.test(t.text))) {
                return where + ": bad text '" + t.text + "'";
            }
        }
        return "";
    }

    function checkAll(hasData) {
        for (const entry of scene.cases) {
            const problem = scene.checkView(entry, hasData);
            if (problem !== "") {
                return problem;
            }
        }
        return "";
    }

    function sizeProblem(what) {
        for (const entry of scene.cases) {
            const before = scene.sizesWithData[entry.name];
            if (Math.abs(entry.view.implicitWidth - before[0]) > 0.01 || Math.abs(entry.view.implicitHeight - before[1]) > 0.01) {
                return entry.name + ": size changed " + what + ": " + before + " -> " + entry.view.implicitWidth + "x" + entry.view.implicitHeight;
            }
        }
        return "";
    }

    function textAt(view, text) {
        return scene.shownTexts(view, view, []).filter(t => t.text === text)[0];
    }

    // The visible Text items and theme icons inside `item`.
    function shownItems(item, found) {
        for (let i = 0; i < item.children.length; i++) {
            const child = item.children[i];
            if (!child.visible) {
                continue;
            }
            if ((child instanceof Text && child.text !== "") || child instanceof Kirigami.Icon) {
                found.push(child);
            }
            scene.shownItems(child, found);
        }
        return found;
    }

    // The texts of a view that are neither a value nor a unit: its symbols.
    function symbolTexts(view) {
        const units = Format.speedUnits(view.formatOptions).concat(Format.speedUnits(Object.assign({}, view.formatOptions, {
            shortUnits: true
        })));
        return scene.shownItems(view, []).filter(item => item instanceof Text && !/^[\d–]/.test(item.text) && units.indexOf(item.text) < 0).map(item => item.text);
    }

    function iconSources(view) {
        return scene.shownItems(view, []).filter(item => item instanceof Kirigami.Icon).map(item => String(item.source));
    }

    // With the default appearance a view shows arrows in the theme font and colour.
    function defaultLookProblem(name, view) {
        const symbols = scene.symbolTexts(view).join(",");
        if (symbols !== "↓,↑") {
            return name + ": symbols are '" + symbols + "', expected '↓,↑'";
        }
        if (scene.iconSources(view).length !== 0) {
            return name + ": shows icons";
        }
        for (const item of scene.shownItems(view, [])) {
            if (item.font.family !== Kirigami.Theme.defaultFont.family || item.font.bold || !Qt.colorEqual(item.color, Kirigami.Theme.textColor)) {
                return name + ": '" + item.text + "' uses " + item.font.family + (item.font.bold ? " bold" : "") + " in " + item.color + ", expected " + Kirigami.Theme.defaultFont.family + " in " + Kirigami.Theme.textColor;
            }
        }
        return "";
    }

    // A family other than the theme's, preferably a wide monospace one.
    readonly property string otherFamily: {
        const families = Qt.fontFamilies().filter(f => f !== Kirigami.Theme.defaultFont.family && !f.endsWith(".pcf"));
        return families.filter(f => /Mono/.test(f))[0] || families[0] || "";
    }
    property real boldWidth: 0

    // A scaled view: every text stays inside the view and inside its own row,
    // and nothing overlaps.
    function scaledProblem(where, texts, labelCount) {
        const problem = scene.textProblem(where, texts, labelCount, true) || scene.placementProblem(where, styled44, texts, false, 0);
        if (problem !== "") {
            return problem;
        }
        const rows = styled44.resolvedLayout === "rows" ? 2 : 1;
        const rowHeight = styled44.height / rows;
        for (const t of texts) {
            const row = Math.min(rows - 1, Math.floor((t.y + t.height / 2) / rowHeight));
            if (t.y < row * rowHeight - 0.01 || t.bottom > (row + 1) * rowHeight + 0.01) {
                return where + ": '" + t.text + "' leaves its row of " + rowHeight + " px: " + scene.describe(texts);
            }
        }
        return "";
    }

    // The visible texts and icons of a view in layout order, with their colours.
    function partColors(view) {
        return scene.shownItems(view, []).map(item => item.text !== undefined ? item.text + "=" + item.color : "icon=" + item.color);
    }

    // "" when the parts have the expected colours (and the accessible name is
    // that of the plain view), else what is wrong.
    function colorProblem(where, view, expected) {
        const items = scene.shownItems(view, []);
        if (view.accessibleName !== wide44.accessibleName) {
            return where + ": accessible name changed to '" + view.accessibleName + "'";
        }
        if (items.length !== expected.length) {
            return where + ": " + items.length + " parts, expected " + expected.length + ": " + scene.partColors(view).join(" ");
        }
        for (let i = 0; i < items.length; i++) {
            if (!Qt.colorEqual(items[i].color, expected[i])) {
                return where + ": part " + i + " is " + items[i].color + ", expected " + expected[i] + ": " + scene.partColors(view).join(" ");
            }
        }
        return "";
    }

    function styledProblem(where) {
        const texts = scene.shownTexts(styled44, styled44, []);
        return scene.textProblem(where, texts, 2, true) || scene.placementProblem(where, styled44, texts, false, 0);
    }

    // What the views reported: "pressed:<button>" and "activated:<button>".
    property var events: []

    Connections {
        target: wide44

        function onPressed(button: int) {
            scene.events.push("pressed:" + button);
        }

        function onActivated(button: int) {
            scene.events.push("activated:" + button);
        }
    }

    // plain qml6 can only synthesize mouse events through a TestCase; it runs
    // its test functions once the steps are through and then quits.
    TestCase {
        id: input

        name: "input"
        when: scene.step >= scene.steps.length && !scene.done

        function test_clicks() {
            const problem = scene.clickProblem();
            if (problem !== "") {
                scene.fail(problem);
                return;
            }
            scene.finish(true, "SMOKE OK compact");
        }
    }

    // Clicks the middle of the view with a button; returns what was reported.
    function clickWith(button: int): string {
        scene.events = [];
        input.mouseClick(wide44, wide44.width / 2, wide44.height / 2, button);
        return scene.events.join(",");
    }

    // A history of `count` samples: the download of sample i is
    // 1000 * i + offset, the upload 10 * i.
    function makeHistory(count, offset) {
        const history = {
            down: [],
            up: [],
            times: []
        };
        for (let i = 0; i < count; i++) {
            history.down.push(1000 * i + offset);
            history.up.push(10 * i);
            history.times.push(i * 1000);
        }
        return history;
    }

    function lastOf(list, count) {
        return JSON.stringify(list.slice(-count));
    }

    // "" when the chart of `view` is loaded with the given series, else what is
    // wrong.
    function sparkSeriesProblem(where, view, history, combined) {
        const item = view.sparkLoaderItem.item;
        if (!item) {
            return where + ": the chart is not loaded";
        }
        const down = combined ? history.down.map((v, i) => v + history.up[i]) : history.down;
        const gotDown = JSON.stringify(item.downSeries);
        const gotUp = JSON.stringify(item.upSeries);
        if (gotDown !== scene.lastOf(down, 60)) {
            return where + ": downSeries " + gotDown + " is not the last 60 of " + JSON.stringify(down);
        }
        if (gotUp !== (combined ? "[]" : scene.lastOf(history.up, 60))) {
            return where + ": upSeries " + gotUp;
        }
        return "";
    }

    // "" when the chart of `view` is ready and drawn in the colours of the
    // values.
    function sparkLookProblem(where, view) {
        const item = view.sparkLoaderItem.item;
        if (view.sparkLoaderItem.status !== Loader.Ready || !item) {
            return where + ": the chart is not ready (status " + view.sparkLoaderItem.status + ")";
        }
        const down = view.combined ? view.totalColor : view.downColor;
        if (!Qt.colorEqual(item.downColor, down) || !Qt.colorEqual(item.upColor, view.upColor)) {
            return where + ": colours " + item.downColor + "/" + item.upColor + ", expected " + down + "/" + view.upColor;
        }
        return "";
    }

    QtObject {
        id: stub

        property var history: scene.makeHistory(80, 5)
        property bool hasData: true
        property real down: 1.5 * 1024 * 1024
        property real up: 130 * 1024
        property bool stale: false
    }

    // Each view sits in a layout of the size of the panel, as in Plasma: the
    // panel gives the thickness, the view's size hints give the length.
    RowLayout {
        id: host44

        x: 10
        y: 10
        width: 300
        height: 44
        spacing: 0

        CompactRepresentation {
            id: wide44

            provider: stub
            formatOptions: Format.DEFAULT_FORMAT
            minReadablePx: scene.plasmaSmallPx
            baseFontPx: scene.plasmaDefaultPx
            Layout.fillHeight: true
        }
    }

    RowLayout {
        id: host20

        x: 10
        y: 70
        width: 300
        height: 20
        spacing: 0

        CompactRepresentation {
            id: wide20

            provider: stub
            formatOptions: Format.DEFAULT_FORMAT
            minReadablePx: scene.plasmaSmallPx
            baseFontPx: scene.plasmaDefaultPx
            Layout.fillHeight: true
        }
    }

    RowLayout {
        id: host96

        x: 10
        y: 110
        width: 300
        height: 96
        spacing: 0

        CompactRepresentation {
            id: wide96

            provider: stub
            formatOptions: Format.DEFAULT_FORMAT
            minReadablePx: scene.plasmaSmallPx
            baseFontPx: scene.plasmaDefaultPx
            Layout.fillHeight: true
        }
    }

    ColumnLayout {
        id: host32

        x: 400
        y: 10
        width: 32
        height: 400
        spacing: 0

        CompactRepresentation {
            id: narrow32

            provider: stub
            formatOptions: Format.DEFAULT_FORMAT
            vertical: true
            minReadablePx: scene.plasmaSmallPx
            baseFontPx: scene.plasmaDefaultPx
            Layout.fillWidth: true
        }
    }

    // The appearance settings: once spelled out with their defaults, once bold
    // in another family, and one view whose style the steps change.
    RowLayout {
        id: hostDefaults

        x: 10
        y: 220
        width: 300
        height: 44
        spacing: 0

        CompactRepresentation {
            id: defaults44

            provider: stub
            formatOptions: Format.DEFAULT_FORMAT
            minReadablePx: scene.plasmaSmallPx
            baseFontPx: scene.plasmaDefaultPx
            fontFamily: ""
            fontBold: false
            fontScale: 100
            iconStyle: "arrows"
            customDownIcon: "↓"
            customUpIcon: "↑"
            Layout.fillHeight: true
        }
    }

    RowLayout {
        id: hostBold

        x: 10
        y: 280
        width: 300
        height: 44
        spacing: 0

        CompactRepresentation {
            id: bold44

            provider: stub
            formatOptions: Format.DEFAULT_FORMAT
            minReadablePx: scene.plasmaSmallPx
            baseFontPx: scene.plasmaDefaultPx
            fontFamily: scene.otherFamily
            fontBold: true
            Layout.fillHeight: true
        }
    }

    RowLayout {
        id: hostStyled

        x: 10
        y: 340
        width: 300
        height: 44
        spacing: 0

        CompactRepresentation {
            id: styled44

            provider: stub
            formatOptions: Format.DEFAULT_FORMAT
            minReadablePx: scene.plasmaSmallPx
            baseFontPx: scene.plasmaDefaultPx
            Layout.fillHeight: true
        }
    }

    // The mini chart: a horizontal view whose mode the steps change, and two
    // vertical panels, with and without the chart beside the text.
    RowLayout {
        id: hostSpark

        x: 10
        y: 400
        width: 300
        height: 44
        spacing: 0

        CompactRepresentation {
            id: spark44

            provider: stub
            history: stub.history
            formatOptions: Format.DEFAULT_FORMAT
            minReadablePx: scene.plasmaSmallPx
            baseFontPx: scene.plasmaDefaultPx
            Layout.fillHeight: true
        }
    }

    ColumnLayout {
        id: hostSparkPlain

        x: 450
        y: 10
        width: 32
        height: 400
        spacing: 0

        CompactRepresentation {
            id: narrowPlain

            provider: stub
            formatOptions: Format.DEFAULT_FORMAT
            vertical: true
            minReadablePx: scene.plasmaSmallPx
            baseFontPx: scene.plasmaDefaultPx
            Layout.fillWidth: true
        }
    }

    ColumnLayout {
        id: hostSparkVertical

        x: 500
        y: 10
        width: 32
        height: 400
        spacing: 0

        CompactRepresentation {
            id: narrowSpark

            provider: stub
            history: stub.history
            sparkline: "beside"
            formatOptions: Format.DEFAULT_FORMAT
            vertical: true
            minReadablePx: scene.plasmaSmallPx
            baseFontPx: scene.plasmaDefaultPx
            Layout.fillWidth: true
        }
    }

    function clickProblem() {
        const expected = [[Qt.LeftButton, "pressed:" + Qt.LeftButton + ",activated:" + Qt.LeftButton, "left"], [Qt.MiddleButton, "pressed:" + Qt.MiddleButton + ",activated:" + Qt.MiddleButton, "middle"], [Qt.RightButton, "", "right"]];
        for (const [button, events, name] of expected) {
            const got = scene.clickWith(button);
            if (got !== events) {
                return name + " click reported '" + got + "', expected '" + events + "'";
            }
        }
        console.log("compact clicks: left and middle report pressed then activated, right nothing");
        return "";
    }

    // Each step checks what the previous one changed and then changes the next
    // thing; the Timer gives the layouts time to settle in between. A step
    // returns the problem it found, or "".
    readonly property var steps: [
        () => {
            const problem = scene.checkAll(true);
            for (const entry of scene.cases) {
                scene.sizesWithData[entry.name] = [entry.view.implicitWidth, entry.view.implicitHeight];
            }
            // The widest values that automatic decimals can show: "99.9" (one
            // decimal below 100) and "999" (none from 100). A fixed width must
            // not change, and the slot must hold them without waste.
            stub.down = 99.9 * 1024 * 1024;
            stub.up = 999 * 1024;
            return problem;
        },
        () => {
            const problem = scene.checkAll(true) || scene.sizeProblem("with the values");
            // The value slot of the horizontal view is as wide as "99.9", the
            // widest of the two (three digits and the point).
            const widest = scene.textAt(wide44, "99.9");
            if (!widest || Math.abs(widest.width - widest.content) > 1) {
                return "horizontal 44px: the value slot is " + (widest ? widest.width.toFixed(2) : "missing") + " px for a text of " + (widest ? widest.content.toFixed(2) : "?") + " px";
            }
            // Before the first data.
            stub.hasData = false;
            return problem;
        },
        () => {
            const problem = scene.checkAll(false) || scene.sizeProblem("without data");
            stub.hasData = true;
            stub.stale = true;
            return problem;
        },
        () => {
            // Stale data is dimmed.
            for (const entry of scene.cases) {
                if (entry.view.opacity !== 0.5) {
                    return entry.name + ": stale opacity is " + entry.view.opacity;
                }
            }
            stub.stale = false;
            stub.down = 1.5 * 1024 * 1024;
            stub.up = 130 * 1024;
            wide44.uploadFirst = true;
            narrow32.uploadFirst = true;
            return "";
        },
        () => {
            // Upload first: its arrow stands above the arrow of the download.
            for (const view of [wide44, narrow32]) {
                if (view.opacity !== 1 || scene.textAt(view, "↑").y >= scene.textAt(view, "↓").y) {
                    return "upload first: the upload does not come first (opacity " + view.opacity + ")";
                }
            }
            wide44.uploadFirst = false;
            narrow32.uploadFirst = false;
            wide44.combined = true;
            narrow32.combined = true;
            return "";
        },
        () => {
            // Combined: one label with both arrows and the sum of both rates,
            // 1.5 MiB/s + 130 KiB/s = 1.6 MiB/s (a vertical panel may show it as 2).
            for (const [name, view, vertical, sum] of [["horizontal", wide44, false, /^1\.6$/], ["vertical", narrow32, true, /^(1\.6|2)$/]]) {
                const where = "combined " + name;
                const texts = scene.shownTexts(view, view, []);
                if (view.resolvedLayout !== "single" || !scene.textAt(view, "↓↑") || texts.some(t => t.text === "↑" || t.text === "↓")) {
                    return where + ": not a single label: " + view.resolvedLayout + " " + scene.describe(texts);
                }
                const problem = scene.textProblem(where, texts, 1, true) || scene.placementProblem(where, view, texts, vertical, 32);
                if (problem !== "") {
                    return problem;
                }
                if (!texts.some(t => sum.test(t.text))) {
                    return where + ": the sum is not shown: " + scene.describe(texts);
                }
            }
            wide44.combined = false;
            narrow32.combined = false;
            wide44.fixedWidth = false;
            return "";
        },
        () => {
            // Natural width: the view takes only what the current text needs.
            const fixed = scene.sizesWithData["horizontal 44px"][0];
            if (!(wide44.implicitWidth > 0 && wide44.implicitWidth < fixed)) {
                return "natural width " + wide44.implicitWidth + " is not below the fixed width " + fixed;
            }
            wide44.fixedWidth = true;
            // Explicit layouts are honored, also in a panel for which auto chooses otherwise.
            wide20.layoutMode = "rows";
            narrow32.layoutMode = "columns";
            return "";
        },
        () => {
            let texts = scene.shownTexts(wide20, wide20, []);
            let problem = wide20.resolvedLayout !== "rows" ? "explicit rows at 20 px: layout is " + wide20.resolvedLayout : scene.textProblem("rows at 20 px", texts, 2, true) || scene.placementProblem("rows at 20 px", wide20, texts, false, 0);
            if (problem !== "") {
                return problem;
            }
            // Side by side in a 32 px panel is far too wide for readable text,
            // but it must still stay inside the panel.
            texts = scene.shownTexts(narrow32, narrow32, []);
            problem = narrow32.resolvedLayout !== "columns" ? "explicit columns at 32 px: layout is " + narrow32.resolvedLayout : scene.textProblem("columns at 32 px", texts, 2, true) || scene.placementProblem("columns at 32 px", narrow32, texts, true, 32);
            console.log("compact vertical 32px with explicit columns: pixelSize " + narrow32.pixelSize + " | " + scene.describe(texts));
            return problem;
        },
        () => {
            // Spelled-out defaults look exactly like a view that sets none of them.
            if (Math.abs(defaults44.implicitWidth - wide44.implicitWidth) > 0.01 || Math.abs(defaults44.implicitHeight - wide44.implicitHeight) > 0.01) {
                return "explicit defaults: " + defaults44.implicitWidth + "x" + defaults44.implicitHeight + " instead of " + wide44.implicitWidth + "x" + wide44.implicitHeight;
            }
            const problem = scene.defaultLookProblem("no appearance set", wide44) || scene.defaultLookProblem("explicit defaults", defaults44);
            if (problem !== "") {
                return problem;
            }
            if (scene.otherFamily === "") {
                return "no font family besides the theme's";
            }
            // The bold view starts with small values.
            stub.down = 2 * 1024;
            stub.up = 3 * 1024;
            return "";
        },
        () => {
            const fonts = scene.shownItems(bold44, []).filter(item => item.font.family !== scene.otherFamily || !item.font.bold);
            if (fonts.length > 0) {
                return "bold view: '" + fonts[0].text + "' uses " + fonts[0].font.family + ", expected bold " + scene.otherFamily;
            }
            const texts = scene.shownTexts(bold44, bold44, []);
            const problem = scene.textProblem("bold", texts, 2, true) || scene.placementProblem("bold", bold44, texts, false, 0);
            scene.boldWidth = bold44.implicitWidth;
            stub.down = 99.9 * 1024 * 1024;
            stub.up = 999 * 1024;
            return problem;
        },
        () => {
            // The fixed width holds in the chosen font, and the widest values fit.
            if (Math.abs(bold44.implicitWidth - scene.boldWidth) > 0.01) {
                return "bold " + scene.otherFamily + ": width changed from " + scene.boldWidth + " to " + bold44.implicitWidth;
            }
            const texts = scene.shownTexts(bold44, bold44, []);
            console.log("compact bold " + scene.otherFamily + ": implicit " + bold44.implicitWidth.toFixed(1) + " | " + scene.describe(texts));
            const problem = scene.textProblem("bold widest", texts, 2, true) || scene.placementProblem("bold widest", bold44, texts, false, 0);
            stub.down = 1.5 * 1024 * 1024;
            stub.up = 130 * 1024;
            styled44.iconStyle = "none";
            return problem;
        },
        () => {
            // No symbols: the values start at the left edge, without a gap.
            const texts = scene.shownTexts(styled44, styled44, []);
            const symbols = scene.symbolTexts(styled44);
            if (symbols.length !== 0 || scene.iconSources(styled44).length !== 0) {
                return "style none: shows symbols " + symbols;
            }
            const values = texts.filter(t => /^\d/.test(t.text));
            if (values.some(t => Math.abs(t.x) > 0.5) || !(styled44.implicitWidth < wide44.implicitWidth)) {
                return "style none: values do not start at the left edge or the width " + styled44.implicitWidth + " is not below " + wide44.implicitWidth + ": " + scene.describe(texts);
            }
            const problem = scene.styledProblem("style none");
            styled44.iconStyle = "triangles";
            return problem;
        },
        () => {
            const symbols = scene.symbolTexts(styled44).join(",");
            if (symbols !== "▼,▲") {
                return "style triangles: symbols are '" + symbols + "'";
            }
            const problem = scene.styledProblem("style triangles");
            styled44.iconStyle = "icons";
            return problem;
        },
        () => {
            const sources = scene.iconSources(styled44).join(",");
            const symbols = scene.symbolTexts(styled44);
            if (sources !== "go-down,go-up" || symbols.length !== 0) {
                return "style icons: icons '" + sources + "', texts '" + symbols + "'";
            }
            const icons = scene.shownItems(styled44, []).filter(item => item instanceof Kirigami.Icon);
            if (icons.some(icon => Math.abs(icon.width - styled44.pixelSize) > 0.01 || Math.abs(icon.height - styled44.pixelSize) > 0.01)) {
                return "style icons: an icon is " + icons[0].width + "x" + icons[0].height + ", expected " + styled44.pixelSize;
            }
            const problem = scene.styledProblem("style icons");
            styled44.customDownIcon = "D";
            styled44.customUpIcon = "U";
            styled44.iconStyle = "custom";
            return problem;
        },
        () => {
            const symbols = scene.symbolTexts(styled44).join(",");
            if (symbols !== "D,U") {
                return "style custom: symbols are '" + symbols + "'";
            }
            const problem = scene.styledProblem("style custom");
            styled44.iconStyle = "triangles";
            styled44.combined = true;
            return problem;
        },
        () => {
            const symbols = scene.symbolTexts(styled44).join(",");
            if (symbols !== "▼▲") {
                return "combined triangles: symbols are '" + symbols + "'";
            }
            const texts = scene.shownTexts(styled44, styled44, []);
            const problem = scene.textProblem("combined triangles", texts, 1, true) || scene.placementProblem("combined triangles", styled44, texts, false, 0);
            styled44.combined = false;
            styled44.iconStyle = "arrows";
            styled44.fontScale = 150;
            return problem;
        },
        () => {
            if (!(styled44.pixelSize > wide44.pixelSize)) {
                return "fontScale 150: pixelSize " + styled44.pixelSize + " is not above " + wide44.pixelSize;
            }
            const texts = scene.shownTexts(styled44, styled44, []);
            console.log("compact fontScale 150: pixelSize " + styled44.pixelSize + " | " + scene.describe(texts));
            const problem = scene.scaledProblem("fontScale 150 rows", texts, 2);
            styled44.layoutMode = "columns";
            return problem;
        },
        () => {
            const texts = scene.shownTexts(styled44, styled44, []);
            console.log("compact fontScale 150 columns: pixelSize " + styled44.pixelSize + " | " + scene.describe(texts));
            const problem = styled44.resolvedLayout !== "columns" ? "fontScale 150: layout is " + styled44.resolvedLayout : scene.scaledProblem("fontScale 150 columns", texts, 2);
            styled44.layoutMode = "auto";
            styled44.combined = true;
            return problem;
        },
        () => {
            const texts = scene.shownTexts(styled44, styled44, []);
            console.log("compact fontScale 150 single: pixelSize " + styled44.pixelSize + " | " + scene.describe(texts));
            return styled44.resolvedLayout !== "single" ? "fontScale 150: layout is " + styled44.resolvedLayout : scene.scaledProblem("fontScale 150 single", texts, 1);
        },
        () => {
            // The colours; parts in order: symbol, value, unit, symbol, value, unit.
            styled44.fontScale = 100;
            styled44.combined = false;
            styled44.layoutMode = "auto";
            return "";
        },
        () => {
            const text = Kirigami.Theme.textColor;
            const problem = scene.colorProblem("colors theme", styled44, [text, text, text, text, text, text]);
            styled44.colorMode = "direction";
            styled44.downloadColor = "#ff0000";
            styled44.uploadColor = "#00ff00";
            return problem;
        },
        () => {
            const text = Kirigami.Theme.textColor;
            const problem = scene.colorProblem("colors direction", styled44, [text, "#ff0000", text, text, "#00ff00", text]);
            styled44.colorUnits = true;
            return problem;
        },
        () => {
            const problem = scene.colorProblem("colors direction with units", styled44, ["#ff0000", "#ff0000", "#ff0000", "#00ff00", "#00ff00", "#00ff00"]);
            styled44.colorUnits = false;
            styled44.downloadColor = "";
            styled44.uploadColor = "";
            return problem;
        },
        () => {
            const text = Kirigami.Theme.textColor;
            const high = Kirigami.Theme.highlightColor;
            const neutral = Kirigami.Theme.neutralTextColor;
            const problem = scene.colorProblem("colors direction by theme", styled44, [text, high, text, text, neutral, text]);
            styled44.colorMode = "thresholds";
            stub.down = 2 * 1024 * 1024;
            stub.up = 0;
            return problem;
        },
        () => {
            const text = Kirigami.Theme.textColor;
            const problem = scene.colorProblem("colors thresholds", styled44, [text, "#1d99f3", text, text, text, text]);
            styled44.combined = true;
            return problem;
        },
        () => {
            const text = Kirigami.Theme.textColor;
            // The sum of 2 MiB/s and 0 reaches the second level.
            const problem = scene.colorProblem("colors thresholds combined", styled44, [text, "#1d99f3", text]);
            styled44.colorMode = "direction";
            styled44.downloadColor = "#ff0000";
            styled44.uploadColor = "#00ff00";
            styled44.combined = false;
            styled44.iconStyle = "icons";
            return problem;
        },
        () => {
            // Icons: tinted like the unit.
            const text = Kirigami.Theme.textColor;
            const problem = scene.colorProblem("colors icons", styled44, [text, "#ff0000", text, text, "#00ff00", text]);
            styled44.colorUnits = true;
            return problem;
        },
        () => {
            const problem = scene.colorProblem("colors icons with units", styled44, ["#ff0000", "#ff0000", "#ff0000", "#00ff00", "#00ff00", "#00ff00"]);
            styled44.colorUnits = false;
            styled44.colorMode = "theme";
            styled44.iconStyle = "arrows";
            stub.down = 1.5 * 1024 * 1024;
            stub.up = 130 * 1024;
            return problem;
        },
        () => {
            // The mini chart, off: nothing is loaded and the width is that of a view without it.
            if (spark44.sparkLoaderItem.active || spark44.sparkLoaderItem.status !== Loader.Null) {
                return "sparkline off: the chart is loaded";
            }
            if (Math.abs(spark44.implicitWidth - wide44.implicitWidth) > 0.01) {
                return "sparkline off: width " + spark44.implicitWidth + " instead of " + wide44.implicitWidth;
            }
            spark44.sparkline = "beside";
            return "";
        },
        () => {
            const rowHeight = spark44.height / 2;
            const item = spark44.sparkLoaderItem.item;
            let problem = scene.sparkLookProblem("sparkline beside", spark44) || scene.sparkSeriesProblem("sparkline beside", spark44, stub.history, false);
            if (problem !== "") {
                return problem;
            }
            if (Math.abs(spark44.implicitWidth - (wide44.implicitWidth + 2 * rowHeight)) > 0.01) {
                return "sparkline beside: width " + spark44.implicitWidth + ", expected " + wide44.implicitWidth + " + " + 2 * rowHeight;
            }
            if (Math.abs(spark44.Layout.preferredWidth - spark44.implicitWidth) > 0.01 || spark44.sparkLoaderItem.opacity !== 1 || item.filled) {
                return "sparkline beside: preferred width " + spark44.Layout.preferredWidth + ", opacity " + spark44.sparkLoaderItem.opacity + ", filled " + item.filled;
            }
            // The chart takes the room right of the text and the text stays inside the rest.
            const texts = scene.shownTexts(spark44, spark44, []);
            problem = scene.textProblem("sparkline beside", texts, 2, true) || scene.placementProblem("sparkline beside", spark44, texts, false, 0);
            if (problem === "" && (Math.abs(spark44.sparkLoaderItem.width + spark44.sparkGap - 2 * rowHeight) > 0.01 || spark44.sparkGap <= 0 || texts.some(t => t.right > spark44.sparkLoaderItem.x - spark44.sparkGap + 1.5))) {
                problem = "sparkline beside: the text reaches into the chart: " + scene.describe(texts);
            }
            console.log("compact sparkline beside: implicit " + spark44.implicitWidth.toFixed(1) + " | " + scene.describe(texts));
            spark44.sparkline = "background";
            return problem;
        },
        () => {
            let problem = scene.sparkLookProblem("sparkline background", spark44) || scene.sparkSeriesProblem("sparkline background", spark44, stub.history, false);
            if (problem !== "") {
                return problem;
            }
            if (Math.abs(spark44.implicitWidth - wide44.implicitWidth) > 0.01 || Math.abs(spark44.sparkLoaderItem.opacity * spark44.sparkLoaderItem.item.fillOpacity - 0.35) > 0.001 || !spark44.sparkLoaderItem.item.filled) {
                return "sparkline background: width " + spark44.implicitWidth + ", opacity " + spark44.sparkLoaderItem.opacity + ", filled " + spark44.sparkLoaderItem.item.filled;
            }
            if (spark44.sparkLoaderItem.width !== spark44.width || spark44.sparkLoaderItem.height !== spark44.height) {
                return "sparkline background: the chart covers " + spark44.sparkLoaderItem.width + "x" + spark44.sparkLoaderItem.height + " of " + spark44.width + "x" + spark44.height;
            }
            const texts = scene.shownTexts(spark44, spark44, []);
            problem = scene.textProblem("sparkline background", texts, 2, true) || scene.placementProblem("sparkline background", spark44, texts, false, 0);
            // A new sample moves the window on: the oldest value drops out.
            stub.history = scene.makeHistory(81, 5);
            return problem;
        },
        () => {
            const problem = scene.sparkSeriesProblem("sparkline new sample", spark44, stub.history, false);
            spark44.combined = true;
            return problem;
        },
        () => {
            const problem = scene.sparkLookProblem("sparkline combined", spark44) || scene.sparkSeriesProblem("sparkline combined", spark44, stub.history, true);
            spark44.combined = false;
            spark44.sparkline = "off";
            return problem;
        },
        () => {
            // Back to off: the chart is unloaded again.
            if (spark44.sparkLoaderItem.status !== Loader.Null || Math.abs(spark44.implicitWidth - wide44.implicitWidth) > 0.01) {
                return "sparkline off again: status " + spark44.sparkLoaderItem.status + ", width " + spark44.implicitWidth;
            }
            // A vertical panel gives all of its width to the text: beside acts like background.
            const loader = narrowSpark.sparkLoaderItem;
            if (Math.abs(narrowSpark.implicitWidth - narrowPlain.implicitWidth) > 0.01 || Math.abs(narrowSpark.implicitHeight - narrowPlain.implicitHeight) > 0.01) {
                return "vertical beside: size " + narrowSpark.implicitWidth + "x" + narrowSpark.implicitHeight + " instead of " + narrowPlain.implicitWidth + "x" + narrowPlain.implicitHeight;
            }
            if (narrowSpark.sparkWidth !== 0 || loader.opacity !== 0.35 || loader.width !== narrowSpark.width || !loader.item || Math.abs(loader.opacity * loader.item.fillOpacity - 0.35) > 0.001) {
                return "vertical beside: not drawn like background (opacity " + loader.opacity + ", width " + loader.width + ")";
            }
            const texts = scene.shownTexts(narrowSpark, narrowSpark, []);
            return scene.sparkSeriesProblem("vertical beside", narrowSpark, stub.history, false) || scene.placementProblem("vertical beside", narrowSpark, texts, true, 32);
        }
    ]
    property int step: 0

    Timer {
        interval: 400
        running: true
        repeat: true
        onTriggered: {
            if (scene.done) {
                return;
            }
            if (scene.step >= scene.steps.length) {
                // the TestCase takes over (the click checks)
                return;
            }
            const problem = scene.steps[scene.step]();
            if (problem !== "") {
                scene.fail("step " + scene.step + ": " + problem);
                return;
            }
            scene.step += 1;
        }
    }

    Timer {
        interval: 15000
        running: true
        onTriggered: scene.fail("timeout after 15 s in step " + scene.step)
    }
}
