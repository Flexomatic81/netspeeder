// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Keeps the bookkeeping of a UsageModel in the configuration: the data cap
// level reported in the current billing period (see capAction() in usage.mjs)
// and the interfaces once seen as virtual (see nextKnownVirtual()). A value
// is written only when it changes. Reports a newly reached cap level through
// capReached; the applet shows the notification.

import QtQuick
import "../../code/usage.mjs" as Usage

Item {
    id: root

    required property UsageModel usage
    // Plasmoid.configuration, or an object with the same keys in tests:
    // capNotify, capNotifiedCycle, capNotifiedLevel and knownVirtual.
    property var configuration: null

    // A cap level (1 warning, 2 reached) to report.
    signal capReached(int level)

    // Takes a new vnStat result: decides the cap level once per level and
    // billing period and stores what has been seen.
    function handleFreshResult() {
        const config = root.configuration;
        if (config === null) {
            return;
        }
        const action = Usage.capAction({
            usageEnabled: root.usage.enabled,
            dataCapEnabled: root.usage.cap.enabled,
            capNotify: config.capNotify === true,
            freshOk: root.usage.status === "ok",
            namesReady: root.usage.ready,
            level: root.usage.cap.level,
            cycle: String(root.usage.summary.current.start ?? ""),
            notified: {
                cycle: config.capNotifiedCycle,
                level: config.capNotifiedLevel
            }
        });
        if (action.store.cycle !== config.capNotifiedCycle) {
            config.capNotifiedCycle = action.store.cycle;
        }
        if (action.store.level !== config.capNotifiedLevel) {
            config.capNotifiedLevel = action.store.level;
        }
        if (action.notify > 0) {
            root.capReached(action.notify);
        }
    }

    // Stores the interfaces once seen as virtual when that list changes.
    function rememberVirtual() {
        const update = root.usage.knownVirtualUpdate;
        if (root.configuration !== null && update !== null) {
            root.configuration.knownVirtual = update;
        }
    }

    Connections {
        target: root.usage

        function onFreshResult() {
            root.handleFreshResult();
        }

        // Later, because the write changes the input of knownVirtualUpdate.
        function onKnownVirtualUpdateChanged() {
            Qt.callLater(root.rememberVirtual);
        }
    }
}
