// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Smoke scene for the shared JS modules: runs the same checks the Node tests
// run, but inside the QML engine. Catches differences between the engines
// (sorting, number formatting) and proves that providerstate.mjs can import
// selection.mjs there. Run it with LC_ALL=C as well as with the system locale.

import QtQuick
import "../../package/contents/code/format.mjs" as Format
import "../../package/contents/code/selection.mjs" as Selection
import "../../package/contents/code/providerstate.mjs" as ProviderState

Item {
    id: scene

    function finish(ok, message) {
        console.log(message);
        Qt.exit(ok ? 0 : 1);
    }

    // Compares by JSON text so arrays and objects can be checked in one go.
    function same(label, actual, expected) {
        const a = JSON.stringify(actual);
        const e = JSON.stringify(expected);
        return a === e ? "" : label + ": got " + a + ", expected " + e;
    }

    function iface(fields) {
        const base = { down: 0, up: 0, totalDown: 0, totalUp: 0, kind: "physical", online: true,
            label: "", ipv4: "", ipv6: "", signal: null };
        for (const key of Object.keys(fields)) {
            base[key] = fields[key];
        }
        return base;
    }

    // Returns the first problem found, or "".
    function run() {
        const problems = [];

        problems.push(scene.same("sorted names",
            ["WorkVPN", "docker0", "b", "A", "a"].sort(Selection.compareNames),
            ["A", "a", "b", "docker0", "WorkVPN"]));

        problems.push(scene.same("rounding up to the next unit",
            Format.formatSpeed(999.97 * 1024, {}), { value: "1.0", unit: "MiB/s" }));
        problems.push(scene.same("decimal point",
            Format.formatSpeed(1536, { decimalPoint: "," }).value, "1,5"));

        const interfaces = {
            lo: scene.iface({ kind: "virtual", down: 999, up: 999 }),
            enp7s0: scene.iface({ down: 100, up: 10 }),
            wlp3s0: scene.iface({ down: 1, up: 1, online: false }),
            docker0: scene.iface({ kind: "virtual", down: 50, up: 50, online: false }),
            WorkVPN: scene.iface({ kind: "virtual", down: 80, up: 8 })
        };
        problems.push(scene.same("auto sum",
            Selection.summarize(interfaces, "auto", []),
            { down: 101, up: 11, online: true, included: ["enp7s0", "wlp3s0"], primary: "enp7s0" }));
        problems.push(scene.same("interface list order",
            Selection.interfaceList(interfaces, ["enp7s0", "wlp3s0"]).map(row => row.name),
            ["enp7s0", "wlp3s0", "docker0", "WorkVPN"]));

        const state = ProviderState.reduce(ProviderState.initialState(), {
            type: "sample",
            sample: {
                timestamp: 0,
                source: "proc",
                interfaces: { eth0: scene.iface({ down: 5, up: 6, ipv4: "10.0.0.2" }) }
            },
            now: 100
        });
        const view = ProviderState.derive(state, { mode: "auto", selected: [], now: 100, intervalMs: 1000 });
        problems.push(scene.same("populated view",
            [view.hasData, view.down, view.up, view.activeSource, view.includedCount,
                view.primaryLabel, view.primaryIp, view.stale],
            [true, 5, 6, "proc", 1, "eth0", "10.0.0.2", false]));

        for (const problem of problems) {
            if (problem !== "") {
                return problem;
            }
        }
        return "";
    }

    Component.onCompleted: {
        const problem = scene.run();
        scene.finish(problem === "", problem === "" ? "SMOKE OK parity" : "SMOKE FAIL parity: " + problem);
    }
}
